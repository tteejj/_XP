# Projects Screen - Simple table view with ID1, ID2, Name columns

class ProjectsScreenNew : Screen {
    [System.Collections.ArrayList]$Projects
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [object]$ProjectService
    
    ProjectsScreenNew() {
        $this.Title = "PROJECTS"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Initialize service
        try {
            $this.ProjectService = [ProjectService]::new()
        } catch {
            Write-Warning "Failed to initialize ProjectService: $($_.Exception.Message)"
            $this.ProjectService = $null
        }
        
        $this.LoadProjects()
        $this.BindKeys()
    }
    
    [void] BindKeys() {
        # Navigation
        $this.BindKey([ConsoleKey]::UpArrow, { $this.NavigateUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.NavigateDown(); $this.RequestRender() })
        
        # Actions
        $this.BindKey([ConsoleKey]::Enter, { $this.OpenProject() })
        $this.BindKey([ConsoleKey]::Spacebar, { $this.ViewProjectDetails() })
        $this.BindKey([ConsoleKey]::F, { $this.OpenProjectFolder() })
        
        # CRUD
        $this.BindKey([ConsoleKey]::N, { $this.NewProject() })
        $this.BindKey([ConsoleKey]::E, { $this.EditProject() })
        $this.BindKey([ConsoleKey]::D, { $this.DeleteProject() })
        
        # Exit
        $this.BindKey([ConsoleKey]::Escape, { $this.Active = $false })
        $this.BindKey([ConsoleKey]::Q, { $this.Active = $false })
    }
    
    [void] LoadProjects() {
        if ($this.ProjectService) {
            try {
                $this.Projects = $this.ProjectService.GetAllProjects()
                if (-not $this.Projects) { $this.Projects = [System.Collections.ArrayList]::new() }
            } catch {
                Write-Warning "Failed to load projects: $($_.Exception.Message)"
                $this.Projects = [System.Collections.ArrayList]::new()
            }
        } else {
            $this.Projects = [System.Collections.ArrayList]::new()
        }
        
        # Reset selection
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
    }
    
    [string] RenderContent() {
        $output = ""
        
        # Clear screen
        $output += [VT]::Clear()
        
        # Header
        $output += [VT]::MoveTo(2, 2)
        $output += [VT]::TextBright() + "PROJECTS" + [VT]::Reset()
        
        # Table header
        $headerY = 4
        $output += [VT]::MoveTo(2, $headerY)
        $output += [VT]::TextBright() + [Measure]::Pad("ID1", 12) + " " + [Measure]::Pad("ID2", 20) + " " + [Measure]::Pad("NAME", 30) + [VT]::Reset()
        
        $output += [VT]::MoveTo(2, $headerY + 1)
        $output += [VT]::Border() + "─" * 12 + " " + "─" * 20 + " " + "─" * 30 + [VT]::Reset()
        
        # Project list
        $startY = $headerY + 2
        $listHeight = 20
        
        for ($i = 0; $i -lt $listHeight; $i++) {
            $projectIndex = $i + $this.ScrollOffset
            $y = $startY + $i
            
            $output += [VT]::MoveTo(2, $y)
            
            if ($projectIndex -lt $this.Projects.Count) {
                $project = $this.Projects[$projectIndex]
                
                # Get project info
                $id1 = if ($project.ID) { $project.ID.Substring(0, [Math]::Min(10, $project.ID.Length)) } else { "N/A" }
                $id2 = if ($project.ProjectCode) { $project.ProjectCode } else { "N/A" }
                $name = if ($project.Name) { $project.Name } else { "Unnamed" }
                
                $projectLine = [Measure]::Pad($id1, 12) + " " + [Measure]::Pad($id2, 20) + " " + [Measure]::Pad($name, 30)
                
                # Highlight selected item
                if ($projectIndex -eq $this.SelectedIndex) {
                    $output += [VT]::Selected() + $projectLine + [VT]::Reset()
                } else {
                    $output += [VT]::Text() + $projectLine + [VT]::Reset()
                }
            }
            
            $output += [VT]::ClearLine()
        }
        
        # Status/Help
        $statusY = $startY + $listHeight + 2
        $output += [VT]::MoveTo(2, $statusY)
        $output += [VT]::TextDim() + "Enter: Open | Space: Details | F: Open Folder | N: New | E: Edit | D: Delete | Esc: Exit" + [VT]::Reset()
        
        # Project count
        $output += [VT]::MoveTo(2, $statusY + 1)
        $output += [VT]::TextDim() + "Projects: $($this.Projects.Count)" + [VT]::Reset()
        
        return $output
    }
    
    # Navigation methods
    [void] NavigateDown() {
        if ($this.Projects.Count -gt 0 -and $this.SelectedIndex -lt $this.Projects.Count - 1) {
            $this.SelectedIndex++
            $this.EnsureVisible()
        }
    }
    
    [void] NavigateUp() {
        if ($this.Projects.Count -gt 0 -and $this.SelectedIndex -gt 0) {
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
    
    # Action methods
    [void] OpenProject() {
        if ($this.GetSelectedProject()) {
            $project = $this.GetSelectedProject()
            Write-Host "Opening project: $($project.Name)"
            # TODO: Implement project opening logic
        }
    }
    
    [void] ViewProjectDetails() {
        if ($this.GetSelectedProject()) {
            $project = $this.GetSelectedProject()
            $dialog = New-Object ProjectDetailsDialog -ArgumentList $this, $project
            $global:ScreenManager.PushModal($dialog)
        }
    }
    
    [void] OpenProjectFolder() {
        if ($this.GetSelectedProject()) {
            $project = $this.GetSelectedProject()
            if ($project.ProjectPath -and (Test-Path $project.ProjectPath)) {
                try {
                    # Open folder in system file manager
                    $os = [System.Environment]::OSVersion.Platform
                    if ($os -eq [System.PlatformID]::Win32NT) {
                        Start-Process "explorer.exe" -ArgumentList $project.ProjectPath
                    } elseif ($os -eq [System.PlatformID]::Unix) {
                        if (Test-Path "/usr/bin/xdg-open") {
                            Start-Process "xdg-open" -ArgumentList $project.ProjectPath
                        } elseif (Test-Path "/usr/bin/open") {
                            Start-Process "open" -ArgumentList $project.ProjectPath
                        } else {
                            Write-Host "Project folder: $($project.ProjectPath)"
                        }
                    } else {
                        Write-Host "Project folder: $($project.ProjectPath)"
                    }
                } catch {
                    Write-Warning "Failed to open project folder: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "Project folder not found or not set"
            }
        }
    }
    
    [void] NewProject() {
        $service = if ($this.ProjectService) { $this.ProjectService } else { $global:ServiceContainer.GetService("ProjectService") }
        $dialog = New-Object ProjectCreationDialog -ArgumentList $service
        $global:ScreenManager.PushModal($dialog)
        
        if ($dialog.Result -eq [DialogResult]::OK) {
            $this.LoadProjects()
            $this.RequestRender()
        }
    }
    
    [void] EditProject() {
        if ($this.GetSelectedProject()) {
            $project = $this.GetSelectedProject()
            $dialog = New-Object ProjectCreationDialog -ArgumentList $this.ProjectService, $project
            $dialog | Add-Member -NotePropertyName IsEdit -NotePropertyValue $true
            $global:ScreenManager.PushModal($dialog)
            
            if ($dialog.Result -eq [DialogResult]::OK) {
                $this.LoadProjects()
                $this.RequestRender()
            }
        }
    }
    
    [void] DeleteProject() {
        if ($this.GetSelectedProject()) {
            $project = $this.GetSelectedProject()
            $message = "Delete project '$($project.Name)'?`nThis action cannot be undone."
            
            $dialog = New-Object ConfirmDialog -ArgumentList $this, "DELETE PROJECT", $message
            $global:ScreenManager.PushModal($dialog)
            
            if ($dialog.Result -eq [DialogResult]::Yes) {
                $this.ProjectService.DeleteProject($project.ID)
                $this.LoadProjects()
                
                # Adjust selection if needed
                if ($this.SelectedIndex -ge $this.Projects.Count) {
                    $this.SelectedIndex = [Math]::Max(0, $this.Projects.Count - 1)
                }
                $this.EnsureVisible()
                $this.RequestRender()
            }
        }
    }
    
    [object] GetSelectedProject() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Projects.Count) {
            return $this.Projects[$this.SelectedIndex]
        }
        return $null
    }
}