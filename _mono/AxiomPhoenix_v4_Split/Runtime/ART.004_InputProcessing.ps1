####\AllRuntime.ps1
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

#region Input Processing

# PURPOSE:
#   Re-architects the input loop to be "focus-first," establishing a clear and correct
#   input processing hierarchy. This is the definitive fix for the UI lockup.
#
# LOGIC:
#   1. PRIORITY 1: FOCUSED COMPONENT - The component currently tracked by the FocusManager
#      (e.g., the CommandPalette's text box) ALWAYS gets the first chance to handle the key.
#      If it returns $true, the input cycle for that key is complete.
#   2. PRIORITY 2: BUBBLE TO OVERLAY - If the focused component returns $false, and an
#      overlay is active, the overlay container itself gets a chance to handle the key.
#      This is for container-level actions like 'Escape' to close. The input cycle stops
#      here to enforce modality.
#   3. PRIORITY 3 & 4: GLOBALS & SCREEN - If no overlay is active, the event continues
#      to global keybindings and finally to the base screen.
#
function Process-TuiInput {
    [CmdletBinding()]
    param()
    
    try {
        while ([Console]::KeyAvailable) {
            $keyInfo = [Console]::ReadKey($true)
            
            # Emergency exit - Ctrl+C always works
            if ($keyInfo.Key -eq [ConsoleKey]::C -and ($keyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
                $global:TuiState.Running = $false
                return
            }
            
            # Get services from global state
            $focusManager = $global:TuiState.Services.FocusManager
            $keybindingService = $global:TuiState.Services.KeybindingService
            $actionService = $global:TuiState.Services.ActionService
            
            $inputHandled = $false
            
            # Priority 1: Focused component gets first chance
            $focusedComponent = if ($focusManager) { $focusManager.FocusedComponent } else { $null }
            
            if ($focusedComponent -and $focusedComponent.IsFocused -and $focusedComponent.Enabled) {
                Write-Log -Level Debug -Message "Process-TuiInput: Trying focused component: $($focusedComponent.Name)"
                if ($focusedComponent.HandleInput($keyInfo)) {
                    $global:TuiState.IsDirty = $true
                    Write-Log -Level Debug -Message "  - Input handled by focused component"
                    continue  # Input was handled, move to next key
                }
            }
            
            # Priority 2: If overlay is active, check if it wants to handle the input
            # But don't enforce strict modality - let focused components handle their input
            if ($global:TuiState.OverlayStack -and $global:TuiState.OverlayStack.Count -gt 0) {
                $topOverlay = $global:TuiState.OverlayStack[-1]
                Write-Log -Level Debug -Message "  - Checking overlay: $($topOverlay.Name)"
                if ($topOverlay -and $topOverlay.HandleInput($keyInfo)) {
                    $global:TuiState.IsDirty = $true
                    Write-Log -Level Debug -Message "  - Input handled by overlay"
                    continue  # Only continue if overlay actually handled it
                }
                # Don't enforce modality - let the input continue to other handlers
            }
            
            # Priority 3: Global keybindings (only if no overlay is active)
            if ($keybindingService) {
                $action = $keybindingService.GetAction($keyInfo)
                if ($action) {
                    Write-Log -Level Debug -Message "Process-TuiInput: Executing global action: $action"
                    if ($actionService) {
                        try {
                            $actionService.ExecuteAction($action, @{})
                            $global:TuiState.IsDirty = $true
                        }
                        catch {
                            Write-Log -Level Error -Message "Process-TuiInput: Failed to execute action '$action': $($_.Exception.Message)"
                        }
                    }
                    continue
                }
            }
            
            # Priority 4: Current screen gets the final chance (only if no overlay is active)
            if ($global:TuiState.CurrentScreen) {
                if ($global:TuiState.CurrentScreen.HandleInput($keyInfo)) {
                    $global:TuiState.IsDirty = $true
                }
            }
        }
    }
    catch {
        Write-Log -Level Error -Message "Input processing error: $($_.Exception.Message)"
    }
}

#endregion
#<!-- END_PAGE: ART.004 -->
