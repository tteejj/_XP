# TimeTrackingScreen - Time entry management with export functionality
# Based on ALCAR patterns and PMC specifications from doc_review.txt

class TimeTrackingScreen : Screen {
    [object]$TimeService
    [object]$ProjectService
    [array]$TimeEntries
    [string]$CurrentView = "All"  # All, Week, Project
    [string]$SelectedProjectID = ""
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [string]$StatusText = ""
    
    TimeTrackingScreen() {
        $this.Title = "TIME TRACKING"
        
        # Initialize services with error handling
        try {
            Write-Host "Initializing TimeTrackingService..." -ForegroundColor Yellow
            $this.TimeService = [TimeTrackingService]::new()
            Write-Host "TimeTrackingService initialized" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to initialize TimeTrackingService: $($_.Exception.Message)"
            $this.TimeService = $null
        }
        
        try {
            $this.ProjectService = [ProjectService]::new()
        } catch {
            Write-Warning "Failed to initialize ProjectService: $($_.Exception.Message)"
            $this.ProjectService = $null
        }
        
        $this.InitializeComponents()
        $this.LoadTimeEntries()
        $this.BindKeys()
    }
    
    [void] InitializeComponents() {
        # Simple list with selection index
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
    }
    
    [void] BindKeys() {
        # Navigation
        $this.BindKey([ConsoleKey]::DownArrow, { $this.NavigateDown(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::UpArrow, { $this.NavigateUp(); $this.RequestRender() })
        
        # Actions
        $this.BindKey([ConsoleKey]::N, { $this.NewTimeEntry() })
        $this.BindKey([ConsoleKey]::E, { $this.EditTimeEntry() })
        $this.BindKey([ConsoleKey]::D, { $this.DeleteTimeEntry() })
        
        # Views
        $this.BindKey([ConsoleKey]::A, { $this.ShowAllEntries() })
        $this.BindKey([ConsoleKey]::W, { $this.ShowWeekEntries() })
        $this.BindKey([ConsoleKey]::P, { $this.ShowProjectEntries() })
        
        # Export
        $this.BindKey([ConsoleKey]::X, { $this.ExportTimesheet() })
        $this.BindKey([ConsoleKey]::Q, { $this.ExportQuickWeek() })
        
        # Quick time entry
        $this.BindKey([ConsoleKey]::T, { $this.QuickTimeEntry() })
        
        # Escape to exit
        $this.BindKey([ConsoleKey]::Escape, { $this.Active = $false })
    }
    
    [void] LoadTimeEntries() {
        try {
            # Check if service is available
            if (-not $this.TimeService) {
                Write-Warning "TimeService is not initialized"
                $this.TimeEntries = @()
                $this.UpdateStatusPanel()
                return
            }
            
            switch ($this.CurrentView) {
                "All" { 
                    $entries = $this.TimeService.GetAllTimeEntries()
                    $this.TimeEntries = if ($entries) { $entries.ToArray() } else { @() }
                }
                "Week" { 
                    $this.TimeEntries = $this.TimeService.GetCurrentWeekEntries()
                    if (-not $this.TimeEntries) { $this.TimeEntries = @() }
                }
                "Project" { 
                    $this.TimeEntries = $this.TimeService.GetTimeEntriesForProject($this.SelectedProjectID)
                    if (-not $this.TimeEntries) { $this.TimeEntries = @() }
                }
            }
            
            # Sort by date descending (most recent first)
            $this.TimeEntries = $this.TimeEntries | Sort-Object Date -Descending
            
            # Reset selection
            $this.SelectedIndex = 0
            $this.ScrollOffset = 0
            $this.UpdateStatusPanel()
        }
        catch {
            Write-Warning "Failed to load time entries: $($_.Exception.Message)"
        }
    }
    
    [void] UpdateStatusPanel() {
        if (-not $this.TimeEntries) { $this.TimeEntries = @() }
        
        $totalHours = ($this.TimeEntries | Measure-Object -Property Hours -Sum).Sum
        $entryCount = $this.TimeEntries.Count
        
        if ($this.TimeService) {
            try {
                $stats = $this.TimeService.GetStatistics()
                $systemHours = if ($stats) { $stats.TotalHours.ToString('0.00') } else { "0.00" }
                $systemEntries = if ($stats) { $stats.TotalEntries } else { 0 }
            } catch {
                $systemHours = "0.00"
                $systemEntries = 0
            }
        } else {
            $systemHours = "N/A"
            $systemEntries = "N/A"
        }
        
        $this.StatusText = "View: $($this.CurrentView) | Entries: $entryCount | Hours: $($totalHours.ToString('0.00'))" + "`n" +
                           "Total System Hours: $systemHours | Total Entries: $systemEntries" + "`n" +
                           "" + "`n" +
                           "N:New E:Edit D:Delete | A:All W:Week P:Project | X:Export Q:QuickWeek T:QuickEntry"
    }
    
    [void] NewTimeEntry() {
        $dialog = New-Object GuidedTimeEntryDialog -ArgumentList $this
        $global:ScreenManager.PushModal($dialog)
        
        # Refresh entries when dialog closes
        if ($dialog.Result -eq [DialogResult]::OK) {
            $this.LoadTimeEntries()
            $this.RequestRender()
        }
    }
    
    [void] EditTimeEntry() {
        if ($this.TimeEntries.Count -gt 0 -and $this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.TimeEntries.Count) {
            $selectedEntry = $this.TimeEntries[$this.SelectedIndex]
            $dialog = New-Object EditTimeEntryDialog -ArgumentList $this, $selectedEntry
            $global:ScreenManager.PushModal($dialog)
            
            # Refresh entries when dialog closes
            if ($dialog.Result -eq [DialogResult]::OK) {
                $this.LoadTimeEntries()
                $this.RequestRender()
            }
        }
    }
    
    [void] DeleteTimeEntry() {
        if ($this.TimeEntries.Count -gt 0 -and $this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.TimeEntries.Count) {
            $selectedEntry = $this.TimeEntries[$this.SelectedIndex]
            $message = "Delete time entry for $($selectedEntry.ProjectID) on $($selectedEntry.Date.ToString('yyyy-MM-dd'))?`n$($selectedEntry.Hours)h - $($selectedEntry.Description)"
            
            $dialog = New-Object ConfirmDialog -ArgumentList $this, "DELETE TIME ENTRY", $message
            $global:ScreenManager.PushModal($dialog)
            
            if ($dialog.Result -eq [DialogResult]::Yes) {
                $this.TimeService.DeleteTimeEntry($selectedEntry.ID)
                $this.LoadTimeEntries()
                
                # Adjust selection if needed
                if ($this.SelectedIndex -ge $this.TimeEntries.Count) {
                    $this.SelectedIndex = [Math]::Max(0, $this.TimeEntries.Count - 1)
                }
                $this.EnsureVisible()
                $this.RequestRender()
            }
        }
    }
    
    [void] QuickTimeEntry() {
        Write-Host "Quick Time Entry - Not implemented yet"
    }
    
    [void] ShowAllEntries() {
        $this.CurrentView = "All"
        $this.SelectedProjectID = ""
        $this.LoadTimeEntries()
    }
    
    [void] ShowWeekEntries() {
        $this.CurrentView = "Week"
        $this.SelectedProjectID = ""
        $this.LoadTimeEntries()
    }
    
    [void] ShowProjectEntries() {
        Write-Host "Show Project Entries - Not implemented yet"
    }
    
    [void] ExportTimesheet() {
        Write-Host "Export Timesheet - Not implemented yet"
    }
    
    [void] ExportQuickWeek() {
        Write-Host "Export Quick Week - Not implemented yet"
    }
    
    [string] RenderContent() {
        $output = ""
        
        # Clear screen
        $output += [VT]::Clear()
        
        # Header
        $header = "TIME TRACKING"
        $output += [VT]::MoveTo(2, 2)
        $output += [VT]::TextBright() + $header + [VT]::Reset()
        
        # View indicator
        $viewText = "Current View: $($this.CurrentView)"
        if ($this.CurrentView -eq "Project" -and $this.SelectedProjectID) {
            $project = $this.ProjectService.GetProject($this.SelectedProjectID)
            $projectName = if ($project) { $project.Name } else { $this.SelectedProjectID }
            $viewText += " ($projectName)"
        }
        
        $output += [VT]::MoveTo(2, 3)
        $output += [VT]::TextBright() + $viewText + [VT]::Reset()
        
        # Render time entries list
        $startY = 5
        $listHeight = 20
        
        for ($i = 0; $i -lt $listHeight; $i++) {
            $entryIndex = $i + $this.ScrollOffset
            $y = $startY + $i
            
            $output += [VT]::MoveTo(2, $y)
            
            if ($entryIndex -lt $this.TimeEntries.Count) {
                $entry = $this.TimeEntries[$entryIndex]
                $project = $this.ProjectService.GetProject($entry.ProjectID)
                $projectName = if ($project) { $project.Name } else { $entry.ProjectID }
                $text = "$($entry.Date.ToString('MM/dd')) | $($entry.Hours.ToString('0.00'))h | $projectName | $($entry.Description)"
                
                # Highlight selected item
                if ($entryIndex -eq $this.SelectedIndex) {
                    $output += [VT]::Selected() + $text + [VT]::Reset()
                } else {
                    $output += [VT]::Text() + $text + [VT]::Reset()
                }
            }
            
            $output += [VT]::ClearLine()
        }
        
        # Render status panel
        $statusY = $startY + $listHeight + 2
        $output += [VT]::MoveTo(2, $statusY)
        $output += [VT]::Text() + $this.StatusText + [VT]::Reset()
        
        return $output
    }
    
    # Navigation methods
    [void] NavigateDown() {
        if ($this.TimeEntries.Count -gt 0 -and $this.SelectedIndex -lt $this.TimeEntries.Count - 1) {
            $this.SelectedIndex++
            $this.EnsureVisible()
        }
    }
    
    [void] NavigateUp() {
        if ($this.TimeEntries.Count -gt 0 -and $this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.EnsureVisible()
        }
    }
    
    [void] EnsureVisible() {
        $listHeight = 20
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $listHeight) {
            $this.ScrollOffset = $this.SelectedIndex - $listHeight + 1
        }
    }
    
    [object] GetSelectedEntry() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.TimeEntries.Count) {
            return $this.TimeEntries[$this.SelectedIndex]
        }
        return $null
    }
}