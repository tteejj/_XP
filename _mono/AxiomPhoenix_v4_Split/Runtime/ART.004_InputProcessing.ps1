# ==============================================================================
# Axiom-Phoenix v4.0 - Input Processing
# Handles keyboard input and routes to appropriate handlers
# ==============================================================================

# Process input for current screen and services
function Process-TuiInput {
    param([System.ConsoleKeyInfo]$KeyInfo)
    
    if ($null -eq $KeyInfo) { return }
    
    Write-Log -Level Debug -Message "Process-TuiInput: Key=$($KeyInfo.Key), Char='$($KeyInfo.KeyChar)', Modifiers=$($KeyInfo.Modifiers)"
    
    # First priority: Command palette if active
    if ($global:TuiState.CommandPalette -and $global:TuiState.CommandPalette.IsActive) {
        Write-Log -Level Debug -Message "Routing input to CommandPalette"
        if ($global:TuiState.CommandPalette.HandleInput($KeyInfo)) {
            $global:TuiState.IsDirty = $true
            return
        }
    }
    
    # Second priority: Global hotkeys (including Ctrl+P for command palette)
    $keybindingService = $global:TuiState.Services.KeybindingService
    if ($keybindingService) {
        # Check for Ctrl+P specifically first
        if ($KeyInfo.Modifiers -band [ConsoleModifiers]::Control -and $KeyInfo.Key -eq [ConsoleKey]::P) {
            Write-Log -Level Debug -Message "Ctrl+P detected - opening command palette"
            $actionService = $global:TuiState.Services.ActionService
            if ($actionService) {
                $actionService.ExecuteAction("app.commandPalette", @{KeyInfo = $KeyInfo})
                $global:TuiState.IsDirty = $true
                return
            }
        }
        
        # Then check other global hotkeys
        if ($keybindingService.IsAction($KeyInfo)) {
            $actionName = $keybindingService.GetAction($KeyInfo)
            Write-Log -Level Debug -Message "Global hotkey detected: $actionName"
            
            $actionService = $global:TuiState.Services.ActionService
            if ($actionService) {
                $actionService.ExecuteAction($actionName, @{KeyInfo = $KeyInfo})
                $global:TuiState.IsDirty = $true
                return
            }
        }
    }
    
    # Third priority: Current screen (handles its own focus management)
    if ($global:TuiState.CurrentScreen) {
        Write-Log -Level Debug -Message "Routing input to current screen: $($global:TuiState.CurrentScreen.Name)"
        if ($global:TuiState.CurrentScreen.HandleInput($KeyInfo)) {
            $global:TuiState.IsDirty = $true
            return
        }
    }
    
    Write-Log -Level Debug -Message "Input not handled by any component"
}
