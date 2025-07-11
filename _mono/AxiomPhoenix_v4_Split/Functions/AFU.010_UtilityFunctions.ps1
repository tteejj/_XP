# ==============================================================================
# Axiom-Phoenix v4.0 - All Functions (Load After Classes)
# Standalone functions for TUI operations and utilities
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: AFU.###" to find specific sections.
# Each section ends with "END_PAGE: AFU.###"
# ==============================================================================

#region Utility Functions

# Initialize functions removed - Start.ps1 now uses direct service instantiation

# ===== FUNCTION: Show-CommandPalette (Temporary Workaround) =====
# Module: command-palette-workaround
# Dependencies: Global TUI state
# Purpose: Alternative command palette implementation
function Show-CommandPalette {
    # Direct command palette implementation
    $actionService = $global:TuiState.Services.ActionService
    $focusManager = $global:TuiState.Services.FocusManager
    
    if (-not $actionService) {
        Write-Host "ActionService not available!" -ForegroundColor Red
        return
    }
    
    # Create a simple selection menu
    $actions = @()
    foreach ($entry in $actionService.ActionRegistry.GetEnumerator()) {
        $actions += [PSCustomObject]@{
            Key = $entry.Key
            Name = $entry.Value.Name
            Description = $entry.Value.Description
            Category = $entry.Value.Category
        }
    }
    
    # Sort by category and name
    $actions = $actions | Sort-Object Category, Name
    
    # Display in console (temporary)
    Clear-Host
    Write-Host "=== COMMAND PALETTE ===" -ForegroundColor Cyan
    Write-Host "Press number to select action, ESC to cancel" -ForegroundColor Yellow
    Write-Host ""
    
    $index = 1
    $actionMap = @{}
    foreach ($action in $actions) {
        Write-Host "[$index] [$($action.Category)] $($action.Name) - $($action.Description)"
        $actionMap[$index] = $action.Key
        $index++
    }
    
    # Get selection
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($key.VirtualKeyCode -eq 27) { # ESC
        Clear-Host
        return
    }
    
    $selection = [int]$key.Character - 48  # Convert char to number
    if ($actionMap.ContainsKey($selection)) {
        Clear-Host
        $actionService.ExecuteAction($actionMap[$selection], @{})
    } else {
        Clear-Host
    }
}

# ===== FUNCTION: Register-CommandPaletteWorkaround =====
#UNCOMMENT **ONLY** IF OTHER METHODS FAIL**
# Module: command-palette-workaround
# Dependencies: ActionService
# Purpose: Override the command palette action with temporary fix
#function Register-CommandPaletteWorkaround {
#    # Override the command palette action
#    $actionService = $global:TuiState.Services.ActionService
#    if ($actionService) {
#        $actionService.RegisterAction("app.commandPalette", {
#            Show-CommandPalette
#        }, @{
#            Category = "Application"
#            Description = "Show command palette (temporary fix)"
#            Hotkey = "Ctrl+P"
#        })
#        Write-Host "Command Palette workaround registered. Use Ctrl+P to test." -ForegroundColor Green
#    }
#}

#endregion
#<!-- END_PAGE: AFU.010 -->
