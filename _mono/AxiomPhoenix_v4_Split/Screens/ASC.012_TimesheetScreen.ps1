# ==============================================================================
# Axiom-Phoenix v4.0 - TimesheetScreen
# Weekly timesheet view with navigation and reporting
# ==============================================================================

class TimesheetScreen : Screen {
    # Services
    hidden $_navService
    hidden $_dataManager
    hidden $_dialogManager
    hidden $_timeSheetService
    hidden $_eventManager
    
    # UI Components
    hidden [Panel]$_mainPanel
    hidden [Panel]$_headerPanel
    hidden [LabelComponent]$_titleLabel
    hidden [LabelComponent]$_weekLabel
    hidden [ButtonComponent]$_prevWeekButton
    hidden [ButtonComponent]$_nextWeekButton
    hidden [ButtonComponent]$_currentWeekButton
    hidden [ButtonComponent]$_addEntryButton
    hidden [ButtonComponent]$_exportButton
    hidden [Table]$_timesheetTable
    hidden [LabelComponent]$_statusLabel
    hidden [LabelComponent]$_totalHoursLabel
    
    # State
    hidden [DateTime]$_currentWeekStart
    hidden [hashtable]$_currentReport
    
    TimesheetScreen([object]$serviceContainer) : base("TimesheetScreen", $serviceContainer) {
        # Get services
        $this._navService = $serviceContainer.GetService("NavigationService")
        $this._dataManager = $serviceContainer.GetService("DataManager")
        $this._dialogManager = $serviceContainer.GetService("DialogManager")
        $this._timeSheetService = $serviceContainer.GetService("TimeSheetService")
        $this._eventManager = $serviceContainer.GetService("EventManager")
        
        # Initialize to current week
        $this._currentWeekStart = $this._timeSheetService.GetWeekStartDate([DateTime]::Now)
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
        $this.AddChild($this._mainPanel)
        
        # Header panel
        $this._headerPanel = [Panel]::new("HeaderPanel")
        $this._headerPanel.Width = $this._mainPanel.Width - 2
        $this._headerPanel.Height = 5
        $this._headerPanel.X = 1
        $this._headerPanel.Y = 1
        $this._headerPanel.HasBorder = $false
        $this._headerPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.AddChild($this._headerPanel)
        
        # Title
        $this._titleLabel = [LabelComponent]::new("TitleLabel")
        $this._titleLabel.Text = "Weekly Timesheet"
        $this._titleLabel.X = 2
        $this._titleLabel.Y = 0
        $this._titleLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._headerPanel.AddChild($this._titleLabel)
        
        # Week label
        $this._weekLabel = [LabelComponent]::new("WeekLabel")
        $this._weekLabel.X = 2
        $this._weekLabel.Y = 2
        $this._weekLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._headerPanel.AddChild($this._weekLabel)
        
        # Navigation buttons
        $buttonY = 3
        $buttonSpacing = 2
        
        # Previous week button
        $this._prevWeekButton = [ButtonComponent]::new("PrevWeekButton")
        $this._prevWeekButton.Text = "< Previous"
        $this._prevWeekButton.X = 2
        $this._prevWeekButton.Y = $buttonY
        $this._prevWeekButton.Width = 12
        $this._prevWeekButton.Height = 1
        $this._prevWeekButton.IsFocusable = $true
        $this._prevWeekButton.TabIndex = 0
        $currentScreenRef = $this
        $this._prevWeekButton.OnClick = {
            $currentScreenRef._NavigateToPreviousWeek()
        }.GetNewClosure()
        $this._headerPanel.AddChild($this._prevWeekButton)
        
        # Current week button
        $this._currentWeekButton = [ButtonComponent]::new("CurrentWeekButton")
        $this._currentWeekButton.Text = "Current Week"
        $this._currentWeekButton.X = $this._prevWeekButton.X + $this._prevWeekButton.Width + $buttonSpacing
        $this._currentWeekButton.Y = $buttonY
        $this._currentWeekButton.Width = 14
        $this._currentWeekButton.Height = 1
        $this._currentWeekButton.IsFocusable = $true
        $this._currentWeekButton.TabIndex = 1
        $this._currentWeekButton.OnClick = {
            $currentScreenRef._NavigateToCurrentWeek()
        }.GetNewClosure()
        $this._headerPanel.AddChild($this._currentWeekButton)
        
        # Next week button
        $this._nextWeekButton = [ButtonComponent]::new("NextWeekButton")
        $this._nextWeekButton.Text = "Next >"
        $this._nextWeekButton.X = $this._currentWeekButton.X + $this._currentWeekButton.Width + $buttonSpacing
        $this._nextWeekButton.Y = $buttonY
        $this._nextWeekButton.Width = 10
        $this._nextWeekButton.Height = 1
        $this._nextWeekButton.IsFocusable = $true
        $this._nextWeekButton.TabIndex = 2
        $this._nextWeekButton.OnClick = {
            $currentScreenRef._NavigateToNextWeek()
        }.GetNewClosure()
        $this._headerPanel.AddChild($this._nextWeekButton)
        
        # Export button
        $this._exportButton = [ButtonComponent]::new("ExportButton")
        $this._exportButton.Text = "[E]xport CSV"
        $this._exportButton.X = $this._headerPanel.Width - 30
        $this._exportButton.Y = $buttonY
        $this._exportButton.Width = 13
        $this._exportButton.Height = 1
        $this._exportButton.IsFocusable = $true
        $this._exportButton.TabIndex = 3
        $this._exportButton.OnClick = {
            $currentScreenRef._ExportTimesheetToClipboard()
        }.GetNewClosure()
        $this._headerPanel.AddChild($this._exportButton)
        
        # Add entry button
        $this._addEntryButton = [ButtonComponent]::new("AddEntryButton")
        $this._addEntryButton.Text = "[A]dd Entry"
        $this._addEntryButton.X = $this._headerPanel.Width - 15
        $this._addEntryButton.Y = $buttonY
        $this._addEntryButton.Width = 13
        $this._addEntryButton.Height = 1
        $this._addEntryButton.IsFocusable = $true
        $this._addEntryButton.TabIndex = 4
        $this._addEntryButton.BackgroundColor = Get-ThemeColor "button.primary.background"
        $this._addEntryButton.ForegroundColor = Get-ThemeColor "button.primary.foreground"
        $this._addEntryButton.OnClick = {
            $currentScreenRef._ShowAddEntryDialog()
        }.GetNewClosure()
        $this._headerPanel.AddChild($this._addEntryButton)
        
        # Timesheet table
        $this._timesheetTable = [Table]::new("TimesheetTable")
        $this._timesheetTable.X = 1
        $this._timesheetTable.Y = $this._headerPanel.Y + $this._headerPanel.Height + 1
        $this._timesheetTable.Width = $this._mainPanel.Width - 2
        $this._timesheetTable.Height = $this._mainPanel.Height - $this._timesheetTable.Y - 4
        $this._timesheetTable.ShowBorder = $true
        $this._timesheetTable.IsFocusable = $true
        $this._timesheetTable.TabIndex = 5
        $this._timesheetTable.BackgroundColor = Get-ThemeColor "table.background"
        $this._timesheetTable.BorderColor = Get-ThemeColor "table.border"
        
        # Configure table columns
        $this._timesheetTable.Columns = @(
            @{ Name = "Project"; Width = 20; Align = "Left" }
            @{ Name = "Monday"; Width = 8; Align = "Right" }
            @{ Name = "Tuesday"; Width = 8; Align = "Right" }
            @{ Name = "Wednesday"; Width = 8; Align = "Right" }
            @{ Name = "Thursday"; Width = 8; Align = "Right" }
            @{ Name = "Friday"; Width = 8; Align = "Right" }
            @{ Name = "Saturday"; Width = 8; Align = "Right" }
            @{ Name = "Sunday"; Width = 8; Align = "Right" }
            @{ Name = "Total"; Width = 10; Align = "Right" }
        )
        
        $this._mainPanel.AddChild($this._timesheetTable)
        
        # Status label
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.X = 2
        $this._statusLabel.Y = $this._mainPanel.Height - 2
        $this._statusLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._mainPanel.AddChild($this._statusLabel)
        
        # Total hours label
        $this._totalHoursLabel = [LabelComponent]::new("TotalHoursLabel")
        $this._totalHoursLabel.X = $this._mainPanel.Width - 30
        $this._totalHoursLabel.Y = $this._mainPanel.Height - 2
        $this._totalHoursLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._mainPanel.AddChild($this._totalHoursLabel)
        
        # Load initial data
        $this._RefreshTimesheet()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        $focused = $this.GetFocusedChild()
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                if ($this._navService.CanGoBack()) {
                    $this._navService.GoBack()
                    return $true
                }
            }
            ([ConsoleKey]::F5) {
                $this._RefreshTimesheet()
                return $true
            }
        }
        
        # Handle keyboard shortcuts
        switch ($keyInfo.KeyChar) {
            'a' { $this._ShowAddEntryDialog(); return $true }
            'A' { $this._ShowAddEntryDialog(); return $true }
            'e' { $this._ExportTimesheetToClipboard(); return $true }
            'E' { $this._ExportTimesheetToClipboard(); return $true }
            '<' { $this._NavigateToPreviousWeek(); return $true }
            '>' { $this._NavigateToNextWeek(); return $true }
        }
        
        return ([Screen]$this).HandleInput($keyInfo)
    }
    
    hidden [void] _RefreshTimesheet() {
        try {
            # Update week label
            $weekEnd = $this._currentWeekStart.AddDays(6)
            $this._weekLabel.Text = "Week of $($this._currentWeekStart.ToString('MMM dd, yyyy')) - $($weekEnd.ToString('MMM dd, yyyy'))"
            
            # Generate report
            $tableData = $this._timeSheetService.GenerateWeeklyReportTable($this._currentWeekStart)
            $this._currentReport = $this._timeSheetService.GenerateWeeklyReport($this._currentWeekStart)
            
            # Update table
            $this._timesheetTable.Data = $tableData
            
            # Update totals
            $totalHours = $this._currentReport.TotalHours
            $billableHours = $this._currentReport.TotalBillableHours
            $this._totalHoursLabel.Text = "Total: {0:N2}h (Billable: {1:N2}h)" -f $totalHours, $billableHours
            
            # Update status
            $entryCount = $this._currentReport.Entries.Count
            if ($entryCount -eq 0) {
                $this._statusLabel.Text = "No time entries for this week"
            } else {
                $this._statusLabel.Text = "$entryCount time entries"
            }
            
            $this.RequestRedraw()
        }
        catch {
            Write-Log -Level Error -Message "Failed to refresh timesheet: $_"
            $this._statusLabel.Text = "Error loading timesheet data"
            $this.RequestRedraw()
        }
    }
    
    hidden [void] _NavigateToPreviousWeek() {
        $this._currentWeekStart = $this._currentWeekStart.AddDays(-7)
        $this._RefreshTimesheet()
    }
    
    hidden [void] _NavigateToNextWeek() {
        $this._currentWeekStart = $this._currentWeekStart.AddDays(7)
        $this._RefreshTimesheet()
    }
    
    hidden [void] _NavigateToCurrentWeek() {
        $this._currentWeekStart = $this._timeSheetService.GetWeekStartDate([DateTime]::Now)
        $this._RefreshTimesheet()
    }
    
    hidden [void] _ShowAddEntryDialog() {
        $dialog = New-Object TimeEntryDialog -ArgumentList $this.ServiceContainer
        $dialog.Initialize()
        $this._navService.NavigateTo($dialog)
    }
    
    hidden [void] _ExportTimesheetToClipboard() {
        try {
            $weekEnd = $this._currentWeekStart.AddDays(6)
            $success = $this._timeSheetService.ExportToClipboard($this._currentWeekStart, $weekEnd, "Weekly")
            
            if ($success) {
                $this._statusLabel.Text = "Weekly timesheet exported to clipboard (CSV format)"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "status.success"
            } else {
                $this._statusLabel.Text = "Failed to export timesheet to clipboard"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "status.error"
            }
            
            $this.RequestRedraw()
        }
        catch {
            Write-Log -Level Error -Message "Export to clipboard failed: $_"
            $this._statusLabel.Text = "Export failed: $($_.Exception.Message)"
            $this._statusLabel.ForegroundColor = Get-ThemeColor "status.error"
            $this.RequestRedraw()
        }
    }
    
    [void] OnEnter() {
        # Subscribe to data change events
        $currentRef = $this
        $this.SubscribeToEvent("TimeEntries.Changed", {
            param($sender, $data)
            $currentRef._RefreshTimesheet()
        }.GetNewClosure())
        
        # Refresh data
        $this._RefreshTimesheet()
        
        # Call base to set initial focus
        ([Screen]$this).OnEnter()
    }
    
    [void] OnExit() {
        # Base class handles event unsubscription
        ([Screen]$this).OnExit()
    }
}