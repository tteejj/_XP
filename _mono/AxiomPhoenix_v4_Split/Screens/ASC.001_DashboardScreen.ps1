# ==============================================================================
# Axiom-Phoenix v4.0 - All Screens (Load After Components)
# Application screens that extend Screen base class
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASC.###" to find specific sections.
# Each section ends with "END_PAGE: ASC.###"
# ==============================================================================

using namespace System.Collections.Generic

#region Screen Classes

# ==============================================================================
# CLASS: DashboardScreen (Data-Driven Dashboard with DataGridComponent)
#
# INHERITS:
#   - Screen (ABC.006)
#
# DEPENDENCIES:
#   Services:
#     - NavigationService (ASE.004)
#     - FocusManager (ASE.009)
#     - DataManager (ASE.003)
#     - ViewDefinitionService (ASE.011)
#   Components:
#     - Panel (ACO.011)
#     - DataGridComponent (ACO.022)
#     - LabelComponent (ACO.001)
#
# PURPOSE:
#   Data-driven dashboard showing task statistics, recent tasks, and quick actions
#   using the ViewDefinitionService pattern for consistent formatting.
# ==============================================================================
class DashboardScreen : Screen {
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [DataGridComponent] $_statsGrid
    hidden [DataGridComponent] $_recentTasksGrid
    hidden [DataGridComponent] $_navigationGrid
    #endregion

    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}

    [void] Initialize() {
        if (-not $this.ServiceContainer) { return }

        # Main container panel
        $this._mainPanel = [Panel]::new("DashboardPanel")
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Axiom-Phoenix v4.0 Dashboard "
        $this.AddChild($this._mainPanel)

        # ASCII Art Title (smaller)
        $titleArt = @(
            '   ___   _  _  _  ___  __  __   ',
            '  / _ \ | \/ || |/ _ \|  \/  |  ',
            ' | |_| | >  < | | (_) | |\/| |  ',
            ' |_| |_|/_/\_\|_|\___/|_|  |_|  '
        )
        $y = 2
        foreach ($line in $titleArt) {
            $label = [LabelComponent]::new("TitleLine$y")
            $label.Text = $line
            $label.Width = $line.Length
            $label.ForegroundColor = Get-ThemeColor -ColorName "Primary"
            $label.X = [Math]::Floor(($this.Width - $line.Length) / 2)
            $label.Y = $y++
            $this._mainPanel.AddChild($label)
        }
        $y += 1  # Add spacing

        # Calculate layout dimensions
        $leftWidth = [Math]::Floor($this.Width * 0.35)
        $rightWidth = $this.Width - $leftWidth - 3
        $gridHeight = [Math]::Floor(($this.Height - $y - 2) / 2)

        # Task Statistics Grid (top-left)
        $this._statsGrid = [DataGridComponent]::new("StatsGrid")
        $this._statsGrid.X = 1
        $this._statsGrid.Y = $y
        $this._statsGrid.Width = $leftWidth
        $this._statsGrid.Height = $gridHeight
        $this._statsGrid.ShowHeaders = $true
        $this._statsGrid.IsFocusable = $false
        $this._mainPanel.AddChild($this._statsGrid)

        # Recent Tasks Grid (top-right)
        $this._recentTasksGrid = [DataGridComponent]::new("RecentTasksGrid")
        $this._recentTasksGrid.X = $leftWidth + 2
        $this._recentTasksGrid.Y = $y
        $this._recentTasksGrid.Width = $rightWidth
        $this._recentTasksGrid.Height = $gridHeight
        $this._recentTasksGrid.ShowHeaders = $true
        $this._recentTasksGrid.IsFocusable = $false
        $this._mainPanel.AddChild($this._recentTasksGrid)

        # Quick Actions Grid (bottom, centered)
        $actionsY = $y + $gridHeight + 1
        $actionsWidth = [Math]::Floor($this.Width * 0.7)
        $this._navigationGrid = [DataGridComponent]::new("NavigationGrid")
        $this._navigationGrid.X = [Math]::Floor(($this.Width - $actionsWidth) / 2)
        $this._navigationGrid.Y = $actionsY
        $this._navigationGrid.Width = $actionsWidth
        $this._navigationGrid.Height = $this.Height - $actionsY - 2
        $this._navigationGrid.ShowHeaders = $true
        $thisScreen = $this
        $this._navigationGrid.OnSelectionChanged = {
            param($sender, $selectedIndex)
            $item = $sender.GetSelectedItem()
            if ($item -and $item.ContainsKey("ActionKey")) {
                $thisScreen._ExecuteNavigationAction($item.ActionKey)
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._navigationGrid)
    }

    [void] OnEnter() {
        # Load and display data
        $this._RefreshDashboardData()
        
        # Set focus to navigation grid for user interaction
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager -and $this._navigationGrid) {
            $focusManager.SetFocus($this._navigationGrid)
        }
    }

    [void] OnResize([int]$newWidth, [int]$newHeight) {
        ([Screen]$this).OnResize($newWidth, $newHeight)
        
        if ($this._mainPanel) {
            $this._mainPanel.Width = $newWidth
            $this._mainPanel.Height = $newHeight
            
            # Recalculate layout
            $this.Initialize()
        }
    }

    hidden [void] _RefreshDashboardData() {
        $this._UpdateTaskStatistics()
        $this._UpdateRecentTasks()
        $this._UpdateNavigationActions()
    }

    hidden [void] _UpdateTaskStatistics() {
        if (-not $this._statsGrid) { return }

        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        $viewDefService = $this.ServiceContainer?.GetService("ViewDefinitionService")
        
        if (-not $dataManager -or -not $viewDefService) { return }

        # Get view definition
        $viewDef = $viewDefService.GetViewDefinition('dashboard.task.stats')
        $this._statsGrid.SetColumns($viewDef.Columns)

        # Get tasks and calculate statistics
        $allTasks = $dataManager.GetTasks()
        $stats = @()

        # Total tasks
        $stats += @{ Name="Total Tasks"; Count=$allTasks.Count; Type="info" }

        # Tasks by status
        $pendingCount = @($allTasks | Where-Object { $_.Status -eq [TaskStatus]::Pending }).Count
        $inProgressCount = @($allTasks | Where-Object { $_.Status -eq [TaskStatus]::InProgress }).Count
        $completedCount = @($allTasks | Where-Object { $_.Status -eq [TaskStatus]::Completed }).Count
        $cancelledCount = @($allTasks | Where-Object { $_.Status -eq [TaskStatus]::Cancelled }).Count

        $stats += @{ Name="Pending"; Count=$pendingCount; Type="warning" }
        $stats += @{ Name="In Progress"; Count=$inProgressCount; Type="info" }
        $stats += @{ Name="Completed"; Count=$completedCount; Type="success" }
        if ($cancelledCount -gt 0) {
            $stats += @{ Name="Cancelled"; Count=$cancelledCount; Type="error" }
        }

        # High priority tasks
        $highPriorityCount = @($allTasks | Where-Object { $_.Priority -eq [TaskPriority]::High -and $_.Status -ne [TaskStatus]::Completed }).Count
        if ($highPriorityCount -gt 0) {
            $stats += @{ Name="High Priority"; Count=$highPriorityCount; Type="warning" }
        }

        # Transform stats using view definition
        $transformer = $viewDef.Transformer
        $displayItems = @()
        foreach ($stat in $stats) {
            $displayItems += & $transformer $stat
        }

        $this._statsGrid.SetItems($displayItems)
    }

    hidden [void] _UpdateRecentTasks() {
        if (-not $this._recentTasksGrid) { return }

        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        $viewDefService = $this.ServiceContainer?.GetService("ViewDefinitionService")
        
        if (-not $dataManager -or -not $viewDefService) { return }

        # Get view definition
        $viewDef = $viewDefService.GetViewDefinition('dashboard.recent.tasks')
        $this._recentTasksGrid.SetColumns($viewDef.Columns)

        # Get recent tasks (last 8, sorted by creation date)
        $allTasks = $dataManager.GetTasks()
        $recentTasks = @($allTasks | Sort-Object CreatedAt -Descending | Select-Object -First 8)

        if ($recentTasks.Count -eq 0) {
            $this._recentTasksGrid.SetItems(@())
            return
        }

        # Transform tasks using view definition
        $transformer = $viewDef.Transformer
        $displayItems = @()
        foreach ($task in $recentTasks) {
            $displayItems += & $transformer $task
        }

        $this._recentTasksGrid.SetItems($displayItems)
    }

    hidden [void] _UpdateNavigationActions() {
        if (-not $this._navigationGrid) { return }

        $viewDefService = $this.ServiceContainer?.GetService("ViewDefinitionService")
        if (-not $viewDefService) { return }

        # Get view definition
        $viewDef = $viewDefService.GetViewDefinition('dashboard.navigation')
        $this._navigationGrid.SetColumns($viewDef.Columns)

        # Define navigation actions
        $navActions = @(
            @{ Key="T"; Name="Task Management"; Description="View and manage tasks"; ActionKey="tasks" },
            @{ Key="P"; Name="Projects"; Description="Manage projects"; ActionKey="projects" },
            @{ Key="S"; Name="Settings"; Description="Change theme and settings"; ActionKey="settings" },
            @{ Key="Q"; Name="Exit Application"; Description="Quit Axiom-Phoenix"; ActionKey="exit" }
        )

        # Transform nav actions using view definition
        $transformer = $viewDef.Transformer
        $displayItems = @()
        foreach ($action in $navActions) {
            $displayItem = & $transformer $action
            $displayItem.ActionKey = $action.ActionKey  # Add action key for execution
            $displayItems += $displayItem
        }

        $this._navigationGrid.SetItems($displayItems)
    }

    hidden [void] _ExecuteNavigationAction([string]$actionKey) {
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if (-not $navService) { return }

        switch ($actionKey) {
            "tasks" {
                # Tasks screen will be loaded dynamically to avoid circular dependency
                $actionService = $this.ServiceContainer?.GetService("ActionService")
                if ($actionService) {
                    $actionService.ExecuteAction("navigation.taskList")
                }
            }
            "projects" {
                # Future: ProjectListScreen
                Write-Host "Projects feature coming soon!" -ForegroundColor Yellow
            }
            "settings" {
                # Theme picker not available in this version
                Write-Host "Settings feature coming soon!" -ForegroundColor Yellow
            }
            "exit" {
                $global:TuiState.Running = $false
            }
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Handle hotkeys for quick navigation
        switch ($keyInfo.KeyChar.ToString().ToUpper()) {
            "T" {
                $this._ExecuteNavigationAction("tasks")
                return $true
            }
            "P" {
                $this._ExecuteNavigationAction("projects")
                return $true
            }
            "S" {
                $this._ExecuteNavigationAction("settings")
                return $true
            }
            "Q" {
                $this._ExecuteNavigationAction("exit")
                return $true
            }
            default {
                # Let base class handle other keys (like arrow navigation in grid)
                return ([Screen]$this).HandleInput($keyInfo)
            }
        }
        return $false
    }
}

#endregion
#<!-- END_PAGE: ASC.001 -->
