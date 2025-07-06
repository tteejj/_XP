# ==============================================================================
# Axiom-Phoenix v4.0 - Runtime Components
# Core engine, screen manager, and application runtime
# ==============================================================================

#region Global State

$global:TuiState = @{
    Running = $false
    BufferWidth = 0
    BufferHeight = 0
    CompositorBuffer = $null
    PreviousCompositorBuffer = $null
    ScreenStack = [System.Collections.Stack]::new()
    CurrentScreen = $null
    IsDirty = $true
    FocusedComponent = $null
    LastWindowWidth = 0
    LastWindowHeight = 0
    CommandPalette = $null
    Services = @{}
}

#endregion

#region Application Entry Point

function Start-AxiomPhoenix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ServiceContainer]$ServiceContainer
    )
    
    try {
        # Store service container in global state
        $global:TuiState.Services = $ServiceContainer
        
        # Register navigation actions
        $actionService = $ServiceContainer.GetService("ActionService")
        if ($actionService) {
            $actionService.RegisterAction(
                "Navigation:Dashboard",
                "Go to Dashboard",
                { Push-Screen -Screen ([DashboardScreen]::new($ServiceContainer)) },
                "Navigation",
                $true
            )
        }
        
        # Initialize engine
        Initialize-TuiEngine
        
        # Create command palette
        $global:TuiState.CommandPalette = [CommandPalette]::new($actionService)
        
        # Create and show dashboard
        $dashboard = [DashboardScreen]::new($ServiceContainer)
        Push-Screen -Screen $dashboard
        
        # Start main loop
        Start-TuiEngine
    }
    catch {
        Write-Error "Application error: $($_.Exception.Message)"
        throw
    }
    finally {
        Stop-TuiEngine
        if ($ServiceContainer) {
            $ServiceContainer.Cleanup()
        }
        Write-Host "Axiom-Phoenix stopped." -ForegroundColor Gray
    }
}

#endregion

#region TUI Main Loop and Rendering

function Start-TuiEngine {
    [CmdletBinding()]
    param()
    
    $global:TuiState.Running = $true
    
    # Main loop with panic handler
    while ($global:TuiState.Running) {
        try {
            # Check for window resize
            if ([Console]::WindowWidth -ne $global:TuiState.LastWindowWidth -or
                [Console]::WindowHeight -ne $global:TuiState.LastWindowHeight) {
                Handle-WindowResize
            }
            
            # Process input
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                Process-KeyInput -Key $key
            }
            
            # Render if dirty
            if ($global:TuiState.IsDirty) {
                Render-Frame
                $global:TuiState.IsDirty = $false
            }
            
            # Small delay to prevent CPU spinning
            [System.Threading.Thread]::Sleep(10)
        }
        catch {
            # Panic handler
            Invoke-PanicHandler -Exception $_
            break
        }
    }
}

function Stop-TuiEngine {
    [CmdletBinding()]
    param()
    
    $global:TuiState.Running = $false
    [Console]::CursorVisible = $true
    [Console]::TreatControlCAsInput = $false
    [Console]::Clear()
}

function Render-Frame {
    [CmdletBinding()]
    param()
    
    # Clear compositor buffer
    $global:TuiState.CompositorBuffer.Clear()
    
    # Render current screen
    if ($global:TuiState.CurrentScreen) {
        $global:TuiState.CurrentScreen.Render($global:TuiState.CompositorBuffer)
    }
    
    # Render command palette overlay (higher Z-index)
    if ($global:TuiState.CommandPalette -and $global:TuiState.CommandPalette.Visible) {
        $global:TuiState.CommandPalette.Render()
        if ($global:TuiState.CommandPalette._private_buffer) {
            # Blend with Z-index priority
            $paletteX = $global:TuiState.CommandPalette.X
            $paletteY = $global:TuiState.CommandPalette.Y
            $paletteBuffer = $global:TuiState.CommandPalette._private_buffer
            
            for ($y = 0; $y -lt $paletteBuffer.Height; $y++) {
                for ($x = 0; $x -lt $paletteBuffer.Width; $x++) {
                    $targetX = $paletteX + $x
                    $targetY = $paletteY + $y
                    if ($targetX -ge 0 -and $targetX -lt $global:TuiState.CompositorBuffer.Width -and
                        $targetY -ge 0 -and $targetY -lt $global:TuiState.CompositorBuffer.Height) {
                        $overlayCell = $paletteBuffer.Cells[$y, $x]
                        $overlayCell.ZIndex = 1000
                        $global:TuiState.CompositorBuffer.SetCell($targetX, $targetY, $overlayCell)
                    }
                }
            }
        }
    }
    
    # Differential rendering
    Render-DifferentialBuffer -Current $global:TuiState.CompositorBuffer -Previous $global:TuiState.PreviousCompositorBuffer
    
    # Swap buffers
    $global:TuiState.PreviousCompositorBuffer = $global:TuiState.CompositorBuffer.Clone()
}

function Render-DifferentialBuffer {
    [CmdletBinding()]
    param(
        [TuiBuffer]$Current,
        [TuiBuffer]$Previous
    )
    
    $output = [System.Text.StringBuilder]::new(16384)
    [void]$output.Append("`e[?25l") # Hide cursor during render
    
    for ($y = 0; $y -lt $Current.Height; $y++) {
        $needsMove = $true
        for ($x = 0; $x -lt $Current.Width; $x++) {
            $currentCell = $Current.Cells[$y, $x]
            $previousCell = if ($Previous) { $Previous.Cells[$y, $x] } else { $null }
            
            # Check if cell differs (including Z-index)
            if ($previousCell -and $currentCell.DiffersFrom($previousCell) -eq $false) {
                $needsMove = $true
                continue
            }
            
            # Position cursor if needed
            if ($needsMove) {
                [void]$output.Append("`e[$($y + 1);$($x + 1)H")
                $needsMove = $false
            }
            
            # Use the cell's built-in ANSI string method (supports truecolor)
            [void]$output.Append($currentCell.ToAnsiString())
        }
    }
    
    # Reset styles and show cursor
    [void]$output.Append([TuiAnsiHelper]::Reset())
    [void]$output.Append("`e[?25h")
    
    # Output everything at once
    [Console]::Write($output.ToString())
}

function Process-KeyInput {
    [CmdletBinding()]
    param(
        [System.ConsoleKeyInfo]$Key
    )
    
    # Command palette gets input priority if visible
    if ($global:TuiState.CommandPalette -and $global:TuiState.CommandPalette.Visible) {
        $handled = $global:TuiState.CommandPalette.HandleInput($Key)
        if ($handled) {
            $global:TuiState.IsDirty = $true
            return
        }
    }
    
    # Check for global hotkeys
    if ($Key.Modifiers -band [ConsoleModifiers]::Control) {
        switch ($Key.Key) {
            'C' {
                $global:TuiState.Running = $false
                return
            }
            'P' {
                if ($global:TuiState.CommandPalette) {
                    $global:TuiState.CommandPalette.Show()
                    $global:TuiState.IsDirty = $true
                }
                return
            }
        }
    }
    
    # Pass to current screen
    if ($global:TuiState.CurrentScreen) {
        $global:TuiState.CurrentScreen.HandleKeyPress($Key)
        $global:TuiState.IsDirty = $true
    }
}

function Handle-WindowResize {
    [CmdletBinding()]
    param()
    
    $newWidth = [Console]::WindowWidth
    $newHeight = [Console]::WindowHeight - 1
    
    $global:TuiState.BufferWidth = $newWidth
    $global:TuiState.BufferHeight = $newHeight
    $global:TuiState.LastWindowWidth = $newWidth
    $global:TuiState.LastWindowHeight = [Console]::WindowHeight
    
    # Recreate buffers
    $global:TuiState.CompositorBuffer = [TuiBuffer]::new($newWidth, $newHeight, "CompositorBuffer")
    $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($newWidth, $newHeight, "PreviousCompositorBuffer")
    
    # Notify current screen
    if ($global:TuiState.CurrentScreen) {
        $global:TuiState.CurrentScreen.HandleResize($newWidth, $newHeight)
    }
    
    $global:TuiState.IsDirty = $true
    [Console]::Clear()
}

function Push-Screen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Screen]$Screen
    )
    
    $global:TuiState.ScreenStack.Push($Screen)
    $global:TuiState.CurrentScreen = $Screen
    $Screen.Initialize()
    $global:TuiState.IsDirty = $true
}

function Pop-Screen {
    [CmdletBinding()]
    param()
    
    if ($global:TuiState.ScreenStack.Count -gt 0) {
        $oldScreen = $global:TuiState.ScreenStack.Pop()
        $oldScreen.Cleanup()
        
        if ($global:TuiState.ScreenStack.Count -gt 0) {
            $global:TuiState.CurrentScreen = $global:TuiState.ScreenStack.Peek()
        } else {
            $global:TuiState.CurrentScreen = $null
            $global:TuiState.Running = $false
        }
        
        $global:TuiState.IsDirty = $true
    }
}

#endregion

#region Panic Handler

function Invoke-PanicHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$Exception
    )
    
    try {
        # Restore terminal
        [Console]::CursorVisible = $true
        [Console]::TreatControlCAsInput = $false
        [Console]::ResetColor()
        [Console]::Clear()
        
        # Create crash report
        $crashTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $crashDir = Join-Path $PSScriptRoot "crash_reports"
        if (-not (Test-Path $crashDir)) {
            New-Item -ItemType Directory -Path $crashDir -Force | Out-Null
        }
        
        $crashFile = Join-Path $crashDir "crash_$crashTime.log"
        
        $crashReport = @"
Axiom-Phoenix Crash Report
========================
Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Exception:
$($Exception.Exception.Message)

Stack Trace:
$($Exception.ScriptStackTrace)

Error Details:
$($Exception | Format-List * | Out-String)

System Information:
PowerShell Version: $($PSVersionTable.PSVersion)
OS: $([System.Environment]::OSVersion.VersionString)

Last Known State:
Screen Stack Count: $($global:TuiState.ScreenStack.Count)
Current Screen: $($global:TuiState.CurrentScreen.GetType().Name)
Buffer Size: $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight)
"@
        
        # Save crash report
        $crashReport | Out-File -FilePath $crashFile -Encoding UTF8
        
        # Display error to user
        Write-Host "`n`n⚠️  AXIOM-PHOENIX CRASH DETECTED  ⚠️" -ForegroundColor Red
        Write-Host "═══════════════════════════════" -ForegroundColor Red
        Write-Host "Exception: $($Exception.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Crash report saved to: $crashFile" -ForegroundColor Cyan
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        
        [Console]::ReadKey($true) | Out-Null
    }
    catch {
        # Last resort - just try to restore terminal
        [Console]::CursorVisible = $true
        [Console]::TreatControlCAsInput = $false
        Write-Host "FATAL: Panic handler failed - $_" -ForegroundColor Red
    }
}

#endregion

#region TUI Engine

function Initialize-TuiEngine {
    [CmdletBinding()]
    param(
        [int]$Width = [Console]::WindowWidth,
        [int]$Height = [Console]::WindowHeight - 1
    )
    
    try {
        $global:TuiState.BufferWidth = $Width
        $global:TuiState.BufferHeight = $Height
        $global:TuiState.LastWindowWidth = [Console]::WindowWidth
        $global:TuiState.LastWindowHeight = [Console]::WindowHeight
        
        $global:TuiState.CompositorBuffer = [TuiBuffer]::new($Width, $Height, "CompositorBuffer")
        $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($Width, $Height, "PreviousCompositorBuffer")
        
        [Console]::CursorVisible = $false
        [Console]::TreatControlCAsInput = $true
    }
    catch {
        throw
    }
}

function Start-TuiEngine {
    [CmdletBinding()]
    param()
    
    try {
        if ($global:TuiState.Running) {
            return
        }
        
        # Clear console completely before starting
        [Console]::Clear()
        [Console]::SetCursorPosition(0, 0)
        
        $global:TuiState.Running = $true
        
        # Force initial render
        $global:TuiState.IsDirty = $true
        
        # Main render loop
        while ($global:TuiState.Running) {
            # Check for window resize
            if ([Console]::WindowWidth -ne $global:TuiState.LastWindowWidth -or 
                [Console]::WindowHeight -ne $global:TuiState.LastWindowHeight) {
                Update-TuiEngineSize
            }
            
            # Process input
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                Process-TuiInput $key
            }
            
            # Render if dirty
            if ($global:TuiState.IsDirty) {
                Invoke-TuiRender
                $global:TuiState.IsDirty = $false
            }
            
            # Small delay to prevent CPU spinning
            Start-Sleep -Milliseconds 16  # ~60 FPS
        }
    }
    catch {
        throw
    }
    finally {
        Stop-TuiEngine
    }
}

function Stop-TuiEngine {
    [CmdletBinding()]
    param()
    
    $global:TuiState.Running = $false
    [Console]::Clear()
    [Console]::CursorVisible = $true
    [Console]::TreatControlCAsInput = $false
}

function Update-TuiEngineSize {
    [CmdletBinding()]
    param()
    
    $newWidth = [Console]::WindowWidth
    $newHeight = [Console]::WindowHeight - 1
    
    $global:TuiState.BufferWidth = $newWidth
    $global:TuiState.BufferHeight = $newHeight
    $global:TuiState.LastWindowWidth = $newWidth
    $global:TuiState.LastWindowHeight = [Console]::WindowHeight
    
    # Resize buffers
    $global:TuiState.CompositorBuffer.Resize($newWidth, $newHeight)
    $global:TuiState.PreviousCompositorBuffer.Resize($newWidth, $newHeight)
    
    # Resize current screen
    if ($global:TuiState.CurrentScreen) {
        $global:TuiState.CurrentScreen.Resize($newWidth, $newHeight)
    }
    
    $global:TuiState.IsDirty = $true
}

function Process-TuiInput {
    [CmdletBinding()]
    param(
        [System.ConsoleKeyInfo]$KeyInfo
    )
    
    # Check if command palette is open first
    if ($global:TuiState.CommandPalette -and $global:TuiState.CommandPalette.Visible) {
        if ($global:TuiState.CommandPalette.HandleInput($KeyInfo)) {
            return
        }
    }
    
    # Check keybindings
    if ($global:TuiState.Services.KeybindingService) {
        $action = $global:TuiState.Services.KeybindingService.GetAction($KeyInfo)
        if ($action) {
            switch ($action) {
                'app.exit' {
                    Stop-TuiEngine
                    return
                }
                'app.showCommandPalette' {
                    if ($global:TuiState.CommandPalette) {
                        $global:TuiState.CommandPalette.Show()
                    }
                    return
                }
            }
        }
    }
    
    # Legacy key handling for compatibility
    if ($KeyInfo.Modifiers -eq [ConsoleModifiers]::Control) {
        switch ($KeyInfo.Key) {
            ([ConsoleKey]::C) {
                Stop-TuiEngine
                return
            }
            ([ConsoleKey]::P) {
                if ($global:TuiState.CommandPalette) {
                    $global:TuiState.CommandPalette.Show()
                }
                return
            }
        }
    }
    
    # Pass to current screen
    if ($global:TuiState.CurrentScreen) {
        $global:TuiState.CurrentScreen.HandleInput($KeyInfo)
    }
}

function Invoke-TuiRender {
    [CmdletBinding()]
    param()
    
    try {
        # Clear compositor buffer
        $global:TuiState.CompositorBuffer.Clear()
        
        # Render current screen
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.Render()
            $screenBuffer = $global:TuiState.CurrentScreen.GetBuffer()
            if ($screenBuffer) {
                $global:TuiState.CompositorBuffer.BlendBuffer($screenBuffer, 0, 0)
            }
        }
        
        # Render command palette overlay if visible
        if ($global:TuiState.CommandPalette -and $global:TuiState.CommandPalette.Visible) {
            $global:TuiState.CommandPalette.Render()
            $paletteBuffer = $global:TuiState.CommandPalette.GetBuffer()
            if ($paletteBuffer) {
                $global:TuiState.CompositorBuffer.BlendBuffer($paletteBuffer, 
                    $global:TuiState.CommandPalette.X, 
                    $global:TuiState.CommandPalette.Y)
            }
        }
        
        # Differential rendering
        $output = [System.Text.StringBuilder]::new()
        $compositor = $global:TuiState.CompositorBuffer
        $previous = $global:TuiState.PreviousCompositorBuffer
        
        for ($y = 0; $y -lt $compositor.Height; $y++) {
            $lineChanged = $false
            $lineOutput = [System.Text.StringBuilder]::new()
            
            for ($x = 0; $x -lt $compositor.Width; $x++) {
                $currentCell = $compositor.GetCell($x, $y)
                $previousCell = $previous.GetCell($x, $y)
                
                if ($currentCell.DiffersFrom($previousCell)) {
                    if (-not $lineChanged) {
                        [void]$lineOutput.Append("`e[$(($y + 1));$(($x + 1))H")
                        $lineChanged = $true
                    }
                    [void]$lineOutput.Append($currentCell.ToAnsiString())
                }
            }
            
            if ($lineChanged) {
                [void]$output.Append($lineOutput.ToString())
                [void]$output.Append([TuiAnsiHelper]::Reset())
            }
        }
        
        # Output to console
        if ($output.Length -gt 0) {
            [Console]::Write($output.ToString())
        }
        
        # Copy current to previous for next frame
        for ($y = 0; $y -lt $compositor.Height; $y++) {
            for ($x = 0; $x -lt $compositor.Width; $x++) {
                $previous.SetCell($x, $y, [TuiCell]::new($compositor.GetCell($x, $y)))
            }
        }
    }
    catch {
        Write-Error "Render error: $($_.Exception.Message)"
    }
}

#endregion

#region Screen Manager

function Push-Screen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Screen]$Screen
    )
    
    # Exit current screen
    if ($global:TuiState.CurrentScreen) {
        $global:TuiState.CurrentScreen.OnExit()
        $global:TuiState.ScreenStack.Push($global:TuiState.CurrentScreen)
    }
    
    # Set new screen
    $global:TuiState.CurrentScreen = $Screen
    $Screen.Width = $global:TuiState.BufferWidth
    $Screen.Height = $global:TuiState.BufferHeight
    $Screen.Initialize()
    $Screen.OnEnter()
    
    $global:TuiState.IsDirty = $true
}

function Pop-Screen {
    [CmdletBinding()]
    param()
    
    if ($global:TuiState.ScreenStack.Count -eq 0) {
        Write-Warning "No screens to pop"
        return
    }
    
    # Exit current screen
    if ($global:TuiState.CurrentScreen) {
        $global:TuiState.CurrentScreen.OnExit()
        $global:TuiState.CurrentScreen.Cleanup()
    }
    
    # Restore previous screen
    $global:TuiState.CurrentScreen = $global:TuiState.ScreenStack.Pop()
    $global:TuiState.CurrentScreen.OnResume()
    
    $global:TuiState.IsDirty = $true
}

function Switch-Screen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Screen]$Screen
    )
    
    # Exit current screen
    if ($global:TuiState.CurrentScreen) {
        $global:TuiState.CurrentScreen.OnExit()
        $global:TuiState.CurrentScreen.Cleanup()
    }
    
    # Clear stack
    $global:TuiState.ScreenStack.Clear()
    
    # Set new screen
    $global:TuiState.CurrentScreen = $Screen
    $Screen.Width = $global:TuiState.BufferWidth
    $Screen.Height = $global:TuiState.BufferHeight
    $Screen.Initialize()
    $Screen.OnEnter()
    
    $global:TuiState.IsDirty = $true
}

#endregion

#region Application Entry Point

function Start-AxiomPhoenix {
    [CmdletBinding()]
    param(
        [ServiceContainer]$ServiceContainer
    )
    
    try {
        # Disable all verbose output to prevent display corruption
    $VerbosePreference = 'SilentlyContinue'
    
    Write-Host "Starting Axiom-Phoenix..." -ForegroundColor Cyan
        
        # Initialize services
        $global:TuiState.Services = @{
            ServiceContainer = $ServiceContainer
            ActionService = $ServiceContainer.GetService("ActionService")
            KeybindingService = $ServiceContainer.GetService("KeybindingService")
            DataManager = $ServiceContainer.GetService("DataManager")
            NavigationService = $ServiceContainer.GetService("NavigationService")
            ThemeManager = $ServiceContainer.GetService("ThemeManager")
            EventManager = $ServiceContainer.GetService("EventManager")
            Logger = $ServiceContainer.GetService("Logger")
        }
        
        # Initialize command palette
        if ($global:TuiState.Services.ActionService) {
            $global:TuiState.CommandPalette = [CommandPalette]::new($global:TuiState.Services.ActionService)
            $global:TuiState.CommandPalette.Initialize()
            
            # Register command palette action
            $global:TuiState.Services.ActionService.RegisterAction(
                "app.showCommandPalette", 
                "Show the command palette for quick action access", 
                { $global:TuiState.CommandPalette.Show() }, 
                "Application", 
                $true
            )
            
            # Register additional actions
            $global:TuiState.Services.ActionService.RegisterAction(
                "nav.dashboard",
                "Navigate to dashboard",
                { 
                    $dashboard = [DashboardScreen]::new($ServiceContainer)
                    Switch-Screen -Screen $dashboard
                },
                "Navigation",
                $true
            )
            
            $global:TuiState.Services.ActionService.RegisterAction(
                "nav.tasks",
                "Navigate to task list",
                { 
                    $taskList = [TaskListScreen]::new($ServiceContainer)
                    Switch-Screen -Screen $taskList
                },
                "Navigation",
                $true
            )
        }
        
        # Initialize engine
        Initialize-TuiEngine
        
        # Create and show dashboard
        $dashboard = [DashboardScreen]::new($ServiceContainer)
        Push-Screen -Screen $dashboard
        
        # Start main loop
        Start-TuiEngine
    }
    catch {
        Write-Error "Application error: $($_.Exception.Message)"
        throw
    }
    finally {
        Stop-TuiEngine
        if ($ServiceContainer) {
            $ServiceContainer.Cleanup()
        }
        Write-Host "Axiom-Phoenix stopped." -ForegroundColor Gray
    }
}

#endregion
