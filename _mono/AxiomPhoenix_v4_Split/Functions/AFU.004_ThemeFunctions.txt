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

#region Theme Functions

function Get-ThemeColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ColorName,
        
        [string]$DefaultColor = "#808080"
    )
    
    $themeManager = $global:TuiState.Services.ThemeManager
    if ($themeManager) {
        # ThemeManager.GetColor already guarantees hex format
        $color = $themeManager.GetColor($ColorName)
        if ($color) {
            return $color
        }
    }
    
    # Write-Log -Level Debug -Message "Get-ThemeColor: Color '$ColorName' not found, using default '$DefaultColor'"
    return $DefaultColor
}

#endregion
#<!-- END_PAGE: AFU.004 -->
