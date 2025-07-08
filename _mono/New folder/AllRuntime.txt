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

# $global:TuiState is the central, volatile state store for the running
# application. It holds references to the current screen, buffers, services,
# and engine control flags. It is initialized here and populated by
# Start-AxiomPhoenix.
$global:TuiState = @{
    Running = $false
    BufferWidth = 0
    BufferHeight = 0
    CompositorBuffer = $null
    PreviousCompositorBuffer = $null
    CurrentScreen = $null
    IsDirty = $true
    FocusedComponent = $null
    CommandPalette = $null
    Services = @{}
    ServiceContainer = $null
    LastRenderTime = [datetime]::Now
    FrameCount = 0
    OverlayStack = [System.Collections.Generic.List[UIElement]]::new()
}

# ==============================================================================
# FUNCTION: Invoke-WithErrorHandling (Internal Utility)
#
# PURPOSE:
#   A wrapper to execute a scriptblock within a try/catch block, centralizing
#   the logging of non-fatal errors that occur during UI operations.
#
# KEY LOGIC:
#   - Executes the provided ScriptBlock.
#   - If an exception is caught, it logs a structured error message using
#     Write-Log, including the component, context, and error details.
#   - It re-throws the exception so the original calling context can handle it
#     further if necessary.
# ==============================================================================
function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Component,
        [Parameter(Mandatory)][string]$Context,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [hashtable]$AdditionalData = @{}
    )
    try {
        & $ScriptBlock
    }
    catch {
        $errorDetails = @{ Component = $Component; Context = $Context; ErrorMessage = $_.Exception.Message; StackTrace = $_.ScriptStackTrace }
        foreach ($key in $AdditionalData.Keys) { $errorDetails[$key] = $AdditionalData[$key] }
        Write-Log -Level Error -Message "Error in $Component during $Context: $($_.Exception.Message)" -Data $errorDetails
        throw
    }
}

#endregion
#<!-- END_PAGE: ART.001 -->

#<!-- PAGE: ART.002 - Engine Management -->
#region Engine Management

# ==============================================================================
# FUNCTION: Initialize-TuiEngine
#
# PURPOSE:
#   Prepares the console host for TUI rendering. This is one of the first
#   functions called when the application starts.
#
# KEY LOGIC:
#   - Sets the console output encoding to UTF-8 to support special characters.
#   - Hides the cursor and sets the window title.
#   - Calls `Update-TuiEngineSize` to get the initial console dimensions.
#   - Creates the main `CompositorBuffer` and `PreviousCompositorBuffer` based
#     on the console size.
# ==============================================================================
function Initialize-TuiEngine {
    [CmdletBinding()]
    param()
    try {
        Write-Log -Level Info -Message "Initializing TUI engine..."
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::CursorVisible = $false
        $Host.UI.RawUI.WindowTitle = "Axiom-Phoenix v4.0"
        Clear-Host
        [Console]::SetCursorPosition(0, 0)
        
        Update-TuiEngineSize
        
        $width = $global:TuiState.BufferWidth
        $height = $global:TuiState.BufferHeight
        $global:TuiState.CompositorBuffer = [TuiBuffer]::new($width, $height, "Compositor")
        $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($width, $height, "PreviousCompositor")
        
        $bgColor = Get-ThemeColor -ColorName "Background" -DefaultColor "#000000"
        $fillCell = [TuiCell]::new(' ', $bgColor, $bgColor)
        $global:TuiState.CompositorBuffer.Clear($fillCell)
        $global:TuiState.PreviousCompositorBuffer.Clear($fillCell)
        
        Write-Log -Level Info -Message "TUI engine initialized. Buffer size: ${width}x${height}"
    }
    catch {
        Invoke-PanicHandler $_
    }
}

# ==============================================================================
# FUNCTION: Start-TuiEngine
#
# PURPOSE:
#   The main application loop. It runs continuously until the application is
#   instructed to exit.
#
# KEY LOGIC:
#   1. Checks for console window resize events and calls `Update-TuiEngineSize`
#      if detected.
#   2. Calls `Process-TuiInput` to handle any pending keyboard events.
#   3. Calls `Invoke-TuiRender` to draw the current state of the UI to the screen.
#   4. Implements frame-rate throttling by sleeping for a calculated duration
#      at the end of each loop to prevent high CPU usage and ensure a stable
#      refresh rate (typically targeting ~30 FPS).
# ==============================================================================
function Start-TuiEngine {
    [CmdletBinding()]
    param()
    try {
        Write-Log -Level Info -Message "Starting TUI Engine main loop..."
        $global:TuiState.Running = $true
        $frameTimer = [System.Diagnostics.Stopwatch]::new()
        $targetFrameTimeMs = 33 # Target ~30 FPS
        
        while ($global:TuiState.Running) {
            $frameTimer.Restart()
            
            if ([Console]::WindowWidth -ne $global:TuiState.BufferWidth -or [Console]::WindowHeight -ne $global:TuiState.BufferHeight) {
                Update-TuiEngineSize
            }
            
            Process-TuiInput
            
            # Rendering is now driven by component state (_needs_redraw)
            Invoke-TuiRender
            
            $frameTimer.Stop()
            $elapsedMs = $frameTimer.ElapsedMilliseconds
            if ($elapsedMs -lt $targetFrameTimeMs) {
                Start-Sleep -Milliseconds ($targetFrameTimeMs - $elapsedMs)
            }
            $global:TuiState.FrameCount++
        }
    }
    catch {
        Invoke-PanicHandler $_
    }
    finally {
        Stop-TuiEngine
    }
}

# ==============================================================================
# FUNCTION: Stop-TuiEngine
#
# PURPOSE:
#   Gracefully shuts down the TUI engine and restores the console to its
#   original state.
#
# KEY LOGIC:
#   - Sets the global `Running` flag to false to terminate the main loop.
#   - Iterates through all registered services and calls their `Cleanup` method
#     if it exists. This ensures resources like file handles (Logger) and
#     event subscriptions are released.
#   - Makes the cursor visible again and clears the screen.
# ==============================================================================
function Stop-TuiEngine {
    [CmdletBinding()]
    param()
    try {
        Write-Log -Level Info -Message "Stopping TUI Engine..."
        $global:TuiState.Running = $false
        
        $global:TuiState.ServiceContainer?.Cleanup()
        
        [Console]::CursorVisible = $true
        [Console]::Clear()
        [Console]::SetCursorPosition(0, 0)
        Write-Host "Axiom-Phoenix session terminated."
    }
    catch {
        # Fallback to console write if logger fails during shutdown
        Write-Error "Error stopping TUI engine: $_"
    }
}

# ==============================================================================
# FUNCTION: Update-TuiEngineSize
#
# PURPOSE:
#   Handles console window resize events.
#
# KEY LOGIC:
#   - Reads the new dimensions from `[Console]::WindowWidth/Height`.
#   - Updates the corresponding values in `$global:TuiState`.
#   - Calls the `Resize` method on the main compositor buffers and the current
#     screen, which propagates the resize down the UI component tree.
#   - Forces a full redraw of the UI.
# ==============================================================================
function Update-TuiEngineSize {
    [CmdletBinding()]
    param()
    try {
        $newWidth = [Console]::WindowWidth
        $newHeight = [Console]::WindowHeight
        Write-Log -Level Debug -Message "Console resized to ${newWidth}x${newHeight}"
        
        $global:TuiState.BufferWidth = $newWidth
        $global:TuiState.BufferHeight = $newHeight
        
        $global:TuiState.CompositorBuffer?.Resize($newWidth, $newHeight)
        $global:TuiState.PreviousCompositorBuffer?.Resize($newWidth, $newHeight)
        $global:TuiState.CurrentScreen?.Resize($newWidth, $newHeight)
        
        $global:TuiState.IsDirty = $true
        if ($global:TuiState.CompositorBuffer) { [Console]::Clear() }
    }
    catch {
        Write-Log -Level Error -Message "Failed to update engine size: $($_.Exception.Message)" -Data $_
    }
}

#endregion
#<!-- END_PAGE: ART.002 -->

#<!-- PAGE: ART.003 - Rendering System -->
#region Rendering System

# ==============================================================================
# FUNCTION: Invoke-TuiRender
#
# PURPOSE:
#   The main rendering orchestrator, called once per frame from the engine loop.
#
# KEY LOGIC:
#   1. Clears the main `CompositorBuffer`.
#   2. Renders the `$global:TuiState.CurrentScreen` into its own buffer.
#   3. Blends the current screen's buffer onto the `CompositorBuffer`.
#   4. Renders any active overlays (like dialogs from the `OverlayStack`) on top,
#      blending them onto the `CompositorBuffer` in order.
#   5. Calls `Render-DifferentialBuffer` to perform the optimized write to the
#      console.
#   6. Clones the `CompositorBuffer` to `PreviousCompositorBuffer` in preparation
#      for the next frame's differential comparison.
# ==============================================================================
function Invoke-TuiRender {
    [CmdletBinding()]
    param()
    try {
        if (-not $global:TuiState.CompositorBuffer) { return }
        
        $bgColor = Get-ThemeColor -ColorName "Background" -DefaultColor "#000000"
        $global:TuiState.CompositorBuffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        $currentScreenToRender = $global:TuiState.CurrentScreen
        if ($currentScreenToRender) {
            $currentScreenToRender.Render()
            $screenBuffer = $currentScreenToRender.GetBuffer()
            if ($screenBuffer) {
                $global:TuiState.CompositorBuffer.BlendBuffer($screenBuffer, 0, 0)
            }
        }
        
        if ($global:TuiState.OverlayStack) {
            foreach ($overlay in $global:TuiState.OverlayStack) {
                if ($overlay -and $overlay.Visible) {
                    $overlay.Render()
                    $overlayBuffer = $overlay.GetBuffer()
                    if ($overlayBuffer) {
                        $global:TuiState.CompositorBuffer.BlendBuffer($overlayBuffer, $overlay.X, $overlay.Y)
                    }
                }
            }
        }
        
        Render-DifferentialBuffer
        
        $global:TuiState.PreviousCompositorBuffer = $global:TuiState.CompositorBuffer.Clone()
        
    }
    catch {
        Write-Log -Level Error -Message "Render error in Invoke-TuiRender: $($_.Exception.Message)" -Data $_
        # Do not re-throw from render loop to avoid crashing the app
    }
}

# ==============================================================================
# FUNCTION: Render-DifferentialBuffer
#
# PURPOSE:
#   The core of the rendering optimization. It compares the current frame's
#   compositor buffer with the previous frame's buffer and only writes the
#   changed cells to the terminal.
#
# KEY LOGIC:
#   - Iterates through every cell (X, Y) of the `CompositorBuffer`.
#   - Compares each `TuiCell` with the cell at the same position in the
#     `PreviousCompositorBuffer` using the cell's `DiffersFrom()` method.
#   - If a cell has changed, it builds up an ANSI escape code string to move the
#     cursor to that position and print the new cell's character with its new
#     styling.
#   - All changes are aggregated into a single `StringBuilder` and written to
#     the console in one operation to minimize screen flicker.
# ==============================================================================
function Render-DifferentialBuffer {
    [CmdletBinding()]
    param()
    try {
        $current = $global:TuiState.CompositorBuffer
        $previous = $global:TuiState.PreviousCompositorBuffer
        if (-not $current -or -not $previous) { return }
        
        $ansiBuilder = [System.Text.StringBuilder]::new()
        $lastX = -1; $lastY = -1
        
        for ($y = 0; $y -lt $current.Height; $y++) {
            for ($x = 0; $x -lt $current.Width; $x++) {
                $currentCell = $current.GetCell($x, $y)
                $previousCell = $previous.GetCell($x, $y)
                
                if ($currentCell.DiffersFrom($previousCell)) {
                    if ($lastY -ne $y -or $lastX -ne ($x - 1)) {
                        [void]$ansiBuilder.Append("`e[$($y + 1);$($x + 1)H")
                    }
                    [void]$ansiBuilder.Append($currentCell.ToAnsiString())
                    $lastX = $x; $lastY = $y
                }
            }
        }
        
        if ($ansiBuilder.Length -gt 0) {
            [void]$ansiBuilder.Append("`e[0m")
            [Console]::Write($ansiBuilder.ToString())
        }
    }
    catch {
        Write-Log -Level Error -Message "Differential rendering error: $($_.Exception.Message)" -Data $_
    }
}

#endregion
#<!-- END_PAGE: ART.003 -->

#<!-- PAGE: ART.004 - Input Processing -->
#region Input Processing

# ==============================================================================
# FUNCTION: Process-TuiInput
#
# PURPOSE:
#   The central input handling routine, called once per frame from the engine
#   loop. It determines which component should receive the keyboard input based
#   on a strict order of precedence.
#
# KEY LOGIC:
#   The order of precedence is:
#   1. **Overlays**: If an overlay (dialog) is active, it gets the first chance.
#   2. **Focused Component**: The component currently focused by `FocusManager`.
#   3. **Global Keybindings**: `KeybindingService` checks for global hotkeys.
#   4. **Current Screen**: The top-level screen gets a final chance.
#
#   If any layer in this chain handles the input (returns $true), processing stops.
# ==============================================================================
function Process-TuiInput {
    [CmdletBinding()]
    param()
    try {
        while ([Console]::KeyAvailable) {
            $keyInfo = [Console]::ReadKey($true)
            
            # 1. Overlay gets highest priority
            if ($global:TuiState.OverlayStack.Count -gt 0) {
                $topOverlay = $global:TuiState.OverlayStack[-1]
                if ($topOverlay?.HandleInput($keyInfo)) { $global:TuiState.IsDirty = $true; continue }
            }
            
            # 2. Focused component is next
            $focusManager = $global:TuiState.Services.FocusManager
            if ($focusManager.FocusedComponent?.HandleInput($keyInfo)) { $global:TuiState.IsDirty = $true; continue }

            # 3. Global Keybindings
            $keybindingService = $global:TuiState.Services.KeybindingService
            if ($keybindingService) {
                $action = $keybindingService.GetAction($keyInfo)
                if ($action) {
                    $global:TuiState.Services.ActionService?.ExecuteAction($action, @{})
                    $global:TuiState.IsDirty = $true
                    continue
                }
            }
            
            # 4. Current Screen gets last chance
            if ($global:TuiState.CurrentScreen?.HandleInput($keyInfo)) {
                $global:TuiState.IsDirty = $true
                continue
            }
        }
    }
    catch {
        Write-Log -Level Error -Message "Input processing error: $($_.Exception.Message)" -Data $_
    }
}

#endregion
#<!-- END_PAGE: ART.004 -->

#<!-- PAGE: ART.005 - Screen Management -->
#region Overlay Management
# DEPRECATED - Logic is now in DialogManager (ASE.009)
#endregion
#<!-- END_PAGE: ART.005 -->

#<!-- PAGE: ART.006 - Error Handling -->
#region Panic Handler

# ==============================================================================
# FUNCTION: Invoke-PanicHandler
#
# PURPOSE:
#   A last-resort error handler for unrecoverable exceptions that occur in the
#   main engine loop. Its job is to safely terminate the TUI, restore the
#   console, and display a helpful error report to the user.
#
# KEY LOGIC:
#   - Restores the console to a usable state (visible cursor, reset color).
#   - Prints a formatted error message including the exception message, type,
#     and stack trace.
#   - Gathers system information and a snapshot of the TUI state.
#   - Saves a detailed crash report to a log file in the user's temp directory.
#   - Halts execution and exits the application.
# ==============================================================================
function Invoke-PanicHandler {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$ErrorRecord)
    
    try { [Console]::ResetColor(); [Console]::CursorVisible = $true; Clear-Host } catch { }
    
    Write-Host "`nPANIC: An unrecoverable error has occurred:`n" -ForegroundColor Red
    Write-Host "  Message: $($ErrorRecord.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  Type:    $($ErrorRecord.Exception.GetType().FullName)" -ForegroundColor Yellow
    Write-Host "`nSTACK TRACE:`n$($ErrorRecord.ScriptStackTrace)" -ForegroundColor DarkGray
    
    $crashDir = Join-Path $env:TEMP "AxiomPhoenix\Crashes"
    if (-not (Test-Path $crashDir)) { New-Item -ItemType Directory -Path $crashDir -Force | Out-Null }
    $crashFile = Join-Path $crashDir "crash_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    try {
        $ErrorRecord | ConvertTo-Json -Depth 5 | Out-File -FilePath $crashFile -Encoding UTF8
        Write-Host "`nCrash report saved to: $crashFile" -ForegroundColor Green
    } catch {
        Write-Host "`nFailed to save crash report: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Stop-TuiEngine
    exit 1
}

# ==============================================================================
# FUNCTION: Start-AxiomPhoenix
#
# PURPOSE:
#   The main entry point for the entire application. It wires together all the
#   services and starts the TUI engine.
#
# KEY LOGIC:
#   - Takes the pre-configured `ServiceContainer` as a parameter.
#   - Populates the `$global:TuiState.Services` hashtable by resolving all
#     necessary services from the container. This makes them easily accessible
#     to the rest of the framework.
#   - Initializes the TUI engine via `Initialize-TuiEngine`.
#   - Uses the `NavigationService` to navigate to the provided initial screen.
#   - Calls `Start-TuiEngine` to begin the main application loop.
# ==============================================================================
function Start-AxiomPhoenix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ServiceContainer]$ServiceContainer,
        [Parameter(Mandatory)][Screen]$InitialScreen
    )
    
    try {
        $global:TuiState.ServiceContainer = $ServiceContainer
        $global:TuiState.Services = @{}
        $serviceNames = @('Logger', 'EventManager', 'ThemeManager', 'DataManager', 'ActionService', 'KeybindingService', 'NavigationService', 'FocusManager', 'DialogManager')
        foreach ($serviceName in $serviceNames) {
            try { $global:TuiState.Services[$serviceName] = $ServiceContainer.GetService($serviceName) }
            catch { Write-Log -Level Warning -Message "Failed to get required service '$serviceName': $($_.Exception.Message)" }
        }
        
        Initialize-TuiEngine
        
        $global:TuiState.Services.NavigationService.NavigateTo($InitialScreen)
        
        Start-TuiEngine
    }
    catch {
        Invoke-PanicHandler $_
    }
    finally {
        Stop-TuiEngine
    }
}

#endregion
#<!-- END_PAGE: ART.006 -->