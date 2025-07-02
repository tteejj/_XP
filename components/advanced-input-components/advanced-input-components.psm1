# Advanced Input Components - Phase 2 Migration Complete
# All components now inherit from UIElement and use buffer-based rendering

#using module '.\components\tui-primitives.psm1'
#using module '.\components\ui-classes.psm1'
#using module '..\modules\logger.psm1'
#using module '..\modules\exceptions.psm1'

#region Advanced Input Classes

# AI: REFACTORED - MultilineTextBox converted from functional to class-based
class MultilineTextBoxComponent : UIElement {
    [string[]]$Lines = @("")
    [string]$Placeholder = "Enter text..."
    [int]$MaxLines = 10
    [int]$MaxLineLength = 100
    [int]$CurrentLine = 0
    [int]$CursorPosition = 0
    [int]$ScrollOffsetY = 0
    [bool]$WordWrap = $true
    [scriptblock]$OnChange
    
    MultilineTextBoxComponent([string]$name) : base() {
        $this.Name = $name
        $this.IsFocusable = $true
        $this.Width = 40
        $this.Height = 10
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
            
            # AI: Calculate visible area
            $textAreaHeight = $this.Height - 2
            $textAreaWidth = $this.Width - 2
            $startLine = $this.ScrollOffsetY
            $endLine = [Math]::Min($this.Lines.Count - 1, $startLine + $textAreaHeight - 1)
            
            # AI: Render text lines
            for ($i = $startLine; $i -le $endLine; $i++) {
                if ($i -ge $this.Lines.Count) { break }
                
                $line = $this.Lines[$i] ?? ""
                $displayLine = $line
                if ($displayLine.Length -gt $textAreaWidth) {
                    $displayLine = $displayLine.Substring(0, $textAreaWidth)
                }
                
                $lineY = 1 + ($i - $startLine)
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y $lineY -Text $displayLine `
                    -ForegroundColor ([ConsoleColor]::White) -BackgroundColor ([ConsoleColor]::Black)
            }
            
            # AI: Show placeholder if empty and not focused
            if ($this.Lines.Count -eq 1 -and [string]::IsNullOrEmpty($this.Lines[0]) -and -not $this.IsFocused) {
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $this.Placeholder `
                    -ForegroundColor ([ConsoleColor]::DarkGray) -BackgroundColor ([ConsoleColor]::Black)
            }
            
            # AI: Draw cursor if focused
            if ($this.IsFocused) {
                $cursorLine = $this.CurrentLine - $this.ScrollOffsetY
                if ($cursorLine -ge 0 -and $cursorLine -lt $textAreaHeight) {
                    $cursorX = 1 + $this.CursorPosition
                    $cursorY = 1 + $cursorLine
                    if ($cursorX -lt $this.Width - 1) {
                        Write-TuiText -Buffer $this._private_buffer -X $cursorX -Y $cursorY -Text "_" `
                            -ForegroundColor ([ConsoleColor]::Yellow) -BackgroundColor ([ConsoleColor]::Black)
                    }
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "MultilineTextBox render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $currentLineText = $this.Lines[$this.CurrentLine] ?? ""
            $originalLines = $this.Lines.Clone()
            $handled = $true
            
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this.CurrentLine -gt 0) {
                        $this.CurrentLine--
                        $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.Lines[$this.CurrentLine].Length)
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $this.CurrentLine++
                        $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.Lines[$this.CurrentLine].Length)
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.CursorPosition -gt 0) {
                        $this.CursorPosition--
                    } elseif ($this.CurrentLine -gt 0) {
                        $this.CurrentLine--
                        $this.CursorPosition = $this.Lines[$this.CurrentLine].Length
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.CursorPosition -lt $currentLineText.Length) {
                        $this.CursorPosition++
                    } elseif ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $this.CurrentLine++
                        $this.CursorPosition = 0
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::Home) { $this.CursorPosition = 0 }
                ([ConsoleKey]::End) { $this.CursorPosition = $currentLineText.Length }
                ([ConsoleKey]::Enter) {
                    if ($this.Lines.Count -lt $this.MaxLines) {
                        $beforeCursor = $currentLineText.Substring(0, $this.CursorPosition)
                        $afterCursor = $currentLineText.Substring($this.CursorPosition)
                        
                        $this.Lines[$this.CurrentLine] = $beforeCursor
                        $this.Lines = @($this.Lines[0..$this.CurrentLine]) + @($afterCursor) + @($this.Lines[($this.CurrentLine + 1)..($this.Lines.Count - 1)])
                        
                        $this.CurrentLine++
                        $this.CursorPosition = 0
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CursorPosition -gt 0) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Remove($this.CursorPosition - 1, 1)
                        $this.CursorPosition--
                    } elseif ($this.CurrentLine -gt 0 -and $this.Lines.Count -gt 1) {
                        $previousLine = $this.Lines[$this.CurrentLine - 1]
                        $this.CursorPosition = $previousLine.Length
                        $this.Lines[$this.CurrentLine - 1] = $previousLine + $currentLineText
                        $this.Lines = @($this.Lines[0..($this.CurrentLine - 1)]) + @($this.Lines[($this.CurrentLine + 1)..($this.Lines.Count - 1)])
                        $this.CurrentLine--
                        $this._UpdateScrolling()
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($this.CursorPosition -lt $currentLineText.Length) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Remove($this.CursorPosition, 1)
                    } elseif ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $nextLine = $this.Lines[$this.CurrentLine + 1]
                        $this.Lines[$this.CurrentLine] = $currentLineText + $nextLine
                        $this.Lines = @($this.Lines[0..$this.CurrentLine]) + @($this.Lines[($this.CurrentLine + 2)..($this.Lines.Count - 1)])
                    }
                }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar) -and $currentLineText.Length -lt $this.MaxLineLength) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Insert($this.CursorPosition, $key.KeyChar)
                        $this.CursorPosition++
                    } else {
                        $handled = $false
                    }
                }
            }
            
            if ($handled -and $this.OnChange -and -not $this._ArraysEqual($originalLines, $this.Lines)) {
                Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -Context "Change Event" -ScriptBlock { 
                    & $this.OnChange -NewValue $this.Lines 
                }
                $this.RequestRedraw()
            }
            
            return $handled
        } catch { 
            Write-Log -Level Error -Message "MultilineTextBox input error for '$($this.Name)': $_"
            return $false 
        }
    }
    
    hidden [void] _UpdateScrolling() {
        $textAreaHeight = $this.Height - 2
        if ($this.CurrentLine -lt $this.ScrollOffsetY) {
            $this.ScrollOffsetY = $this.CurrentLine
        } elseif ($this.CurrentLine -ge ($this.ScrollOffsetY + $textAreaHeight)) {
            $this.ScrollOffsetY = $this.CurrentLine - $textAreaHeight + 1
        }
    }
    
    hidden [bool] _ArraysEqual([string[]]$array1, [string[]]$array2) {
        if ($array1.Count -ne $array2.Count) { return $false }
        for ($i = 0; $i -lt $array1.Count; $i++) {
            if ($array1[$i] -ne $array2[$i]) { return $false }
        }
        return $true
    }
    
    [string] GetText() {
        return $this.Lines -join "`n"
    }
    
    [void] SetText([string]$text) {
        $this.Lines = if ([string]::IsNullOrEmpty($text)) { @("") } else { $text -split "`n" }
        $this.CurrentLine = 0
        $this.CursorPosition = 0
        $this.ScrollOffsetY = 0
        $this.RequestRedraw()
    }
}

# AI: REFACTORED - NumericInput converted from functional to class-based
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

# AI: REFACTORED - DateInput converted from functional to class-based
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

# AI: REFACTORED - ComboBox converted from functional to class-based
class ComboBoxComponent : UIElement {
    [object[]]$Items = @()
    [object]$SelectedItem = $null
    [int]$SelectedIndex = -1
    [string]$DisplayMember = "Display"
    [string]$ValueMember = "Value"
    [string]$Placeholder = "Select an item..."
    [bool]$IsDropDownOpen = $false
    [int]$MaxDropDownHeight = 6
    [int]$ScrollOffset = 0
    [scriptblock]$OnSelectionChanged
    
    ComboBoxComponent([string]$name) : base() {
        $this.Name = $name
        $this.IsFocusable = $true
        $this.Width = 30
        $this.Height = 3
    }
    
    # AI: REFACTORED - Now uses UIElement buffer system
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            
            # AI: Draw main combobox
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Display selected item or placeholder
            $displayText = ""
            if ($this.SelectedItem) {
                if ($this.SelectedItem -is [string]) {
                    $displayText = $this.SelectedItem
                } elseif ($this.SelectedItem -is [hashtable] -and $this.SelectedItem.ContainsKey($this.DisplayMember)) {
                    $displayText = $this.SelectedItem[$this.DisplayMember]
                } else {
                    $displayText = $this.SelectedItem.ToString()
                }
            } else {
                $displayText = $this.Placeholder
            }
            
            $maxDisplayLength = $this.Width - 6
            if ($displayText.Length -gt $maxDisplayLength) {
                $displayText = $displayText.Substring(0, $maxDisplayLength - 3) + "..."
            }
            
            $textColor = $this.SelectedItem ? [ConsoleColor]::White : [ConsoleColor]::DarkGray
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y 1 -Text $displayText `
                -ForegroundColor $textColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw dropdown arrow
            $arrow = $this.IsDropDownOpen ? "▲" : "▼"
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 1 -Text $arrow `
                -ForegroundColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
        } catch { 
            Write-Log -Level Error -Message "ComboBox render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $handled = $true
            $originalSelection = $this.SelectedItem
            
            if ($this.IsDropDownOpen) {
                switch ($key.Key) {
                    ([ConsoleKey]::Escape) {
                        $this.IsDropDownOpen = $false
                    }
                    ([ConsoleKey]::Enter) {
                        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
                            $this.SelectedItem = $this.Items[$this.SelectedIndex]
                        }
                        $this.IsDropDownOpen = $false
                    }
                    ([ConsoleKey]::UpArrow) {
                        if ($this.SelectedIndex -gt 0) {
                            $this.SelectedIndex--
                            $this._UpdateScrolling()
                        }
                    }
                    ([ConsoleKey]::DownArrow) {
                        if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                            $this.SelectedIndex++
                            $this._UpdateScrolling()
                        }
                    }
                    default { $handled = $false }
                }
            } else {
                switch ($key.Key) {
                    ([ConsoleKey]::Enter) { $this._OpenDropDown() }
                    ([ConsoleKey]::Spacebar) { $this._OpenDropDown() }
                    ([ConsoleKey]::DownArrow) { $this._OpenDropDown() }
                    ([ConsoleKey]::UpArrow) { $this._OpenDropDown() }
                    ([ConsoleKey]::F4) { $this._OpenDropDown() }
                    default { $handled = $false }
                }
            }
            
            if ($handled -and $this.SelectedItem -ne $originalSelection -and $this.OnSelectionChanged) {
                Invoke-WithErrorHandling -Component "$($this.Name).OnSelectionChanged" -Context "Selection Change" -ScriptBlock { 
                    & $this.OnSelectionChanged -SelectedItem $this.SelectedItem 
                }
                $this.RequestRedraw()
            }
            
            return $handled
        } catch { 
            Write-Log -Level Error -Message "ComboBox input error for '$($this.Name)': $_"
            return $false 
        }
    }
    
    hidden [void] _OpenDropDown() {
        if ($this.Items.Count -gt 0) {
            $this.IsDropDownOpen = $true
            $this._FindCurrentSelection()
        }
    }
    
    hidden [void] _FindCurrentSelection() {
        $this.SelectedIndex = -1
        if ($this.SelectedItem) {
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                if ($this._ItemsEqual($this.Items[$i], $this.SelectedItem)) {
                    $this.SelectedIndex = $i
                    break
                }
            }
        }
        if ($this.SelectedIndex -eq -1) { $this.SelectedIndex = 0 }
        $this._UpdateScrolling()
    }
    
    hidden [void] _UpdateScrolling() {
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $this.MaxDropDownHeight)) {
            $this.ScrollOffset = $this.SelectedIndex - $this.MaxDropDownHeight + 1
        }
    }
    
    hidden [bool] _ItemsEqual([object]$item1, [object]$item2) {
        if ($item1 -is [string] -and $item2 -is [string]) {
            return $item1 -eq $item2
        } elseif ($item1 -is [hashtable] -and $item2 -is [hashtable]) {
            return $item1[$this.ValueMember] -eq $item2[$this.ValueMember]
        } else {
            return $item1 -eq $item2
        }
    }
    
    [void] SetItems([object[]]$items) {
        $this.Items = $items
        $this.SelectedItem = $null
        $this.SelectedIndex = -1
        $this.ScrollOffset = 0
        $this.IsDropDownOpen = $false
        $this.RequestRedraw()
    }
    
    [object] GetSelectedValue() {
        if ($this.SelectedItem -is [hashtable] -and $this.SelectedItem.ContainsKey($this.ValueMember)) {
            return $this.SelectedItem[$this.ValueMember]
        }
        return $this.SelectedItem
    }
}

#endregion

#region Factory Functions

# AI: Updated factories to return class instances

function New-TuiMultilineTextBox {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "MultilineTextBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $textBox = [MultilineTextBoxComponent]::new($name)
    
    $textBox.X = $Props.X ?? $textBox.X
    $textBox.Y = $Props.Y ?? $textBox.Y
    $textBox.Width = $Props.Width ?? $textBox.Width
    $textBox.Height = $Props.Height ?? $textBox.Height
    $textBox.Visible = $Props.Visible ?? $textBox.Visible
    $textBox.ZIndex = $Props.ZIndex ?? $textBox.ZIndex
    $textBox.Placeholder = $Props.Placeholder ?? $textBox.Placeholder
    $textBox.MaxLines = $Props.MaxLines ?? $textBox.MaxLines
    $textBox.MaxLineLength = $Props.MaxLineLength ?? $textBox.MaxLineLength
    $textBox.WordWrap = $Props.WordWrap ?? $textBox.WordWrap
    $textBox.OnChange = $Props.OnChange ?? $textBox.OnChange
    
    if ($Props.Text) {
        $textBox.SetText($Props.Text)
    }
    
    return $textBox
}

function New-TuiNumericInput {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "NumericInput_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $numericInput = [NumericInputComponent]::new($name)
    
    $numericInput.X = $Props.X ?? $numericInput.X
    $numericInput.Y = $Props.Y ?? $numericInput.Y
    $numericInput.Width = $Props.Width ?? $numericInput.Width
    $numericInput.Height = $Props.Height ?? $numericInput.Height
    $numericInput.Visible = $Props.Visible ?? $numericInput.Visible
    $numericInput.ZIndex = $Props.ZIndex ?? $numericInput.ZIndex
    $numericInput.Value = $Props.Value ?? $numericInput.Value
    $numericInput.Min = $Props.Min ?? $numericInput.Min
    $numericInput.Max = $Props.Max ?? $numericInput.Max
    $numericInput.Step = $Props.Step ?? $numericInput.Step
    $numericInput.DecimalPlaces = $Props.DecimalPlaces ?? $numericInput.DecimalPlaces
    $numericInput.Suffix = $Props.Suffix ?? $numericInput.Suffix
    $numericInput.OnChange = $Props.OnChange ?? $numericInput.OnChange
    
    # Update text value based on initial value
    $numericInput.TextValue = $numericInput.Value.ToString("F$($numericInput.DecimalPlaces)")
    
    return $numericInput
}

function New-TuiDateInput {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "DateInput_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $dateInput = [DateInputComponent]::new($name)
    
    $dateInput.X = $Props.X ?? $dateInput.X
    $dateInput.Y = $Props.Y ?? $dateInput.Y
    $dateInput.Width = $Props.Width ?? $dateInput.Width
    $dateInput.Height = $Props.Height ?? $dateInput.Height
    $dateInput.Visible = $Props.Visible ?? $dateInput.Visible
    $dateInput.ZIndex = $Props.ZIndex ?? $dateInput.ZIndex
    $dateInput.Value = $Props.Value ?? $dateInput.Value
    $dateInput.MinDate = $Props.MinDate ?? $dateInput.MinDate
    $dateInput.MaxDate = $Props.MaxDate ?? $dateInput.MaxDate
    $dateInput.Format = $Props.Format ?? $dateInput.Format
    $dateInput.OnChange = $Props.OnChange ?? $dateInput.OnChange
    
    # Update text value based on initial value
    $dateInput.TextValue = $dateInput.Value.ToString($dateInput.Format)
    
    return $dateInput
}

function New-TuiComboBox {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "ComboBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $comboBox = [ComboBoxComponent]::new($name)
    
    $comboBox.X = $Props.X ?? $comboBox.X
    $comboBox.Y = $Props.Y ?? $comboBox.Y
    $comboBox.Width = $Props.Width ?? $comboBox.Width
    $comboBox.Height = $Props.Height ?? $comboBox.Height
    $comboBox.Visible = $Props.Visible ?? $comboBox.Visible
    $comboBox.ZIndex = $Props.ZIndex ?? $comboBox.ZIndex
    $comboBox.DisplayMember = $Props.DisplayMember ?? $comboBox.DisplayMember
    $comboBox.ValueMember = $Props.ValueMember ?? $comboBox.ValueMember
    $comboBox.Placeholder = $Props.Placeholder ?? $comboBox.Placeholder
    $comboBox.MaxDropDownHeight = $Props.MaxDropDownHeight ?? $comboBox.MaxDropDownHeight
    $comboBox.OnSelectionChanged = $Props.OnSelectionChanged ?? $comboBox.OnSelectionChanged
    
    if ($Props.Items) {
        $comboBox.SetItems($Props.Items)
    }
    
    if ($Props.SelectedItem) {
        $comboBox.SelectedItem = $Props.SelectedItem
    }
    
    return $comboBox
}

#endregion

Export-ModuleMember -Function 'New-TuiMultilineTextBox', 'New-TuiNumericInput', 'New-TuiDateInput', 'New-TuiComboBox'