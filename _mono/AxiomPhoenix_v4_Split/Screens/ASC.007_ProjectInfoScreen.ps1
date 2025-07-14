# ==============================================================================
# Axiom-Phoenix v4.0 - Project Info Screen
# FIXED: Removed FocusManager dependency, simplified input handling
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

    ProjectInfoScreen([object]$serviceContainer) : base("ProjectInfoScreen", $serviceContainer) {
        $this._dataManager = $serviceContainer.GetService("DataManager")
        Write-Log -Level Debug -Message "ProjectInfoScreen: Constructor called"
    }

    # Method to set the project after construction
    [void] SetProject([PmcProject]$project) {
        if ($null -eq $project) {
            throw [System.ArgumentNullException]::new("project", "Project must be provided to ProjectInfoScreen.")
        }
        $this._project = $project
        $this.Title = " Project: $($project.Name) "
    }

    [void] Initialize() {
        Write-Log -Level Debug -Message "ProjectInfoScreen.Initialize: Starting"
        
        if ($null -eq $this._project) {
            Write-Log -Level Error -Message "ProjectInfoScreen.Initialize: Project not set!"
            throw "Project must be set before Initialize"
        }
        
        # Main panel covering the whole screen
        $this._mainPanel = [Panel]::new("ProjectMainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Project Details: $($this._project.Name) "
        $this._mainPanel.BorderColor = Get-ThemeColor "Panel.Border" "#00d4ff"
        $this._mainPanel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
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
        $this._detailsScrollPanel.BorderColor = Get-ThemeColor "Panel.Border" "#666666"
        $this._detailsScrollPanel.ShowScrollbar = $true
        $this._mainPanel.AddChild($this._detailsScrollPanel)

        # Tasks Panel (right side)
        $this._tasksPanel = [Panel]::new("ProjectTasksPanel")
        $this._tasksPanel.X = $detailsWidth + 2
        $this._tasksPanel.Y = 1
        $this._tasksPanel.Width = $rightPanelWidth
        $this._tasksPanel.Height = $tasksHeight
        $this._tasksPanel.Title = " Associated Tasks "
        $this._tasksPanel.BorderColor = Get-ThemeColor "Panel.Border" "#666666"
        $this._mainPanel.AddChild($this._tasksPanel)

        # Files Panel (right side, below tasks)
        $this._filesPanel = [Panel]::new("ProjectFilesPanel")
        $this._filesPanel.X = $detailsWidth + 2
        $this._filesPanel.Y = $filesY
        $this._filesPanel.Width = $rightPanelWidth
        $this._filesPanel.Height = $filesHeight
        $this._filesPanel.Title = " Client Documents "
        $this._filesPanel.BorderColor = Get-ThemeColor "Panel.Border" "#666666"
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
            $daysUntil = ($this._project.BFDate - [DateTime]::Now).Days
            $dueDateText = $this._project.BFDate.ToString("yyyy-MM-dd")
            
            if ($daysUntil -lt 0) {
                $dueDateText += " (OVERDUE!)"
                $this.AddDetailField("Due Date (BF):", $dueDateText, $y, "#FF4444")
            } elseif ($daysUntil -eq 0) {
                $dueDateText += " (TODAY)"
                $this.AddDetailField("Due Date (BF):", $dueDateText, $y, "#FFA500")
            } elseif ($daysUntil -le 7) {
                $dueDateText += " ($daysUntil days)"
                $this.AddDetailField("Due Date (BF):", $dueDateText, $y, "#FFD700")
            } else {
                $this.AddDetailField("Due Date (BF):", $dueDateText, $y)
            }
            $y += 2
        }
        
        $this.AddDetailField("Owner:", ($this._project.Owner -or "Unassigned"), $y)
        $y += 2
        
        $statusText = "Archived"
        $statusColor = Get-ThemeColor "subtle"
        if ($this._project.IsActive) { 
            $statusText = "Active"
            $statusColor = Get-ThemeColor "success"
        }
        $this.AddDetailField("Status:", $statusText, $y, $statusColor)
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
        $this._taskListbox.IsFocusable = $false  # We handle input directly
        $this._taskListbox.SelectedBackgroundColor = Get-ThemeColor "List.ItemSelectedBackground" "#007acc"
        $this._taskListbox.SelectedForegroundColor = Get-ThemeColor "List.ItemSelected" "#ffffff"
        $this._tasksPanel.AddChild($this._taskListbox)

        # Populate Files Listbox
        $this._fileListbox = [ListBox]::new("ProjectFileListBox")
        $this._fileListbox.X = 1
        $this._fileListbox.Y = 1
        $this._fileListbox.Width = $this._filesPanel.Width - 2
        $this._fileListbox.Height = $this._filesPanel.Height - 2
        $this._fileListbox.HasBorder = $false
        $this._fileListbox.IsFocusable = $false  # We handle input directly
        $this._fileListbox.SelectedBackgroundColor = Get-ThemeColor "List.ItemSelectedBackground" "#007acc"
        $this._fileListbox.SelectedForegroundColor = Get-ThemeColor "List.ItemSelected" "#ffffff"
        $this._filesPanel.AddChild($this._fileListbox)

        # Instructions
        $instructionText = "[↑↓] Scroll Details | [PgUp/PgDn] Page | [E] Edit | [Esc] Back"
        $instructionLabel = [LabelComponent]::new("InstructionLabel")
        $instructionLabel.Text = $instructionText
        $instructionLabel.X = 2
        $instructionLabel.Y = $this.Height - 2
        $instructionLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#666666"
        $this._mainPanel.AddChild($instructionLabel)

        Write-Log -Level Debug -Message "ProjectInfoScreen.Initialize: Completed"
    }

    hidden [void] AddDetailField([string]$label, [string]$value, [int]$y, [string]$valueColor = $null) {
        $labelComponent = [LabelComponent]::new("Label_$y")
        $labelComponent.Text = $label
        $labelComponent.X = 2
        $labelComponent.Y = $y
        $labelComponent.ForegroundColor = Get-ThemeColor "Label.Foreground" "#d4d4d4"
        $this._detailsScrollPanel.AddChild($labelComponent)

        $valueComponent = [LabelComponent]::new("Value_$y")
        $valueComponent.Text = $value
        $valueComponent.X = 25
        $valueComponent.Y = $y
        $valueComponent.ForegroundColor = if ($valueColor) { $valueColor } else { Get-ThemeColor "Label.Foreground" "#d4d4d4" }
        $this._detailsScrollPanel.AddChild($valueComponent)
    }

    hidden [void] AddDetailLabel([string]$label, [int]$y) {
        $labelComponent = [LabelComponent]::new("Label_$y")
        $labelComponent.Text = $label
        $labelComponent.X = 2
        $labelComponent.Y = $y
        $labelComponent.ForegroundColor = Get-ThemeColor "Label.Foreground" "#d4d4d4"
        $this._detailsScrollPanel.AddChild($labelComponent)
    }

    hidden [void] AddDetailText([string]$text, [int]$y) {
        # Word wrap the text
        $maxWidth = $this._detailsScrollPanel.ContentWidth - 4
        $lines = $this.WrapText($text, $maxWidth)
        
        $currentY = $y
        foreach ($line in $lines) {
            $textComponent = [LabelComponent]::new("Text_$currentY")
            $textComponent.Text = $line
            $textComponent.X = 2
            $textComponent.Y = $currentY
            $textComponent.ForegroundColor = Get-ThemeColor "Label.Foreground" "#d4d4d4"
            $this._detailsScrollPanel.AddChild($textComponent)
            $currentY++
        }
    }

    hidden [string[]] WrapText([string]$text, [int]$maxWidth) {
        $lines = @()
        $words = $text -split '\s+'
        $currentLine = ""
        
        foreach ($word in $words) {
            if (($currentLine + " " + $word).Length -gt $maxWidth) {
                if ($currentLine) {
                    $lines += $currentLine
                    $currentLine = $word
                } else {
                    # Word is longer than max width, break it
                    $lines += $word.Substring(0, $maxWidth)
                    $currentLine = $word.Substring($maxWidth)
                }
            } else {
                if ($currentLine) {
                    $currentLine = "$currentLine $word"
                } else {
                    $currentLine = $word
                }
            }
        }
        
        if ($currentLine) {
            $lines += $currentLine
        }
        
        return $lines
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "ProjectInfoScreen.OnEnter: Loading project data"
        
        # Populate Associated Tasks
        $this._taskListbox.ClearItems()
        $allTasks = $this._dataManager.GetTasks()
        $projectTasks = @($allTasks | Where-Object { $_.ProjectKey -eq $this._project.Key })
        
        if ($projectTasks.Count -gt 0) {
            foreach ($task in $projectTasks) {
                $statusIcon = switch ($task.Status) {
                    ([TaskStatus]::Pending) { "○" }
                    ([TaskStatus]::InProgress) { "◐" }
                    ([TaskStatus]::Completed) { "●" }
                    ([TaskStatus]::Cancelled) { "✕" }
                    default { "?" }
                }
                $taskText = "$statusIcon $($task.Title)"
                $this._taskListbox.AddItem($taskText)
            }
        } else {
            $this._taskListbox.AddItem("No tasks associated with this project.")
        }
        $this._taskListbox.SelectedIndex = -1

        # Populate Client Documents
        $this._fileListbox.ClearItems()
        $filesFound = $false

        if ($this._project.ProjectFolderPath -and (Test-Path $this._project.ProjectFolderPath)) {
            $files = Get-ChildItem -Path $this._project.ProjectFolderPath -File -CaseSensitive
            if ($files.Count -gt 0) {
                foreach ($file in $files) {
                    $fileText = "📄 $($file.Name)"
                    $this._fileListbox.AddItem($fileText)
                }
                $filesFound = $true
            }
        }
        
        # Check specific file properties
        if ($this._project.CaaFileName) {
            $this._fileListbox.AddItem("📋 CAA: $($this._project.CaaFileName)")
            $filesFound = $true
        }
        if ($this._project.RequestFileName) {
            $this._fileListbox.AddItem("📋 Request: $($this._project.RequestFileName)")
            $filesFound = $true
        }
        if ($this._project.T2020FileName) {
            $this._fileListbox.AddItem("📋 T2020: $($this._project.T2020FileName)")
            $filesFound = $true
        }
        
        if (-not $filesFound) {
            $this._fileListbox.AddItem("No client documents found for this project.")
        }
        $this._fileListbox.SelectedIndex = -1
        
        # No FocusManager needed - this is a display screen
        $this.RequestRedraw()
    }

    # === INPUT HANDLING (DIRECT, NO FOCUS MANAGER) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "ProjectInfoScreen.HandleInput: Null keyInfo"
            return $false
        }

        Write-Log -Level Debug -Message "ProjectInfoScreen.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)'"

        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                Write-Log -Level Debug -Message "ProjectInfoScreen: Navigating back"
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
            ([ConsoleKey]::UpArrow) {
                $this._detailsScrollPanel.ScrollUp()
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                $this._detailsScrollPanel.ScrollDown()
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::PageUp) {
                $this._detailsScrollPanel.ScrollPageUp()
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::PageDown) {
                $this._detailsScrollPanel.ScrollPageDown()
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Home) {
                $this._detailsScrollPanel.ScrollToTop()
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::End) {
                $this._detailsScrollPanel.ScrollToBottom()
                $this.RequestRedraw()
                return $true
            }
        }
        
        # Character shortcuts
        switch ($keyInfo.KeyChar) {
            'e' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    # Edit project
                    $navService = $this.ServiceContainer?.GetService("NavigationService")
                    if ($navService) {
                        $editDialog = [ProjectEditDialog]::new($this.ServiceContainer, $this._project)
                        $editDialog.Initialize()
                        $navService.NavigateTo($editDialog)
                    }
                    return $true
                }
            }
            'E' {
                # Edit project
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService) {
                    $editDialog = [ProjectEditDialog]::new($this.ServiceContainer, $this._project)
                    $editDialog.Initialize()
                    $navService.NavigateTo($editDialog)
                }
                return $true
            }
        }
        
        # Let base handle Tab and route to components - GUIDE PATTERN
        return ([Screen]$this).HandleInput($keyInfo)
    }
}

# ==============================================================================
# END OF PROJECT INFO SCREEN
# ==============================================================================