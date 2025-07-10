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

#<!-- PAGE: ART.001 - Global State -->
#region Global State

# Initialize global TUI state
$global:TuiState = @{
    Running = $false
    BufferWidth = [Math]::Max(80, [Console]::WindowWidth)
    BufferHeight = [Math]::Max(24, [Console]::WindowHeight)
    CompositorBuffer = $null
    PreviousCompositorBuffer = $null
    ScreenStack = [System.Collections.Generic.Stack[Screen]]::new() # CHANGED TO GENERIC STACK
    CurrentScreen = $null
    IsDirty = $true
    FocusedComponent = $null
    # CommandPalette removed - now managed by CommandPaletteManager service
    Services = @{}
    LastRenderTime = [datetime]::Now
    FrameCount = 0
    InputQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]'
    OverlayStack = [System.Collections.Generic.List[UIElement]]::new() # CHANGED TO GENERIC LIST
    # Added for input thread management
    CancellationTokenSource = $null
    InputRunspace = $null
    InputPowerShell = $null
    InputAsyncResult = $null
}

function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Component,
        
        [Parameter(Mandatory)]
        [string]$Context,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [hashtable]$AdditionalData = @{}
    )
    
    try {
        & $ScriptBlock
    }
    catch {
        $errorDetails = @{
            Component = $Component
            Context = $Context
            ErrorMessage = $_.Exception.Message
            ErrorType = $_.Exception.GetType().FullName
            StackTrace = $_.ScriptStackTrace
            Timestamp = [datetime]::Now
        }
        
        foreach ($key in $AdditionalData.Keys) {
            $errorDetails[$key] = $AdditionalData[$key]
        }
        
        $logger = $global:TuiState.Services.Logger
        if ($logger) {
            $logger.Log("Error", "Error in $Component during $Context : $($_.Exception.Message)")
            # Log error details with minimal depth to avoid circular references
            try {
                $logger.Log("Debug", "Error details: $($errorDetails | ConvertTo-Json -Compress -Depth 3 -ErrorAction SilentlyContinue)")
            } catch {
                # If serialization fails, just log the error type
                $logger.Log("Debug", "Error type: $($_.Exception.GetType().FullName)")
            }
        }
        
        # Re-throw for caller to handle if needed
        throw
    }
}
#endregion
#<!-- END_PAGE: ART.001 -->

#<!-- PAGE: ART.002 - Engine Management -->
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
                elseif ($elapsedTime.TotalMilliseconds -gt $targetFrameTime.TotalMilliseconds * 2) {
                    # Frame took more than twice the target time - we're falling behind
                    $skippedFrameCount++
                    
                    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Warning -Message "TUI Engine: Frame $($global:TuiState.FrameCount) took $([Math]::Round($elapsedTime.TotalMilliseconds, 1))ms (target: $([Math]::Round($targetFrameTime.TotalMilliseconds, 1))ms)"
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
        $newWidth = [Console]::WindowWidth
        $newHeight = [Console]::WindowHeight
        
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

#<!-- PAGE: ART.003 - Rendering System -->
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

#<!-- PAGE: ART.004 - Input Processing -->
#region Input Processing

# PURPOSE:
#   Re-architects the input loop to be "focus-first," establishing a clear and correct
#   input processing hierarchy. This is the definitive fix for the UI lockup.
#
# LOGIC:
#   1. PRIORITY 1: FOCUSED COMPONENT - The component currently tracked by the FocusManager
#      (e.g., the CommandPalette's text box) ALWAYS gets the first chance to handle the key.
#      If it returns $true, the input cycle for that key is complete.
#   2. PRIORITY 2: BUBBLE TO OVERLAY - If the focused component returns $false, and an
#      overlay is active, the overlay container itself gets a chance to handle the key.
#      This is for container-level actions like 'Escape' to close. The input cycle stops
#      here to enforce modality.
#   3. PRIORITY 3 & 4: GLOBALS & SCREEN - If no overlay is active, the event continues
#      to global keybindings and finally to the base screen.
#
function Process-TuiInput {
    [CmdletBinding()]
    param()
    
    try {
        while ([Console]::KeyAvailable) {
            $keyInfo = [Console]::ReadKey($true)
            
            # Emergency exit - Ctrl+C always works
            if ($keyInfo.Key -eq [ConsoleKey]::C -and ($keyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
                $global:TuiState.Running = $false
                return
            }
            
            # Get services from global state
            $focusManager = $global:TuiState.Services.FocusManager
            $keybindingService = $global:TuiState.Services.KeybindingService
            $actionService = $global:TuiState.Services.ActionService
            
            $inputHandled = $false
            
            # Priority 1: Focused component gets first chance
            $focusedComponent = if ($focusManager) { $focusManager.FocusedComponent } else { $null }
            
            if ($focusedComponent -and $focusedComponent.IsFocused -and $focusedComponent.Enabled) {
                Write-Log -Level Debug -Message "Process-TuiInput: Trying focused component: $($focusedComponent.Name)"
                if ($focusedComponent.HandleInput($keyInfo)) {
                    $global:TuiState.IsDirty = $true
                    Write-Log -Level Debug -Message "  - Input handled by focused component"
                    continue  # Input was handled, move to next key
                }
            }
            
            # Priority 2: If overlay is active, check if it wants to handle the input
            # But don't enforce strict modality - let focused components handle their input
            if ($global:TuiState.OverlayStack -and $global:TuiState.OverlayStack.Count -gt 0) {
                $topOverlay = $global:TuiState.OverlayStack[-1]
                Write-Log -Level Debug -Message "  - Checking overlay: $($topOverlay.Name)"
                if ($topOverlay -and $topOverlay.HandleInput($keyInfo)) {
                    $global:TuiState.IsDirty = $true
                    Write-Log -Level Debug -Message "  - Input handled by overlay"
                    continue  # Only continue if overlay actually handled it
                }
                # Don't enforce modality - let the input continue to other handlers
            }
            
            # Priority 3: Global keybindings (only if no overlay is active)
            if ($keybindingService) {
                $action = $keybindingService.GetAction($keyInfo)
                if ($action) {
                    Write-Log -Level Debug -Message "Process-TuiInput: Executing global action: $action"
                    if ($actionService) {
                        try {
                            $actionService.ExecuteAction($action, @{})
                            $global:TuiState.IsDirty = $true
                        }
                        catch {
                            Write-Log -Level Error -Message "Process-TuiInput: Failed to execute action '$action': $($_.Exception.Message)"
                        }
                    }
                    continue
                }
            }
            
            # Priority 4: Current screen gets the final chance (only if no overlay is active)
            if ($global:TuiState.CurrentScreen) {
                if ($global:TuiState.CurrentScreen.HandleInput($keyInfo)) {
                    $global:TuiState.IsDirty = $true
                }
            }
        }
    }
    catch {
        Write-Log -Level Error -Message "Input processing error: $($_.Exception.Message)"
    }
}

#endregion
#<!-- END_PAGE: ART.004 -->

#<!-- PAGE: ART.005 - Screen Management -->
#region Overlay Management

function Show-TuiOverlay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [UIElement]$Overlay
    )
    
    Write-Warning "Show-TuiOverlay is deprecated. Use DialogManager.ShowDialog() for dialogs or manage overlays directly."
    
    # Use DialogManager if the overlay is a Dialog
    if ($Overlay.GetType().Name -match "Dialog") {
        $dialogManager = $global:TuiState.Services.DialogManager
        if ($dialogManager) {
            $dialogManager.ShowDialog($Overlay)
            return
        }
    }
    
    # For non-dialog overlays, handle manually (deprecated path)
    if (-not $global:TuiState.OverlayStack) {
        $global:TuiState.OverlayStack = [System.Collections.Generic.List[UIElement]]::new()
    }
    
    # Position overlay at center
    $consoleWidth = $global:TuiState.BufferWidth
    $consoleHeight = $global:TuiState.BufferHeight
    $Overlay.X = [Math]::Max(0, [Math]::Floor(($consoleWidth - $Overlay.Width) / 2))
    $Overlay.Y = [Math]::Max(0, [Math]::Floor(($consoleHeight - $Overlay.Height) / 2))
    
    $Overlay.Visible = $true
    $Overlay.IsOverlay = $true
    $global:TuiState.OverlayStack.Add($Overlay)
    $global:TuiState.IsDirty = $true
    
    # Write-Log -Level Debug -Message "Show-TuiOverlay: Displayed overlay '$($Overlay.Name)' at X=$($Overlay.X), Y=$($Overlay.Y)"
}

function Close-TopTuiOverlay {
    [CmdletBinding()]
    param()
    
    Write-Warning "Close-TopTuiOverlay is deprecated. Use DialogManager.HideDialog() for dialogs or manage overlays directly."
    
    if ($global:TuiState.OverlayStack.Count -eq 0) {
        # Write-Log -Level Warning -Message "Close-TopTuiOverlay: No overlays to close"
        return
    }
    
    $topOverlay = $global:TuiState.OverlayStack[-1]
    
    # Use DialogManager if it's a Dialog
    if ($topOverlay.GetType().Name -match "Dialog") {
        $dialogManager = $global:TuiState.Services.DialogManager
        if ($dialogManager) {
            $dialogManager.HideDialog($topOverlay)
            return
        }
    }
    
    # Manual removal for non-dialog overlays (deprecated path)
    $global:TuiState.OverlayStack.RemoveAt($global:TuiState.OverlayStack.Count - 1)
    $topOverlay.Visible = $false
    $topOverlay.IsOverlay = $false
    $topOverlay.Cleanup()
    $global:TuiState.IsDirty = $true
    
    # Write-Log -Level Debug -Message "Close-TopTuiOverlay: Closed overlay '$($topOverlay.Name)'"
}

#endregion
#<!-- END_PAGE: ART.005 -->

#<!-- PAGE: ART.006 - Error Handling -->
#region Panic Handler

function Invoke-PanicHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ErrorRecord
    )
    
    # Ensure we're in a safe state to write to console
    try {
        [Console]::ResetColor()
        [Console]::CursorVisible = $true
        Clear-Host
    } catch { }
    
    Write-Host "`n`n" -NoNewline
    Write-Host "================================ PANIC HANDLER ================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "An unrecoverable error has occurred:" -ForegroundColor Yellow
    Write-Host ""
    
    # Error details
    Write-Host "ERROR: " -ForegroundColor Red -NoNewline
    Write-Host $ErrorRecord.Exception.Message
    Write-Host ""
    Write-Host "TYPE: " -ForegroundColor Yellow -NoNewline
    Write-Host $ErrorRecord.Exception.GetType().FullName
    Write-Host ""
    
    # Stack trace
    Write-Host "STACK TRACE:" -ForegroundColor Yellow
    $stackLines = $ErrorRecord.ScriptStackTrace -split "`n"
    foreach ($line in $stackLines) {
        Write-Host "  $line" -ForegroundColor DarkGray
    }
    Write-Host ""
    
    # System info
    Write-Host "SYSTEM INFO:" -ForegroundColor Yellow
    Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    Write-Host "  Platform: $($PSVersionTable.Platform)" -ForegroundColor DarkGray
    Write-Host "  OS: $($PSVersionTable.OS)" -ForegroundColor DarkGray
    Write-Host "  Host: $($Host.Name) v$($Host.Version)" -ForegroundColor DarkGray
    Write-Host ""
    
    # Save crash report
    $crashDir = Join-Path $env:TEMP "AxiomPhoenix\Crashes"
    if (-not (Test-Path $crashDir)) {
        New-Item -ItemType Directory -Path $crashDir -Force | Out-Null
    }
    
    $crashFile = Join-Path $crashDir "crash_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $crashReport = @{
        Timestamp = [datetime]::Now
        Error = @{
            Message = $ErrorRecord.Exception.Message
            Type = $ErrorRecord.Exception.GetType().FullName
            StackTrace = $ErrorRecord.ScriptStackTrace
            InnerException = if ($ErrorRecord.Exception.InnerException) { $ErrorRecord.Exception.InnerException.Message } else { $null }
        }
        System = @{
            PowerShell = $PSVersionTable.PSVersion.ToString()
            Platform = $PSVersionTable.Platform
            OS = $PSVersionTable.OS
            Host = "$($Host.Name) v$($Host.Version)"
        }
        GlobalState = @{
            Running = $global:TuiState.Running
            BufferSize = "$($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight)"
            CurrentScreen = if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.Name } else { "None" }
            OverlayCount = if ($global:TuiState.OverlayStack) { $global:TuiState.OverlayStack.Count } else { 0 }
        }
    }
    
    try {
        # Sanitize crash report data to avoid circular references
        $sanitizedReport = @{
            Timestamp = $crashReport.Timestamp
            ErrorMessage = $crashReport.ErrorMessage
            ErrorType = $crashReport.ErrorType
            ScriptStackTrace = $crashReport.ScriptStackTrace
            GlobalState = @{
                Running = $crashReport.GlobalState.Running
                BufferSize = $crashReport.GlobalState.BufferSize
                CurrentScreen = $crashReport.GlobalState.CurrentScreen
                OverlayCount = $crashReport.GlobalState.OverlayCount
            }
        }
        $sanitizedReport | ConvertTo-Json -Depth 5 | Out-File -FilePath $crashFile -Encoding UTF8
        Write-Host "Crash report saved to: $crashFile" -ForegroundColor Green
    } catch {
        Write-Host "Failed to save crash report: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Final cleanup
    try {
        Stop-TuiEngine -Force
    } catch { }
    
    exit 1
}

function Start-AxiomPhoenix {
    [CmdletBinding()]
    param(
        [ServiceContainer]$ServiceContainer,
        [Screen]$InitialScreen
    )
    
    try {
        # Write-Log -Level Info -Message "Starting Axiom-Phoenix application..."
        
        # Store services
        $global:TuiState.Services = @{
            ServiceContainer = $ServiceContainer
        }
        
        # Extract key services for quick access
        $serviceNames = @(
            'ActionService', 'KeybindingService', 'NavigationService', 
            'DataManager', 'ThemeManager', 'EventManager', 'Logger', 'FocusManager', 'DialogManager', 
            'TuiFrameworkService', 'CommandPaletteManager' # Add new services
        )
        
        foreach ($serviceName in $serviceNames) {
            try {
                $service = $ServiceContainer.GetService($serviceName)
                if ($service) {
                    $global:TuiState.Services[$serviceName] = $service
                }
            }
            catch {
                # Write-Log -Level Warning -Message "Failed to get service '$serviceName': $($_.Exception.Message)" -Data $_
            }
        }
        
        # CommandPalette is now managed by the CommandPaletteManager service
        
        # Initialize engine
        Initialize-TuiEngine
        
        # Get the NavigationService instance directly from global state
        $navService = $global:TuiState.Services.NavigationService

        # Set initial screen using NavigationService (CRUCIAL FIX)
        if ($InitialScreen) {
            $navService.NavigateTo($InitialScreen) # Use the service directly
        }
        else {
            # Write-Log -Level Warning -Message "No initial screen provided. Application might not display anything."
        }
        
        # Start main loop
        Start-TuiEngine
    }
    catch {
        # Use Invoke-PanicHandler for critical startup errors
        Invoke-PanicHandler $_
    }
    finally {
        Stop-TuiEngine # Ensure cleanup even if startup fails
    }
}

#endregion
#<!-- END_PAGE: ART.006 -->