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
#   SIMPLIFIED WINDOW-BASED INPUT MODEL
#   Only the active window (screen) gets input. Period.
#   No complex routing, no overlays, no confusion.
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
            
            # Log the key for debugging
            if ($keyInfo.Key -or $keyInfo.KeyChar) {
                Write-Log -Level Debug -Message "Process-TuiInput: Key pressed - Key: $($keyInfo.Key), KeyChar: '$($keyInfo.KeyChar)', Modifiers: $($keyInfo.Modifiers)"
            }
            
            # Get the active window from NavigationService
            $navService = $global:TuiState.Services.NavigationService
            $activeWindow = if ($navService) { $navService.CurrentScreen } else { $null }
            
            if (-not $activeWindow) {
                Write-Log -Level Warning -Message "Process-TuiInput: No active window"
                continue
            }
            
            Write-Log -Level Debug -Message "Process-TuiInput: Routing to active window: $($activeWindow.Name)"
            
            # WINDOW-BASED MODEL: Active window handles ALL input
            # Step 1: Let focused component within the window handle it first
            $focusManager = $global:TuiState.Services.FocusManager
            $focusedComponent = if ($focusManager) { $focusManager.FocusedComponent } else { $null }
            
            $handled = $false
            
            # If there's a focused component IN THIS WINDOW, let it try first
            if ($focusedComponent -and $focusedComponent.IsFocused -and $focusedComponent.Enabled) {
                # Verify the focused component belongs to the active window
                $parent = $focusedComponent.Parent
                while ($parent -and $parent -ne $activeWindow) {
                    $parent = $parent.Parent
                }
                
                if ($parent -eq $activeWindow) {
                    Write-Log -Level Debug -Message "  - Trying focused component: $($focusedComponent.Name)"
                    $handled = $focusedComponent.HandleInput($keyInfo)
                    if ($handled) {
                        Write-Log -Level Debug -Message "  - Handled by focused component"
                        $global:TuiState.IsDirty = $true
                        continue
                    }
                }
            }
            
            # Step 2: Let the window handle it (includes global keybindings, window-level actions)
            if (-not $handled) {
                Write-Log -Level Debug -Message "  - Trying window: $($activeWindow.Name)"
                $handled = $activeWindow.HandleInput($keyInfo)
                if ($handled) {
                    Write-Log -Level Debug -Message "  - Handled by window"
                    $global:TuiState.IsDirty = $true
                    continue
                }
            }
            
            # Step 3: Check global keybindings as fallback
            if (-not $handled) {
                $keybindingService = $global:TuiState.Services.KeybindingService
                if ($keybindingService) {
                    $action = $keybindingService.GetAction($keyInfo)
                    if ($action) {
                        Write-Log -Level Debug -Message "  - Executing global action: $action"
                        $actionService = $global:TuiState.Services.ActionService
                        if ($actionService) {
                            try {
                                $actionService.ExecuteAction($action, @{})
                                $global:TuiState.IsDirty = $true
                                $handled = $true
                            }
                            catch {
                                Write-Log -Level Error -Message "  - Failed to execute action '$action': $($_.Exception.Message)"
                            }
                        }
                    }
                }
            }
            
            if (-not $handled) {
                Write-Log -Level Debug -Message "  - Key not handled by any component"
            }
        }
    }
    catch {
        Write-Log -Level Error -Message "Input processing error: $($_.Exception.Message)"
    }
}

#endregion
#<!-- END_PAGE: ART.004 -->
