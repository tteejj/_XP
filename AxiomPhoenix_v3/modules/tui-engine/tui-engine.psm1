# TUI Engine v5.2 - Pure Compositor Edition

# Implements a pure NCurses-style compositor loop. The engine's core responsibilities

# are: running the main application loop, processing the input queue, and orchestrating

# the compositor pipeline (Screen -> Overlays -> Console). All rendering is handled

# via TuiBuffer objects, ensuring a flicker-free, layered UI.



#region Core TUI State

$global:TuiState = @{

Running         = $false

BufferWidth     = 0

BufferHeight    = 0

CompositorBuffer = $null    # The master compositor buffer (TuiBuffer) that gets drawn to the console.

PreviousCompositorBuffer = $null # A copy of the last frame's compositor buffer, used for optimized diff-rendering.

ScreenStack     = [System.Collections.Stack]::new()

CurrentScreen   = $null

OverlayStack    = [System.Collections.Generic.List[UIElement]]::new() # A list to hold modal elements like dialogs.

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

}

#endregion



#region Engine Lifecycle & Main Loop



function Initialize-TuiEngine {

param(

[int]$Width = [Console]::WindowWidth,

[int]$Height = [Console]::WindowHeight - 1

)

Write-Log -Level Info -Message "Initializing TUI Engine v5.2 (Pure Compositor): ${Width}x${Height}"

try {

if ($Width -le 0 -or $Height -le 0) { throw "Invalid console dimensions: ${Width}x${Height}" }



$global:TuiState.BufferWidth = $Width

$global:TuiState.BufferHeight = $Height



$global:TuiState.CompositorBuffer = [TuiBuffer]::new($Width, $Height, "MainCompositor")

$global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($Width, $Height, "PreviousCompositor")



[Console]::CursorVisible = $false

[Console]::Clear()



$global:TuiState.EventHandlers = @{}

[Console]::TreatControlCAsInput = $false



Subscribe-Event -EventName "TUI.RefreshRequested" -Handler {

Request-TuiRefresh

} -Source "TuiEngine"



Initialize-InputThread



Publish-Event -EventName "System.EngineInitialized" -Data @{ Width = $Width; Height = $Height }

Write-Log -Level Info -Message "TUI Engine v5.2 initialized successfully"

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



# 1. Give the topmost overlay (e.g., a dialog) exclusive input priority.

if ($global:TuiState.OverlayStack.Count -gt 0) {

$topOverlay = $global:TuiState.OverlayStack[-1]

if ($topOverlay.HandleInput($keyInfo)) {

return # Overlay handled the input, stop processing.

}

}



# 2. If no overlay handled it, check for global tab navigation.

if ($keyInfo.Key -eq [ConsoleKey]::Tab) {

Move-Focus -Reverse ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift)

return

}



# 3. Give the currently focused component a chance to handle the input.

$focusedComponent = Get-FocusedComponent

if ($focusedComponent -and $focusedComponent.HandleInput($keyInfo)) {

return

}



# 4. Finally, let the current screen handle the input.

$currentScreen = $global:TuiState.CurrentScreen

if ($currentScreen) {

try {

$currentScreen.HandleInput($keyInfo)

} catch {

Write-Warning "Screen input handler error: $_"

Write-Log -Level Error -Message "HandleInput failed for screen '$($currentScreen.Name)': $_"

}

}

}



function Start-TuiLoop {

param([UIElement]$InitialScreen)

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



function Render-Frame {

try {

$global:TuiState.RenderStats.FrameCount++



Render-FrameCompositor



# After rendering, copy the current compositor state to the previous state buffer for the next frame's diff.

$global:TuiState.PreviousCompositorBuffer.Clear()

$global:TuiState.PreviousCompositorBuffer.BlendBuffer($global:TuiState.CompositorBuffer, 0, 0)



# Position the cursor out of the way to prevent visual artifacts

[Console]::SetCursorPosition($global:TuiState.BufferWidth - 1, $global:TuiState.BufferHeight - 1)

} catch {

Write-Log -Level Error -Message "A fatal error occurred during Render-Frame: $_" -Data $_

}

}



function Render-FrameCompositor {

try {

# 1. Clear the master compositor buffer

$clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, (Get-ThemeColor "Background"))

$global:TuiState.CompositorBuffer.Clear($clearCell)



# 2. Render current screen to its private buffer, then composite

if ($global:TuiState.CurrentScreen) {

Invoke-WithErrorHandling -Component ($global:TuiState.CurrentScreen.Name ?? "Screen") -Context "Screen Render" -ScriptBlock {

$global:TuiState.CurrentScreen.Render()

$screenBuffer = $global:TuiState.CurrentScreen.GetBuffer()

if ($null -ne $screenBuffer) {

$global:TuiState.CompositorBuffer.BlendBuffer($screenBuffer, 0, 0)

}

}

}



# 3. Render overlays (e.g., dialogs) on top of the screen

foreach ($overlay in $global:TuiState.OverlayStack) {

Invoke-WithErrorHandling -Component ($overlay.Name ?? "Overlay") -Context "Overlay Render" -ScriptBlock {

$overlay.Render()

$overlayBuffer = $overlay.GetBuffer()

if ($null -ne $overlayBuffer) {

$pos = $overlay.GetAbsolutePosition()

$global:TuiState.CompositorBuffer.BlendBuffer($overlayBuffer, $pos.X, $pos.Y)

}

}

}



# 4. Convert TuiBuffer to console output with optimal diffing

Render-CompositorToConsole



} catch {

Write-Log -Level Error -Message "Compositor rendering failed: $_" -Data $_

}

}



function Render-CompositorToConsole {

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

[void]$outputBuilder.Append("`e[$($y + 1);$($x + 2)H")

}

}

}



if ($lastFG -ne -1) { [void]$outputBuilder.Append("`e[0m") }



if ($outputBuilder.Length -gt 10) {

[Console]::Write($outputBuilder.ToString())

}

} catch {

Write-Log -Level Error -Message "Compositor-to-console rendering failed: $_" -Data $_

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



#region Screen & Overlay Management

function Push-Screen {

param([UIElement]$Screen)

if (-not $Screen) { return }



Write-Log -Level Debug -Message "Pushing screen: $($Screen.Name)"



try {

$global:TuiState.FocusedComponent?.OnBlur()

if ($global:TuiState.CurrentScreen) {

$global:TuiState.CurrentScreen.OnExit()

$global:TuiState.ScreenStack.Push($global:TuiState.CurrentScreen)

}

$global:TuiState.CurrentScreen = $Screen

$global:TuiState.FocusedComponent = $null



if ($Screen.Width -eq 10 -and $Screen.Height -eq 3) { # Default size

$Screen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)

}



# Call OnEnter lifecycle method

if ($Screen -is [Screen] -or $Screen.GetType().GetMethod("OnEnter")) {

$Screen.OnEnter()

}



$Screen.RequestRedraw()



Request-TuiRefresh

Publish-Event -EventName "Screen.Pushed" -Data @{ ScreenName = $Screen.Name }

} catch {

Write-Warning "Push screen error: $_"

Write-Log -Level Error -Message "Failed to push screen '$($Screen.Name)': $_"

}

}



function Pop-Screen {

if ($global:TuiState.ScreenStack.Count -eq 0) { return $false }

Write-Log -Level Debug -Message "Popping screen"

try {

$global:TuiState.FocusedComponent?.OnBlur()

$screenToExit = $global:TuiState.CurrentScreen

$global:TuiState.CurrentScreen = $global:TuiState.ScreenStack.Pop()

$global:TuiState.FocusedComponent = $null



$screenToExit?.OnExit()

$global:TuiState.CurrentScreen?.OnResume()

if ($global:TuiState.CurrentScreen.LastFocusedComponent) { Set-ComponentFocus -Component $global:TuiState.CurrentScreen.LastFocusedComponent }



Request-TuiRefresh

Publish-Event -EventName "Screen.Popped" -Data @{ ScreenName = $global:TuiState.CurrentScreen.Name }

return $true

} catch { Write-Warning "Pop screen error: $_"; return $false }

}



function Show-TuiOverlay {

param([UIElement]$Element)

$global:TuiState.OverlayStack.Add($Element)

Request-TuiRefresh

}



function Close-TopTuiOverlay {

if ($global:TuiState.OverlayStack.Count > 0) {

$global:TuiState.OverlayStack.RemoveAt($global:TuiState.OverlayStack.Count - 1)

Request-TuiRefresh

}

}

#endregion



#region Component System

function Set-ComponentFocus {

param([UIElement]$Component)

if ($Component -and (-not $Component.Enabled)) { return }



$global:TuiState.FocusedComponent?.OnBlur()

if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.LastFocusedComponent = $Component }

$global:TuiState.FocusedComponent = $Component

$Component?.OnFocus()



Request-TuiRefresh

}



function Get-NextFocusableComponent {

param([UIElement]$CurrentComponent, [bool]$Reverse = $false)

if (-not $global:TuiState.CurrentScreen) { return $null }



$focusableComponents = [System.Collections.Generic.List[UIElement]]::new()



function Find-Focusable([UIElement]$Comp) {

if ($Comp.IsFocusable -and $Comp.Visible -and $Comp.Enabled) {

$focusableComponents.Add($Comp)

}

foreach ($child in $Comp.Children) { Find-Focusable $child }

}



Find-Focusable $global:TuiState.CurrentScreen



if ($focusableComponents.Count -eq 0) { return $null }



$sorted = $focusableComponents | Sort-Object { $_.TabIndex * 10000 + $_.Y * 100 + $_.X }



if ($Reverse) { [Array]::Reverse($sorted) }



$currentIndex = [array]::IndexOf($sorted, $CurrentComponent)

if ($currentIndex -ge 0) {

return $sorted[($currentIndex + 1) % $sorted.Count]

} else {

return $sorted[0]

}

}



function Move-Focus { param([bool]$Reverse = $false); $next = Get-NextFocusableComponent -CurrentComponent $global:TuiState.FocusedComponent -Reverse $Reverse; if ($next) { Set-ComponentFocus -Component $next } }

function Get-FocusedComponent { return $global:TuiState.FocusedComponent }

function Stop-AllTuiAsyncJobs { Write-Log -Level Debug -Message "Stopping all TUI async jobs (none currently active)" }

#endregion



#region Utilities

function Get-AnsiColorCode { param([ConsoleColor]$Color, [bool]$IsBackground); $map = @{ Black=30;DarkBlue=34;DarkGreen=32;DarkCyan=36;DarkRed=31;DarkMagenta=35;DarkYellow=33;Gray=37;DarkGray=90;Blue=94;Green=92;Cyan=96;Red=91;Magenta=95;Yellow=93;White=97 }; $code = $map[$Color.ToString()]; return $IsBackground ? $code + 10 : $code }

function Stop-TuiEngine { Write-Log -Level Info -Message "Stop-TuiEngine called"; $global:TuiState.Running = $false; $global:TuiState.CancellationTokenSource?.Cancel(); Publish-Event -EventName "System.Shutdown" }

function Stop-TuiLoop { Stop-TuiEngine }

#endregion
