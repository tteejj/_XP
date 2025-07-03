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
