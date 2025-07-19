# ProjectService - Business logic for project management
# Lightweight service focusing on project-related operations

class ProjectService {
    hidden [System.Collections.ArrayList]$Projects = [System.Collections.ArrayList]::new()
    hidden [string]$DataFile = "$HOME/.alcar/projects.json"
    
    ProjectService() {
        $this.LoadProjects()
    }
    
    [void] LoadProjects() {
        if (Test-Path $this.DataFile) {
            try {
                $json = Get-Content $this.DataFile -Raw
                $data = $json | ConvertFrom-Json
                $this.Projects.Clear()
                foreach ($projData in $data) {
                    $project = [Project]::new($projData.Name)
                    $project.Description = $projData.Description
                    $project.Id = $projData.Id
                    $this.Projects.Add($project) | Out-Null
                }
            }
            catch {
                Write-Error "Failed to load projects: $_"
            }
        }
        
        # Ensure default project exists
        if (-not ($this.Projects | Where-Object { $_.Name -eq "Default" })) {
            $default = [Project]::new("Default")
            $default.Description = "Default project for uncategorized tasks"
            $this.Projects.Add($default) | Out-Null
            $this.SaveProjects()
        }
    }
    
    [void] SaveProjects() {
        $dir = Split-Path $this.DataFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        $data = @()
        foreach ($project in $this.Projects) {
            $data += @{
                Id = $project.Id
                Name = $project.Name
                Description = $project.Description
            }
        }
        
        $json = $data | ConvertTo-Json -Depth 10
        Set-Content -Path $this.DataFile -Value $json
    }
    
    [Project[]] GetAllProjects() {
        return $this.Projects.ToArray()
    }
    
    [Project] GetProject([string]$id) {
        return $this.Projects | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    }
    
    [Project] GetProjectByName([string]$name) {
        return $this.Projects | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    }
    
    [Project] AddProject([string]$name) {
        # Check if already exists
        $existing = $this.GetProjectByName($name)
        if ($existing) {
            return $existing
        }
        
        $project = [Project]::new($name)
        $this.Projects.Add($project) | Out-Null
        $this.SaveProjects()
        return $project
    }
    
    [void] UpdateProject([Project]$project) {
        $this.SaveProjects()
    }
    
    [void] DeleteProject([string]$id) {
        $project = $this.GetProject($id)
        if ($project -and $project.Name -ne "Default") {
            $this.Projects.Remove($project)
            $this.SaveProjects()
        }
    }
    
    [hashtable[]] GetProjectsWithStats([object]$taskService) {
        $result = @()
        
        foreach ($project in $this.Projects) {
            $tasks = $taskService.GetTasksByProject($project.Name)
            $completed = ($tasks | Where-Object { $_.Status -eq "Done" }).Count
            $total = $tasks.Count
            
            $result += @{
                Project = $project
                Name = $project.Name
                TaskCount = $total
                CompletedCount = $completed
                Progress = if ($total -gt 0) { $completed / $total } else { 0 }
            }
        }
        
        return $result
    }
}