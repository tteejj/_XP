# ALCARLazyGitScreen - LazyGit-style interface integrated with ALCAR services
# Full integration with TaskService, ProjectService, and existing ALCAR data

class ALCARLazyGitScreen : Screen {
    # Core LazyGit components
    [object]$Layout
    [object]$Renderer
    [object]$FocusManager
    
    # Panels
    [object[]]$LeftPanels = @()
    [object]$MainPanel
    [object]$CommandBar
    
    # ALCAR Services integration
    [object]$TaskService
    [object]$ProjectService
    [object]$TimeTrackingService
    [object]$ViewDefinitionService
    
    # Screen state
    [bool]$IsInitialized = $false
    [bool]$ShowHelp = $false
    [string]$StatusMessage = ""
    [datetime]$LastStatusUpdate = [datetime]::Now
    
    # Performance tracking
    [int]$FrameCount = 0
    [double]$AverageFrameTime = 0
    
    ALCARLazyGitScreen() {
        $this.Title = "ALCAR LazyGit Interface"
        $this.Initialize()
    }
    
    [void] Initialize() {
        try {
            Write-Debug "Initializing ALCAR LazyGit interface..."
            
            # Get ALCAR services
            $this.TaskService = $global:ServiceContainer.GetService("TaskService")
            $this.ProjectService = $global:ServiceContainer.GetService("ProjectService")
            $this.ViewDefinitionService = $global:ServiceContainer.GetService("ViewDefinitionService")
            
            # Try to get optional services
            try {
                $this.TimeTrackingService = $global:ServiceContainer.GetService("TimeTrackingService")
            } catch {
                Write-Debug "TimeTrackingService not available"
            }
            
            # Create LazyGit components
            $this.Layout = [LazyGitLayout]::new()
            $this.Layout.CommandPaletteHeight = 3  # Just the command bar height
            $this.Layout.CalculateLayout()  # Recalculate layout with new command palette height
            $this.Renderer = [LazyGitRenderer]::new(8192)
            $this.FocusManager = [LazyGitFocusManager]::new()
            
            # Create command bar
            $this.CommandBar = [EnhancedCommandBar]::new()
            $this.CommandBar.ParentScreen = $this
            $this.CommandBar.Width = [Console]::WindowWidth
            $this.CommandBar.Y = 0
            
            # Create panels based on layout
            $this.CreatePanels()
            
            # Setup ALCAR-specific views
            $this.SetupALCARViews()
            
            # Initialize focus management (command bar is not part of focus cycle)
            $this.FocusManager.Initialize($this.LeftPanels, $this.MainPanel, $null)
            
            # Setup key bindings
            $this.InitializeKeyBindings()
            
            $this.IsInitialized = $true
            $this.SetStatusMessage("ALCAR LazyGit interface ready")
            
            Write-Debug "ALCAR LazyGit interface initialized successfully"
        } catch {
            Write-Host "ALCAR LazyGit initialization failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Debug "Stack trace: $($_.ScriptStackTrace)"
            throw
        }
    }
    
    # Create panels based on layout
    [void] CreatePanels() {
        $leftConfigs = $this.Layout.GetLeftPanelConfigs()
        $mainConfig = $this.Layout.GetMainPanelConfig()
        
        # Panel configuration for ALCAR
        $panelConfigs = @(
            @{ Title = "FILTERS"; ShortTitle = "FLT" },
            @{ Title = "PROJECTS"; ShortTitle = "PRJ" },
            @{ Title = "TASKS"; ShortTitle = "TSK" },
            @{ Title = "RECENT"; ShortTitle = "REC" },
            @{ Title = "BOOKMARKS"; ShortTitle = "BMK" },
            @{ Title = "ACTIONS"; ShortTitle = "ACT" }
        )
        
        # Create left panels
        $this.LeftPanels = @()
        for ($i = 0; $i -lt [Math]::Min($leftConfigs.Count, $panelConfigs.Count); $i++) {
            $config = $leftConfigs[$i]
            $panelConfig = $panelConfigs[$i]
            
            $panel = [LazyGitPanel]::new(
                $panelConfig.Title,
                $config.X,
                $config.Y,
                $config.Width,
                $config.Height
            )
            $panel.ShowBorder = $false  # LazyGit style
            $panel.ParentScreen = $this
            $this.LeftPanels += $panel
        }
        
        # Create main panel
        $this.MainPanel = [LazyGitPanel]::new(
            "DETAILS",
            $mainConfig.X,
            $mainConfig.Y,
            $mainConfig.Width,
            $mainConfig.Height
        )
        $this.MainPanel.ShowBorder = $false
        $this.MainPanel.ShowTabs = $false
        $this.MainPanel.ParentScreen = $this
    }
    
    # Setup ALCAR-specific views
    [void] SetupALCARViews() {
        # Panel 0: Filters with tabs
        if ($this.LeftPanels.Count -gt 0) {
            # Status filters tab
            $filterView = [ALCARFilterView]::new($this.TaskService)
            $filterView.Name = "Status"
            $filterView.ShortName = "STS"
            $this.LeftPanels[0].AddView($filterView)
            
            # Task list tab (showing task names with status)
            $taskListView = [ALCARTaskListView]::new($this.TaskService)
            $taskListView.Name = "Tasks"
            $taskListView.ShortName = "TSK" 
            $this.LeftPanels[0].AddView($taskListView)
        }
        
        # Panel 1: Projects
        if ($this.LeftPanels.Count -gt 1) {
            $projectView = [ALCARProjectView]::new($this.ProjectService, $this.TaskService)
            $this.LeftPanels[1].AddView($projectView)
            
            # Add a tree view tab
            $projectTreeView = [ALCARProjectTreeView]::new($this.ProjectService, $this.TaskService)
            $this.LeftPanels[1].AddView($projectTreeView)
        }
        
        # Panel 2: Tasks
        if ($this.LeftPanels.Count -gt 2) {
            $taskView = [ALCARTaskView]::new($this.TaskService, $this.ViewDefinitionService)
            $this.LeftPanels[2].AddView($taskView)
        }
        
        # Panel 3: Recent files/activities
        if ($this.LeftPanels.Count -gt 3) {
            $recentView = [ALCARRecentView]::new($this.TaskService, $this.ProjectService)
            $this.LeftPanels[3].AddView($recentView)
        }
        
        # Panel 4: Bookmarks
        if ($this.LeftPanels.Count -gt 4) {
            $bookmarkView = [ALCARBookmarkView]::new()
            $this.LeftPanels[4].AddView($bookmarkView)
        }
        
        # Panel 5: Actions
        if ($this.LeftPanels.Count -gt 5) {
            $actionView = [ALCARActionView]::new($this)
            $this.LeftPanels[5].AddView($actionView)
        }
        
        # Main panel: Task details
        $detailView = [ALCARDetailView]::new($this.TaskService, $this.ProjectService, $this.ViewDefinitionService)
        $this.MainPanel.AddView($detailView)
        
        # Set up cross-panel communication
        $this.SetupCrossPanelCommunication()
    }
    
    # Setup cross-panel communication
    [void] SetupCrossPanelCommunication() {
        $self = $this
        
        # Get panels
        $filterPanel = $this.LeftPanels | Where-Object { $_.Title -eq "FILTERS" } | Select-Object -First 1
        $projectPanel = $this.LeftPanels | Where-Object { $_.Title -eq "PROJECTS" } | Select-Object -First 1
        $taskPanel = $this.LeftPanels | Where-Object { $_.Title -eq "TASKS" } | Select-Object -First 1
        
        # When filter is changed, update task view
        if ($filterPanel) {
            # Status filter view
            $filterView = $filterPanel.Views | Where-Object { $_.Name -eq "Status" } | Select-Object -First 1
            if ($filterView) {
                $filterView | Add-Member -MemberType NoteProperty -Name "OnFilterChanged" -Value {
                    param($filter)
                    $taskView = $self.LeftPanels | Where-Object { $_.Title -eq "TASKS" } | Select-Object -First 1
                    if ($taskView -and $taskView.CurrentView) {
                        $taskView.CurrentView.FilterByStatus($filter)
                        $taskView.Invalidate()
                        $self.NeedsRender = $true
                    }
                }.GetNewClosure() -Force
            }
            
            # Task list view
            $taskListView = $filterPanel.Views | Where-Object { $_.Name -eq "Tasks" } | Select-Object -First 1
            if ($taskListView) {
                $taskListView | Add-Member -MemberType NoteProperty -Name "OnSelectionChanged" -Value {
                    param($selectedTask)
                    # Update details panel
                    if ($self.MainPanel.CurrentView) {
                        $self.MainPanel.CurrentView.SetSelection($selectedTask)
                        $self.MainPanel.Invalidate()
                        $self.NeedsRender = $true
                    }
                    # Update task panel selection
                    $taskPanel = $self.LeftPanels | Where-Object { $_.Title -eq "TASKS" } | Select-Object -First 1
                    if ($taskPanel -and $taskPanel.CurrentView) {
                        # Find and select the same task
                        $taskView = $taskPanel.CurrentView
                        for ($i = 0; $i -lt $taskView.Items.Count; $i++) {
                            if ($taskView.Items[$i].Id -eq $selectedTask.Id) {
                                $taskView.SelectedIndex = $i
                                $taskView.EnsureVisible($taskPanel.Height - 2)
                                $taskView.IsDirty = $true
                                break
                            }
                        }
                    }
                }.GetNewClosure() -Force
            }
        }
        
        # When a project is selected, filter tasks by project
        if ($projectPanel) {
            $projectView = $projectPanel.Views | Where-Object { $_.Name -eq "Projects" } | Select-Object -First 1
            if ($projectView) {
                $projectView | Add-Member -MemberType NoteProperty -Name "OnSelectionChanged" -Value {
                    param($selectedProject)
                    $taskView = $self.LeftPanels | Where-Object { $_.Title -eq "TASKS" } | Select-Object -First 1
                    if ($taskView -and $taskView.CurrentView) {
                        $taskView.CurrentView.FilterByProject($selectedProject)
                        $taskView.Invalidate()
                        $self.NeedsRender = $true
                    }
                }.GetNewClosure() -Force
            }
        }
        
        # When a task is selected, update the detail view
        if ($taskPanel) {
            $taskView = $taskPanel.Views | Where-Object { $_.Name -eq "Tasks" } | Select-Object -First 1
            if ($taskView) {
                $taskView | Add-Member -MemberType NoteProperty -Name "OnSelectionChanged" -Value {
                    param($selectedTask)
                    if ($self.MainPanel.CurrentView) {
                        $self.MainPanel.CurrentView.SetSelection($selectedTask)
                        $self.MainPanel.Invalidate()
                        $self.NeedsRender = $true
                    }
                }.GetNewClosure() -Force
                
                # Edit task handler
                $taskView | Add-Member -MemberType NoteProperty -Name "OnEditTask" -Value {
                    param($task)
                    $self.EditTask($task)
                }.GetNewClosure() -Force
                
                # Delete task handler
                $taskView | Add-Member -MemberType NoteProperty -Name "OnDeleteTask" -Value {
                    param($task)
                    $self.DeleteTask($task)
                }.GetNewClosure() -Force
                
                # New task handler
                $taskView | Add-Member -MemberType NoteProperty -Name "OnNewTask" -Value {
                    $self.CreateNewTask()
                }.GetNewClosure() -Force
            }
        }
    }
    
    # Initialize key bindings
    [void] InitializeKeyBindings() {
        # Screen-specific bindings
        $this.BindKey([ConsoleKey]::F1, { $this.ToggleHelp() })
        $this.BindKey([ConsoleKey]::F5, { $this.RefreshAll() })
        $this.BindKey([ConsoleKey]::F12, { $this.ShowLayoutInfo() })
        $this.BindKey('q', { $this.Quit() })
        $this.BindKey('r', { $this.RefreshAll() })
        $this.BindKey('n', { $this.CreateNewTask() })
        $this.BindKey('p', { $this.CreateNewProject() })
        $this.BindKey('/', { $this.ActivateSearch() })
        $this.BindKey('?', { $this.ToggleHelp() })
    }
    
    # Override OnActivate to clear screen properly
    [void] OnActivate() {
        # Clear the entire screen first
        [Console]::Clear()
        
        # Force a full redraw
        $this.Layout.MarkDirty()
        $this.Renderer.ClearBuffer()
        
        # Initialize focus if not already done
        if ($this.FocusManager.FocusedPanelIndex -eq -1) {
            $this.FocusManager.SetFocus(0)  # Focus first left panel
        }
        
        # Set status message
        $this.SetStatusMessage("Ready | Ctrl+Tab: Switch | Ctrl+P: Commands | Space: Toggle | E: Edit | D: Delete | N: New | Q: Quit")
        
        # Force render
        $this.NeedsRender = $true
    }
    
    # Main rendering method
    [string] RenderContent() {
        if (-not $this.IsInitialized) {
            return "Initializing ALCAR LazyGit interface..."
        }
        
        # Check for layout updates
        if ($this.Layout.NeedsRecalculation()) {
            $this.UpdateLayout()
        }
        
        # Begin frame (renderer now handles clearing)
        $buffer = $this.Renderer.BeginFrame()
        
        # Render command bar at top
        $buffer.Append($this.CommandBar.Render()) | Out-Null
        
        # Render all panels (layout already accounts for command bar space)
        foreach ($panel in $this.LeftPanels) {
            $buffer.Append($panel.Render()) | Out-Null
        }
        
        # Main panel
        $buffer.Append($this.MainPanel.Render()) | Out-Null
        
        # Render status and help
        $this.RenderStatusLine($buffer)
        
        # Render help overlay if active
        if ($this.ShowHelp) {
            $this.RenderHelpOverlay($buffer)
        }
        
        # Render command dropdown as overlay (last so it appears on top)
        $dropdownOverlay = $this.CommandBar.RenderDropdownOverlay()
        if ($dropdownOverlay) {
            $buffer.Append($dropdownOverlay) | Out-Null
        }
        
        return $buffer.ToString()
    }
    
    # Handle input
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        # Check for Ctrl+P to activate command bar
        if ($key.Key -eq [ConsoleKey]::P -and $key.Modifiers -eq [ConsoleModifiers]::Control) {
            $this.ActivateCommandBar()
            $this.NeedsRender = $true
            return $true
        }
        
        # If command bar is active, let it handle input
        if ($this.CommandBar.IsActive) {
            if ($this.CommandBar.HandleInput($key)) {
                $this.NeedsRender = $true
                return $true
            }
        }
        
        # Let focus manager handle panel navigation
        if ($this.FocusManager.HandleInput($key)) {
            $this.UpdateCommandBarContext()
            $this.NeedsRender = $true
            return $true
        }
        
        # Check our key bindings first
        $binding = $null
        
        # Try special keys
        if ($key.Key -ne [ConsoleKey]::None) {
            $binding = $this.KeyBindings[$key.Key.ToString()]
        }
        
        # Try character keys
        if (-not $binding -and $key.KeyChar) {
            $binding = $this.KeyBindings[[string]$key.KeyChar]
        }
        
        # Execute binding if found
        if ($binding) {
            if ($binding -is [scriptblock]) {
                & $binding
            }
            $this.NeedsRender = $true
            return $true
        }
        
        return $false
    }
    
    # Update layout on terminal resize
    [void] UpdateLayout() {
        $this.Layout.UpdateTerminalSize()
        $this.Layout.AutoAdjust()
        
        # Update panel positions
        $leftConfigs = $this.Layout.GetLeftPanelConfigs()
        for ($i = 0; $i -lt [Math]::Min($this.LeftPanels.Count, $leftConfigs.Count); $i++) {
            $config = $leftConfigs[$i]
            $this.LeftPanels[$i].MoveTo($config.X, $config.Y)
            $this.LeftPanels[$i].Resize($config.Width, $config.Height)
        }
        
        $mainConfig = $this.Layout.GetMainPanelConfig()
        $this.MainPanel.MoveTo($mainConfig.X, $mainConfig.Y)
        $this.MainPanel.Resize($mainConfig.Width, $mainConfig.Height)
        
        $this.SetStatusMessage("Layout updated: $($this.Layout.LayoutMode) mode")
    }
    
    
    # Render status line
    [void] RenderStatusLine([System.Text.StringBuilder]$buffer) {
        $termHeight = $this.Layout.TerminalHeight
        $statusY = $termHeight - 1  # Bottom line
        
        $buffer.Append($this.Renderer.MoveTo(1, $statusY)) | Out-Null
        
        $focusState = $this.FocusManager.GetFocusState()
        $layoutStats = $this.Layout.GetLayoutStats()
        
        # Clear old status message after 3 seconds
        if (([datetime]::Now - $this.LastStatusUpdate).TotalSeconds -gt 3) {
            $this.StatusMessage = ""
        }
        
        # Build status text
        $statusText = "ALCAR | $($focusState.FocusedPanelName) | $($layoutStats.LayoutMode) | "
        if (-not [string]::IsNullOrEmpty($this.StatusMessage)) {
            $statusText += $this.StatusMessage
        } else {
            # Show task/project counts
            $taskCount = if ($this.TaskService) { $this.TaskService.GetAllTasks().Count } else { 0 }
            $projectCount = if ($this.ProjectService) { $this.ProjectService.GetAllProjects().Count } else { 0 }
            $statusText += "$taskCount tasks, $projectCount projects | Ctrl+Tab=Navigate F1=Help"
        }
        
        # Truncate if too long
        $maxLength = $this.Layout.TerminalWidth - 2
        if ($statusText.Length -gt $maxLength) {
            $statusText = $statusText.Substring(0, $maxLength - 3) + "..."
        }
        
        $buffer.Append($this.Renderer.GetVT("fg_dim")) | Out-Null
        $buffer.Append($statusText) | Out-Null
        $buffer.Append($this.Renderer.GetVT("reset")) | Out-Null
    }
    
    # Render help overlay
    [void] RenderHelpOverlay([System.Text.StringBuilder]$buffer) {
        $helpLines = @(
            "ALCAR LazyGit Interface - Help",
            "",
            "Panel Navigation:",
            "  Ctrl+Tab / Ctrl+Shift+Tab - Next/Previous panel",
            "  Alt+1-9 - Jump to panel 1-9",
            "  Alt+0 - Jump to main panel",
            "  Ctrl+P - Toggle command palette",
            "",
            "Within Panels:",
            "  ↑↓ - Navigate items",
            "  Enter - Select/Open",
            "  Tab/Shift+Tab - Switch tabs",
            "  Space - Toggle (where applicable)",
            "",
            "Actions:",
            "  n - New task",
            "  p - New project",
            "  / - Search",
            "  r/F5 - Refresh all",
            "  q/Esc - Exit",
            "",
            "Press any key to close help"
        )
        
        $helpWidth = 60
        $helpHeight = $helpLines.Count + 2
        $startX = [Math]::Max(1, ([Console]::WindowWidth - $helpWidth) / 2)
        $startY = [Math]::Max(1, ([Console]::WindowHeight - $helpHeight) / 2)
        
        # Draw background
        for ($y = 0; $y -lt $helpHeight; $y++) {
            $buffer.Append($this.Renderer.MoveTo($startX, $startY + $y)) | Out-Null
            $buffer.Append($this.Renderer.GetVT("bg_selected")) | Out-Null
            $buffer.Append(" " * $helpWidth) | Out-Null
            $buffer.Append($this.Renderer.GetVT("reset")) | Out-Null
        }
        
        # Draw help content
        for ($i = 0; $i -lt $helpLines.Count; $i++) {
            $buffer.Append($this.Renderer.MoveTo($startX + 2, $startY + $i + 1)) | Out-Null
            $buffer.Append($this.Renderer.GetVT("fg_bright")) | Out-Null
            $buffer.Append($helpLines[$i].PadRight($helpWidth - 4)) | Out-Null
            $buffer.Append($this.Renderer.GetVT("reset")) | Out-Null
        }
    }
    
    # Commands
    [void] ToggleHelp() {
        $this.ShowHelp = -not $this.ShowHelp
        if ($this.ShowHelp) {
            $this.SetStatusMessage("Help shown - Press any key to close")
        } else {
            $this.SetStatusMessage("Help hidden")
        }
    }
    
    [void] RefreshAll() {
        # Refresh all data from services
        foreach ($panel in $this.LeftPanels) {
            $panel.RefreshData()
        }
        $this.MainPanel.RefreshData()
        $this.SetStatusMessage("All panels refreshed")
    }
    
    [void] ShowLayoutInfo() {
        $layoutInfo = $this.Layout.ExportLayout()
        Write-Host $layoutInfo -ForegroundColor Yellow
        $stats = $this.Layout.GetLayoutStats()
        Write-Host "Panel Utilization: Left=$($stats.LeftPanelUtilization)% Main=$($stats.MainPanelUtilization)%" -ForegroundColor Cyan
        $this.SetStatusMessage("Layout info shown in console")
    }
    
    [void] CreateNewTask() {
        # Use ALCAR's task creation dialog
        $dialog = [EditDialog]::new($this, "New Task", $null, "Task")
        $result = $dialog.Show()
        if ($result -and $result.Name) {
            $task = [Task]::new()
            $task.Name = $result.Name
            $task.Description = $result.Description
            $task.Status = "Pending"
            $task.Priority = "Medium"
            
            if ($this.TaskService) {
                $this.TaskService.AddTask($task)
                $this.RefreshAll()
                $this.SetStatusMessage("Task created: $($task.Name)")
            }
        }
    }
    
    [void] CreateNewProject() {
        # Use ALCAR's project creation dialog
        $dialog = [ProjectCreationDialog]::new($this)
        $result = $dialog.Show()
        if ($result) {
            $this.RefreshAll()
            $this.SetStatusMessage("Project created: $($result.Name)")
        }
    }
    
    [void] EditTask([object]$task) {
        if (-not $task) { return }
        
        # Use ALCAR's edit dialog
        $dialog = [EditDialog]::new($this, "Edit Task", $task, "Task")
        $result = $dialog.Show()
        if ($result) {
            # Update task with edited values
            $task.Name = $result.Name
            $task.Description = $result.Description
            $task.Status = $result.Status
            $task.Priority = $result.Priority
            
            if ($this.TaskService) {
                $this.TaskService.UpdateTask($task)
                $this.RefreshAll()
                $this.SetStatusMessage("Task updated: $($task.Name)")
            }
        }
    }
    
    [void] DeleteTask([object]$task) {
        if (-not $task) { return }
        
        # Confirm deletion
        $confirmDialog = [DeleteConfirmDialog]::new($this, "Delete Task", "Are you sure you want to delete '$($task.Name)'?")
        if ($confirmDialog.Show() -eq [DialogResult]::OK) {
            if ($this.TaskService) {
                $this.TaskService.DeleteTask($task.Id)
                $this.RefreshAll()
                $this.SetStatusMessage("Task deleted: $($task.Name)")
            }
        }
    }
    
    [void] ActivateSearch() {
        # Activate command bar in search mode
        $this.ActivateCommandBar()
        $this.SetStatusMessage("Search activated")
    }
    
    [void] ActivateCommandBar() {
        $this.CommandBar.Activate()
        $this.UpdateCommandBarContext()
    }
    
    [void] UpdateCommandBarContext() {
        # Get current context
        $focusedPanel = $this.FocusManager.GetFocusedPanel()
        $panelName = ""
        $currentTask = $null
        $currentProject = $null
        
        if ($focusedPanel) {
            if ($focusedPanel.Title -eq "TASKS" -and $focusedPanel.CurrentView) {
                $panelName = "task"
                $currentTask = $focusedPanel.CurrentView.GetSelectedItem()
            } elseif ($focusedPanel.Title -eq "PROJECTS" -and $focusedPanel.CurrentView) {
                $panelName = "project"  
                $currentProject = $focusedPanel.CurrentView.GetSelectedItem()
            } elseif ($focusedPanel.Title -eq "FILTERS") {
                $panelName = "filter"
            }
        }
        
        $this.CommandBar.SetContext($currentProject, $currentTask, $panelName)
    }
    
    [void] ApplyFilter([string]$filter) {
        # Find filter panel and apply filter
        $filterPanel = $this.LeftPanels | Where-Object { $_.Title -eq "FILTERS" } | Select-Object -First 1
        if ($filterPanel -and $filterPanel.CurrentView) {
            $filterView = $filterPanel.CurrentView
            if ($filterView.PSObject.Properties.Name -contains "OnFilterChanged") {
                $filterView.ActiveFilter = $filter
                $filterView.OnFilterChanged.Invoke($filter)
                $filterView.IsDirty = $true
                $this.NeedsRender = $true
            }
        }
    }
    
    [void] ToggleTaskStatus([object]$task) {
        if (-not $task) { return }
        
        switch ($task.Status) {
            "Pending" { $task.Status = "Active" }
            "Active" { $task.Status = "Completed" }
            "Completed" { $task.Status = "Pending" }
        }
        
        if ($this.TaskService) {
            $this.TaskService.UpdateTask($task)
            $this.RefreshAll()
        }
    }
    
    [void] Quit() {
        $this.SetStatusMessage("Exiting ALCAR LazyGit interface...")
        $this.Active = $false
    }
    
    [void] SetStatusMessage([string]$message) {
        $this.StatusMessage = $message
        $this.LastStatusUpdate = [datetime]::Now
    }
    
    # Cleanup
    [void] Dispose() {
        if ($this.Renderer) {
            $this.Renderer.Dispose()
        }
        
        if ($this.FocusManager) {
            $this.FocusManager.Reset()
        }
    }
}

# ALCAR-specific view implementations
class ALCARFilterView : LazyGitViewBase {
    [object]$TaskService
    [string]$ActiveFilter = "All"
    
    ALCARFilterView([object]$taskService) : base("Filters", "FLT") {
        $this.TaskService = $taskService
        $this.LoadFilters()
    }
    
    [void] LoadFilters() {
        $this.Items = @(
            @{ Name = "All Tasks"; Filter = "All" },
            @{ Name = "Active"; Filter = "Active" },
            @{ Name = "Pending"; Filter = "Pending" },
            @{ Name = "Completed"; Filter = "Completed" },
            @{ Name = "High Priority"; Filter = "HighPriority" },
            @{ Name = "Due Today"; Filter = "DueToday" },
            @{ Name = "Overdue"; Filter = "Overdue" },
            @{ Name = "No Project"; Filter = "NoProject" }
        )
    }
    
    [string] Render([int]$width, [int]$height) {
        $output = [System.Text.StringBuilder]::new(512)
        
        # Ensure selection is visible
        $this.EnsureVisible($height)
        
        # Calculate visible range
        $startIdx = $this.ScrollOffset
        $endIdx = [Math]::Min($this.Items.Count, $startIdx + $height)
        
        for ($i = $startIdx; $i -lt $endIdx; $i++) {
            $item = $this.Items[$i]
            $prefix = if ($item.Filter -eq $this.ActiveFilter) { "◉ " } else { "◯ " }  # Radio button style
            $line = $this.RenderListItem($i, "$prefix$($item.Name)", $width)
            $output.AppendLine($line) | Out-Null
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter) {
            $this.ActiveFilter = $this.Items[$this.SelectedIndex].Filter
            $this.IsDirty = $true
            
            # Trigger filter change
            if ($this.PSObject.Properties.Name -contains "OnFilterChanged") {
                $this.OnFilterChanged.Invoke($this.ActiveFilter)
            }
            
            return $true
        }
        
        return ([LazyGitViewBase]$this).HandleInput($key)
    }
}

class ALCARProjectView : LazyGitViewBase {
    [object]$ProjectService
    [object]$TaskService
    
    ALCARProjectView([object]$projectService, [object]$taskService) : base("Projects", "PRJ") {
        $this.ProjectService = $projectService
        $this.TaskService = $taskService
        $this.RefreshData()
    }
    
    [void] RefreshData() {
        $this.LoadProjects()
    }
    
    [void] LoadProjects() {
        try {
            $this.Items = @()
            
            if ($this.ProjectService) {
                $projects = $this.ProjectService.GetAllProjects()
                foreach ($project in $projects) {
                    $taskCount = 0
                    if ($this.TaskService) {
                        $tasks = $this.TaskService.GetTasksByProject($project.Id)
                        $taskCount = $tasks.Count
                    }
                    
                    $this.Items += @{
                        Name = $project.Name
                        Type = "Project"
                        Data = $project
                        TaskCount = $taskCount
                    }
                }
            }
            
            # Add "No Project" option
            $this.Items += @{
                Name = "(No Project)"
                Type = "NoProject"
                Data = $null
                TaskCount = 0
            }
        } catch {
            Write-Debug "Failed to load projects: $($_.Exception.Message)"
            $this.Items = @(@{ Name = "Error loading projects"; Type = "Error"; Data = $null })
        }
    }
    
    [string] Render([int]$width, [int]$height) {
        $output = [System.Text.StringBuilder]::new(1024)
        
        for ($i = 0; $i -lt [Math]::Min($this.Items.Count, $height); $i++) {
            $item = $this.Items[$i]
            $icon = switch ($item.Type) {
                "Project" { "◆" }  # Diamond for projects
                "NoProject" { "◇" }  # Empty diamond for no project
                "Error" { "⚠" }  # Warning symbol for errors
                default { "•" }  # Bullet for default
            }
            
            $text = "$icon $($item.Name)"
            if ($item.Type -eq "Project" -and $item.TaskCount -gt 0) {
                $text += " ($($item.TaskCount))"
            }
            
            $line = $this.RenderListItem($i, $text, $width)
            $output.AppendLine($line) | Out-Null
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter) {
            $selectedItem = $this.GetSelectedItem()
            if ($selectedItem -and $this.PSObject.Properties.Name -contains "OnSelectionChanged") {
                $this.OnSelectionChanged.Invoke($selectedItem.Data)
            }
            return $true
        }
        
        return ([LazyGitViewBase]$this).HandleInput($key)
    }
}

class ALCARProjectTreeView : LazyGitViewBase {
    [object]$ProjectService
    [object]$TaskService
    [hashtable]$ExpandedProjects = @{}
    
    ALCARProjectTreeView([object]$projectService, [object]$taskService) : base("Tree View", "TRE") {
        $this.ProjectService = $projectService
        $this.TaskService = $taskService
        $this.RefreshData()
    }
    
    [void] RefreshData() {
        $this.LoadProjectTree()
    }
    
    [void] LoadProjectTree() {
        $this.Items = @()
        
        if ($this.ProjectService) {
            $projects = $this.ProjectService.GetAllProjects()
            foreach ($project in $projects) {
                # Add project
                $this.Items += @{
                    Name = $project.Name
                    Type = "Project"
                    Data = $project
                    Level = 0
                    ProjectId = $project.Id
                }
                
                # Add tasks if expanded
                if ($this.ExpandedProjects[$project.Id] -and $this.TaskService) {
                    $tasks = $this.TaskService.GetTasksByProject($project.Id)
                    foreach ($task in $tasks) {
                        $this.Items += @{
                            Name = $task.Name
                            Type = "Task"
                            Data = $task
                            Level = 1
                            ProjectId = $project.Id
                            Status = $task.Status
                        }
                    }
                }
            }
        }
    }
    
    [string] Render([int]$width, [int]$height) {
        $output = [System.Text.StringBuilder]::new(1024)
        
        for ($i = 0; $i -lt [Math]::Min($this.Items.Count, $height); $i++) {
            $item = $this.Items[$i]
            $indent = "  " * $item.Level
            
            $icon = ""
            if ($item.Type -eq "Project") {
                $isExpanded = $this.ExpandedProjects[$item.ProjectId]
                $icon = if ($isExpanded) { "▼ ◆" } else { "▶ ◆" }  # Triangle for expand/collapse, diamond for project
            } else {
                $icon = switch ($item.Status) {
                    "Completed" { "  ✓" }  # Checkmark for completed
                    "Active" { "  ●" }  # Filled circle for active
                    default { "  ○" }  # Empty circle for pending
                }
            }
            
            $text = "$indent$icon $($item.Name)"
            $line = $this.RenderListItem($i, $text, $width)
            $output.AppendLine($line) | Out-Null
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter -or $key.Key -eq [ConsoleKey]::Spacebar) {
            $item = $this.GetSelectedItem()
            if ($item -and $item.Type -eq "Project") {
                # Toggle expansion
                $this.ExpandedProjects[$item.ProjectId] = -not $this.ExpandedProjects[$item.ProjectId]
                $this.RefreshData()
                $this.IsDirty = $true
                return $true
            }
        }
        
        return ([LazyGitViewBase]$this).HandleInput($key)
    }
}

class ALCARTaskView : LazyGitViewBase {
    [object]$TaskService
    [object]$ViewDefinitionService
    [object]$CurrentProject = $null
    [string]$CurrentFilter = "All"
    
    ALCARTaskView([object]$taskService, [object]$viewDefService) : base("Tasks", "TSK") {
        $this.TaskService = $taskService
        $this.ViewDefinitionService = $viewDefService
        $this.RefreshData()
    }
    
    [void] RefreshData() {
        $this.LoadTasks()
    }
    
    [void] LoadTasks() {
        try {
            $this.Items = @()
            
            if ($this.TaskService) {
                $allTasks = $this.TaskService.GetAllTasks()
                
                # Filter by project if set
                if ($this.CurrentProject) {
                    $allTasks = $allTasks | Where-Object { $_.ProjectId -eq $this.CurrentProject.Id }
                } elseif ($this.CurrentProject -eq $null -and $this.CurrentFilter -eq "NoProject") {
                    $allTasks = $allTasks | Where-Object { -not $_.ProjectId }
                }
                
                # Apply filter
                switch ($this.CurrentFilter) {
                    "Active" { $allTasks = $allTasks | Where-Object { $_.Status -eq "Active" } }
                    "Pending" { $allTasks = $allTasks | Where-Object { $_.Status -eq "Pending" } }
                    "Completed" { $allTasks = $allTasks | Where-Object { $_.Status -eq "Completed" } }
                    "HighPriority" { $allTasks = $allTasks | Where-Object { $_.Priority -eq "High" } }
                    "DueToday" {
                        $today = [datetime]::Today
                        $allTasks = $allTasks | Where-Object { 
                            $_.DueDate -and [datetime]$_.DueDate.Date -eq $today 
                        }
                    }
                    "Overdue" {
                        $today = [datetime]::Today
                        $allTasks = $allTasks | Where-Object { 
                            $_.DueDate -and [datetime]$_.DueDate.Date -lt $today -and $_.Status -ne "Completed"
                        }
                    }
                }
                
                $this.Items = $allTasks
            }
        } catch {
            Write-Debug "Failed to load tasks: $($_.Exception.Message)"
            $this.Items = @()
        }
    }
    
    [string] Render([int]$width, [int]$height) {
        $output = [System.Text.StringBuilder]::new(1024)
        
        if ($this.Items.Count -eq 0) {
            $output.AppendLine("  (no tasks)") | Out-Null
            return $output.ToString().TrimEnd("`r`n")
        }
        
        for ($i = 0; $i -lt [Math]::Min($this.Items.Count, $height); $i++) {
            $task = $this.Items[$i]
            $icon = switch ($task.Status) {
                "Completed" { "✓" }  # Checkmark
                "Active" { "●" }     # Filled circle
                "Blocked" { "⊗" }    # Circle with X
                default { "○" }       # Empty circle
            }
            
            # Use ViewDefinitionService if available for consistent formatting
            $text = if ($this.ViewDefinitionService) {
                $formatted = $this.ViewDefinitionService.FormatTaskLine($task, $width - 4)
                "$icon $formatted"
            } else {
                $priority = switch ($task.Priority) {
                    "High" { "!" }
                    "Low" { "↓" }
                    default { " " }
                }
                "$icon$priority $($task.Name)"
            }
            
            $line = $this.RenderListItem($i, $text, $width)
            $output.AppendLine($line) | Out-Null
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
    
    [void] SetFilter([string]$filter) {
        $this.CurrentFilter = $filter
        $this.RefreshData()
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter) {
            $selectedTask = $this.GetSelectedItem()
            if ($selectedTask -and $this.PSObject.Properties.Name -contains "OnSelectionChanged") {
                $this.OnSelectionChanged.Invoke($selectedTask)
            }
            return $true
        }
        
        if ($key.Key -eq [ConsoleKey]::Spacebar) {
            # Toggle task status
            $task = $this.GetSelectedItem()
            if ($task) {
                switch ($task.Status) {
                    "Pending" { $task.Status = "Active" }
                    "Active" { $task.Status = "Completed" }
                    "Completed" { $task.Status = "Pending" }
                }
                
                if ($this.TaskService) {
                    $this.TaskService.UpdateTask($task)
                }
                
                $this.IsDirty = $true
                return $true
            }
        }
        
        # Edit task
        if ($key.KeyChar -eq 'e') {
            $task = $this.GetSelectedItem()
            if ($task -and $this.PSObject.Properties.Name -contains "OnEditTask") {
                $this.OnEditTask.Invoke($task)
            }
            return $true
        }
        
        # Delete task
        if ($key.KeyChar -eq 'd') {
            $task = $this.GetSelectedItem()
            if ($task -and $this.PSObject.Properties.Name -contains "OnDeleteTask") {
                $this.OnDeleteTask.Invoke($task)
            }
            return $true
        }
        
        # New task
        if ($key.KeyChar -eq 'n') {
            if ($this.PSObject.Properties.Name -contains "OnNewTask") {
                $this.OnNewTask.Invoke()
            }
            return $true
        }
        
        return ([LazyGitViewBase]$this).HandleInput($key)
    }
    
    [hashtable] GetContextCommands() {
        return @{
            "Enter" = "Open task"
            "Space" = "Toggle status"
            "e" = "Edit task"
            "d" = "Delete task"
            "n" = "New task"
        }
    }
    
    [void] FilterByStatus([string]$filter) {
        $this.CurrentFilter = $filter
        $this.LoadTasks()
        $this.IsDirty = $true
    }
    
    [void] FilterByProject([object]$project) {
        $this.CurrentProject = $project
        $this.LoadTasks()
        $this.IsDirty = $true
    }
}

class ALCARTaskListView : LazyGitViewBase {
    [object]$TaskService
    
    ALCARTaskListView([object]$taskService) : base("Task List", "TSK") {
        $this.TaskService = $taskService
        $this.RefreshData()
    }
    
    [void] RefreshData() {
        $this.LoadTasks()
    }
    
    [void] LoadTasks() {
        try {
            $this.Items = @()
            
            if ($this.TaskService) {
                $allTasks = $this.TaskService.GetAllTasks() | Sort-Object Name
                
                foreach ($task in $allTasks) {
                    $this.Items += @{
                        Name = $task.Name
                        Status = $task.Status
                        Priority = $task.Priority
                        Task = $task
                    }
                }
            }
        } catch {
            Write-Debug "Failed to load task list: $($_.Exception.Message)"
            $this.Items = @()
        }
    }
    
    [string] Render([int]$width, [int]$height) {
        $output = [System.Text.StringBuilder]::new(1024)
        
        if ($this.Items.Count -eq 0) {
            $output.AppendLine("  (no tasks)") | Out-Null
            return $output.ToString().TrimEnd("`r`n")
        }
        
        # Ensure selection is visible
        $this.EnsureVisible($height)
        
        # Calculate visible range
        $startIdx = $this.ScrollOffset
        $endIdx = [Math]::Min($this.Items.Count, $startIdx + $height)
        
        for ($i = $startIdx; $i -lt $endIdx; $i++) {
            $item = $this.Items[$i]
            
            # Format: STATUS TaskName (Priority)
            $status = switch ($item.Status) {
                "Completed" { "✓" }  # Checkmark
                "Active" { "●" }     # Filled circle
                "Blocked" { "⊗" }    # Circle with X
                default { "○" }       # Empty circle
            }
            
            $priority = switch ($item.Priority) {
                "High" { "(H)" }
                "Medium" { "(M)" }
                "Low" { "(L)" }
                default { "" }
            }
            
            $text = "$status $($item.Name)"
            if ($priority) {
                $text += " $priority"
            }
            
            # Truncate if needed
            if ($text.Length -gt $width - 2) {
                $text = $text.Substring(0, $width - 5) + "..."
            }
            
            $line = $this.RenderListItem($i, $text, $width)
            $output.AppendLine($line) | Out-Null
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter) {
            $selectedItem = $this.GetSelectedItem()
            if ($selectedItem -and $this.PSObject.Properties.Name -contains "OnSelectionChanged") {
                $this.OnSelectionChanged.Invoke($selectedItem.Task)
            }
            return $true
        }
        
        return ([LazyGitViewBase]$this).HandleInput($key)
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
}

class ALCARRecentView : LazyGitViewBase {
    [object]$TaskService
    [object]$ProjectService
    
    ALCARRecentView([object]$taskService, [object]$projectService) : base("Recent", "REC") {
        $this.TaskService = $taskService
        $this.ProjectService = $projectService
        $this.RefreshData()
    }
    
    [void] RefreshData() {
        $this.LoadRecent()
    }
    
    [void] LoadRecent() {
        $this.Items = @()
        
        # Get recently modified tasks
        if ($this.TaskService) {
            $recentTasks = $this.TaskService.GetAllTasks() | 
                Where-Object { $_.ModifiedDate } |
                Sort-Object ModifiedDate -Descending |
                Select-Object -First 5
            
            foreach ($task in $recentTasks) {
                $this.Items += @{
                    Name = $task.Name
                    Type = "Task"
                    Data = $task
                    Time = $task.ModifiedDate
                }
            }
        }
        
        # Get recently accessed projects
        if ($this.ProjectService) {
            $recentProjects = $this.ProjectService.GetAllProjects() |
                Where-Object { $_.LastAccessed } |
                Sort-Object LastAccessed -Descending |
                Select-Object -First 3
            
            foreach ($project in $recentProjects) {
                $this.Items += @{
                    Name = $project.Name
                    Type = "Project"
                    Data = $project
                    Time = $project.LastAccessed
                }
            }
        }
        
        # Sort all by time
        $this.Items = $this.Items | Sort-Object Time -Descending
    }
    
    [string] Render([int]$width, [int]$height) {
        $output = [System.Text.StringBuilder]::new(512)
        
        if ($this.Items.Count -eq 0) {
            $output.AppendLine("  (no recent items)") | Out-Null
            return $output.ToString().TrimEnd("`r`n")
        }
        
        for ($i = 0; $i -lt [Math]::Min($this.Items.Count, $height); $i++) {
            $item = $this.Items[$i]
            $icon = if ($item.Type -eq "Task") { "▸" } else { "◆" }  # Right triangle for tasks, diamond for projects
            $timeAgo = $this.GetTimeAgo($item.Time)
            
            $text = "$icon $($item.Name) - $timeAgo"
            if ($text.Length -gt $width - 2) {
                $text = $text.Substring(0, $width - 5) + "..."
            }
            
            $line = $this.RenderListItem($i, $text, $width)
            $output.AppendLine($line) | Out-Null
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
    
    [string] GetTimeAgo([datetime]$time) {
        $span = [datetime]::Now - $time
        if ($span.TotalMinutes -lt 60) {
            return "$([int]$span.TotalMinutes)m ago"
        } elseif ($span.TotalHours -lt 24) {
            return "$([int]$span.TotalHours)h ago"
        } else {
            return "$([int]$span.TotalDays)d ago"
        }
    }
}

class ALCARBookmarkView : LazyGitViewBase {
    ALCARBookmarkView() : base("Bookmarks", "BMK") {
        $this.LoadBookmarks()
    }
    
    [void] LoadBookmarks() {
        $this.Items = @(
            @{ Name = "🏠 Dashboard"; Action = "Dashboard" },
            @{ Name = "📋 All Tasks"; Action = "AllTasks" },
            @{ Name = "🔄 Active Tasks"; Action = "ActiveTasks" },
            @{ Name = "📅 Today's Tasks"; Action = "TodayTasks" },
            @{ Name = "📊 Task Statistics"; Action = "TaskStats" },
            @{ Name = "🗂️ All Projects"; Action = "AllProjects" },
            @{ Name = "⏱️ Time Tracking"; Action = "TimeTracking" }
        )
    }
    
    [string] Render([int]$width, [int]$height) {
        $output = [System.Text.StringBuilder]::new(512)
        
        for ($i = 0; $i -lt [Math]::Min($this.Items.Count, $height); $i++) {
            $item = $this.Items[$i]
            $line = $this.RenderListItem($i, $item.Name, $width)
            $output.AppendLine($line) | Out-Null
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
}

class ALCARActionView : LazyGitViewBase {
    [object]$ParentScreen
    
    ALCARActionView([object]$parentScreen) : base("Actions", "ACT") {
        $this.ParentScreen = $parentScreen
        $this.LoadActions()
    }
    
    [void] LoadActions() {
        $this.Items = @(
            @{ Name = "➕ New Task"; Key = "n"; Action = { $this.ParentScreen.CreateNewTask() } },
            @{ Name = "➕ New Project"; Key = "p"; Action = { $this.ParentScreen.CreateNewProject() } },
            @{ Name = "🔍 Search"; Key = "/"; Action = { $this.ParentScreen.ActivateSearch() } },
            @{ Name = "📤 Export Data"; Key = "e"; Action = { Write-Host "Export not implemented" } },
            @{ Name = "⚙️ Settings"; Key = "s"; Action = { Write-Host "Settings not implemented" } },
            @{ Name = "🔄 Refresh All"; Key = "r"; Action = { $this.ParentScreen.RefreshAll() } },
            @{ Name = "❓ Help"; Key = "?"; Action = { $this.ParentScreen.ToggleHelp() } },
            @{ Name = "🚪 Exit"; Key = "q"; Action = { $this.ParentScreen.Quit() } }
        )
    }
    
    [string] Render([int]$width, [int]$height) {
        $output = [System.Text.StringBuilder]::new(512)
        
        for ($i = 0; $i -lt [Math]::Min($this.Items.Count, $height); $i++) {
            $item = $this.Items[$i]
            $text = "$($item.Name) [$($item.Key)]"
            $line = $this.RenderListItem($i, $text, $width)
            $output.AppendLine($line) | Out-Null
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter) {
            $item = $this.GetSelectedItem()
            if ($item -and $item.Action) {
                & $item.Action
                return $true
            }
        }
        
        return ([LazyGitViewBase]$this).HandleInput($key)
    }
}

class ALCARDetailView : LazyGitViewBase {
    [object]$TaskService
    [object]$ProjectService
    [object]$ViewDefinitionService
    [object]$CurrentItem = $null
    
    ALCARDetailView([object]$taskService, [object]$projectService, [object]$viewDefService) : base("Details", "DTL") {
        $this.TaskService = $taskService
        $this.ProjectService = $projectService
        $this.ViewDefinitionService = $viewDefService
    }
    
    [string] Render([int]$width, [int]$height) {
        if ($this.CurrentItem -eq $null) {
            return "$($this._dimFG)  Select an item to view details$($this._reset)"
        }
        
        $output = [System.Text.StringBuilder]::new(1024)
        $item = $this.CurrentItem
        
        # Determine item type
        $isTask = $item.PSObject.Properties.Name -contains "Status"
        $isProject = $item.PSObject.Properties.Name -contains "Description" -and -not $isTask
        
        if ($isTask) {
            $this.RenderTaskDetails($output, $item, $width, $height)
        } elseif ($isProject) {
            $this.RenderProjectDetails($output, $item, $width, $height)
        } else {
            $output.AppendLine("$($this._normalFG)Item: $($this._reset)$($item.Name)") | Out-Null
        }
        
        return $output.ToString()
    }
    
    [void] RenderTaskDetails([System.Text.StringBuilder]$output, [object]$task, [int]$width, [int]$height) {
        # Task header
        $output.AppendLine("$($this._normalFG)TASK DETAILS$($this._reset)") | Out-Null
        $output.AppendLine() | Out-Null
        
        # Task name
        $output.AppendLine("$($this._normalFG)Name: $($this._reset)$($task.Name)") | Out-Null
        
        # Status with color
        $statusColor = switch ($task.Status) {
            "Completed" { "`e[38;2;100;200;100m" }
            "Active" { "`e[38;2;100;150;250m" }
            "Blocked" { "`e[38;2;250;100;100m" }
            default { $this._normalFG }
        }
        $output.AppendLine("$($this._normalFG)Status: $($this._reset)$statusColor$($task.Status)$($this._reset)") | Out-Null
        
        # Priority with color
        $priorityColor = switch ($task.Priority) {
            "High" { "`e[38;2;250;100;100m" }
            "Low" { "`e[38;2;100;100;200m" }
            default { $this._normalFG }
        }
        $output.AppendLine("$($this._normalFG)Priority: $($this._reset)$priorityColor$($task.Priority)$($this._reset)") | Out-Null
        
        # Project
        if ($task.ProjectId -and $this.ProjectService) {
            $project = $this.ProjectService.GetProject($task.ProjectId)
            if ($project) {
                $output.AppendLine("$($this._normalFG)Project: $($this._reset)$($project.Name)") | Out-Null
            }
        }
        
        # Due date
        if ($task.DueDate) {
            $dueDate = [datetime]$task.DueDate
            $daysUntilDue = ($dueDate.Date - [datetime]::Today).Days
            $dueDateColor = if ($daysUntilDue -lt 0) { "`e[38;2;250;100;100m" }
                           elseif ($daysUntilDue -eq 0) { "`e[38;2;250;200;100m" }
                           else { $this._normalFG }
            
            $dueDateText = $dueDate.ToString("yyyy-MM-dd")
            if ($daysUntilDue -eq 0) { $dueDateText += " (Today)" }
            elseif ($daysUntilDue -eq 1) { $dueDateText += " (Tomorrow)" }
            elseif ($daysUntilDue -lt 0) { $dueDateText += " (Overdue)" }
            
            $output.AppendLine("$($this._normalFG)Due Date: $($this._reset)$dueDateColor$dueDateText$($this._reset)") | Out-Null
        }
        
        # Description
        if ($task.Description) {
            $output.AppendLine() | Out-Null
            $output.AppendLine("$($this._normalFG)Description:$($this._reset)") | Out-Null
            
            # Wrap description text
            $words = $task.Description -split '\s+'
            $line = ""
            foreach ($word in $words) {
                if (($line + " " + $word).Length -gt $width - 2) {
                    $output.AppendLine($line) | Out-Null
                    $line = $word
                } else {
                    $line = if ($line) { "$line $word" } else { $word }
                }
            }
            if ($line) {
                $output.AppendLine($line) | Out-Null
            }
        }
        
        # Progress
        if ($task.Progress -ge 0) {
            $output.AppendLine() | Out-Null
            $progressBar = $this.RenderProgressBar($task.Progress, 20)
            $output.AppendLine("$($this._normalFG)Progress: $($this._reset)$progressBar $($task.Progress)%") | Out-Null
        }
        
        # Actions
        $output.AppendLine() | Out-Null
        $output.AppendLine("$($this._dimFG)Actions:$($this._reset)") | Out-Null
        $output.AppendLine("  Enter - Edit task") | Out-Null
        $output.AppendLine("  Space - Toggle status") | Out-Null
        $output.AppendLine("  d - Delete task") | Out-Null
        $output.AppendLine("  t - Add time entry") | Out-Null
    }
    
    [void] RenderProjectDetails([System.Text.StringBuilder]$output, [object]$project, [int]$width, [int]$height) {
        # Project header
        $output.AppendLine("$($this._normalFG)PROJECT DETAILS$($this._reset)") | Out-Null
        $output.AppendLine() | Out-Null
        
        # Project name
        $output.AppendLine("$($this._normalFG)Name: $($this._reset)$($project.Name)") | Out-Null
        
        # Description
        if ($project.Description) {
            $output.AppendLine("$($this._normalFG)Description: $($this._reset)$($project.Description)") | Out-Null
        }
        
        # Task statistics
        if ($this.TaskService) {
            $tasks = $this.TaskService.GetTasksByProject($project.Id)
            $completedTasks = $tasks | Where-Object { $_.Status -eq "Completed" }
            $activeTasks = $tasks | Where-Object { $_.Status -eq "Active" }
            
            $output.AppendLine() | Out-Null
            $output.AppendLine("$($this._normalFG)Tasks:$($this._reset)") | Out-Null
            $output.AppendLine("  Total: $($tasks.Count)") | Out-Null
            $output.AppendLine("  Active: $($activeTasks.Count)") | Out-Null
            $output.AppendLine("  Completed: $($completedTasks.Count)") | Out-Null
            
            if ($tasks.Count -gt 0) {
                $completionRate = [Math]::Round($completedTasks.Count / $tasks.Count * 100)
                $progressBar = $this.RenderProgressBar($completionRate, 20)
                $output.AppendLine("  Progress: $progressBar $completionRate%") | Out-Null
            }
        }
        
        # Actions
        $output.AppendLine() | Out-Null
        $output.AppendLine("$($this._dimFG)Actions:$($this._reset)") | Out-Null
        $output.AppendLine("  Enter - View tasks") | Out-Null
        $output.AppendLine("  e - Edit project") | Out-Null
        $output.AppendLine("  n - New task in project") | Out-Null
    }
    
    [string] RenderProgressBar([int]$percentage, [int]$width) {
        $filled = [Math]::Floor($width * $percentage / 100)
        $empty = $width - $filled
        
        $bar = "`e[38;2;100;200;100m" # Green
        $bar += "█" * $filled
        $bar += "`e[38;2;60;60;60m" # Dark gray
        $bar += "░" * $empty
        $bar += $this._reset
        
        return $bar
    }
    
    [void] SetSelection([object]$item) {
        $this.CurrentItem = $item
        $this.IsDirty = $true
    }
}

# Command palette implementation moved to EnhancedCommandBar
# Legacy ALCARCommandPalette removed - using EnhancedCommandBar instead
