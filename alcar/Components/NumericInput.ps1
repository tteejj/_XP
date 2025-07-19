# NumericInput Component - Number-only input with validation and spinners

class NumericInput : Component {
    [double]$Value = 0
    [double]$Minimum = [double]::MinValue
    [double]$Maximum = [double]::MaxValue
    [double]$Step = 1
    [int]$DecimalPlaces = 0
    [scriptblock]$OnChange = $null
    
    # Visual properties
    [bool]$ShowBorder = $true
    [bool]$ShowSpinners = $true
    [string]$Prefix = ""     # e.g., "$" for currency
    [string]$Suffix = ""     # e.g., "%" for percentage
    
    # Internal state
    hidden [string]$_textValue = "0"
    hidden [int]$_cursorPosition = 0
    hidden [bool]$_isEditing = $false
    
    NumericInput([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Height = if ($this.ShowBorder) { 3 } else { 1 }
        $this.Width = 15
        $this.UpdateTextValue()
    }
    
    [void] SetValue([double]$value) {
        $this.Value = $this.ClampValue($value)
        $this.UpdateTextValue()
        $this.Invalidate()
    }
    
    [void] SetRange([double]$min, [double]$max) {
        $this.Minimum = $min
        $this.Maximum = $max
        $this.Value = $this.ClampValue($this.Value)
        $this.UpdateTextValue()
        $this.Invalidate()
    }
    
    [double] ClampValue([double]$value) {
        return [Math]::Max($this.Minimum, [Math]::Min($this.Maximum, $value))
    }
    
    [void] UpdateTextValue() {
        if ($this._isEditing) { return }
        
        if ($this.DecimalPlaces -eq 0) {
            $this._textValue = [Math]::Truncate($this.Value).ToString()
        } else {
            $this._textValue = $this.Value.ToString("F$($this.DecimalPlaces)")
        }
        
        $this._cursorPosition = $this._textValue.Length
    }
    
    [void] Increment() {
        $newValue = $this.Value + $this.Step
        if ($newValue -le $this.Maximum) {
            $oldValue = $this.Value
            $this.Value = $newValue
            $this.UpdateTextValue()
            
            if ($this.OnChange -and $oldValue -ne $this.Value) {
                & $this.OnChange $this $this.Value
            }
            
            $this.Invalidate()
        }
    }
    
    [void] Decrement() {
        $newValue = $this.Value - $this.Step
        if ($newValue -ge $this.Minimum) {
            $oldValue = $this.Value
            $this.Value = $newValue
            $this.UpdateTextValue()
            
            if ($this.OnChange -and $oldValue -ne $this.Value) {
                & $this.OnChange $this $this.Value
            }
            
            $this.Invalidate()
        }
    }
    
    [void] ParseAndValidate() {
        try {
            $parsedValue = [double]::Parse($this._textValue)
            $parsedValue = $this.ClampValue($parsedValue)
            
            $oldValue = $this.Value
            $this.Value = $parsedValue
            
            $this._isEditing = $false
            $this.UpdateTextValue()
            
            if ($this.OnChange -and $oldValue -ne $this.Value) {
                & $this.OnChange $this $this.Value
            }
        }
        catch {
            # Reset to valid value on parse error
            $this._isEditing = $false
            $this.UpdateTextValue()
        }
    }
    
    [void] OnRender([object]$buffer) {
        if (-not $this.Visible) { return }
        
        # Colors
        $bgColor = if ($this.BackgroundColor) { $this.BackgroundColor } else { [VT]::RGBBG(30, 30, 35) }
        $fgColor = if ($this.ForegroundColor) { $this.ForegroundColor } else { [VT]::RGB(220, 220, 220) }
        $borderColor = if ($this.BorderColor) { $this.BorderColor } else {
            if ($this.IsFocused) { [VT]::RGB(100, 200, 255) } else { [VT]::RGB(80, 80, 100) }
        }
        
        # Clear background
        for ($y = 0; $y -lt $this.Height; $y++) {
            $this.DrawText($buffer, 0, $y, $bgColor + (" " * $this.Width) + [VT]::Reset())
        }
        
        # Draw border if enabled
        if ($this.ShowBorder) {
            $this.DrawBorder($buffer, $borderColor)
        }
        
        # Calculate content area
        $contentY = if ($this.ShowBorder) { 1 } else { 0 }
        $contentX = if ($this.ShowBorder) { 1 } else { 0 }
        $spinnerSpace = if ($this.ShowSpinners) { 3 } else { 0 }
        $contentWidth = $this.Width - (if ($this.ShowBorder) { 2 } else { 0 }) - $spinnerSpace
        
        # Build display text
        $displayText = $this.Prefix + $this._textValue + $this.Suffix
        
        # Ensure text fits
        if ($displayText.Length -gt $contentWidth) {
            # Scroll to keep cursor visible
            if ($this._isEditing) {
                $prefixLen = $this.Prefix.Length
                $cursorInDisplay = $prefixLen + $this._cursorPosition
                
                if ($cursorInDisplay -ge $contentWidth) {
                    $offset = $cursorInDisplay - $contentWidth + 1
                    $displayText = "..." + $displayText.Substring($offset + 3)
                } else {
                    $displayText = $displayText.Substring(0, $contentWidth - 3) + "..."
                }
            } else {
                $displayText = $displayText.Substring(0, $contentWidth - 3) + "..."
            }
        }
        
        # Draw text
        $this.DrawText($buffer, $contentX, $contentY, $fgColor + $displayText + [VT]::Reset())
        
        # Draw cursor if focused and editing
        if ($this.IsFocused -and $this._isEditing) {
            $cursorScreenX = $contentX + $this.Prefix.Length + $this._cursorPosition
            
            if ($cursorScreenX -ge $contentX -and $cursorScreenX -lt $contentX + $contentWidth) {
                $charUnderCursor = ' '
                if ($this._cursorPosition -lt $this._textValue.Length) {
                    $charUnderCursor = $this._textValue[$this._cursorPosition]
                }
                
                $this.DrawText($buffer, $cursorScreenX, $contentY,
                              [VT]::RGBBG(220, 220, 220) + [VT]::RGB(30, 30, 35) + 
                              $charUnderCursor + [VT]::Reset())
            }
        }
        
        # Draw spinners if enabled
        if ($this.ShowSpinners) {
            $spinnerX = $this.Width - (if ($this.ShowBorder) { 2 } else { 1 })
            $spinnerColor = if ($this.IsFocused) { [VT]::RGB(255, 200, 100) } else { [VT]::RGB(100, 100, 100) }
            
            # Up arrow
            $upEnabled = $this.Value < $this.Maximum
            $upColor = if ($upEnabled) { $spinnerColor } else { [VT]::RGB(60, 60, 60) }
            $this.DrawText($buffer, $spinnerX, $contentY, $upColor + "▲" + [VT]::Reset())
            
            # Down arrow (if height allows)
            if ($this.Height -ge 3) {
                $downY = if ($this.ShowBorder) { $this.Height - 2 } else { $this.Height - 1 }
                $downEnabled = $this.Value > $this.Minimum
                $downColor = if ($downEnabled) { $spinnerColor } else { [VT]::RGB(60, 60, 60) }
                $this.DrawText($buffer, $spinnerX, $downY, $downColor + "▼" + [VT]::Reset())
            }
        }
    }
    
    [void] DrawBorder([object]$buffer, [string]$color) {
        # Top
        $this.DrawText($buffer, 0, 0, $color + "┌" + ("─" * ($this.Width - 2)) + "┐" + [VT]::Reset())
        
        # Sides
        $this.DrawText($buffer, 0, 1, $color + "│" + [VT]::Reset())
        $this.DrawText($buffer, $this.Width - 1, 1, $color + "│" + [VT]::Reset())
        
        # Bottom
        $this.DrawText($buffer, 0, 2, $color + "└" + ("─" * ($this.Width - 2)) + "┘" + [VT]::Reset())
    }
    
    [void] DrawText([object]$buffer, [int]$x, [int]$y, [string]$text) {
        # Placeholder for alcar buffer integration
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.Enabled -or -not $this.IsFocused) { return $false }
        
        $handled = $true
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                $this.Increment()
            }
            ([ConsoleKey]::DownArrow) {
                $this.Decrement()
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this._isEditing -and $this._cursorPosition -gt 0) {
                    $this._cursorPosition--
                    $this.Invalidate()
                } else {
                    $handled = $false
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($this._isEditing -and $this._cursorPosition -lt $this._textValue.Length) {
                    $this._cursorPosition++
                    $this.Invalidate()
                } else {
                    $handled = $false
                }
            }
            ([ConsoleKey]::Home) {
                if ($this._isEditing) {
                    $this._cursorPosition = 0
                    $this.Invalidate()
                } else {
                    $handled = $false
                }
            }
            ([ConsoleKey]::End) {
                if ($this._isEditing) {
                    $this._cursorPosition = $this._textValue.Length
                    $this.Invalidate()
                } else {
                    $handled = $false
                }
            }
            ([ConsoleKey]::Backspace) {
                if (-not $this._isEditing) {
                    $this._isEditing = $true
                }
                
                if ($this._cursorPosition -gt 0) {
                    $this._textValue = $this._textValue.Remove($this._cursorPosition - 1, 1)
                    $this._cursorPosition--
                    $this.Invalidate()
                }
            }
            ([ConsoleKey]::Delete) {
                if (-not $this._isEditing) {
                    $this._isEditing = $true
                }
                
                if ($this._cursorPosition -lt $this._textValue.Length) {
                    $this._textValue = $this._textValue.Remove($this._cursorPosition, 1)
                    $this.Invalidate()
                }
            }
            ([ConsoleKey]::Enter) {
                if ($this._isEditing) {
                    $this.ParseAndValidate()
                    $this.Invalidate()
                } else {
                    $handled = $false
                }
            }
            ([ConsoleKey]::Escape) {
                if ($this._isEditing) {
                    # Cancel editing
                    $this._isEditing = $false
                    $this.UpdateTextValue()
                    $this.Invalidate()
                } else {
                    $handled = $false
                }
            }
            default {
                # Handle numeric input
                if ($key.KeyChar -and $key.KeyChar -match '[0-9.\-+]') {
                    if (-not $this._isEditing) {
                        $this._isEditing = $true
                        $this._textValue = ""
                        $this._cursorPosition = 0
                    }
                    
                    # Validate character
                    $canInsert = $true
                    
                    if ($key.KeyChar -eq '.') {
                        # Only one decimal point allowed
                        if ($this._textValue.Contains('.') -or $this.DecimalPlaces -eq 0) {
                            $canInsert = $false
                        }
                    } elseif ($key.KeyChar -match '[\-+]') {
                        # Only at beginning
                        if ($this._cursorPosition -ne 0 -or $this._textValue -match '[\-+]') {
                            $canInsert = $false
                        }
                    }
                    
                    if ($canInsert) {
                        $this._textValue = $this._textValue.Insert($this._cursorPosition, $key.KeyChar)
                        $this._cursorPosition++
                        $this.Invalidate()
                    }
                } else {
                    $handled = $false
                }
            }
        }
        
        return $handled
    }
    
    [void] OnFocus() {
        $this.Invalidate()
    }
    
    [void] OnBlur() {
        if ($this._isEditing) {
            $this.ParseAndValidate()
        }
        $this.Invalidate()
    }
    
    # Static factory methods
    static [NumericInput] CreatePercentage([string]$name) {
        $input = [NumericInput]::new($name)
        $input.Minimum = 0
        $input.Maximum = 100
        $input.Step = 1
        $input.Suffix = "%"
        return $input
    }
    
    static [NumericInput] CreateCurrency([string]$name) {
        $input = [NumericInput]::new($name)
        $input.Minimum = 0
        $input.DecimalPlaces = 2
        $input.Prefix = "$"
        $input.Step = 0.01
        return $input
    }
    
    static [NumericInput] CreateInteger([string]$name, [int]$min, [int]$max) {
        $input = [NumericInput]::new($name)
        $input.Minimum = $min
        $input.Maximum = $max
        $input.DecimalPlaces = 0
        $input.Step = 1
        return $input
    }
}