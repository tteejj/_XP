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
