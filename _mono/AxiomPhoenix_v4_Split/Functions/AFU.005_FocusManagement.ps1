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

#region Focus Management Functions

function Set-ComponentFocus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][UIElement]$Component
    )
    
    # Use per-screen focus management
    if ($global:TuiState.CurrentScreen) {
        $global:TuiState.CurrentScreen.SetChildFocus($Component)
    } else {
        Write-Warning "Set-ComponentFocus: No current screen available for focus management."
    }
}

#endregion
#<!-- END_PAGE: AFU.005 -->
