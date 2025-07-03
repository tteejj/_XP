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
