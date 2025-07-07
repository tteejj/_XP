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
    BufferWidth = 0
    BufferHeight = 0
    CompositorBuffer = $null
    PreviousCompositorBuffer = $null
    ScreenStack = [System.Collections.Generic.Stack[Screen]]::new() # CHANGED TO GENERIC STACK
    CurrentScreen = $null
    IsDirty = $true
    FocusedComponent = $null
    CommandPalette = $null
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
            $logger.Log("Debug", "Error details: $($errorDetails | ConvertTo-Json -Compress)")
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
    param()
    
    try {
        Write-Verbose "Starting TUI Engine main loop..."
        
        $global:TuiState.Running = $true
        $frameTimer = [System.Diagnostics.Stopwatch]::new()
        
        while ($global:TuiState.Running) {
            $frameTimer.Restart()
            
            # Check for resize
            if ([Console]::WindowWidth -ne $global:TuiState.BufferWidth -or 
                [Console]::WindowHeight -ne $global:TuiState.BufferHeight) {
                Update-TuiEngineSize
            }
            
            # Process input
            Process-TuiInput
            
            # Render if dirty
            if ($global:TuiState.IsDirty) {
                Invoke-TuiRender
                $global:TuiState.IsDirty = $false
            }
            
            # Frame timing (target 60 FPS)
            $frameTimer.Stop()
            $frameTime = $frameTimer.ElapsedMilliseconds
            if ($frameTime -lt 16) {
                Start-Sleep -Milliseconds (16 - $frameTime)
            }
            
            $global:TuiState.FrameCount++
        }
        
        Write-Verbose "TUI Engine stopped after $($global:TuiState.FrameCount) frames"
    }
    catch {
        Write-Error "TUI Engine error: $_"
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
        Write-Verbose "Stopping TUI Engine..."
        
        $global:TuiState.Running = $false
        
        # Cleanup current screen via NavigationService
        $navService = $global:TuiState.Services.NavigationService
        if ($navService -and $navService.CurrentScreen) {
            try {
                $navService.CurrentScreen.OnExit()
                $navService.CurrentScreen.Cleanup()
            }
            catch {
                Write-Warning "Error cleaning up current screen: $_"
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
                    Write-Warning "Error cleaning up service: $_"
                }
            }
        }
        
        # Restore console
        [Console]::CursorVisible = $true
        [Console]::Clear()
        [Console]::SetCursorPosition(0, 0)
        
        Write-Verbose "TUI Engine stopped and cleaned up"
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
        
        Write-Verbose "Console resized from $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight) to ${newWidth}x${newHeight}"
        
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
            Write-Warning "Compositor buffer is null, skipping render"
            return
        }
        
        # Clear compositor buffer
        $global:TuiState.CompositorBuffer.Clear()
        
        Write-Verbose "Starting render frame $($global:TuiState.FrameCount)"
        
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
                    Write-Warning "Screen buffer is null for $($currentScreenToRender.Name)"
                }
            }
            catch {
                Write-Error "Error rendering screen: $_"
                throw
            }
            
            # Render command palette if visible
            if ($global:TuiState.CommandPalette -and $global:TuiState.CommandPalette.Visible) {
                try {
                    $global:TuiState.CommandPalette.Render()
                    $paletteBuffer = $global:TuiState.CommandPalette.GetBuffer()
                    if ($paletteBuffer) {
                        # Command palette position was set during initialization
                        $global:TuiState.CompositorBuffer.BlendBuffer($paletteBuffer, 
                            $global:TuiState.CommandPalette.X,
                            $global:TuiState.CommandPalette.Y
                        )
                    }
                }
                catch {
                    Write-Warning "Error rendering command palette: $_"
                }
            }
            
            # Render overlays
            if ($global:TuiState.ContainsKey('OverlayStack') -and $global:TuiState.OverlayStack -and @($global:TuiState.OverlayStack).Count -gt 0) {
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
        }
        
        # Debug: Add a test message to see if rendering is working
        if ($global:TuiState.FrameCount -eq 0) {
            $testMsg = "RENDERING IS WORKING - Frame: $($global:TuiState.FrameCount)"
            $global:TuiState.CompositorBuffer.WriteString(2, 2, $testMsg, @{ FG = "#FFFF00"; BG = "#000000" })
        }
        
        # Force full redraw on first frame by making previous buffer different
        if ($global:TuiState.FrameCount -eq 0) {
            Write-Host "First frame - initializing previous buffer for differential rendering" -ForegroundColor Green
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
        # Create proper copies to avoid reference issues
        $tempBuffer = [TuiBuffer]::new($global:TuiState.CompositorBuffer.Width, $global:TuiState.CompositorBuffer.Height, "TempBuffer")
        
        # Copy current compositor to temp
        for ($y = 0; $y -lt $global:TuiState.CompositorBuffer.Height; $y++) {
            for ($x = 0; $x -lt $global:TuiState.CompositorBuffer.Width; $x++) {
                $cell = $global:TuiState.CompositorBuffer.GetCell($x, $y)
                $tempBuffer.SetCell($x, $y, [TuiCell]::new($cell))
            }
        }
        
        # Clear compositor for next frame
        $bgColor = Get-ThemeColor -ColorName "Background" -DefaultColor "#000000"
        $global:TuiState.CompositorBuffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Update previous buffer with what was just rendered
        $global:TuiState.PreviousCompositorBuffer = $tempBuffer
        
        $renderTimer.Stop()
        
        if ($renderTimer.ElapsedMilliseconds -gt 16) {
            Write-Verbose "Slow frame: $($renderTimer.ElapsedMilliseconds)ms"
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
            Write-Warning "Compositor buffers not initialized, skipping differential render"
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
                    
                    # Copy to previous buffer
                    $previous.SetCell($x, $y, [TuiCell]::new($currentCell))
                }
            }
        }
        
        # Log changes on first few frames
        if ($global:TuiState.FrameCount -lt 5) {
            Write-Host "Frame $($global:TuiState.FrameCount): $changeCount cells changed" -ForegroundColor Cyan
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

function Process-TuiInput {
    [CmdletBinding()]
    param()
    
    try {
        if ([Console]::KeyAvailable) {
            $keyInfo = [Console]::ReadKey($true)
            
            # If there's an active overlay (like a dialog), give it priority
            if ($global:TuiState.OverlayStack.Count -gt 0) {
                $topOverlay = $global:TuiState.OverlayStack[-1]
                if ($topOverlay -and $topOverlay.Visible) {
                    if ($topOverlay.HandleInput($keyInfo)) {
                        $global:TuiState.IsDirty = $true
                        return
                    }
                }
            }
            
            # Check command palette if visible
            if ($global:TuiState.CommandPalette -and $global:TuiState.CommandPalette.Visible) {
                if ($global:TuiState.CommandPalette.HandleInput($keyInfo)) {
                    $global:TuiState.IsDirty = $true
                    return
                }
            }

            # Give the currently focused component a chance to handle the input first
            $focusManager = $global:TuiState.Services.FocusManager
            if ($focusManager -and $focusManager.FocusedComponent) {
                if ($focusManager.FocusedComponent.HandleInput($keyInfo)) {
                    $global:TuiState.IsDirty = $true
                    return
                }
            }

            # Check global hotkeys via KeybindingService (including Ctrl+P and Tab)
            if ($global:TuiState.Services.KeybindingService) {
                $action = $global:TuiState.Services.KeybindingService.GetAction($keyInfo)
                if ($action) {
                    # Handle framework-level actions that need special processing
                    if ($action -eq "app.commandPalette") {
                        if ($global:TuiState.CommandPalette) {
                            $global:TuiState.CommandPalette.Show()
                            $global:TuiState.IsDirty = $true
                            return
                        }
                    }
                    elseif ($action -eq "navigation.nextComponent" -or $action -eq "navigation.previousComponent") {
                        if ($focusManager) {
                            $reverse = ($action -eq "navigation.previousComponent")
                            $focusManager.MoveFocus($reverse)
                            $global:TuiState.IsDirty = $true
                            return
                        }
                    }
                    else {
                        # Execute other actions via ActionService
                        if ($global:TuiState.Services.ActionService) {
                            try {
                                $global:TuiState.Services.ActionService.ExecuteAction($action)
                                $global:TuiState.IsDirty = $true
                                return
                            }
                            catch {
                                Write-Log -Level Warning -Message "Failed to execute action '$action' via keybinding: $($_.Exception.Message)" -Data $_
                            }
                        }
                    }
                }
            }
            
            # Finally, give the current screen a chance to handle the input
            $navService = $global:TuiState.Services.NavigationService
            if ($navService -and $navService.CurrentScreen -and $navService.CurrentScreen.HandleInput($keyInfo)) {
                $global:TuiState.IsDirty = $true
                return
            }
        }
    }
    catch {
        Write-Error "Input processing error: $_"
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
        $crashReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $crashFile -Encoding UTF8
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
            'DataManager', 'ThemeManager', 'EventManager', 'Logger', 'FocusManager', 'DialogManager' # Add new services
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
        
        # Create command palette if available
        $actionService = $global:TuiState.Services.ActionService
        if ($actionService) {
            $global:TuiState.CommandPalette = [CommandPalette]::new("GlobalCommandPalette", $actionService)
            $global:TuiState.CommandPalette.RefreshActions()
        }
        
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
