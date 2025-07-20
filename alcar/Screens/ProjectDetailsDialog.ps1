# ProjectDetailsDialog - Show full project information

class ProjectDetailsDialog : Dialog {
    [object]$Project
    [object]$ParentScreen
    
    ProjectDetailsDialog([object]$parent, [object]$project) : base("PROJECT DETAILS", "") {
        $this.ParentScreen = $parent
        $this.Project = $project
        $this.DialogWidth = 70
        $this.DialogHeight = 25
        
        $this.BindKeys()
    }
    
    [void] BindKeys() {
        $this.BindKey([ConsoleKey]::Escape, { $this.Close() })
        $this.BindKey([ConsoleKey]::Enter, { $this.Close() })
        $this.BindKey([ConsoleKey]::F, { $this.OpenFolder() })
        $this.BindKey([ConsoleKey]::E, { $this.EditProject() })
    }
    
    [void] OpenFolder() {
        if ($this.Project.ProjectPath -and (Test-Path $this.Project.ProjectPath)) {
            try {
                $os = [System.Environment]::OSVersion.Platform
                if ($os -eq [System.PlatformID]::Win32NT) {
                    Start-Process "explorer.exe" -ArgumentList $this.Project.ProjectPath
                } elseif ($os -eq [System.PlatformID]::Unix) {
                    if (Test-Path "/usr/bin/xdg-open") {
                        Start-Process "xdg-open" -ArgumentList $this.Project.ProjectPath
                    } elseif (Test-Path "/usr/bin/open") {
                        Start-Process "open" -ArgumentList $this.Project.ProjectPath
                    } else {
                        Write-Host "Project folder: $($this.Project.ProjectPath)"
                    }
                } else {
                    Write-Host "Project folder: $($this.Project.ProjectPath)"
                }
            } catch {
                Write-Warning "Failed to open project folder: $($_.Exception.Message)"
            }
        }
    }
    
    [void] EditProject() {
        $this.Close()
        # Trigger edit on parent screen
        if ($this.ParentScreen -and $this.ParentScreen.GetType().Name -eq "ProjectsScreenNew") {
            $this.ParentScreen.EditProject()
        }
    }
    
    [string] RenderContent() {
        $output = ([Dialog]$this).RenderContent()
        
        $x = $this.DialogX + 2
        $y = $this.DialogY + 2
        
        # Project information
        $dateAssigned = if ($this.Project.DateCreated) { $this.Project.DateCreated.ToString("yyyy-MM-dd") } else { "N/A" }
        $budget = if ($this.Project.Budget) { "$" + $this.Project.Budget.ToString("N2") } else { "N/A" }
        $hoursEstimate = if ($this.Project.EstimatedHours) { $this.Project.EstimatedHours.ToString() + "h" } else { "N/A" }
        $created = if ($this.Project.CreatedDate) { $this.Project.CreatedDate.ToString("yyyy-MM-dd HH:mm") } else { "N/A" }
        $modified = if ($this.Project.ModifiedDate) { $this.Project.ModifiedDate.ToString("yyyy-MM-dd HH:mm") } else { "N/A" }
        
        $fields = @(
            @("ID1 (GUID):", $this.Project.ID),
            @("ID2 (Code):", $this.Project.ProjectCode),
            @("Name:", $this.Project.Name),
            @("Description:", $this.Project.Description),
            @("Project Path:", $this.Project.ProjectPath),
            @("Date Assigned:", $dateAssigned),
            @("Status:", $this.Project.Status),
            @("Priority:", $this.Project.Priority),
            @("Client:", $this.Project.ClientName),
            @("Budget:", $budget),
            @("Hours Estimate:", $hoursEstimate),
            @("Created:", $created),
            @("Modified:", $modified)
        )
        
        foreach ($field in $fields) {
            $output += [VT]::MoveTo($x, $y)
            $output += [VT]::TextBright() + [Measure]::Pad($field[0], 16) + [VT]::Reset()
            $output += [VT]::Text() + $field[1] + [VT]::Reset()
            $y++
            
            # Add spacing for description and path
            if ($field[0] -eq "Description:" -or $field[0] -eq "Project Path:") {
                if ($field[1] -and $field[1].Length -gt 50) {
                    # Wrap long text
                    $wrapped = $field[1] -split "(.{50})" | Where-Object { $_ }
                    for ($i = 1; $i -lt $wrapped.Count; $i++) {
                        $output += [VT]::MoveTo($x + 16, $y)
                        $output += [VT]::Text() + $wrapped[$i] + [VT]::Reset()
                        $y++
                    }
                }
                $y++ # Extra spacing
            }
        }
        
        # Instructions
        $y = $this.DialogY + $this.DialogHeight - 3
        $output += [VT]::MoveTo($x, $y)
        $output += [VT]::TextDim() + "F: Open Folder | E: Edit | Enter/Esc: Close" + [VT]::Reset()
        
        return $output
    }
}