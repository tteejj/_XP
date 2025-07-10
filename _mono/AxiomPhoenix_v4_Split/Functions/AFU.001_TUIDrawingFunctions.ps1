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

#region TUI Drawing Functions

function Write-TuiText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][TuiBuffer]$Buffer,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][string]$Text,
        [hashtable]$Style = @{} # Accepts a hashtable for all style properties
    )
    
    if ($null -eq $Buffer -or [string]::IsNullOrEmpty($Text)) { 
        # Write-Log -Level Debug -Message "Write-TuiText: Skipped for buffer '$($Buffer.Name)' due to empty text."
        return 
    }
    
    # Now simply pass the style hashtable to TuiBuffer.WriteString
    $Buffer.WriteString($X, $Y, $Text, $Style)
    
    # Write-Log -Level Debug -Message "Write-TuiText: Wrote '$Text' to buffer '$($Buffer.Name)' at ($X, $Y)."
}

function Write-TuiBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][TuiBuffer]$Buffer,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][int]$Width,
        [Parameter(Mandatory)][int]$Height,
        [string]$Title = "",
        [hashtable]$Style = @{} # All visual aspects now passed via Style hashtable
    )
    
    if ($null -eq $Buffer -or $Width -le 0 -or $Height -le 0) {
        # Write-Log -Level Warning -Message "Write-TuiBox: Invalid dimensions ($($Width)x$($Height)). Dimensions must be positive."
        return
    }

    # Extract properties from the style object with safe fallbacks.
    $borderStyleName = if ($Style.ContainsKey('BorderStyle')) { $Style['BorderStyle'] } else { "Single" }
    $borderColor = if ($Style.ContainsKey('BorderFG')) { $Style['BorderFG'] } else { "#808080" } # Default border color (gray hex)
    $bgColor = if ($Style.ContainsKey('BG')) { $Style['BG'] } else { "#000000" }           # Default background color (black hex)
    $titleColor = if ($Style.ContainsKey('TitleFG')) { $Style['TitleFG'] } else { $borderColor } # Title defaults to border color
    $fillChar = if ($Style.ContainsKey('FillChar')) { [char]$Style['FillChar'] } else { ' ' }   # Optional fill character

    $borders = Get-TuiBorderChars -Style $borderStyleName
    
    # Define style objects for child calls to Write-TuiText.
    $generalStyle = @{ FG = $borderColor; BG = $bgColor } # For borders
    $fillStyle = @{ FG = $borderColor; BG = $bgColor }    # For fill area (fill char uses border fg)
    
    $titleTextStyle = @{ FG = $titleColor; BG = $bgColor }
    # Merge any additional title style overrides (e.g., Bold = $true for title)
    if ($Style.ContainsKey('TitleStyle') -and $Style['TitleStyle']) {
        foreach ($key in $Style['TitleStyle'].Keys) { $titleTextStyle[$key] = $Style['TitleStyle'][$key] }
    }

    # Fill background of the entire box area first
    $Buffer.FillRect($X, $Y, $Width, $Height, $fillChar, $fillStyle)
    
    # Top border - handle edge cases for small dimensions
    if ($Height -gt 0) {
        if ($Width > 2) {
            # Normal case: Width >= 3
            $middlePart = $borders.Horizontal * ($Width - 2)
            Write-TuiText -Buffer $Buffer -X $X -Y $Y -Text "$($borders.TopLeft)$middlePart$($borders.TopRight)" -Style $generalStyle
        } elseif ($Width -eq 2) {
            # Special case: Width = 2 (just corners)
            Write-TuiText -Buffer $Buffer -X $X -Y $Y -Text "$($borders.TopLeft)$($borders.TopRight)" -Style $generalStyle
        } elseif ($Width -eq 1) {
            # Special case: Width = 1 (just a vertical line segment)
            $Buffer.SetCell($X, $Y, [TuiCell]::new($borders.Vertical, $generalStyle.FG, $generalStyle.BG))
        }
    }

    # Side borders
    for ($i = 1; $i -lt ($Height - 1); $i++) {
        Write-TuiText -Buffer $Buffer -X $X -Y ($Y + $i) -Text $borders.Vertical -Style $generalStyle
        if ($Width -gt 1) {
            Write-TuiText -Buffer $Buffer -X ($X + $Width - 1) -Y ($Y + $i) -Text $borders.Vertical -Style $generalStyle
        }
    }
    
    # Bottom border - handle edge cases for small dimensions
    if ($Height -gt 1) {
        if ($Width > 2) {
            # Normal case: Width >= 3
            $middlePart = $borders.Horizontal * ($Width - 2)
            Write-TuiText -Buffer $Buffer -X $X -Y ($Y + $Height - 1) -Text "$($borders.BottomLeft)$middlePart$($borders.BottomRight)" -Style $generalStyle
        } elseif ($Width -eq 2) {
            # Special case: Width = 2 (just corners)
            Write-TuiText -Buffer $Buffer -X $X -Y ($Y + $Height - 1) -Text "$($borders.BottomLeft)$($borders.BottomRight)" -Style $generalStyle
        } elseif ($Width -eq 1) {
            # Special case: Width = 1 (just a vertical line segment)
            $Buffer.SetCell($X, $Y + $Height - 1, [TuiCell]::new($borders.Vertical, $generalStyle.FG, $generalStyle.BG))
        }
    }

    # Draw title if specified
    if (-not [string]::IsNullOrEmpty($Title) -and $Y -ge 0 -and $Y -lt $Buffer.Height) {
        $titleText = " $Title "
        
        # Truncate title if too long
        $maxTitleLength = $Width - 2
        if ($titleText.Length -gt $maxTitleLength -and $maxTitleLength -gt 3) {
            $titleText = $titleText.Substring(0, $maxTitleLength - 3) + "..."
        }
        
        if ($titleText.Length -le ($Width - 2) -and $Width -gt 2) {
            $titleAlignment = $Style.TitleAlignment ?? "TopBorder" # Default to current behavior
            $titleX = $X + [Math]::Floor(($Width - $titleText.Length) / 2)
            
            # Calculate title Y position based on alignment
            $titleY = $Y # Default to top border
            switch ($titleAlignment) {
                "TopBorder" { $titleY = $Y }  # Default - on the top border
                "Top" { $titleY = $Y + 1 }    # Just inside the top border
                "Center" { $titleY = $Y + [Math]::Floor($Height / 2) }  # Vertically centered
                "Bottom" { $titleY = $Y + $Height - 2 }  # Just inside the bottom border
                default { $titleY = $Y }      # Fallback to top border
            }
            
            # Ensure title Y is within buffer bounds
            if ($titleY -ge 0 -and $titleY -lt $Buffer.Height) {
                Write-TuiText -Buffer $Buffer -X $titleX -Y $titleY -Text $titleText -Style $titleTextStyle
            }
        }
    }
    
    $Buffer.IsDirty = $true
    # Write-Log -Level Debug -Message "Write-TuiBox: Drew '$borderStyleName' box on buffer '$($Buffer.Name)' at ($X, $Y) with dimensions $($Width)x$($Height)."
}

#endregion
#<!-- END_PAGE: AFU.001 -->
