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
