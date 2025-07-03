class DateInputComponent : UIElement {
    [DateTime]$Value = (Get-Date)
    [DateTime]$MinDate = [DateTime]::MinValue
    [DateTime]$MaxDate = [DateTime]::MaxValue
    [string]$Format = "yyyy-MM-dd"
    [string]$TextValue = ""
    [int]$CursorPosition = 0
    [bool]$ShowCalendar = $false
    [scriptblock]$OnChange
    
    DateInputComponent([string]$name) : base() {
        $this.Name = $name
        $this.IsFocusable = $true
        $this.Width = 25
        $this.Height = 3
        $this.TextValue = $this.Value.ToString($this.Format)
    }
    
    # AI: REFACTORED - Now uses UIElement buffer system
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            
            # AI: Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Display date value
            $displayText = $this.TextValue
            $maxDisplayLength = $this.Width - 6
            if ($displayText.Length -gt $maxDisplayLength) {
                $displayText = $displayText.Substring(0, $maxDisplayLength)
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y 1 -Text $displayText `
                -ForegroundColor ([ConsoleColor]::White) -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw calendar icon
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 1 -Text "📅" `
                -ForegroundColor ([ConsoleColor]::Cyan) -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw cursor if focused
            if ($this.IsFocused -and $this.CursorPosition -le $this.TextValue.Length) {
                $cursorX = 2 + $this.CursorPosition
                if ($cursorX -lt $this.Width - 4) {
                    Write-TuiText -Buffer $this._private_buffer -X $cursorX -Y 1 -Text "_" `
                        -ForegroundColor ([ConsoleColor]::Yellow) -BackgroundColor ([ConsoleColor]::Black)
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "DateInput render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $handled = $true
            $originalValue = $this.Value
            
            if ($this.ShowCalendar) {
                switch ($key.Key) {
                    ([ConsoleKey]::Escape) { $this.ShowCalendar = $false }
                    ([ConsoleKey]::LeftArrow) { $this.Value = $this.Value.AddDays(-1) }
                    ([ConsoleKey]::RightArrow) { $this.Value = $this.Value.AddDays(1) }
                    ([ConsoleKey]::UpArrow) { $this.Value = $this.Value.AddDays(-7) }
                    ([ConsoleKey]::DownArrow) { $this.Value = $this.Value.AddDays(7) }
                    ([ConsoleKey]::Enter) { 
                        $this.ShowCalendar = $false
                        $this.TextValue = $this.Value.ToString($this.Format)
                    }
                    default { $handled = $false }
                }
            } else {
                switch ($key.Key) {
                    ([ConsoleKey]::F4) { $this.ShowCalendar = $true }
                    ([ConsoleKey]::UpArrow) { $this.Value = $this.Value.AddDays(1); $this.TextValue = $this.Value.ToString($this.Format) }
                    ([ConsoleKey]::DownArrow) { $this.Value = $this.Value.AddDays(-1); $this.TextValue = $this.Value.ToString($this.Format) }
                    ([ConsoleKey]::LeftArrow) {
                        if ($this.CursorPosition -gt 0) { $this.CursorPosition-- }
                    }
                    ([ConsoleKey]::RightArrow) {
                        if ($this.CursorPosition -lt $this.TextValue.Length) { $this.CursorPosition++ }
                    }
                    ([ConsoleKey]::Home) { $this.CursorPosition = 0 }
                    ([ConsoleKey]::End) { $this.CursorPosition = $this.TextValue.Length }
                    ([ConsoleKey]::Backspace) {
                        if ($this.CursorPosition -gt 0) {
                            $this.TextValue = $this.TextValue.Remove($this.CursorPosition - 1, 1)
                            $this.CursorPosition--
                        }
                    }
                    ([ConsoleKey]::Delete) {
                        if ($this.CursorPosition -lt $this.TextValue.Length) {
                            $this.TextValue = $this.TextValue.Remove($this.CursorPosition, 1)
                        }
                    }
                    ([ConsoleKey]::Enter) {
                        $this._ValidateAndUpdate()
                    }
                    default {
                        if ($key.KeyChar -and ($key.KeyChar -match '[\d\-\/]')) {
                            $this.TextValue = $this.TextValue.Insert($this.CursorPosition, $key.KeyChar)
                            $this.CursorPosition++
                        } else {
                            $handled = $false
                        }
                    }
                }
            }
            
            if ($handled -and $this.Value -ne $originalValue -and $this.OnChange) {
                Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -Context "Change Event" -ScriptBlock { 
                    & $this.OnChange -NewValue $this.Value 
                }
                $this.RequestRedraw()
            }
            
            return $handled
        } catch { 
            Write-Log -Level Error -Message "DateInput input error for '$($this.Name)': $_"
            return $false 
        }
    }
    
    hidden [bool] _ValidateAndUpdate() {
        try {
            $newDate = [DateTime]::ParseExact($this.TextValue, $this.Format, $null)
            if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                $this.Value = $newDate
                $this.TextValue = $newDate.ToString($this.Format)
                return $true
            }
        } catch {
            # Reset to current value on parse error
            $this.TextValue = $this.Value.ToString($this.Format)
            Write-Log -Level Warning -Message "DateInput validation failed for '$($this.Name)': $_"
        }
        return $false
    }
}
