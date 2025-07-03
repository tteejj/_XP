class NumericInputComponent : UIElement {
    [double]$Value = 0
    [double]$Min = [double]::MinValue
    [double]$Max = [double]::MaxValue
    [double]$Step = 1
    [int]$DecimalPlaces = 0
    [string]$TextValue = "0"
    [int]$CursorPosition = 0
    [string]$Suffix = ""
    [scriptblock]$OnChange
    
    NumericInputComponent([string]$name) : base() {
        $this.Name = $name
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3
        $this.TextValue = $this.Value.ToString("F$($this.DecimalPlaces)")
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
            
            # AI: Display value with suffix
            $displayText = $this.TextValue + $this.Suffix
            $maxDisplayLength = $this.Width - 6
            if ($displayText.Length -gt $maxDisplayLength) {
                $displayText = $displayText.Substring(0, $maxDisplayLength)
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y 1 -Text $displayText `
                -ForegroundColor ([ConsoleColor]::White) -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw spinner arrows
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 0 -Text "▲" `
                -ForegroundColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 2 -Text "▼" `
                -ForegroundColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw cursor if focused
            if ($this.IsFocused -and $this.CursorPosition -le $this.TextValue.Length) {
                $cursorX = 2 + $this.CursorPosition
                if ($cursorX -lt $this.Width - 4) {
                    Write-TuiText -Buffer $this._private_buffer -X $cursorX -Y 1 -Text "_" `
                        -ForegroundColor ([ConsoleColor]::Yellow) -BackgroundColor ([ConsoleColor]::Black)
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "NumericInput render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $handled = $true
            $originalValue = $this.Value
            
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    $this._IncrementValue()
                }
                ([ConsoleKey]::DownArrow) {
                    $this._DecrementValue()
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.CursorPosition -gt 0) { 
                        $this.CursorPosition-- 
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.CursorPosition -lt $this.TextValue.Length) { 
                        $this.CursorPosition++ 
                    }
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
                    if ($key.KeyChar -and ($key.KeyChar -match '[\d\.\-]' -or 
                        ($key.KeyChar -eq '.' -and $this.DecimalPlaces -gt 0 -and -not $this.TextValue.Contains('.')))) {
                        $this.TextValue = $this.TextValue.Insert($this.CursorPosition, $key.KeyChar)
                        $this.CursorPosition++
                    } else {
                        $handled = $false
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
            Write-Log -Level Error -Message "NumericInput input error for '$($this.Name)': $_"
            return $false 
        }
    }
    
    hidden [void] _IncrementValue() {
        $newValue = [Math]::Min($this.Max, $this.Value + $this.Step)
        $this._SetValue($newValue)
    }
    
    hidden [void] _DecrementValue() {
        $newValue = [Math]::Max($this.Min, $this.Value - $this.Step)
        $this._SetValue($newValue)
    }
    
    hidden [void] _SetValue([double]$value) {
        $this.Value = $value
        $this.TextValue = $value.ToString("F$($this.DecimalPlaces)")
        $this.CursorPosition = $this.TextValue.Length
    }
    
    hidden [bool] _ValidateAndUpdate() {
        try {
            $newValue = [double]$this.TextValue
            $newValue = [Math]::Max($this.Min, [Math]::Min($this.Max, $newValue))
            $newValue = [Math]::Round($newValue, $this.DecimalPlaces)
            
            $this._SetValue($newValue)
            return $true
        } catch {
            $this.TextValue = $this.Value.ToString("F$($this.DecimalPlaces)")
            Write-Log -Level Warning -Message "NumericInput validation failed for '$($this.Name)': $_"
            return $false
        }
    }
}
