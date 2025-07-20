# Enhanced Task Screen - PTUI Patterns: Search + Multi-select
# Demonstrates type-ahead search and bulk operations

class EnhancedTaskScreen : Screen {
    [MultiSelectListBox]$TaskList
    [object]$TaskService
    [System.Collections.ArrayList]$AllTasks
    [bool]$BulkMode = $false
    
    EnhancedTaskScreen() {
        $this.Title = "ENHANCED TASKS"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Get task service
        $this.TaskService = $global:ServiceContainer.GetService("TaskService")
        $this.AllTasks = [System.Collections.ArrayList]::new()
        
        # Create searchable multi-select task list
        $this.TaskList = [MultiSelectListBox]::new("TaskList")
        $this.TaskList.X = 2
        $this.TaskList.Y = 3
        $this.TaskList.Width = [Console]::WindowWidth - 4
        $this.TaskList.Height = [Console]::WindowHeight - 8
        $this.TaskList.SearchPrompt = "Search tasks: "
        
        # Custom formatter for tasks
        $this.TaskList.ItemFormatter = {
            param($task)
            $status = if ($task.Status -eq "Done") { "✓" } else { "○" }
            $priority = switch ($task.Priority) {
                "High" { "!" }
                "Medium" { "·" }
                default { " " }
            }
            return "$status $priority $($task.Title)"
        }.GetNewClosure()
        
        # Load tasks
        $this.LoadTasks()
        
        # Key bindings
        $this.BindKey([ConsoleKey]::Enter, { $this.ViewTask() })
        $this.BindKey([ConsoleKey]::N, { $this.NewTask() })
        $this.BindKey([ConsoleKey]::E, { $this.EditTask() })
        $this.BindKey([ConsoleKey]::D, { $this.DeleteTask() })
        $this.BindKey([ConsoleKey]::M, { $this.ToggleBulkMode() })
        $this.BindKey([ConsoleKey]::C, { $this.BulkComplete() })
        $this.BindKey([ConsoleKey]::X, { $this.BulkDelete() })
        $this.BindKey([ConsoleKey]::F5, { $this.RefreshTasks() })
        $this.BindKey([ConsoleKey]::Escape, { $this.Active = $false })
        
        # Navigation
        $this.BindKey([ConsoleKey]::UpArrow, { $this.TaskList.NavigateUp() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.TaskList.NavigateDown() })
        $this.BindKey([ConsoleKey]::PageUp, { $this.TaskList.PageUp() })
        $this.BindKey([ConsoleKey]::PageDown, { $this.TaskList.PageDown() })
        
        $this.UpdateStatusBar()
    }
    
    [void] LoadTasks() {
        try {
            $tasks = $this.TaskService.GetAllTasks()
            $this.AllTasks.Clear()
            $this.AllTasks.AddRange($tasks)
            $this.TaskList.SetItems($tasks)
        }
        catch {
            Write-Error "Failed to load tasks: $_"
        }
    }
    
    [void] RefreshTasks() {
        $this.LoadTasks()
        $this.RequestRender()
    }
    
    [void] ToggleBulkMode() {
        $this.BulkMode = -not $this.BulkMode
        $this.TaskList.AllowMultiSelect = $this.BulkMode
        if (-not $this.BulkMode) {
            $this.TaskList.ClearSelection()
        }
        $this.UpdateStatusBar()
        $this.RequestRender()
    }
    
    [void] BulkComplete() {
        if (-not $this.BulkMode) { return }
        
        $selectedTasks = $this.TaskList.GetSelectedItems()
        if ($selectedTasks.Count -eq 0) { return }
        
        foreach ($task in $selectedTasks) {
            $task.Status = "Done"
            $task.CompletedAt = [DateTime]::Now
            $this.TaskService.UpdateTask($task)
        }
        
        $this.TaskList.ClearSelection()
        $this.RefreshTasks()
    }
    
    [void] BulkDelete() {
        if (-not $this.BulkMode) { return }
        
        $selectedTasks = $this.TaskList.GetSelectedItems()
        if ($selectedTasks.Count -eq 0) { return }
        
        # Simple confirmation
        Write-Host "`nDelete $($selectedTasks.Count) selected tasks? (y/N): " -NoNewline
        $confirm = [Console]::ReadKey($true)
        if ($confirm.KeyChar -eq 'y' -or $confirm.KeyChar -eq 'Y') {
            foreach ($task in $selectedTasks) {
                $this.TaskService.DeleteTask($task.Id)
            }
            $this.TaskList.ClearSelection()
            $this.RefreshTasks()
        }
    }
    
    [void] ViewTask() {
        $task = $this.TaskList.GetSelectedItem()
        if (-not $task) { return }
        
        # Create simple task view dialog
        $dialog = New-Object TaskViewDialog -ArgumentList $task
        $global:ScreenManager.PushModal($dialog)
    }
    
    [void] NewTask() {
        # Create new task dialog (placeholder)
        Write-Host "`nNew task creation not implemented yet" -ForegroundColor Yellow
        Start-Sleep 1
    }
    
    [void] EditTask() {
        $task = $this.TaskList.GetSelectedItem()
        if (-not $task) { return }
        
        # Edit task dialog (placeholder)
        Write-Host "`nEdit task not implemented yet" -ForegroundColor Yellow
        Start-Sleep 1
    }
    
    [void] DeleteTask() {
        $task = $this.TaskList.GetSelectedItem()
        if (-not $task) { return }
        
        # Simple confirmation
        Write-Host "`nDelete task '$($task.Title)'? (y/N): " -NoNewline
        $confirm = [Console]::ReadKey($true)
        if ($confirm.KeyChar -eq 'y' -or $confirm.KeyChar -eq 'Y') {
            $this.TaskService.DeleteTask($task.Id)
            $this.RefreshTasks()
        }
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        
        if ($this.BulkMode) {
            $selectedCount = $this.TaskList.SelectedIndices.Count
            $this.AddStatusItem('Space', 'select')
            $this.AddStatusItem('C', 'complete selected')
            $this.AddStatusItem('X', 'delete selected') 
            $this.AddStatusItem('M', 'exit bulk')
            $this.AddStatusItem('Ctrl+A', 'select all')
            if ($selectedCount -gt 0) {
                $this.AddStatusItem("$selectedCount selected", '')
            }
        } else {
            $this.AddStatusItem('↑↓', 'navigate')
            $this.AddStatusItem('Enter', 'view')
            $this.AddStatusItem('N', 'new')
            $this.AddStatusItem('E', 'edit')
            $this.AddStatusItem('D', 'delete')
            $this.AddStatusItem('M', 'bulk mode')
            $this.AddStatusItem('F5', 'refresh')
        }
        
        $this.AddStatusItem('Type', 'search')
        $this.AddStatusItem('ESC', 'back')
    }
    
    [string] RenderContent() {
        $output = ""
        $output += [VT]::Clear()
        
        # Header
        $title = if ($this.BulkMode) { "ENHANCED TASKS - BULK MODE" } else { "ENHANCED TASKS" }
        $output += [VT]::MoveTo(2, 1)
        $output += [VT]::TextBright() + $title + [VT]::Reset()
        
        # Instructions
        $output += [VT]::MoveTo(2, 2)
        if ($this.BulkMode) {
            $output += [VT]::Warning() + "Bulk mode: Use SPACE to select, C to complete, X to delete selected tasks" + [VT]::Reset()
        } else {
            $output += [VT]::TextDim() + "Type to search • M for bulk mode • Enter to view task details" + [VT]::Reset()
        }
        
        # Render task list
        $output += $this.TaskList.Render()
        
        return $output
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        # Let task list handle search input first
        if ($this.TaskList.HandleKey($key)) {
            $this.RequestRender()
            return $true
        }
        
        # Then let base class handle other keys
        return ([Screen]$this).HandleInput($key)
    }
}

# Simple task view dialog
class TaskViewDialog : Screen {
    [object]$Task
    
    TaskViewDialog([object]$task) {
        $this.Task = $task
        $this.Title = "Task Details"
        $this.BindKey([ConsoleKey]::Escape, { $this.Active = $false })
        $this.BindKey([ConsoleKey]::Q, { $this.Active = $false })
    }
    
    [string] RenderContent() {
        $output = ""
        $output += [VT]::Clear()
        
        $width = 60
        $height = 15
        $x = ([Console]::WindowWidth - $width) / 2
        $y = ([Console]::WindowHeight - $height) / 2
        
        # Draw dialog box
        $output += [VT]::MoveTo($x, $y)
        $output += [VT]::Border() + [VT]::DTL() + ([VT]::DH() * ($width - 2)) + [VT]::DTR() + [VT]::Reset()
        
        for ($i = 1; $i -lt $height - 1; $i++) {
            $output += [VT]::MoveTo($x, $y + $i)
            $output += [VT]::Border() + [VT]::DV() + (" " * ($width - 2)) + [VT]::DV() + [VT]::Reset()
        }
        
        $output += [VT]::MoveTo($x, $y + $height - 1)
        $output += [VT]::Border() + [VT]::DBL() + ([VT]::DH() * ($width - 2)) + [VT]::DBR() + [VT]::Reset()
        
        # Content
        $output += [VT]::MoveTo($x + 2, $y + 1)
        $output += [VT]::TextBright() + "Task Details" + [VT]::Reset()
        
        $output += [VT]::MoveTo($x + 2, $y + 3)
        $output += [VT]::TextDim() + "Title: " + [VT]::Reset() + $this.Task.Title
        
        $output += [VT]::MoveTo($x + 2, $y + 4)
        $statusColor = if ($this.Task.Status -eq "Done") { [VT]::Accent() } else { [VT]::Warning() }
        $output += [VT]::TextDim() + "Status: " + $statusColor + $this.Task.Status + [VT]::Reset()
        
        $output += [VT]::MoveTo($x + 2, $y + 5)
        $output += [VT]::TextDim() + "Priority: " + [VT]::Reset() + $this.Task.Priority
        
        $output += [VT]::MoveTo($x + 2, $y + 6)
        $output += [VT]::TextDim() + "Project: " + [VT]::Reset() + $this.Task.Project
        
        if ($this.Task.Description) {
            $output += [VT]::MoveTo($x + 2, $y + 8)
            $output += [VT]::TextDim() + "Description:" + [VT]::Reset()
            $output += [VT]::MoveTo($x + 2, $y + 9)
            $output += [VT]::Text() + $this.Task.Description + [VT]::Reset()
        }
        
        $output += [VT]::MoveTo($x + 2, $y + $height - 3)
        $output += [VT]::TextDim() + "Press ESC or Q to close" + [VT]::Reset()
        
        return $output
    }
}