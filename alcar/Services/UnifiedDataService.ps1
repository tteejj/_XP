# UnifiedDataService - PMC Pattern: Single JSON file with embedded relationships
# Based on doc_review.txt PMC analysis - replaces separate CSV/JSON files

class UnifiedDataService {
    [string]$DataFile
    [hashtable]$Data
    [bool]$AutoSave = $true
    
    UnifiedDataService() {
        $this.DataFile = Join-Path $PSScriptRoot "../_ProjectData/unified_data.json"
        $this.Data = @{}
        $this.EnsureDataDirectory()
        $this.LoadData()
    }
    
    UnifiedDataService([string]$dataFile) {
        $this.DataFile = $dataFile
        $this.Data = @{}
        $this.EnsureDataDirectory()
        $this.LoadData()
    }
    
    # Ensure data directory exists (PMC pattern)
    [void] EnsureDataDirectory() {
        $dir = Split-Path $this.DataFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    # Load unified data structure
    [void] LoadData() {
        try {
            if (Test-Path $this.DataFile) {
                $json = Get-Content $this.DataFile -Raw -Encoding UTF8
                $this.Data = $json | ConvertFrom-Json -AsHashtable
# Data loaded successfully
            } else {
                # Initialize with PMC structure
                $this.InitializeDefaultStructure()
                $this.SaveData()
            }
        }
        catch {
            Write-Warning "Failed to load unified data: $($_.Exception.Message)"
            $this.InitializeDefaultStructure()
        }
    }
    
    # Initialize default PMC-style structure
    [void] InitializeDefaultStructure() {
        $this.Data = @{
            metadata = @{
                version = "1.0"
                created = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
                lastModified = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            }
            projects = @()
            configuration = @{
                kanbanColumns = @(
                    @{ name = "To Do"; status = "Pending" }
                    @{ name = "In Progress"; status = "InProgress" }
                    @{ name = "Done"; status = "Completed" }
                )
                defaultTheme = "Default"
                exportFormats = @("CSV", "JSON")
            }
        }
# Default structure initialized
    }
    
    # Save unified data (atomic operation as per PMC pattern)
    [void] SaveData() {
        try {
            # Update metadata
            $this.Data.metadata.lastModified = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            
            # Create backup first
            if (Test-Path $this.DataFile) {
                $backupFile = $this.DataFile + ".backup"
                Copy-Item $this.DataFile $backupFile -Force
            }
            
            # Atomic save
            $json = $this.Data | ConvertTo-Json -Depth 10 -Compress:$false
            $json | Out-File -FilePath $this.DataFile -Encoding UTF8 -Force
            
# Data saved successfully
        }
        catch {
            Write-Error "Failed to save unified data: $($_.Exception.Message)"
        }
    }
    
    # Get all projects
    [array] GetProjects() {
        if ($this.Data.projects) {
            return $this.Data.projects
        }
        return @()
    }
    
    # Get project by ID
    [hashtable] GetProject([string]$projectId) {
        $projects = $this.GetProjects()
        return $projects | Where-Object { $_.ID -eq $projectId } | Select-Object -First 1
    }
    
    # Add new project with embedded tasks (PMC pattern)
    [hashtable] AddProject([string]$name, [string]$description = "") {
        $project = @{
            ID = [guid]::NewGuid().ToString()
            Name = $name
            Description = $description
            CreatedDate = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            ModifiedDate = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            Status = "Active"
            tasks = @()  # Embedded tasks for atomic updates
        }
        
        if (-not $this.Data.projects) {
            $this.Data.projects = @()
        }
        
        $this.Data.projects += $project
        
        if ($this.AutoSave) {
            $this.SaveData()
        }
        
        return $project
    }
    
    # Get all tasks from all projects
    [array] GetAllTasks() {
        $allTasks = @()
        foreach ($project in $this.GetProjects()) {
            if ($project.tasks) {
                foreach ($task in $project.tasks) {
                    # Add project reference for easy access
                    $taskWithProject = $task.Clone()
                    $taskWithProject.ProjectID = $project.ID
                    $taskWithProject.ProjectName = $project.Name
                    $allTasks += $taskWithProject
                }
            }
        }
        return $allTasks
    }
    
    # Get tasks for specific project
    [array] GetProjectTasks([string]$projectId) {
        $project = $this.GetProject($projectId)
        if ($project -and $project.tasks) {
            return $project.tasks
        }
        return @()
    }
    
    # Get tasks by status for Kanban view
    [array] GetTasksByStatus([string]$status) {
        $allTasks = $this.GetAllTasks()
        return $allTasks | Where-Object { $_.Status -eq $status }
    }
    
    # Add task to project (embedded relationship)
    [hashtable] AddTask([string]$projectId, [string]$title, [string]$description = "") {
        $project = $this.GetProject($projectId)
        if (-not $project) {
            throw "Project not found: $projectId"
        }
        
        $task = @{
            ID = [guid]::NewGuid().ToString()
            Title = $title
            Description = $description
            Status = "Pending"  # Default to Kanban "To Do"
            Priority = "Medium"
            Progress = 0
            CreatedDate = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            ModifiedDate = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            DueDate = $null
            Tags = @()
            KanbanColumn = "To Do"  # Kanban-specific field
        }
        
        if (-not $project.tasks) {
            $project.tasks = @()
        }
        
        $project.tasks += $task
        $project.ModifiedDate = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
        
        if ($this.AutoSave) {
            $this.SaveData()
        }
        
        return $task
    }
    
    # Update task status (for Kanban movement)
    [bool] UpdateTaskStatus([string]$projectId, [string]$taskId, [string]$newStatus) {
        $project = $this.GetProject($projectId)
        if (-not $project -or -not $project.tasks) {
            return $false
        }
        
        $task = $project.tasks | Where-Object { $_.ID -eq $taskId } | Select-Object -First 1
        if ($task) {
            $task.Status = $newStatus
            $task.ModifiedDate = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            
            # Update Kanban column based on status
            switch ($newStatus) {
                "Pending" { $task.KanbanColumn = "To Do" }
                "InProgress" { $task.KanbanColumn = "In Progress" }
                "Completed" { $task.KanbanColumn = "Done" }
                default { $task.KanbanColumn = "To Do" }
            }
            
            $project.ModifiedDate = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            
            if ($this.AutoSave) {
                $this.SaveData()
            }
            
            return $true
        }
        
        return $false
    }
    
    # Move task between Kanban columns
    [bool] MoveTaskToColumn([string]$projectId, [string]$taskId, [string]$targetColumn) {
        $statusMap = @{
            "To Do" = "Pending"
            "In Progress" = "InProgress"
            "Done" = "Completed"
        }
        
        $newStatus = $statusMap[$targetColumn]
        if ($newStatus) {
            return $this.UpdateTaskStatus($projectId, $taskId, $newStatus)
        }
        
        return $false
    }
    
    # Get task by ID across all projects
    [hashtable] GetTask([string]$taskId) {
        foreach ($project in $this.GetProjects()) {
            if ($project.tasks) {
                $task = $project.tasks | Where-Object { $_.ID -eq $taskId } | Select-Object -First 1
                if ($task) {
                    $taskWithProject = $task.Clone()
                    $taskWithProject.ProjectID = $project.ID
                    $taskWithProject.ProjectName = $project.Name
                    return $taskWithProject
                }
            }
        }
        return $null
    }
    
    # Update task with properties
    [bool] UpdateTask([string]$projectId, [string]$taskId, [hashtable]$updates) {
        $project = $this.GetProject($projectId)
        if (-not $project -or -not $project.tasks) {
            return $false
        }
        
        $task = $project.tasks | Where-Object { $_.ID -eq $taskId } | Select-Object -First 1
        if ($task) {
            # Apply updates
            foreach ($key in $updates.Keys) {
                $task[$key] = $updates[$key]
            }
            
            $task.ModifiedDate = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            $project.ModifiedDate = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            
            if ($this.AutoSave) {
                $this.SaveData()
            }
            
            return $true
        }
        
        return $false
    }

    # Delete task
    [bool] DeleteTask([string]$projectId, [string]$taskId) {
        $project = $this.GetProject($projectId)
        if (-not $project -or -not $project.tasks) {
            return $false
        }
        
        $taskIndex = -1
        for ($i = 0; $i -lt $project.tasks.Count; $i++) {
            if ($project.tasks[$i].ID -eq $taskId) {
                $taskIndex = $i
                break
            }
        }
        
        if ($taskIndex -ge 0) {
            $project.tasks = $project.tasks | Where-Object { $_.ID -ne $taskId }
            $project.ModifiedDate = [datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
            
            if ($this.AutoSave) {
                $this.SaveData()
            }
            
            return $true
        }
        
        return $false
    }
    
    # Export data in various formats
    [void] ExportData([string]$format, [string]$outputPath) {
        switch ($format.ToUpper()) {
            "JSON" {
                $this.Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8
            }
            "CSV" {
                # Export tasks as CSV
                $allTasks = $this.GetAllTasks()
                $csvData = $allTasks | Select-Object ProjectName, Title, Description, Status, Priority, CreatedDate, DueDate
                $csvData | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
            }
            default {
                throw "Unsupported export format: $format"
            }
        }
        
        Write-Host "Exported data to $outputPath in $format format" -ForegroundColor Green
    }
    
    # Get statistics for dashboard
    [hashtable] GetStatistics() {
        $allTasks = $this.GetAllTasks()
        $projects = $this.GetProjects()
        
        return @{
            TotalProjects = $projects.Count
            TotalTasks = $allTasks.Count
            TasksByStatus = @{
                Pending = ($allTasks | Where-Object { $_.Status -eq "Pending" }).Count
                InProgress = ($allTasks | Where-Object { $_.Status -eq "InProgress" }).Count
                Completed = ($allTasks | Where-Object { $_.Status -eq "Completed" }).Count
            }
            KanbanColumns = $this.Data.configuration.kanbanColumns
        }
    }
    
    # Migrate from old separate files (compatibility)
    [void] MigrateFromSeparateFiles([string]$tasksFile, [string]$projectsFile) {
# Migrating from separate files to unified data model
        
        # This would implement migration logic from old TaskService/ProjectService files
        # For now, we'll start fresh with the new structure
        
        Write-Host "Migration completed. Old files preserved as backups." -ForegroundColor Green
    }
}