# Data Manager Module - Axiom-Phoenix v4.0 Enhancement
# High-performance, transaction-safe, and lifecycle-aware data service.

function Initialize-DataManager {
    <#
    .SYNOPSIS
    Initializes and returns a new DataManager instance.
    #>
    [CmdletBinding()]
    param()
    
    return Invoke-WithErrorHandling -Component "DataManager.Initialize" -Context "Creating DataManager instance" -ScriptBlock {
        Write-Verbose "DataManager: Initializing new instance."
        return [DataManager]::new()
    }
}

class DataManager : IDisposable {
    #region Private State
    hidden [hashtable] $_dataStore
    hidden [string] $_dataFilePath
    hidden [string] $_backupPath
    hidden [datetime] $_lastSaveTime
    hidden [bool] $_dataModified = $false
    
    # High-performance indexes for fast lookups
    hidden [System.Collections.Generic.Dictionary[string, object]] $_taskIndex
    hidden [System.Collections.Generic.Dictionary[string, object]] $_projectIndex
    
    # For transactional updates
    hidden [int] $_updateTransactionCount = 0
    #endregion

    #region Constructor and Initialization
    DataManager() {
        $this.{_dataStore} = @{
            Projects = [System.Collections.ArrayList]::new()
            Tasks = [System.Collections.ArrayList]::new()
            Settings = @{ 
                AutoSave = $true
                BackupCount = 5
                LastModified = [datetime]::MinValue
            }
        }
        $this.{_taskIndex} = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.{_projectIndex} = [System.Collections.Generic.Dictionary[string, object]]::new()
        
        # Set up file paths
        $baseDir = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal"
        $this.{_dataFilePath} = Join-Path $baseDir "pmc-data.json"
        $this.{_backupPath} = Join-Path $baseDir "backups"

        # Ensure directories exist
        if (-not (Test-Path $baseDir)) {
            New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
        }
        if (-not (Test-Path $this.{_backupPath})) {
            New-Item -ItemType Directory -Path $this.{_backupPath} -Force | Out-Null
        }

        $this.LoadData()
        $this.InitializeEventHandlers()
        
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "DataManager initialized successfully." -Data @{
                DataPath = $this.{_dataFilePath}
                BackupPath = $this.{_backupPath}
                TaskCount = $this.{_dataStore}.Tasks.Count
                ProjectCount = $this.{_dataStore}.Projects.Count
            }
        }
        Write-Verbose "DataManager: Initialization complete."
    }

    hidden [void] LoadData() {
        try {
            if (Test-Path $this.{_dataFilePath}) {
                $jsonData = Get-Content $this.{_dataFilePath} -Raw | ConvertFrom-Json -AsHashtable
                
                # Validate and load data structure
                if ($jsonData.ContainsKey('Tasks')) {
                    $this.{_dataStore}.Tasks.Clear()
                    foreach ($taskData in $jsonData.Tasks) {
                        $task = [PmcTask]::new($taskData)
                        [void]$this.{_dataStore}.Tasks.Add($task)
                    }
                }
                
                if ($jsonData.ContainsKey('Projects')) {
                    $this.{_dataStore}.Projects.Clear()
                    foreach ($projectData in $jsonData.Projects) {
                        $project = [PmcProject]::new($projectData)
                        [void]$this.{_dataStore}.Projects.Add($project)
                    }
                }
                
                if ($jsonData.ContainsKey('Settings')) {
                    foreach ($key in $jsonData.Settings.Keys) {
                        $this.{_dataStore}.Settings[$key] = $jsonData.Settings[$key]
                    }
                }
                
                $this.{_lastSaveTime} = [datetime]::Now
                Write-Verbose "DataManager: Loaded data from '$($this.{_dataFilePath})'."
            } else {
                Write-Verbose "DataManager: No existing data file found. Starting with empty data store."
            }
        } catch {
            Write-Warning "DataManager: Failed to load data from '$($this.{_dataFilePath})': $($_.Exception.Message). Starting with empty data store."
            $this.{_dataStore}.Tasks.Clear()
            $this.{_dataStore}.Projects.Clear()
        }
        
        # Rebuild indexes after loading
        $this._RebuildIndexes()
    }
    
    hidden [void] _RebuildIndexes() {
        $this.{_taskIndex}.Clear()
        $this.{_projectIndex}.Clear()
        
        foreach ($task in $this.{_dataStore}.Tasks) {
            if ($task.Id) {
                $this.{_taskIndex}[$task.Id] = $task
            }
        }
        
        foreach ($project in $this.{_dataStore}.Projects) {
            if ($project.Key) {
                $this.{_projectIndex}[$project.Key] = $project
            }
        }
        
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "Rebuilt data indexes." -Data @{
                TaskIndexCount = $this.{_taskIndex}.Count
                ProjectIndexCount = $this.{_projectIndex}.Count
            }
        }
        Write-Verbose "DataManager: Rebuilt data indexes for $($this.{_taskIndex}.Count) tasks and $($this.{_projectIndex}.Count) projects."
    }
    
    hidden [void] SaveData() {
        # Only save if not in a transaction or at the end of one
        if ($this.{_updateTransactionCount} -gt 0) {
            Write-Verbose "DataManager: SaveData deferred - inside update transaction (level $($this.{_updateTransactionCount}))."
            return
        }
        
        try {
            # Create backup before saving
            $this.CreateBackup()
            
            # Prepare data for serialization
            $saveData = @{
                Tasks = @()
                Projects = @()
                Settings = $this.{_dataStore}.Settings.Clone()
                SavedAt = [datetime]::Now
            }
            
            # Convert objects to serializable format
            foreach ($task in $this.{_dataStore}.Tasks) {
                $saveData.Tasks += $task.ToHashtable()
            }
            
            foreach ($project in $this.{_dataStore}.Projects) {
                $saveData.Projects += $project.ToHashtable()
            }
            
            # Save to file
            $saveData | ConvertTo-Json -Depth 10 | Set-Content -Path $this.{_dataFilePath} -Encoding UTF8 -Force
            $this.{_lastSaveTime} = [datetime]::Now
            $this.{_dataModified} = $false
            
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Debug -Message "Data saved successfully." -Data @{
                    FilePath = $this.{_dataFilePath}
                    TaskCount = $saveData.Tasks.Count
                    ProjectCount = $saveData.Projects.Count
                }
            }
            Write-Verbose "DataManager: Data saved to '$($this.{_dataFilePath})'."
        } catch {
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Error -Message "Failed to save data: $($_.Exception.Message)"
            }
            throw
        }
    }
    
    hidden [void] CreateBackup() {
        try {
            if (Test-Path $this.{_dataFilePath}) {
                $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
                $backupFileName = "pmc-data-$timestamp.json"
                $backupFilePath = Join-Path $this.{_backupPath} $backupFileName
                
                Copy-Item -Path $this.{_dataFilePath} -Destination $backupFilePath -Force
                
                # Clean up old backups
                $backups = Get-ChildItem -Path $this.{_backupPath} -Filter "pmc-data-*.json" | Sort-Object LastWriteTime -Descending
                if ($backups.Count -gt $this.{_dataStore}.Settings.BackupCount) {
                    $backupsToDelete = $backups | Select-Object -Skip $this.{_dataStore}.Settings.BackupCount
                    foreach ($backup in $backupsToDelete) {
                        Remove-Item -Path $backup.FullName -Force
                        Write-Verbose "DataManager: Removed old backup '$($backup.Name)'."
                    }
                }
                
                Write-Verbose "DataManager: Created backup '$backupFileName'."
            }
        } catch {
            Write-Warning "DataManager: Failed to create backup: $($_.Exception.Message)"
        }
    }
    
    hidden [void] InitializeEventHandlers() {
        # Initialize any event subscriptions if needed
        Write-Verbose "DataManager: Event handlers initialized."
    }
    #endregion
    
    #region Lifecycle Management
    [void] Dispose() {
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "DataManager disposing. Checking for unsaved data."
        }
        Write-Verbose "DataManager: Disposing - checking for unsaved data."
        
        if ($this.{_dataModified}) {
            # Force save on dispose, ignoring any transaction counts
            $originalTransactionCount = $this.{_updateTransactionCount}
            $this.{_updateTransactionCount} = 0
            try {
                $this.SaveData()
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Info -Message "Performed final save of modified data during dispose."
                }
                Write-Verbose "DataManager: Performed final save during dispose."
            } catch {
                Write-Warning "DataManager: Failed to save data during dispose: $($_.Exception.Message)"
            } finally {
                $this.{_updateTransactionCount} = $originalTransactionCount
            }
        }
    }
    #endregion

    #region Transactional Updates
    [void] BeginUpdate() {
        $this.{_updateTransactionCount}++
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "Began data update transaction." -Data @{ Depth = $this.{_updateTransactionCount} }
        }
        Write-Verbose "DataManager: Began update transaction. Depth: $($this.{_updateTransactionCount})."
    }

    [void] EndUpdate() {
        $this.EndUpdate($false)
    }
    
    [void] EndUpdate([bool]$forceSave) {
        if ($this.{_updateTransactionCount} -gt 0) {
            $this.{_updateTransactionCount}--
        }
        
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "Ended data update transaction." -Data @{ Depth = $this.{_updateTransactionCount} }
        }
        Write-Verbose "DataManager: Ended update transaction. Depth: $($this.{_updateTransactionCount})."
        
        if ($this.{_updateTransactionCount} -eq 0 -and ($this.{_dataModified} -or $forceSave)) {
            if ($this.{_dataStore}.Settings.AutoSave -or $forceSave) {
                $this.SaveData()
            }
        }
    }
    #endregion

    #region Task Management Methods
    [PmcTask] AddTask([Parameter(Mandatory)][ValidateNotNull()][PmcTask]$newTask) {
        return Invoke-WithErrorHandling -Component "DataManager.AddTask" -Context "Adding new task" -AdditionalData @{ TaskId = $newTask.Id; TaskTitle = $newTask.Title } -ScriptBlock {
            # Ensure task has required properties
            if ([string]::IsNullOrEmpty($newTask.Id)) {
                $newTask.Id = [guid]::NewGuid().ToString()
            }
            if ($newTask.CreatedAt -eq [datetime]::MinValue) {
                $newTask.CreatedAt = [datetime]::Now
            }
            
            # Check for duplicate ID
            if ($this.{_taskIndex}.ContainsKey($newTask.Id)) {
                throw [System.InvalidOperationException]::new("Task with ID '$($newTask.Id)' already exists.")
            }
            
            [void]$this.{_dataStore}.Tasks.Add($newTask)
            $this.{_taskIndex}[$newTask.Id] = $newTask
            $this.{_dataModified} = $true
            
            if ($this.{_dataStore}.Settings.AutoSave -and $this.{_updateTransactionCount} -eq 0) {
                $this.SaveData()
            }
            
            if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
                Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Created"; Task = $newTask }
            }
            
            Write-Verbose "DataManager: Added task '$($newTask.Title)' with ID '$($newTask.Id)'."
            return $newTask
        }
    }

    [PmcTask] UpdateTask([Parameter(Mandatory)][ValidateNotNull()][PmcTask]$taskWithUpdates) {
        return Invoke-WithErrorHandling -Component "DataManager.UpdateTask" -Context "Updating task" -AdditionalData @{ TaskId = $taskWithUpdates.Id } -ScriptBlock {
            if (-not $this.{_taskIndex}.ContainsKey($taskWithUpdates.Id)) {
                throw [System.InvalidOperationException]::new("Task with ID '$($taskWithUpdates.Id)' not found for update.")
            }
            
            # Get the actual, managed instance of the task from our store
            $managedTask = $this.{_taskIndex}[$taskWithUpdates.Id]
            
            # Copy properties from the provided object to the managed object
            $propertiesToUpdate = @('Title', 'Description', 'Status', 'Priority', 'ProjectKey', 'Tags', 'DueDate', 'CompletedAt')
            foreach ($propName in $propertiesToUpdate) {
                if ($taskWithUpdates.PSObject.Properties[$propName]) {
                    $managedTask.$propName = $taskWithUpdates.$propName
                }
            }
            $managedTask.UpdatedAt = [datetime]::Now
            
            $this.{_dataModified} = $true
            
            if ($this.{_dataStore}.Settings.AutoSave -and $this.{_updateTransactionCount} -eq 0) {
                $this.SaveData()
            }
            
            if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
                Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Updated"; Task = $managedTask }
            }
            
            Write-Verbose "DataManager: Updated task '$($managedTask.Title)' with ID '$($managedTask.Id)'."
            return $managedTask
        }
    }

    [bool] RemoveTask([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$taskId) {
        return Invoke-WithErrorHandling -Component "DataManager.RemoveTask" -Context "Removing task" -AdditionalData @{ TaskId = $taskId } -ScriptBlock {
            if (-not $this.{_taskIndex}.ContainsKey($taskId)) {
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Warning -Message "Task not found for removal: '$taskId'"
                }
                Write-Verbose "DataManager: Task '$taskId' not found for removal."
                return $false
            }
            
            $taskToRemove = $this.{_taskIndex}[$taskId]
            [void]$this.{_dataStore}.Tasks.Remove($taskToRemove)
            [void]$this.{_taskIndex}.Remove($taskId)
            $this.{_dataModified} = $true
            
            if ($this.{_dataStore}.Settings.AutoSave -and $this.{_updateTransactionCount} -eq 0) {
                $this.SaveData()
            }
            
            if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
                Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Deleted"; TaskId = $taskId }
            }
            
            Write-Verbose "DataManager: Removed task with ID '$taskId'."
            return $true
        }
    }
    
    [PmcTask] GetTask([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$taskId) {
        if ($this.{_taskIndex}.ContainsKey($taskId)) {
            return $this.{_taskIndex}[$taskId]
        }
        return $null
    }
    
    [PmcTask[]] GetTasks() {
        return $this.{_dataStore}.Tasks.ToArray()
    }
    #endregion
    
    #region Project Management Methods
    [PmcProject] AddProject([Parameter(Mandatory)][ValidateNotNull()][PmcProject]$newProject) {
        return Invoke-WithErrorHandling -Component "DataManager.AddProject" -Context "Adding new project" -AdditionalData @{ ProjectKey = $newProject.Key; ProjectName = $newProject.Name } -ScriptBlock {
            # Ensure project has required properties
            if ([string]::IsNullOrEmpty($newProject.Key)) {
                throw [System.ArgumentException]::new("Project Key is required.")
            }
            if ($newProject.CreatedAt -eq [datetime]::MinValue) {
                $newProject.CreatedAt = [datetime]::Now
            }
            
            # Check for duplicate key
            if ($this.{_projectIndex}.ContainsKey($newProject.Key)) {
                throw [System.InvalidOperationException]::new("Project with Key '$($newProject.Key)' already exists.")
            }
            
            [void]$this.{_dataStore}.Projects.Add($newProject)
            $this.{_projectIndex}[$newProject.Key] = $newProject
            $this.{_dataModified} = $true
            
            if ($this.{_dataStore}.Settings.AutoSave -and $this.{_updateTransactionCount} -eq 0) {
                $this.SaveData()
            }
            
            if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
                Publish-Event -EventName "Projects.Changed" -Data @{ Action = "Created"; Project = $newProject }
            }
            
            Write-Verbose "DataManager: Added project '$($newProject.Name)' with Key '$($newProject.Key)'."
            return $newProject
        }
    }
    
    [PmcProject] UpdateProject([Parameter(Mandatory)][ValidateNotNull()][PmcProject]$projectWithUpdates) {
        return Invoke-WithErrorHandling -Component "DataManager.UpdateProject" -Context "Updating project" -AdditionalData @{ ProjectKey = $projectWithUpdates.Key } -ScriptBlock {
            if (-not $this.{_projectIndex}.ContainsKey($projectWithUpdates.Key)) {
                throw [System.InvalidOperationException]::new("Project with Key '$($projectWithUpdates.Key)' not found for update.")
            }
            
            # Get the actual, managed instance
            $managedProject = $this.{_projectIndex}[$projectWithUpdates.Key]
            
            # Copy properties
            $propertiesToUpdate = @('Name', 'Description', 'Status', 'CompletedAt')
            foreach ($propName in $propertiesToUpdate) {
                if ($projectWithUpdates.PSObject.Properties[$propName]) {
                    $managedProject.$propName = $projectWithUpdates.$propName
                }
            }
            $managedProject.UpdatedAt = [datetime]::Now
            
            $this.{_dataModified} = $true
            
            if ($this.{_dataStore}.Settings.AutoSave -and $this.{_updateTransactionCount} -eq 0) {
                $this.SaveData()
            }
            
            if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
                Publish-Event -EventName "Projects.Changed" -Data @{ Action = "Updated"; Project = $managedProject }
            }
            
            Write-Verbose "DataManager: Updated project '$($managedProject.Name)' with Key '$($managedProject.Key)'."
            return $managedProject
        }
    }
    
    [bool] RemoveProject([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$projectKey) {
        return Invoke-WithErrorHandling -Component "DataManager.RemoveProject" -Context "Removing project" -AdditionalData @{ ProjectKey = $projectKey } -ScriptBlock {
            if (-not $this.{_projectIndex}.ContainsKey($projectKey)) {
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Warning -Message "Project not found for removal: '$projectKey'"
                }
                Write-Verbose "DataManager: Project '$projectKey' not found for removal."
                return $false
            }
            
            $projectToRemove = $this.{_projectIndex}[$projectKey]
            [void]$this.{_dataStore}.Projects.Remove($projectToRemove)
            [void]$this.{_projectIndex}.Remove($projectKey)
            $this.{_dataModified} = $true
            
            if ($this.{_dataStore}.Settings.AutoSave -and $this.{_updateTransactionCount} -eq 0) {
                $this.SaveData()
            }
            
            if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
                Publish-Event -EventName "Projects.Changed" -Data @{ Action = "Deleted"; ProjectKey = $projectKey }
            }
            
            Write-Verbose "DataManager: Removed project with Key '$projectKey'."
            return $true
        }
    }
    
    [PmcProject] GetProject([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$projectKey) {
        if ($this.{_projectIndex}.ContainsKey($projectKey)) {
            return $this.{_projectIndex}[$projectKey]
        }
        return $null
    }
    
    [PmcProject[]] GetProjects() {
        return $this.{_dataStore}.Projects.ToArray()
    }
    #endregion
    
    #region Settings and Utility Methods
    [bool] IsAutoSaveEnabled() {
        return $this.{_dataStore}.Settings.AutoSave
    }
    
    [void] SetAutoSave([bool]$enabled) {
        $this.{_dataStore}.Settings.AutoSave = $enabled
        $this.{_dataModified} = $true
        Write-Verbose "DataManager: AutoSave set to '$enabled'."
    }
    
    [datetime] GetLastSaveTime() {
        return $this.{_lastSaveTime}
    }
    
    [void] ForceSave() {
        $this.SaveData()
    }
    #endregion
}

# Export the factory function
Export-ModuleMember -Function Initialize-DataManager
