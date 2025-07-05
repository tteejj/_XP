# ==============================================================================
# Axiom-Phoenix v4.0 - Dashboard Screen
# A modern, theme-aware, and event-driven dashboard.
# ==============================================================================

using module ui-classes
using module panels-class
using module theme-manager
using module logger

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
        # FIX: Defensive programming - check ServiceContainer exists
        if (-not $this.ServiceContainer) {
            Write-Warning "DashboardScreen.OnInitialize: ServiceContainer is null"
            return
        }
        
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
        # FIX: Only subscribe if we have a valid ServiceContainer and SubscribeToEvent method
        if ($this.PSObject.Methods['SubscribeToEvent']) {
            $this.SubscribeToEvent("Tasks.Changed", {
                param($EventData)
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Debug "DashboardScreen detected Tasks.Changed event. Refreshing data."
                }
                # FIX: Safely access ServiceContainer for refresh
                if ($this.ServiceContainer) {
                    $refreshDataManager = $this.ServiceContainer.GetService("DataManager")
                    $this._RefreshData($refreshDataManager)
                } else {
                    $this._RefreshData($null)
                }
            })
        }
    }

    # OnEnter is called every time the screen becomes active. Good for refreshing data.
    [void] OnEnter() {
        # FIX: Add null check for ServiceContainer
        if ($this.ServiceContainer) {
            $dataManager = $this.ServiceContainer.GetService("DataManager")
            $this._RefreshData($dataManager)
        } else {
            Write-Warning "DashboardScreen.OnEnter: ServiceContainer is null, using defaults"
            $this._RefreshData($null)
        }
        
        # Set focus to the main panel, allowing for potential future keyboard interactions.
        if ($this._mainPanel -and (Get-Command Set-ComponentFocus -ErrorAction SilentlyContinue)) {
            Set-ComponentFocus -Component $this._mainPanel
        }
    }

    # Fetches the latest data and triggers a display update.
    hidden [void] _RefreshData([object]$dataManager) {
        if(-not $dataManager) {
            Write-Warning "DashboardScreen: DataManager service not found."
            # FIX: Set safe defaults when DataManager is unavailable
            $this._totalTasks = 0
            $this._completedTasks = 0
            $this._pendingTasks = 0
            $this._UpdateDisplay()
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
        if (-not $panel) { return }
        
        # FIX: Safe service access with fallback
        $theme = $null
        if ($this.ServiceContainer) {
            $theme = $this.ServiceContainer.GetService('ThemeManager')
        }
        
        $panel.ClearContent()

        # FIX: Safe theme access with fallbacks
        $headerColor = if ($theme) { $theme.GetColor('Header') } else { [ConsoleColor]::Cyan }
        $subtleColor = if ($theme) { $theme.GetColor('Subtle') } else { [ConsoleColor]::DarkGray }
        $foregroundColor = if ($theme) { $theme.GetColor('Foreground') } else { [ConsoleColor]::White }
        $highlightColor = if ($theme) { $theme.GetColor('Highlight') } else { [ConsoleColor]::Yellow }
        
        $panel.WriteToBuffer(1, 0, "Task Overview", $headerColor)
        $panel.WriteToBuffer(1, 1, ('─' * ($panel.ContentWidth-2)), $subtleColor)
        
        $panel.WriteToBuffer(1, 3, "Total Tasks:    $($this._totalTasks)", $foregroundColor)
        $panel.WriteToBuffer(1, 4, "Completed:      $($this._completedTasks)", $foregroundColor)
        $panel.WriteToBuffer(1, 5, "Pending:        $($this._pendingTasks)", $foregroundColor)
        
        $progress = $this._GetProgressBar()
        $panel.WriteToBuffer(1, 7, "Overall Progress:", $foregroundColor)
        $panel.WriteToBuffer(1, 8, $progress, $highlightColor)
    }

    # Updates the help panel to guide users to the new Command Palette.
    hidden [void] _UpdateHelpPanel() {
        $panel = $this._helpPanel
        if (-not $panel) { return }
        
        # FIX: Safe service access with fallbacks
        $theme = $null
        $actionService = $null
        if ($this.ServiceContainer) {
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            $actionService = $this.ServiceContainer.GetService('ActionService')
        }
        
        $panel.ClearContent()
        
        # FIX: Safe ActionService access with fallback
        $paletteHotkey = "Ctrl+P" # Default fallback
        if ($actionService) {
            try {
                $paletteAction = $actionService.GetAction("app.showCommandPalette")
                if ($paletteAction -and $paletteAction.Hotkey) {
                    $paletteHotkey = $paletteAction.Hotkey
                }
            } catch {
                # Action service not available or action not found, use default
            }
        }
        
        # FIX: Safe theme access with fallbacks
        $headerColor = if ($theme) { $theme.GetColor('Header') } else { [ConsoleColor]::Cyan }
        $subtleColor = if ($theme) { $theme.GetColor('Subtle') } else { [ConsoleColor]::DarkGray }
        $foregroundColor = if ($theme) { $theme.GetColor('Foreground') } else { [ConsoleColor]::White }
        $accentColor = if ($theme) { $theme.GetColor('Accent') } else { [ConsoleColor]::Yellow }
        
        $panel.WriteToBuffer(1, 0, "Welcome to Axiom-Phoenix!", $headerColor)
        $panel.WriteToBuffer(1, 1, ('─' * ($panel.ContentWidth-2)), $subtleColor)
        
        $panel.WriteToBuffer(1, 3, "Press ", $foregroundColor)
        $panel.WriteToBuffer(7, 3, $paletteHotkey, $accentColor)
        $panel.WriteToBuffer(7 + $paletteHotkey.Length, 3, " to open the", $foregroundColor)
        $panel.WriteToBuffer(1, 4, "Command Palette.", $foregroundColor)

        $panel.WriteToBuffer(1, 6, "All navigation and actions are", $subtleColor)
        $panel.WriteToBuffer(1, 7, "now available from there.", $subtleColor)
    }
    
    # Updates the status panel with system info.
    hidden [void] _UpdateStatusPanel() {
        $panel = $this._statusPanel
        if (-not $panel) { return }
        
        # FIX: Safe service access with fallback
        $theme = $null
        if ($this.ServiceContainer) {
            $theme = $this.ServiceContainer.GetService('ThemeManager')
        }
        
        $panel.ClearContent()

        # FIX: Safe process access
        $memoryMB = 0
        try {
            $process = Get-Process -Id $global:PID -ErrorAction SilentlyContinue
            if ($process) {
                $memoryMB = [Math]::Round($process.WorkingSet64 / 1MB, 2)
            }
        } catch {
            # Process info not available
        }

        # FIX: Safe theme access with fallbacks
        $headerColor = if ($theme) { $theme.GetColor('Header') } else { [ConsoleColor]::Cyan }
        $subtleColor = if ($theme) { $theme.GetColor('Subtle') } else { [ConsoleColor]::DarkGray }
        $foregroundColor = if ($theme) { $theme.GetColor('Foreground') } else { [ConsoleColor]::White }
        
        $panel.WriteToBuffer(1, 0, "System Information", $headerColor)
        $panel.WriteToBuffer(1, 1, ('─' * ($panel.ContentWidth-2)), $subtleColor)
        $panel.WriteToBuffer(1, 3, "PowerShell Version: $($global:PSVersionTable.PSVersion)", $foregroundColor)
        $panel.WriteToBuffer(1, 4, "Platform:           $($global:PSVersionTable.Platform)", $foregroundColor)
        $panel.WriteToBuffer(1, 5, "Memory Usage:       $($memoryMB) MB", $foregroundColor)
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