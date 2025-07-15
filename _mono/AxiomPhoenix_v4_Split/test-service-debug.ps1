#!/usr/bin/env pwsh

# Test script to verify actual service registration during startup
Write-Host "=== SERVICE REGISTRATION DEBUG ===" -ForegroundColor Yellow

# Add debug logging to the actual Process-TuiInput function
Write-Host "Patching Process-TuiInput function for debugging..." -ForegroundColor Cyan

$originalProcessTuiInput = @'
function Process-TuiInput {
    param([System.ConsoleKeyInfo]$KeyInfo)
    
    if ($null -eq $KeyInfo) { return }
    
    Write-Log -Level Debug -Message "Process-TuiInput: Key=$($KeyInfo.Key), Char='$($KeyInfo.KeyChar)', Modifiers=$($KeyInfo.Modifiers)"
    
    # DEBUG: Add detailed service checking
    Write-Log -Level Debug -Message "DEBUG: TuiState exists: $($null -ne $global:TuiState)"
    Write-Log -Level Debug -Message "DEBUG: TuiState.Services exists: $($null -ne $global:TuiState.Services)"
    if ($global:TuiState.Services) {
        Write-Log -Level Debug -Message "DEBUG: Services count: $($global:TuiState.Services.Count)"
        Write-Log -Level Debug -Message "DEBUG: Service keys: $($global:TuiState.Services.Keys -join ', ')"
        Write-Log -Level Debug -Message "DEBUG: KeybindingService exists: $($null -ne $global:TuiState.Services.KeybindingService)"
        Write-Log -Level Debug -Message "DEBUG: ActionService exists: $($null -ne $global:TuiState.Services.ActionService)"
    }
    
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
    Write-Log -Level Debug -Message "DEBUG: Retrieved KeybindingService: $($null -ne $keybindingService)"
    if ($keybindingService) {
        Write-Log -Level Debug -Message "DEBUG: KeybindingService found, checking for global hotkeys"
        
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
        $actionName = $keybindingService.GetAction($KeyInfo)
        Write-Log -Level Debug -Message "DEBUG: GetAction result: '$actionName'"
        if ($actionName) {
            Write-Log -Level Debug -Message "Global hotkey detected: $actionName"
            $actionService = $global:TuiState.Services.ActionService
            if ($actionService) {
                Write-Log -Level Debug -Message "DEBUG: Executing action: $actionName"
                $actionService.ExecuteAction($actionName, @{KeyInfo = $KeyInfo})
                $global:TuiState.IsDirty = $true
                return
            }
        }
    } else {
        Write-Log -Level Warning -Message "DEBUG: KeybindingService is NULL - global hotkeys will not work!"
    }
    
    # Third priority: Current screen (handles its own focus management)
    $navService = $global:TuiState.Services.NavigationService
    $currentScreen = if ($navService) { $navService.CurrentScreen } else { $null }
    if ($currentScreen) {
        Write-Log -Level Debug -Message "Routing input to current screen: $($currentScreen.Name)"
        if ($currentScreen.HandleInput($KeyInfo)) {
            $global:TuiState.IsDirty = $true
            return
        }
    } else {
        Write-Log -Level Warning -Message "No current screen available for input routing"
    }
    
    Write-Log -Level Debug -Message "Input not handled by any component"
}
'@

# Write the patched function to a temp file
$originalProcessTuiInput | Out-File -FilePath "./patched-input.ps1" -Encoding UTF8

Write-Host "Patched function saved to ./patched-input.ps1" -ForegroundColor Green
Write-Host "To use this patch:" -ForegroundColor Yellow
Write-Host "1. Replace the Process-TuiInput function in Runtime/ART.004_InputProcessing.ps1" -ForegroundColor Yellow
Write-Host "2. Run the application" -ForegroundColor Yellow
Write-Host "3. Press Tab key" -ForegroundColor Yellow
Write-Host "4. Check the debug logs to see exactly what's happening" -ForegroundColor Yellow

Write-Host "`n=== ALTERNATIVE: Quick service check ===" -ForegroundColor Cyan
Write-Host "You can also add this at the start of Start.ps1 to check services:" -ForegroundColor White

$serviceCheck = @'
# Add this after Start-AxiomPhoenix call to debug services
Write-Host "=== SERVICE DEBUG ===" -ForegroundColor Yellow
Write-Host "TuiState exists: $($null -ne $global:TuiState)" -ForegroundColor White  
Write-Host "Services exists: $($null -ne $global:TuiState.Services)" -ForegroundColor White
if ($global:TuiState.Services) {
    Write-Host "Service count: $($global:TuiState.Services.Count)" -ForegroundColor White
    Write-Host "Service keys: $($global:TuiState.Services.Keys -join ', ')" -ForegroundColor White
    Write-Host "KeybindingService: $($null -ne $global:TuiState.Services.KeybindingService)" -ForegroundColor White
}
Write-Host "=== END DEBUG ===" -ForegroundColor Yellow
'@

Write-Host $serviceCheck -ForegroundColor Gray