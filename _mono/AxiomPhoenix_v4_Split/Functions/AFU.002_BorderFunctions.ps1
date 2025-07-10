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

#region Border Functions

function Get-TuiBorderChars {
    [CmdletBinding()]
    param(
        [ValidateSet("Single", "Double", "Rounded", "Thick")][string]$Style = "Single"
    )
    
    $styles = @{
        Single = @{ 
            TopLeft = '┌'; TopRight = '┐'; BottomLeft = '└'; BottomRight = '┘'; 
            Horizontal = '─'; Vertical = '│' 
        }
        Double = @{ 
            TopLeft = '╔'; TopRight = '╗'; BottomLeft = '╚'; BottomRight = '╝'; 
            Horizontal = '═'; Vertical = '║' 
        }
        Rounded = @{ 
            TopLeft = '╭'; TopRight = '╮'; BottomLeft = '╰'; BottomRight = '╯'; 
            Horizontal = '─'; Vertical = '│' 
        }
        Thick = @{ 
            TopLeft = '┏'; TopRight = '┓'; BottomLeft = '┗'; BottomRight = '┛'; 
            Horizontal = '━'; Vertical = '┃' 
        }
    }
    
    $selectedStyle = $styles[$Style]
    if ($null -eq $selectedStyle) {
        Write-Warning "Get-TuiBorderChars: Border style '$Style' not found. Returning 'Single' style."
        return $styles.Single
    }
    
    Write-Verbose "Get-TuiBorderChars: Retrieved TUI border characters for style: $Style."
    return $selectedStyle
}

#endregion
#<!-- END_PAGE: AFU.002 -->
