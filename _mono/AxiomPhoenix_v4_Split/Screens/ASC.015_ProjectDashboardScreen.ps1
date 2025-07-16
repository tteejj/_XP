# ==============================================================================
# Axiom-Phoenix v4.0 - ProjectDashboardScreen
# Enhanced dashboard with project overview, status indicators, and latest todos
# ==============================================================================

class ProjectDashboardScreen : Screen {
    # Services
    hidden $_navService
    hidden $_dataManager
    hidden $_dialogManager
    hidden $_timeSheetService
    
    # UI Components
    hidden [Panel]$_mainPanel
    hidden [Panel]$_headerPanel
    hidden [LabelComponent]$_titleLabel
    hidden [LabelComponent]$_summaryLabel
    hidden [Table]$_projectsTable
    hidden [Panel]$_actionsPanel
    hidden [LabelComponent]$_actionsLabel
    hidden [LabelComponent]$_instructionsLabel
    
    # State
    hidden [array]$_activeProjects = @()
    
    # Event subscriptions
    hidden [string]$_projectChangeSubscriptionId = $null
    hidden [string]$_taskChangeSubscriptionId = $null
    
    ProjectDashboardScreen([object]$serviceContainer) : base("ProjectDashboardScreen", $serviceContainer) {
        $this._navService = $serviceContainer.GetService("NavigationService")
        $this._dataManager = $serviceContainer.GetService("DataManager")
        $this._dialogManager = $serviceContainer.GetService("DialogManager")
        $this._timeSheetService = $serviceContainer.GetService("TimeSheetService")
    }
    
    [void] Initialize() {
        # Main panel
        $this._mainPanel = [Panel]::new("MainPanel")
        $this._mainPanel.Width = $this.Width - 4
        $this._mainPanel.Height = $this.Height - 4
        $this._mainPanel.X = 2
        $this._mainPanel.Y = 2
        $this._mainPanel.HasBorder = $true
        $this._mainPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.BorderColor = Get-ThemeColor "panel.border"
        $this._mainPanel.Title = " Project Management Dashboard "
        $this.AddChild($this._mainPanel)
        
        # Header panel
        $this._headerPanel = [Panel]::new("HeaderPanel")
        $this._headerPanel.Width = $this._mainPanel.Width - 2
        $this._headerPanel.Height = 4
        $this._headerPanel.X = 1
        $this._headerPanel.Y = 1
        $this._headerPanel.HasBorder = $false
        $this._headerPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.AddChild($this._headerPanel)
        
        # Title
        $this._titleLabel = [LabelComponent]::new("TitleLabel")
        $this._titleLabel.Text = "Active Projects Overview"
        $this._titleLabel.X = 2
        $this._titleLabel.Y = 0
        $this._titleLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._headerPanel.AddChild($this._titleLabel)
        
        # Summary
        $this._summaryLabel = [LabelComponent]::new("SummaryLabel")
        $this._summaryLabel.X = 2
        $this._summaryLabel.Y = 2
        $this._summaryLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._headerPanel.AddChild($this._summaryLabel)
        
        # Projects table
        $this._projectsTable = [Table]::new("ProjectsTable")
        $this._projectsTable.X = 1
        $this._projectsTable.Y = $this._headerPanel.Y + $this._headerPanel.Height + 1
        $this._projectsTable.Width = $this._mainPanel.Width - 2
        $this._projectsTable.Height = $this._mainPanel.Height - $this._projectsTable.Y - 8
        $this._projectsTable.ShowBorder = $true
        $this._projectsTable.IsFocusable = $true
        $this._projectsTable.TabIndex = 0
        $this._projectsTable.BackgroundColor = Get-ThemeColor "table.background"
        $this._projectsTable.BorderColor = Get-ThemeColor "table.border"
        
        # Configure table columns
        $this._projectsTable.Columns = @(
            @{ Name = "#"; Width = 3; Align = "Right" }
            @{ Name = "Status"; Width = 8; Align = "Center" }
            @{ Name = "ID2"; Width = 12; Align = "Left" }
            @{ Name = "Project Name"; Width = 25; Align = "Left" }
            @{ Name = "Contact"; Width = 15; Align = "Left" }
            @{ Name = "BF Date"; Width = 10; Align = "Center" }
            @{ Name = "Hours"; Width = 6; Align = "Right" }
            @{ Name = "Latest Todo"; Width = 20; Align = "Left" }
        )
        
        $this._mainPanel.AddChild($this._projectsTable)
        
        # Actions panel
        $this._actionsPanel = [Panel]::new("ActionsPanel")
        $this._actionsPanel.X = 1
        $this._actionsPanel.Y = $this._mainPanel.Height - 6
        $this._actionsPanel.Width = $this._mainPanel.Width - 2
        $this._actionsPanel.Height = 5
        $this._actionsPanel.HasBorder = $false
        $this._actionsPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.AddChild($this._actionsPanel)
        
        # Actions label
        $this._actionsLabel = [LabelComponent]::new("ActionsLabel")
        $this._actionsLabel.Text = "Quick Actions:"
        $this._actionsLabel.X = 2
        $this._actionsLabel.Y = 0
        $this._actionsLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._actionsPanel.AddChild($this._actionsLabel)
        
        # Instructions
        $this._instructionsLabel = [LabelComponent]::new("InstructionsLabel")
        $this._instructionsLabel.Text = "Enter: View Details | N: New Project | T: Timesheet | C: Commands | M: Main Menu | Q: Quit"
        $this._instructionsLabel.X = 2
        $this._instructionsLabel.Y = 3
        $this._instructionsLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._actionsPanel.AddChild($this._instructionsLabel)
        
        # Load initial data
        $this._RefreshDashboard()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        $focused = $this.GetFocusedChild()
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                if ($focused -eq $this._projectsTable -and $this._projectsTable.SelectedIndex -ge 0) {
                    $this._ShowProjectDetails()
                    return $true
                }
            }
            ([ConsoleKey]::Escape) {
                # Go to main menu
                $this._ShowMainMenu()
                return $true
            }
            ([ConsoleKey]::F5) {
                $this._RefreshDashboard()
                return $true
            }
        }
        
        # Handle keyboard shortcuts
        switch ($keyInfo.KeyChar) {
            'n' { $this._CreateNewProject(); return $true }
            'N' { $this._CreateNewProject(); return $true }
            't' { $this._ShowTimesheet(); return $true }
            'T' { $this._ShowTimesheet(); return $true }
            'c' { $this._ShowCommands(); return $true }
            'C' { $this._ShowCommands(); return $true }
            'm' { $this._ShowMainMenu(); return $true }
            'M' { $this._ShowMainMenu(); return $true }
            'q' { $this._QuitApplication(); return $true }
            'Q' { $this._QuitApplication(); return $true }
        }
        
        return ([Screen]$this).HandleInput($keyInfo)
    }
    
    hidden [void] _RefreshDashboard() {
        try {
            # Get active projects
            $allProjects = $this._dataManager.GetProjects()
            $this._activeProjects = @($allProjects | Where-Object { $_.IsActive })
            
            # Update summary
            $totalProjects = $allProjects.Count
            $activeCount = $this._activeProjects.Count
            $completedCount = $totalProjects - $activeCount
            $this._summaryLabel.Text = "Active: $activeCount | Completed: $completedCount | Total: $totalProjects"
            
            # Prepare table data
            $tableData = @()
            $rowIndex = 1
            
            # Sort projects by BF date (overdue first, then by date)
            $sortedProjects = $this._activeProjects | Sort-Object -Property @(
                @{ Expression = { $this._IsOverdue($_) }; Descending = $true }
                @{ Expression = { $this._GetBFDateForSort($_) }; Ascending = $true }
            )
            
            foreach ($project in $sortedProjects) {
                # Get status indicator
                $statusIcon = $this._GetProjectStatusIcon($project)
                
                # Get latest todo
                $latestTodo = $this._GetLatestTodoText($project)
                
                # Get project hours (last 30 days)
                $thirtyDaysAgo = [DateTime]::Now.AddDays(-30)
                $projectHours = 0
                try {
                    $timeEntries = $this._dataManager.GetTimeEntriesByProject($project.Key)
                    $recentEntries = $timeEntries | Where-Object { $_.StartTime -ge $thirtyDaysAgo }
                    $projectHours = ($recentEntries | ForEach-Object { $_.GetHours() } | Measure-Object -Sum).Sum
                    if ($null -eq $projectHours) { $projectHours = 0 }
                }
                catch {
                    $projectHours = 0
                }
                
                # Format BF date
                $bfDateDisplay = if ($project.BFDate) {
                    $project.BFDate.ToString("MM/dd/yy")
                } else {
                    "-"
                }
                
                # Truncate long names
                $projectName = $project.Name
                if ($projectName.Length -gt 23) {
                    $projectName = $projectName.Substring(0, 20) + "..."
                }
                
                $contact = $project.Contact
                if ($contact -and $contact.Length -gt 13) {
                    $contact = $contact.Substring(0, 10) + "..."
                }
                
                $tableData += ,@(
                    $rowIndex.ToString(),
                    $statusIcon,
                    $project.ID2,
                    $projectName,
                    $contact,
                    $bfDateDisplay,
                    "{0:N1}" -f $projectHours,
                    $latestTodo
                )
                
                $rowIndex++
            }
            
            # Update table
            $this._projectsTable.SetItems($tableData)
            
            $this.RequestRedraw()
        }
        catch {
            Write-Log -Level Error -Message "Failed to refresh dashboard: $_"
            $this._summaryLabel.Text = "Error loading projects"
            $this.RequestRedraw()
        }
    }
    
    hidden [string] _GetProjectStatusIcon([object]$project) {
        # Check if overdue
        if ($this._IsOverdue($project)) {
            return "🔴 LATE"
        }
        
        # Check if due soon (within 7 days)
        if ($project.BFDate) {
            $daysUntilDue = ($project.BFDate - [DateTime]::Now).TotalDays
            if ($daysUntilDue -le 7 -and $daysUntilDue -ge 0) {
                return "🟡 SOON"
            }
        }
        
        # Check if has recent activity (time entries in last 7 days)
        try {
            $sevenDaysAgo = [DateTime]::Now.AddDays(-7)
            $recentEntries = $this._dataManager.GetTimeEntriesByProject($project.Key) | 
                Where-Object { $_.StartTime -ge $sevenDaysAgo }
            if ($recentEntries.Count -gt 0) {
                return "🟢 ACTV"
            }
        }
        catch { }
        
        return "⚪ IDLE"
    }
    
    hidden [bool] _IsOverdue([object]$project) {
        if (-not $project.BFDate) { return $false }
        return $project.BFDate.Date -lt [DateTime]::Now.Date
    }
    
    hidden [DateTime] _GetBFDateForSort([object]$project) {
        if ($project.BFDate) {
            return $project.BFDate
        }
        return [DateTime]::MaxValue
    }
    
    hidden [string] _GetLatestTodoText([object]$project) {
        try {
            # Get all tasks for this project
            $tasks = $this._dataManager.GetTasksByProject($project.Key)
            if ($tasks.Count -eq 0) {
                return "No tasks"
            }
            
            # Find the most recent pending task
            $pendingTasks = $tasks | Where-Object { $_.Status -eq [TaskStatus]::Pending }
            if ($pendingTasks.Count -eq 0) {
                return "No pending"
            }
            
            $latestTask = $pendingTasks | Sort-Object CreatedAt -Descending | Select-Object -First 1
            $taskText = $latestTask.Title
            
            # Truncate if too long
            if ($taskText.Length -gt 18) {
                $taskText = $taskText.Substring(0, 15) + "..."
            }
            
            return $taskText
        }
        catch {
            return "Error"
        }
    }
    
    hidden [void] _ShowProjectDetails() {
        if ($this._projectsTable.SelectedIndex -ge 0 -and $this._projectsTable.SelectedIndex -lt $this._activeProjects.Count) {
            $selectedProject = $this._activeProjects[$this._projectsTable.SelectedIndex]
            
            # Navigate to comprehensive ProjectDetailScreen
            $projectDetailScreen = New-Object ProjectDetailScreen -ArgumentList $this.ServiceContainer, $selectedProject
            $projectDetailScreen.Initialize()
            $this._navService.NavigateTo($projectDetailScreen)
        }
    }
    
    hidden [void] _CreateNewProject() {
        # Navigate to new project creation using ProjectDetailScreen
        $newProjectScreen = New-Object ProjectDetailScreen -ArgumentList $this.ServiceContainer, $null
        $newProjectScreen.Initialize()
        $this._navService.NavigateTo($newProjectScreen)
    }
    
    hidden [void] _ShowTimesheet() {
        $timesheetScreen = New-Object TimesheetScreen -ArgumentList $this.ServiceContainer
        $timesheetScreen.Initialize()
        $this._navService.NavigateTo($timesheetScreen)
    }
    
    hidden [void] _ShowCommands() {
        $commandScreen = New-Object CommandPaletteScreen -ArgumentList $this.ServiceContainer
        $commandScreen.Initialize()
        $this._navService.NavigateTo($commandScreen)
    }
    
    hidden [void] _ShowMainMenu() {
        $dashboardScreen = New-Object DashboardScreen -ArgumentList $this.ServiceContainer
        $dashboardScreen.Initialize()
        $this._navService.NavigateTo($dashboardScreen)
    }
    
    hidden [void] _QuitApplication() {
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if ($actionService) {
            $actionService.ExecuteAction("app.exit", @{})
        }
    }
    
    [void] OnEnter() {
        # Subscribe to data change events
        $currentRef = $this
        $this.SubscribeToEvent("Projects.Changed", {
            param($sender, $data)
            $currentRef._RefreshDashboard()
        }.GetNewClosure())
        
        $this.SubscribeToEvent("Tasks.Changed", {
            param($sender, $data)
            $currentRef._RefreshDashboard()
        }.GetNewClosure())
        
        $this.SubscribeToEvent("TimeEntries.Changed", {
            param($sender, $data)
            $currentRef._RefreshDashboard()
        }.GetNewClosure())
        
        # Refresh data
        $this._RefreshDashboard()
        
        # Call base to set initial focus
        ([Screen]$this).OnEnter()
    }
    
    [void] OnExit() {
        # Unsubscribe from events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            if ($this._projectChangeSubscriptionId) {
                $eventManager.Unsubscribe("Projects.Changed", $this._projectChangeSubscriptionId)
                $this._projectChangeSubscriptionId = $null
            }
            if ($this._taskChangeSubscriptionId) {
                $eventManager.Unsubscribe("Tasks.Changed", $this._taskChangeSubscriptionId)
                $this._taskChangeSubscriptionId = $null
            }
        }
        
        # Base class handles event unsubscription
        ([Screen]$this).OnExit()
    }
}