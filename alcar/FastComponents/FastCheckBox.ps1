# FastCheckBox - Minimal overhead checkbox

class FastCheckBox : FastComponentBase {
    # State
    [string]$Text = ""
    [bool]$Checked = $false
    [bool]$IsFocused = $false
    
    # Pre-computed
    hidden [string]$_checkedStr
    hidden [string]$_uncheckedStr
    
    FastCheckBox([int]$x, [int]$y, [string]$text) {
        $this.X = $x
        $this.Y = $y
        $this.Text = $text
        $this.Width = $text.Length + 4  # [x] + space + text
        $this.Height = 1
        $this.PrecomputeStrings()
    }
    
    [void] PrecomputeStrings() {
        $normalColor = "`e[38;2;200;200;200m"
        $focusColor = "`e[38;2;255;255;255m"
        $checkColor = "`e[38;2;100;255;100m"
        
        # Pre-build the checked/unchecked strings
        $this._checkedStr = "[" + $checkColor + "✓" + $normalColor + "] " + $this.Text
        $this._uncheckedStr = "[ ] " + $this.Text
    }
    
    # Direct render
    [string] Render() {
        if (-not $this.Visible) { return "" }
        
        $out = $this.MT($this.X, $this.Y)
        
        if ($this.IsFocused) {
            $out += "`e[38;2;255;255;255m"
        } else {
            $out += "`e[38;2;200;200;200m"
        }
        
        if ($this.Checked) {
            $out += $this._checkedStr
        } else {
            $out += $this._uncheckedStr
        }
        
        $out += [FastComponentBase]::VTCache.Reset
        return $out
    }
    
    # Direct input - space to toggle
    [bool] Input([ConsoleKey]$key) {
        if ($key -eq [ConsoleKey]::Spacebar) {
            $this.Checked = -not $this.Checked
            return $true
        }
        return $false
    }
    
    # Fast toggle
    [void] Toggle() {
        $this.Checked = -not $this.Checked
    }
}