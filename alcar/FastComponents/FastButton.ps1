# FastButton - Zero-overhead button implementation

class FastButton : FastComponentBase {
    # Minimal state
    [string]$Text = "Button"
    [bool]$IsFocused = $false
    [bool]$IsPressed = $false
    [bool]$IsDefault = $false
    
    # Pre-computed render strings
    hidden [string]$_normalRender
    hidden [string]$_focusedRender
    hidden [string]$_pressedRender
    hidden [bool]$_needsRebuild = $true
    
    FastButton([int]$x, [int]$y, [string]$text) {
        $this.X = $x
        $this.Y = $y
        $this.Text = $text
        $this.Width = $text.Length + 4
        $this.Height = 1
        $this.BuildRenderStrings()
    }
    
    # Pre-build all render states
    [void] BuildRenderStrings() {
        $mt = $this.MT($this.X, $this.Y)
        
        # Normal state
        $this._normalRender = $mt + "`e[38;2;200;200;200m" + 
                             "[" + $this.Text + "]" + 
                             [FastComponentBase]::VTCache.Reset
        
        # Focused state
        $this._focusedRender = $mt + "`e[48;2;50;50;70m`e[38;2;255;255;255m" +
                              "[" + $this.Text + "]" +
                              [FastComponentBase]::VTCache.Reset
        
        # Pressed state
        $this._pressedRender = $mt + "`e[48;2;60;60;80m`e[38;2;255;255;255m" +
                              "[" + $this.Text + "]" +
                              [FastComponentBase]::VTCache.Reset
        
        $this._needsRebuild = $false
    }
    
    # Ultra-fast render - just return pre-built string
    [string] Render() {
        if (-not $this.Visible) { return "" }
        
        if ($this._needsRebuild) {
            $this.BuildRenderStrings()
        }
        
        if ($this.IsPressed) {
            return $this._pressedRender
        } elseif ($this.IsFocused) {
            return $this._focusedRender
        } else {
            return $this._normalRender
        }
    }
    
    # Direct input - Enter/Space to activate
    [bool] Input([ConsoleKey]$key) {
        if ($key -eq [ConsoleKey]::Enter -or $key -eq [ConsoleKey]::Spacebar) {
            $this.IsPressed = $true
            return $true
        }
        return $false
    }
    
    # Fast click check
    [bool] WasClicked() {
        if ($this.IsPressed) {
            $this.IsPressed = $false
            return $true
        }
        return $false
    }
    
    # Update position (triggers rebuild)
    [void] SetPosition([int]$x, [int]$y) {
        if ($this.X -ne $x -or $this.Y -ne $y) {
            $this.X = $x
            $this.Y = $y
            $this._needsRebuild = $true
        }
    }
}