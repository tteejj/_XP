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
    
    [string] RenderContent() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Clear background by drawing spaces everywhere
        for ($y = 1; $y -le $height; $y++) {
            $output += [VT]::MoveTo(1, $y)
            $output += " " * $width
        }
        
        # Draw border
        $output += $this.DrawBorder()
        
        # Title
        $titleText = "═══ DASHBOARD ═══"
        $titleX = [int](($width - $titleText.Length) / 2)
        $output += [VT]::MoveTo($titleX, 1)
        $output += [VT]::BorderActive() + $titleText + [VT]::Reset()
        
        # Layout widgets
        $widgetY = 4
        $widgetHeight = 8
        $widgetGap = 2
        
        # Task Summary Widget (left)
        $output += $this.DrawTaskSummary(3, $widgetY, 40, $widgetHeight)
        
        # Progress Widget (right)
        $output += $this.DrawProgressWidget(45, $widgetY, 40, $widgetHeight)
        
        # Timeline Widget (bottom left)
        $output += $this.DrawTimelineWidget(3, $widgetY + $widgetHeight + $widgetGap, 40, $widgetHeight)
        
        # Activity Widget (bottom right)
        $output += $this.DrawActivityWidget(45, $widgetY + $widgetHeight + $widgetGap, 40, $widgetHeight)
        
        return $output
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