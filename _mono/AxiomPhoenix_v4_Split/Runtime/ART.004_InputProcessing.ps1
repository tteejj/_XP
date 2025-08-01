# ==============================================================================
# Axiom-Phoenix v4.1 - Input Processing
# Handles keyboard input and routes to appropriate handlers
# FIXED: Removed deprecated CommandPalette references
# FIXED: Corrected keybinding service method calls
# FIXED: Added proper dialog handling
# ==============================================================================

function Process-TuiInput {
    #Write-Host "INPUT-DEBUG: Process-TuiInput called with Key=$($KeyInfo.Key)" -ForegroundColor Blue
    param([System.ConsoleKeyInfo]$KeyInfo)
    
    if ($null -eq $KeyInfo) { return }
    
    # Write-Log -Level Debug -Message "Process-TuiInput: Key=$($KeyInfo.Key), Char='$($KeyInfo.KeyChar)', Modifiers=$($KeyInfo.Modifiers)"
    # CONSOLE LOG for immediate feedback
    #Write-Host "INPUT: Key=$($KeyInfo.Key) Char='$($KeyInfo.KeyChar)' Modifiers=$($KeyInfo.Modifiers)" -ForegroundColor Cyan
    
    # CRITICAL: Check for Ctrl+C FIRST - universal kill switch
    if ($KeyInfo.Key -eq [ConsoleKey]::C -and ($KeyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
        #Write-Host "INPUT: Ctrl+C detected - EXITING APPLICATION" -ForegroundColor Red
        $global:TuiState.Running = $false
        return
    }
    
    # First priority: Check for active dialog
    $dialogManager = $global:TuiState.Services.DialogManager
    if ($dialogManager -and $dialogManager.HasActiveDialog()) {
        $activeDialog = $dialogManager.GetActiveDialog()
        #Write-Host "INPUT: Routing input to active dialog: $($activeDialog.Name)" -ForegroundColor Magenta
        if ($activeDialog.HandleInput($KeyInfo)) {
            $global:TuiState.IsDirty = $true
            return
        }
    }
    
    # Second priority: Global hotkeys
    # PERFORMANCE: Cache service references
    $keybindingService = $global:TuiState.Services.KeybindingService
    if ($keybindingService) {
        # Check for Ctrl+P specifically for command palette
        if ($KeyInfo.Modifiers -band [ConsoleModifiers]::Control -and $KeyInfo.Key -eq [ConsoleKey]::P) {
            $actionService = $global:TuiState.Services.ActionService
            if ($actionService) {
                $actionService.ExecuteAction("app.commandPalette", @{KeyInfo = $KeyInfo})
                $global:TuiState.IsDirty = $true
                return
            }
        }
        
        # Check other global hotkeys
        $actionName = $keybindingService.GetAction($KeyInfo)
        if ($actionName) {
            $actionService = $global:TuiState.Services.ActionService
            if ($actionService) {
                $actionService.ExecuteAction($actionName, @{KeyInfo = $KeyInfo})
                $global:TuiState.IsDirty = $true
                return
            }
        }
    }
    
    # Third priority: Current screen (handles its own focus management)
    $navService = $global:TuiState.Services.NavigationService
    $currentScreen = if ($navService) { $navService.CurrentScreen } else { $null }
    #Write-Host "ROUTING: CurrentScreen = $(if ($currentScreen) { $currentScreen.GetType().Name } else { 'NULL' })" -ForegroundColor Magenta
    if ($currentScreen) {
        #Write-Host "ROUTING: Sending input to $($currentScreen.GetType().Name)" -ForegroundColor Magenta
        if ($currentScreen.HandleInput($KeyInfo)) {
            #Write-Host "ROUTING: Input handled by $($currentScreen.GetType().Name)" -ForegroundColor Green
            $global:TuiState.IsDirty = $true
            return
        } else {
            #Write-Host "ROUTING: Input NOT handled by $($currentScreen.GetType().Name)" -ForegroundColor Red
        }
    }
    
    #Write-Host "INPUT: Input not handled by any component" -ForegroundColor Yellow
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
        #Write-Host "INPUT: Error routing input to component $($Component.Name): $($_.Exception.Message)" -ForegroundColor Red
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
            #Write-Host "INPUT: Error calling OnBlur for $($global:TuiState.FocusedComponent.Name): $($_.Exception.Message)" -ForegroundColor Red
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
        #Write-Host "INPUT: Error calling OnFocus for $($Component.Name): $($_.Exception.Message)" -ForegroundColor Red
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
    $sortedComponents = $FocusableComponents.Where({ $_.IsFocusable -and $_.Visible }).OrderBy({$_.TabIndex})
    
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

