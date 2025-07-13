# ==============================================================================
# Axiom-Phoenix v4.1 - Input Processing
# Handles keyboard input and routes to appropriate handlers
# FIXED: Removed deprecated CommandPalette references
# FIXED: Corrected keybinding service method calls
# FIXED: Added proper dialog handling
# ==============================================================================

function Process-TuiInput {
    param([System.ConsoleKeyInfo]$KeyInfo)
    
    if ($null -eq $KeyInfo) { return }
    
    Write-Log -Level Debug -Message "Process-TuiInput: Key=$($KeyInfo.Key), Char='$($KeyInfo.KeyChar)', Modifiers=$($KeyInfo.Modifiers)"
    
    # CRITICAL: Check for Ctrl+C FIRST - universal kill switch
    if ($KeyInfo.Key -eq [ConsoleKey]::C -and ($KeyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
        Write-Log -Level Info -Message "Ctrl+C detected - EXITING APPLICATION"
        $global:TuiState.Running = $false
        return
    }
    
    # First priority: Check for active dialog
    $dialogManager = $global:TuiState.Services.DialogManager
    if ($dialogManager -and $dialogManager.HasActiveDialog()) {
        $activeDialog = $dialogManager.GetActiveDialog()
        Write-Log -Level Debug -Message "Routing input to active dialog: $($activeDialog.Name)"
        if ($activeDialog.HandleInput($KeyInfo)) {
            $global:TuiState.IsDirty = $true
            return
        }
    }
    
    # Second priority: Global hotkeys
    $keybindingService = $global:TuiState.Services.KeybindingService
    if ($keybindingService) {
        # Check for Ctrl+P specifically for command palette
        if ($KeyInfo.Modifiers -band [ConsoleModifiers]::Control -and $KeyInfo.Key -eq [ConsoleKey]::P) {
            Write-Log -Level Debug -Message "Ctrl+P detected - opening command palette"
            $actionService = $global:TuiState.Services.ActionService
            if ($actionService) {
                $actionService.ExecuteAction("app.commandPalette", @{KeyInfo = $KeyInfo})
                $global:TuiState.IsDirty = $true
                return
            }
        }
        
        # Check other global hotkeys with proper method signature
        $actionName = $keybindingService.GetActionForKey($KeyInfo.Key, $KeyInfo.Modifiers)
        if ($actionName) {
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

# Input routing helper for components
function Route-ComponentInput {
    param(
        [Parameter(Mandatory)]
        [UIElement]$Component,
        
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$KeyInfo
    )
    
    # Skip if component can't handle input
    if (-not $Component.IsFocusable -or -not $Component.Visible) {
        return $false
    }
    
    # Route to component's HandleInput method
    try {
        return $Component.HandleInput($KeyInfo)
    }
    catch {
        Write-Log -Level Error -Message "Error routing input to component $($Component.Name): $($_.Exception.Message)"
        return $false
    }
}

# Focus management helper
function Set-ComponentFocus {
    param(
        [Parameter(Mandatory)]
        [UIElement]$Component
    )
    
    # Clear existing focus
    if ($global:TuiState.FocusedComponent -and $global:TuiState.FocusedComponent -ne $Component) {
        try {
            if ($global:TuiState.FocusedComponent.OnBlur) {
                $global:TuiState.FocusedComponent.OnBlur.Invoke()
            }
        }
        catch {
            Write-Log -Level Warning -Message "Error calling OnBlur for $($global:TuiState.FocusedComponent.Name): $($_.Exception.Message)"
        }
    }
    
    # Set new focus
    $global:TuiState.FocusedComponent = $Component
    
    try {
        if ($Component.OnFocus) {
            $Component.OnFocus.Invoke()
        }
    }
    catch {
        Write-Log -Level Warning -Message "Error calling OnFocus for $($Component.Name): $($_.Exception.Message)"
    }
    
    $global:TuiState.IsDirty = $true
}

# Tab navigation helper
function Move-FocusToNext {
    param(
        [Parameter(Mandatory)]
        [UIElement[]]$FocusableComponents,
        
        [bool]$Reverse = $false
    )
    
    if ($FocusableComponents.Count -eq 0) {
        return
    }
    
    # Sort by TabIndex
    $sortedComponents = $FocusableComponents | Where-Object { $_.IsFocusable -and $_.Visible } | Sort-Object TabIndex
    
    if ($sortedComponents.Count -eq 0) {
        return
    }
    
    # Find current focus index
    $currentIndex = -1
    if ($global:TuiState.FocusedComponent) {
        for ($i = 0; $i -lt $sortedComponents.Count; $i++) {
            if ($sortedComponents[$i] -eq $global:TuiState.FocusedComponent) {
                $currentIndex = $i
                break
            }
        }
    }
    
    # Calculate next index
    if ($Reverse) {
        $nextIndex = if ($currentIndex -le 0) { $sortedComponents.Count - 1 } else { $currentIndex - 1 }
    } else {
        $nextIndex = if ($currentIndex -eq -1 -or $currentIndex -ge $sortedComponents.Count - 1) { 0 } else { $currentIndex + 1 }
    }
    
    # Set focus to next component
    Set-ComponentFocus -Component $sortedComponents[$nextIndex]
}
