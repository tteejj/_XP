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

#region Overlay Management

function Show-TuiOverlay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [UIElement]$Overlay
    )
    
    Write-Warning "Show-TuiOverlay is deprecated. Use DialogManager.ShowDialog() for dialogs or manage overlays directly."
    
    # Use DialogManager if the overlay is a Dialog
    if ($Overlay.GetType().Name -match "Dialog") {
        $dialogManager = $global:TuiState.Services.DialogManager
        if ($dialogManager) {
            $dialogManager.ShowDialog($Overlay)
            return
        }
    }
    
    # For non-dialog overlays, handle manually (deprecated path)
    if (-not $global:TuiState.OverlayStack) {
        $global:TuiState.OverlayStack = [System.Collections.Generic.List[UIElement]]::new()
    }
    
    # Position overlay at center
    $consoleWidth = $global:TuiState.BufferWidth
    $consoleHeight = $global:TuiState.BufferHeight
    $Overlay.X = [Math]::Max(0, [Math]::Floor(($consoleWidth - $Overlay.Width) / 2))
    $Overlay.Y = [Math]::Max(0, [Math]::Floor(($consoleHeight - $Overlay.Height) / 2))
    
    $Overlay.Visible = $true
    $Overlay.IsOverlay = $true
    $global:TuiState.OverlayStack.Add($Overlay)
    $global:TuiState.IsDirty = $true
    
    # Write-Log -Level Debug -Message "Show-TuiOverlay: Displayed overlay '$($Overlay.Name)' at X=$($Overlay.X), Y=$($Overlay.Y)"
}

function Close-TopTuiOverlay {
    [CmdletBinding()]
    param()
    
    Write-Warning "Close-TopTuiOverlay is deprecated. Use DialogManager.HideDialog() for dialogs or manage overlays directly."
    
    if ($global:TuiState.OverlayStack.Count -eq 0) {
        # Write-Log -Level Warning -Message "Close-TopTuiOverlay: No overlays to close"
        return
    }
    
    $topOverlay = $global:TuiState.OverlayStack[-1]
    
    # Use DialogManager if it's a Dialog
    if ($topOverlay.GetType().Name -match "Dialog") {
        $dialogManager = $global:TuiState.Services.DialogManager
        if ($dialogManager) {
            $dialogManager.HideDialog($topOverlay)
            return
        }
    }
    
    # Manual removal for non-dialog overlays (deprecated path)
    $global:TuiState.OverlayStack.RemoveAt($global:TuiState.OverlayStack.Count - 1)
    $topOverlay.Visible = $false
    $topOverlay.IsOverlay = $false
    $topOverlay.Cleanup()
    $global:TuiState.IsDirty = $true
    
    # Write-Log -Level Debug -Message "Close-TopTuiOverlay: Closed overlay '$($topOverlay.Name)'"
}

#endregion
#<!-- END_PAGE: ART.005 -->
