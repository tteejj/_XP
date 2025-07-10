####\AllRuntime.ps1
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

function Invoke-TuiRender {
    [CmdletBinding()]
    param()
    
    try {
        $renderTimer = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Ensure compositor buffer exists
        if ($null -eq $global:TuiState.CompositorBuffer) {
            # Write-Verbose "Compositor buffer is null, skipping render"
            return
        }
        
        # Clear compositor buffer
        $global:TuiState.CompositorBuffer.Clear()
        
        # Write-Verbose "Starting render frame $($global:TuiState.FrameCount)"
        
        # Get the current screen from global state (NavigationService updates this)
        $currentScreenToRender = $global:TuiState.CurrentScreen
        
        # Render current screen
        if ($currentScreenToRender) {
            try {
                # Render the screen which will update its internal buffer
                $currentScreenToRender.Render()
                
                # Get the screen's buffer
                $screenBuffer = $currentScreenToRender.GetBuffer()
                
                if ($screenBuffer) {
                    # Blend screen buffer into compositor
                    $global:TuiState.CompositorBuffer.BlendBuffer($screenBuffer, 0, 0)
                }
                else {
                    # Write-Verbose "Screen buffer is null for $($currentScreenToRender.Name)"
                }
            }
            catch {
                Write-Error "Error rendering screen: $_"
                throw
            }
            
            # Render overlays (including command palette)
            if ($global:TuiState.ContainsKey('OverlayStack') -and $global:TuiState.OverlayStack -and @($global:TuiState.OverlayStack).Count -gt 0) {
                Write-Log -Level Debug -Message "Rendering $($global:TuiState.OverlayStack.Count) overlays"
                foreach ($overlay in $global:TuiState.OverlayStack) {
                    if ($overlay -and $overlay.Visible) {
                        try {
                            Write-Log -Level Debug -Message "Rendering overlay: $($overlay.Name) at X=$($overlay.X), Y=$($overlay.Y)"
                            $overlay.Render()
                            $overlayBuffer = $overlay.GetBuffer()
                            if ($overlayBuffer) {
                                $global:TuiState.CompositorBuffer.BlendBuffer($overlayBuffer, $overlay.X, $overlay.Y)
                            } else {
                                Write-Log -Level Warning -Message "Overlay $($overlay.Name) has no buffer"
                            }
                        } catch {
                            Write-Log -Level Error -Message "Error rendering overlay $($overlay.Name): $_"
                        }
                    }
                }
            }
        }
        
        # Force full redraw on first frame by making previous buffer different
        if ($global:TuiState.FrameCount -eq 0) {
            # Write-Verbose "First frame - initializing previous buffer for differential rendering"
            # Fill previous buffer with different content to force full redraw
            for ($y = 0; $y -lt $global:TuiState.PreviousCompositorBuffer.Height; $y++) {
                for ($x = 0; $x -lt $global:TuiState.PreviousCompositorBuffer.Width; $x++) {
                    $global:TuiState.PreviousCompositorBuffer.SetCell($x, $y, 
                        [TuiCell]::new('?', "#404040", "#404040"))
                }
            }
        }
        
        # Differential rendering - compare current compositor to previous
        Render-DifferentialBuffer
        
        # Swap buffers for next frame - MUST happen AFTER rendering
        # Use the efficient Clone() method instead of manual copying
        $global:TuiState.PreviousCompositorBuffer = $global:TuiState.CompositorBuffer.Clone()
        
        # Clear compositor for next frame
        $bgColor = Get-ThemeColor -ColorName "Background" -DefaultColor "#000000"
        $global:TuiState.CompositorBuffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        $renderTimer.Stop()
        
        if ($renderTimer.ElapsedMilliseconds -gt 16) {
            # Write-Verbose "Slow frame: $($renderTimer.ElapsedMilliseconds)ms"
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
        
        # Ensure both buffers exist
        if ($null -eq $current -or $null -eq $previous) {
            # Write-Verbose "Compositor buffers not initialized, skipping differential render"
            return
        }
        
        $ansiBuilder = [System.Text.StringBuilder]::new()
        $currentX = -1
        $currentY = -1
        $changeCount = 0
        
        for ($y = 0; $y -lt $current.Height; $y++) {
            for ($x = 0; $x -lt $current.Width; $x++) {
                $currentCell = $current.GetCell($x, $y)
                $previousCell = $previous.GetCell($x, $y)
                
                if ($currentCell.DiffersFrom($previousCell)) {
                    $changeCount++
                    
                    # Move cursor if needed
                    if ($currentX -ne $x -or $currentY -ne $y) {
                        [void]$ansiBuilder.Append("`e[$($y + 1);$($x + 1)H")
                        $currentX = $x
                        $currentY = $y
                    }
                    
                    # Use cell's ToAnsiString method which handles all styling
                    [void]$ansiBuilder.Append($currentCell.ToAnsiString())
                    $currentX++
                }
            }
        }
        
        # Log changes on first few frames
        if ($global:TuiState.FrameCount -lt 5) {
            # Write-Verbose "Frame $($global:TuiState.FrameCount): $changeCount cells changed"
        }
        
        # Reset styling at end
        if ($ansiBuilder.Length -gt 0) {
            [void]$ansiBuilder.Append("`e[0m")
            [Console]::Write($ansiBuilder.ToString())
        }
    }
    catch {
        Write-Error "Differential rendering error: $_"
        throw
    }
}

#endregion
#<!-- END_PAGE: ART.003 -->
