# ==============================================================================
# TUI Engine v5.3 - Lifecycle-Aware Compositor
# Core engine providing complete lifecycle management and high-performance rendering
# ==============================================================================

using module ui-classes
using module tui-primitives
using module theme-manager
using module logger
using module exceptions
using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Management.Automation
using namespace System.Threading

#region Core TUI State

# Global TUI state management
$global:TuiState = @{
    Running = $false
    BufferWidth = 0
    BufferHeight = 0
    CompositorBuffer = $null
    PreviousCompositorBuffer = $null
    ScreenStack = [System.Collections.Stack]::new()
    CurrentScreen = $null
    OverlayStack = [System.Collections.Generic.List[UIElement]]::new()
    IsDirty = $true
    RenderStats = @{
        LastFrameTime = 0
        FrameCount = 0
        TargetFPS = 60
        AverageFrameTime = 0
    }
    Components = @()
    Layouts = @{}
    FocusedComponent = $null
    InputQueue = [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]::new()
    InputRunspace = $null
    InputPowerShell = $null
    InputAsyncResult = $null
    CancellationTokenSource = $null
    EventHandlers = @{}
    LastWindowWidth = 0
    LastWindowHeight = 0
}

#endregion

#region Engine Lifecycle & Main Loop

function Initialize-TuiEngine {
    <#
    .SYNOPSIS
    Initializes the TUI engine with specified dimensions.
    #>
    [CmdletBinding()]
    param(
        [int]$Width = [Console]::WindowWidth,
        [int]$Height = [Console]::WindowHeight - 1
    )
    
    try {
        Write-Log -Level Info -Message "Initializing TUI Engine with dimensions $Width x $Height"
        
        # Store initial console state
        $global:TuiState.BufferWidth = $Width
        $global:TuiState.BufferHeight = $Height
        $global:TuiState.LastWindowWidth = [Console]::WindowWidth
        $global:TuiState.LastWindowHeight = [Console]::WindowHeight
        
        # Initialize buffers
        $global:TuiState.CompositorBuffer = [TuiBuffer]::new($Width, $Height, "CompositorBuffer")
        $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($Width, $Height, "PreviousCompositorBuffer")
        
        # Configure console
        [Console]::CursorVisible = $false
        [Console]::TreatControlCAsInput = $true
        
        # Initialize input processing
        Initialize-InputThread
        
        # Initialize panic handler
        Initialize-PanicHandler
        
        Write-Log -Level Info -Message "TUI Engine initialized successfully"
    }
    catch {
        Write-Error "Failed to initialize TUI Engine: $($_.Exception.Message)"
        throw
    }
}

function Initialize-InputThread {
    <#
    .SYNOPSIS
    Initializes the asynchronous input processing thread.
    #>
    [CmdletBinding()]
    param()
    
    try {
        $global:TuiState.CancellationTokenSource = [CancellationTokenSource]::new()
        $global:TuiState.InputRunspace = [RunspaceFactory]::CreateRunspace()
        $global:TuiState.InputRunspace.Open()
        
        # Share the input queue with the runspace
        $global:TuiState.InputRunspace.SessionStateProxy.SetVariable("InputQueue", $global:TuiState.InputQueue)
        $global:TuiState.InputRunspace.SessionStateProxy.SetVariable("CancellationToken", $global:TuiState.CancellationTokenSource.Token)
        
        # Create input processing script
        $inputScript = {
            param($InputQueue, $CancellationToken)
            
            while (-not $CancellationToken.IsCancellationRequested) {
                try {
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        $InputQueue.Enqueue($key)
                    }
                    Start-Sleep -Milliseconds 10
                }
                catch {
                    # Input thread error handling
                    break
                }
            }
        }
        
        # Start input processing
        $global:TuiState.InputPowerShell = [PowerShell]::Create()
        $global:TuiState.InputPowerShell.Runspace = $global:TuiState.InputRunspace
        [void]$global:TuiState.InputPowerShell.AddScript($inputScript).AddArgument($global:TuiState.InputQueue).AddArgument($global:TuiState.CancellationTokenSource.Token)
        $global:TuiState.InputAsyncResult = $global:TuiState.InputPowerShell.BeginInvoke()
        
        Write-Log -Level Debug -Message "Input thread initialized successfully"
    }
    catch {
        Write-Error "Failed to initialize input thread: $($_.Exception.Message)"
        throw
    }
}

function Start-TuiLoop {
    <#
    .SYNOPSIS
    Starts the main TUI rendering and input processing loop.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InitialScreen
    )
    
    try {
        if (-not $global:TuiState.BufferWidth) {
            Initialize-TuiEngine
        }
        
        if ($InitialScreen) {
            Push-Screen -Screen $InitialScreen
        }
        
        if (-not $global:TuiState.CurrentScreen) {
            throw "No screen available to start TUI loop"
        }
        
        $global:TuiState.Running = $true
        $frameTimer = [System.Diagnostics.Stopwatch]::new()
        $targetFrameTime = 1000.0 / $global:TuiState.RenderStats.TargetFPS
        
        Write-Log -Level Info -Message "Starting TUI main loop"
        
        while ($global:TuiState.Running) {
            try {
                $frameTimer.Restart()
                
                # Check for terminal resize
                Check-ForResize
                
                # Process input
                $hadInput = Process-TuiInput
                
                # Render frame if needed
                if ($global:TuiState.IsDirty -or $hadInput) {
                    Render-Frame
                    $global:TuiState.IsDirty = $false
                }
                
                # Frame rate limiting
                $elapsed = $frameTimer.ElapsedMilliseconds
                if ($elapsed -lt $targetFrameTime) {
                    $sleepTime = [Math]::Max(1, [int]($targetFrameTime - $elapsed))
                    Start-Sleep -Milliseconds $sleepTime
                }
                
                # Update render stats
                $global:TuiState.RenderStats.LastFrameTime = $frameTimer.ElapsedMilliseconds
                $global:TuiState.RenderStats.FrameCount++
                
                # Calculate average frame time
                if ($global:TuiState.RenderStats.FrameCount % 60 -eq 0) {
                    $global:TuiState.RenderStats.AverageFrameTime = $global:TuiState.RenderStats.LastFrameTime
                }
            }
            catch {
                Write-Error "Error in TUI main loop: $($_.Exception.Message)"
                Invoke-PanicHandler -ErrorRecord $_ -AdditionalContext @{ Context = "TUI Main Loop" }
                
                # Stop running on any critical error to prevent infinite loops
                $global:TuiState.Running = $false
                break
            }
        }
        
        Write-Log -Level Info -Message "TUI main loop ended"
    }
    catch {
        Write-Error "Fatal error in TUI loop: $($_.Exception.Message)"
        throw
    }
    finally {
        Cleanup-TuiEngine
    }
}

function Check-ForResize {
    <#
    .SYNOPSIS
    Checks for terminal resize and handles resize events.
    #>
    [CmdletBinding()]
    param()
    
    try {
        $currentWidth = [Console]::WindowWidth
        $currentHeight = [Console]::WindowHeight - 1
        
        if ($currentWidth -ne $global:TuiState.BufferWidth -or $currentHeight -ne $global:TuiState.BufferHeight) {
            Write-Log -Level Info -Message "Terminal resized from $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight) to $($currentWidth)x$($currentHeight)"
            
            # Update global state
            $global:TuiState.BufferWidth = $currentWidth
            $global:TuiState.BufferHeight = $currentHeight
            
            # Resize core buffers
            $global:TuiState.CompositorBuffer.Resize($currentWidth, $currentHeight)
            $global:TuiState.PreviousCompositorBuffer.Resize($currentWidth, $currentHeight)
            
            # Propagate resize to current screen
            if ($global:TuiState.CurrentScreen) {
                $global:TuiState.CurrentScreen.Resize($currentWidth, $currentHeight)
            }
            
            # Resize overlays
            foreach ($overlay in $global:TuiState.OverlayStack) {
                if ($overlay -is [Dialog]) {
                    $overlay.X = [Math]::Floor(($currentWidth - $overlay.Width) / 2)
                    $overlay.Y = [Math]::Floor(($currentHeight - $overlay.Height) / 4)
                }
                $overlay.Resize($overlay.Width, $overlay.Height)
            }
            
            # Publish resize event
            Publish-Event -EventName "TUI.Resized" -Data @{
                Width = $currentWidth
                Height = $currentHeight
                PreviousWidth = $global:TuiState.LastWindowWidth
                PreviousHeight = $global:TuiState.LastWindowHeight
            }
            
            # Update tracking variables
            $global:TuiState.LastWindowWidth = $currentWidth
            $global:TuiState.LastWindowHeight = $currentHeight
            
            # Force redraw
            Request-TuiRefresh
        }
    }
    catch {
        Write-Error "Error checking for resize: $($_.Exception.Message)"
    }
}

function Process-TuiInput {
    <#
    .SYNOPSIS
    Processes input from the input queue.
    #>
    [CmdletBinding()]
    param()
    
    $hadInput = $false
    $keyInfo = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::None, $false, $false, $false)
    
    try {
        while ($global:TuiState.InputQueue.TryDequeue([ref]$keyInfo)) {
            $hadInput = $true
            
            # Handle global shortcuts first
            if (Handle-GlobalShortcuts -KeyInfo $keyInfo) {
                continue
            }
            
            # Route to overlays first (top overlay gets priority)
            if ($global:TuiState.OverlayStack.Count -gt 0) {
                $topOverlay = $global:TuiState.OverlayStack[-1]
                if ($topOverlay.HandleInput($keyInfo)) {
                    continue
                }
            }
            
            # Route to focused component if not an overlay
            if ($global:TuiState.OverlayStack.Count -eq 0 -and $global:TuiState.FocusedComponent) {
                if ($global:TuiState.FocusedComponent.HandleInput($keyInfo)) {
                    continue
                }
            }
            
            # Route to current screen
            if ($global:TuiState.CurrentScreen) {
                if ($global:TuiState.CurrentScreen.HandleInput($keyInfo)) {
                    continue
                }
            }
            
            Write-Verbose "Unhandled input: $($keyInfo.Key)"
        }
    }
    catch {
        Write-Error "Error processing input: $($_.Exception.Message)"
    }
    
    return $hadInput
}

function Handle-GlobalShortcuts {
    <#
    .SYNOPSIS
    Handles global keyboard shortcuts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$KeyInfo
    )
    
    try {
        # Ctrl+C - Graceful shutdown
        if ($KeyInfo.Key -eq [ConsoleKey]::C -and $KeyInfo.Modifiers -band [ConsoleModifiers]::Control) {
            Write-Log -Level Info -Message "Received Ctrl+C, initiating graceful shutdown"
            $global:TuiState.Running = $false
            return $true
        }
        
        # Ctrl+P - Command Palette
        if ($KeyInfo.Key -eq [ConsoleKey]::P -and ($KeyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
            if (Get-Command Publish-Event -ErrorAction SilentlyContinue) {
                Publish-Event -EventName "CommandPalette.Open"
                return $true
            }
        }
        
        # F12 - Debug information
        if ($KeyInfo.Key -eq [ConsoleKey]::F12) {
            Show-DebugInfo
            return $true
        }
        
        return $false
    }
    catch {
        Write-Error "Error handling global shortcuts: $($_.Exception.Message)"
        return $false
    }
}

function Render-Frame {
    <#
    .SYNOPSIS
    Renders the current frame to the screen.
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Clear compositor buffer
        $global:TuiState.CompositorBuffer.Clear()
        
        # Render current screen
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.Render()
            $global:TuiState.CompositorBuffer.BlendBuffer($global:TuiState.CurrentScreen.GetBuffer(), 0, 0)
        }
        
        # Render overlays
        foreach ($overlay in $global:TuiState.OverlayStack) {
            $overlay.Render()
            $global:TuiState.CompositorBuffer.BlendBuffer($overlay.GetBuffer(), $overlay.X, $overlay.Y)
        }
        
        # Perform differential update to console
        Render-CompositorToConsole
        
        # Swap buffers for next frame's diffing
        $tempBuffer = $global:TuiState.CompositorBuffer
        $global:TuiState.CompositorBuffer = $global:TuiState.PreviousCompositorBuffer
        $global:TuiState.PreviousCompositorBuffer = $tempBuffer
    }
    catch {
        Write-Error "Error rendering frame: $($_.Exception.Message)"
    }
}

function Render-CompositorToConsole {
    <#
    .SYNOPSIS
    Renders the compositor buffer to the console with differential updates.
    #>
    [CmdletBinding()]
    param()
    
    try {
        $output = [System.Text.StringBuilder]::new()
        
        for ($y = 0; $y -lt $global:TuiState.BufferHeight; $y++) {
            for ($x = 0; $x -lt $global:TuiState.BufferWidth; $x++) {
                $currentCell = $global:TuiState.PreviousCompositorBuffer.GetCell($x, $y) # Note: we render from the buffer that was just composed
                $previousCell = $global:TuiState.CompositorBuffer.GetCell($x, $y) # The "old" frame
                
                # Use DiffersFrom for correct value comparison
                if ($currentCell.DiffersFrom($previousCell)) {
                    # Suppress StringBuilder.Append output by casting to [void]
                    [void]$output.Append("`e[" + ($y + 1) + ";" + ($x + 1) + "H")
                    
                    # Use TuiAnsiHelper for Truecolor support and styling
                    [void]$output.Append([TuiAnsiHelper]::Reset())
                    [void]$output.Append([TuiAnsiHelper]::GetForegroundCode($currentCell.ForegroundColor))
                    [void]$output.Append([TuiAnsiHelper]::GetBackgroundCode($currentCell.BackgroundColor))
                    
                    if ($currentCell.Bold) { [void]$output.Append([TuiAnsiHelper]::Bold()) }
                    if ($currentCell.Underline) { [void]$output.Append([TuiAnsiHelper]::Underline()) }
                    if ($currentCell.Italic) { [void]$output.Append([TuiAnsiHelper]::Italic()) }
                    
                    [void]$output.Append($currentCell.Char)
                }
            }
        }
        
        if ($output.Length -gt 0) {
            [void]$output.Append([TuiAnsiHelper]::Reset())
            [Console]::Write($output.ToString())
        }
    }
    catch {
        Write-Error "Error rendering to console: $($_.Exception.Message)"
    }
}

function Cleanup-TuiEngine {
    <#
    .SYNOPSIS
    Cleans up all TUI engine resources.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Log -Level Info -Message "Cleaning up TUI Engine"
        
        # Cleanup all screens and components
        if ($global:TuiState.CurrentScreen -and $global:TuiState.CurrentScreen.PSObject.Methods['Cleanup']) {
            $global:TuiState.CurrentScreen.Cleanup()
        }
        
        while ($global:TuiState.ScreenStack.Count -gt 0) {
            $screen = $global:TuiState.ScreenStack.Pop()
            if ($screen.PSObject.Methods['Cleanup']) {
                $screen.Cleanup()
            }
        }
        
        # Cleanup overlays
        foreach ($overlay in $global:TuiState.OverlayStack) {
            if ($overlay.PSObject.Methods['Cleanup']) {
                $overlay.Cleanup()
            }
        }
        $global:TuiState.OverlayStack.Clear()
        
        # Stop input thread
        if ($global:TuiState.CancellationTokenSource -and -not $global:TuiState.CancellationTokenSource.IsCancellationRequested) {
            $global:TuiState.CancellationTokenSource.Cancel()
        }
        
        if ($global:TuiState.InputPowerShell) {
            $global:TuiState.InputPowerShell.EndInvoke($global:TuiState.InputAsyncResult)
            $global:TuiState.InputPowerShell.Dispose()
        }
        
        if ($global:TuiState.InputRunspace) {
            $global:TuiState.InputRunspace.Dispose()
        }
        
        $global:TuiState.CancellationTokenSource.Dispose()
        
        # Restore console
        [Console]::CursorVisible = $true
        [Console]::TreatControlCAsInput = $false
        [Console]::Clear()
        
        Write-Log -Level Info -Message "TUI Engine cleanup completed"
    }
    catch {
        Write-Error "Error during TUI cleanup: $($_.Exception.Message)"
    }
}

#endregion

#region Screen & Overlay Management

function Push-Screen {
    <#
    .SYNOPSIS
    Pushes a new screen onto the screen stack.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        # FIX: Removed the [UIElement] type constraint to avoid module scoping issues.
        $Screen
    )
    
    if (-not $Screen) {
        Write-Error "Push-Screen: Screen parameter is null"
        return
    }
    
    try {
        $screenName = $Screen.Name ?? "UnknownScreen"
        Write-Log -Level Debug -Message "Pushing screen: $screenName"
        
        if ($global:TuiState.FocusedComponent) {
            $global:TuiState.FocusedComponent.OnBlur()
        }
        
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.OnExit()
            [void]$global:TuiState.ScreenStack.Push($global:TuiState.CurrentScreen)
        }
        
        $global:TuiState.CurrentScreen = $Screen
        $global:TuiState.FocusedComponent = $null
        
        $Screen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)
        
        if ($Screen.PSObject.Methods['OnInitialize']) {
            $Screen.OnInitialize()
        }
        
        $Screen.OnEnter()
        $Screen.RequestRedraw()
        
        Request-TuiRefresh
        Publish-Event -EventName "Screen.Pushed" -Data @{ ScreenName = $screenName }
        Write-Log -Level Debug -Message "Screen pushed successfully: $screenName"
    }
    catch {
        $errorMsg = $_.Exception.Message ?? "Unknown error"
        $screenName = if ($Screen -and $Screen.PSObject.Properties['Name']) { $Screen.Name } else { "UnknownScreen" }
        Write-Error "Error pushing screen '$screenName': $errorMsg"
        $global:TuiState.Running = $false
    }
}

function Pop-Screen {
    <#
    .SYNOPSIS
    Pops the current screen from the screen stack.
    #>
    [CmdletBinding()]
    param()
    
    if ($global:TuiState.ScreenStack.Count -eq 0) {
        Write-Log -Level Warning -Message "Cannot pop screen: screen stack is empty"
        return $false
    }
    
    try {
        Write-Log -Level Debug -Message "Popping screen"
        
        if ($global:TuiState.FocusedComponent) {
            $global:TuiState.FocusedComponent.OnBlur()
        }
        
        $screenToExit = $global:TuiState.CurrentScreen
        
        $global:TuiState.CurrentScreen = $global:TuiState.ScreenStack.Pop()
        $global:TuiState.FocusedComponent = $null
        
        if ($screenToExit) {
            $screenToExit.OnExit()
            if ($screenToExit.PSObject.Methods['Cleanup']) {
                $screenToExit.Cleanup()
            }
        }
        
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.OnResume()
            if ($global:TuiState.CurrentScreen.LastFocusedComponent) {
                Set-ComponentFocus -Component $global:TuiState.CurrentScreen.LastFocusedComponent
            }
        }
        
        Request-TuiRefresh
        Publish-Event -EventName "Screen.Popped" -Data @{ ScreenName = $global:TuiState.CurrentScreen.Name }
        Write-Log -Level Debug -Message "Screen popped successfully"
        return $true
    }
    catch {
        Write-Error "Error popping screen: $($_.Exception.Message)"
        return $false
    }
}

function Show-TuiOverlay {
    <#
    .SYNOPSIS
    Shows an overlay element (like a dialog) on top of the current screen.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [UIElement]$Element
    )
    
    try {
        Write-Log -Level Debug -Message "Showing overlay: $($Element.Name)"
        
        if ($Element.PSObject.Methods['OnInitialize']) {
            $Element.OnInitialize()
        }
        
        $global:TuiState.OverlayStack.Add($Element)
        Request-TuiRefresh
        Write-Log -Level Debug -Message "Overlay shown successfully: $($Element.Name)"
    }
    catch {
        Write-Error "Error showing overlay '$($Element.Name)': $($_.Exception.Message)"
    }
}

function Close-TopTuiOverlay {
    <#
    .SYNOPSIS
    Closes the top overlay element.
    #>
    [CmdletBinding()]
    param()
    
    try {
        if ($global:TuiState.OverlayStack.Count -gt 0) {
            $overlay = $global:TuiState.OverlayStack[-1]
            $global:TuiState.OverlayStack.RemoveAt($global:TuiState.OverlayStack.Count - 1)
            
            if ($overlay.PSObject.Methods['Cleanup']) {
                $overlay.Cleanup()
            }
            
            Request-TuiRefresh
            Write-Log -Level Debug -Message "Overlay closed: $($overlay.Name)"
        }
    }
    catch {
        Write-Error "Error closing overlay: $($_.Exception.Message)"
    }
}

#endregion

#region Focus Management

function Set-ComponentFocus {
    <#
    .SYNOPSIS
    Sets focus to a specific component.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [UIElement]$Component
    )
    
    try {
        if (-not $Component.IsFocusable) {
            Write-Log -Level Warning -Message "Cannot focus non-focusable component: $($Component.Name)"
            return
        }
        
        if ($global:TuiState.FocusedComponent) {
            $global:TuiState.FocusedComponent.OnBlur()
        }
        
        $global:TuiState.FocusedComponent = $Component
        $Component.OnFocus()
        
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.LastFocusedComponent = $Component
        }
        
        Request-TuiRefresh
        Write-Log -Level Debug -Message "Focus set to component: $($Component.Name)"
    }
    catch {
        Write-Error "Error setting focus to component '$($Component.Name)': $($_.Exception.Message)"
    }
}

function Get-FocusedComponent {
    <#
    .SYNOPSIS
    Gets the currently focused component.
    #>
    [CmdletBinding()]
    param()
    
    return $global:TuiState.FocusedComponent
}

#endregion

#region Utility Functions

function Request-TuiRefresh {
    <#
    .SYNOPSIS
    Requests a refresh of the TUI display.
    #>
    [CmdletBinding()]
    param()
    
    $global:TuiState.IsDirty = $true
}

function Show-DebugInfo {
    <#
    .SYNOPSIS
    Shows debug information about the TUI state.
    #>
    [CmdletBinding()]
    param()
    
    try {
        $debugInfo = @"
=== TUI Engine Debug Information ===
Running: $($global:TuiState.Running)
Buffer Size: $($global:TuiState.BufferWidth) x $($global:TuiState.BufferHeight)
Frame Count: $($global:TuiState.RenderStats.FrameCount)
Last Frame Time: $($global:TuiState.RenderStats.LastFrameTime)ms
Average Frame Time: $($global:TuiState.RenderStats.AverageFrameTime)ms
Target FPS: $($global:TuiState.RenderStats.TargetFPS)
Screen Stack Count: $($global:TuiState.ScreenStack.Count)
Overlay Count: $($global:TuiState.OverlayStack.Count)
Current Screen: $($global:TuiState.CurrentScreen?.Name ?? 'None')
Focused Component: $($global:TuiState.FocusedComponent?.Name ?? 'None')
Input Queue Size: $($global:TuiState.InputQueue.Count)
Memory Usage: $([math]::round([GC]::GetTotalMemory($false) / 1MB, 2)) MB
=== End Debug Information ===
"@
        
        Write-Log -Level Info -Message $debugInfo
        
        if (Get-Command Show-AlertDialog -ErrorAction SilentlyContinue) {
            Show-AlertDialog -Title "Debug Information" -Message $debugInfo
        }
    }
    catch {
        Write-Error "Error showing debug info: $($_.Exception.Message)"
    }
}

#endregion

#region Module Exports

Export-ModuleMember -Function `
    Initialize-TuiEngine, Start-TuiLoop, Cleanup-TuiEngine, `
    Push-Screen, Pop-Screen, Show-TuiOverlay, Close-TopTuiOverlay, `
    Set-ComponentFocus, Get-FocusedComponent, Request-TuiRefresh, `
    Render-Frame, Process-TuiInput, Check-ForResize

Export-ModuleMember -Variable TuiState

#endregion