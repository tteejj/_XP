# ==============================================================================
# TUI Components Module v5.0
# Core interactive UI components with theme integration and advanced features
# ==============================================================================

using module ui-classes
using module tui-primitives
using module theme-manager
using namespace System.Management.Automation

#region Core UI Components

class LabelComponent : UIElement {
    [string]$Text = ""
    [object]$ForegroundColor

    LabelComponent([string]$name) : base($name) {
        $this.IsFocusable = $false
        $this.Width = 10
        $this.Height = 1
        Write-Verbose "LabelComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = $this.ForegroundColor ?? (Get-ThemeColor 'Foreground')
            $bg = Get-ThemeColor 'Background'
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $this.Text -ForegroundColor $fg -BackgroundColor $bg
            Write-Verbose "LabelComponent '$($this.Name)': Rendered text '$($this.Text)'"
        }
        catch {
            Write-Error "LabelComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $false # Labels don't handle input
    }

    [string] ToString() {
        return "LabelComponent(Name='$($this.Name)', Text='$($this.Text)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

class ButtonComponent : UIElement {
    [string]$Text = "Button"
    [bool]$IsPressed = $false
    [scriptblock]$OnClick

    ButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 10
        $this.Height = 3
        Write-Verbose "ButtonComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Determine state for theme colors
            $state = if ($this.IsPressed) { "pressed" } elseif ($this.IsFocused) { "focus" } else { "normal" }
            
            # Get theme colors based on state
            $bgColor = Get-ThemeColor "button.$state.background"
            $borderColor = Get-ThemeColor "button.$state.border"
            $fgColor = Get-ThemeColor "button.$state.foreground"
            
            # Fallback to basic theme colors if specific button colors not available
            if (-not $bgColor) {
                $bgColor = if ($this.IsPressed) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Background' }
            }
            if (-not $borderColor) {
                $borderColor = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Border' }
            }
            if (-not $fgColor) {
                $fgColor = if ($this.IsPressed) { Get-ThemeColor 'Background' } else { Get-ThemeColor 'Foreground' }
            }

            # Clear buffer and draw button
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
            
            # Center text
            $textX = [Math]::Floor(($this.Width - $this.Text.Length) / 2)
            $textY = [Math]::Floor(($this.Height - 1) / 2)
            Write-TuiText -Buffer $this._private_buffer -X $textX -Y $textY -Text $this.Text -ForegroundColor $fgColor -BackgroundColor $bgColor
            
            Write-Verbose "ButtonComponent '$($this.Name)': Rendered in state '$state'"
        }
        catch {
            Write-Error "ButtonComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            try {
                $this.IsPressed = $true
                $this.RequestRedraw()
                
                if ($this.OnClick) {
                    Invoke-WithErrorHandling -Component "$($this.Name).OnClick" -ScriptBlock {
                        & $this.OnClick
                    }
                }
                
                # Brief visual feedback
                Start-Sleep -Milliseconds 50
                $this.IsPressed = $false
                $this.RequestRedraw()
                
                Write-Verbose "ButtonComponent '$($this.Name)': Click event handled"
                return $true
            }
            catch {
                Write-Error "ButtonComponent '$($this.Name)': Error handling click: $($_.Exception.Message)"
                $this.IsPressed = $false
                $this.RequestRedraw()
            }
        }
        return $false
    }

    [string] ToString() {
        return "ButtonComponent(Name='$($this.Name)', Text='$($this.Text)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

class TextBoxComponent : UIElement {
    [string]$Text = ""
    [string]$Placeholder = ""
    [ValidateRange(1, [int]::MaxValue)][int]$MaxLength = 100
    [int]$CursorPosition = 0
    [scriptblock]$OnChange
    hidden [int]$_scrollOffset = 0 # Tracks the start of the visible text window

    TextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3
        Write-Verbose "TextBoxComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = Get-ThemeColor 'Background'
            $borderColor = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Border' }
            $textColor = Get-ThemeColor 'Foreground'
            $placeholderColor = Get-ThemeColor 'Subtle'
            
            # Clear buffer and draw border
            $this._private_buffer.Clear([TuiCell]::new(' ', $textColor, $bgColor))
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor

            $textAreaWidth = $this.Width - 2
            $displayText = $this.Text ?? ""
            $currentTextColor = $textColor

            # Show placeholder if empty and not focused
            if ([string]::IsNullOrEmpty($displayText) -and -not $this.IsFocused) {
                $displayText = $this.Placeholder ?? ""
                $currentTextColor = $placeholderColor
            }

            # Apply viewport scrolling
            if ($displayText.Length -gt $textAreaWidth) {
                $displayText = $displayText.Substring($this._scrollOffset, [Math]::Min($textAreaWidth, $displayText.Length - $this._scrollOffset))
            }

            # Draw text
            if (-not [string]::IsNullOrEmpty($displayText)) {
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $displayText -ForegroundColor $currentTextColor -BackgroundColor $bgColor
            }

            # Render non-destructive block cursor
            if ($this.IsFocused) {
                $cursorX = 1 + ($this.CursorPosition - $this._scrollOffset)
                if ($cursorX -ge 1 -and $cursorX -lt ($this.Width - 1)) {
                    $cell = $this._private_buffer.GetCell($cursorX, 1)
                    if ($null -ne $cell) {
                        $cell.BackgroundColor = Get-ThemeColor 'Accent'
                        $cell.ForegroundColor = Get-ThemeColor 'Background'
                        $this._private_buffer.SetCell($cursorX, 1, $cell)
                    }
                }
            }
            
            Write-Verbose "TextBoxComponent '$($this.Name)': Rendered text (length: $($this.Text.Length), cursor: $($this.CursorPosition))"
        }
        catch {
            Write-Error "TextBoxComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        try {
            $currentText = $this.Text ?? ""
            $cursorPos = $this.CursorPosition
            $originalText = $currentText
            $handled = $true

            switch ($key.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($cursorPos -gt 0) {
                        $this.Text = $currentText.Remove($cursorPos - 1, 1)
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($cursorPos -lt $currentText.Length) {
                        $this.Text = $currentText.Remove($cursorPos, 1)
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($cursorPos -gt 0) {
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($cursorPos -lt $this.Text.Length) {
                        $this.CursorPosition++
                    }
                }
                ([ConsoleKey]::Home) {
                    $this.CursorPosition = 0
                }
                ([ConsoleKey]::End) {
                    $this.CursorPosition = $this.Text.Length
                }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar) -and $currentText.Length -lt $this.MaxLength) {
                        $this.Text = $currentText.Insert($cursorPos, $key.KeyChar)
                        $this.CursorPosition++
                    } else {
                        $handled = $false
                    }
                }
            }

            if ($handled) {
                $this._UpdateScrollOffset()
                
                # Trigger change event if text changed
                if ($this.Text -ne $originalText -and $this.OnChange) {
                    Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock {
                        & $this.OnChange -NewValue $this.Text
                    }
                }
                
                $this.RequestRedraw()
                Write-Verbose "TextBoxComponent '$($this.Name)': Input handled, new text: '$($this.Text)'"
            }
            
            return $handled
        }
        catch {
            Write-Error "TextBoxComponent '$($this.Name)': Error handling input: $($_.Exception.Message)"
            return $false
        }
    }

    # Update scroll offset to keep cursor visible
    hidden [void] _UpdateScrollOffset() {
        $textAreaWidth = $this.Width - 2
        
        # Scroll right if cursor is beyond visible area
        if ($this.CursorPosition -gt ($this._scrollOffset + $textAreaWidth - 1)) {
            $this._scrollOffset = $this.CursorPosition - $textAreaWidth + 1
        }
        
        # Scroll left if cursor is before visible area
        if ($this.CursorPosition -lt $this._scrollOffset) {
            $this._scrollOffset = $this.CursorPosition
        }
        
        # Ensure scroll offset is within bounds
        $maxScroll = [Math]::Max(0, $this.Text.Length - $textAreaWidth)
        $this._scrollOffset = [Math]::Min($this._scrollOffset, $maxScroll)
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
    }

    [string] ToString() {
        return "TextBoxComponent(Name='$($this.Name)', Text='$($this.Text)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

class CheckBoxComponent : UIElement {
    [string]$Text = "Checkbox"
    [bool]$Checked = $false
    [scriptblock]$OnChange

    CheckBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
        Write-Verbose "CheckBoxComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Foreground' }
            $bg = Get-ThemeColor 'Background'
            
            $checkbox = if ($this.Checked) { "[X]" } else { "[ ]" }
            $displayText = "$checkbox $($this.Text)"
            
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg -BackgroundColor $bg
            Write-Verbose "CheckBoxComponent '$($this.Name)': Rendered (Checked: $($this.Checked))"
        }
        catch {
            Write-Error "CheckBoxComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            try {
                $this.Checked = -not $this.Checked
                
                if ($this.OnChange) {
                    Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock {
                        & $this.OnChange -NewValue $this.Checked
                    }
                }
                
                $this.RequestRedraw()
                Write-Verbose "CheckBoxComponent '$($this.Name)': State changed to $($this.Checked)"
                return $true
            }
            catch {
                Write-Error "CheckBoxComponent '$($this.Name)': Error handling toggle: $($_.Exception.Message)"
            }
        }
        return $false
    }

    [string] ToString() {
        return "CheckBoxComponent(Name='$($this.Name)', Text='$($this.Text)', Checked=$($this.Checked), Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

class RadioButtonComponent : UIElement {
    [string]$Text = "Option"
    [bool]$Selected = $false
    [string]$GroupName = ""
    [scriptblock]$OnChange

    RadioButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
        Write-Verbose "RadioButtonComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Foreground' }
            $bg = Get-ThemeColor 'Background'
            
            $radio = if ($this.Selected) { "(●)" } else { "( )" }
            $displayText = "$radio $($this.Text)"
            
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg -BackgroundColor $bg
            Write-Verbose "RadioButtonComponent '$($this.Name)': Rendered (Selected: $($this.Selected))"
        }
        catch {
            Write-Error "RadioButtonComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            try {
                if (-not $this.Selected) {
                    $this.Selected = $true
                    
                    # Unselect other radio buttons in the same group
                    if ($this.Parent -and $this.GroupName) {
                        $this.Parent.Children | Where-Object { 
                            $_ -is [RadioButtonComponent] -and $_.GroupName -eq $this.GroupName -and $_ -ne $this 
                        } | ForEach-Object {
                            $_.Selected = $false
                            $_.RequestRedraw()
                        }
                    }
                    
                    if ($this.OnChange) {
                        Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock {
                            & $this.OnChange -NewValue $this.Selected
                        }
                    }
                    
                    $this.RequestRedraw()
                    Write-Verbose "RadioButtonComponent '$($this.Name)': Selected in group '$($this.GroupName)'"
                }
                return $true
            }
            catch {
                Write-Error "RadioButtonComponent '$($this.Name)': Error handling selection: $($_.Exception.Message)"
            }
        }
        return $false
    }

    [string] ToString() {
        return "RadioButtonComponent(Name='$($this.Name)', Text='$($this.Text)', Selected=$($this.Selected), Group='$($this.GroupName)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

#endregion

#region Factory Functions

function New-TuiLabel {
    <#
    .SYNOPSIS
    Creates a new Label component with specified properties.
    
    .DESCRIPTION
    Factory function to create a LabelComponent with configurable properties.
    
    .PARAMETER Props
    Hashtable of properties to apply to the label component.
    
    .EXAMPLE
    $label = New-TuiLabel -Props @{
        Name = "StatusLabel"
        Text = "Ready"
        ForegroundColor = [ConsoleColor]::Green
    }
    #>
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $labelName = $Props.Name ?? "Label_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $label = [LabelComponent]::new($labelName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($label.PSObject.Properties.Match($_.Name)) {
                $label.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created label '$labelName' with $($Props.Count) properties"
        return $label
    }
    catch {
        Write-Error "Failed to create label: $($_.Exception.Message)"
        throw
    }
}

function New-TuiButton {
    <#
    .SYNOPSIS
    Creates a new Button component with specified properties.
    
    .DESCRIPTION
    Factory function to create a ButtonComponent with configurable properties.
    
    .PARAMETER Props
    Hashtable of properties to apply to the button component.
    
    .EXAMPLE
    $button = New-TuiButton -Props @{
        Name = "SubmitButton"
        Text = "Submit"
        OnClick = { Write-Host "Submitted!" }
    }
    #>
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $buttonName = $Props.Name ?? "Button_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $button = [ButtonComponent]::new($buttonName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($button.PSObject.Properties.Match($_.Name)) {
                $button.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created button '$buttonName' with $($Props.Count) properties"
        return $button
    }
    catch {
        Write-Error "Failed to create button: $($_.Exception.Message)"
        throw
    }
}

function New-TuiTextBox {
    <#
    .SYNOPSIS
    Creates a new TextBox component with specified properties.
    
    .DESCRIPTION
    Factory function to create a TextBoxComponent with configurable properties.
    
    .PARAMETER Props
    Hashtable of properties to apply to the textbox component.
    
    .EXAMPLE
    $textBox = New-TuiTextBox -Props @{
        Name = "InputField"
        Placeholder = "Enter text here"
        MaxLength = 50
        OnChange = { param($NewValue) Write-Host "Text changed: $NewValue" }
    }
    #>
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $textBoxName = $Props.Name ?? "TextBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $textBox = [TextBoxComponent]::new($textBoxName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($textBox.PSObject.Properties.Match($_.Name)) {
                $textBox.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created textbox '$textBoxName' with $($Props.Count) properties"
        return $textBox
    }
    catch {
        Write-Error "Failed to create textbox: $($_.Exception.Message)"
        throw
    }
}

function New-TuiCheckBox {
    <#
    .SYNOPSIS
    Creates a new CheckBox component with specified properties.
    
    .DESCRIPTION
    Factory function to create a CheckBoxComponent with configurable properties.
    
    .PARAMETER Props
    Hashtable of properties to apply to the checkbox component.
    
    .EXAMPLE
    $checkBox = New-TuiCheckBox -Props @{
        Name = "AgreeCheckbox"
        Text = "I agree to the terms"
        OnChange = { param($NewValue) Write-Host "Checkbox changed: $NewValue" }
    }
    #>
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $checkBoxName = $Props.Name ?? "CheckBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $checkBox = [CheckBoxComponent]::new($checkBoxName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($checkBox.PSObject.Properties.Match($_.Name)) {
                $checkBox.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created checkbox '$checkBoxName' with $($Props.Count) properties"
        return $checkBox
    }
    catch {
        Write-Error "Failed to create checkbox: $($_.Exception.Message)"
        throw
    }
}

function New-TuiRadioButton {
    <#
    .SYNOPSIS
    Creates a new RadioButton component with specified properties.
    
    .DESCRIPTION
    Factory function to create a RadioButtonComponent with configurable properties.
    
    .PARAMETER Props
    Hashtable of properties to apply to the radio button component.
    
    .EXAMPLE
    $radioButton = New-TuiRadioButton -Props @{
        Name = "Option1"
        Text = "Option 1"
        GroupName = "MyGroup"
        OnChange = { param($NewValue) Write-Host "Radio button changed: $NewValue" }
    }
    #>
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $radioButtonName = $Props.Name ?? "RadioButton_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $radioButton = [RadioButtonComponent]::new($radioButtonName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($radioButton.PSObject.Properties.Match($_.Name)) {
                $radioButton.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created radio button '$radioButtonName' with $($Props.Count) properties"
        return $radioButton
    }
    catch {
        Write-Error "Failed to create radio button: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Module Exports

# Export public functions
Export-ModuleMember -Function New-TuiLabel, New-TuiButton, New-TuiTextBox, New-TuiCheckBox, New-TuiRadioButton

# Classes are automatically exported in PowerShell 7+
# LabelComponent, ButtonComponent, TextBoxComponent, CheckBoxComponent, RadioButtonComponent classes are available when module is imported

#endregion