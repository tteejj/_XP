# ==============================================================================
# Axiom-Phoenix v4.0 - Dashboard Screen
# A modern, theme-aware, and event-driven dashboard.
# ==============================================================================

class DashboardScreen : Screen {
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [Panel] $_summaryPanel
    hidden [Panel] $_statusPanel
    hidden [Panel] $_helpPanel
    #endregion

    #region State
    hidden [int] $_totalTasks = 0
    hidden [int] $_completedTasks = 0
    hidden [int] $_pendingTasks = 0
    #endregion

    # Constructor is now minimal, only calling the base.
    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}

    # OnInitialize is the correct lifecycle hook for one-time setup and child component creation.
    [void] OnInitialize() {
        # Get services from the container. These will be used in other methods.
        $dataManager = $this.ServiceContainer.GetService("DataManager")
        
        # Create the main layout panels. The Panel class is now theme-aware and will color itself.
        $this._mainPanel = [Panel]::new(0, 0, $this.Width, $this.Height, "Axiom-Phoenix Dashboard")
        $this.AddChild($this._mainPanel)

        $summaryWidth = [Math]::Floor($this.Width * 0.5)
        $this._summaryPanel = [Panel]::new(1, 1, $summaryWidth, 12, "Task Summary")
        $this._mainPanel.AddChild($this._summaryPanel)

        $helpX = $summaryWidth + 2
        $helpWidth = $this.Width - $helpX - 1
        $this._helpPanel = [Panel]::new($helpX, 1, $helpWidth, 12, "Quick Start")
        $this._mainPanel.AddChild($this._helpPanel)

        $this._statusPanel = [Panel]::new(1, 14, $this.Width - 2, $this.Height - 15, "System Status")
        $this._mainPanel.AddChild($this._statusPanel)
        
        # Subscribe to data changes. The base Screen.Cleanup() method will handle unsubscription automatically.
        $this.SubscribeToEvent("Tasks.Changed", {
            param($EventData)
            Write-Log -Level Debug "DashboardScreen detected Tasks.Changed event. Refreshing data."
            $this._RefreshData($dataManager)
        })
    }

    # OnEnter is called every time the screen becomes active. Good for refreshing data.
    [void] OnEnter() {
        $dataManager = $this.ServiceContainer.GetService("DataManager")
        $this._RefreshData($dataManager)
        # Set focus to the main panel, allowing for potential future keyboard interactions.
        Set-ComponentFocus -Component $this._mainPanel
    }

    # Fetches the latest data and triggers a display update.
    hidden [void] _RefreshData([object]$dataManager) {
        if(-not $dataManager) {
            Write-Log -Level Warning -Message "DashboardScreen: DataManager service not found."
            return
        }
        $allTasks = $dataManager.GetTasks()
        $this._totalTasks = $allTasks.Count
        $this._completedTasks = ($allTasks | Where-Object { $_.Completed }).Count
        $this._pendingTasks = $this._totalTasks - $this._completedTasks
        
        $this._UpdateDisplay()
    }
    
    # Orchestrates updating all the child panels with the new data.
    hidden [void] _UpdateDisplay() {
        $this._UpdateSummaryPanel()
        $this._UpdateHelpPanel()
        $this._UpdateStatusPanel()
        $this.RequestRedraw()
    }
    
    # Updates the content of the summary panel using themed colors.
    hidden [void] _UpdateSummaryPanel() {
        $panel = $this._summaryPanel
        $theme = $this.ServiceContainer.GetService('ThemeManager')
        $panel.ClearContent()

        $panel.WriteToBuffer(1, 0, "Task Overview", $theme.GetColor('text.header'))
        $panel.WriteToBuffer(1, 1, ('─' * ($panel.ContentWidth-2)), $theme.GetColor('subtle'))
        
        $panel.WriteToBuffer(1, 3, "Total Tasks:    $($this._totalTasks)", $theme.GetColor('text.normal'))
        $panel.WriteToBuffer(1, 4, "Completed:      $($this._completedTasks)", $theme.GetColor('text.normal'))
        $panel.WriteToBuffer(1, 5, "Pending:        $($this._pendingTasks)", $theme.GetColor('text.normal'))
        
        $progress = $this._GetProgressBar()
        $panel.WriteToBuffer(1, 7, "Overall Progress:", $theme.GetColor('text.normal'))
        $panel.WriteToBuffer(1, 8, $progress, $theme.GetColor('text.highlight'))
    }

    # Updates the help panel to guide users to the new Command Palette.
    hidden [void] _UpdateHelpPanel() {
        $panel = $this._helpPanel
        $theme = $this.ServiceContainer.GetService('ThemeManager')
        $actionService = $this.ServiceContainer.GetService('ActionService')
        $panel.ClearContent()
        
        # Get the hotkey for the command palette from the ActionService definition
        $paletteAction = $actionService.GetAction("app.showCommandPalette")
        $paletteHotkey = $paletteAction.Hotkey ?? "Ctrl+P" # Fallback just in case
        
        $panel.WriteToBuffer(1, 0, "Welcome to Axiom-Phoenix!", $theme.GetColor('text.header'))
        $panel.WriteToBuffer(1, 1, ('─' * ($panel.ContentWidth-2)), $theme.GetColor('subtle'))
        
        $panel.WriteToBuffer(1, 3, "Press ", $theme.GetColor('text.normal'))
        $panel.WriteToBuffer(7, 3, $paletteHotkey, $theme.GetColor('text.hotkey'))
        $panel.WriteToBuffer(7 + $paletteHotkey.Length, 3, " to open the", $theme.GetColor('text.normal'))
        $panel.WriteToBuffer(1, 4, "Command Palette.", $theme.GetColor('text.normal'))

        $panel.WriteToBuffer(1, 6, "All navigation and actions are", $theme.GetColor('text.subtle'))
        $panel.WriteToBuffer(1, 7, "now available from there.", $theme.GetColor('text.subtle'))
    }
    
    # Updates the status panel with system info.
    hidden [void] _UpdateStatusPanel() {
        $panel = $this._statusPanel
        $theme = $this.ServiceContainer.GetService('ThemeManager')
        $panel.ClearContent()

        $process = Get-Process -Id $global:PID
        $memoryMB = [Math]::Round($process.WorkingSet64 / 1MB, 2)

        $panel.WriteToBuffer(1, 0, "System Information", $theme.GetColor('text.header'))
        $panel.WriteToBuffer(1, 1, ('─' * ($panel.ContentWidth-2)), $theme.GetColor('subtle'))
        $panel.WriteToBuffer(1, 3, "PowerShell Version: $($global:PSVersionTable.PSVersion)", $theme.GetColor('text.normal'))
        $panel.WriteToBuffer(1, 4, "Platform:           $($global:PSVersionTable.Platform)", $theme.GetColor('text.normal'))
        $panel.WriteToBuffer(1, 5, "Memory Usage:       $($memoryMB) MB", $theme.GetColor('text.normal'))
    }

    # Helper to generate the progress bar string.
    hidden [string] _GetProgressBar() {
        if ($this._totalTasks -eq 0) { return "No tasks defined." }
        $percentage = [Math]::Round(($this._completedTasks / $this._totalTasks) * 100)
        $barLength = $this._summaryPanel.ContentWidth - 6
        if($barLength -lt 1) { $barLength = 1 }
        $filledLength = [Math]::Floor(($percentage / 100) * $barLength)
        $bar = '█' * $filledLength + '░' * ($barLength - $filledLength)
        return "[$bar] $percentage%"
    }

    # Screen-level input is now minimal. Most actions are in the Command Palette.
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($keyInfo.Key -eq [ConsoleKey]::F5) {
            $this._RefreshData($this.ServiceContainer.GetService("DataManager"))
            return $true # Input was handled
        }
        return $false # Input not handled, let the engine process it (e.g., for global hotkeys)
    }
}