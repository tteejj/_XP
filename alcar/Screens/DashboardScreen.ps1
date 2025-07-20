# Dashboard Screen

class DashboardScreen : Screen {
    [hashtable]$Stats
    
    DashboardScreen() {
        $this.Title = "DASHBOARD"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Calculate stats
        $this.Stats = @{
            TotalTasks = 35
            CompletedTasks = 18
            InProgressTasks = 12
            PendingTasks = 5
            OverdueTasks = 3
            TodayTasks = 4
            WeekTasks = 9
        }
        
        # Key bindings
        $this.InitializeKeyBindings()
        
        # Status bar
        $this.UpdateStatusBar()
    }
    
    [void] InitializeKeyBindings() {
        $this.BindKey([ConsoleKey]::Escape, { $this.Active = $false })
        $this.BindKey([ConsoleKey]::Backspace, { $this.Active = $false })
        $this.BindKey('q', { $this.Active = $false })
        $this.BindKey('r', { $this.Refresh() })
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        $this.AddStatusItem('r', 'refresh')
        $this.AddStatusItem('Esc', 'back')
    }
    
    # Fast string rendering - maximum performance like TaskScreen
    [string] RenderContent() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Clear screen efficiently
        $output += [VT]::Clear()
        
        # Draw the dashboard content
        $output += $this.DrawDashboard()
        
        return $output
    }
    
    [string] DrawDashboard() {
        $output = ""
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Title
        $title = " DASHBOARD "
        $titleX = [int](($width - $title.Length) / 2)
        $output += [VT]::MoveTo($titleX, 3)
        $output += [VT]::RGB(100, 200, 255) + $title + [VT]::Reset()
        
        # Stats grid
        $startY = 6
        $col1X = 10
        $col2X = 40
        
        $output += [VT]::MoveTo($col1X, $startY)
        $output += [VT]::TextBright() + "Total Tasks: " + [VT]::Accent() + $this.Stats.TotalTasks
        
        $output += [VT]::MoveTo($col2X, $startY)
        $output += [VT]::TextBright() + "Completed: " + [VT]::Accent() + $this.Stats.CompletedTasks
        
        $output += [VT]::MoveTo($col1X, $startY + 2)
        $output += [VT]::TextBright() + "In Progress: " + [VT]::Warning() + $this.Stats.InProgressTasks
        
        $output += [VT]::MoveTo($col2X, $startY + 2)
        $output += [VT]::TextBright() + "Pending: " + [VT]::Text() + $this.Stats.PendingTasks
        
        $output += [VT]::MoveTo($col1X, $startY + 4)
        $output += [VT]::TextBright() + "Overdue: " + [VT]::Error() + $this.Stats.OverdueTasks
        
        $output += [VT]::MoveTo($col2X, $startY + 4)
        $output += [VT]::TextBright() + "Today: " + [VT]::Accent() + $this.Stats.TodayTasks
        
        return $output + [VT]::Reset()
    }
    
    # Old buffer method
    [void] OldRenderToBuffer([Buffer]$buffer) {
        # Clear background
        $normalBG = "#1E1E23"
        $normalFG = "#C8C8C8"
        for ($y = 0; $y -lt $buffer.Height; $y++) {
            for ($x = 0; $x -lt $buffer.Width; $x++) {
                $buffer.SetCell($x, $y, ' ', $normalFG, $normalBG)
            }
        }
        
        # Draw border
        $this.DrawBorderToBuffer($buffer)
        
        # Title
        $titleText = "═══ DASHBOARD ═══"
        $titleX = [int](($buffer.Width - $titleText.Length) / 2)
        for ($i = 0; $i -lt $titleText.Length; $i++) {
            $buffer.SetCell($titleX + $i, 0, $titleText[$i], "#64C8FF", $normalBG)
        }
        
        # Layout widgets
        $widgetY = 3
        $widgetHeight = 8
        $widgetGap = 2
        
        # Task Summary Widget (left)
        $this.DrawTaskSummaryToBuffer($buffer, 2, $widgetY, 40, $widgetHeight)
        
        # Progress Widget (right)
        $this.DrawProgressWidgetToBuffer($buffer, 44, $widgetY, 40, $widgetHeight)
        
        # Timeline Widget (bottom left)
        $this.DrawTimelineWidgetToBuffer($buffer, 2, $widgetY + $widgetHeight + $widgetGap, 40, $widgetHeight)
        
        # Activity Widget (bottom right)
        $this.DrawActivityWidgetToBuffer($buffer, 44, $widgetY + $widgetHeight + $widgetGap, 40, $widgetHeight)
    }
    
    # Buffer-based border drawing
    [void] DrawBorderToBuffer([Buffer]$buffer) {
        $borderColor = "#646464"
        $width = $buffer.Width
        $height = $buffer.Height
        
        # Top border
        $buffer.SetCell(0, 0, '╔', $borderColor, "#1E1E23")
        for ($x = 1; $x -lt $width - 1; $x++) {
            $buffer.SetCell($x, 0, '═', $borderColor, "#1E1E23")
        }
        $buffer.SetCell($width - 1, 0, '╗', $borderColor, "#1E1E23")
        
        # Sides
        for ($y = 1; $y -lt $height - 1; $y++) {
            $buffer.SetCell(0, $y, '║', $borderColor, "#1E1E23")
            $buffer.SetCell($width - 1, $y, '║', $borderColor, "#1E1E23")
        }
        
        # Bottom border
        $buffer.SetCell(0, $height - 1, '╚', $borderColor, "#1E1E23")
        for ($x = 1; $x -lt $width - 1; $x++) {
            $buffer.SetCell($x, $height - 1, '═', $borderColor, "#1E1E23")
        }
        $buffer.SetCell($width - 1, $height - 1, '╝', $borderColor, "#1E1E23")
    }
    
    # Buffer-based widget drawing methods
    [void] DrawWidgetToBuffer([Buffer]$buffer, [int]$x, [int]$y, [int]$w, [int]$h, [string]$title) {
        $borderColor = "#646464"
        $normalBG = "#1E1E23"
        
        # Widget border
        $buffer.SetCell($x, $y, '┌', $borderColor, $normalBG)
        for ($i = 1; $i -lt $w - 1; $i++) {
            $buffer.SetCell($x + $i, $y, '─', $borderColor, $normalBG)
        }
        $buffer.SetCell($x + $w - 1, $y, '┐', $borderColor, $normalBG)
        
        for ($i = 1; $i -lt $h - 1; $i++) {
            $buffer.SetCell($x, $y + $i, '│', $borderColor, $normalBG)
            $buffer.SetCell($x + $w - 1, $y + $i, '│', $borderColor, $normalBG)
        }
        
        $buffer.SetCell($x, $y + $h - 1, '└', $borderColor, $normalBG)
        for ($i = 1; $i -lt $w - 1; $i++) {
            $buffer.SetCell($x + $i, $y + $h - 1, '─', $borderColor, $normalBG)
        }
        $buffer.SetCell($x + $w - 1, $y + $h - 1, '┘', $borderColor, $normalBG)
        
        # Title
        if ($title) {
            $titleX = $x + 2
            $titleText = " $title "
            for ($i = 0; $i -lt $titleText.Length; $i++) {
                $buffer.SetCell($titleX + $i, $y, $titleText[$i], "#FFFFFF", $normalBG)
            }
        }
    }
    
    [void] DrawTaskSummaryToBuffer([Buffer]$buffer, [int]$x, [int]$y, [int]$w, [int]$h) {
        $this.DrawWidgetToBuffer($buffer, $x, $y, $w, $h, "TASK SUMMARY")
        
        # Content
        $contentY = $y + 2
        $normalBG = "#1E1E23"
        
        $buffer.WriteString($x + 3, $contentY++, "Total Tasks: $($this.Stats.TotalTasks)", "#C8C8C8", $normalBG)
        $buffer.WriteString($x + 3, $contentY++, "● Completed: $($this.Stats.CompletedTasks)", "#64C8FF", $normalBG)
        $buffer.WriteString($x + 3, $contentY++, "◐ In Progress: $($this.Stats.InProgressTasks)", "#FFB000", $normalBG)
        $buffer.WriteString($x + 3, $contentY++, "○ Pending: $($this.Stats.PendingTasks)", "#646464", $normalBG)
        $buffer.WriteString($x + 3, $contentY++, "✗ Overdue: $($this.Stats.OverdueTasks)", "#FF4444", $normalBG)
    }
    
    [void] DrawProgressWidgetToBuffer([Buffer]$buffer, [int]$x, [int]$y, [int]$w, [int]$h) {
        $this.DrawWidgetToBuffer($buffer, $x, $y, $w, $h, "COMPLETION")
        
        # Calculate percentage
        $percent = [int](($this.Stats.CompletedTasks / $this.Stats.TotalTasks) * 100)
        $percentText = "$percent%"
        $textX = $x + [int](($w - $percentText.Length) / 2)
        
        $buffer.WriteString($textX, $y + 3, $percentText, "#64C8FF", "#1E1E23")
        
        # Progress bar
        $barWidth = $w - 6
        $filled = [int](($percent / 100) * $barWidth)
        $barY = $y + 5
        for ($i = 0; $i -lt $filled; $i++) {
            $buffer.SetCell($x + 3 + $i, $barY, '█', "#64C8FF", "#1E1E23")
        }
        for ($i = $filled; $i -lt $barWidth; $i++) {
            $buffer.SetCell($x + 3 + $i, $barY, '░', "#646464", "#1E1E23")
        }
    }
    
    [void] DrawTimelineWidgetToBuffer([Buffer]$buffer, [int]$x, [int]$y, [int]$w, [int]$h) {
        $this.DrawWidgetToBuffer($buffer, $x, $y, $w, $h, "TIMELINE")
        
        $contentY = $y + 2
        $normalBG = "#1E1E23"
        
        $buffer.WriteString($x + 3, $contentY++, "Today: $($this.Stats.TodayTasks) tasks", "#FFB000", $normalBG)
        $buffer.WriteString($x + 3, $contentY++, "This Week: $($this.Stats.WeekTasks) tasks", "#C8C8C8", $normalBG)
        $buffer.WriteString($x + 3, $contentY++, "Next Week: 12 tasks", "#646464", $normalBG)
        
        # Mini calendar
        $buffer.WriteString($x + 3, $contentY + 1, "M  T  W  T  F  S  S", "#646464", $normalBG)
        $buffer.WriteString($x + 3, $contentY + 2, "2  3  ", "#646464", $normalBG)
        $buffer.SetCell($x + 9, $contentY + 2, '4', "#FFB000", $normalBG)
        $buffer.WriteString($x + 11, $contentY + 2, "  5  6  7  8", "#646464", $normalBG)
    }
    
    [void] DrawActivityWidgetToBuffer([Buffer]$buffer, [int]$x, [int]$y, [int]$w, [int]$h) {
        $this.DrawWidgetToBuffer($buffer, $x, $y, $w, $h, "RECENT ACTIVITY")
        
        $activities = @(
            @{Time="2m ago"; Action="Completed"; Task="Fix login bug"},
            @{Time="15m ago"; Action="Started"; Task="Review PR #234"},
            @{Time="1h ago"; Action="Created"; Task="Update docs"},
            @{Time="3h ago"; Action="Updated"; Task="Deploy staging"}
        )
        
        $contentY = $y + 2
        $normalBG = "#1E1E23"
        foreach ($activity in $activities) {
            if ($contentY -ge $y + $h - 1) { break }
            
            $text = "$($activity.Time) $($activity.Action) $($activity.Task.Substring(0, [Math]::Min($activity.Task.Length, 15)))"
            $buffer.WriteString($x + 3, $contentY++, $text, "#C8C8C8", $normalBG)
        }
    }
    
    [string] DrawBorder() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Top border
        $output += [VT]::MoveTo(1, 1)
        $output += [VT]::Border()
        $output += [VT]::TL() + [VT]::H() * ($width - 2) + [VT]::TR()
        
        # Sides
        for ($y = 2; $y -lt $height - 1; $y++) {
            $output += [VT]::MoveTo(1, $y) + [VT]::V()
            $output += [VT]::MoveTo($width, $y) + [VT]::V()
        }
        
        # Bottom border
        $output += [VT]::MoveTo(1, $height - 1)
        $output += [VT]::BL() + [VT]::H() * ($width - 2) + [VT]::BR()
        
        return $output
    }
    
    [string] DrawWidget([int]$x, [int]$y, [int]$w, [int]$h, [string]$title) {
        $output = ""
        
        # Widget border
        $output += [VT]::MoveTo($x, $y)
        $output += [VT]::Border()
        $output += "┌" + ("─" * ($w - 2)) + "┐"
        
        for ($i = 1; $i -lt $h - 1; $i++) {
            $output += [VT]::MoveTo($x, $y + $i)
            $output += "│" + (" " * ($w - 2)) + "│"
        }
        
        $output += [VT]::MoveTo($x, $y + $h - 1)
        $output += "└" + ("─" * ($w - 2)) + "┘"
        
        # Title
        $titleX = $x + 2
        $output += [VT]::MoveTo($titleX, $y)
        $output += [VT]::TextBright() + " $title " + [VT]::Reset()
        
        return $output
    }
    
    [string] DrawTaskSummary([int]$x, [int]$y, [int]$w, [int]$h) {
        $output = $this.DrawWidget($x, $y, $w, $h, "TASK SUMMARY")
        
        # Content
        $contentY = $y + 2
        
        $output += [VT]::MoveTo($x + 3, $contentY++)
        $output += [VT]::Text() + "Total Tasks: " + [VT]::TextBright() + $this.Stats.TotalTasks
        
        $output += [VT]::MoveTo($x + 3, $contentY++)
        $output += [VT]::Accent() + "● Completed: " + $this.Stats.CompletedTasks
        
        $output += [VT]::MoveTo($x + 3, $contentY++)
        $output += [VT]::Warning() + "◐ In Progress: " + $this.Stats.InProgressTasks
        
        $output += [VT]::MoveTo($x + 3, $contentY++)
        $output += [VT]::TextDim() + "○ Pending: " + $this.Stats.PendingTasks
        
        $output += [VT]::MoveTo($x + 3, $contentY++)
        $output += [VT]::Error() + "✗ Overdue: " + $this.Stats.OverdueTasks
        
        return $output
    }
    
    [string] DrawProgressWidget([int]$x, [int]$y, [int]$w, [int]$h) {
        $output = $this.DrawWidget($x, $y, $w, $h, "COMPLETION")
        
        # Calculate percentage
        $percent = [int](($this.Stats.CompletedTasks / $this.Stats.TotalTasks) * 100)
        
        # Big percentage display
        $percentText = "$percent%"
        $textX = $x + [int](($w - $percentText.Length - 2) / 2)
        $output += [VT]::MoveTo($textX, $y + 3)
        $output += [VT]::Accent() + [VT]::TextBright()
        
        # Large text using block characters
        $output += "█▀▀▀█ █▀▀▀█ ▐▌  ▐▌"
        $output += [VT]::MoveTo($textX, $y + 4)
        $output += "█▄▄▄█ ▄▄▄▄█ ▐▌▄▄██"
        
        # Progress bar
        $barWidth = $w - 6
        $filled = [int](($percent / 100) * $barWidth)
        $output += [VT]::MoveTo($x + 3, $y + 6)
        $output += [VT]::Accent() + ("█" * $filled) + [VT]::TextDim() + ("░" * ($barWidth - $filled))
        
        return $output
    }
    
    [string] DrawTimelineWidget([int]$x, [int]$y, [int]$w, [int]$h) {
        $output = $this.DrawWidget($x, $y, $w, $h, "TIMELINE")
        
        $contentY = $y + 2
        
        $output += [VT]::MoveTo($x + 3, $contentY++)
        $output += [VT]::Warning() + "Today: " + [VT]::TextBright() + $this.Stats.TodayTasks + " tasks"
        
        $output += [VT]::MoveTo($x + 3, $contentY++)
        $output += [VT]::Text() + "This Week: " + [VT]::TextBright() + $this.Stats.WeekTasks + " tasks"
        
        $output += [VT]::MoveTo($x + 3, $contentY++)
        $output += [VT]::TextDim() + "Next Week: " + [VT]::Text() + "12 tasks"
        
        # Mini calendar view
        $output += [VT]::MoveTo($x + 3, $contentY + 1)
        $output += [VT]::TextDim() + "M  T  W  T  F  S  S"
        
        $output += [VT]::MoveTo($x + 3, $contentY + 2)
        $days = "2  3  " + [VT]::Warning() + "4" + [VT]::TextDim() + "  5  6  7  8"
        $output += $days
        
        return $output
    }
    
    [string] DrawActivityWidget([int]$x, [int]$y, [int]$w, [int]$h) {
        $output = $this.DrawWidget($x, $y, $w, $h, "RECENT ACTIVITY")
        
        $activities = @(
            @{Time="2m ago"; Action="Completed"; Task="Fix login bug"},
            @{Time="15m ago"; Action="Started"; Task="Review PR #234"},
            @{Time="1h ago"; Action="Created"; Task="Update docs"},
            @{Time="3h ago"; Action="Updated"; Task="Deploy staging"}
        )
        
        $contentY = $y + 2
        foreach ($activity in $activities) {
            if ($contentY -ge $y + $h - 1) { break }
            
            $output += [VT]::MoveTo($x + 3, $contentY++)
            $output += [VT]::TextDim() + $activity.Time + " " + 
                      [VT]::Text() + $activity.Action + " " +
                      [VT]::TextBright() + $activity.Task.Substring(0, [Math]::Min($activity.Task.Length, 15))
        }
        
        return $output
    }
    
    [void] Refresh() {
        # Simulate refresh
        $this.Stats.TotalTasks = Get-Random -Minimum 30 -Maximum 40
        $this.Stats.CompletedTasks = Get-Random -Minimum 15 -Maximum 25
        $this.Initialize()
    }
}