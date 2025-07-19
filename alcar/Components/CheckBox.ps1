# CheckBox Component - Boolean toggle input

class CheckBox : Component {
    [string]$Text = ""
    [bool]$Checked = $false
    [scriptblock]$OnChange = $null
    
    # Visual properties
    [string]$CheckedChar = "✓"
    [string]$UncheckedChar = " "
    [bool]$ShowBrackets = $true
    [string]$CheckedColor = ""
    [string]$TextAlignment = "Right"  # Left or Right of checkbox
    
    # Three-state support
    [bool]$ThreeState = $false
    [nullable[bool]]$CheckState = $false  # $null = indeterminate
    [string]$IndeterminateChar = "■"
    
    CheckBox([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Height = 1
        $this.UpdateWidth()
    }
    
    [void] SetText([string]$text) {
        $this.Text = $text
        $this.UpdateWidth()
        $this.Invalidate()
    }
    
    [void] UpdateWidth() {
        # Auto-size: checkbox (3) + space (1) + text
        $checkBoxWidth = if ($this.ShowBrackets) { 3 } else { 1 }
        $this.Width = $checkBoxWidth + 1 + $this.Text.Length
    }
    
    [void] Toggle() {
        if ($this.ThreeState) {
            # Cycle through: unchecked -> checked -> indeterminate -> unchecked
            if ($this.CheckState -eq $false) {
                $this.CheckState = $true
                $this.Checked = $true
            } elseif ($this.CheckState -eq $true) {
                $this.CheckState = $null  # Indeterminate
                $this.Checked = $false
            } else {
                $this.CheckState = $false
                $this.Checked = $false
            }
        } else {
            # Simple toggle
            $this.Checked = -not $this.Checked
            $this.CheckState = $this.Checked
        }
        
        if ($this.OnChange) {
            & $this.OnChange $this $this.CheckState
        }
        
        $this.Invalidate()
    }
    
    [void] SetChecked([bool]$checked) {
        $this.Checked = $checked
        $this.CheckState = $checked
        $this.Invalidate()
    }
    
    [void] SetIndeterminate() {
        if ($this.ThreeState) {
            $this.CheckState = $null
            $this.Checked = $false
            $this.Invalidate()
        }
    }
    
    [void] OnRender([object]$buffer) {
        if (-not $this.Visible) { return }
        
        # Determine colors
        $bgColor = if ($this.BackgroundColor) { $this.BackgroundColor } else { "" }
        $fgColor = if ($this.ForegroundColor) { $this.ForegroundColor } else { [VT]::RGB(200, 200, 200) }
        $checkColor = if ($this.CheckedColor) { $this.CheckedColor } else { [VT]::RGB(100, 255, 100) }
        
        if ($this.IsFocused) {
            $fgColor = [VT]::RGB(255, 255, 255)
        }
        
        if (-not $this.Enabled) {
            $fgColor = [VT]::RGB(100, 100, 100)
            $checkColor = [VT]::RGB(80, 80, 80)
        }
        
        # Build checkbox display
        $checkDisplay = ""
        if ($this.ShowBrackets) {
            $innerChar = if ($this.CheckState -eq $null) {
                $this.IndeterminateChar
            } elseif ($this.CheckState -eq $true) {
                $this.CheckedChar
            } else {
                $this.UncheckedChar
            }
            
            $checkDisplay = "[" + $innerChar + "]"
        } else {
            $checkDisplay = if ($this.CheckState -eq $null) {
                $this.IndeterminateChar
            } elseif ($this.CheckState -eq $true) {
                $this.CheckedChar
            } else {
                $this.UncheckedChar
            }
        }
        
        # Draw based on text alignment
        $x = 0
        if ($this.TextAlignment -eq "Right") {
            # Checkbox on left, text on right
            $this.DrawText($buffer, $x, 0, $bgColor)
            
            # Draw checkbox
            if ($this.CheckState -eq $true) {
                $this.DrawText($buffer, $x, 0, $checkColor + $checkDisplay + [VT]::Reset())
            } else {
                $this.DrawText($buffer, $x, 0, $fgColor + $checkDisplay + [VT]::Reset())
            }
            
            # Draw text
            if ($this.Text) {
                $x += $checkDisplay.Length + 1
                $this.DrawText($buffer, $x, 0, $fgColor + $this.Text + [VT]::Reset())
            }
        } else {
            # Text on left, checkbox on right
            if ($this.Text) {
                $this.DrawText($buffer, $x, 0, $fgColor + $this.Text + " " + [VT]::Reset())
                $x += $this.Text.Length + 1
            }
            
            # Draw checkbox
            if ($this.CheckState -eq $true) {
                $this.DrawText($buffer, $x, 0, $checkColor + $checkDisplay + [VT]::Reset())
            } else {
                $this.DrawText($buffer, $x, 0, $fgColor + $checkDisplay + [VT]::Reset())
            }
        }
    }
    
    [void] DrawText([object]$buffer, [int]$x, [int]$y, [string]$text) {
        # Placeholder for alcar buffer integration
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.Enabled -or -not $this.IsFocused) { return $false }
        
        switch ($key.Key) {
            ([ConsoleKey]::Spacebar) {
                $this.Toggle()
                return $true
            }
            ([ConsoleKey]::Enter) {
                $this.Toggle()
                return $true
            }
        }
        
        # Handle letter shortcuts (first letter of text)
        if ($this.Text -and $key.KeyChar) {
            $firstChar = [char]::ToUpper($this.Text[0])
            if ([char]::ToUpper($key.KeyChar) -eq $firstChar) {
                $this.Toggle()
                return $true
            }
        }
        
        return $false
    }
    
    [void] OnFocus() {
        $this.Invalidate()
    }
    
    [void] OnBlur() {
        $this.Invalidate()
    }
    
    # Static factory methods
    static [CheckBox] CreateThreeState([string]$name, [string]$text) {
        $cb = [CheckBox]::new($name)
        $cb.Text = $text
        $cb.ThreeState = $true
        return $cb
    }
    
    static [CheckBox] CreateSwitch([string]$name, [string]$text) {
        $cb = [CheckBox]::new($name)
        $cb.Text = $text
        $cb.ShowBrackets = $false
        $cb.CheckedChar = "ON "
        $cb.UncheckedChar = "OFF"
        $cb.CheckedColor = [VT]::RGB(100, 255, 100)
        return $cb
    }
}