# Projects Screen

class ProjectsScreen : Screen {
    [System.Collections.ArrayList]$Projects
    [int]$SelectedIndex = 0
    [ThreePaneLayout]$Layout
    
    ProjectsScreen() {
        $this.Title = "PROJECTS"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Setup layout
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        $this.Layout = [ThreePaneLayout]::new($width, $height, 25, 30)
        $this.Layout.LeftPane.Title = "PROJECTS"
        $this.Layout.MiddlePane.Title = "TASKS"
        $this.Layout.RightPane.Title = "DETAILS"
        
        # Start with left pane focused
        $this.Layout.SetFocus(0)
        
        # Load actual projects from service
        $this.LoadProjects()
        
        # Key bindings
        $this.InitializeKeyBindings()
        
        # Status bar
        $this.UpdateStatusBar()
    }
    
    [void] InitializeKeyBindings() {
        # STANDARDIZED NAVIGATION:
        # Up/Down: Navigate within current pane
        $this.BindKey([ConsoleKey]::UpArrow, { $this.NavigateUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.NavigateDown(); $this.RequestRender() })
        
        # Left/Right: Move between panes
        $this.BindKey([ConsoleKey]::LeftArrow, { 
            if ($this.Layout.FocusedPane -gt 0) {
                $this.Layout.SetFocus($this.Layout.FocusedPane - 1)
                $this.RequestRender()
            } else {
                # In leftmost pane, go back to main menu
                $this.Active = $false
            }
        })
        $this.BindKey([ConsoleKey]::RightArrow, { 
            if ($this.Layout.FocusedPane -lt 2) {
                $this.Layout.SetFocus($this.Layout.FocusedPane + 1) 
                $this.RequestRender()
            } else {
                # In rightmost pane, open project
                $this.OpenProject()
            }
        })
        
        # Standard actions
        $this.BindKey([ConsoleKey]::Enter, { $this.OpenProject() })
        $this.BindKey([ConsoleKey]::Escape, { $this.Active = $false })
        $this.BindKey([ConsoleKey]::Backspace, { $this.Active = $false })
        
        $this.BindKey('a', { $this.AddProject() })
        $this.BindKey('e', { $this.EditProject() })
        $this.BindKey('d', { $this.DeleteProject() })
        $this.BindKey('q', { $this.Active = $false })
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        $this.AddStatusItem('↑↓', 'navigate')
        $this.AddStatusItem('Enter', 'open')
        $this.AddStatusItem('a', 'add')
        $this.AddStatusItem('e', 'edit')
        $this.AddStatusItem('d', 'delete')
        $this.AddStatusItem('Esc', 'back')
    }
    
    # Fast string rendering - maximum performance like TaskScreen  
    [string] RenderContent() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Clear background efficiently
        $output += [VT]::Clear()
        
        # Update all panes first
        $this.UpdateLeftPane()
        $this.UpdateMiddlePane()
        $this.UpdateRightPane()
        
        # Render layout in one pass
        $output += $this.Layout.Render()
        
        return $output
    }
    
    [void] LoadProjects() {
        try {
            $projectService = $global:ServiceContainer.GetService("ProjectService")
            $taskService = $global:ServiceContainer.GetService("TaskService")
            $projectsWithStats = $projectService.GetProjectsWithStats($taskService)
            
            $this.Projects = [System.Collections.ArrayList]::new()
            
            foreach ($projStat in $projectsWithStats) {
                $project = $projStat.Project
                
                # Generate color based on project status
                $color = [VT]::RGB(0, 255, 255)  # Default cyan
                if ($project.Deleted) {
                    $color = [VT]::RGB(128, 128, 128)  # Gray for deleted
                } elseif ($project.ClosedDate -and $project.ClosedDate -ne [DateTime]::MinValue) {
                    $color = [VT]::RGB(0, 255, 0)  # Green for completed
                } elseif ($project.DateDue -lt [DateTime]::Now) {
                    $color = [VT]::RGB(255, 0, 0)  # Red for overdue
                } elseif ($project.DateDue -lt [DateTime]::Now.AddDays(7)) {
                    $color = [VT]::RGB(255, 255, 0)  # Yellow for due soon
                }
                
                $projectDisplay = @{
                    Name = $project.Nickname
                    FullName = $project.FullProjectName
                    Description = $project.Note
                    TaskCount = $projStat.TaskCount
                    CompletedCount = $projStat.CompletedCount
                    Color = $color
                    Project = $project  # Store the full project object
                }
                
                $this.Projects.Add($projectDisplay) | Out-Null
            }
            
            # Ensure we have at least the default project
            if ($this.Projects.Count -eq 0) {
                $defaultProject = @{
                    Name = "Default"
                    FullName = "Default Project"
                    Description = "No projects available"
                    TaskCount = 0
                    CompletedCount = 0
                    Color = [VT]::RGB(128, 128, 128)
                    Project = $null
                }
                $this.Projects.Add($defaultProject) | Out-Null
            }
        }
        catch {
            Write-Error "Failed to load projects: $_"
        }
    }
    
    [void] UpdateLeftPane() {
        $this.Layout.LeftPane.Content.Clear()
        
        for ($i = 0; $i -lt $this.Projects.Count; $i++) {
            $project = $this.Projects[$i]
            $isSelected = $i -eq $this.SelectedIndex
            
            $line = ""
            if ($isSelected) {
                $line += [VT]::Selected() + " > "
            } else {
                $line += "   "
            }
            
            # Project name with color
            $line += $project.Color + "●" + [VT]::Reset() + " "
            $line += [VT]::TextBright() + $project.Name
            
            # Progress - only show if there's space
            $progress = if ($project.TaskCount -gt 0) { 
                [int](($project.CompletedCount / $project.TaskCount) * 100) 
            } else { 0 }
            
            $progressText = " $progress%"
            $availableWidth = $this.Layout.LeftPane.Width - 8  # Account for selection marker and padding
            $nameAndProgressLength = $project.Name.Length + $progressText.Length + 2  # +2 for bullet and space
            
            if ($nameAndProgressLength -le $availableWidth) {
                # Only add progress if it fits
                $padding = $availableWidth - $project.Name.Length - $progressText.Length - 2
                if ($padding -gt 0) {
                    $line += " " * $padding
                }
                
                if ($progress -eq 100) {
                    $line += [VT]::Accent() + $progressText
                } elseif ($progress -gt 50) {
                    $line += [VT]::Warning() + $progressText
                } else {
                    $line += [VT]::TextDim() + $progressText
                }
            }
            
            $line += [VT]::Reset()
            $this.Layout.LeftPane.Content.Add($line) | Out-Null
        }
    }
    
    [void] UpdateMiddlePane() {
        $this.Layout.MiddlePane.Content.Clear()
        
        if ($this.Projects.Count -eq 0) {
            $this.Layout.MiddlePane.Content.Add([VT]::TextDim() + " No projects") | Out-Null
            return
        }
        
        $project = $this.Projects[$this.SelectedIndex]
        $this.Layout.MiddlePane.Title = "TASKS - " + $project.Name
        
        # Sample tasks for the selected project
        $tasks = @(
            "Setup project structure",
            "Implement core features",
            "Write documentation",
            "Add unit tests",
            "Performance optimization"
        )
        
        foreach ($task in $tasks) {
            $line = " " + [VT]::TextDim() + "○ " + [VT]::Text() + $task
            $this.Layout.MiddlePane.Content.Add($line) | Out-Null
        }
    }
    
    [void] UpdateRightPane() {
        $this.Layout.RightPane.Content.Clear()
        
        if ($this.Projects.Count -eq 0) {
            return
        }
        
        $projectDisplay = $this.Projects[$this.SelectedIndex]
        $project = $projectDisplay.Project
        
        # Project header
        $this.Layout.RightPane.Content.Add($projectDisplay.Color + " ● " + [VT]::TextBright() + $projectDisplay.Name) | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " " + ("─" * ($this.Layout.RightPane.Width - 3))) | Out-Null
        $this.Layout.RightPane.Content.Add("") | Out-Null
        
        if ($project) {
            # PMC-style project details
            $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Full Name: " + [VT]::Text() + $project.FullProjectName) | Out-Null
            $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Nickname: " + [VT]::Text() + $project.Nickname) | Out-Null
            
            if ($project.ID1) {
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " ID1: " + [VT]::Text() + $project.ID1) | Out-Null
            }
            if ($project.ID2) {
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " ID2: " + [VT]::Text() + $project.ID2) | Out-Null
            }
            
            $this.Layout.RightPane.Content.Add("") | Out-Null
            
            # Dates
            $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Assigned: " + [VT]::Text() + $project.DateAssigned.ToString("yyyy-MM-dd")) | Out-Null
            $this.Layout.RightPane.Content.Add([VT]::TextDim() + " BF Date: " + [VT]::Text() + $project.BFDate.ToString("yyyy-MM-dd")) | Out-Null
            
            # Due date with color coding
            $dueColor = [VT]::Text()
            if ($project.DateDue -lt [DateTime]::Now) {
                $dueColor = [VT]::RGB(255, 0, 0)  # Red for overdue
            } elseif ($project.DateDue -lt [DateTime]::Now.AddDays(7)) {
                $dueColor = [VT]::RGB(255, 255, 0)  # Yellow for due soon
            }
            $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Due Date: " + $dueColor + $project.DateDue.ToString("yyyy-MM-dd")) | Out-Null
            
            if ($project.ClosedDate -and $project.ClosedDate -ne [DateTime]::MinValue) {
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Closed: " + [VT]::Accent() + $project.ClosedDate.ToString("yyyy-MM-dd")) | Out-Null
            }
            
            $this.Layout.RightPane.Content.Add("") | Out-Null
            
            # Time tracking
            if ($project.CumulativeHrs -gt 0) {
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Hours: " + [VT]::Text() + $project.CumulativeHrs) | Out-Null
            }
            
            # File paths
            if ($project.CAAPath) {
                $fileName = Split-Path $project.CAAPath -Leaf
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " CAA: " + [VT]::Text() + $fileName) | Out-Null
            }
            if ($project.RequestPath) {
                $fileName = Split-Path $project.RequestPath -Leaf
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Request: " + [VT]::Text() + $fileName) | Out-Null
            }
            if ($project.T2020Path) {
                $fileName = Split-Path $project.T2020Path -Leaf
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " T2020: " + [VT]::Text() + $fileName) | Out-Null
            }
            
            # Note
            if ($project.Note) {
                $this.Layout.RightPane.Content.Add("") | Out-Null
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Note:") | Out-Null
                
                # Word wrap note text
                $maxWidth = $this.Layout.RightPane.Width - 4
                $words = $project.Note -split '\s+'
                $currentLine = " "
                
                foreach ($word in $words) {
                    if (($currentLine + $word).Length -gt $maxWidth) {
                        $this.Layout.RightPane.Content.Add([VT]::Text() + $currentLine) | Out-Null
                        $currentLine = " " + $word
                    } else {
                        $currentLine += " " + $word
                    }
                }
                if ($currentLine.Trim()) {
                    $this.Layout.RightPane.Content.Add([VT]::Text() + $currentLine) | Out-Null
                }
            }
        } else {
            # Fallback for legacy projects
            $this.Layout.RightPane.Content.Add([VT]::Text() + " " + $projectDisplay.Description) | Out-Null
        }
        
        # Task statistics
        $this.Layout.RightPane.Content.Add("") | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Tasks: " + [VT]::Text() + $projectDisplay.TaskCount) | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Completed: " + [VT]::Accent() + $projectDisplay.CompletedCount) | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Remaining: " + [VT]::Warning() + ($projectDisplay.TaskCount - $projectDisplay.CompletedCount)) | Out-Null
        
        # Progress bar
        $this.Layout.RightPane.Content.Add("") | Out-Null
        $progress = if ($projectDisplay.TaskCount -gt 0) { 
            ($projectDisplay.CompletedCount / $projectDisplay.TaskCount) 
        } else { 0 }
        
        $barWidth = 20
        $filled = [int]($progress * $barWidth)
        $bar = $projectDisplay.Color + ("█" * $filled) + [VT]::TextDim() + ("░" * ($barWidth - $filled))
        
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Progress: " + $bar + [VT]::Reset() + " " + ([int]($progress * 100)) + "%") | Out-Null
    }
    
    [void] NavigateUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
        }
    }
    
    [void] NavigateDown() {
        if ($this.SelectedIndex -lt $this.Projects.Count - 1) {
            $this.SelectedIndex++
        }
    }
    
    [void] OpenProject() {
        # Would open project-specific task view
        # For now, just go to task screen
        if ($global:ScreenManager) {
            $screen = New-Object TaskScreen
            $global:ScreenManager.Push($screen)
        }
    }
    
    [void] AddProject() {
        # Open guided project creation dialog with alternate buffer
        $projectService = $global:ServiceContainer.GetService("ProjectService")
        $screen = New-Object ProjectCreationDialog -ArgumentList $projectService
        $global:ScreenManager.PushModal($screen)
        
        # Refresh projects list when we return
        $this.LoadProjects()
    }
    
    [void] EditProject() {
        if ($this.Projects.Count -gt 0 -and $this.Layout.FocusedPane -eq 0) {
            $selectedProject = $this.Projects[$this.SelectedIndex]
            
            # Create edit dialog (reuse project creation dialog)
            $dialog = New-Object ProjectCreationDialog -ArgumentList $this, $selectedProject
            $dialog | Add-Member -NotePropertyName IsEdit -NotePropertyValue $true
            $dialog | Add-Member -NotePropertyName ParentProjectScreen -NotePropertyValue $this
            
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] DeleteProject() {
        if ($this.Projects.Count -gt 0 -and $this.Layout.FocusedPane -eq 0) {
            $selectedProject = $this.Projects[$this.SelectedIndex]
            
            # Create simple confirmation dialog
            $dialog = New-Object ConfirmDialog -ArgumentList $this, "Delete Project", "Are you sure you want to delete project '$($selectedProject.Name)'?"
            $dialog | Add-Member -NotePropertyName ProjectToDelete -NotePropertyValue $selectedProject
            $dialog | Add-Member -NotePropertyName ParentProjectScreen -NotePropertyValue $this
            
            $global:ScreenManager.Push($dialog)
        }
    }
}