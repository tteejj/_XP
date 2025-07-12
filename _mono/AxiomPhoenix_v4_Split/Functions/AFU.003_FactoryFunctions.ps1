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
        $label.SetForegroundColor($ForegroundColor)
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
