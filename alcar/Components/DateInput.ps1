# DateInput Component - Date selection with calendar popup

class DateInput : Component {
    [DateTime]$Value = [DateTime]::Today
    [DateTime]$MinDate = [DateTime]::MinValue
    [DateTime]$MaxDate = [DateTime]::MaxValue
    [string]$Format = "yyyy-MM-dd"
    [scriptblock]$OnChange = $null
    
    # Visual properties
    [bool]$ShowBorder = $true
    [bool]$ShowCalendarIcon = $true
    
    # Calendar state
    hidden [bool]$_showCalendar = $false
    hidden [DateTime]$_viewMonth
    hidden [int]$_selectedDay
    
    DateInput([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 25
        $this.Height = if ($this.ShowBorder) { 3 } else { 1 }
        $this._viewMonth = $this.Value
        $this._selectedDay = $this.Value.Day
    }
    
    [void] SetValue([DateTime]$date) {
        if ($date -ge $this.MinDate -and $date -le $this.MaxDate) {
            $oldValue = $this.Value
            $this.Value = $date
            $this._viewMonth = $date
            $this._selectedDay = $date.Day
            
            if ($this.OnChange -and $oldValue -ne $date) {
                & $this.OnChange $this $date
            }
            
            $this.Invalidate()
        }
    }
    
    [void] ToggleCalendar() {
        $this._showCalendar = -not $this._showCalendar
        
        # Adjust component height for calendar
        if ($this._showCalendar) {
            $this.Height = if ($this.ShowBorder) { 12 } else { 10 }
        } else {
            $this.Height = if ($this.ShowBorder) { 3 } else { 1 }
        }
        
        $this.Invalidate()
    }
    
    [void] OnRender([object]$buffer) {
        if (-not $this.Visible) { return }
        
        # Colors
        $bgColor = if ($this.BackgroundColor) { $this.BackgroundColor } else { [VT]::RGBBG(30, 30, 35) }
        $fgColor = if ($this.ForegroundColor) { $this.ForegroundColor } else { [VT]::RGB(220, 220, 220) }
        $borderColor = if ($this.BorderColor) { $this.BorderColor } else {
            if ($this.IsFocused) { [VT]::RGB(100, 200, 255) } else { [VT]::RGB(80, 80, 100) }
        }
        
        # Clear background
        for ($y = 0; $y -lt $this.Height; $y++) {
            $this.DrawText($buffer, 0, $y, $bgColor + (" " * $this.Width) + [VT]::Reset())
        }
        
        # Draw main input box
        if ($this.ShowBorder) {
            $this.DrawBorder($buffer, $borderColor, 0, 0, $this.Width, 3)
        }
        
        # Draw date value
        $dateStr = $this.Value.ToString($this.Format)
        $contentY = if ($this.ShowBorder) { 1 } else { 0 }
        $contentX = if ($this.ShowBorder) { 1 } else { 0 }
        $this.DrawText($buffer, $contentX, $contentY, $fgColor + $dateStr + [VT]::Reset())
        
        # Draw calendar icon
        if ($this.ShowCalendarIcon) {
            $iconX = $this.Width - (if ($this.ShowBorder) { 2 } else { 1 })
            $iconColor = if ($this._showCalendar) { [VT]::RGB(255, 200, 100) } else { [VT]::RGB(100, 100, 150) }
            $this.DrawText($buffer, $iconX, $contentY, $iconColor + "📅" + [VT]::Reset())
        }
        
        # Draw calendar if open
        if ($this._showCalendar) {
            $calendarY = if ($this.ShowBorder) { 3 } else { 1 }
            $this.DrawCalendar($buffer, 0, $calendarY)
        }
    }
    
    [void] DrawCalendar([object]$buffer, [int]$startX, [int]$startY) {
        $calendarWidth = $this.Width
        $calendarHeight = 9
        
        # Calendar colors
        $calBgColor = [VT]::RGBBG(25, 25, 30)
        $calBorderColor = [VT]::RGB(80, 80, 100)
        $headerColor = [VT]::RGB(255, 200, 100)
        $dayHeaderColor = [VT]::RGB(150, 150, 150)
        $normalDayColor = [VT]::RGB(200, 200, 200)
        $selectedDayColor = [VT]::RGB(255, 255, 255)
        $selectedBgColor = [VT]::RGBBG(60, 60, 100)
        $todayColor = [VT]::RGB(100, 255, 100)
        $otherMonthColor = [VT]::RGB(80, 80, 80)
        
        # Draw calendar background
        for ($y = 0; $y -lt $calendarHeight; $y++) {
            $this.DrawText($buffer, $startX, $startY + $y, $calBgColor + (" " * $calendarWidth) + [VT]::Reset())
        }
        
        # Draw calendar border
        $this.DrawBorder($buffer, $calBorderColor, $startX, $startY, $calendarWidth, $calendarHeight)
        
        # Month/Year header
        $monthYearStr = $this._viewMonth.ToString("MMMM yyyy")
        $headerX = $startX + [int](($calendarWidth - $monthYearStr.Length) / 2)
        $this.DrawText($buffer, $headerX, $startY + 1, $headerColor + $monthYearStr + [VT]::Reset())
        
        # Navigation arrows
        $this.DrawText($buffer, $startX + 1, $startY + 1, $headerColor + "◄" + [VT]::Reset())
        $this.DrawText($buffer, $startX + $calendarWidth - 2, $startY + 1, $headerColor + "►" + [VT]::Reset())
        
        # Day headers
        $dayHeaders = @("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
        $dayX = $startX + 2
        foreach ($day in $dayHeaders) {
            $this.DrawText($buffer, $dayX, $startY + 2, $dayHeaderColor + $day + [VT]::Reset())
            $dayX += 3
        }
        
        # Calendar days
        $firstDay = [DateTime]::new($this._viewMonth.Year, $this._viewMonth.Month, 1)
        $startDayOfWeek = [int]$firstDay.DayOfWeek
        $daysInMonth = [DateTime]::DaysInMonth($this._viewMonth.Year, $this._viewMonth.Month)
        $today = [DateTime]::Today
        
        # Previous month days
        $prevMonth = $this._viewMonth.AddMonths(-1)
        $daysInPrevMonth = [DateTime]::DaysInMonth($prevMonth.Year, $prevMonth.Month)
        $prevMonthDay = $daysInPrevMonth - $startDayOfWeek + 1
        
        $currentDay = 1
        $nextMonthDay = 1
        
        for ($week = 0; $week -lt 6; $week++) {
            for ($dayOfWeek = 0; $dayOfWeek -lt 7; $dayOfWeek++) {
                $dayX = $startX + 2 + ($dayOfWeek * 3)
                $dayY = $startY + 3 + $week
                
                $dayStr = ""
                $dayColor = $normalDayColor
                $dayBgColor = $calBgColor
                
                if ($week -eq 0 -and $dayOfWeek -lt $startDayOfWeek) {
                    # Previous month
                    $dayStr = $prevMonthDay.ToString().PadLeft(2)
                    $dayColor = $otherMonthColor
                    $prevMonthDay++
                } elseif ($currentDay -le $daysInMonth) {
                    # Current month
                    $dayStr = $currentDay.ToString().PadLeft(2)
                    $currentDate = [DateTime]::new($this._viewMonth.Year, $this._viewMonth.Month, $currentDay)
                    
                    # Highlight selected day
                    if ($currentDate -eq $this.Value) {
                        $dayColor = $selectedDayColor
                        $dayBgColor = $selectedBgColor
                    }
                    # Highlight today
                    elseif ($currentDate -eq $today) {
                        $dayColor = $todayColor
                    }
                    
                    $currentDay++
                } else {
                    # Next month
                    $dayStr = $nextMonthDay.ToString().PadLeft(2)
                    $dayColor = $otherMonthColor
                    $nextMonthDay++
                }
                
                if ($dayStr) {
                    $this.DrawText($buffer, $dayX, $dayY, $dayBgColor + $dayColor + $dayStr + [VT]::Reset())
                }
            }
        }
    }
    
    [void] DrawBorder([object]$buffer, [string]$color, [int]$x, [int]$y, [int]$w, [int]$h) {
        # Top
        $this.DrawText($buffer, $x, $y, $color + "┌" + ("─" * ($w - 2)) + "┐" + [VT]::Reset())
        
        # Sides
        for ($i = 1; $i -lt $h - 1; $i++) {
            $this.DrawText($buffer, $x, $y + $i, $color + "│" + [VT]::Reset())
            $this.DrawText($buffer, $x + $w - 1, $y + $i, $color + "│" + [VT]::Reset())
        }
        
        # Bottom
        $this.DrawText($buffer, $x, $y + $h - 1, $color + "└" + ("─" * ($w - 2)) + "┘" + [VT]::Reset())
    }
    
    [void] DrawText([object]$buffer, [int]$x, [int]$y, [string]$text) {
        # Placeholder for alcar buffer integration
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.Enabled -or -not $this.IsFocused) { return $false }
        
        if (-not $this._showCalendar) {
            # Closed state
            switch ($key.Key) {
                ([ConsoleKey]::Enter) {
                    $this.ToggleCalendar()
                    return $true
                }
                ([ConsoleKey]::Spacebar) {
                    $this.ToggleCalendar()
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    $this.ToggleCalendar()
                    return $true
                }
            }
        } else {
            # Calendar open
            $oldValue = $this.Value
            
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this._showCalendar = $false
                    $this.Height = if ($this.ShowBorder) { 3 } else { 1 }
                    $this.Invalidate()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    # Confirm selection
                    $this._showCalendar = $false
                    $this.Height = if ($this.ShowBorder) { 3 } else { 1 }
                    $this.Invalidate()
                    return $true
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                        # Previous month
                        $this._viewMonth = $this._viewMonth.AddMonths(-1)
                        if ($this._viewMonth.Month -eq $this.Value.Month -and 
                            $this._viewMonth.Year -eq $this.Value.Year) {
                            $this._selectedDay = $this.Value.Day
                        } else {
                            $this._selectedDay = 1
                        }
                    } else {
                        # Previous day
                        $newDate = $this.Value.AddDays(-1)
                        if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                            $this.Value = $newDate
                            $this._viewMonth = $newDate
                            $this._selectedDay = $newDate.Day
                        }
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                        # Next month
                        $this._viewMonth = $this._viewMonth.AddMonths(1)
                        if ($this._viewMonth.Month -eq $this.Value.Month -and 
                            $this._viewMonth.Year -eq $this.Value.Year) {
                            $this._selectedDay = $this.Value.Day
                        } else {
                            $this._selectedDay = 1
                        }
                    } else {
                        # Next day
                        $newDate = $this.Value.AddDays(1)
                        if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                            $this.Value = $newDate
                            $this._viewMonth = $newDate
                            $this._selectedDay = $newDate.Day
                        }
                    }
                }
                ([ConsoleKey]::UpArrow) {
                    # Previous week
                    $newDate = $this.Value.AddDays(-7)
                    if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                        $this.Value = $newDate
                        $this._viewMonth = $newDate
                        $this._selectedDay = $newDate.Day
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    # Next week
                    $newDate = $this.Value.AddDays(7)
                    if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                        $this.Value = $newDate
                        $this._viewMonth = $newDate
                        $this._selectedDay = $newDate.Day
                    }
                }
                ([ConsoleKey]::Home) {
                    # First day of month
                    $newDate = [DateTime]::new($this._viewMonth.Year, $this._viewMonth.Month, 1)
                    if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                        $this.Value = $newDate
                        $this._selectedDay = 1
                    }
                }
                ([ConsoleKey]::End) {
                    # Last day of month
                    $lastDay = [DateTime]::DaysInMonth($this._viewMonth.Year, $this._viewMonth.Month)
                    $newDate = [DateTime]::new($this._viewMonth.Year, $this._viewMonth.Month, $lastDay)
                    if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                        $this.Value = $newDate
                        $this._selectedDay = $lastDay
                    }
                }
                ([ConsoleKey]::T) {
                    # Today
                    $today = [DateTime]::Today
                    if ($today -ge $this.MinDate -and $today -le $this.MaxDate) {
                        $this.Value = $today
                        $this._viewMonth = $today
                        $this._selectedDay = $today.Day
                    }
                }
            }
            
            if ($oldValue -ne $this.Value -and $this.OnChange) {
                & $this.OnChange $this $this.Value
            }
            
            $this.Invalidate()
            return $true
        }
        
        return $false
    }
    
    [void] OnFocus() {
        $this.Invalidate()
    }
    
    [void] OnBlur() {
        if ($this._showCalendar) {
            $this.ToggleCalendar()
        }
        $this.Invalidate()
    }
    
    # Static factory methods
    static [DateInput] CreateBirthDate([string]$name) {
        $input = [DateInput]::new($name)
        $input.MinDate = [DateTime]::new(1900, 1, 1)
        $input.MaxDate = [DateTime]::Today
        return $input
    }
    
    static [DateInput] CreateFutureDate([string]$name) {
        $input = [DateInput]::new($name)
        $input.MinDate = [DateTime]::Today
        $input.MaxDate = [DateTime]::Today.AddYears(10)
        return $input
    }
}