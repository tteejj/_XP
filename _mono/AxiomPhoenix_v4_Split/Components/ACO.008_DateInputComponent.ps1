# ==============================================================================
# Axiom-Phoenix v4.0 - All Components
# UI components that extend UIElement - full implementations from axiom
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ACO.###" to find specific sections.
# Each section ends with "END_PAGE: ACO.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#

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
    
    DateInputComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.TabIndex = 0
        $this.Width = 25
        $this.Height = 1  # Expands to 10 when calendar shown
        $this._viewMonth = $this.Value
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = $this.GetEffectiveBackgroundColor()
            $fgColor = $this.GetEffectiveForegroundColor()
            if ($this.IsFocused) { 
                $borderColorValue = Get-ThemeColor "Primary" "#00FFFF" 
            } else { 
                $borderColorValue = $this.GetEffectiveBorderColor()
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