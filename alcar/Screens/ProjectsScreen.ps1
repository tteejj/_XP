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
        
        # Sample projects
        $this.Projects = [System.Collections.ArrayList]@(
            @{
                Name = "BOLT-AXIOM"
                Description = "Terminal UI Framework"
                TaskCount = 15
                CompletedCount = 8
                Color = [VT]::RGB(0, 255, 255)
            },
            @{
                Name = "Personal Website"
                Description = "Portfolio and blog"
                TaskCount = 8
                CompletedCount = 3
                Color = [VT]::RGB(255, 128, 0)
            },
            @{
                Name = "Learning"
                Description = "Courses and tutorials"
                TaskCount = 12
                CompletedCount = 10
                Color = [VT]::RGB(128, 255, 0)
            }
        )
        
        # Key bindings
        $this.InitializeKeyBindings()
        
        # Status bar
        $this.UpdateStatusBar()
    }
    
    [void] InitializeKeyBindings() {
        $this.BindKey([ConsoleKey]::UpArrow, { $this.NavigateUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.NavigateDown(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::LeftArrow, { 
            # In left pane, go back to main menu
            if ($this.Layout.FocusedPane -eq 0) {
                $this.Active = $false
            }
        })
        $this.BindKey([ConsoleKey]::Enter, { $this.OpenProject() })
        $this.BindKey([ConsoleKey]::RightArrow, { 
            # Right arrow opens project when in left pane
            if ($this.Layout.FocusedPane -eq 0) {
                $this.OpenProject()
            }
        })
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
    
    [string] RenderContent() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Clear background by drawing spaces everywhere
        for ($y = 1; $y -le $height; $y++) {
            $output += [VT]::MoveTo(1, $y)
            $output += " " * $width
        }
        
        $this.UpdateLeftPane()
        $this.UpdateMiddlePane()
        $this.UpdateRightPane()
        
        $output += $this.Layout.Render()
        return $output
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
        
        $project = $this.Projects[$this.SelectedIndex]
        
        # Project details
        $this.Layout.RightPane.Content.Add($project.Color + " ● " + [VT]::TextBright() + $project.Name) | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " " + ("─" * ($this.Layout.RightPane.Width - 3))) | Out-Null
        $this.Layout.RightPane.Content.Add("") | Out-Null
        
        # Description
        $this.Layout.RightPane.Content.Add([VT]::Text() + " " + $project.Description) | Out-Null
        $this.Layout.RightPane.Content.Add("") | Out-Null
        
        # Statistics
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Tasks: " + [VT]::Text() + $project.TaskCount) | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Completed: " + [VT]::Accent() + $project.CompletedCount) | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Remaining: " + [VT]::Warning() + ($project.TaskCount - $project.CompletedCount)) | Out-Null
        
        # Progress bar
        $this.Layout.RightPane.Content.Add("") | Out-Null
        $progress = if ($project.TaskCount -gt 0) { 
            ($project.CompletedCount / $project.TaskCount) 
        } else { 0 }
        
        $barWidth = 20
        $filled = [int]($progress * $barWidth)
        $bar = $project.Color + ("█" * $filled) + [VT]::TextDim() + ("░" * ($barWidth - $filled))
        
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
        # Would show add project dialog
        Write-Host "`nAdd project not implemented yet" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    
    [void] EditProject() {
        # Would show edit project dialog
        Write-Host "`nEdit project not implemented yet" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    
    [void] DeleteProject() {
        # Would show delete confirmation
        Write-Host "`nDelete project not implemented yet" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}