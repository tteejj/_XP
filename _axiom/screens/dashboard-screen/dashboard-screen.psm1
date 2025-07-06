# ==============================================================================
# Axiom-Phoenix v4.0 - Dashboard Screen
# A modern, theme-aware, and event-driven dashboard.
# ==============================================================================

#using module ui-classes
#using module panels-class
#using module theme-manager
#using module logger

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

    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}

    [void] Initialize() {
        if (-not $this.ServiceContainer) {
            Write-Warning "DashboardScreen.Initialize: ServiceContainer is null"
            return
        }
        
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
        
        if ($this.PSObject.Methods['SubscribeToEvent']) {
            $this.SubscribeToEvent("Tasks.Changed", {
                param($EventData)
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Debug "DashboardScreen detected Tasks.Changed event. Refreshing data."
                }
                if ($this.ServiceContainer) {
                    $this._RefreshData($this.ServiceContainer.GetService("DataManager"))
                }
            })
        }
    }

    [void] OnEnter() {
        Write-Verbose "DashboardScreen: OnEnter called"
        
        # Force a complete redraw of all panels
        if ($this._summaryPanel) { $this._summaryPanel.RequestRedraw() }
        if ($this._helpPanel) { $this._helpPanel.RequestRedraw() }
        if ($this._statusPanel) { $this._statusPanel.RequestRedraw() }
        if ($this._mainPanel) { $this._mainPanel.RequestRedraw() }
        
        if ($this.ServiceContainer) {
            $this._RefreshData($this.ServiceContainer.GetService("DataManager"))
        } else {
            Write-Warning "DashboardScreen.OnEnter: ServiceContainer is null, using defaults"
            $this._RefreshData($null)
        }
        
        # Force another redraw after data refresh
        $this.RequestRedraw()
        
        if ($this._mainPanel -and (Get-Command Set-ComponentFocus -ErrorAction SilentlyContinue)) {
            Set-ComponentFocus -Component $this._mainPanel
        }
    }

    hidden [void] _RefreshData([object]$dataManager) {
        if(-not $dataManager) {
            Write-Warning "DashboardScreen: DataManager service not found."
            $this._totalTasks = 0
            $this._completedTasks = 0
            $this._pendingTasks = 0
        } else {
            $allTasks = $dataManager.GetTasks()
            $this._totalTasks = $allTasks.Count
            $this._completedTasks = ($allTasks | Where-Object { $_.Completed }).Count
            $this._pendingTasks = $this._totalTasks - $this._completedTasks
        }
        $this._UpdateDisplay()
    }
    
    hidden [void] _UpdateDisplay() {
        $this._UpdateSummaryPanel()
        $this._UpdateHelpPanel()
        $this._UpdateStatusPanel()
        $this.RequestRedraw()
    }
    
    hidden [void] _UpdateSummaryPanel() {
        $panel = $this._summaryPanel
        if (-not $panel) { return }
        
        Write-Verbose "DashboardScreen: Updating summary panel"
        
        # Clear the panel content completely
        $panel.ClearContent()
        
        # Force the panel to render its background
        $panel.OnRender()

        $headerColor = Get-ThemeColor 'Header'
        $subtleColor = Get-ThemeColor 'Subtle'
        $defaultColor = Get-ThemeColor 'Foreground'
        $highlightColor = Get-ThemeColor 'Highlight'
        $bgColor = Get-ThemeColor 'Background'
        
        $buffer = $panel.GetBuffer()
        $contentX = $panel.ContentX
        $contentY = $panel.ContentY

        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY) -Text "Task Overview" -ForegroundColor $headerColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 1) -Text ('─' * ($panel.ContentWidth - 2)) -ForegroundColor $subtleColor -BackgroundColor $bgColor
        
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 3) -Text "Total Tasks:    $($this._totalTasks)" -ForegroundColor $defaultColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 4) -Text "Completed:      $($this._completedTasks)" -ForegroundColor $defaultColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 5) -Text "Pending:        $($this._pendingTasks)" -ForegroundColor $defaultColor -BackgroundColor $bgColor
        
        $progress = $this._GetProgressBar()
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 7) -Text "Overall Progress:" -ForegroundColor $defaultColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 8) -Text $progress -ForegroundColor $highlightColor -BackgroundColor $bgColor
        
        $panel.RequestRedraw()
    }

    hidden [void] _UpdateHelpPanel() {
        $panel = $this._helpPanel
        if (-not $panel) { return }
        
        Write-Verbose "DashboardScreen: Updating help panel"
        
        # Clear the panel content completely
        $panel.ClearContent()
        
        # Force the panel to render its background
        $panel.OnRender()
        
        $paletteHotkey = "Ctrl+P"
        
        $headerColor = Get-ThemeColor 'Header'
        $subtleColor = Get-ThemeColor 'Subtle'
        $defaultColor = Get-ThemeColor 'Foreground'
        $accentColor = Get-ThemeColor 'Accent'
        $bgColor = Get-ThemeColor 'Background'

        $buffer = $panel.GetBuffer()
        $contentX = $panel.ContentX
        $contentY = $panel.ContentY
        
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 0) -Text "Welcome to Axiom-Phoenix!" -ForegroundColor $headerColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 1) -Text ('─' * ($panel.ContentWidth - 2)) -ForegroundColor $subtleColor -BackgroundColor $bgColor
        
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 3) -Text "Press " -ForegroundColor $defaultColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 7) -Y ($contentY + 3) -Text $paletteHotkey -ForegroundColor $accentColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 7 + $paletteHotkey.Length) -Y ($contentY + 3) -Text " to open the" -ForegroundColor $defaultColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 4) -Text "Command Palette." -ForegroundColor $defaultColor -BackgroundColor $bgColor

        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 6) -Text "All navigation and actions are" -ForegroundColor $subtleColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 7) -Text "now available from there." -ForegroundColor $subtleColor -BackgroundColor $bgColor
        
        $panel.RequestRedraw()
    }
    
    hidden [void] _UpdateStatusPanel() {
        $panel = $this._statusPanel
        if (-not $panel) { return }
        
        Write-Verbose "DashboardScreen: Updating status panel"
        
        # Clear the panel content completely
        $panel.ClearContent()
        
        # Force the panel to render its background
        $panel.OnRender()

        $memoryMB = try { [Math]::Round((Get-Process -Id $global:PID).WorkingSet64 / 1MB, 2) } catch { 0 } # FIX: Changed $PID to $global:PID to access the global automatic variable from within a class method.

        $headerColor = Get-ThemeColor 'Header'
        $subtleColor = Get-ThemeColor 'Subtle'
        $defaultColor = Get-ThemeColor 'Foreground'
        $bgColor = Get-ThemeColor 'Background'
        
        $buffer = $panel.GetBuffer()
        $contentX = $panel.ContentX
        $contentY = $panel.ContentY

        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 0) -Text "System Information" -ForegroundColor $headerColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 1) -Text ('─' * ($panel.ContentWidth - 2)) -ForegroundColor $subtleColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 3) -Text "PowerShell Version: $($global:PSVersionTable.PSVersion)" -ForegroundColor $defaultColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 4) -Text "Platform:           $($global:PSVersionTable.Platform)" -ForegroundColor $defaultColor -BackgroundColor $bgColor
        Write-TuiText -Buffer $buffer -X ($contentX + 1) -Y ($contentY + 5) -Text "Memory Usage:       $($memoryMB) MB" -ForegroundColor $defaultColor -BackgroundColor $bgColor
        
        $panel.RequestRedraw()
    }

    hidden [string] _GetProgressBar() {
        if ($this._totalTasks -eq 0) { return "No tasks defined." }
        $percentage = [Math]::Round(($this._completedTasks / $this._totalTasks) * 100)
        $barLength = $this._summaryPanel.ContentWidth - 6
        if($barLength -lt 1) { $barLength = 1 }
        $filledLength = [Math]::Floor(($percentage / 100) * $barLength)
        $bar = '█' * $filledLength + '░' * ($barLength - $filledLength)
        return "[$bar] $percentage%"
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($keyInfo.Key -eq [ConsoleKey]::F5) {
            $this._RefreshData($this.ServiceContainer.GetService("DataManager"))
            return $true
        }
        return $false
    }
}