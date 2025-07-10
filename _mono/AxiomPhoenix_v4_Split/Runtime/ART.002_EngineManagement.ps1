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

#region Engine Management

function Initialize-TuiEngine {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log -Level Info -Message "Initializing TUI engine..."
        
        # Store original console state
        $global:TuiState.OriginalWindowTitle = $Host.UI.RawUI.WindowTitle
        $global:TuiState.OriginalCursorVisible = [Console]::CursorVisible
        
        # Configure console
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $env:PYTHONIOENCODING = "utf-8"
        [Console]::CursorVisible = $false
        $Host.UI.RawUI.WindowTitle = "Axiom-Phoenix v4.0 TUI Framework"
        
        # Clear screen and hide cursor
        Clear-Host
        [Console]::SetCursorPosition(0, 0)
        
        # Get initial size
        Update-TuiEngineSize
        
        # Create compositor buffers
        $width = $global:TuiState.BufferWidth
        $height = $global:TuiState.BufferHeight
        $global:TuiState.CompositorBuffer = [TuiBuffer]::new($width, $height, "Compositor")
        $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($width, $height, "PreviousCompositor")
        
        # Clear with theme background
        $bgColor = Get-ThemeColor -ColorName "Background" -DefaultColor "#000000"
        $global:TuiState.CompositorBuffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        $global:TuiState.PreviousCompositorBuffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        Write-Log -Level Info -Message "TUI engine initialized. Buffer size: ${width}x${height}"
    }
    catch {
        Invoke-WithErrorHandling -Component "TuiEngine" -Context "Initialization" -ScriptBlock { throw } `
            -AdditionalData @{ Phase = "EngineInit" }
    }
}

function Start-TuiEngine {
    [CmdletBinding()]
    param(
        [int]$TargetFPS = 30,
        [switch]$EnablePerformanceMonitoring,
        [int]$PerformanceReportInterval = 300  # frames
    )
    
    try {
        Write-Log -Level Info -Message "Starting TUI Engine with target FPS: $TargetFPS"
        
        # Calculate frame timing
        $targetFrameTime = [timespan]::FromSeconds(1.0 / $TargetFPS)
        $frameStopwatch = [System.Diagnostics.Stopwatch]::new()
        $performanceStopwatch = [System.Diagnostics.Stopwatch]::new()
        
        # Performance monitoring variables
        $frameTimeHistory = [System.Collections.Generic.Queue[double]]::new()
        $maxHistorySize = 60  # Keep last 60 frame times
        $slowFrameCount = 0
        $skippedFrameCount = 0
        
        $global:TuiState.Running = $true
        $global:TuiState.FrameCount = 0
        
        if ($EnablePerformanceMonitoring) {
            $performanceStopwatch.Start()
        }
        
        while ($global:TuiState.Running) {
            $frameStopwatch.Restart()
            
            try {
                # Phase 1: Handle console resize
                if ([Console]::WindowWidth -ne $global:TuiState.BufferWidth -or 
                    [Console]::WindowHeight -ne $global:TuiState.BufferHeight) {
                    
                    Invoke-WithErrorHandling -Component "TuiEngine" -Context "Resize" -ScriptBlock {
                        Update-TuiEngineSize
                    }
                }
                
                # Phase 2: Process input (always process input for responsiveness)
                Invoke-WithErrorHandling -Component "TuiEngine" -Context "Input" -ScriptBlock {
                    Process-TuiInput
                }
                
                # Phase 3: Render frame
                # Always render to maintain consistent frame rate and handle animations
                Invoke-WithErrorHandling -Component "TuiEngine" -Context "Render" -ScriptBlock {
                    Invoke-TuiRender
                }
                
                $global:TuiState.FrameCount++
                
                # Phase 4: Performance monitoring
                if ($EnablePerformanceMonitoring) {
                    $frameTime = $frameStopwatch.ElapsedMilliseconds
                    
                    # Track frame times
                    $frameTimeHistory.Enqueue($frameTime)
                    if ($frameTimeHistory.Count -gt $maxHistorySize) {
                        $frameTimeHistory.Dequeue()
                    }
                    
                    # Count slow frames
                    if ($frameTime -gt $targetFrameTime.TotalMilliseconds) {
                        $slowFrameCount++
                    }
                    
                    # Report performance every N frames
                    if ($global:TuiState.FrameCount % $PerformanceReportInterval -eq 0) {
                        $avgFrameTime = ($frameTimeHistory | Measure-Object -Average).Average
                        $maxFrameTime = ($frameTimeHistory | Measure-Object -Maximum).Maximum
                        $currentFPS = if ($avgFrameTime -gt 0) { 1000.0 / $avgFrameTime } else { 0 }
                        
                        Write-Log -Level Info -Message "TUI Performance Report - Frame: $($global:TuiState.FrameCount), Avg FPS: $([Math]::Round($currentFPS, 1)), Avg Frame Time: $([Math]::Round($avgFrameTime, 1))ms, Max Frame Time: $([Math]::Round($maxFrameTime, 1))ms, Slow Frames: $slowFrameCount, Skipped: $skippedFrameCount"
                        
                        # Reset counters
                        $slowFrameCount = 0
                        $skippedFrameCount = 0
                    }
                }
                
                # Phase 5: Frame rate throttling
                $frameStopwatch.Stop()
                $elapsedTime = $frameStopwatch.Elapsed
                
                if ($elapsedTime -lt $targetFrameTime) {
                    # We have time to spare - sleep for the remainder
                    $sleepTime = $targetFrameTime - $elapsedTime
                    if ($sleepTime.TotalMilliseconds -gt 0) {
                        Start-Sleep -Milliseconds $sleepTime.TotalMilliseconds
                    }
                }
                else {
                    # Frame took longer than target - log but continue
                    # Never skip input processing or rendering
                    $slowFrameCount++
                    
                    if ($EnablePerformanceMonitoring -and $elapsedTime.TotalMilliseconds -gt ($targetFrameTime.TotalMilliseconds * 2)) {
                        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                            $targetMs = [Math]::Round($targetFrameTime.TotalMilliseconds, 1)
                            $actualMs = [Math]::Round($elapsedTime.TotalMilliseconds, 1)
                            Write-Log -Level Warning -Message "TUI Engine: Frame $($global:TuiState.FrameCount) took ${actualMs}ms (target: ${targetMs}ms)"
                        }
                    }
                }
            }
            catch {
                Write-Log -Level Error -Message "TUI Engine: Frame $($global:TuiState.FrameCount) error: $($_.Exception.Message)"
                
                # Don't exit on frame errors - try to continue
                Start-Sleep -Milliseconds 50  # Brief pause to prevent tight error loop
            }
        }
        
        # Final performance report
        if ($EnablePerformanceMonitoring -and $performanceStopwatch.IsRunning) {
            $performanceStopwatch.Stop()
            $totalSeconds = $performanceStopwatch.Elapsed.TotalSeconds
            $avgFPS = if ($totalSeconds -gt 0) { $global:TuiState.FrameCount / $totalSeconds } else { 0 }
            
            Write-Log -Level Info -Message "TUI Engine stopped after $($global:TuiState.FrameCount) frames in $([Math]::Round($totalSeconds, 1))s. Average FPS: $([Math]::Round($avgFPS, 1))"
        }
        else {
            Write-Log -Level Info -Message "TUI Engine stopped after $($global:TuiState.FrameCount) frames"
        }
    }
    catch {
        Write-Log -Level Error -Message "TUI Engine critical error: $($_.Exception.Message)"
        Invoke-PanicHandler $_
    }
    finally {
        Stop-TuiEngine
    }
}

function Stop-TuiEngine {
    [CmdletBinding()]
    param(
        [switch]$Force
    )
    
    try {
        # Write-Verbose "Stopping TUI Engine..."
        
        $global:TuiState.Running = $false
        
        # Cleanup current screen via NavigationService
        $navService = $global:TuiState.Services.NavigationService
        if ($navService -and $navService.CurrentScreen) {
            try {
                $navService.CurrentScreen.OnExit()
                $navService.CurrentScreen.Cleanup()
            }
            catch {
                # Write-Verbose "Error cleaning up current screen: $_"
            }
        }
        
        # Cleanup services
        foreach ($service in $global:TuiState.Services.Values) {
            if ($service -and $service.PSObject -and $service.PSObject.Methods -and 
                $service.PSObject.Methods.Name -contains 'Cleanup') {
                try {
                    $service.Cleanup()
                }
                catch {
                    # Write-Verbose "Error cleaning up service: $_"
                }
            }
        }
        
        # Restore console
        [Console]::CursorVisible = $true
        [Console]::Clear()
        [Console]::SetCursorPosition(0, 0)
        
        # Write-Verbose "TUI Engine stopped and cleaned up"
    }
    catch {
        Write-Error "Error stopping TUI engine: $_"
    }
}

function Update-TuiEngineSize {
    [CmdletBinding()]
    param()
    
    try {
        # Try multiple methods to get console size
        $newWidth = $null
        $newHeight = $null
        
        # Method 1: Host.UI.RawUI
        try {
            $newWidth = $Host.UI.RawUI.WindowSize.Width
            $newHeight = $Host.UI.RawUI.WindowSize.Height
        } catch {}
        
        # Method 2: Console class
        if ($null -eq $newWidth -or $newWidth -le 0) {
            try {
                $newWidth = [Console]::WindowWidth
                $newHeight = [Console]::WindowHeight
            } catch {}
        }
        
        # Method 3: Mode command (Windows)
        if ($null -eq $newWidth -or $newWidth -le 0) {
            try {
                $modeOutput = cmd /c "mode con" 2>$null | Select-String "Columns:"
                if ($modeOutput) {
                    $newWidth = [int]($modeOutput -replace '.*Columns:\s*', '')
                }
                $modeOutput = cmd /c "mode con" 2>$null | Select-String "Lines:"
                if ($modeOutput) {
                    $newHeight = [int]($modeOutput -replace '.*Lines:\s*', '')
                }
            } catch {}
        }
        
        # Fallback
        if ($null -eq $newWidth -or $newWidth -le 0 -or $null -eq $newHeight -or $newHeight -le 0) {
            $newWidth = 120
            $newHeight = 30
            Write-Log -Level Warning -Message "Invalid console size detected. Using fallback: ${newWidth}x${newHeight}"
        }
        
        # Write-Verbose "Console resized from $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight) to ${newWidth}x${newHeight}"
        
        # Update state
        $global:TuiState.BufferWidth = $newWidth
        $global:TuiState.BufferHeight = $newHeight
        
        # Resize compositor buffers only if they exist
        if ($null -ne $global:TuiState.CompositorBuffer) {
            $global:TuiState.CompositorBuffer.Resize($newWidth, $newHeight)
        }
        if ($null -ne $global:TuiState.PreviousCompositorBuffer) {
            $global:TuiState.PreviousCompositorBuffer.Resize($newWidth, $newHeight)
        }
        
        # Resize current screen
        $navService = $global:TuiState.Services.NavigationService
        if ($navService -and $navService.CurrentScreen) {
            $navService.CurrentScreen.Resize($newWidth, $newHeight)
        }
        
        # Force full redraw
        $global:TuiState.IsDirty = $true
        if ($null -ne $global:TuiState.CompositorBuffer) {
            [Console]::Clear()
        }
    }
    catch {
        Write-Error "Failed to update engine size: $_"
    }
}

#endregion
#<!-- END_PAGE: ART.002 -->
