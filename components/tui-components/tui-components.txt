####\components\tui-components.psm1
# TUI Component Library - Phase 1 Migration Complete
# All components now inherit from UIElement and use buffer-based rendering

#using module '.\tui-primitives.psm1'
#using module '.\ui-classes.psm1'
#using module '..\modules\exceptions.psm1'
#using module '..\modules\logger.psm1'

#region Core UI Components

# AI: REFACTORED - LabelComponent now properly inherits from UIElement
class LabelComponent : UIElement {
    [string]$Text = ""
    [object]$ForegroundColor
    
    LabelComponent([string]$name) : base($name) {
        $this.IsFocusable = $false
        $this.Width = 10
        $this.Height = 1
    }
    
    [void] OnRender() {
        # AI: REFACTORED - Renders to its own private buffer.
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = $this.ForegroundColor ?? [ConsoleColor]::White
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $this.Text -ForegroundColor $fg

        } catch { 
            Write-Log -Level Error -Message "Label render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $false # Labels don't handle input
    }
}

# AI: REFACTORED - ButtonComponent updated for buffer-based rendering
class ButtonComponent : UIElement {
    [string]$Text = "Button"
    [bool]$IsPressed = $false
    [scriptblock]$OnClick
    
    ButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 10
        $this.Height = 3
        $this.Text = "Button"
    }
    
    [void] OnRender() {
        # AI: REFACTORED - Renders to its own private buffer, not the parent's.
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))

            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            $bgColor = $this.IsPressed ? [ConsoleColor]::Yellow : [ConsoleColor]::Black
            $fgColor = $this.IsPressed ? [ConsoleColor]::Black : $borderColor
            
            # Render border to own buffer
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
            
            # Render text centered in own buffer
            $textX = [Math]::Floor(($this.Width - $this.Text.Length) / 2)
            $textY = [Math]::Floor(($this.Height - 1) / 2)
            Write-TuiText -Buffer $this._private_buffer -X $textX -Y $textY -Text $this.Text -ForegroundColor $fgColor -BackgroundColor $bgColor

        } catch { 
            Write-Log -Level Error -Message "Button render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                $this.IsPressed = $true
                $this.RequestRedraw()
                
                if ($this.OnClick) { 
                    Invoke-WithErrorHandling -Component "$($this.Name).OnClick" -ScriptBlock { & $this.OnClick }
                }
                
                Start-Sleep -Milliseconds 50 # Visual feedback for press
                $this.IsPressed = $false
                $this.RequestRedraw()
                return $true
            }
        } catch { 
            Write-Log -Level Error -Message "Button input error for '$($this.Name)': $_" 
        }
        return $false
    }
}

# AI: REFACTORED - TextBoxComponent with buffer-based rendering
class TextBoxComponent : UIElement {
    [string]$Text = ""
    [string]$Placeholder = ""
    [int]$MaxLength = 100
    [int]$CursorPosition = 0
    [scriptblock]$OnChange
    
    TextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3
        $this.MaxLength = 100
    }
    
    [void] OnRender() {
        # AI: REFACTORED - Renders to its own private buffer.
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            
            # Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)

            # Display text or placeholder
            $displayText = $this.Text ?? ""
            $textColor = [ConsoleColor]::White
            if ([string]::IsNullOrEmpty($displayText) -and -not $this.IsFocused) { 
                $displayText = $this.Placeholder ?? "" 
                $textColor = [ConsoleColor]::DarkGray
            }
            
            $maxDisplayLength = $this.Width - 2
            if ($displayText.Length > $maxDisplayLength) { 
                $displayText = $displayText.Substring(0, $maxDisplayLength) 
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $displayText -ForegroundColor $textColor
            
            # Draw cursor if focused
            if ($this.IsFocused -and ($this.CursorPosition -le $displayText.Length)) {
                $cursorX = 1 + $this.CursorPosition
                # Only draw cursor if it's within the visible area
                # AI: FIX - Changed '<' to '-lt' to avoid PowerShell parser ambiguity
                if ($cursorX -lt ($this.Width - 1)) {
                    Write-TuiText -Buffer $this._private_buffer -X $cursorX -Y 1 -Text "_" -ForegroundColor [ConsoleColor]::Yellow
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "TextBox render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $currentText = $this.Text ?? ""
            $cursorPos = $this.CursorPosition ?? 0
            $originalText = $currentText
            $handled = $true
            
            switch ($key.Key) {
                ([ConsoleKey]::Backspace) { 
                    if ($cursorPos -gt 0) { 
                        $currentText = $currentText.Remove($cursorPos - 1, 1)
                        $cursorPos-- 
                    } 
                }
                ([ConsoleKey]::Delete) { 
                    if ($cursorPos -lt $currentText.Length) { 
                        $currentText = $currentText.Remove($cursorPos, 1) 
                    } 
                }
                ([ConsoleKey]::LeftArrow) { 
                    if ($cursorPos -gt 0) { $cursorPos-- } 
                }
                ([ConsoleKey]::RightArrow) { 
                    if ($cursorPos -lt $currentText.Length) { $cursorPos++ } 
                }
                ([ConsoleKey]::Home) { $cursorPos = 0 }
                ([ConsoleKey]::End) { $cursorPos = $currentText.Length }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar) -and $currentText.Length -lt $this.MaxLength) { 
                        $currentText = $currentText.Insert($cursorPos, $key.KeyChar)
                        $cursorPos++ 
                    } else { 
                        $handled = $false
                    }
                }
            }
            
            if ($handled) {
                if ($currentText -ne $originalText -or $cursorPos -ne $this.CursorPosition) {
                    $this.Text = $currentText
                    $this.CursorPosition = $cursorPos
                    if ($this.OnChange) { 
                        Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock { 
                            & $this.OnChange -NewValue $currentText 
                        }
                    }
                    $this.RequestRedraw()
                }
            }
            return $handled
        } catch { 
            Write-Log -Level Error -Message "TextBox input error for '$($this.Name)': $_"
            return $false 
        }
    }
}

# AI: NEW - CheckBoxComponent converted from functional to class-based
class CheckBoxComponent : UIElement {
    [string]$Text = "Checkbox"
    [bool]$Checked = $false
    [scriptblock]$OnChange
    
    CheckBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $fg = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::White
            $checkbox = $this.Checked ? "[X]" : "[ ]"
            $displayText = "$checkbox $($this.Text)"
            
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg
            
        } catch { 
            Write-Log -Level Error -Message "CheckBox render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                $this.Checked = -not $this.Checked
                if ($this.OnChange) { 
                    Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock { 
                        & $this.OnChange -NewValue $this.Checked 
                    } 
                }
                $this.RequestRedraw()
                return $true
            }
        } catch { 
            Write-Log -Level Error -Message "CheckBox input error for '$($this.Name)': $_" 
        }
        return $false
    }
}

# AI: NEW - RadioButtonComponent converted from functional to class-based
class RadioButtonComponent : UIElement {
    [string]$Text = "Option"
    [bool]$Selected = $false
    [string]$GroupName = ""
    [scriptblock]$OnChange
    
    RadioButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $fg = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::White
            $radio = $this.Selected ? "(●)" : "( )"
            $displayText = "$radio $($this.Text)"

            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg

        } catch { 
            Write-Log -Level Error -Message "RadioButton render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                if (-not $this.Selected) {
                    # AI: Unselect other radio buttons in the same group
                    if ($this.Parent -and $this.GroupName) {
                        $siblingRadios = $this.Parent.Children | Where-Object { 
                            $_ -is [RadioButtonComponent] -and $_.GroupName -eq $this.GroupName -and $_ -ne $this 
                        }
                        foreach ($radio in $siblingRadios) {
                            $radio.Selected = $false
                        }
                    }
                    
                    $this.Selected = $true
                    if ($this.OnChange) { 
                        Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock { 
                            & $this.OnChange -NewValue $this.Selected 
                        } 
                    }
                    $this.Parent.RequestRedraw()
                }
                return $true
            }
        } catch { 
            Write-Log -Level Error -Message "RadioButton input error for '$($this.Name)': $_" 
        }
        return $false
    }
}

#endregion

#region Factory Functions

# AI: Updated factories to return class instances

function New-TuiLabel {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "Label_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $label = [LabelComponent]::new($name)
    
    $label.X = $Props.X ?? $label.X
    $label.Y = $Props.Y ?? $label.Y
    $label.Width = $Props.Width ?? $label.Width
    $label.Height = $Props.Height ?? $label.Height
    $label.Visible = $Props.Visible ?? $label.Visible
    $label.ZIndex = $Props.ZIndex ?? $label.ZIndex
    $label.Text = $Props.Text ?? $label.Text
    $label.ForegroundColor = $Props.ForegroundColor ?? $label.ForegroundColor
    
    return $label
}

function New-TuiButton {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "Button_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $button = [ButtonComponent]::new($name)
    
    $button.X = $Props.X ?? $button.X
    $button.Y = $Props.Y ?? $button.Y
    $button.Width = $Props.Width ?? $button.Width
    $button.Height = $Props.Height ?? $button.Height
    $button.Visible = $Props.Visible ?? $button.Visible
    $button.ZIndex = $Props.ZIndex ?? $button.ZIndex
    $button.Text = $Props.Text ?? $button.Text
    $button.OnClick = $Props.OnClick ?? $button.OnClick
    
    return $button
}

function New-TuiTextBox {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "TextBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $textBox = [TextBoxComponent]::new($name)
    
    $textBox.X = $Props.X ?? $textBox.X
    $textBox.Y = $Props.Y ?? $textBox.Y
    $textBox.Width = $Props.Width ?? $textBox.Width
    $textBox.Height = $Props.Height ?? $textBox.Height
    $textBox.Visible = $Props.Visible ?? $textBox.Visible
    $textBox.ZIndex = $Props.ZIndex ?? $textBox.ZIndex
    $textBox.Text = $Props.Text ?? $textBox.Text
    $textBox.Placeholder = $Props.Placeholder ?? $textBox.Placeholder
    $textBox.MaxLength = $Props.MaxLength ?? $textBox.MaxLength
    $textBox.CursorPosition = $Props.CursorPosition ?? $textBox.CursorPosition
    $textBox.OnChange = $Props.OnChange ?? $textBox.OnChange
    
    return $textBox
}

function New-TuiCheckBox {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "CheckBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $checkBox = [CheckBoxComponent]::new($name)
    
    $checkBox.X = $Props.X ?? $checkBox.X
    $checkBox.Y = $Props.Y ?? $checkBox.Y
    $checkBox.Width = $Props.Width ?? $checkBox.Width
    $checkBox.Height = $Props.Height ?? $checkBox.Height
    $checkBox.Visible = $Props.Visible ?? $checkBox.Visible
    $checkBox.ZIndex = $Props.ZIndex ?? $checkBox.ZIndex
    $checkBox.Text = $Props.Text ?? $checkBox.Text
    $checkBox.Checked = $Props.Checked ?? $checkBox.Checked
    $checkBox.OnChange = $Props.OnChange ?? $checkBox.OnChange
    
    return $checkBox
}

function New-TuiRadioButton {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "RadioButton_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $radioButton = [RadioButtonComponent]::new($name)
    
    $radioButton.X = $Props.X ?? $radioButton.X
    $radioButton.Y = $Props.Y ?? $radioButton.Y
    $radioButton.Width = $Props.Width ?? $radioButton.Width
    $radioButton.Height = $Props.Height ?? $radioButton.Height
    $radioButton.Visible = $Props.Visible ?? $radioButton.Visible
    $radioButton.ZIndex = $Props.ZIndex ?? $radioButton.ZIndex
    $radioButton.Text = $Props.Text ?? $radioButton.Text
    $radioButton.Selected = $Props.Selected ?? $radioButton.Selected
    $radioButton.GroupName = $Props.GroupName ?? $radioButton.GroupName
    $radioButton.OnChange = $Props.OnChange ?? $radioButton.OnChange
    
    return $radioButton
}

#endregion

Export-ModuleMember -Function 'New-TuiLabel', 'New-TuiButton', 'New-TuiTextBox', 'New-TuiCheckBox', 'New-TuiRadioButton'