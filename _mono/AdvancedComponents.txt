# ==============================================================================
# Axiom-Phoenix v4.0 - Advanced & Data Components
# Contains advanced input components (MultilineTextBox, NumericInput, DateInput,
# ComboBox) and data display components (Table, DataGrid).
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#<!-- PAGE: ACO.006 - MultilineTextBoxComponent Class -->
# ===== CLASS: MultilineTextBoxComponent =====
# Module: advanced-input-components
# Dependencies: UIElement, TuiCell
# Purpose: Full text editor with scrolling
class MultilineTextBoxComponent : UIElement {
    [List[string]]$Lines
    [int]$CursorLine = 0
    [int]$CursorColumn = 0
    [int]$ScrollOffsetY = 0
    [int]$ScrollOffsetX = 0
    [bool]$ReadOnly = $false
    [scriptblock]$OnChange
    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$BorderColor = "#808080"
    
    MultilineTextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Lines = [List[string]]::new()
        $this.Lines.Add("")
        $this.Width = 40
        $this.Height = 10
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor -ColorName "input.background" -DefaultColor $this.BackgroundColor
            $fgColor = Get-ThemeColor -ColorName "input.foreground" -DefaultColor $this.ForegroundColor
            $borderColorValue = if ($this.IsFocused) { Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF" } else { Get-ThemeColor -ColorName "component.border" -DefaultColor $this.BorderColor }
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            
            # Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                -Width $this.Width -Height $this.Height `
                -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = "Single" }
            
            # Calculate visible area
            $contentWidth = $this.Width - 2
            $contentHeight = $this.Height - 2
            
            # Adjust scroll to keep cursor visible
            if ($this.CursorLine -lt $this.ScrollOffsetY) {
                $this.ScrollOffsetY = $this.CursorLine
            }
            elseif ($this.CursorLine -ge $this.ScrollOffsetY + $contentHeight) {
                $this.ScrollOffsetY = $this.CursorLine - $contentHeight + 1
            }
            
            if ($this.CursorColumn -lt $this.ScrollOffsetX) {
                $this.ScrollOffsetX = $this.CursorColumn
            }
            elseif ($this.CursorColumn -ge $this.ScrollOffsetX + $contentWidth) {
                $this.ScrollOffsetX = $this.CursorColumn - $contentWidth + 1
            }
            
            # Draw visible lines
            for ($y = 0; $y -lt $contentHeight; $y++) {
                $lineIndex = $y + $this.ScrollOffsetY
                if ($lineIndex -lt $this.Lines.Count) {
                    $line = $this.Lines[$lineIndex]
                    $visiblePart = ""
                    
                    if ($line.Length -gt $this.ScrollOffsetX) {
                        $endPos = [Math]::Min($this.ScrollOffsetX + $contentWidth, $line.Length)
                        $visiblePart = $line.Substring($this.ScrollOffsetX, $endPos - $this.ScrollOffsetX)
                    }
                    
                    if ($visiblePart) {
                        Write-TuiText -Buffer $this._private_buffer -X 1 -Y ($y + 1) -Text $visiblePart -Style @{ FG = $fgColor; BG = $bgColor }
                    }
                }
            }
            
            # Draw cursor if focused
            if ($this.IsFocused -and -not $this.ReadOnly) {
                $cursorScreenY = $this.CursorLine - $this.ScrollOffsetY + 1
                $cursorScreenX = $this.CursorColumn - $this.ScrollOffsetX + 1
                
                if ($cursorScreenY -ge 1 -and $cursorScreenY -lt $this.Height - 1 -and
                    $cursorScreenX -ge 1 -and $cursorScreenX -lt $this.Width - 1) {
                    
                    $currentLine = $this.Lines[$this.CursorLine]
                    $cursorChar = ' '
                    if ($this.CursorColumn -lt $currentLine.Length) {
                        $cursorChar = $currentLine[$this.CursorColumn]
                    }
                    
                    $this._private_buffer.SetCell($cursorScreenX, $cursorScreenY,
                        [TuiCell]::new($cursorChar, $bgColor, $fgColor))
                }
            }
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or $this.ReadOnly) { return $false }
        
        $handled = $true
        $changed = $false
        
        switch ($key.Key) {
            ([ConsoleKey]::LeftArrow) {
                if ($this.CursorColumn -gt 0) {
                    $this.CursorColumn--
                }
                elseif ($this.CursorLine -gt 0) {
                    $this.CursorLine--
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
            }
            ([ConsoleKey]::RightArrow) {
                $currentLine = $this.Lines[$this.CursorLine]
                if ($this.CursorColumn -lt $currentLine.Length) {
                    $this.CursorColumn++
                }
                elseif ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $this.CursorLine++
                    $this.CursorColumn = 0
                }
            }
            ([ConsoleKey]::UpArrow) {
                if ($this.CursorLine -gt 0) {
                    $this.CursorLine--
                    $newLineLength = $this.Lines[$this.CursorLine].Length
                    if ($this.CursorColumn -gt $newLineLength) {
                        $this.CursorColumn = $newLineLength
                    }
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $this.CursorLine++
                    $newLineLength = $this.Lines[$this.CursorLine].Length
                    if ($this.CursorColumn -gt $newLineLength) {
                        $this.CursorColumn = $newLineLength
                    }
                }
            }
            ([ConsoleKey]::Home) {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    $this.CursorLine = 0
                    $this.CursorColumn = 0
                }
                else {
                    $this.CursorColumn = 0
                }
            }
            ([ConsoleKey]::End) {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    $this.CursorLine = $this.Lines.Count - 1
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
                else {
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
            }
            ([ConsoleKey]::Enter) {
                $currentLine = $this.Lines[$this.CursorLine]
                $beforeCursor = $currentLine.Substring(0, $this.CursorColumn)
                $afterCursor = $currentLine.Substring($this.CursorColumn)
                
                $this.Lines[$this.CursorLine] = $beforeCursor
                $this.Lines.Insert($this.CursorLine + 1, $afterCursor)
                
                $this.CursorLine++
                $this.CursorColumn = 0
                $changed = $true
            }
            ([ConsoleKey]::Backspace) {
                if ($this.CursorColumn -gt 0) {
                    $currentLine = $this.Lines[$this.CursorLine]
                    $this.Lines[$this.CursorLine] = $currentLine.Remove($this.CursorColumn - 1, 1)
                    $this.CursorColumn--
                    $changed = $true
                }
                elseif ($this.CursorLine -gt 0) {
                    $currentLine = $this.Lines[$this.CursorLine]
                    $previousLine = $this.Lines[$this.CursorLine - 1]
                    $this.CursorColumn = $previousLine.Length
                    $this.Lines[$this.CursorLine - 1] = $previousLine + $currentLine
                    $this.Lines.RemoveAt($this.CursorLine)
                    $this.CursorLine--
                    $changed = $true
                }
            }
            ([ConsoleKey]::Delete) {
                $currentLine = $this.Lines[$this.CursorLine]
                if ($this.CursorColumn -lt $currentLine.Length) {
                    $this.Lines[$this.CursorLine] = $currentLine.Remove($this.CursorColumn, 1)
                    $changed = $true
                }
                elseif ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $nextLine = $this.Lines[$this.CursorLine + 1]
                    $this.Lines[$this.CursorLine] = $currentLine + $nextLine
                    $this.Lines.RemoveAt($this.CursorLine + 1)
                    $changed = $true
                }
            }
            default {
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    $currentLine = $this.Lines[$this.CursorLine]
                    $this.Lines[$this.CursorLine] = $currentLine.Insert($this.CursorColumn, $key.KeyChar)
                    $this.CursorColumn++
                    $changed = $true
                }
                else {
                    $handled = $false
                }
            }
        }
        
        if ($handled) {
            if ($changed -and $this.OnChange) {
                try { & $this.OnChange $this $this.GetText() } catch {}
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    [string] GetText() {
        return ($this.Lines -join "`n")
    }
    
    [void] SetText([string]$text) {
        $this.Lines.Clear()
        $splitLines = $text -split "`n"
        foreach ($line in $splitLines) {
            $this.Lines.Add($line)
        }
        if ($this.Lines.Count -eq 0) {
            $this.Lines.Add("")
        }
        $this.CursorLine = 0
        $this.CursorColumn = 0
        $this.ScrollOffsetY = 0
        $this.ScrollOffsetX = 0
        $this.RequestRedraw()
    }
}

#<!-- END_PAGE: ACO.006 -->

#<!-- PAGE: ACO.007 - NumericInputComponent Class -->
# ===== CLASS: NumericInputComponent =====
# Module: advanced-input-components
# Dependencies: UIElement, TuiCell
# Purpose: Numeric input with spinners and validation
class NumericInputComponent : UIElement {
    [double]$Value = 0
    [double]$Minimum = [double]::MinValue
    [double]$Maximum = [double]::MaxValue
    [double]$Step = 1
    [int]$DecimalPlaces = 0
    [scriptblock]$OnChange
    hidden [string]$_textValue = "0"
    hidden [int]$_cursorPosition = 1
    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$BorderColor = "#808080"
    
    NumericInputComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 15
        $this.Height = 3
        $this._textValue = $this.FormatValue($this.Value)
        $this._cursorPosition = $this._textValue.Length
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor -ColorName "input.background" -DefaultColor $this.BackgroundColor
            $fgColor = Get-ThemeColor -ColorName "input.foreground" -DefaultColor $this.ForegroundColor
            $borderColorValue = if ($this.IsFocused) { Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF" } else { Get-ThemeColor -ColorName "component.border" -DefaultColor $this.BorderColor }
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            
            # Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                -Width $this.Width -Height $this.Height `
                -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = "Single" }
            
            # Draw spinners
            $spinnerColor = if ($this.IsFocused) { "#FFFF00" } else { "#808080" }
            $this._private_buffer.SetCell($this.Width - 2, 1, [TuiCell]::new('▲', $spinnerColor, $bgColor))
            $this._private_buffer.SetCell($this.Width - 2, $this.Height - 2, [TuiCell]::new('▼', $spinnerColor, $bgColor))
            
            # Draw value
            $displayValue = $this._textValue
            $maxTextWidth = $this.Width - 4  # Border + spinner
            if ($displayValue.Length -gt $maxTextWidth) {
                $displayValue = $displayValue.Substring(0, $maxTextWidth)
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $displayValue -Style @{ FG = $fgColor; BG = $bgColor }
            
            # Draw cursor if focused
            if ($this.IsFocused -and $this._cursorPosition -le $displayValue.Length) {
                $cursorX = 1 + $this._cursorPosition
                if ($cursorX -lt $this.Width - 2) {
                    if ($this._cursorPosition -lt $this._textValue.Length) {
                        $cursorChar = $this._textValue[$this._cursorPosition]
                    } else { 
                        $cursorChar = ' ' 
                    }
                    
                    $this._private_buffer.SetCell($cursorX, 1, 
                        [TuiCell]::new($cursorChar, $bgColor, $fgColor))
                }
            }
        }
        catch {}
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $handled = $true
        $oldValue = $this.Value
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                $this.IncrementValue()
            }
            ([ConsoleKey]::DownArrow) {
                $this.DecrementValue()
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this._cursorPosition -gt 0) {
                    $this._cursorPosition--
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($this._cursorPosition -lt $this._textValue.Length) {
                    $this._cursorPosition++
                }
            }
            ([ConsoleKey]::Home) {
                $this._cursorPosition = 0
            }
            ([ConsoleKey]::End) {
                $this._cursorPosition = $this._textValue.Length
            }
            ([ConsoleKey]::Backspace) {
                if ($this._cursorPosition -gt 0) {
                    $this._textValue = $this._textValue.Remove($this._cursorPosition - 1, 1)
                    $this._cursorPosition--
                    $this.ParseAndValidate()
                }
            }
            ([ConsoleKey]::Delete) {
                if ($this._cursorPosition -lt $this._textValue.Length) {
                    $this._textValue = $this._textValue.Remove($this._cursorPosition, 1)
                    $this.ParseAndValidate()
                }
            }
            ([ConsoleKey]::Enter) {
                $this.ParseAndValidate()
            }
            default {
                if ($key.KeyChar -and ($key.KeyChar -match '[0-9.\-]')) {
                    # Allow only valid numeric characters
                    if ($key.KeyChar -eq '.' -and $this._textValue.Contains('.')) {
                        # Only one decimal point allowed
                        $handled = $false
                    }
                    elseif ($key.KeyChar -eq '-' -and ($this._cursorPosition -ne 0 -or $this._textValue.Contains('-'))) {
                        # Minus only at beginning
                        $handled = $false
                    }
                    else {
                        $this._textValue = $this._textValue.Insert($this._cursorPosition, $key.KeyChar)
                        $this._cursorPosition++
                        $this.ParseAndValidate()
                    }
                }
                else {
                    $handled = $false
                }
            }
        }
        
        if ($handled) {
            if ($oldValue -ne $this.Value -and $this.OnChange) {
                try { & $this.OnChange $this $this.Value } catch {}
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    hidden [void] IncrementValue() {
        $newValue = $this.Value + $this.Step
        if ($newValue -le $this.Maximum) {
            $this.Value = $newValue
            $this._textValue = $this.FormatValue($this.Value)
            $this._cursorPosition = $this._textValue.Length
        }
    }
    
    hidden [void] DecrementValue() {
        $newValue = $this.Value - $this.Step
        if ($newValue -ge $this.Minimum) {
            $this.Value = $newValue
            $this._textValue = $this.FormatValue($this.Value)
            $this._cursorPosition = $this._textValue.Length
        }
    }
    
    hidden [void] ParseAndValidate() {
        try {
            $parsedValue = [double]::Parse($this._textValue)
            $parsedValue = [Math]::Max($this.Minimum, [Math]::Min($this.Maximum, $parsedValue))
            $this.Value = $parsedValue
        }
        catch {
            # Keep current value if parse fails
        }
    }
    
    hidden [string] FormatValue([double]$value) {
        if ($this.DecimalPlaces -eq 0) {
            return [Math]::Truncate($value).ToString()
        }
        else {
            return $value.ToString("F$($this.DecimalPlaces)")
        }
    }
}

#<!-- END_PAGE: ACO.007 -->

#<!-- PAGE: ACO.008 - DateInputComponent Class -->
# ===== CLASS: DateInputComponent =====
# Module: advanced-input-components
# Dependencies: UIElement, TuiCell
# Purpose: Date picker with calendar interface
class DateInputComponent : UIElement {
    [DateTime]$Value = [DateTime]::Today
    [DateTime]$MinDate = [DateTime]::MinValue
    [DateTime]$MaxDate = [DateTime]::MaxValue
    [scriptblock]$OnChange
    hidden [bool]$_showCalendar = $false
    hidden [DateTime]$_viewMonth
    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$BorderColor = "#808080"
    
    DateInputComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 25
        $this.Height = 1  # Expands to 10 when calendar shown
        $this._viewMonth = $this.Value
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor -ColorName "input.background" -DefaultColor $this.BackgroundColor
            $fgColor = Get-ThemeColor -ColorName "input.foreground" -DefaultColor $this.ForegroundColor
            if ($this.IsFocused) { 
                $borderColorValue = Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF" 
            } else { 
                $borderColorValue = Get-ThemeColor -ColorName "component.border" -DefaultColor $this.BorderColor 
            }
            
            # Adjust height based on calendar visibility
            if ($this._showCalendar) { 
                $renderHeight = 10 
            } else { 
                $renderHeight = 3 
            }
            if ($this.Height -ne $renderHeight) {
                $this.Height = $renderHeight
                $this.RequestRedraw()
                return
            }
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            
            # Draw text box
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                -Width $this.Width -Height 3 `
                -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = "Single" }
            
            # Draw date value
            $dateStr = $this.Value.ToString("yyyy-MM-dd")
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $dateStr -Style @{ FG = $fgColor; BG = $bgColor }
            
            # Draw calendar icon
            $this._private_buffer.SetCell($this.Width - 2, 1, [TuiCell]::new('📅', $borderColorValue, $bgColor))
            
            # Draw calendar if shown
            if ($this._showCalendar) {
                $this.DrawCalendar(0, 3)
            }
        }
        catch {}
    }
    
    hidden [void] DrawCalendar([int]$startX, [int]$startY) {
        $bgColor = "#000000"
        $fgColor = "#FFFFFF"
        $headerColor = "#FFFF00"
        $selectedColor = "#00FFFF"
        $todayColor = "#00FF00"
        
        # Calendar border
        Write-TuiBox -Buffer $this._private_buffer -X $startX -Y $startY `
            -Width $this.Width -Height 7 `
            -Style @{ BorderFG = "#808080"; BG = $bgColor; BorderStyle = "Single" }
        
        # Month/Year header
        $monthYearStr = $this._viewMonth.ToString("MMMM yyyy")
        $headerX = $startX + [Math]::Floor(($this.Width - $monthYearStr.Length) / 2)
        Write-TuiText -Buffer $this._private_buffer -X $headerX -Y ($startY + 1) -Text $monthYearStr -Style @{ FG = $headerColor; BG = $bgColor }
        
        # Navigation arrows
        $this._private_buffer.SetCell($startX + 1, $startY + 1, [TuiCell]::new('<', $headerColor, $bgColor))
        $this._private_buffer.SetCell($startX + $this.Width - 2, $startY + 1, [TuiCell]::new('>', $headerColor, $bgColor))
        
        # Day headers
        $dayHeaders = @("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
        $dayX = $startX + 2
        foreach ($day in $dayHeaders) {
            Write-TuiText -Buffer $this._private_buffer -X $dayX -Y ($startY + 2) -Text $day -Style @{ FG = "#808080"; BG = $bgColor }
            $dayX += 3
        }
        
        # Calendar days
        $firstDay = [DateTime]::new($this._viewMonth.Year, $this._viewMonth.Month, 1)
        $startDayOfWeek = [int]$firstDay.DayOfWeek
        $daysInMonth = [DateTime]::DaysInMonth($this._viewMonth.Year, $this._viewMonth.Month)
        
        $currentDay = 1
        $today = [DateTime]::Today
        
        for ($week = 0; $week -lt 6; $week++) {
            if ($currentDay -gt $daysInMonth) { break }
            
            for ($dayOfWeek = 0; $dayOfWeek -lt 7; $dayOfWeek++) {
                if ($week -eq 0 -and $dayOfWeek -lt $startDayOfWeek) { continue }
                if ($currentDay -gt $daysInMonth) { break }
                
                $dayX = $startX + 2 + ($dayOfWeek * 3)
                $dayY = $startY + 3 + $week
                
                $currentDate = [DateTime]::new($this._viewMonth.Year, $this._viewMonth.Month, $currentDay)
                $dayStr = $currentDay.ToString().PadLeft(2)
                
                # Determine color
                $dayColor = $fgColor
                if ($currentDate -eq $this.Value) {
                    $dayColor = $selectedColor
                }
                elseif ($currentDate -eq $today) {
                    $dayColor = $todayColor
                }
                
                Write-TuiText -Buffer $this._private_buffer -X $dayX -Y $dayY -Text $dayStr -Style @{ FG = $dayColor; BG = $bgColor }
                $currentDay++
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $handled = $true
        $oldValue = $this.Value
        
        if (-not $this._showCalendar) {
            switch ($key.Key) {
                ([ConsoleKey]::Enter) { $this._showCalendar = $true }
                ([ConsoleKey]::Spacebar) { $this._showCalendar = $true }
                ([ConsoleKey]::DownArrow) { $this._showCalendar = $true }
                default { $handled = $false }
            }
        }
        else {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) { 
                    $this._showCalendar = $false 
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                        # Previous month
                        $this._viewMonth = $this._viewMonth.AddMonths(-1)
                    }
                    else {
                        # Previous day
                        $newDate = $this.Value.AddDays(-1)
                        if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                            $this.Value = $newDate
                            $this._viewMonth = $newDate
                        }
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                        # Next month
                        $this._viewMonth = $this._viewMonth.AddMonths(1)
                    }
                    else {
                        # Next day
                        $newDate = $this.Value.AddDays(1)
                        if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                            $this.Value = $newDate
                            $this._viewMonth = $newDate
                        }
                    }
                }
                ([ConsoleKey]::UpArrow) {
                    # Previous week
                    $newDate = $this.Value.AddDays(-7)
                    if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                        $this.Value = $newDate
                        $this._viewMonth = $newDate
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    # Next week
                    $newDate = $this.Value.AddDays(7)
                    if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                        $this.Value = $newDate
                        $this._viewMonth = $newDate
                    }
                }
                ([ConsoleKey]::Enter) {
                    $this._showCalendar = $false
                }
                ([ConsoleKey]::T) {
                    # Today
                    $today = [DateTime]::Today
                    if ($today -ge $this.MinDate -and $today -le $this.MaxDate) {
                        $this.Value = $today
                        $this._viewMonth = $today
                    }
                }
                default { $handled = $false }
            }
        }
        
        if ($handled) {
            if ($oldValue -ne $this.Value -and $this.OnChange) {
                try { & $this.OnChange $this $this.Value } catch {}
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
}

#<!-- END_PAGE: ACO.008 -->

#<!-- PAGE: ACO.009 - ComboBoxComponent Class -->
# ===== CLASS: ComboBoxComponent =====
# Module: advanced-input-components
# Dependencies: UIElement, TuiCell
# Purpose: Dropdown with search and overlay rendering
class ComboBoxComponent : UIElement {
    [List[object]]$Items
    [int]$SelectedIndex = -1
    [string]$DisplayMember = ""
    [string]$ValueMember = ""
    [bool]$IsEditable = $false
    [string]$Text = ""
    [scriptblock]$OnSelectionChanged
    hidden [bool]$_isDropdownOpen = $false
    hidden [int]$_highlightedIndex = -1
    hidden [string]$_searchText = ""
    hidden [List[int]]$_filteredIndices
    
    ComboBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 25
        $this.Height = 3
        $this.Items = [List[object]]::new()
        $this._filteredIndices = [List[int]]::new()
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor("input.background")
            $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            
            # Draw main box
            if ($this.IsFocused) { 
                $borderColor = Get-ThemeColor("Primary") 
            } else { 
                $borderColor = Get-ThemeColor("component.border") 
            }
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -Style @{ BorderFG = $borderColor; BG = $bgColor; BorderStyle = "Single" }
            
            # Draw selected text or placeholder
            $displayText = ""
            if ($this.IsEditable) {
                $displayText = $this._searchText
            }
            elseif ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
                $item = $this.Items[$this.SelectedIndex]
                $displayText = $this.GetDisplayText($item)
            }
            
            if ($displayText) { 
                $textColor = Get-ThemeColor("input.foreground") 
            } else { 
                $textColor = Get-ThemeColor("input.placeholder") 
            }
            
            $maxTextWidth = $this.Width - 4  # Border + dropdown arrow
            if ($displayText.Length -gt $maxTextWidth) {
                $displayText = $displayText.Substring(0, $maxTextWidth)
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $displayText `
                -Style @{ FG = $textColor; BG = $bgColor }
            
            # Draw dropdown arrow
            if ($this._isDropdownOpen) { 
                $arrowChar = '▲' 
            } else { 
                $arrowChar = '▼' 
            }
            if ($this.IsFocused) { 
                $arrowColor = Get-ThemeColor("Accent") 
            } else { 
                $arrowColor = Get-ThemeColor("Subtle") 
            }
            $this._private_buffer.SetCell($this.Width - 2, 1, [TuiCell]::new($arrowChar, $arrowColor, $bgColor))
            
            # Draw dropdown if open (as overlay)
            if ($this._isDropdownOpen) {
                $this.IsOverlay = $true
                $this.DrawDropdown()
            }
            else {
                $this.IsOverlay = $false
            }
        }
        catch {}
    }
    
    hidden [void] DrawDropdown() {
        $dropdownY = $this.Height
        $maxDropdownHeight = 10
        $dropdownHeight = [Math]::Min($this._filteredIndices.Count + 2, $maxDropdownHeight)
        
        if ($dropdownHeight -lt 3) { $dropdownHeight = 3 }  # Minimum height
        
        # Create dropdown buffer
        $dropdownBuffer = [TuiBuffer]::new($this.Width, $dropdownHeight)
        $dropdownBuffer.Name = "ComboDropdown"
        
        # Draw dropdown border
        Write-TuiBox -Buffer $dropdownBuffer -X 0 -Y 0 `
            -Width $this.Width -Height $dropdownHeight `
            -Style @{ BorderFG = Get-ThemeColor("component.border"); BG = Get-ThemeColor("input.background"); BorderStyle = "Single" }
        
        # Draw items
        $itemY = 1
        $maxItems = $dropdownHeight - 2
        $scrollOffset = 0
        
        if ($this._highlightedIndex -ge $maxItems) {
            $scrollOffset = $this._highlightedIndex - $maxItems + 1
        }
        
        for ($i = $scrollOffset; $i -lt $this._filteredIndices.Count -and $itemY -lt $dropdownHeight - 1; $i++) {
            $itemIndex = $this._filteredIndices[$i]
            $item = $this.Items[$itemIndex]
            $itemText = $this.GetDisplayText($item)
            
            $itemFg = Get-ThemeColor("list.item.normal")
            $itemBg = Get-ThemeColor("input.background")
            
            if ($i -eq $this._highlightedIndex) {
                $itemFg = Get-ThemeColor("list.item.selected")
                $itemBg = Get-ThemeColor("list.item.selected.background")
            }
            elseif ($itemIndex -eq $this.SelectedIndex) {
                $itemFg = Get-ThemeColor("Accent")
            }
            
            # Clear line and draw item
            for ($x = 1; $x -lt $this.Width - 1; $x++) {
                $dropdownBuffer.SetCell($x, $itemY, [TuiCell]::new(' ', $itemFg, $itemBg))
            }
            
            $maxTextWidth = $this.Width - 2
            if ($itemText.Length -gt $maxTextWidth) {
                $itemText = $itemText.Substring(0, $maxTextWidth - 3) + "..."
            }
            
            Write-TuiText -Buffer $dropdownBuffer -X 1 -Y $itemY -Text $itemText -Style @{ FG = $itemFg; BG = $itemBg }
            $itemY++
        }
        
        # Blend dropdown buffer with main buffer at dropdown position
        $absPos = $this.GetAbsolutePosition()
        $dropX = 0
        $dropY = $dropdownY
        
        for ($y = 0; $y -lt $dropdownBuffer.Height; $y++) {
            for ($x = 0; $x -lt $dropdownBuffer.Width; $x++) {
                $cell = $dropdownBuffer.GetCell($x, $y)
                if ($cell) {
                    $this._private_buffer.SetCell($dropX + $x, $dropY + $y, $cell)
                }
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $handled = $true
        
        if (-not $this._isDropdownOpen) {
            switch ($key.Key) {
                ([ConsoleKey]::Enter) { 
                    $this.OpenDropdown()
                }
                ([ConsoleKey]::Spacebar) {
                    if (-not $this.IsEditable) {
                        $this.OpenDropdown()
                    }
                    else {
                        $handled = $false
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    $this.OpenDropdown()
                }
                default {
                    if ($this.IsEditable -and $key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                        $this._searchText += $key.KeyChar
                        $this.OpenDropdown()
                        $this.FilterItems()
                    }
                    else {
                        $handled = $false
                    }
                }
            }
        }
        else {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this.CloseDropdown()
                }
                ([ConsoleKey]::Enter) {
                    if ($this._highlightedIndex -ge 0 -and $this._highlightedIndex -lt $this._filteredIndices.Count) {
                        $this.SelectItem($this._filteredIndices[$this._highlightedIndex])
                        $this.CloseDropdown()
                    }
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this._highlightedIndex -gt 0) {
                        $this._highlightedIndex--
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this._highlightedIndex -lt $this._filteredIndices.Count - 1) {
                        $this._highlightedIndex++
                    }
                }
                ([ConsoleKey]::Home) {
                    $this._highlightedIndex = 0
                }
                ([ConsoleKey]::End) {
                    $this._highlightedIndex = $this._filteredIndices.Count - 1
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.IsEditable -and $this._searchText.Length -gt 0) {
                        $this._searchText = $this._searchText.Substring(0, $this._searchText.Length - 1)
                        $this.FilterItems()
                    }
                }
                default {
                    if ($this.IsEditable -and $key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                        $this._searchText += $key.KeyChar
                        $this.FilterItems()
                    }
                    else {
                        $handled = $false
                    }
                }
            }
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    hidden [void] OpenDropdown() {
        $this._isDropdownOpen = $true
        $this.FilterItems()
        
        # Set highlighted index to selected item
        if ($this.SelectedIndex -ge 0) {
            for ($i = 0; $i -lt $this._filteredIndices.Count; $i++) {
                if ($this._filteredIndices[$i] -eq $this.SelectedIndex) {
                    $this._highlightedIndex = $i
                    break
                }
            }
        }
        
        if ($this._highlightedIndex -eq -1 -and $this._filteredIndices.Count -gt 0) {
            $this._highlightedIndex = 0
        }
    }
    
    hidden [void] CloseDropdown() {
        $this._isDropdownOpen = $false
        $this.IsOverlay = $false
        if (-not $this.IsEditable) {
            $this._searchText = ""
        }
    }
    
    hidden [void] FilterItems() {
        $this._filteredIndices.Clear()
        
        if ($this._searchText -eq "") {
            # Show all items
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                $this._filteredIndices.Add($i)
            }
        }
        else {
            # Filter items based on search text
            $searchLower = $this._searchText.ToLower()
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                $itemText = $this.GetDisplayText($this.Items[$i]).ToLower()
                if ($itemText.Contains($searchLower)) {
                    $this._filteredIndices.Add($i)
                }
            }
        }
        
        # Reset highlighted index
        if ($this._highlightedIndex -ge $this._filteredIndices.Count) {
            $this._highlightedIndex = $this._filteredIndices.Count - 1
        }
        if ($this._highlightedIndex -lt 0 -and $this._filteredIndices.Count -gt 0) {
            $this._highlightedIndex = 0
        }
    }
    
    hidden [void] SelectItem([int]$index) {
        $oldIndex = $this.SelectedIndex
        $this.SelectedIndex = $index
        
        if (-not $this.IsEditable) {
            $this.Text = $this.GetDisplayText($this.Items[$index])
        }
        
        if ($oldIndex -ne $index -and $this.OnSelectionChanged) {
            try { & $this.OnSelectionChanged $this $index } catch {}
        }
    }
    
    hidden [string] GetDisplayText([object]$item) {
        if ($null -eq $item) { return "" }
        
        if ($this.DisplayMember -and $item.PSObject.Properties[$this.DisplayMember]) {
            return $item.$($this.DisplayMember).ToString()
        }
        
        return $item.ToString()
    }
}

#<!-- END_PAGE: ACO.009 -->

#<!-- PAGE: ACO.010 - Table Class -->
# ===== CLASS: Table =====
# Module: advanced-data-components
# Dependencies: UIElement, TuiCell
# Purpose: High-performance data grid with virtual scrolling
class Table : UIElement {
    [List[PSObject]]$Items
    [List[string]]$Columns
    [hashtable]$ColumnWidths
    [int]$SelectedIndex = -1
    [bool]$ShowHeader = $true
    [bool]$ShowBorder = $true
    [bool]$AllowSelection = $true
    [scriptblock]$OnSelectionChanged
    hidden [int]$_scrollOffset = 0
    hidden [int]$_horizontalScroll = 0
    
    Table([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Items = [List[PSObject]]::new()
        $this.Columns = [List[string]]::new()
        $this.ColumnWidths = @{}
        $this.Width = 80
        $this.Height = 20
    }
    
    [void] SetColumns([string[]]$columns) {
        $this.Columns.Clear()
        foreach ($col in $columns) {
            $this.Columns.Add($col)
            if (-not $this.ColumnWidths.ContainsKey($col)) {
                $this.ColumnWidths[$col] = 15  # Default width
            }
        }
    }
    
    [void] AutoSizeColumns() {
        foreach ($col in $this.Columns) {
            $maxWidth = $col.Length
            
            foreach ($item in $this.Items) {
                if ($item.PSObject.Properties[$col]) {
                    $val = $item.$col
                    if ($null -ne $val) {
                        $len = $val.ToString().Length
                        if ($len -gt $maxWidth) {
                            $maxWidth = $len
                        }
                    }
                }
            }
            
            $this.ColumnWidths[$col] = [Math]::Min($maxWidth + 2, 30)  # Cap at 30
        }
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor("component.background")
            $fgColor = Get-ThemeColor("Foreground")
            if ($this.IsFocused) { 
                $borderColor = Get-ThemeColor("Primary") 
            } else { 
                $borderColor = Get-ThemeColor("component.border") 
            }
            $headerBg = Get-ThemeColor("list.header.bg")
            $selectedBg = Get-ThemeColor("list.item.selected.background")
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            
            $contentX = 0
            $contentY = 0
            $contentWidth = $this.Width
            $contentHeight = $this.Height
            
            # Draw border if enabled
            if ($this.ShowBorder) {
                Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                    -Width $this.Width -Height $this.Height `
                    -Style @{ BorderFG = $borderColor; BG = $bgColor; BorderStyle = "Single" }
                
                $contentX = 1
                $contentY = 1
                $contentWidth = $this.Width - 2
                $contentHeight = $this.Height - 2
            }
            
            $currentY = $contentY
            $dataStartY = $contentY
            
            # Draw header if enabled
            if ($this.ShowHeader -and $this.Columns.Count -gt 0) {
                $this.DrawHeader($contentX, $currentY, $contentWidth, $headerBg)
                $currentY++
                $dataStartY++
                
                # Draw separator line
                for ($x = $contentX; $x -lt $contentX + $contentWidth; $x++) {
                    $this._private_buffer.SetCell($x, $currentY, [TuiCell]::new('-', $borderColor, $bgColor))
                }
                $currentY++
                $dataStartY++
            }
            
            # Calculate visible rows
            $visibleRows = $contentHeight - ($dataStartY - $contentY)
            if ($visibleRows -le 0) { return }
            
            # Adjust scroll offset to keep selection visible
            if ($this.AllowSelection -and $this.SelectedIndex -ge 0) {
                if ($this.SelectedIndex -lt $this._scrollOffset) {
                    $this._scrollOffset = $this.SelectedIndex
                }
                elseif ($this.SelectedIndex -ge $this._scrollOffset + $visibleRows) {
                    $this._scrollOffset = $this.SelectedIndex - $visibleRows + 1
                }
            }
            
            # Draw data rows
            for ($i = 0; $i -lt $visibleRows; $i++) {
                $itemIndex = $i + $this._scrollOffset
                if ($itemIndex -ge $this.Items.Count) { break }
                
                $item = $this.Items[$itemIndex]
                $rowBg = $bgColor
                $rowFg = $fgColor
                
                if ($this.AllowSelection -and $itemIndex -eq $this.SelectedIndex) {
                    $rowBg = $selectedBg
                    $rowFg = Get-ThemeColor("list.item.selected")
                }
                
                $this.DrawRow($item, $contentX, $currentY, $contentWidth, $rowFg, $rowBg)
                $currentY++
            }
            
            # Draw scrollbar if needed
            if ($this.Items.Count -gt $visibleRows) {
                $this.DrawScrollbar($contentX + $contentWidth - 1, $dataStartY, $visibleRows)
            }
        }
        catch {}
    }
    
    hidden [void] DrawHeader([int]$x, [int]$y, [int]$maxWidth, [string]$headerBg) {
        $currentX = $x - $this._horizontalScroll
        
        foreach ($col in $this.Columns) {
            $colWidth = $this.ColumnWidths[$col]
            
            if ($currentX + $colWidth -gt $x) {
                $visibleStart = [Math]::Max(0, $x - $currentX)
                $visibleWidth = [Math]::Min($colWidth - $visibleStart, $maxWidth - ($currentX - $x))
                
                if ($visibleWidth -gt 0) {
                    $headerText = $col
                    if ($headerText.Length -gt $visibleWidth) {
                        $headerText = $headerText.Substring(0, $visibleWidth - 1) + ">"
                    }
                    else {
                        $headerText = $headerText.PadRight($visibleWidth)
                    }
                    
                    $drawX = [Math]::Max($x, $currentX)
                    Write-TuiText -Buffer $this._private_buffer -X $drawX -Y $y -Text $headerText -Style @{ FG = Get-ThemeColor("list.header.fg"); BG = $headerBg }
                }
            }
            
            $currentX += $colWidth
            if ($currentX -ge $x + $maxWidth) { break }
        }
    }
    
    hidden [void] DrawRow([PSObject]$item, [int]$x, [int]$y, [int]$maxWidth, [string]$fg, [string]$bg) {
        # Clear row first
        for ($i = 0; $i -lt $maxWidth; $i++) {
            $this._private_buffer.SetCell($x + $i, $y, [TuiCell]::new(' ', $fg, $bg))
        }
        
        $currentX = $x - $this._horizontalScroll
        
        foreach ($col in $this.Columns) {
            $colWidth = $this.ColumnWidths[$col]
            
            if ($currentX + $colWidth -gt $x) {
                $value = ""
                if ($item.PSObject.Properties[$col]) {
                    $val = $item.$col
                    if ($null -ne $val) {
                        $value = $val.ToString()
                    }
                }
                
                $visibleStart = [Math]::Max(0, $x - $currentX)
                $visibleWidth = [Math]::Min($colWidth - $visibleStart, $maxWidth - ($currentX - $x))
                
                if ($visibleWidth -gt 0) {
                    if ($value.Length -gt $visibleWidth - 1) {
                        $value = $value.Substring(0, $visibleWidth - 2) + ".."
                    }
                    
                    $drawX = [Math]::Max($x, $currentX)
                    Write-TuiText -Buffer $this._private_buffer -X $drawX -Y $y -Text $value -Style @{ FG = $fg; BG = $bg }
                }
            }
            
            $currentX += $colWidth
            if ($currentX -ge $x + $maxWidth) { break }
        }
    }
    
    hidden [void] DrawScrollbar([int]$x, [int]$y, [int]$height) {
        $scrollbarHeight = [Math]::Max(1, [int]($height * $height / $this.Items.Count))
        $scrollbarPos = [int](($height - $scrollbarHeight) * $this._scrollOffset / ($this.Items.Count - $height))
        
        $scrollbarColor = Get-ThemeColor("list.scrollbar")
        $bgColor = Get-ThemeColor("component.background")
        
        for ($i = 0; $i -lt $height; $i++) {
            $char = if ($i -ge $scrollbarPos -and $i -lt $scrollbarPos + $scrollbarHeight) { '█' } else { '│' }
            $this._private_buffer.SetCell($x, $y + $i, [TuiCell]::new($char, $scrollbarColor, $bgColor))
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or -not $this.AllowSelection) { return $false }
        
        $handled = $true
        $oldSelection = $this.SelectedIndex
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectedIndex++
                }
            }
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
            }
            ([ConsoleKey]::PageUp) {
                $pageSize = $this.Height - 4  # Account for border and header
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
            }
            ([ConsoleKey]::PageDown) {
                $pageSize = $this.Height - 4
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $pageSize)
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this._horizontalScroll -gt 0) {
                    $this._horizontalScroll = [Math]::Max(0, $this._horizontalScroll - 5)
                }
            }
            ([ConsoleKey]::RightArrow) {
                $totalWidth = 0
                foreach ($col in $this.Columns) {
                    $totalWidth += $this.ColumnWidths[$col]
                }
                $maxScroll = [Math]::Max(0, $totalWidth - $this.Width + 2)
                $this._horizontalScroll = [Math]::Min($maxScroll, $this._horizontalScroll + 5)
            }
            default {
                $handled = $false
            }
        }
        
        if ($handled) {
            if ($oldSelection -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
                try { & $this.OnSelectionChanged $this $this.SelectedIndex } catch {}
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
}
#<!-- END_PAGE: ACO.010 -->

#<!-- PAGE: ACO.022 - DataGridComponent Class -->
# ===== CLASS: DataGridComponent =====
# Module: data-grid-component
# Dependencies: UIElement, TuiCell
# Purpose: Generic data grid for displaying tabular data with scrolling and selection
class DataGridComponent : UIElement {
    [hashtable[]]$Columns = @()
    [hashtable[]]$Items = @()
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowHeaders = $true
    [string]$HeaderBackgroundColor = "#333333"
    [string]$HeaderForegroundColor = "#FFFFFF"
    [string]$SelectedBackgroundColor = "#0078D4"
    [string]$SelectedForegroundColor = "#FFFFFF"
    [string]$NormalBackgroundColor = "#000000"
    [string]$NormalForegroundColor = "#C0C0C0"
    [scriptblock]$OnSelectionChanged
    
    DataGridComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 60
        $this.Height = 20
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        $y = 0
        
        # Render headers if enabled
        if ($this.ShowHeaders -and $this.Columns.Count -gt 0) {
            $x = 0
            foreach ($column in $this.Columns) {
                $header = if ($column.Header) { $column.Header } else { $column.Name }
                $width = if ($column.Width) { $column.Width } else { 10 }
                
                # Truncate header if needed
                if ($header.Length -gt $width) {
                    $header = $header.Substring(0, [Math]::Max(1, $width - 2)) + ".."
                }
                
                # Pad header to column width
                $header = $header.PadRight($width)
                
                Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $header -Style @{
                    FG = $this.HeaderForegroundColor
                    BG = $this.HeaderBackgroundColor
                }
                
                $x += $width + 1  # +1 for separator
            }
            $y++
        }
        
        # Calculate visible items
        $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
        $startIndex = $this.ScrollOffset
        $endIndex = [Math]::Min($this.Items.Count - 1, $startIndex + $visibleHeight - 1)
        
        # Render data rows
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            if ($i -ge $this.Items.Count) { break }
            
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            $x = 0
            foreach ($column in $this.Columns) {
                $value = if ($item.ContainsKey($column.Name)) { $item[$column.Name] } else { "" }
                $width = if ($column.Width) { $column.Width } else { 10 }
                
                # Convert value to string and truncate if needed
                $text = $value.ToString()
                if ($text.Length -gt $width) {
                    $text = $text.Substring(0, [Math]::Max(1, $width - 2)) + ".."
                }
                
                # Pad text to column width
                $text = $text.PadRight($width)
                
                # Set colors based on selection
                $fgColor = if ($isSelected) { $this.SelectedForegroundColor } else { $this.NormalForegroundColor }
                $bgColor = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.NormalBackgroundColor }
                
                Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $text -Style @{
                    FG = $fgColor
                    BG = $bgColor
                }
                
                $x += $width + 1  # +1 for separator
            }
            $y++
        }
        
        $this._needs_redraw = $false
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.Enabled -or -not $this.IsFocused) { return $false }
        
        $handled = $false
        $oldSelectedIndex = $this.SelectedIndex
        
        switch ($key.Key) {
            "UpArrow" {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this._EnsureVisible()
                    $handled = $true
                }
            }
            "DownArrow" {
                if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                    $this.SelectedIndex++
                    $this._EnsureVisible()
                    $handled = $true
                }
            }
            "PageUp" {
                $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $visibleHeight)
                $this._EnsureVisible()
                $handled = $true
            }
            "PageDown" {
                $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $visibleHeight)
                $this._EnsureVisible()
                $handled = $true
            }
            "Home" {
                $this.SelectedIndex = 0
                $this._EnsureVisible()
                $handled = $true
            }
            "End" {
                $this.SelectedIndex = [Math]::Max(0, $this.Items.Count - 1)
                $this._EnsureVisible()
                $handled = $true
            }
        }
        
        # Fire selection changed event if selection changed
        if ($handled -and $oldSelectedIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
            & $this.OnSelectionChanged $this $this.SelectedIndex
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    hidden [void] _EnsureVisible() {
        if ($this.Items.Count -eq 0) { return }
        
        $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
        
        # Scroll up if selected item is above visible area
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        }
        # Scroll down if selected item is below visible area
        elseif ($this.SelectedIndex -gt ($this.ScrollOffset + $visibleHeight - 1)) {
            $this.ScrollOffset = $this.SelectedIndex - $visibleHeight + 1
        }
        
        # Ensure scroll offset is within bounds
        $this.ScrollOffset = [Math]::Max(0, [Math]::Min($this.ScrollOffset, $this.Items.Count - $visibleHeight))
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SetItems([hashtable[]]$items) {
        $this.Items = $items
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this.RequestRedraw()
    }
    
    [void] SetColumns([hashtable[]]$columns) {
        $this.Columns = $columns
        $this.RequestRedraw()
    }
}
#<!-- END_PAGE: ACO.022 -->