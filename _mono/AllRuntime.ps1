# ==============================================================================
# Axiom-Phoenix v4.0 - All Runtime (Load Last)
# TUI engine, screen management, and main application loop
# ==============================================================================

#region Global State

# Initialize global TUI state
$global:TuiState = @{
    Running = $false
    BufferWidth = 0
    BufferHeight = 0
    CompositorBuffer = $null
    PreviousCompositorBuffer = $null
    ScreenStack = @()  # Simple array instead of Stack
    CurrentScreen = $null
    IsDirty = $true
    FocusedComponent = $null
    CommandPalette = $null
    Services = @{}
    LastRenderTime = [datetime]::Now
    FrameCount = 0
    InputQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]'
    OverlayStack = @()  # Simple array instead of Stack
}

#endregion

#region Engine Management

function Initialize-TuiEngine {
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Initializing TUI Engine..."
        
        # Hide cursor
        [Console]::CursorVisible = $false
        
        # Clear screen
        [Console]::Clear()
        
        # Get initial console size
        $global:TuiState.BufferWidth = [Console]::WindowWidth
        $global:TuiState.BufferHeight = [Console]::WindowHeight
        
        Write-Host "Console size: $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight)" -ForegroundColor Yellow
        
        # Create compositor buffers
        $global:TuiState.CompositorBuffer = [TuiBuffer]::new(
            $global:TuiState.BufferWidth,
            $global:TuiState.BufferHeight,
            "Compositor"
        )
        
        $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new(
            $global:TuiState.BufferWidth,
            $global:TuiState.BufferHeight,
            "PreviousCompositor"
        )
        
        Write-Verbose "TUI Engine initialized with buffer size: $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight)"
    }
    catch {
        Write-Error "Failed to initialize TUI engine: $_"
        throw
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
    param()
    
    try {
        Write-Verbose "Stopping TUI Engine..."
        
        $global:TuiState.Running = $false
        
        # Cleanup current screen
        if ($global:TuiState.CurrentScreen) {
            try {
                $global:TuiState.CurrentScreen.OnExit()
                $global:TuiState.CurrentScreen.Cleanup()
            }
            catch {
                Write-Warning "Error cleaning up current screen: $_"
            }
        }
        
        # Cleanup services
        foreach ($service in $global:TuiState.Services.Values) {
            if ($service -and $service.PSObject.Methods.Match('Cleanup')) {
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
        
        # Resize compositor buffers
        $global:TuiState.CompositorBuffer.Resize($newWidth, $newHeight)
        $global:TuiState.PreviousCompositorBuffer.Resize($newWidth, $newHeight)
        
        # Resize current screen
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.Resize($newWidth, $newHeight)
        }
        
        # Force full redraw
        $global:TuiState.IsDirty = $true
        [Console]::Clear()
    }
    catch {
        Write-Error "Failed to update engine size: $_"
    }
}

#endregion

#region Rendering System

function Invoke-TuiRender {
    [CmdletBinding()]
    param()
    
    try {
        $renderTimer = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Clear compositor buffer
        $global:TuiState.CompositorBuffer.Clear()
        
        Write-Verbose "Starting render frame $($global:TuiState.FrameCount)"
        
        # Render current screen
        if ($global:TuiState.CurrentScreen) {
            try {
                # Render the screen which will update its internal buffer
                $global:TuiState.CurrentScreen.Render()
                
                # Get the screen's buffer
                $screenBuffer = $global:TuiState.CurrentScreen.GetBuffer()
                
                if ($screenBuffer) {
                    # Blend screen buffer into compositor
                    $global:TuiState.CompositorBuffer.BlendBuffer($screenBuffer, 0, 0)
                }
                else {
                    Write-Warning "Screen buffer is null for $($global:TuiState.CurrentScreen.Name)"
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
            $global:TuiState.CompositorBuffer.WriteString(2, 2, $testMsg, [ConsoleColor]::Yellow, [ConsoleColor]::Black)
        }
        
        # Force full redraw on first frame by making previous buffer different
        if ($global:TuiState.FrameCount -eq 0) {
            Write-Host "First frame - initializing previous buffer for differential rendering" -ForegroundColor Green
            # Fill previous buffer with different content to force full redraw
            for ($y = 0; $y -lt $global:TuiState.PreviousCompositorBuffer.Height; $y++) {
                for ($x = 0; $x -lt $global:TuiState.PreviousCompositorBuffer.Width; $x++) {
                    $global:TuiState.PreviousCompositorBuffer.SetCell($x, $y, 
                        [TuiCell]::new('?', [ConsoleColor]::DarkGray, [ConsoleColor]::DarkGray))
                }
            }
        }
        
        # Differential rendering - compare current compositor to previous
        Render-DifferentialBuffer
        
        # Swap buffers for next frame
        $temp = $global:TuiState.PreviousCompositorBuffer
        $global:TuiState.PreviousCompositorBuffer = $global:TuiState.CompositorBuffer
        $global:TuiState.CompositorBuffer = $temp
        
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
        
        $ansiBuilder = [System.Text.StringBuilder]::new()
        $lastBgColor = $null
        $lastFgColor = $null
        $lastBold = $false
        $lastUnderline = $false
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
                    
                    # Apply styling if changed
                    if ($currentCell.BackgroundColor -ne $lastBgColor) {
                        [void]$ansiBuilder.Append([TuiAnsiHelper]::GetBackgroundCode($currentCell.BackgroundColor))
                        $lastBgColor = $currentCell.BackgroundColor
                    }
                    
                    if ($currentCell.ForegroundColor -ne $lastFgColor) {
                        [void]$ansiBuilder.Append([TuiAnsiHelper]::GetForegroundCode($currentCell.ForegroundColor))
                        $lastFgColor = $currentCell.ForegroundColor
                    }
                    
                    if ($currentCell.Bold -ne $lastBold) {
                        [void]$ansiBuilder.Append($(if ($currentCell.Bold) { "`e[1m" } else { "`e[22m" }))
                        $lastBold = $currentCell.Bold
                    }
                    
                    if ($currentCell.Underline -ne $lastUnderline) {
                        [void]$ansiBuilder.Append($(if ($currentCell.Underline) { "`e[4m" } else { "`e[24m" }))
                        $lastUnderline = $currentCell.Underline
                    }
                    
                    # Write character
                    [void]$ansiBuilder.Append($currentCell.Char)
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

#region Input Processing

function Process-TuiInput {
    [CmdletBinding()]
    param()
    
    try {
        if ([Console]::KeyAvailable) {
            $keyInfo = [Console]::ReadKey($true)
            
            # Check command palette first
            if ($global:TuiState.CommandPalette -and $global:TuiState.CommandPalette.Visible) {
                $handled = $global:TuiState.CommandPalette.HandleInput($keyInfo)
                if ($handled) {
                    $global:TuiState.IsDirty = $true
                    return
                }
            }
            
            # Check global hotkeys
            if ($global:TuiState.Services.KeybindingService) {
                try {
                    $action = $global:TuiState.Services.KeybindingService.GetAction($keyInfo)
                    
                    if ($action) {
                        Write-Host "Processing global action: $action" -ForegroundColor Yellow
                        
                        switch ($action) {
                            "app.exit" {
                                Write-Host "Exiting application..." -ForegroundColor Red
                                $global:TuiState.Running = $false
                                return
                            }
                            "app.commandPalette" {
                                Write-Host "Opening command palette..." -ForegroundColor Cyan
                                if ($global:TuiState.CommandPalette) {
                                    $global:TuiState.CommandPalette.Show()
                                    $global:TuiState.IsDirty = $true
                                }
                                return
                            }
                        }
                        
                        # Try to execute via ActionService
                        if ($global:TuiState.Services.ActionService) {
                            try {
                                $global:TuiState.Services.ActionService.ExecuteAction($action)
                                $global:TuiState.IsDirty = $true
                                return
                            }
                            catch {
                                Write-Host "Action execution failed: $_" -ForegroundColor Red
                            }
                        }
                    }
                }
                catch {
                    Write-Host "KeybindingService error: $_" -ForegroundColor Red
                }
            }
            
            # Pass to current screen
            if ($global:TuiState.CurrentScreen) {
                $global:TuiState.CurrentScreen.HandleInput($keyInfo)
                $global:TuiState.IsDirty = $true
            }
        }
    }
    catch {
        Write-Error "Input processing error: $_"
    }
}

#endregion

#region Screen Management

function Push-Screen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Screen]$Screen
    )
    
    try {
        Write-Verbose "Pushing screen: $($Screen.Name)"
        
        # Ensure ScreenStack exists
        if ($null -eq $global:TuiState.ScreenStack) {
            $global:TuiState.ScreenStack = @()
        }
        
        # Exit current screen
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.OnExit()
            $global:TuiState.ScreenStack += $global:TuiState.CurrentScreen
        }
        
        # Initialize and enter new screen
        $global:TuiState.CurrentScreen = $Screen
        
        # Resize screen to match console BEFORE initializing
        $Screen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)
        
        # Now initialize with correct size
        if (-not $Screen._isInitialized) {
            Write-Host "Initializing screen $($Screen.Name) with size $($Screen.Width)x$($Screen.Height)" -ForegroundColor Yellow
            $Screen.Initialize()
            $Screen._isInitialized = $true
        }
        
        $Screen.OnEnter()
        $global:TuiState.IsDirty = $true
    }
    catch {
        Write-Error "Failed to push screen: $_"
        throw
    }
}

function Pop-Screen {
    [CmdletBinding()]
    param()
    
    try {
        # Ensure ScreenStack exists
        if ($null -eq $global:TuiState.ScreenStack) {
            $global:TuiState.ScreenStack = @()
        }
        
        if (@($global:TuiState.ScreenStack).Count -eq 0) {
            Write-Warning "No screens to pop"
            return
        }
        
        Write-Verbose "Popping screen"
        
        # Exit current screen
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.OnExit()
        }
        
        # Resume previous screen
        $previousScreen = $global:TuiState.ScreenStack[-1]
        if (@($global:TuiState.ScreenStack).Count -eq 1) {
            $global:TuiState.ScreenStack = @()
        } else {
            $count = @($global:TuiState.ScreenStack).Count
            $endIndex = $count - 2
            if ($endIndex -ge 0) {
                $global:TuiState.ScreenStack = @($global:TuiState.ScreenStack)[0..$endIndex]
            } else {
                $global:TuiState.ScreenStack = @()
            }
        }
        $global:TuiState.CurrentScreen = $previousScreen
        $previousScreen.OnResume()
        
        $global:TuiState.IsDirty = $true
    }
    catch {
        Write-Error "Failed to pop screen: $_"
        throw
    }
}

function Switch-Screen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Screen]$Screen
    )
    
    try {
        Write-Verbose "Switching to screen: $($Screen.Name)"
        
        # Exit current screen without pushing to stack
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.OnExit()
        }
        
        # Initialize and enter new screen
        $global:TuiState.CurrentScreen = $Screen
        
        # Resize screen to match console
        $Screen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)
        
        if (-not $Screen._isInitialized) {
            $Screen.Initialize()
            $Screen._isInitialized = $true
        }
        
        $Screen.OnEnter()
        $global:TuiState.IsDirty = $true
    }
    catch {
        Write-Error "Failed to switch screen: $_"
        throw
    }
}

#endregion

#region Overlay Management

function Show-TuiOverlay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [UIElement]$Element
    )
    
    try {
        Write-Verbose "Showing overlay: $($Element.Name)"
        
        # Initialize overlay stack if needed
        if (-not $global:TuiState.ContainsKey('OverlayStack')) {
            $global:TuiState.OverlayStack = @()
        }
        
        # Push to overlay stack
        $global:TuiState.OverlayStack += $Element
        
        # Initialize if needed
        if ($Element -and $Element.PSObject.Methods.Match('Initialize') -and -not $Element._isInitialized) {
            $Element.Initialize()
            $Element._isInitialized = $true
        }
        
        # Enter the overlay
        if ($Element -and $Element.PSObject.Methods.Match('OnEnter')) {
            $Element.OnEnter()
        }
        
        $global:TuiState.IsDirty = $true
    }
    catch {
        Write-Error "Failed to show overlay: $_"
        throw
    }
}

function Close-TopTuiOverlay {
    [CmdletBinding()]
    param()
    
    try {
        if (-not $global:TuiState.ContainsKey('OverlayStack') -or @($global:TuiState.OverlayStack).Count -eq 0) {
            Write-Warning "No overlays to close"
            return
        }
        
        Write-Verbose "Closing top overlay"
        
        # Pop from overlay stack
        $overlay = $global:TuiState.OverlayStack[-1]
        if (@($global:TuiState.OverlayStack).Count -eq 1) {
            $global:TuiState.OverlayStack = @()
        } else {
            $count = @($global:TuiState.OverlayStack).Count
            $endIndex = $count - 2
            if ($endIndex -ge 0) {
                $global:TuiState.OverlayStack = @($global:TuiState.OverlayStack)[0..$endIndex]
            } else {
                $global:TuiState.OverlayStack = @()
            }
        }
        
        # Exit the overlay
        if ($overlay -and $overlay.PSObject.Methods.Match('OnExit')) {
            $overlay.OnExit()
        }
        
        # Cleanup if disposable
        if ($overlay -and $overlay.PSObject.Methods.Match('Cleanup')) {
            $overlay.Cleanup()
        }
        
        $global:TuiState.IsDirty = $true
    }
    catch {
        Write-Error "Failed to close overlay: $_"
        throw
    }
}

#endregion

#region Error Handling

function Invoke-PanicHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Error
    )
    
    try {
        Write-Host "`n`n=== AXIOM-PHOENIX PANIC HANDLER ===" -ForegroundColor Red
        Write-Host "A critical error has occurred!" -ForegroundColor Red
        Write-Host ""
        
        # Error details
        Write-Host "Error Message:" -ForegroundColor Yellow
        Write-Host "  $($Error.Exception.Message)" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Error Type:" -ForegroundColor Yellow
        Write-Host "  $($Error.Exception.GetType().FullName)" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Stack Trace:" -ForegroundColor Yellow
        $Error.ScriptStackTrace -split "`n" | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
        Write-Host ""
        
        # System info
        Write-Host "System Information:" -ForegroundColor Yellow
        Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
        Write-Host "  OS: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor Gray
        Write-Host "  Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        Write-Host ""
        
        # Crash report location
        $crashReportPath = Join-Path $env:TEMP "axiom-phoenix-crash-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        
        $crashReport = @"
AXIOM-PHOENIX CRASH REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

ERROR DETAILS:
$($Error | Out-String)

SYSTEM INFORMATION:
PowerShell Version: $($PSVersionTable.PSVersion)
OS Version: $([System.Environment]::OSVersion.VersionString)
CLR Version: $($PSVersionTable.CLRVersion)
Host: $($Host.Name)

GLOBAL STATE:
$($global:TuiState | ConvertTo-Json -Depth 3)
"@
        
        $crashReport | Out-File -FilePath $crashReportPath -Force
        
        Write-Host "Crash report saved to:" -ForegroundColor Yellow
        Write-Host "  $crashReportPath" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "Press any key to exit..." -ForegroundColor White
        [Console]::ReadKey($true) | Out-Null
    }
    catch {
        Write-Host "FATAL: Panic handler failed!" -ForegroundColor Magenta
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    finally {
        # Try to restore console
        try {
            [Console]::CursorVisible = $true
            [Console]::Clear()
        }
        catch {}
        
        # Exit
        exit 1
    }
}

#endregion

#region Application Entry

function Start-AxiomPhoenix {
    [CmdletBinding()]
    param(
        [ServiceContainer]$ServiceContainer,
        [Screen]$InitialScreen
    )
    
    try {
        Write-Host "Starting Axiom-Phoenix application..." -ForegroundColor Cyan
        
        # Store services
        $global:TuiState.Services = @{
            ServiceContainer = $ServiceContainer
        }
        
        # Extract key services for quick access
        $serviceNames = @(
            'ActionService', 'KeybindingService', 'NavigationService', 
            'DataManager', 'ThemeManager', 'EventManager', 'Logger'
        )
        
        foreach ($serviceName in $serviceNames) {
            try {
                $service = $ServiceContainer.GetService($serviceName)
                if ($service) {
                    $global:TuiState.Services[$serviceName] = $service
                    Write-Host "  - $serviceName loaded" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "Failed to get service '$serviceName': $_"
            }
        }
        
        # Initialize engine FIRST before creating UI components
        Initialize-TuiEngine
        
        # Create command palette after engine is initialized
        $actionService = $ServiceContainer.GetService("ActionService")
        if ($actionService) {
            Write-Host "Creating Command Palette..." -ForegroundColor Yellow
            $global:TuiState.CommandPalette = [CommandPalette]::new("GlobalCommandPalette", $actionService)
            # Center the command palette
            $global:TuiState.CommandPalette.X = [Math]::Floor(($global:TuiState.BufferWidth - $global:TuiState.CommandPalette.Width) / 2)
            $global:TuiState.CommandPalette.Y = [Math]::Floor(($global:TuiState.BufferHeight - $global:TuiState.CommandPalette.Height) / 2)
            Write-Host "  - Command Palette created" -ForegroundColor Green
        }
        
        # Verify ScreenStack still exists after engine init
        if ($null -eq $global:TuiState.ScreenStack) {
            $global:TuiState.ScreenStack = @()
        }
        
        # Set initial screen
        if ($InitialScreen) {
            Write-Host "Loading initial screen: $($InitialScreen.Name)" -ForegroundColor Yellow
            Push-Screen -Screen $InitialScreen
            Write-Host "  - Screen loaded successfully" -ForegroundColor Green
        }
        else {
            Write-Warning "No initial screen provided"
        }
        
        Write-Host "" # Empty line
        Write-Host "Application started successfully!" -ForegroundColor Green
        Write-Host "Press Ctrl+P for Command Palette, Ctrl+Q to exit" -ForegroundColor Cyan
        Write-Host "" # Empty line
        
        # Force initial render
        $global:TuiState.IsDirty = $true
        
        # Start main loop
        Start-TuiEngine
    }
    catch {
        Write-Error "Application startup failed: $_"
        Write-Error "Error occurred at: $($_.InvocationInfo.ScriptLineNumber) in $($_.InvocationInfo.ScriptName)"
        Write-Error "Statement: $($_.InvocationInfo.Line)"
        Invoke-PanicHandler $_
    }
    finally {
        Stop-TuiEngine
    }
}

#endregion
