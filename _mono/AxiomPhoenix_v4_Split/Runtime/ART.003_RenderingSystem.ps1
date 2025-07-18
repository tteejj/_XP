# ==============================================================================
# Axiom-Phoenix v4.0 - All Runtime (Load Last)
# TUI engine, screen management, and main application loop
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ART.###" to find specific sections.
# Each section ends with "END_PAGE: ART.###"
# ==============================================================================

#region Rendering System

# PERFORMANCE: Track dirty regions to avoid full-screen renders
$script:DirtyRegions = [System.Collections.Generic.List[object]]::new()
$script:FullRedrawRequested = $true

function Add-DirtyRegion {
    param([int]$X, [int]$Y, [int]$Width, [int]$Height)
    $script:DirtyRegions.Add(@{ X = $X; Y = $Y; Width = $Width; Height = $Height })
}

function Request-FullRedraw {
    $script:FullRedrawRequested = $true
    $script:DirtyRegions.Clear()
}

# PERFORMANCE: Function to get performance report
function Get-TuiPerformanceReport {
    [CmdletBinding()]
    param()
    
    $report = @{
        RenderMetrics = $global:TuiPerformanceMetrics
        MemoryMetrics = $global:TuiMemoryMetrics
        TemplatePoolSize = if ($global:TuiTemplateCellPool) { $global:TuiTemplateCellPool.Count } else { 0 }
        GCInfo = @{
            Gen0Collections = [System.GC]::CollectionCount(0)
            Gen1Collections = [System.GC]::CollectionCount(1)
            Gen2Collections = [System.GC]::CollectionCount(2)
            TotalMemory = [System.GC]::GetTotalMemory($false)
        }
        OptimizationSavings = @{}
    }
    
    # Calculate optimization savings
    if ($global:TuiMemoryMetrics) {
        $totalCells = $global:TuiMemoryMetrics.TuiCellsCreated + $global:TuiMemoryMetrics.TuiCellsReused
        if ($totalCells -gt 0) {
            $reusePercentage = ($global:TuiMemoryMetrics.TuiCellsReused / $totalCells) * 100
            $report.OptimizationSavings.CellReusePercentage = [Math]::Round($reusePercentage, 2)
            $report.OptimizationSavings.ObjectsAvoided = $global:TuiMemoryMetrics.TuiCellsReused
        }
    }
    
    return $report
}

function Invoke-TuiRender {
    [CmdletBinding()]
    param()
    
    try {
        # DEBUG: Show when rendering happens
        #Write-Host "RENDER: Invoke-TuiRender called" -ForegroundColor Green
        
        # PERFORMANCE: Track render metrics
        $renderStartTime = [System.Diagnostics.Stopwatch]::StartNew()
        
        if ($null -eq $global:TuiState.CompositorBuffer) {
            #Write-Host "RENDER: CompositorBuffer is NULL - returning" -ForegroundColor Red
            return
        }
        
        # Clear the main compositor buffer with the base theme background
        $bgColor = Get-ThemeColor "Screen.Background" "#000000"
        $global:TuiState.CompositorBuffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # FIXED: WINDOW-BASED MODEL: Render all windows in the stack
        $navService = $global:TuiState.Services.NavigationService
        if ($navService) {
            # GetWindows() returns the stack from bottom to top, with the current screen last.
            $windowsToRender = $navService.GetWindows()
            
            foreach ($window in $windowsToRender) {
                if ($null -eq $window -or -not $window.Visible) { continue }
                
                try {
                    # Render the window, which updates its internal buffer
                    $window.Render()
                    
                    # Get the window's buffer and blend it onto the main compositor
                    $windowBuffer = $window.GetBuffer()
                    if ($windowBuffer) {
                        # The BlendBuffer method in TuiBuffer handles the Z-indexing and composition.
                        # For overlays, the dialog's OnRender method should handle dimming the background.
                        $global:TuiState.CompositorBuffer.BlendBuffer($windowBuffer, 0, 0)
                    }
                }
                catch {
                    Write-Error "Error rendering window '$($window.Name)': $_"
                    throw
                }
            }
        }
        
        # FIXED: Force full redraw on first frame by making previous buffer different
        if ($global:TuiState.FrameCount -eq 0) {
            for ($y = 0; $y -lt $global:TuiState.PreviousCompositorBuffer.Height; $y++) {
                for ($x = 0; $x -lt $global:TuiState.PreviousCompositorBuffer.Width; $x++) {
                    # Use a character and color that is unlikely to be the default
                    $global:TuiState.PreviousCompositorBuffer.SetCell($x, $y, [TuiCell]::new('?', "#010101", "#010101"))
                }
            }
        }
        
        # Differential rendering - compare current compositor to previous
        Render-DifferentialBuffer
        
        # PERFORMANCE: Swap buffers instead of cloning for differential rendering
        try {
            $tempBuffer = $global:TuiState.PreviousCompositorBuffer
            $global:TuiState.PreviousCompositorBuffer = $global:TuiState.CompositorBuffer
            $global:TuiState.CompositorBuffer = $tempBuffer
            
            # PERFORMANCE: Track buffer swaps
            if ($global:TuiMemoryMetrics -and $global:TuiDebugMode) {
                $global:TuiMemoryMetrics.BufferSwaps++
            }
            
            # Clear the swapped buffer for next frame
            $global:TuiState.CompositorBuffer.Clear([TuiCell]::new(' ', "#ffffff", "#000000"))
        }
        catch {
            # FALLBACK: If buffer swapping fails, fall back to cloning
            if ($global:TuiDebugMode) {
                Write-Log -Level Warning -Message "Buffer swapping failed, falling back to cloning: $_"
            }
            $global:TuiState.PreviousCompositorBuffer = $global:TuiState.CompositorBuffer.Clone()
        }
        
        # PERFORMANCE: Record render metrics
        $renderStartTime.Stop()
        if (-not $global:TuiPerformanceMetrics) {
            $global:TuiPerformanceMetrics = @{
                RenderTimes = [System.Collections.Generic.List[long]]::new()
                FrameCount = 0
                TotalRenderTime = 0
                AverageRenderTime = 0
                MaxRenderTime = 0
                MinRenderTime = [long]::MaxValue
            }
        }
        
        $renderTimeMs = $renderStartTime.ElapsedMilliseconds
        $global:TuiPerformanceMetrics.RenderTimes.Add($renderTimeMs)
        $global:TuiPerformanceMetrics.FrameCount++
        $global:TuiPerformanceMetrics.TotalRenderTime += $renderTimeMs
        $global:TuiPerformanceMetrics.AverageRenderTime = $global:TuiPerformanceMetrics.TotalRenderTime / $global:TuiPerformanceMetrics.FrameCount
        
        if ($renderTimeMs -gt $global:TuiPerformanceMetrics.MaxRenderTime) {
            $global:TuiPerformanceMetrics.MaxRenderTime = $renderTimeMs
        }
        if ($renderTimeMs -lt $global:TuiPerformanceMetrics.MinRenderTime) {
            $global:TuiPerformanceMetrics.MinRenderTime = $renderTimeMs
        }
        
        # Keep only last 100 render times to prevent memory buildup
        if ($global:TuiPerformanceMetrics.RenderTimes.Count -gt 100) {
            $global:TuiPerformanceMetrics.RenderTimes.RemoveAt(0)
        }
        
    }
    catch {
        Write-Error "Render error: $_"
        throw
    }
}

function Render-DifferentialBuffer {
    [CmdletBinding()]
    param()
    
    try {
        $current = $global:TuiState.CompositorBuffer
        $previous = $global:TuiState.PreviousCompositorBuffer
        
        if ($null -eq $current -or $null -eq $previous) {
            return
        }
        
        # PERFORMANCE OPTIMIZATION: Batch consecutive changes to reduce console calls
        $ansiBuilder = [System.Text.StringBuilder]::new(8192) # Pre-allocate larger buffer
        $lastFg = $null
        $lastBg = $null
        $lastBold = $false
        $lastItalic = $false
        $lastUnderline = $false
        $lastStrikethrough = $false
        
        # Track current run of consecutive changes
        $currentRun = $null
        $runCells = [System.Collections.Generic.List[object]]::new()
        
        # PERFORMANCE: Use dirty row tracking for optimal rendering
        $dirtyRows = if ($script:FullRedrawRequested) {
            # Full redraw - check all rows
            0..($current.Height - 1)
        } else {
            # Use buffer's dirty row tracking
            $current.GetDirtyRows()
        }
        
        # PERFORMANCE: Track metrics for dirty row optimization
        if ($global:TuiPerformanceMetrics) {
            $global:TuiPerformanceMetrics.DirtyRowsChecked = $dirtyRows.Count
            $global:TuiPerformanceMetrics.TotalRows = $current.Height
        }
        
        foreach ($y in $dirtyRows) {
            if ($y -lt 0 -or $y -ge $current.Height) { continue }
            
            # Check entire row for changes
            for ($x = 0; $x -lt $current.Width; $x++) {
                $currentCell = $current.GetCell($x, $y)
                $previousCell = $previous.GetCell($x, $y)
                
                if ($currentCell.DiffersFrom($previousCell)) {
                    # Start new run if we don't have one, or if this cell isn't consecutive
                    if ($null -eq $currentRun -or $currentRun.Y -ne $y -or $currentRun.X + $currentRun.Length -ne $x) {
                        # Flush previous run if we have one
                        if ($null -ne $currentRun) {
                            FlushRun $ansiBuilder $currentRun $runCells ([ref]$lastFg) ([ref]$lastBg) ([ref]$lastBold) ([ref]$lastItalic) ([ref]$lastUnderline) ([ref]$lastStrikethrough)
                        }
                        
                        # Start new run
                        $currentRun = @{ X = $x; Y = $y; Length = 0 }
                        $runCells.Clear()
                    }
                    
                    # Add cell to current run
                    $runCells.Add($currentCell)
                    $currentRun.Length++
                } else {
                    # End current run if we have one
                    if ($null -ne $currentRun) {
                        FlushRun $ansiBuilder $currentRun $runCells ([ref]$lastFg) ([ref]$lastBg) ([ref]$lastBold) ([ref]$lastItalic) ([ref]$lastUnderline) ([ref]$lastStrikethrough)
                        $currentRun = $null
                    }
                }
            }
            
            # End run at end of line
            if ($null -ne $currentRun) {
                FlushRun $ansiBuilder $currentRun $runCells ([ref]$lastFg) ([ref]$lastBg) ([ref]$lastBold) ([ref]$lastItalic) ([ref]$lastUnderline) ([ref]$lastStrikethrough)
                $currentRun = $null
            }
        }
        
        # Clear dirty regions after processing
        $script:DirtyRegions.Clear()
        $script:FullRedrawRequested = $false
        
        # PERFORMANCE: Clear dirty row tracking after rendering
        $current.ClearDirtyTracking()
        
        # Reset styling at the very end of the string
        if ($ansiBuilder.Length -gt 0) {
            [void]$ansiBuilder.Append([TuiAnsiHelper]::Reset())
            [Console]::Write($ansiBuilder.ToString())
        }
    }
    catch {
        Write-Error "Differential rendering error: $_"
        throw
    }
}

# PERFORMANCE OPTIMIZATION: Helper function to flush a run of consecutive changes
function FlushRun {
    [CmdletBinding()]
    param(
        [System.Text.StringBuilder]$ansiBuilder,
        [hashtable]$run,
        [System.Collections.Generic.List[object]]$cells,
        [ref]$lastFg,
        [ref]$lastBg,
        [ref]$lastBold,
        [ref]$lastItalic,
        [ref]$lastUnderline,
        [ref]$lastStrikethrough
    )
    
    if ($cells.Count -eq 0) { return }
    
    # Move cursor to start of run
    [void]$ansiBuilder.Append("`e[$($run.Y + 1);$($run.X + 1)H")
    
    # Optimize for runs with same styling
    $firstCell = $cells[0]
    $allSameStyle = $true
    
    for ($i = 1; $i -lt $cells.Count; $i++) {
        $cell = $cells[$i]
        if ($cell.ForegroundColor -ne $firstCell.ForegroundColor -or
            $cell.BackgroundColor -ne $firstCell.BackgroundColor -or
            $cell.Bold -ne $firstCell.Bold -or
            $cell.Italic -ne $firstCell.Italic -or
            $cell.Underline -ne $firstCell.Underline -or
            $cell.Strikethrough -ne $firstCell.Strikethrough) {
            $allSameStyle = $false
            break
        }
    }
    
    if ($allSameStyle -and $cells.Count -gt 1) {
        # Optimized path: Set style once for entire run  
        # Use TuiAnsiHelper directly to get just the style sequence
        $attributes = @{ 
            Bold=$firstCell.Bold; Italic=$firstCell.Italic; 
            Underline=$firstCell.Underline; Strikethrough=$firstCell.Strikethrough 
        }
        $sequence = [TuiAnsiHelper]::GetAnsiSequence($firstCell.ForegroundColor, $firstCell.BackgroundColor, $attributes)
        
        $styleChanged = ($firstCell.ForegroundColor -ne $lastFg.Value) -or
                       ($firstCell.BackgroundColor -ne $lastBg.Value) -or
                       ($firstCell.Bold -ne $lastBold.Value) -or
                       ($firstCell.Italic -ne $lastItalic.Value) -or
                       ($firstCell.Underline -ne $lastUnderline.Value) -or
                       ($firstCell.Strikethrough -ne $lastStrikethrough.Value)
        
        if ($styleChanged) {
            [void]$ansiBuilder.Append($sequence)
            $lastFg.Value = $firstCell.ForegroundColor
            $lastBg.Value = $firstCell.BackgroundColor
            $lastBold.Value = $firstCell.Bold
            $lastItalic.Value = $firstCell.Italic
            $lastUnderline.Value = $firstCell.Underline
            $lastStrikethrough.Value = $firstCell.Strikethrough
        }
        
        # Output all characters in run
        foreach ($cell in $cells) {
            [void]$ansiBuilder.Append($cell.Char)
        }
    } else {
        # Regular path: Handle each cell individually
        foreach ($cell in $cells) {
            $styleChanged = ($cell.ForegroundColor -ne $lastFg.Value) -or
                           ($cell.BackgroundColor -ne $lastBg.Value) -or
                           ($cell.Bold -ne $lastBold.Value) -or
                           ($cell.Italic -ne $lastItalic.Value) -or
                           ($cell.Underline -ne $lastUnderline.Value) -or
                           ($cell.Strikethrough -ne $lastStrikethrough.Value)
            
            if ($styleChanged) {
                [void]$ansiBuilder.Append($cell.ToAnsiString())
                $lastFg.Value = $cell.ForegroundColor
                $lastBg.Value = $cell.BackgroundColor
                $lastBold.Value = $cell.Bold
                $lastItalic.Value = $cell.Italic
                $lastUnderline.Value = $cell.Underline
                $lastStrikethrough.Value = $cell.Strikethrough
            } else {
                [void]$ansiBuilder.Append($cell.Char)
            }
        }
    }
}

#endregion
#<!-- END_PAGE: ART.003 -->