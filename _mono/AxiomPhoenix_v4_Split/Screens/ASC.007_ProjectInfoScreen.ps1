# ==============================================================================
# Axiom-Phoenix v4.0 - Project Info Screen
# Displays detailed information about a selected project, including linked files.
# ==============================================================================

using namespace System.Collections.Generic

class ProjectInfoScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [ScrollablePanel] $_detailsScrollPanel
    hidden [Panel] $_tasksPanel
    hidden [Panel] $_filesPanel
    hidden [PmcProject] $_project
    hidden [ListBox] $_taskListbox
    hidden [ListBox] $_fileListbox
    hidden [object] $_dataManager

    ProjectInfoScreen([object]$serviceContainer, [PmcProject]$project) : base("ProjectInfoScreen", $serviceContainer) {
        if ($null -eq $project) {
            throw [System.ArgumentNullException]::new("project", "Project must be provided to ProjectInfoScreen.")
        }
        $this._project = $project
        $this._dataManager = $serviceContainer.GetService("DataManager")
        $this.Title = " Project: $($project.Name) "
    }

    [void] Initialize() {
        # Main panel covering the whole screen
        $this._mainPanel = [Panel]::new("ProjectMainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Project Details: $($this._project.Name) "
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.BorderColor = Get-ThemeColor "Primary"
        $this._mainPanel.BackgroundColor = Get-ThemeColor "Background"
        $this.AddChild($this._mainPanel)

        # Calculate panel dimensions
        $detailsWidth = [Math]::Floor($this.Width * 0.5) - 2
        $rightPanelWidth = $this.Width - $detailsWidth - 3
        $tasksHeight = [Math]::Floor($this.Height * 0.4) - 2
        $filesY = $tasksHeight + 2
        $filesHeight = $this.Height - $filesY - 3

        # Details Scrollable Panel (left side)
        $this._detailsScrollPanel = [ScrollablePanel]::new("ProjectDetailsScrollPanel")
        $this._detailsScrollPanel.X = 1
        $this._detailsScrollPanel.Y = 1
        $this._detailsScrollPanel.Width = $detailsWidth
        $this._detailsScrollPanel.Height = $this.Height - 4
        $this._detailsScrollPanel.Title = " General Information "
        $this._detailsScrollPanel.BorderStyle = "Single"
        $this._detailsScrollPanel.BorderColor = Get-ThemeColor "component.border"
        $this._detailsScrollPanel.ShowScrollbar = $true
        $this._mainPanel.AddChild($this._detailsScrollPanel)

        # Tasks Panel (right side)
        $this._tasksPanel = [Panel]::new("ProjectTasksPanel")
        $this._tasksPanel.X = $detailsWidth + 2
        $this._tasksPanel.Y = 1
        $this._tasksPanel.Width = $rightPanelWidth
        $this._tasksPanel.Height = $tasksHeight
        $this._tasksPanel.Title = " Associated Tasks "
        $this._tasksPanel.BorderStyle = "Single"
        $this._tasksPanel.BorderColor = Get-ThemeColor "component.border"
        $this._mainPanel.AddChild($this._tasksPanel)

        # Files Panel (right side, below tasks)
        $this._filesPanel = [Panel]::new("ProjectFilesPanel")
        $this._filesPanel.X = $detailsWidth + 2
        $this._filesPanel.Y = $filesY
        $this._filesPanel.Width = $rightPanelWidth
        $this._filesPanel.Height = $filesHeight
        $this._filesPanel.Title = " Client Documents "
        $this._filesPanel.BorderStyle = "Single"
        $this._filesPanel.BorderColor = Get-ThemeColor "component.border"
        $this._mainPanel.AddChild($this._filesPanel)

        # Populate Details Panel
        $y = 2
        $this.AddDetailField("Project Key:", $this._project.Key, $y)
        $y += 2
        $this.AddDetailField("Name:", $this._project.Name, $y)
        $y += 2
        
        if ($this._project.ID1) {
            $this.AddDetailField("ID1 (Non-Unique):", $this._project.ID1, $y)
            $y += 2
        }
        
        if ($this._project.ID2) {
            $this.AddDetailField("ID2 (Main Case):", $this._project.ID2, $y)
            $y += 2
        }
        
        $clientId = $this._project.GetMetadata("ClientID")
        if ($clientId) {
            $this.AddDetailField("Client ID (BN):", $clientId, $y)
            $y += 2
        }
        
        if ($this._project.AssignedDate) {
            $this.AddDetailField("Assigned Date:", $this._project.AssignedDate.ToString("yyyy-MM-dd"), $y)
            $y += 2
        }
        
        if ($this._project.BFDate) {
            $this.AddDetailField("Due Date (BF):", $this._project.BFDate.ToString("yyyy-MM-dd"), $y)
            $y += 2
        }
        
        $this.AddDetailField("Owner:", ($this._project.Owner -or "Unassigned"), $y)
        $y += 2
        
        $this.AddDetailField("Status:", (if ($this._project.IsActive) { "Active" } else { "Archived" }), $y)
        $y += 2

        # Description
        if ($this._project.Description) {
            $this.AddDetailLabel("Description:", $y)
            $y += 1
            $this.AddDetailText($this._project.Description, $y)
            $y += 4
        }

        # Populate Tasks Listbox
        $this._taskListbox = [ListBox]::new("ProjectTaskListBox")
        $this._taskListbox.X = 1
        $this._taskListbox.Y = 1
        $this._taskListbox.Width = $this._tasksPanel.Width - 2
        $this._taskListbox.Height = $this._tasksPanel.Height - 2
        $this._taskListbox.HasBorder = $false
        $this._taskListbox.SelectedBackgroundColor = Get-ThemeColor "list.selected.bg"
        $this._taskListbox.SelectedForegroundColor = Get-ThemeColor "list.selected.fg"
        $this._tasksPanel.AddChild($this._taskListbox)

        # Populate Files Listbox
        $this._fileListbox = [ListBox]::new("ProjectFileListBox")
        $this._fileListbox.X = 1
        $this._fileListbox.Y = 1
        $this._fileListbox.Width = $this._filesPanel.Width - 2
        $this._fileListbox.Height = $this._filesPanel.Height - 2
        $this._fileListbox.HasBorder = $false
        $this._fileListbox.SelectedBackgroundColor = Get-ThemeColor "list.selected.bg"
        $this._fileListbox.SelectedForegroundColor = Get-ThemeColor "list.selected.fg"
        $this._filesPanel.AddChild($this._fileListbox)

        # Instructions
        $instructions = [LabelComponent]::new("Instructions")
        $instructions.Text = "Press [ESC] to go back to Dashboard. Use ↑↓ PgUp/PgDn to scroll details."
        $instructions.X = 1
        $instructions.Y = $this.Height - 2
        $instructions.ForegroundColor = Get-ThemeColor "Subtle"
        $this._mainPanel.AddChild($instructions)
    }

    hidden [void] AddDetailField([string]$label, [string]$value, [int]$y) {
        $labelComp = [LabelComponent]::new("Label_$y")
        $labelComp.Text = $label
        $labelComp.X = 2
        $labelComp.Y = $y
        $labelComp.ForegroundColor = Get-ThemeColor "label"
        $this._detailsScrollPanel.AddChild($labelComp)

        $valueComp = [LabelComponent]::new("Value_$y")
        $valueComp.Text = $value
        $valueComp.X = 20
        $valueComp.Y = $y
        $valueComp.ForegroundColor = Get-ThemeColor "Foreground"
        $this._detailsScrollPanel.AddChild($valueComp)
    }

    hidden [void] AddDetailLabel([string]$label, [int]$y) {
        $labelComp = [LabelComponent]::new("Label_$y")
        $labelComp.Text = $label
        $labelComp.X = 2
        $labelComp.Y = $y
        $labelComp.ForegroundColor = Get-ThemeColor "label"
        $this._detailsScrollPanel.AddChild($labelComp)
    }

    hidden [void] AddDetailText([string]$text, [int]$y) {
        $lines = $text -split "`n"
        $currentY = $y
        foreach ($line in $lines) {
            $textComp = [LabelComponent]::new("Text_$currentY")
            $textComp.Text = $line
            $textComp.X = 2
            $textComp.Y = $currentY
            $textComp.ForegroundColor = Get-ThemeColor "Foreground"
            $this._detailsScrollPanel.AddChild($textComp)
            $currentY++
        }
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "ProjectInfoScreen.OnEnter: Project: $($this._project.Name)"

        # Load and display tasks
        $tasks = $this._dataManager.GetTasksByProject($this._project.Key)
        $this._taskListbox.ClearItems()
        if ($tasks.Count -gt 0) {
            foreach ($task in $tasks) {
                $this._taskListbox.AddItem($task.ToString())
            }
        } else {
            $this._taskListbox.AddItem("No tasks associated with this project.")
        }
        $this._taskListbox.SelectedIndex = -1

        # Load and display files
        $this._fileListbox.ClearItems()
        $filesFound = $false
        
        # Add special linked files first
        if ($this._project.CaaFileName) {
            $this._fileListbox.AddItem("📄 CAA File: $($this._project.CaaFileName)")
            $filesFound = $true
        }
        
        if ($this._project.RequestFileName) {
            $this._fileListbox.AddItem("📋 Request File: $($this._project.RequestFileName)")
            $filesFound = $true
        }
        
        if ($this._project.T2020FileName) {
            $this._fileListbox.AddItem("📊 T2020 File: $($this._project.T2020FileName)")
            $filesFound = $true
        }

        # List other files in the project folder
        if ($this._project.ProjectFolderPath -and (Test-Path $this._project.ProjectFolderPath -PathType Container)) {
            try {
                $linkedFiles = @($this._project.CaaFileName, $this._project.RequestFileName, $this._project.T2020FileName) | Where-Object { $_ }
                $files = Get-ChildItem -Path $this._project.ProjectFolderPath -File | Where-Object { 
                    $_.Name -notin $linkedFiles
                } | Select-Object -ExpandProperty Name

                if ($files.Count -gt 0) {
                    foreach ($file in $files) {
                        $this._fileListbox.AddItem("📁 $file")
                    }
                    $filesFound = $true
                }
            } catch {
                Write-Log -Level Warning -Message "ProjectInfoScreen: Could not list files in $($this._project.ProjectFolderPath): $($_.Exception.Message)"
                $this._fileListbox.AddItem("Error listing files: $($_.Exception.Message)")
            }
        }
        
        if (-not $filesFound) {
            $this._fileListbox.AddItem("No client documents found for this project.")
        }
        $this._fileListbox.SelectedIndex = -1
        
        # Set focus to the screen for keyboard navigation
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager) {
            $focusManager.SetFocus($this)
        }

        $this.RequestRedraw()
        ([Screen]$this).OnEnter()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }

        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                Write-Log -Level Debug -Message "ProjectInfoScreen.HandleInput: ESC pressed, navigating back."
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                    return $true
                }
            }
            ([ConsoleKey]::UpArrow) {
                $this._detailsScrollPanel.ScrollUp()
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                $this._detailsScrollPanel.ScrollDown()
                return $true
            }
            ([ConsoleKey]::PageUp) {
                $this._detailsScrollPanel.ScrollPageUp()
                return $true
            }
            ([ConsoleKey]::PageDown) {
                $this._detailsScrollPanel.ScrollPageDown()
                return $true
            }
        }
        
        return ([Screen]$this).HandleInput($keyInfo)
    }
}
