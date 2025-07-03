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
