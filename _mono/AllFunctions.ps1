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

#<!-- PAGE: AFU.001 - TUI Drawing Functions -->
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
    $borderStyleName = $Style.BorderStyle ?? "Single"
    $borderColor = $Style.BorderFG ?? "#808080" # Default border color (gray hex)
    $bgColor = $Style.BG ?? "#000000"           # Default background color (black hex)
    $titleColor = $Style.TitleFG ?? $borderColor # Title defaults to border color
    $fillChar = [char]($Style.FillChar ?? ' ')   # Optional fill character

    $borders = Get-TuiBorderChars -Style $borderStyleName
    
    # Define style objects for child calls to Write-TuiText.
    $generalStyle = @{ FG = $borderColor; BG = $bgColor } # For borders
    $fillStyle = @{ FG = $borderColor; BG = $bgColor }    # For fill area (fill char uses border fg)
    
    $titleTextStyle = @{ FG = $titleColor; BG = $bgColor }
    # Merge any additional title style overrides (e.g., Bold = $true for title)
    if ($Style.TitleStyle) {
        foreach ($key in $Style.TitleStyle.Keys) { $titleTextStyle[$key] = $Style.TitleStyle[$key] }
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
        if ($titleText.Length -le ($Width - 2)) {
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

#<!-- PAGE: AFU.002 - Border Functions -->
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

#<!-- PAGE: AFU.003 - Factory Functions -->
#region Factory Functions

function New-TuiBuffer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Width,
        [Parameter(Mandatory)][int]$Height,
        [string]$Name = "Unnamed"
    )
    return [TuiBuffer]::new($Width, $Height, $Name)
}

function New-TuiLabel {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Text = "",
        [int]$X = 0,
        [int]$Y = 0,
        [string]$ForegroundColor = $null
    )
    
    $label = [LabelComponent]::new($Name)
    $label.Text = $Text
    $label.X = $X
    $label.Y = $Y
    if ($ForegroundColor) {
        $label.ForegroundColor = $ForegroundColor
    }
    return $label
}

function New-TuiButton {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Text = "Button",
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Width = 10,
        [int]$Height = 3,
        [scriptblock]$OnClick = $null
    )
    
    $button = [ButtonComponent]::new($Name)
    $button.Text = $Text
    $button.X = $X
    $button.Y = $Y
    $button.Width = $Width
    $button.Height = $Height
    if ($OnClick) {
        $button.OnClick = $OnClick
    }
    return $button
}

function New-TuiTextBox {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Placeholder = "",
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Width = 20,
        [int]$Height = 3,
        [int]$MaxLength = 100,
        [scriptblock]$OnChange = $null
    )
    
    $textBox = [TextBoxComponent]::new($Name)
    $textBox.Placeholder = $Placeholder
    $textBox.X = $X
    $textBox.Y = $Y
    $textBox.Width = $Width
    $textBox.Height = $Height
    $textBox.MaxLength = $MaxLength
    if ($OnChange) {
        $textBox.OnChange = $OnChange
    }
    return $textBox
}

function New-TuiCheckBox {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Text = "Checkbox",
        [int]$X = 0,
        [int]$Y = 0,
        [bool]$Checked = $false,
        [scriptblock]$OnChange = $null
    )
    
    $checkBox = [CheckBoxComponent]::new($Name)
    $checkBox.Text = $Text
    $checkBox.X = $X
    $checkBox.Y = $Y
    $checkBox.Checked = $Checked
    if ($OnChange) {
        $checkBox.OnChange = $OnChange
    }
    return $checkBox
}

function New-TuiRadioButton {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Text = "Radio",
        [string]$GroupName = "default",
        [int]$X = 0,
        [int]$Y = 0,
        [bool]$Selected = $false,
        [scriptblock]$OnChange = $null
    )
    
    $radioButton = [RadioButtonComponent]::new($Name)
    $radioButton.Text = $Text
    $radioButton.GroupName = $GroupName
    $radioButton.X = $X
    $radioButton.Y = $Y
    $radioButton.Selected = $Selected
    if ($OnChange) {
        $radioButton.OnChange = $OnChange
    }
    return $radioButton
}

#endregion
#<!-- END_PAGE: AFU.003 -->

#<!-- PAGE: AFU.004 - Theme Functions -->
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

#<!-- PAGE: AFU.005 - Focus Management -->
#region Focus Management Functions

function Set-ComponentFocus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][UIElement]$Component
    )
    
    # This function is now obsolete - use FocusManager service instead
    $focusManager = $global:TuiState.Services.FocusManager
    if ($focusManager) {
        $focusManager.SetFocus($Component)
    } else {
        Write-Warning "Set-ComponentFocus is deprecated. FocusManager service not available."
    }
}

#endregion
#<!-- END_PAGE: AFU.005 -->

#<!-- PAGE: AFU.006 - Logging Functions -->
#region Logging Functions

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Trace', 'Debug', 'Info', 'Warning', 'Error', 'Fatal')]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [object]$Data = $null
    )
    
    $logger = $global:TuiState.Services.Logger
    if ($logger) {
        # Combine message and data into a single log entry for better correlation
        $finalMessage = $Message
        if ($Data) {
            $dataJson = $Data | ConvertTo-Json -Compress -Depth 5
            $finalMessage = "$Message | Data: $dataJson"
        }
        # Logger.Log method signature is: Log([string]$message, [string]$level = "Info")
        $logger.Log($finalMessage, $Level)
    }
    else {
        # Fallback to console if logger not available
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $prefix = "[$timestamp] [$Level]"
        
        switch ($Level) {
            'Error' { Write-Host "$prefix $Message" -ForegroundColor Red }
            'Warning' { Write-Host "$prefix $Message" -ForegroundColor Yellow }
            'Info' { Write-Host "$prefix $Message" -ForegroundColor Cyan }
            'Debug' { Write-Host "$prefix $Message" -ForegroundColor Gray }
            default { Write-Host "$prefix $Message" }
        }
    }
}

#endregion
#<!-- END_PAGE: AFU.006 -->

#<!-- PAGE: AFU.007 - Event Functions -->
#region Event System

function Subscribe-Event {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventName,
        [Parameter(Mandatory)][scriptblock]$Handler,
        [string]$Source = ""
    )
    
    if ($global:TuiState.Services.EventManager) {
        return $global:TuiState.Services.EventManager.Subscribe($EventName, $Handler)
    }
    
    # Fallback
    $subscriptionId = [Guid]::NewGuid().ToString()
    Write-Verbose "Subscribed to event '$EventName' with handler ID: $subscriptionId"
    return $subscriptionId
}

function Unsubscribe-Event {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventName,
        [Parameter(Mandatory)][string]$HandlerId
    )
    
    if ($global:TuiState.Services.EventManager) {
        $global:TuiState.Services.EventManager.Unsubscribe($EventName, $HandlerId)
    }
    Write-Verbose "Unsubscribed from event '$EventName' (Handler ID: $HandlerId)"
}

function Publish-Event {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventName,
        [hashtable]$EventData = @{}
    )
    
    if ($global:TuiState.Services.EventManager) {
        $global:TuiState.Services.EventManager.Publish($EventName, $EventData)
    }
    Write-Verbose "Published event '$EventName' with data: $($EventData | ConvertTo-Json -Compress)"
}

#endregion
#<!-- END_PAGE: AFU.007 -->

#<!-- PAGE: AFU.008 - Error Handling -->
#region Error Handling Functions

# No specific error handling functions currently implemented
# This section reserved for future error management utilities

#endregion
#<!-- END_PAGE: AFU.008 -->

#<!-- PAGE: AFU.009 - Input Processing -->
#region Input Processing Functions

# No specific input processing functions currently implemented
# This section reserved for future input handling utilities

#endregion
#<!-- END_PAGE: AFU.009 -->

#<!-- PAGE: AFU.010 - Utility Functions -->
#region Utility Functions

# Initialize functions removed - Start.ps1 now uses direct service instantiation

#endregion
#<!-- END_PAGE: AFU.010 -->
