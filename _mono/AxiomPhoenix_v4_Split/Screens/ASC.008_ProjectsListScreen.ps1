# ==============================================================================
# Axiom-Phoenix v4.0 - Projects List Screen
# FIXED: Removed FocusManager dependency, uses direct input handling
# ==============================================================================

using namespace System.Collections.Generic

class ProjectsListScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [Panel] $_listPanel
    hidden [Panel] $_detailPanel
    hidden [Panel] $_actionPanel
    hidden [TextBoxComponent] $_searchBox
    hidden [ListBox] $_projectListBox
    hidden [List[PmcProject]] $_allProjects
    hidden [List[PmcProject]] $_filteredProjects
    hidden [LabelComponent] $_statusLabel
    hidden [object] $_dataManager
    hidden [string] $_currentFilter = ""
    
    # Detail panel components
    hidden [MultilineTextBoxComponent] $_descriptionBox
    hidden [Dictionary[string, LabelComponent]] $_detailLabels
    
    # Search state
    hidden [string] $_searchText = ""
    
    ProjectsListScreen([object]$serviceContainer) : base("ProjectsListScreen", $serviceContainer) {
        $this._dataManager = $serviceContainer.GetService("DataManager")
        $this._detailLabels = [Dictionary[string, LabelComponent]]::new()
        Write-Log -Level Debug -Message "ProjectsListScreen: Constructor called"
    }
    
    [void] Initialize() {
        Write-Log -Level Debug -Message "ProjectsListScreen.Initialize: Starting"
        
        # Main panel covering the whole screen
        $this._mainPanel = [Panel]::new("ProjectsMainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Projects Management "
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.BorderColor = Get-ThemeColor "Panel.Border" "#00d4ff"
        $this._mainPanel.SetBackgroundColor((Get-ThemeColor "Panel.Background" "#1e1e1e"))
        $this.AddChild($this._mainPanel)
        
        # Calculate dimensions
        $listWidth = [Math]::Floor($this.Width * 0.4)
        $detailWidth = $this.Width - $listWidth - 3
        
        # List panel (left side)
        $this._listPanel = [Panel]::new("ProjectListPanel")
        $this._listPanel.X = 1
        $this._listPanel.Y = 1
        $this._listPanel.Width = $listWidth
        $this._listPanel.Height = $this.Height - 6  # Leave room for action panel
        $this._listPanel.Title = " Projects "
        $this._listPanel.BorderStyle = "Single"
        $this._listPanel.BorderColor = Get-ThemeColor "Panel.Border" "#666666"
        $this._mainPanel.AddChild($this._listPanel)
        
        # Search box
        $this._searchBox = [TextBoxComponent]::new("ProjectSearchBox")
        $this._searchBox.X = 2
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this._listPanel.Width - 4
        $this._searchBox.Height = 1
        $this._searchBox.Placeholder = "🔍 Search projects..."
        $this._searchBox.IsFocusable = $true  # HYBRID MODEL: Component handles its own input
        $this._searchBox.TabIndex = 0
        $this._searchBox.SetBackgroundColor((Get-ThemeColor "Input.Background" "#2d2d30")) # Added SetBackgroundColor
        $this._searchBox.SetForegroundColor((Get-ThemeColor "Input.Foreground" "#d4d4d4")) # Added SetForegroundColor
        $this._searchBox.BorderColor = (Get-ThemeColor "Input.Border" "#404040") # Direct assignment is fine for BorderColor
        
        # Add visual focus feedback for search box
        $this._searchBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "Input.FocusedBorder" "#00d4ff"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._searchBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "Input.Border" "#666666"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        # Handle search text changes
        $screenRef = $this
        $this._searchBox.OnChange = {
            param($sender, $newText)
            $screenRef._searchText = $newText
            $screenRef.FilterProjects($newText)
        }.GetNewClosure()
        
        $this._listPanel.AddChild($this._searchBox)
        
        # Project list
        $this._projectListBox = [ListBox]::new("ProjectList")
        $this._projectListBox.X = 1
        $this._projectListBox.Y = 3
        $this._projectListBox.Width = $this._listPanel.Width - 2
        $this._projectListBox.Height = $this._listPanel.Height - 5
        $this._projectListBox.HasBorder = $false
        $this._projectListBox.IsFocusable = $true  # HYBRID MODEL: Component handles its own input
        $this._projectListBox.TabIndex = 1
        $this._projectListBox.SelectedBackgroundColor = Get-ThemeColor "List.ItemSelectedBackground" "#007acc" # Direct assignment is fine
        $this._projectListBox.SelectedForegroundColor = Get-ThemeColor "List.ItemSelected" "#ffffff" # Direct assignment is fine
        
        # Add visual focus feedback for list box
        $this._projectListBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "Input.FocusedBorder" "#00d4ff" # Direct assignment is fine
            $this.RequestRedraw()
        } -Force
        
        $this._projectListBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "Panel.Border" "#666666" # Direct assignment is fine
            $this.RequestRedraw()
        } -Force
        
        # Handle list selection changes
        $screenRef = $this
        $this._projectListBox.SelectedIndexChanged = {
            param($sender, $newIndex)
            $screenRef.UpdateDetailPanel()
        }.GetNewClosure()
        
        $this._listPanel.AddChild($this._projectListBox)
        
        # Detail panel (right side)
        $this._detailPanel = [Panel]::new("ProjectDetailPanel")
        $this._detailPanel.X = $listWidth + 2
        $this._detailPanel.Y = 1
        $this._detailPanel.Width = $detailWidth
        $this._detailPanel.Height = $this.Height - 6  # Leave room for action panel
        $this._detailPanel.Title = " Project Details "
        $this._detailPanel.BorderStyle = "Single"
        $this._detailPanel.BorderColor = Get-ThemeColor "Panel.Border" "#666666" # Direct assignment is fine
        $this._mainPanel.AddChild($this._detailPanel)
        
        # Create detail components
        $this.CreateDetailComponents()
        
        # Action panel (bottom)
        $this._actionPanel = [Panel]::new("ProjectActionPanel")
        $this._actionPanel.X = 1
        $this._actionPanel.Y = $this.Height - 4
        $this._actionPanel.Width = $this.Width - 2
        $this._actionPanel.Height = 3
        $this._actionPanel.BorderStyle = "Single"
        $this._actionPanel.BorderColor = Get-ThemeColor "Panel.Border" "#666666" # Direct assignment is fine
        $this._mainPanel.AddChild($this._actionPanel)
        
        # Action buttons and status
        $buttonY = 1
        $buttonSpacing = 15
        
        # View button
        $viewBtn = [LabelComponent]::new("ViewButton")
        $viewBtn.Text = "[Enter] View"
        $viewBtn.X = 2
        $viewBtn.Y = $buttonY
        $viewBtn.SetForegroundColor((Get-ThemeColor "Label.Foreground" "#00ff88"))
        $this._actionPanel.AddChild($viewBtn)
        
        # New button
        $newBtn = [LabelComponent]::new("NewButton")
        $newBtn.Text = "[N] New"
        $newBtn.X = $viewBtn.X + $buttonSpacing
        $newBtn.Y = $buttonY
        $newBtn.SetForegroundColor((Get-ThemeColor "Label.Foreground" "#00d4ff"))
        $this._actionPanel.AddChild($newBtn)
        
        # Edit button
        $editBtn = [LabelComponent]::new("EditButton")
        $editBtn.Text = "[E] Edit"
        $editBtn.X = $newBtn.X + $buttonSpacing
        $editBtn.Y = $buttonY
        $editBtn.SetForegroundColor((Get-ThemeColor "Label.Foreground" "#ffa500"))
        $this._actionPanel.AddChild($editBtn)
        
        # Delete button
        $deleteBtn = [LabelComponent]::new("DeleteButton")
        $deleteBtn.Text = "[D] Delete"
        $deleteBtn.X = $editBtn.X + $buttonSpacing
        $deleteBtn.Y = $buttonY
        $deleteBtn.SetForegroundColor((Get-ThemeColor "Label.Foreground" "#ff4444"))
        $this._actionPanel.AddChild($deleteBtn)
        
        # Archive button
        $archiveBtn = [LabelComponent]::new("ArchiveButton")
        $archiveBtn.Text = "[A] Archive"
        $archiveBtn.X = $deleteBtn.X + $buttonSpacing
        $archiveBtn.Y = $buttonY
        $archiveBtn.SetForegroundColor((Get-ThemeColor "Label.Foreground" "#d4d4d4"))
        $this._actionPanel.AddChild($archiveBtn)
        
        # Tab hint
        $tabHint = [LabelComponent]::new("TabHint")
        $tabHint.Text = "[Tab] Focus"
        $tabHint.X = $archiveBtn.X + $buttonSpacing
        $tabHint.Y = $buttonY
        $tabHint.SetForegroundColor((Get-ThemeColor "Label.Foreground" "#666666"))
        $this._actionPanel.AddChild($tabHint)
        
        # Status label
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.Text = "0 projects"
        $this._statusLabel.X = $this._actionPanel.Width - 20
        $this._statusLabel.Y = $buttonY
        $this._statusLabel.SetForegroundColor((Get-ThemeColor "Label.Foreground" "#666666"))
        $this._actionPanel.AddChild($this._statusLabel)
        
        # Exit instructions
        $exitLabel = [LabelComponent]::new("ExitLabel")
        $exitLabel.Text = "[Esc] Back"
        $exitLabel.X = $this._actionPanel.Width - 12
        $exitLabel.Y = $buttonY
        $exitLabel.SetForegroundColor((Get-ThemeColor "Label.Foreground" "#666666"))
        $this._actionPanel.AddChild($exitLabel)
        
        Write-Log -Level Debug -Message "ProjectsListScreen.Initialize: Completed"
    }
    
    hidden [void] CreateDetailComponents() {
        $labelStyle = @{ 
            ForegroundColor = Get-ThemeColor "Label.Foreground" "#d4d4d4"
            Width = 15
            Height = 1 
        }
        $valueStyle = @{ 
            ForegroundColor = Get-ThemeColor "Label.Foreground" "#d4d4d4"
            Width = $this._detailPanel.Width - 20
            Height = 1 
        }
        
        $y = 2
        
        # Project Key
        $keyLabel = [LabelComponent]::new("KeyLabel")
        $keyLabel.Text = "Project Key:"
        $keyLabel.X = 2
        $keyLabel.Y = $y
        $keyLabel.SetForegroundColor($labelStyle.ForegroundColor)
        $this._detailPanel.AddChild($keyLabel)
        
        $keyValue = [LabelComponent]::new("KeyValue")
        $keyValue.X = 18
        $keyValue.Y = $y
        $keyValue.SetForegroundColor((Get-ThemeColor "Label.Foreground" "#00d4ff"))
        $this._detailPanel.AddChild($keyValue)
        $this._detailLabels["Key"] = $keyValue
        $y += 2
        
        # Project Name
        $nameLabel = [LabelComponent]::new("NameLabel")
        $nameLabel.Text = "Name:"
        $nameLabel.X = 2
        $nameLabel.Y = $y
        $nameLabel.SetForegroundColor($labelStyle.ForegroundColor)
        $this._detailPanel.AddChild($nameLabel)
        
        $nameValue = [LabelComponent]::new("NameValue")
        $nameValue.X = 18
        $nameValue.Y = $y
        $nameValue.SetForegroundColor($valueStyle.ForegroundColor)
        $this._detailPanel.AddChild($nameValue)
        $this._detailLabels["Name"] = $nameValue
        $y += 2
        
        # Owner
        $ownerLabel = [LabelComponent]::new("OwnerLabel")
        $ownerLabel.Text = "Owner:"
        $ownerLabel.X = 2
        $ownerLabel.Y = $y
        $ownerLabel.SetForegroundColor($labelStyle.ForegroundColor)
        $this._detailPanel.AddChild($ownerLabel)
        
        $ownerValue = [LabelComponent]::new("OwnerValue")
        $ownerValue.X = 18
        $ownerValue.Y = $y
        $ownerValue.SetForegroundColor($valueStyle.ForegroundColor)
        $this._detailPanel.AddChild($ownerValue)
        $this._detailLabels["Owner"] = $ownerValue
        $y += 2
        
        # Status
        $statusLabel = [LabelComponent]::new("StatusLabel")
        $statusLabel.Text = "Status:"
        $statusLabel.X = 2
        $statusLabel.Y = $y
        $statusLabel.SetForegroundColor($labelStyle.ForegroundColor)
        $this._detailPanel.AddChild($statusLabel)
        
        $statusValue = [LabelComponent]::new("StatusValue")
        $statusValue.X = 18
        $statusValue.Y = $y
        $statusValue.SetForegroundColor((Get-ThemeColor "Label.Foreground" "#00ff88"))
        $this._detailPanel.AddChild($statusValue)
        $this._detailLabels["Status"] = $statusValue
        $y += 2
        
        # Client ID
        $clientLabel = [LabelComponent]::new("ClientLabel")
        $clientLabel.Text = "Client ID:"
        $clientLabel.X = 2
        $clientLabel.Y = $y
        $clientLabel.SetForegroundColor($labelStyle.ForegroundColor)
        $this._detailPanel.AddChild($clientLabel)
        
        $clientValue = [LabelComponent]::new("ClientValue")
        $clientValue.X = 18
        $clientValue.Y = $y
        $clientValue.SetForegroundColor($valueStyle.ForegroundColor)
        $this._detailPanel.AddChild($clientValue)
        $this._detailLabels["ClientID"] = $clientValue
        $y += 2
        
        # Due Date
        $dueDateLabel = [LabelComponent]::new("DueDateLabel")
        $dueDateLabel.Text = "Due Date:"
        $dueDateLabel.X = 2
        $dueDateLabel.Y = $y
        $dueDateLabel.SetForegroundColor($labelStyle.ForegroundColor)
        $this._detailPanel.AddChild($dueDateLabel)
        
        $dueDateValue = [LabelComponent]::new("DueDateValue")
        $dueDateValue.X = 18
        $dueDateValue.Y = $y
        $dueDateValue.SetForegroundColor($valueStyle.ForegroundColor)
        $this._detailPanel.AddChild($dueDateValue)
        $this._detailLabels["DueDate"] = $dueDateValue
        $y += 3
        
        # Description
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = 2
        $descLabel.Y = $y
        $descLabel.SetForegroundColor($labelStyle.ForegroundColor)
        $this._detailPanel.AddChild($descLabel)
        $y += 1
        
        $this._descriptionBox = [MultilineTextBoxComponent]::new("DescriptionBox")
        $this._descriptionBox.X = 2
        $this._descriptionBox.Y = $y
        $this._descriptionBox.Width = $this._detailPanel.Width - 4
        $this._descriptionBox.Height = $this._detailPanel.Height - $y - 2
        $this._descriptionBox.ReadOnly = $true
        $this._descriptionBox.BorderStyle = "Single"
        $this._descriptionBox.IsFocusable = $false  # Read-only, no focus needed
        $this._descriptionBox.SetBackgroundColor((Get-ThemeColor "textbox.bg" "#2A2A2A")) # Added SetBackgroundColor
        $this._descriptionBox.SetForegroundColor((Get-ThemeColor "textbox.fg" "#FFFFFF")) # Added SetForegroundColor
        $this._detailPanel.AddChild($this._descriptionBox)
    }
    
    [void] OnEnter() {
        Write-Log -Level Debug -Message "ProjectsListScreen.OnEnter: Loading projects"
        
        # Load all projects
        $this._allProjects = [List[PmcProject]]::new()
        $projects = $this._dataManager.GetProjects()
        foreach ($project in $projects) {
            $this._allProjects.Add($project)
        }
        
        # Initial display
        $this._searchText = ""
        $this._searchBox.Text = ""
        $this.FilterProjects($this._searchText) # Pass the empty string to filter
        
        # Call base class to handle focus management
        ([Screen]$this).OnEnter()
        
        $this.RequestRedraw()
    }
    
    [void] OnExit() {
        Write-Log -Level Debug -Message "ProjectsListScreen.OnExit: Cleaning up"
        # Nothing to clean up
    }
    
    hidden [void] FilterProjects([string]$searchTerm) {
        $this._currentFilter = $searchTerm
        $this._filteredProjects = [List[PmcProject]]::new()
        
        foreach ($project in $this._allProjects) {
            if ([string]::IsNullOrWhiteSpace($searchTerm) -or
                $project.Key -like "*$searchTerm*" -or
                $project.Name -like "*$searchTerm*" -or
                $project.Description -like "*$searchTerm*" -or
                $project.Owner -like "*$searchTerm*") {
                $this._filteredProjects.Add($project)
            }
        }
        
        # Update list
        $this._projectListBox.ClearItems()
        foreach ($project in $this._filteredProjects) {
            $icon = if ($project.IsActive) { "📁" } else { "📂" }
            $status = if ($project.IsActive) { "" } else { " [Archived]" }
            $itemText = "$icon $($project.Key) - $($project.Name)$status"
            $this._projectListBox.AddItem($itemText)
        }
        
        # Update status
        $count = $this._filteredProjects.Count
        $total = $this._allProjects.Count
        if ([string]::IsNullOrWhiteSpace($searchTerm)) {
            $this._statusLabel.SetText("$count projects")
        } else {
            $this._statusLabel.SetText("$count of $total")
        }
        
        # Select first item if available
        if ($this._filteredProjects.Count -gt 0) {
            $this._projectListBox.SelectedIndex = 0
        } else {
            $this._projectListBox.SelectedIndex = -1 # No items, no selection
        }
        
        $this.UpdateDetailPanel()
        $this.RequestRedraw()
    }
    
    hidden [void] UpdateDetailPanel() {
        if ($this._projectListBox.SelectedIndex -lt 0 -or 
            $this._projectListBox.SelectedIndex -ge $this._filteredProjects.Count) {
            # Clear all details
            foreach ($label in $this._detailLabels.Values) {
                $label.SetText("")
            }
            $this._descriptionBox.SetText("")
            return
        }
        
        $project = $this._filteredProjects[$this._projectListBox.SelectedIndex]
        
        # Update basic fields
        $this._detailLabels["Key"].SetText($project.Key)
        $this._detailLabels["Name"].SetText($project.Name)
        $this._detailLabels["Owner"].SetText((if ($project.Owner) { $project.Owner } else { "Unassigned" }))
        
        # Status with color
        $statusText = if ($project.IsActive) { "Active" } else { "Archived" }
        $this._detailLabels["Status"].SetText($statusText)
        $this._detailLabels["Status"].SetForegroundColor((if ($project.IsActive) { 
            Get-ThemeColor "Label.Foreground" "#00ff88"
        } else { 
            Get-ThemeColor "Label.Foreground" "#666666"
        }))
        
        # Client ID from metadata
        $clientId = $project.GetMetadata("ClientID")
        $this._detailLabels["ClientID"].SetText((if ($clientId) { $clientId } else { "N/A" }))
        
        # Due date
        if ($project.BFDate) {
            $daysUntil = ($project.BFDate - [DateTime]::Now).Days
            $dateText = $project.BFDate.ToString("yyyy-MM-dd")
            if ($daysUntil -lt 0) {
                $dateText += " (Overdue!)"
                $this._detailLabels["DueDate"].SetForegroundColor((Get-ThemeColor "Label.Foreground" "#ff4444"))
            } elseif ($daysUntil -le 7) {
                $dateText += " ($daysUntil days)"
                $this._detailLabels["DueDate"].SetForegroundColor((Get-ThemeColor "Label.Foreground" "#ffa500"))
            } else {
                $this._detailLabels["DueDate"].SetForegroundColor((Get-ThemeColor "Label.Foreground" "#d4d4d4"))
            }
            $this._detailLabels["DueDate"].SetText($dateText)
        } else {
            $this._detailLabels["DueDate"].SetText("Not set")
            $this._detailLabels["DueDate"].SetForegroundColor((Get-ThemeColor "Label.Foreground" "#666666"))
        }
        
        # Description
        if ($project.Description) {
            $this._descriptionBox.SetText($project.Description)
        } else {
            $this._descriptionBox.SetText("No description available.")
        }
        
        $this.RequestRedraw()
    }
    
    hidden [void] ViewSelectedProject() {
        if ($this._projectListBox.SelectedIndex -ge 0 -and 
            $this._projectListBox.SelectedIndex -lt $this._filteredProjects.Count) {
            $selectedProject = $this._filteredProjects[$this._projectListBox.SelectedIndex]
            
            $navService = $this.ServiceContainer?.GetService("NavigationService")
            if ($navService) {
                $projectInfoScreen = [ProjectInfoScreen]::new($this.ServiceContainer)
                $projectInfoScreen.SetProject($selectedProject)
                $projectInfoScreen.Initialize()
                $navService.NavigateTo($projectInfoScreen)
            }
        }
    }
    
    hidden [void] CreateNewProject() {
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navService) {
            $editDialog = [ProjectEditDialog]::new($this.ServiceContainer, $null)
            $editDialog.Initialize()
            $navService.NavigateTo($editDialog)
        }
    }
    
    hidden [void] EditSelectedProject() {
        if ($this._projectListBox.SelectedIndex -ge 0 -and 
            $this._projectListBox.SelectedIndex -lt $this._filteredProjects.Count) {
            $selectedProject = $this._filteredProjects[$this._projectListBox.SelectedIndex]
            
            $navService = $this.ServiceContainer?.GetService("NavigationService")
            if ($navService) {
                $editDialog = [ProjectEditDialog]::new($this.ServiceContainer, $selectedProject)
                $editDialog.Initialize()
                $navService.NavigateTo($editDialog)
            }
        }
    }
    
    hidden [void] DeleteSelectedProject() {
        if ($this._projectListBox.SelectedIndex -lt 0 -or 
            $this._projectListBox.SelectedIndex -ge $this._filteredProjects.Count) {
            return
        }
        
        $selectedProject = $this._filteredProjects[$this._projectListBox.SelectedIndex]
        
        # Simple confirmation - in real app would use dialog
        Write-Log -Level Warning -Message "Delete not implemented for project: $($selectedProject.Key)"
    }
    
    hidden [void] ArchiveSelectedProject() {
        if ($this._projectListBox.SelectedIndex -lt 0 -or 
            $this._projectListBox.SelectedIndex -ge $this._filteredProjects.Count) {
            return
        }
        
        $selectedProject = $this._filteredProjects[$this._projectListBox.SelectedIndex]
        
        if ($selectedProject.IsActive) {
            $selectedProject.IsActive = $false
            $this._dataManager.UpdateProject($selectedProject)
            Write-Log -Level Info -Message "Archived project: $($selectedProject.Key)"
        } else {
            $selectedProject.IsActive = $true
            $this._dataManager.UpdateProject($selectedProject)
            Write-Log -Level Info -Message "Activated project: $($selectedProject.Key)"
        }
        
        # Refresh display
        $this.FilterProjects($this._searchText)
    }
    
    # === INPUT HANDLING (HYBRID MODEL) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "ProjectsListScreen.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "ProjectsListScreen.HandleInput: Key=$($keyInfo.Key)"
        
        # HYBRID MODEL: Base class handles Tab navigation and routes input to focused component
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # Handle screen-level shortcuts that work regardless of focus
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                $this.ViewSelectedProject()
                return $true
            }
            ([ConsoleKey]::Escape) {
                # Go back
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                } else {
                    # Fallback to dashboard
                    $actionService = $this.ServiceContainer?.GetService("ActionService")
                    if ($actionService) {
                        $actionService.ExecuteAction("navigation.dashboard", @{})
                    }
                }
                return $true
            }
        }
        
        # Global character shortcuts (work in both search and list)
        switch ($keyInfo.KeyChar) {
            'n' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this.CreateNewProject()
                    return $true
                }
            }
            'N' {
                $this.CreateNewProject()
                return $true
            }
            'e' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this.EditSelectedProject()
                    return $true
                }
            }
            'E' {
                $this.EditSelectedProject()
                return $true
            }
            'd' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this.DeleteSelectedProject()
                    return $true
                }
            }
            'D' {
                $this.DeleteSelectedProject()
                return $true
            }
            'a' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this.ArchiveSelectedProject()
                    return $true
                }
            }
            'A' {
                $this.ArchiveSelectedProject()
                return $true
            }
            '/' {
                # Quick jump to search - focus the search box
                # The framework will handle this through focus management
                # We can use SetChildFocus if needed
                return $false  # Let framework handle
            }
        }
        
        return $false
    }
}

# ==============================================================================
# END OF PROJECTS LIST SCREEN
# ==============================================================================