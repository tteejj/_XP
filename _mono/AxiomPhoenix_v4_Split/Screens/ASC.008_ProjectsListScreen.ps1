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
    
    # Internal focus management
    hidden [string] $_activeComponent = "search"  # "search", "list"
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
        $this._mainPanel.BorderColor = Get-ThemeColor "primary.accent"
        $this._mainPanel.BackgroundColor = Get-ThemeColor "background"
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
        $this._listPanel.BorderColor = Get-ThemeColor "component.border"
        $this._mainPanel.AddChild($this._listPanel)
        
        # Search box
        $this._searchBox = [TextBoxComponent]::new("ProjectSearchBox")
        $this._searchBox.X = 2
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this._listPanel.Width - 4
        $this._searchBox.Height = 1
        $this._searchBox.Placeholder = "🔍 Search projects..."
        $this._searchBox.IsFocusable = $false  # We handle input directly
        $this._searchBox.ShowCursor = $true  # Show cursor initially
        $this._listPanel.AddChild($this._searchBox)
        
        # Project list
        $this._projectListBox = [ListBox]::new("ProjectList")
        $this._projectListBox.X = 1
        $this._projectListBox.Y = 3
        $this._projectListBox.Width = $this._listPanel.Width - 2
        $this._projectListBox.Height = $this._listPanel.Height - 5
        $this._projectListBox.HasBorder = $false
        $this._projectListBox.IsFocusable = $false  # We handle input directly
        $this._projectListBox.SelectedBackgroundColor = Get-ThemeColor "list.selected.bg"
        $this._projectListBox.SelectedForegroundColor = Get-ThemeColor "list.selected.fg"
        $this._listPanel.AddChild($this._projectListBox)
        
        # Detail panel (right side)
        $this._detailPanel = [Panel]::new("ProjectDetailPanel")
        $this._detailPanel.X = $listWidth + 2
        $this._detailPanel.Y = 1
        $this._detailPanel.Width = $detailWidth
        $this._detailPanel.Height = $this.Height - 6  # Leave room for action panel
        $this._detailPanel.Title = " Project Details "
        $this._detailPanel.BorderStyle = "Single"
        $this._detailPanel.BorderColor = Get-ThemeColor "component.border"
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
        $this._actionPanel.BorderColor = Get-ThemeColor "component.border"
        $this._mainPanel.AddChild($this._actionPanel)
        
        # Action buttons and status
        $buttonY = 1
        $buttonSpacing = 15
        
        # View button
        $viewBtn = [LabelComponent]::new("ViewButton")
        $viewBtn.Text = "[Enter] View"
        $viewBtn.X = 2
        $viewBtn.Y = $buttonY
        $viewBtn.ForegroundColor = Get-ThemeColor "success"
        $this._actionPanel.AddChild($viewBtn)
        
        # New button
        $newBtn = [LabelComponent]::new("NewButton")
        $newBtn.Text = "[N] New"
        $newBtn.X = $viewBtn.X + $buttonSpacing
        $newBtn.Y = $buttonY
        $newBtn.ForegroundColor = Get-ThemeColor "primary"
        $this._actionPanel.AddChild($newBtn)
        
        # Edit button
        $editBtn = [LabelComponent]::new("EditButton")
        $editBtn.Text = "[E] Edit"
        $editBtn.X = $newBtn.X + $buttonSpacing
        $editBtn.Y = $buttonY
        $editBtn.ForegroundColor = Get-ThemeColor "warning"
        $this._actionPanel.AddChild($editBtn)
        
        # Delete button
        $deleteBtn = [LabelComponent]::new("DeleteButton")
        $deleteBtn.Text = "[D] Delete"
        $deleteBtn.X = $editBtn.X + $buttonSpacing
        $deleteBtn.Y = $buttonY
        $deleteBtn.ForegroundColor = Get-ThemeColor "error"
        $this._actionPanel.AddChild($deleteBtn)
        
        # Archive button
        $archiveBtn = [LabelComponent]::new("ArchiveButton")
        $archiveBtn.Text = "[A] Archive"
        $archiveBtn.X = $deleteBtn.X + $buttonSpacing
        $archiveBtn.Y = $buttonY
        $archiveBtn.ForegroundColor = Get-ThemeColor "component.text"
        $this._actionPanel.AddChild($archiveBtn)
        
        # Tab hint
        $tabHint = [LabelComponent]::new("TabHint")
        $tabHint.Text = "[Tab] Switch"
        $tabHint.X = $archiveBtn.X + $buttonSpacing
        $tabHint.Y = $buttonY
        $tabHint.ForegroundColor = Get-ThemeColor "subtle"
        $this._actionPanel.AddChild($tabHint)
        
        # Status label
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.Text = "0 projects"
        $this._statusLabel.X = $this._actionPanel.Width - 20
        $this._statusLabel.Y = $buttonY
        $this._statusLabel.ForegroundColor = Get-ThemeColor "subtle"
        $this._actionPanel.AddChild($this._statusLabel)
        
        # Exit instructions
        $exitLabel = [LabelComponent]::new("ExitLabel")
        $exitLabel.Text = "[Esc] Back"
        $exitLabel.X = $this._actionPanel.Width - 12
        $exitLabel.Y = $buttonY
        $exitLabel.ForegroundColor = Get-ThemeColor "subtle"
        $this._actionPanel.AddChild($exitLabel)
        
        Write-Log -Level Debug -Message "ProjectsListScreen.Initialize: Completed"
    }
    
    hidden [void] CreateDetailComponents() {
        $labelStyle = @{ 
            ForegroundColor = Get-ThemeColor "label"
            Width = 15
            Height = 1 
        }
        $valueStyle = @{ 
            ForegroundColor = Get-ThemeColor "foreground"
            Width = $this._detailPanel.Width - 20
            Height = 1 
        }
        
        $y = 2
        
        # Project Key
        $keyLabel = [LabelComponent]::new("KeyLabel")
        $keyLabel.Text = "Project Key:"
        $keyLabel.X = 2
        $keyLabel.Y = $y
        $keyLabel.ForegroundColor = $labelStyle.ForegroundColor
        $this._detailPanel.AddChild($keyLabel)
        
        $keyValue = [LabelComponent]::new("KeyValue")
        $keyValue.X = 18
        $keyValue.Y = $y
        $keyValue.ForegroundColor = Get-ThemeColor "primary"
        $this._detailPanel.AddChild($keyValue)
        $this._detailLabels["Key"] = $keyValue
        $y += 2
        
        # Project Name
        $nameLabel = [LabelComponent]::new("NameLabel")
        $nameLabel.Text = "Name:"
        $nameLabel.X = 2
        $nameLabel.Y = $y
        $nameLabel.ForegroundColor = $labelStyle.ForegroundColor
        $this._detailPanel.AddChild($nameLabel)
        
        $nameValue = [LabelComponent]::new("NameValue")
        $nameValue.X = 18
        $nameValue.Y = $y
        $nameValue.ForegroundColor = $valueStyle.ForegroundColor
        $this._detailPanel.AddChild($nameValue)
        $this._detailLabels["Name"] = $nameValue
        $y += 2
        
        # Owner
        $ownerLabel = [LabelComponent]::new("OwnerLabel")
        $ownerLabel.Text = "Owner:"
        $ownerLabel.X = 2
        $ownerLabel.Y = $y
        $ownerLabel.ForegroundColor = $labelStyle.ForegroundColor
        $this._detailPanel.AddChild($ownerLabel)
        
        $ownerValue = [LabelComponent]::new("OwnerValue")
        $ownerValue.X = 18
        $ownerValue.Y = $y
        $ownerValue.ForegroundColor = $valueStyle.ForegroundColor
        $this._detailPanel.AddChild($ownerValue)
        $this._detailLabels["Owner"] = $ownerValue
        $y += 2
        
        # Status
        $statusLabel = [LabelComponent]::new("StatusLabel")
        $statusLabel.Text = "Status:"
        $statusLabel.X = 2
        $statusLabel.Y = $y
        $statusLabel.ForegroundColor = $labelStyle.ForegroundColor
        $this._detailPanel.AddChild($statusLabel)
        
        $statusValue = [LabelComponent]::new("StatusValue")
        $statusValue.X = 18
        $statusValue.Y = $y
        $statusValue.ForegroundColor = Get-ThemeColor "success"
        $this._detailPanel.AddChild($statusValue)
        $this._detailLabels["Status"] = $statusValue
        $y += 2
        
        # Client ID
        $clientLabel = [LabelComponent]::new("ClientLabel")
        $clientLabel.Text = "Client ID:"
        $clientLabel.X = 2
        $clientLabel.Y = $y
        $clientLabel.ForegroundColor = $labelStyle.ForegroundColor
        $this._detailPanel.AddChild($clientLabel)
        
        $clientValue = [LabelComponent]::new("ClientValue")
        $clientValue.X = 18
        $clientValue.Y = $y
        $clientValue.ForegroundColor = $valueStyle.ForegroundColor
        $this._detailPanel.AddChild($clientValue)
        $this._detailLabels["ClientID"] = $clientValue
        $y += 2
        
        # Due Date
        $dueDateLabel = [LabelComponent]::new("DueDateLabel")
        $dueDateLabel.Text = "Due Date:"
        $dueDateLabel.X = 2
        $dueDateLabel.Y = $y
        $dueDateLabel.ForegroundColor = $labelStyle.ForegroundColor
        $this._detailPanel.AddChild($dueDateLabel)
        
        $dueDateValue = [LabelComponent]::new("DueDateValue")
        $dueDateValue.X = 18
        $dueDateValue.Y = $y
        $dueDateValue.ForegroundColor = $valueStyle.ForegroundColor
        $this._detailPanel.AddChild($dueDateValue)
        $this._detailLabels["DueDate"] = $dueDateValue
        $y += 3
        
        # Description
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = 2
        $descLabel.Y = $y
        $descLabel.ForegroundColor = $labelStyle.ForegroundColor
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
        $this.FilterProjects("")
        
        # Set initial focus state
        $this._activeComponent = "search"
        $this._UpdateVisualFocus()
        
        $this.RequestRedraw()
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
            $this._statusLabel.Text = "$count projects"
        } else {
            $this._statusLabel.Text = "$count of $total"
        }
        
        # Select first item if available
        if ($this._filteredProjects.Count -gt 0) {
            $this._projectListBox.SelectedIndex = 0
        }
        
        $this.UpdateDetailPanel()
        $this.RequestRedraw()
    }
    
    hidden [void] UpdateDetailPanel() {
        if ($this._projectListBox.SelectedIndex -lt 0 -or 
            $this._projectListBox.SelectedIndex -ge $this._filteredProjects.Count) {
            # Clear all details
            foreach ($label in $this._detailLabels.Values) {
                $label.Text = ""
            }
            $this._descriptionBox.SetText("")
            return
        }
        
        $project = $this._filteredProjects[$this._projectListBox.SelectedIndex]
        
        # Update basic fields
        $this._detailLabels["Key"].Text = $project.Key
        $this._detailLabels["Name"].Text = $project.Name
        $this._detailLabels["Owner"].Text = if ($project.Owner) { $project.Owner } else { "Unassigned" }
        
        # Status with color
        $statusText = if ($project.IsActive) { "Active" } else { "Archived" }
        $this._detailLabels["Status"].Text = $statusText
        $this._detailLabels["Status"].ForegroundColor = if ($project.IsActive) { 
            Get-ThemeColor "success" 
        } else { 
            Get-ThemeColor "subtle" 
        }
        
        # Client ID from metadata
        $clientId = $project.GetMetadata("ClientID")
        $this._detailLabels["ClientID"].Text = if ($clientId) { $clientId } else { "N/A" }
        
        # Due date
        if ($project.BFDate) {
            $daysUntil = ($project.BFDate - [DateTime]::Now).Days
            $dateText = $project.BFDate.ToString("yyyy-MM-dd")
            if ($daysUntil -lt 0) {
                $dateText += " (Overdue!)"
                $this._detailLabels["DueDate"].ForegroundColor = Get-ThemeColor "error"
            } elseif ($daysUntil -le 7) {
                $dateText += " ($daysUntil days)"
                $this._detailLabels["DueDate"].ForegroundColor = Get-ThemeColor "warning"
            } else {
                $this._detailLabels["DueDate"].ForegroundColor = Get-ThemeColor "foreground"
            }
            $this._detailLabels["DueDate"].Text = $dateText
        } else {
            $this._detailLabels["DueDate"].Text = "Not set"
            $this._detailLabels["DueDate"].ForegroundColor = Get-ThemeColor "subtle"
        }
        
        # Description
        if ($project.Description) {
            $this._descriptionBox.SetText($project.Description)
        } else {
            $this._descriptionBox.SetText("No description available.")
        }
        
        $this.RequestRedraw()
    }
    
    hidden [void] _UpdateVisualFocus() {
        # Update visual indicators based on active component
        if ($this._activeComponent -eq "search") {
            $this._searchBox.ShowCursor = $true
            $this._listPanel.BorderColor = Get-ThemeColor "primary.accent"
            $this._searchBox.BorderColor = Get-ThemeColor "primary.accent"
        } else {
            $this._searchBox.ShowCursor = $false
            $this._listPanel.BorderColor = Get-ThemeColor "component.border"
            $this._searchBox.BorderColor = Get-ThemeColor "component.border"
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
        
        # Show confirmation dialog
        $dialogManager = $this.ServiceContainer?.GetService("DialogManager")
        if ($dialogManager) {
            $dialogManager.ShowConfirmation(
                "Delete Project",
                "Are you sure you want to delete project '$($selectedProject.Name)'?`nThis action cannot be undone.",
                {
                    # On confirm
                    $this._dataManager.DeleteProject($selectedProject.Key)
                    $this._allProjects.Remove($selectedProject)
                    $this.FilterProjects($this._currentFilter)
                },
                $null  # On cancel
            )
        }
    }
    
    hidden [void] ToggleArchiveSelectedProject() {
        if ($this._projectListBox.SelectedIndex -ge 0 -and 
            $this._projectListBox.SelectedIndex -lt $this._filteredProjects.Count) {
            $selectedProject = $this._filteredProjects[$this._projectListBox.SelectedIndex]
            
            # Toggle archive status
            $selectedProject.IsActive = -not $selectedProject.IsActive
            $this._dataManager.UpdateProject($selectedProject)
            
            # Refresh display
            $this.FilterProjects($this._currentFilter)
        }
    }
    
    # === INPUT HANDLING (DIRECT, NO FOCUS MANAGER) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "ProjectsListScreen.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "ProjectsListScreen.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)', Active=$($this._activeComponent)"
        
        # Global keys work regardless of focus
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                # Go back
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
            ([ConsoleKey]::Tab) {
                # Toggle between search and list
                if ($this._activeComponent -eq "search") {
                    $this._activeComponent = "list"
                } else {
                    $this._activeComponent = "search"
                }
                $this._UpdateVisualFocus()
                return $true
            }
        }
        
        # Handle based on active component
        if ($this._activeComponent -eq "search") {
            # Search box is active
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($this._searchText.Length -gt 0) {
                        $this._searchText = $this._searchText.Substring(0, $this._searchText.Length - 1)
                        $this._searchBox.Text = $this._searchText
                        $this.FilterProjects($this._searchText)
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    # View first result if any
                    if ($this._filteredProjects.Count -gt 0) {
                        $this.ViewSelectedProject()
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    # Move to list if there are results
                    if ($this._filteredProjects.Count -gt 0) {
                        $this._activeComponent = "list"
                        $this._UpdateVisualFocus()
                    }
                    return $true
                }
                default {
                    # Add character to search
                    if ($keyInfo.KeyChar -and ([char]::IsLetterOrDigit($keyInfo.KeyChar) -or 
                        [char]::IsPunctuation($keyInfo.KeyChar) -or 
                        [char]::IsWhiteSpace($keyInfo.KeyChar))) {
                        $this._searchText += $keyInfo.KeyChar
                        $this._searchBox.Text = $this._searchText
                        $this.FilterProjects($this._searchText)
                        return $true
                    }
                }
            }
        } else {
            # List is active
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this._projectListBox.SelectedIndex -gt 0) {
                        $this._projectListBox.SelectedIndex--
                        $this.UpdateDetailPanel()
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this._projectListBox.SelectedIndex -lt $this._filteredProjects.Count - 1) {
                        $this._projectListBox.SelectedIndex++
                        $this.UpdateDetailPanel()
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    $this.ViewSelectedProject()
                    return $true
                }
                ([ConsoleKey]::Home) {
                    if ($this._filteredProjects.Count -gt 0) {
                        $this._projectListBox.SelectedIndex = 0
                        $this.UpdateDetailPanel()
                    }
                    return $true
                }
                ([ConsoleKey]::End) {
                    if ($this._filteredProjects.Count -gt 0) {
                        $this._projectListBox.SelectedIndex = $this._filteredProjects.Count - 1
                        $this.UpdateDetailPanel()
                    }
                    return $true
                }
            }
        }
        
        # Character shortcuts (work in both modes)
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
                    $this.ToggleArchiveSelectedProject()
                    return $true
                }
            }
            'A' {
                $this.ToggleArchiveSelectedProject()
                return $true
            }
            '/' {
                # Jump to search
                $this._activeComponent = "search"
                $this._UpdateVisualFocus()
                return $true
            }
        }
        
        return $false
    }
}

# ==============================================================================
# END OF PROJECTS LIST SCREEN
# ==============================================================================
