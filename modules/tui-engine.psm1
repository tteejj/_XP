# TUI Engine v5.1 - NCurses Compositor Edition
# Implements NCurses-style compositor with private buffers and TuiCell rendering

#using module '..\components\tui-primitives.psm1'
#using module '.\logger.psm1'
#using module '.\event-system.psm1'
#using module '.\exceptions.psm1'
#using module '.\dialog-system-class.psm1'

#region Core TUI State
$global:TuiState = @{
    Running         = $false
    BufferWidth     = 0
    BufferHeight    = 0
    FrontBuffer     = $null
    BackBuffer      = $null
    CompositorBuffer = $null    # AI: NEW - Master compositor buffer (TuiBuffer)
    PreviousCompositorBuffer = $null # AI: NEW - Buffer for diffing against the main compositor
    ScreenStack     = [System.Collections.Stack]::new()
    CurrentScreen   = $null
    IsDirty         = $true
    RenderStats     = @{ LastFrameTime = 0; FrameCount = 0; TargetFPS = 60 }
    Components      = @()
    Layouts         = @{}
    FocusedComponent = $null
    InputQueue      = [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]::new()
    InputRunspace   = $null
    InputPowerShell = $null
    InputAsyncResult = $null
    CancellationTokenSource = $null
    EventHandlers   = @{}
    CompositorMode  = $true     # AI: NEW - Enable NCurses-style rendering
}
#endregion

#region Engine Lifecycle & Main Loop

function Initialize-TuiEngine {
    param(
        [int]$Width = [Console]::WindowWidth,
        [int]$Height = [Console]::WindowHeight - 1
    )
    Write-Log -Level Info -Message "Initializing TUI Engine v5.1 (NCurses Compositor): ${Width}x${Height}"
    try {
        if ($Width -le 0 -or $Height -le 0) { throw "Invalid console dimensions: ${Width}x${Height}" }
        
        $global:TuiState.BufferWidth = $Width
        $global:TuiState.BufferHeight = $Height
        
        # AI: ENHANCED - Create both legacy buffers and new TuiBuffer compositor
        $global:TuiState.FrontBuffer = New-Object 'object[,]' $Height, $Width
        $global:TuiState.BackBuffer = New-Object 'object[,]' $Height, $Width
        $global:TuiState.CompositorBuffer = [TuiBuffer]::new($Width, $Height, "MainCompositor")
        $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($Width, $Height, "PreviousCompositor")
        
        # Initialize legacy buffers for compatibility
        for ($y = 0; $y -lt $Height; $y++) {
            for ($x = 0; $x -lt $Width; $x++) {
                $global:TuiState.FrontBuffer[$y, $x] = @{ Char = ' '; FG = [ConsoleColor]::White; BG = [ConsoleColor]::Black }
                $global:TuiState.BackBuffer[$y, $x] = @{ Char = ' '; FG = [ConsoleColor]::White; BG = [ConsoleColor]::Black }
            }
        }
        
        [Console]::CursorVisible = $false
        [Console]::Clear()
        
        try { Initialize-LayoutEngines; Write-Log -Level Debug -Message "Layout engines initialized" } catch { Write-Log -Level Error -Message "Layout engines init failed" -Data $_ }
        try { Initialize-ComponentSystem; Write-Log -Level Debug -Message "Component system initialized" } catch { Write-Log -Level Error -Message "Component system init failed" -Data $_ }
        
        $global:TuiState.EventHandlers = @{}
        [Console]::TreatControlCAsInput = $false
        
        # AI: FIX - Subscribe to refresh requests to decouple dialog system
        Subscribe-Event -EventName "TUI.RefreshRequested" -Handler {
            Request-TuiRefresh
        } -Source "TuiEngine"

        Initialize-InputThread
        
        Publish-Event -EventName "System.EngineInitialized" -Data @{ Width = $Width; Height = $Height; CompositorMode = $global:TuiState.CompositorMode }
        Write-Log -Level Info -Message "TUI Engine v5.1 initialized successfully (Compositor Mode: $($global:TuiState.CompositorMode))"
    }
    catch {
        Write-Host "FATAL: TUI Engine initialization failed. See error details below." -ForegroundColor Red
        $_.Exception | Format-List * -Force
        throw "TUI Engine initialization failed."
    }
}

function Initialize-InputThread {
    $global:TuiState.CancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
    $token = $global:TuiState.CancellationTokenSource.Token

    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('InputQueue', $global:TuiState.InputQueue)
    $runspace.SessionStateProxy.SetVariable('token', $token)
    
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    
    $ps.AddScript({
        try {
            while (-not $token.IsCancellationRequested) {
                if ([Console]::KeyAvailable) {
                    if ($InputQueue.Count -lt 100) { $InputQueue.Enqueue([Console]::ReadKey($true)) }
                } else {
                    Start-Sleep -Milliseconds 20
                }
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] { return }
        catch { Write-Warning "Input thread error: $_" }
    }) | Out-Null
    
    $global:TuiState.InputRunspace = $runspace
    $global:TuiState.InputPowerShell = $ps
    $global:TuiState.InputAsyncResult = $ps.BeginInvoke()
}

function Process-TuiInput {
    $processedAny = $false
    $keyInfo = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::None, $false, $false, $false)
    while ($global:TuiState.InputQueue.TryDequeue([ref]$keyInfo)) {
        $processedAny = $true
        try {
            Invoke-WithErrorHandling -Component "Engine.ProcessInput" -Context "Processing single key" -ScriptBlock { Process-SingleKeyInput -keyInfo $keyInfo }
        } catch {
            Write-Log -Level Error -Message "Error processing key input: $($_.Exception.Message)" -Data $_
            Request-TuiRefresh
        }
    }
    return $processedAny
}

function Process-SingleKeyInput {
    param($keyInfo)
    if ($keyInfo.Key -eq [ConsoleKey]::Tab) {
        Move-Focus -Reverse ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift)
        return
    }
    
    if (Handle-DialogInput -Key $keyInfo) { return }
    
    $focusedComponent = Get-FocusedComponent
    if ($focusedComponent) {
        try { 
            # AI: ENHANCED - Better class detection for UIElement-based components
            if ($focusedComponent -is [UIElement]) {
                # New UIElement-based component
                $focusedComponent.HandleInput($keyInfo)
            }
            elseif ($focusedComponent.PSObject.TypeNames -contains 'UIElement' -or $focusedComponent.GetType().IsSubclassOf([UIElement])) {
                # Class-based component (legacy detection)
                if ($focusedComponent.PSObject.Methods.Name -contains 'HandleInput') {
                    $focusedComponent.HandleInput($keyInfo)
                }
            }
            elseif ($focusedComponent.HandleInput) {
                # Functional component with HandleInput scriptblock
                if (& $focusedComponent.HandleInput -self $focusedComponent -Key $keyInfo) { return }
            }
        } catch { 
            Write-Warning "Component input handler error: $_"
            Write-Log -Level Error -Message "HandleInput failed for component '$($focusedComponent.Name)': $_"
        }
    }
    
    $currentScreen = $global:TuiState.CurrentScreen
    if ($currentScreen) {
        try {
            # AI: ENHANCED - Support for UIElement-based screens
            if ($currentScreen -is [UIElement]) {
                # New UIElement-based screen
                $currentScreen.HandleInput($keyInfo)
            }
            elseif ($currentScreen -is [Screen]) {
                # Legacy class-based screen
                $currentScreen.HandleInput($keyInfo)
            }
            elseif ($currentScreen.HandleInput) {
                # Hashtable/functional screen - use scriptblock invocation
                $result = & $currentScreen.HandleInput -self $currentScreen -Key $keyInfo
                switch ($result) {
                    "Back" { Pop-Screen }
                    "Quit" { Stop-TuiEngine }
                }
            }
        } catch { 
            Write-Warning "Screen input handler error: $_"
            Write-Log -Level Error -Message "HandleInput failed for screen '$($currentScreen.Name)': $_"
        }
    }
}

function Start-TuiLoop {
    param([object]$InitialScreen)  # AI: Accept both UIElement and hashtable screens
    try {
        if (-not $global:TuiState.BufferWidth) { Initialize-TuiEngine }
        if ($InitialScreen) { Push-Screen -Screen $InitialScreen }
        if (-not $global:TuiState.CurrentScreen) { throw "No screen available. Push a screen before calling Start-TuiLoop." }

        $global:TuiState.Running = $true
        $frameTime = [System.Diagnostics.Stopwatch]::new()
        $targetFrameTime = 1000.0 / $global:TuiState.RenderStats.TargetFPS
        
        while ($global:TuiState.Running) {
            try {
                $frameTime.Restart()
                $hadInput = Process-TuiInput
                try { Update-DialogSystem } catch {}
                if ($global:TuiState.IsDirty -or $hadInput) { Render-Frame; $global:TuiState.IsDirty = $false }
                $elapsed = $frameTime.ElapsedMilliseconds
                if ($elapsed -lt $targetFrameTime) { Start-Sleep -Milliseconds ([Math]::Max(1, $targetFrameTime - $elapsed)) }
            }
            catch [Helios.HeliosException] {
                Write-Log -Level Error -Message "A TUI Exception occurred: $($_.Exception.Message)" -Data $_.Exception.Context
                Show-AlertDialog -Title "Application Error" -Message "An operation failed: $($_.Exception.Message)"
                $global:TuiState.IsDirty = $true
            }
            catch {
                Write-Log -Level Error -Message "A FATAL, unhandled exception occurred: $($_.Exception.Message)" -Data $_
                Show-AlertDialog -Title "Fatal Error" -Message "A critical error occurred. The application will now close."
                $global:TuiState.Running = $false
            }
        }
    }
    finally { Cleanup-TuiEngine }
}

# AI: REWRITTEN - NCurses Compositor Render-Frame
function Render-Frame {
    try {
        $global:TuiState.RenderStats.FrameCount++
        
        if ($global:TuiState.CompositorMode -and $null -ne $global:TuiState.CompositorBuffer) {
            # AI: NEW - NCurses-style compositor rendering
            Render-FrameCompositor
        } else {
            # AI: LEGACY - Fall back to old rendering for compatibility
            Render-FrameLegacy
        }
        
        # AI: NEW - After rendering, copy the current compositor state to the previous state buffer for the next frame's diff.
        if ($global:TuiState.CompositorMode) {
            $global:TuiState.PreviousCompositorBuffer.Clear()
            $global:TuiState.PreviousCompositorBuffer.BlendBuffer($global:TuiState.CompositorBuffer, 0, 0)
        }
        
        # Position the cursor out of the way to prevent visual artifacts
        [Console]::SetCursorPosition($global:TuiState.BufferWidth - 1, $global:TuiState.BufferHeight - 1)
    } catch { 
        Write-Log -Level Error -Message "A fatal error occurred during Render-Frame: $_" -Data $_
    }
}

function Render-FrameCompositor {
    # AI: NEW - NCurses-style compositor rendering pipeline
    try {
        # 1. Clear the master compositor buffer
        $clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, (Get-ThemeColor "Background"))
        $global:TuiState.CompositorBuffer.Clear($clearCell)
        
        # 2. Render current screen to its private buffer, then composite
        if ($global:TuiState.CurrentScreen) {
            Invoke-WithErrorHandling -Component ($global:TuiState.CurrentScreen.Name ?? "Screen") -Context "Screen Render" -ScriptBlock {
                if ($global:TuiState.CurrentScreen -is [UIElement]) {
                    # New UIElement-based screen - render to its private buffer
                    $global:TuiState.CurrentScreen.Render()
                    
                    # Composite screen buffer onto master compositor
                    $screenBuffer = $global:TuiState.CurrentScreen.GetBuffer()
                    if ($null -ne $screenBuffer) {
                        $global:TuiState.CompositorBuffer.BlendBuffer($screenBuffer, 0, 0)
                    }
                } else {
                    # Legacy screen - render directly (will be deprecated)
                    $global:TuiState.CurrentScreen.Render()
                }
            }
        }
        
        # 3. Render dialogs on top
        $dialog = Get-CurrentDialog
        if ($dialog) {
            Invoke-WithErrorHandling -Component ($dialog.Name ?? $dialog.Type ?? "Dialog") -Context "Dialog Render" -ScriptBlock {
                if ($dialog -is [UIElement]) {
                    # New UIElement-based dialog
                    $dialog.Render()
                    $dialogBuffer = $dialog.GetBuffer()
                    if ($null -ne $dialogBuffer) {
                        $pos = $dialog.GetAbsolutePosition()
                        $global:TuiState.CompositorBuffer.BlendBuffer($dialogBuffer, $pos.X, $pos.Y)
                    }
                } elseif ($dialog.GetType().IsSubclassOf([UIElement])) {
                    # Class-based dialog with Render() method
                    $dialog.Render()
                } elseif ($dialog -is [hashtable] -and $dialog.Render) {
                    # Functional/hashtable dialog with Render scriptblock
                    & $dialog.Render -self $dialog
                } else {
                    Write-Log -Level Warning -Message "Unknown dialog type: $($dialog.GetType().Name)"
                }
            }
        }
        
        # 4. Convert TuiBuffer to console output with optimal diffing
        Render-CompositorToConsole
        
    } catch {
        Write-Log -Level Error -Message "Compositor rendering failed: $_" -Data $_
        # Fall back to legacy rendering
        Render-FrameLegacy
    }
}

function Render-CompositorToConsole {
    # AI: REWRITTEN - True TuiBuffer-to-TuiBuffer diffing.
    $outputBuilder = [System.Text.StringBuilder]::new(20000)
    $currentBuffer = $global:TuiState.CompositorBuffer
    $previousBuffer = $global:TuiState.PreviousCompositorBuffer
    $lastFG = -1; $lastBG = -1
    $forceFullRender = $global:TuiState.RenderStats.FrameCount -eq 1

    try {
        for ($y = 0; $y -lt $currentBuffer.Height; $y++) {
            $rowChanged = $false
            for ($x = 0; $x -lt $currentBuffer.Width; $x++) {
                $newCell = $currentBuffer.GetCell($x, $y)
                $oldCell = $previousBuffer.GetCell($x, $y)
                
                if ($forceFullRender -or $newCell.DiffersFrom($oldCell)) {
                    if (-not $rowChanged) {
                        [void]$outputBuilder.Append("`e[$($y + 1);1H")
                        # On the first change in a row, we must move the cursor.
                        # For subsequent changes, we need to move it again if there was a gap.
                        if ($x > 0) { [void]$outputBuilder.Append("`e[$($y + 1);$($x + 1)H") }
                        $rowChanged = $true
                    }

                    if ($newCell.ForegroundColor -ne $lastFG -or $newCell.BackgroundColor -ne $lastBG) {
                        $fgCode = Get-AnsiColorCode $newCell.ForegroundColor
                        $bgCode = Get-AnsiColorCode $newCell.BackgroundColor -IsBackground $true
                        [void]$outputBuilder.Append("`e[${fgCode};${bgCode}m")
                        $lastFG = $newCell.ForegroundColor
                        $lastBG = $newCell.BackgroundColor
                    }
                    [void]$outputBuilder.Append($newCell.Char)
                } elseif ($rowChanged) {
                    # If a change occurred in this row previously, but this cell is the same,
                    # we need to move the cursor to the next potential change point.
                    [void]$outputBuilder.Append("`e[$($y + 1);$($x + 2)H")
                }
            }
        }
        
        # Reset colors at the end
        if ($lastFG -ne -1) { [void]$outputBuilder.Append("`e[0m") }
        
        if ($outputBuilder.Length -gt 10) {
            [Console]::Write($outputBuilder.ToString())
        }
    } catch {
        Write-Log -Level Error -Message "Compositor-to-console rendering failed: $_" -Data $_
    }
}

function Render-FrameLegacy {
    # AI: LEGACY - Original rendering code for compatibility
    try {
        Clear-BackBuffer -BackgroundColor (Get-ThemeColor "Background")
        
        if ($global:TuiState.CurrentScreen) {
            Invoke-WithErrorHandling -Component $global:TuiState.CurrentScreen.Name -Context "Screen Render" -ScriptBlock {
                $global:TuiState.CurrentScreen.Render()
            }
        }
        
        $dialog = Get-CurrentDialog
        if ($dialog) {
            Invoke-WithErrorHandling -Component ($dialog.Name ?? $dialog.Type ?? "Dialog") -Context "Dialog Render" -ScriptBlock {
                if ($dialog.GetType().IsSubclassOf([UIElement]) -or $dialog -is [UIElement]) {
                    $dialog.Render()
                } elseif ($dialog -is [hashtable] -and $dialog.Render) {
                    & $dialog.Render -self $dialog
                } else {
                    Write-Log -Level Warning -Message "Unknown dialog type: $($dialog.GetType().Name)"
                }
            }
        }
        
        Render-BufferOptimized
        
    } catch {
        Write-Log -Level Error -Message "Legacy rendering failed: $_" -Data $_
    }
}

function Request-TuiRefresh { $global:TuiState.IsDirty = $true }

function Cleanup-TuiEngine {
    try {
        $global:TuiState.CancellationTokenSource?.Cancel()
        $global:TuiState.InputPowerShell?.EndInvoke($global:TuiState.InputAsyncResult)
        $global:TuiState.InputPowerShell?.Dispose()
        $global:TuiState.InputRunspace?.Dispose()
        $global:TuiState.CancellationTokenSource?.Dispose()
        
        Stop-AllTuiAsyncJobs
        
        foreach ($handlerId in $global:TuiState.EventHandlers.Values) { try { Unsubscribe-Event -HandlerId $handlerId } catch {} }
        $global:TuiState.EventHandlers.Clear()
        
        if ($Host.Name -ne 'Visual Studio Code Host') {
            [Console]::Write("`e[0m"); [Console]::CursorVisible = $true; [Console]::Clear(); [Console]::ResetColor()
        }
    } catch { Write-Warning "A secondary error occurred during TUI cleanup: $_" }
}
#endregion

#region Screen Management
function Push-Screen {
    # AI: ENHANCED - Accept both UIElement and legacy screen objects
    param([object]$Screen)
    if (-not $Screen) { return }
    
    $screenName = if ($Screen -is [UIElement]) { $Screen.Name } elseif ($Screen -is [Screen]) { $Screen.Name } else { $Screen.Name }
    Write-Log -Level Debug -Message "Pushing screen: $screenName"
    
    try {
        $global:TuiState.FocusedComponent?.OnBlur?.Invoke()
        if ($global:TuiState.CurrentScreen) {
            # Handle exit for current screen
            if ($global:TuiState.CurrentScreen -is [UIElement]) {
                # New UIElement-based screen
                # No explicit OnExit method - handled by framework
            } elseif ($global:TuiState.CurrentScreen -is [Screen]) {
                # Legacy class-based screen
                $global:TuiState.CurrentScreen.OnExit()
            } elseif ($global:TuiState.CurrentScreen.OnExit) {
                # Functional screen
                $global:TuiState.CurrentScreen.OnExit.Invoke()
            }
            $global:TuiState.ScreenStack.Push($global:TuiState.CurrentScreen)
        }
        $global:TuiState.CurrentScreen = $Screen
        $global:TuiState.FocusedComponent = $null
        
        # Initialize new screen
        if ($Screen -is [UIElement]) {
            # New UIElement-based screen - ensure it's sized to fit screen
            if ($Screen.Width -eq 10 -and $Screen.Height -eq 3) {  # Default size
                $Screen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)
            }
            # Trigger initial render
            $Screen.RequestRedraw()
        } elseif ($Screen -is [Screen]) {
            # Legacy class-based screen
            $Screen.OnEnter()
        } elseif ($Screen.Init) { 
            # Functional screen
            Invoke-WithErrorHandling -Component "$($Screen.Name).Init" -Context "Screen initialization" -ScriptBlock { 
                $services = $Screen._services ?? $global:Services
                & $Screen.Init -self $Screen -services $services
            }
        }
        Request-TuiRefresh
        Publish-Event -EventName "Screen.Pushed" -Data @{ ScreenName = $screenName }
    } catch { 
        Write-Warning "Push screen error: $_"
        Write-Log -Level Error -Message "Failed to push screen '$screenName': $_"
    }
}

function Pop-Screen {
    if ($global:TuiState.ScreenStack.Count -eq 0) { return $false }
    Write-Log -Level Debug -Message "Popping screen"
    try {
        $global:TuiState.FocusedComponent?.OnBlur?.Invoke()
        $screenToExit = $global:TuiState.CurrentScreen
        $global:TuiState.CurrentScreen = $global:TuiState.ScreenStack.Pop()
        $global:TuiState.FocusedComponent = $null
        
        $screenToExit?.OnExit?.Invoke()
        $global:TuiState.CurrentScreen?.OnResume?.Invoke()
        if ($global:TuiState.CurrentScreen.LastFocusedComponent) { Set-ComponentFocus -Component $global:TuiState.CurrentScreen.LastFocusedComponent }
        
        Request-TuiRefresh
        Publish-Event -EventName "Screen.Popped" -Data @{ ScreenName = $global:TuiState.CurrentScreen.Name }
        return $true
    } catch { Write-Warning "Pop screen error: $_"; return $false }
}
#endregion

#region Buffer and Rendering - Legacy Support
function Clear-BackBuffer {
    param([ConsoleColor]$BackgroundColor = [ConsoleColor]::Black)
    for ($y = 0; $y -lt $global:TuiState.BufferHeight; $y++) {
        for ($x = 0; $x -lt $global:TuiState.BufferWidth; $x++) {
            $global:TuiState.BackBuffer[$y, $x] = @{ Char = ' '; FG = [ConsoleColor]::White; BG = $BackgroundColor }
        }
    }
}

function Write-BufferString {
    param([int]$X, [int]$Y, [string]$Text, [ConsoleColor]$ForegroundColor = [ConsoleColor]::White, [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black)
    if ($Y -lt 0 -or $Y -ge $global:TuiState.BufferHeight -or [string]::IsNullOrEmpty($Text)) { return }
    $currentX = $X
    foreach ($char in $Text.ToCharArray()) {
        if ($currentX -ge $global:TuiState.BufferWidth) { break }
        if ($currentX -ge 0) { $global:TuiState.BackBuffer[$Y, $currentX] = @{ Char = $char; FG = $ForegroundColor; BG = $BackgroundColor } }
        $currentX++
    }
}

function Write-BufferBox {
    param([int]$X, [int]$Y, [int]$Width, [int]$Height, [string]$BorderStyle = "Single", [ConsoleColor]$BorderColor = [ConsoleColor]::White, [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black, [string]$Title = "")
    $borders = Get-BorderChars -Style $BorderStyle
    Write-BufferString -X $X -Y $Y -Text "$($borders.TopLeft)$($borders.Horizontal * ($Width - 2))$($borders.TopRight)" -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    if ($Title) {
        $titleText = " $Title "; if ($titleText.Length -gt ($Width-2)) { $titleText = " $($Title.Substring(0,[Math]::Max(0,$Width-5)))... " }
        Write-BufferString -X ($X + [Math]::Floor(($Width - $titleText.Length) / 2)) -Y $Y -Text $titleText -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
    for ($i = 1; $i -lt ($Height - 1); $i++) {
        Write-BufferString -X $X -Y ($Y + $i) -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        Write-BufferString -X ($X + 1) -Y ($Y + $i) -Text (' ' * ($Width - 2)) -BackgroundColor $BackgroundColor
        Write-BufferString -X ($X + $Width - 1) -Y ($Y + $i) -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
    Write-BufferString -X $X -Y ($Y + $Height - 1) -Text "$($borders.BottomLeft)$($borders.Horizontal * ($Width - 2))$($borders.BottomRight)" -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
}

function Render-BufferOptimized {
    $outputBuilder = [System.Text.StringBuilder]::new(20000); $lastFG = -1; $lastBG = -1
    $forceFullRender = $global:TuiState.RenderStats.FrameCount -eq 0
    try {
        for ($y = 0; $y -lt $global:TuiState.BufferHeight; $y++) {
            $outputBuilder.Append("`e[$($y + 1);1H") | Out-Null
            for ($x = 0; $x -lt $global:TuiState.BufferWidth; $x++) {
                $backCell = $global:TuiState.BackBuffer[$y, $x]; $frontCell = $global:TuiState.FrontBuffer[$y, $x]
                if (-not $forceFullRender -and $backCell.Char -eq $frontCell.Char -and $backCell.FG -eq $frontCell.FG -and $backCell.BG -eq $frontCell.BG) { continue }
                if ($x -gt 0 -and $outputBuilder.Length -gt 0) { $outputBuilder.Append("`e[$($y + 1);$($x + 1)H") | Out-Null }
                if ($backCell.FG -ne $lastFG -or $backCell.BG -ne $lastBG) {
                    $fgCode = Get-AnsiColorCode $backCell.FG; $bgCode = Get-AnsiColorCode $backCell.BG -IsBackground $true
                    $outputBuilder.Append("`e[${fgCode};${bgCode}m") | Out-Null; $lastFG = $backCell.FG; $lastBG = $backCell.BG
                }
                $outputBuilder.Append($backCell.Char) | Out-Null
                $global:TuiState.FrontBuffer[$y, $x] = @{ Char = $backCell.Char; FG = $backCell.FG; BG = $backCell.BG }
            }
        }
        $outputBuilder.Append("`e[0m") | Out-Null
        if ($outputBuilder.Length -gt 0) { [Console]::Write($outputBuilder.ToString()) }
    } catch { Write-Warning "Render error: $_" }
}
#endregion

#region Component System - Enhanced for UIElement
function Initialize-ComponentSystem { $global:TuiState.Components = @(); $global:TuiState.FocusedComponent = $null }

function Register-Component { 
    param([object]$Component)  # AI: Accept both UIElement and hashtable components
    $global:TuiState.Components += $Component
    
    # Initialize component based on type
    if ($Component -is [UIElement]) {
        # New UIElement-based component - no explicit init needed
        Write-Log -Level Debug -Message "Registered UIElement component: $($Component.Name)"
    } elseif ($Component.Init) { 
        try { & $Component.Init -self $Component } catch { Write-Warning "Component init error: $_" } 
    }
    return $Component 
}

function Set-ComponentFocus { 
    param([object]$Component)  # AI: Accept both UIElement and hashtable components
    if ($Component -and ($Component.IsEnabled -eq $false -or $Component.Disabled -eq $true)) { return }
    
    # Blur current component
    if ($null -ne $global:TuiState.FocusedComponent) {
        if ($global:TuiState.FocusedComponent -is [UIElement]) {
            $global:TuiState.FocusedComponent.OnBlur()
        } else {
            $global:TuiState.FocusedComponent.OnBlur?.Invoke()
        }
    }
    
    # Set new focused component
    if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.LastFocusedComponent = $Component }
    $global:TuiState.FocusedComponent = $Component
    
    # Focus new component
    if ($null -ne $Component) {
        if ($Component -is [UIElement]) {
            $Component.OnFocus()
        } else {
            $Component.OnFocus?.Invoke()
        }
    }
    
    Request-TuiRefresh 
}

function Clear-ComponentFocus { 
    if ($null -ne $global:TuiState.FocusedComponent) {
        if ($global:TuiState.FocusedComponent -is [UIElement]) {
            $global:TuiState.FocusedComponent.OnBlur()
        } else {
            $global:TuiState.FocusedComponent.OnBlur?.Invoke()
        }
    }
    $global:TuiState.FocusedComponent = $null
    if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.LastFocusedComponent = $null }
    Request-TuiRefresh 
}

# AI: ENHANCED - Support UIElement focusable detection
function Get-NextFocusableComponent { 
    param([object]$CurrentComponent, [bool]$Reverse = $false)
    if (-not $global:TuiState.CurrentScreen) { return $null }
    
    $focusableComponents = @()
    
    function Find-Focusable([object]$Comp) { 
        if ($Comp -is [UIElement]) {
            # New UIElement-based component
            if ($Comp.IsFocusable -and $Comp.Visible -and $Comp.Enabled) {
                $focusableComponents += $Comp
            }
            # Check children
            foreach ($child in $Comp.Children) {
                Find-Focusable $child
            }
        } else {
            # Legacy component
            if ($Comp.IsFocusable -eq $true -and $Comp.Visible -ne $false) { 
                $focusableComponents += $Comp 
            }
            if ($Comp.Children) { 
                foreach ($c in $Comp.Children) { Find-Focusable $c } 
            }
        }
    }
    
    # Find focusable components in current screen
    if ($global:TuiState.CurrentScreen -is [UIElement]) {
        Find-Focusable $global:TuiState.CurrentScreen
    } elseif ($global:TuiState.CurrentScreen.Components) { 
        foreach ($c in $global:TuiState.CurrentScreen.Components.Values) { Find-Focusable $c } 
    }
    
    if ($focusableComponents.Count -eq 0) { return $null }
    
    # Sort by tab index and position
    $sorted = $focusableComponents | Sort-Object { 
        if ($_ -is [UIElement]) {
            $_.TabIndex * 10000 + $_.Y * 100 + $_.X
        } else {
            ($_.TabIndex ?? 0) * 10000 + ($_.Y ?? 0) * 100 + ($_.X ?? 0)
        }
    }
    
    if ($Reverse) { [Array]::Reverse($sorted) }
    
    $currentIndex = [array]::IndexOf($sorted, $CurrentComponent)
    if ($currentIndex -ge 0) { 
        return $sorted[($currentIndex + 1) % $sorted.Count] 
    } else { 
        return $sorted[0] 
    } 
}

function Handle-TabNavigation { param([bool]$Reverse = $false); $next = Get-NextFocusableComponent -CurrentComponent $global:TuiState.FocusedComponent -Reverse $Reverse; if ($next) { Set-ComponentFocus -Component $next } }

# AI: LEGACY - Helper functions maintained for compatibility
function Get-FocusedComponent { return $global:TuiState.FocusedComponent }
function Move-Focus { param([bool]$Reverse = $false); Handle-TabNavigation -Reverse $Reverse }

function Get-CurrentDialog {
    # AI: REFACTORED - This function now directly and reliably accesses the dialog state
    # from the single, class-based dialog system.
    try {
        if (Get-Module -Name 'dialog-system-class' -ErrorAction SilentlyContinue) {
            # This retrieves the $script:DialogState variable from the specified module's scope.
            return (Get-Module -Name 'dialog-system-class').SessionState.PSVariable.Get('DialogState').Value.CurrentDialog
        }
    } catch {
        Write-Log -Level Error -Message "Critical error accessing dialog system state: $_"
    }
    return $null
}

function Handle-DialogInput {
    param([System.ConsoleKeyInfo]$Key)
    # AI: REFACTORED - Simplified to work only with the new UIElement-based dialogs.
    try {
        $dialog = Get-CurrentDialog
        if ($dialog -and $dialog -is [UIElement]) {
            # All dialogs are now UIElements and have a HandleInput method.
            return $dialog.HandleInput($Key)
        }
    } catch {
        Write-Log -Level Error -Message "Error handling dialog input: $_"
    }
    return $false
}

function Update-DialogSystem {
    # Dialog system handles its own updates if loaded
}

function Stop-AllTuiAsyncJobs {
    Write-Log -Level Debug -Message "Stopping all TUI async jobs (none currently active)"
}
#endregion

#region Layout Management & Utilities
function Initialize-LayoutEngines { $global:TuiState.Layouts = @{} }
function Get-BorderChars { param([string]$Style); $styles = @{ Single=@{TopLeft='┌';TopRight='┐';BottomLeft='└';BottomRight='┘';Horizontal='─';Vertical='│'}; Double=@{TopLeft='╔';TopRight='╗';BottomLeft='╚';BottomRight='╝';Horizontal='═';Vertical='║'}; Rounded=@{TopLeft='╭';TopRight='╮';BottomLeft='╰';BottomRight='╯';Horizontal='─';Vertical='│'} }; return $styles[$Style] ?? $styles.Single }
function Get-AnsiColorCode { param([ConsoleColor]$Color, [bool]$IsBackground); $map = @{ Black=30;DarkBlue=34;DarkGreen=32;DarkCyan=36;DarkRed=31;DarkMagenta=35;DarkYellow=33;Gray=37;DarkGray=90;Blue=94;Green=92;Cyan=96;Red=91;Magenta=95;Yellow=93;White=97 }; $code = $map[$Color.ToString()]; return $IsBackground ? $code + 10 : $code }
function Get-WordWrappedLines { param([string]$Text, [int]$MaxWidth); if ([string]::IsNullOrEmpty($Text) -or $MaxWidth -le 0) { return @() }; $lines = @(); $words = $Text -split '\s+'; $sb = [System.Text.StringBuilder]::new(); foreach ($word in $words) { if ($sb.Length -eq 0) { [void]$sb.Append($word) } elseif (($sb.Length + 1 + $word.Length) -le $MaxWidth) { [void]$sb.Append(' ').Append($word) } else { $lines += $sb.ToString(); [void]$sb.Clear().Append($word) } }; if ($sb.Length -gt 0) { $lines += $sb.ToString() }; return $lines }
function Stop-TuiEngine { Write-Log -Level Info -Message "Stop-TuiEngine called"; $global:TuiState.Running = $false; $global:TuiState.CancellationTokenSource?.Cancel(); Publish-Event -EventName "System.Shutdown" }

# AI: NEW - Compositor helper functions
function Get-ThemeColor {
    param([string]$ColorName)
    # Simple theme color mapping - can be enhanced later
    $themeColors = @{
        Background = [ConsoleColor]::Black
        Foreground = [ConsoleColor]::White
        Border = [ConsoleColor]::Gray
        Focus = [ConsoleColor]::Cyan
        Highlight = [ConsoleColor]::Yellow
    }
    return $themeColors[$ColorName] ?? [ConsoleColor]::Black
}
#endregion

Export-ModuleMember -Function 'Initialize-TuiEngine', 'Start-TuiLoop', 'Stop-TuiEngine', 'Push-Screen', 'Pop-Screen', 'Request-TuiRefresh', 'Write-BufferString', 'Write-BufferBox', 'Clear-BackBuffer', 'Get-BorderChars', 'Register-Component', 'Set-ComponentFocus', 'Clear-ComponentFocus', 'Get-NextFocusableComponent', 'Handle-TabNavigation', 'Get-WordWrappedLines', 'Get-FocusedComponent', 'Move-Focus', 'Get-CurrentDialog', 'Handle-DialogInput', 'Update-DialogSystem', 'Stop-AllTuiAsyncJobs', 'Get-ThemeColor' -Variable 'TuiState'