# ==============================================================================
# PMC Terminal v5 - NCurses Task List Screen
# Displays and manages tasks with buffer-based rendering
# ==============================================================================

# AI: PHASE 3 REFACTORED - NCurses buffer-based architecture









class TaskListScreen : Screen {
    # --- Core Architecture ---
    [Panel] $MainPanel
    [Panel] $HeaderPanel
    [Panel] $TablePanel
    [Panel] $FooterPanel
    [Table] $TaskTable
    [System.Collections.Generic.List[UIElement]] $Components

    # --- State Management ---
    [string] $FilterStatus = "All"
    [object[]] $AllTasks = @()
    [System.Collections.ArrayList] $FilteredTasks = [System.Collections.ArrayList]::new()
    [int] $SelectedIndex = 0

    # --- Constructor ---
    TaskListScreen([hashtable]$services) : base("TaskListScreen", $services) {
        $this.Name = "TaskListScreen"
        $this.Components = [System.Collections.Generic.List[UIElement]]::new()
        $this.IsFocusable = $true
        $this.Enabled = $true
        $this.Visible = $true
    }

    # --- Initialization ---
    [void] Initialize() {
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "Initialize" -ScriptBlock {
            # AI: PHASE 3 - Set screen dimensions from console
            $this.Width = $global:TuiState.BufferWidth
            $this.Height = $global:TuiState.BufferHeight
            
            # Resize the private buffer to match
            if ($null -ne $this._private_buffer) {
                $this._private_buffer.Resize($this.Width, $this.Height)
            }
            
            # AI: PHASE 3 - Create main panel structure
            $this.MainPanel = [Panel]::new(0, 0, $this.Width, $this.Height, "Task List")
            $this.MainPanel.HasBorder = $true
            $this.MainPanel.BorderStyle = "Double"
            $this.MainPanel.BorderColor = [ConsoleColor]::Gray
            $this.MainPanel.BackgroundColor = [ConsoleColor]::Black
            $this.MainPanel.Name = "MainTaskPanel"
            $this.AddChild($this.MainPanel)
            
            # AI: PHASE 3 - Header panel for title and filter info
            $this.HeaderPanel = [Panel]::new(1, 1, $this.Width - 2, 3, "")
            $this.HeaderPanel.HasBorder = $false
            $this.HeaderPanel.BackgroundColor = [ConsoleColor]::Black
            $this.HeaderPanel.Name = "HeaderPanel"
            $this.MainPanel.AddChild($this.HeaderPanel)
            
            # AI: PHASE 3 - Table panel for task data
            $this.TablePanel = [Panel]::new(1, 4, $this.Width - 2, $this.Height - 8, "")
            $this.TablePanel.HasBorder = $true
            $this.TablePanel.BorderStyle = "Single"
            $this.TablePanel.BorderColor = [ConsoleColor]::DarkGray
            $this.TablePanel.BackgroundColor = [ConsoleColor]::Black
            $this.TablePanel.Name = "TablePanel"
            $this.MainPanel.AddChild($this.TablePanel)
            
            # AI: PHASE 3 - Footer panel for navigation help
            $this.FooterPanel = [Panel]::new(1, $this.Height - 4, $this.Width - 2, 3, "")
            $this.FooterPanel.HasBorder = $false
            $this.FooterPanel.BackgroundColor = [ConsoleColor]::Black
            $this.FooterPanel.Name = "FooterPanel"
            $this.MainPanel.AddChild($this.FooterPanel)
            
            # AI: PHASE 3 - Create task table component
            $this.TaskTable = [Table]::new("TaskTable")
            $this.TaskTable.Move(1, 1)  # Inside table panel
            $this.TaskTable.Resize($this.TablePanel.ContentWidth, $this.TablePanel.ContentHeight)

            # AI: FIX - Use proper TableColumn class instances
            $columns = @(
                [TableColumn]::new('Title', 'Task Title', 50),
                [TableColumn]::new('Status', 'Status', 15),
                [TableColumn]::new('Priority', 'Priority', 12),
                [TableColumn]::new('DueDate', 'Due Date', 15)
            )
            $this.TaskTable.SetColumns($columns)
            
            $this.TablePanel.AddChild($this.TaskTable)
            
            # AI: PHASE 3 - Load initial data
            $this.RefreshData()
            $this.UpdateDisplay()
            
            # Force initial render
            $this.RequestRedraw()
            $this.Render()
            
            Write-Log -Level Info -Message "TaskListScreen initialized with NCurses architecture"
        }
    }

    # --- Data Management ---
    hidden [void] RefreshData() {
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "RefreshData" -ScriptBlock {
            # AI: PHASE 3 - Safe data loading with error handling
            try {
                $this.AllTasks = @($this.Services.DataManager.GetTasks())
                if ($null -eq $this.AllTasks) { $this.AllTasks = @() }
                Write-Log -Level Debug -Message "Loaded $($this.AllTasks.Count) tasks from DataManager"
            } catch {
                Write-Log -Level Warning -Message "Failed to load tasks: $_"
                $this.AllTasks = @()
            }
            
            # AI: PHASE 3 - Apply current filter
            $filterResult = switch ($this.FilterStatus) {
                "Active" { $this.AllTasks | Where-Object { $_.Status -ne [TaskStatus]::Completed } }
                "Completed" { $this.AllTasks | Where-Object { $_.Status -eq [TaskStatus]::Completed } }
                default { $this.AllTasks }
            }
            # Ensure FilteredTasks is always a proper array with Count property
            if ($null -eq $filterResult) {
                $this.FilteredTasks = [System.Collections.ArrayList]::new()
            } else {
                $this.FilteredTasks = [System.Collections.ArrayList]::new()
                if ($filterResult -is [array]) {
                    foreach ($item in $filterResult) {
                        $this.FilteredTasks.Add($item) | Out-Null
                    }
                } else {
                    $this.FilteredTasks.Add($filterResult) | Out-Null
                }
            }
            
            Write-Log -Level Debug -Message "Filtered to $($this.FilteredTasks.Count) tasks with filter: $($this.FilterStatus)"
            
            # AI: PHASE 3 - Update table data
            $this.TaskTable.SetData($this.FilteredTasks)
            
            # AI: PHASE 3 - Adjust selection if needed
            if ($null -ne $this.FilteredTasks -and $this.SelectedIndex -ge $this.FilteredTasks.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.FilteredTasks.Count - 1)
            }
            
            $this.RequestRedraw()
        }
    }

    hidden [void] UpdateDisplay() {
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "UpdateDisplay" -ScriptBlock {
            # AI: PHASE 3 - Update header text
            $taskCount = if ($null -ne $this.FilteredTasks) { $this.FilteredTasks.Count } else { 0 }
            $headerText = "Filter: $($this.FilterStatus) | Total: $taskCount tasks"
            $this.WriteTextToPanel($this.HeaderPanel, $headerText, 0, 0, [ConsoleColor]::White)
            $this.HeaderPanel.RequestRedraw()
            
            # AI: PHASE 3 - Update footer navigation text
            $footerText = "[↑↓]Navigate [Space]Toggle [N]ew [E]dit [D]elete [F]ilter [Esc]Back"
            $this.WriteTextToPanel($this.FooterPanel, $footerText, 0, 0, [ConsoleColor]::Yellow)
            $this.FooterPanel.RequestRedraw()
            
            # AI: PHASE 3 - Update table selection
            $this.TaskTable.SelectedIndex = $this.SelectedIndex
            
            $this.RequestRedraw()
        }
    }

    # --- Helper Methods ---
    hidden [void] WriteTextToPanel([Panel]$panel, [string]$text, [int]$x, [int]$y, [ConsoleColor]$color) {
        if ($null -eq $panel -or $null -eq $panel._private_buffer) { return }
        
        $chars = $text.ToCharArray()
        for ($i = 0; $i -lt $chars.Length -and ($x + $i) -lt $panel.ContentWidth; $i++) {
            $cell = [TuiCell]::new($chars[$i], $color, $panel.BackgroundColor)
            $panel._private_buffer.SetCell($panel.ContentX + $x + $i, $panel.ContentY + $y, $cell)
        }
    }

    # --- Input Handling ---
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "HandleInput" -ScriptBlock {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                        $this.UpdateDisplay()
                        return $true
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.SelectedIndex -lt ($this.FilteredTasks.Count - 1) -and $this.FilteredTasks.Count -gt 0) {
                        $this.SelectedIndex++
                        $this.UpdateDisplay()
                        return $true
                    }
                }
                ([ConsoleKey]::Spacebar) {
                    $this.ToggleSelectedTask()
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    $this.NavigateBack()
                    return $true
                }
                default {
                    $keyChar = $keyInfo.KeyChar.ToString().ToUpper()
                    switch ($keyChar) {
                        'N' { $this.ShowNewTaskDialog(); return $true }
                        'E' { $this.EditSelectedTask(); return $true }
                        'D' { $this.DeleteSelectedTask(); return $true }
                        'F' { $this.CycleFilter(); return $true }
                    }
                }
            }
        }
        return $false
    }

    # --- Task Actions ---
    hidden [void] ToggleSelectedTask() {
        if ($this.FilteredTasks.Count -eq 0 -or $this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $this.FilteredTasks.Count) {
            return
        }
        
        $task = $this.FilteredTasks[$this.SelectedIndex]
        if ($null -eq $task) { return }
        
        try {
            $newCompletedStatus = $task.Status -ne [TaskStatus]::Completed
            
            $this.Services.DataManager.UpdateTask(@{
                Task = $task
                Completed = $newCompletedStatus
            })
            
            $this.RefreshData()
            $this.UpdateDisplay()
        } catch {
            Write-Log -Level Error -Message "Failed to toggle task: $_"
        }
    }

    hidden [void] ShowNewTaskDialog() {
        Write-Log -Level Info -Message "New task dialog requested"
        
        $dataManager = $this.Services.DataManager
        $refreshCallback = { $this.RefreshData(); $this.UpdateDisplay() }.GetNewClosure()
        
        try {
            Show-InputDialog -Title "New Task" -Prompt "Enter task title:" -OnSubmit {
                param($Value)
                if (-not [string]::IsNullOrWhiteSpace($Value)) {
                    # AI: FIX - This now uses correct method call syntax with positional arguments.
                    $newTask = $dataManager.AddTask($Value, "", "medium", "General")
                    Write-Log -Level Info -Message "Created new task: $($newTask.Title)"
                    & $refreshCallback
                }
            }
        } catch {
            Write-Log -Level Error -Message "Failed to show new task dialog: $_"
        }
    }

    hidden [void] EditSelectedTask() {
        if ($null -eq $this.FilteredTasks -or $this.FilteredTasks.Count -eq 0 -or $this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $this.FilteredTasks.Count) {
            return
        }
        
        $task = $this.FilteredTasks[$this.SelectedIndex]
        if ($null -eq $task) { return }
        
        Write-Log -Level Info -Message "Edit task requested for: $($task.Title)"
        
        $refreshCallback = { $this.RefreshData(); $this.UpdateDisplay() }.GetNewClosure()
        try {
            Show-InputDialog -Title "Edit Task" -Prompt "New title:" -DefaultValue $task.Title -OnSubmit {
                param($Value)
                if (-not [string]::IsNullOrWhiteSpace($Value)) {
                    $this.Services.DataManager.UpdateTask(@{
                        Task = $task
                        Title = $Value
                    })
                    & $refreshCallback
                }
            }
        } catch {
             Write-Log -Level Error -Message "Failed to show edit task dialog: $_"
        }
    }

    hidden [void] DeleteSelectedTask() {
        if ($null -eq $this.FilteredTasks -or $this.FilteredTasks.Count -eq 0 -or $this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $this.FilteredTasks.Count) {
            return
        }
        
        $task = $this.FilteredTasks[$this.SelectedIndex]
        if ($null -eq $task) { return }
        
        Write-Log -Level Info -Message "Delete task requested for: $($task.Title)"
        
        $refreshCallback = { $this.RefreshData(); $this.UpdateDisplay() }.GetNewClosure()
        try {
            Show-ConfirmDialog -Title "Delete Task" -Message "Are you sure you want to delete `"$($task.Title)`"?" -OnConfirm {
                $this.Services.DataManager.RemoveTask($task)
                & $refreshCallback
            }
        } catch {
             Write-Log -Level Error -Message "Failed to show delete confirm dialog: $_"
        }
    }

    hidden [void] CycleFilter() {
        $this.FilterStatus = switch ($this.FilterStatus) {
            "All" { "Active" }
            "Active" { "Completed" }
            default { "All" }
        }
        $this.RefreshData()
        $this.UpdateDisplay()
    }

    hidden [void] NavigateBack() {
        try {
            $this.Services.Navigation.PopScreen()
        } catch {
            Write-Log -Level Error -Message "Failed to navigate back: $_"
        }
    }

    # --- NCurses Rendering ---
    [void] OnRender() {
        # AI: PHASE 3 - Ensure buffer exists and is properly sized
        if ($null -eq $this._private_buffer) {
            $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "TaskListScreen.Buffer")
        }
        
        # Clear buffer with background color
        $bgCell = [TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black)
        $this._private_buffer.Clear($bgCell)
        
        # SHOW INSTRUCTIONS: Force immediate console output to show controls
        try {
            $taskCount = if ($null -ne $this.FilteredTasks) { $this.FilteredTasks.Count } else { 0 }
            
            # Show instructions at the top of the screen
            [Console]::SetCursorPosition(0, 0)
            [Console]::ForegroundColor = [ConsoleColor]::Yellow
            [Console]::WriteLine("╔══════════════════════════════════════════════════════════════════════════════════════════════════╗")
            [Console]::WriteLine("║                                    TASK LIST CONTROLS                                               ║")
            [Console]::WriteLine("╠══════════════════════════════════════════════════════════════════════════════════════════════════╣")
            [Console]::ForegroundColor = [ConsoleColor]::White
            [Console]::WriteLine("║ [↑↓] Navigate  [Space] Toggle Complete  [N] New Task  [E] Edit  [D] Delete  [F] Filter  [Esc] Back ║")
            [Console]::WriteLine("║ Filter: $($this.FilterStatus)  |  Tasks: $taskCount  |  Selected: $($this.SelectedIndex + 1)".PadRight(98) + "║")
            [Console]::ForegroundColor = [ConsoleColor]::Yellow
            [Console]::WriteLine("╚══════════════════════════════════════════════════════════════════════════════════════════════════╝")
            [Console]::ResetColor()
            
        } catch {
            Write-Log -Level Error -Message "TaskListScreen instruction rendering failed: $_"
        }
        
        # The base Render() method will handle rendering children
    }
    
    [void] _RenderContent() {
        # AI: PHASE 3 - Buffer-based rendering
        if ($null -eq $this._private_buffer) { return }
        
        # AI: PHASE 3 - Clear buffer
        $bgCell = [TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black)
        $this._private_buffer.Clear($bgCell)
        
        # AI: PHASE 3 - Render all child components
        # Call the base class's _RenderContent which handles compositing children.
        ([UIElement]$this)._RenderContent()
    }
    
    # --- Lifecycle Methods ---
    [void] OnEnter() {
        $this.RefreshData()
        $this.UpdateDisplay()
        Write-Log -Level Debug -Message "TaskListScreen entered"
    }

    [void] OnExit() {
        Write-Log -Level Debug -Message "TaskListScreen exited"
    }

    [void] Cleanup() {
        $this.Components.Clear()
        $this.Children.Clear()
        Write-Log -Level Debug -Message "TaskListScreen cleaned up"
    }
}
