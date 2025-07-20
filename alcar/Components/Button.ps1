# Button Component - Interactive button with click events

class Button : Component {
    [string]$Text = "Button"
    [scriptblock]$OnClick = $null
    [bool]$IsPressed = $false
    [bool]$IsDefault = $false  # Default button (responds to Enter from anywhere)
    [bool]$IsCancel = $false   # Cancel button (responds to Escape)
    
    # Visual properties
    [bool]$ShowBorder = $true
    [string]$PressedColor = ""
    [string]$DisabledColor = ""
    [char]$AcceleratorPrefix = '&'  # For keyboard shortcuts like &Save
    hidden [char]$_accelerator = $null
    hidden [int]$_acceleratorIndex = -1
    
    Button([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Height = if ($this.ShowBorder) { 3 } else { 1 }
        $this.UpdateWidth()
    }
    
    [void] SetText([string]$text) {
        $this.Text = $text
        $this.ParseAccelerator()
        $this.UpdateWidth()
        $this.Invalidate()
    }
    
    [void] UpdateWidth() {
        # Auto-size based on text length
        $textLen = $this.GetDisplayText().Length
        $this.Width = [Math]::Max($textLen + 4, 10)  # Minimum width of 10
    }
    
    [string] GetDisplayText() {
        # Remove accelerator prefix for display
        if ($this._acceleratorIndex -ge 0) {
            return $this.Text.Replace("$($this.AcceleratorPrefix)", "")
        }
        return $this.Text
    }
    
    [void] ParseAccelerator() {
        $this._accelerator = $null
        $this._acceleratorIndex = -1
        
        $index = $this.Text.IndexOf($this.AcceleratorPrefix)
        if ($index -ge 0 -and $index -lt $this.Text.Length - 1) {
            $this._accelerator = [char]::ToUpper($this.Text[$index + 1])
            $this._acceleratorIndex = $index
        }
    }
    
    [void] Click() {
        if (-not $this.Enabled) { return }
        
        $this.IsPressed = $true
        $this.Invalidate()
        
        # No sleep needed - instant response
        
        if ($this.OnClick) {
            & $this.OnClick $this
        }
        
        $this.IsPressed = $false
        $this.Invalidate()
    }
    
    [void] OnRender([object]$buffer) {
        if (-not $this.Visible) { return }
        
        # Determine colors based on state
        $bgColor = ""
        $fgColor = ""
        $borderColor = ""
        
        if (-not $this.Enabled) {
            $bgColor = if ($this.DisabledColor) { $this.DisabledColor } else { [VT]::RGBBG(40, 40, 40) }
            $fgColor = [VT]::RGB(100, 100, 100)
            $borderColor = [VT]::RGB(60, 60, 60)
        } elseif ($this.IsPressed) {
            $bgColor = if ($this.PressedColor) { $this.PressedColor } else { [VT]::RGBBG(60, 60, 80) }
            $fgColor = [VT]::RGB(255, 255, 255)
            $borderColor = [VT]::RGB(150, 150, 200)
        } elseif ($this.IsFocused) {
            $bgColor = if ($this.BackgroundColor) { $this.BackgroundColor } else { [VT]::RGBBG(50, 50, 70) }
            $fgColor = [VT]::RGB(255, 255, 255)
            $borderColor = [VT]::RGB(100, 200, 255)
        } else {
            $bgColor = if ($this.BackgroundColor) { $this.BackgroundColor } else { [VT]::RGBBG(40, 40, 50) }
            $fgColor = if ($this.ForegroundColor) { $this.ForegroundColor } else { [VT]::RGB(200, 200, 200) }
            $borderColor = if ($this.BorderColor) { $this.BorderColor } else { [VT]::RGB(80, 80, 100) }
        }
        
        # Clear background
        for ($y = 0; $y -lt $this.Height; $y++) {
            $this.DrawText($buffer, 0, $y, $bgColor + (" " * $this.Width) + [VT]::Reset())
        }
        
        # Draw border if enabled
        if ($this.ShowBorder) {
            $this.DrawBorder($buffer, $borderColor, $bgColor)
        }
        
        # Draw button text centered
        $displayText = $this.GetDisplayText()
        $textY = [int]($this.Height / 2)
        $textX = [int](($this.Width - $displayText.Length) / 2)
        
        if ($this._acceleratorIndex -ge 0) {
            # Draw text with underlined accelerator
            $beforeAccel = $displayText.Substring(0, $this._acceleratorIndex)
            $accelChar = $displayText[$this._acceleratorIndex]
            $afterAccel = if ($this._acceleratorIndex -lt $displayText.Length - 1) {
                $displayText.Substring($this._acceleratorIndex + 1)
            } else { "" }
            
            $x = $textX
            if ($beforeAccel) {
                $this.DrawText($buffer, $x, $textY, $fgColor + $beforeAccel)
                $x += $beforeAccel.Length
            }
            
            # Draw accelerator with underline
            $this.DrawText($buffer, $x, $textY, $fgColor + [VT]::Underline() + $accelChar + [VT]::Reset())
            $x++
            
            if ($afterAccel) {
                $this.DrawText($buffer, $x, $textY, $fgColor + $afterAccel)
            }
        } else {
            # Draw normal text
            $this.DrawText($buffer, $textX, $textY, $fgColor + $displayText)
        }
        
        # Add visual indicators for special buttons
        if ($this.IsDefault) {
            # Draw default indicator (brackets)
            $this.DrawText($buffer, 1, $textY, $fgColor + "[")
            $this.DrawText($buffer, $this.Width - 2, $textY, $fgColor + "]")
        }
        
        $this.DrawText($buffer, 0, 0, [VT]::Reset())
    }
    
    [void] DrawBorder([object]$buffer, [string]$borderColor, [string]$bgColor) {
        # Different border styles based on state
        $style = if ($this.IsPressed) { "Double" } else { "Single" }
        
        $chars = switch ($style) {
            "Double" { @{TL="╔"; TR="╗"; BL="╚"; BR="╝"; H="═"; V="║"} }
            default { @{TL="┌"; TR="┐"; BL="└"; BR="┘"; H="─"; V="│"} }
        }
        
        # Top border
        $this.DrawText($buffer, 0, 0, $borderColor + $chars.TL + ($chars.H * ($this.Width - 2)) + $chars.TR)
        
        # Sides
        for ($y = 1; $y -lt $this.Height - 1; $y++) {
            $this.DrawText($buffer, 0, $y, $borderColor + $chars.V)
            $this.DrawText($buffer, $this.Width - 1, $y, $borderColor + $chars.V)
        }
        
        # Bottom border
        $this.DrawText($buffer, 0, $this.Height - 1, 
                      $borderColor + $chars.BL + ($chars.H * ($this.Width - 2)) + $chars.BR)
    }
    
    [void] DrawText([object]$buffer, [int]$x, [int]$y, [string]$text) {
        # Placeholder for alcar buffer integration
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.Enabled) { return $false }
        
        # Handle button activation
        if ($this.IsFocused) {
            if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                $this.Click()
                return $true
            }
        }
        
        # Handle accelerator key (Alt+Letter)
        if ($this._accelerator -and 
            ($key.Modifiers -band [ConsoleModifiers]::Alt) -and
            [char]::ToUpper($key.KeyChar) -eq $this._accelerator) {
            $this.Click()
            return $true
        }
        
        # Handle default button behavior
        if ($this.IsDefault -and $key.Key -eq [ConsoleKey]::Enter -and 
            -not ($key.Modifiers -band [ConsoleModifiers]::Alt)) {
            $this.Click()
            return $true
        }
        
        # Handle cancel button behavior  
        if ($this.IsCancel -and $key.Key -eq [ConsoleKey]::Escape) {
            $this.Click()
            return $true
        }
        
        return $false
    }
    
    [void] OnFocus() {
        $this.Invalidate()
    }
    
    [void] OnBlur() {
        $this.Invalidate()
    }
    
    # Static factory methods for common button types
    static [Button] CreateOK([string]$name) {
        $btn = [Button]::new($name)
        $btn.Text = "OK"
        $btn.IsDefault = $true
        return $btn
    }
    
    static [Button] CreateCancel([string]$name) {
        $btn = [Button]::new($name)
        $btn.Text = "Cancel"
        $btn.IsCancel = $true
        return $btn
    }
    
    static [Button] CreateYesNo([string]$name, [bool]$isYes) {
        $btn = [Button]::new($name)
        if ($isYes) {
            $btn.Text = "&Yes"
            $btn.IsDefault = $true
        } else {
            $btn.Text = "&No"
            $btn.IsCancel = $true
        }
        return $btn
    }
}