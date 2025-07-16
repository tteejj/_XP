# ==============================================================================
# Axiom-Phoenix v4.0 - All Services (Load After Components)
# Core application services: action, navigation, data, theming, logging, events
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASE.###" to find specific sections.
# Each section ends with "END_PAGE: ASE.###"
# ==============================================================================

#region DataManager Class

# ===== CLASS: DataManager =====
# Module: data-manager (from axiom)
# Dependencies: EventManager (optional), PmcTask, PmcProject, TimeEntry
# Purpose: High-performance data management with transactions, backups, and robust serialization
class DataManager : System.IDisposable {
    # Private fields for high-performance indexes
    hidden [System.Collections.Generic.Dictionary[string, PmcTask]]$_taskIndex
    hidden [System.Collections.Generic.Dictionary[string, PmcProject]]$_projectIndex
    hidden [System.Collections.Generic.Dictionary[string, TimeEntry]]$_timeEntryIndex
    hidden [string]$_dataFilePath
    hidden [string]$_backupPath
    hidden [datetime]$_lastSaveTime
    hidden [bool]$_dataModified = $false
    hidden [int]$_updateTransactionCount = 0
    
    # Public properties
    [hashtable]$Metadata = @{}
    [bool]$AutoSave = $true
    [int]$BackupCount = 5
    [EventManager]$EventManager = $null
    
    DataManager([string]$dataPath) {
        $this._dataFilePath = $dataPath
        $this._Initialize()
    }
    
    DataManager([string]$dataPath, [EventManager]$eventManager) {
        $this._dataFilePath = $dataPath
        $this.EventManager = $eventManager
        $this._Initialize()
    }
    
    hidden [void] _Initialize() {
        # Initialize indexes
        $this._taskIndex = [System.Collections.Generic.Dictionary[string, PmcTask]]::new()
        $this._projectIndex = [System.Collections.Generic.Dictionary[string, PmcProject]]::new()
        $this._timeEntryIndex = [System.Collections.Generic.Dictionary[string, TimeEntry]]::new()
        
        # Set up directories
        $baseDir = Split-Path -Path $this._dataFilePath -Parent
        $this._backupPath = Join-Path $baseDir "backups"
        
        # Ensure directories exist
        if (-not (Test-Path $baseDir)) {
            New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
        }
        if (-not (Test-Path $this._backupPath)) {
            New-Item -ItemType Directory -Path $this._backupPath -Force | Out-Null
        }
        
        # Write-Verbose "DataManager: Initialized with path '$($this._dataFilePath)'"
    }
    
    [void] LoadData() {
        try {
            if (-not (Test-Path $this._dataFilePath)) {
                # Write-Verbose "DataManager: No existing data file found at '$($this._dataFilePath)'"
                return
            }
            
            $jsonContent = Get-Content -Path $this._dataFilePath -Raw -Encoding UTF8
            if ([string]::IsNullOrWhiteSpace($jsonContent)) {
                # Write-Verbose "DataManager: Data file is empty"
                return
            }
            
            $data = $jsonContent | ConvertFrom-Json -AsHashtable
            
            # Clear existing data
            $this._taskIndex.Clear()
            $this._projectIndex.Clear()
            $this._timeEntryIndex.Clear()
            
            # Load tasks using FromLegacyFormat
            if ($data.ContainsKey('Tasks')) {
                foreach ($taskData in $data.Tasks) {
                    try {
                        $task = [PmcTask]::FromLegacyFormat($taskData)
                        $this._taskIndex[$task.Id] = $task
                    }
                    catch {
                        Write-Warning "DataManager: Failed to load task: $($_.Exception.Message)"
                    }
                }
            }
            
            # Load projects using FromLegacyFormat
            if ($data.ContainsKey('Projects')) {
                foreach ($projectData in $data.Projects) {
                    try {
                        $project = [PmcProject]::FromLegacyFormat($projectData)
                        $this._projectIndex[$project.Key] = $project
                    }
                    catch {
                        Write-Warning "DataManager: Failed to load project: $($_.Exception.Message)"
                    }
                }
            }
            
            # Load time entries
            if ($data.ContainsKey('TimeEntries')) {
                foreach ($entryData in $data.TimeEntries) {
                    try {
                        $entry = [TimeEntry]::new()
                        $entry.Id = $entryData.Id
                        $entry.TaskId = $entryData.TaskId
                        $entry.ProjectKey = $entryData.ProjectKey
                        $entry.StartTime = [DateTime]::Parse($entryData.StartTime)
                        if ($entryData.EndTime) {
                            $entry.EndTime = [DateTime]::Parse($entryData.EndTime)
                        }
                        $entry.Description = $entryData.Description
                        $entry.BillingType = [System.Enum]::Parse([BillingType], $entryData.BillingType, $true)
                        $entry.UserId = $entryData.UserId
                        $entry.HourlyRate = [decimal]$entryData.HourlyRate
                        if ($entryData.Metadata) {
                            $entry.Metadata = $entryData.Metadata.Clone()
                        }
                        
                        $this._timeEntryIndex[$entry.Id] = $entry
                    }
                    catch {
                        Write-Warning "DataManager: Failed to load time entry: $($_.Exception.Message)"
                    }
                }
            }
            
            # Load metadata
            if ($data.ContainsKey('Metadata')) {
                $this.Metadata = $data.Metadata.Clone()
            }
            
            $this._lastSaveTime = [datetime]::Now
            $this._dataModified = $false
            
            # Write-Verbose "DataManager: Loaded $($this._taskIndex.Count) tasks, $($this._projectIndex.Count) projects, and $($this._timeEntryIndex.Count) time entries"
            
            # Publish event
            if ($this.EventManager) {
                $this.EventManager.Publish("Data.Loaded", @{
                    TaskCount = $this._taskIndex.Count
                    ProjectCount = $this._projectIndex.Count
                    TimeEntryCount = $this._timeEntryIndex.Count
                    Source = $this._dataFilePath
                })
            }
        }
        catch {
            Write-Error "DataManager: Failed to load data from '$($this._dataFilePath)': $($_.Exception.Message)"
            throw
        }
    }
    
    [void] SaveData() {
        if ($this._updateTransactionCount -gt 0) {
            # Write-Verbose "DataManager: SaveData deferred - inside update transaction (level $($this._updateTransactionCount))"
            return
        }
        
        try {
            $this.CreateBackup()
            
            $saveData = @{
                Tasks = @()
                Projects = @()
                TimeEntries = @()
                Metadata = $this.Metadata.Clone()
                SavedAt = [datetime]::Now
                Version = "4.0"
            }
            
            # Convert tasks to legacy format for serialization
            foreach ($task in $this._taskIndex.Values) {
                $saveData.Tasks += $task.ToLegacyFormat()
            }
            
            # Convert projects to legacy format for serialization
            foreach ($project in $this._projectIndex.Values) {
                $saveData.Projects += $project.ToLegacyFormat()
            }
            
            # Convert time entries for serialization
            foreach ($entry in $this._timeEntryIndex.Values) {
                $saveData.TimeEntries += @{
                    Id = $entry.Id
                    TaskId = $entry.TaskId
                    ProjectKey = $entry.ProjectKey
                    StartTime = $entry.StartTime.ToString("yyyy-MM-ddTHH:mm:ss")
                    EndTime = if ($entry.EndTime) { $entry.EndTime.ToString("yyyy-MM-ddTHH:mm:ss") } else { $null }
                    Description = $entry.Description
                    BillingType = $entry.BillingType.ToString()
                    UserId = $entry.UserId
                    HourlyRate = $entry.HourlyRate
                    Metadata = $entry.Metadata.Clone()
                }
            }
            
            $saveData | ConvertTo-Json -Depth 10 -WarningAction SilentlyContinue | Set-Content -Path $this._dataFilePath -Encoding UTF8 -Force
            $this._lastSaveTime = [datetime]::Now
            $this._dataModified = $false
            
            # Write-Verbose "DataManager: Data saved to '$($this._dataFilePath)'"
            
            # Publish event
            if ($this.EventManager) {
                $this.EventManager.Publish("Data.Saved", @{
                    TaskCount = $saveData.Tasks.Count
                    ProjectCount = $saveData.Projects.Count
                    TimeEntryCount = $saveData.TimeEntries.Count
                    Destination = $this._dataFilePath
                })
            }
        }
        catch {
            Write-Error "DataManager: Failed to save data: $($_.Exception.Message)"
            throw
        }
    }
    
    hidden [void] CreateBackup() {
        try {
            if (Test-Path $this._dataFilePath) {
                $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
                $backupFileName = "data-backup-$timestamp.json"
                $backupFilePath = Join-Path $this._backupPath $backupFileName
                
                Copy-Item -Path $this._dataFilePath -Destination $backupFilePath -Force
                
                # Manage backup rotation
                if ($this.BackupCount -gt 0) {
                    $backups = Get-ChildItem -Path $this._backupPath -Filter "data-backup-*.json" | 
                               Sort-Object LastWriteTime -Descending
                    
                    if ($backups.Count -gt $this.BackupCount) {
                        $backupsToDelete = $backups | Select-Object -Skip $this.BackupCount
                        foreach ($backup in $backupsToDelete) {
                            Remove-Item -Path $backup.FullName -Force
                            # Write-Verbose "DataManager: Removed old backup '$($backup.Name)'"
                        }
                    }
                }
                
                # Write-Verbose "DataManager: Created backup '$backupFileName'"
            }
        }
        catch {
            Write-Warning "DataManager: Failed to create backup: $($_.Exception.Message)"
        }
    }
    
    # Transactional update methods
    [void] BeginUpdate() {
        $this._updateTransactionCount++
        # Write-Verbose "DataManager: Began update transaction. Depth: $($this._updateTransactionCount)"
    }
    
    [void] EndUpdate() {
        $this.EndUpdate($false)
    }
    
    [void] EndUpdate([bool]$forceSave) {
        if ($this._updateTransactionCount -gt 0) {
            $this._updateTransactionCount--
        }
        
        # Write-Verbose "DataManager: Ended update transaction. Depth: $($this._updateTransactionCount)"
        
        if ($this._updateTransactionCount -eq 0 -and ($this._dataModified -or $forceSave)) {
            if ($this.AutoSave -or $forceSave) {
                $this.SaveData()
            }
        }
    }
    
    # Task management methods
    [PmcTask[]] GetTasks() {
        return @($this._taskIndex.Values)
    }
    
    [PmcTask] GetTask([string]$taskId) {
        if ($this._taskIndex.ContainsKey($taskId)) {
            return $this._taskIndex[$taskId]
        }
        return $null
    }
    
    [PmcTask[]] GetTasksByProject([string]$projectKey) {
        return @($this._taskIndex.Values.Where({$_.ProjectKey -eq $projectKey}))
    }
    
    [PmcTask] AddTask([PmcTask]$task) {
        if ($null -eq $task) {
            throw [System.ArgumentNullException]::new("task", "Task cannot be null")
        }
        
        if ([string]::IsNullOrEmpty($task.Id)) {
            $task.Id = [guid]::NewGuid().ToString()
        }
        
        if ($this._taskIndex.ContainsKey($task.Id)) {
            throw [System.InvalidOperationException]::new("Task with ID '$($task.Id)' already exists")
        }
        
        $this._taskIndex[$task.Id] = $task
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Tasks.Changed", @{ Action = "Created"; Task = $task })
        }
        
        # Write-Verbose "DataManager: Added task '$($task.Title)' with ID '$($task.Id)'"
        return $task
    }
    
    [PmcTask] UpdateTask([PmcTask]$task) {
        if ($null -eq $task) {
            throw [System.ArgumentNullException]::new("task", "Task cannot be null")
        }
        
        if (-not $this._taskIndex.ContainsKey($task.Id)) {
            throw [System.InvalidOperationException]::new("Task with ID '$($task.Id)' not found")
        }
        
        $task.UpdatedAt = [datetime]::Now
        $this._taskIndex[$task.Id] = $task
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Tasks.Changed", @{ Action = "Updated"; Task = $task })
        }
        
        # Write-Verbose "DataManager: Updated task '$($task.Title)' with ID '$($task.Id)'"
        return $task
    }
    
    [bool] DeleteTask([string]$taskId) {
        if (-not $this._taskIndex.ContainsKey($taskId)) {
            # Write-Verbose "DataManager: Task '$taskId' not found for deletion"
            return $false
        }
        
        $task = $this._taskIndex[$taskId]
        $this._taskIndex.Remove($taskId) | Out-Null
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Tasks.Changed", @{ Action = "Deleted"; TaskId = $taskId })
        }
        
        # Write-Verbose "DataManager: Deleted task with ID '$taskId'"
        return $true
    }
    
    # Project management methods
    [PmcProject[]] GetProjects() {
        return @($this._projectIndex.Values)
    }
    
    [PmcProject] GetProject([string]$projectKey) {
        if ($this._projectIndex.ContainsKey($projectKey)) {
            return $this._projectIndex[$projectKey]
        }
        return $null
    }
    
    [PmcProject] AddProject([PmcProject]$project) {
        if ($null -eq $project) {
            throw [System.ArgumentNullException]::new("project", "Project cannot be null")
        }
        
        if ([string]::IsNullOrEmpty($project.Key)) {
            throw [System.ArgumentException]::new("Project Key is required")
        }
        
        if ($this._projectIndex.ContainsKey($project.Key)) {
            throw [System.InvalidOperationException]::new("Project with Key '$($project.Key)' already exists")
        }
        
        $this._projectIndex[$project.Key] = $project
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Projects.Changed", @{ Action = "Created"; Project = $project })
        }
        
        # Write-Verbose "DataManager: Added project '$($project.Name)' with Key '$($project.Key)'"
        return $project
    }
    
    [PmcProject] UpdateProject([PmcProject]$project) {
        if ($null -eq $project) {
            throw [System.ArgumentNullException]::new("project", "Project cannot be null")
        }
        
        if (-not $this._projectIndex.ContainsKey($project.Key)) {
            throw [System.InvalidOperationException]::new("Project with Key '$($project.Key)' not found")
        }
        
        $project.UpdatedAt = [datetime]::Now
        $this._projectIndex[$project.Key] = $project
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Projects.Changed", @{ Action = "Updated"; Project = $project })
        }
        
        # Write-Verbose "DataManager: Updated project '$($project.Name)' with Key '$($project.Key)'"
        return $project
    }
    
    [bool] DeleteProject([string]$projectKey) {
        if (-not $this._projectIndex.ContainsKey($projectKey)) {
            # Write-Verbose "DataManager: Project '$projectKey' not found for deletion"
            return $false
        }
        
        # Delete all tasks associated with this project
        $tasksToDelete = @($this._taskIndex.Values.Where({$_.ProjectKey -eq $projectKey}))
        foreach ($task in $tasksToDelete) {
            $this.DeleteTask($task.Id) | Out-Null
        }
        
        # Delete all time entries associated with this project
        $timeEntriesToDelete = @($this._timeEntryIndex.Values.Where({$_.ProjectKey -eq $projectKey}))
        foreach ($entry in $timeEntriesToDelete) {
            $this.DeleteTimeEntry($entry.Id) | Out-Null
        }
        
        $project = $this._projectIndex[$projectKey]
        $this._projectIndex.Remove($projectKey) | Out-Null
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Projects.Changed", @{ 
                Action = "Deleted"
                ProjectKey = $projectKey
                DeletedTaskCount = $tasksToDelete.Count
            })
        }
        
        # Write-Verbose "DataManager: Deleted project '$projectKey' and $($tasksToDelete.Count) associated tasks"
        return $true
    }
    
    # Time entry management methods
    [TimeEntry[]] GetTimeEntries() {
        return @($this._timeEntryIndex.Values)
    }
    
    [TimeEntry] GetTimeEntry([string]$entryId) {
        if ($this._timeEntryIndex.ContainsKey($entryId)) {
            return $this._timeEntryIndex[$entryId]
        }
        return $null
    }
    
    [TimeEntry[]] GetTimeEntriesByProject([string]$projectKey) {
        return @($this._timeEntryIndex.Values.Where({$_.ProjectKey -eq $projectKey}))
    }
    
    [TimeEntry[]] GetTimeEntriesByTask([string]$taskId) {
        return @($this._timeEntryIndex.Values.Where({$_.TaskId -eq $taskId}))
    }
    
    [TimeEntry[]] GetTimeEntriesByDateRange([DateTime]$startDate, [DateTime]$endDate) {
        return @($this._timeEntryIndex.Values.Where({ 
            $_.StartTime -ge $startDate -and $_.StartTime -le $endDate 
        }))
    }
    
    [TimeEntry[]] GetTimeEntriesByID1([string]$id1) {
        return @($this._timeEntryIndex.Values.Where({$_.ID1 -eq $id1}))
    }
    
    [TimeEntry] AddTimeEntry([TimeEntry]$entry) {
        if ($null -eq $entry) {
            throw [System.ArgumentNullException]::new("entry", "Time entry cannot be null")
        }
        
        if ([string]::IsNullOrEmpty($entry.Id)) {
            $entry.Id = [guid]::NewGuid().ToString()
        }
        
        if ($this._timeEntryIndex.ContainsKey($entry.Id)) {
            throw [System.InvalidOperationException]::new("Time entry with ID '$($entry.Id)' already exists")
        }
        
        $this._timeEntryIndex[$entry.Id] = $entry
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("TimeEntries.Changed", @{ Action = "Created"; TimeEntry = $entry })
        }
        
        # Write-Verbose "DataManager: Added time entry for project '$($entry.ProjectKey)' with ID '$($entry.Id)'"
        return $entry
    }
    
    [TimeEntry] UpdateTimeEntry([TimeEntry]$entry) {
        if ($null -eq $entry) {
            throw [System.ArgumentNullException]::new("entry", "Time entry cannot be null")
        }
        
        if (-not $this._timeEntryIndex.ContainsKey($entry.Id)) {
            throw [System.InvalidOperationException]::new("Time entry with ID '$($entry.Id)' not found")
        }
        
        $this._timeEntryIndex[$entry.Id] = $entry
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("TimeEntries.Changed", @{ Action = "Updated"; TimeEntry = $entry })
        }
        
        # Write-Verbose "DataManager: Updated time entry with ID '$($entry.Id)'"
        return $entry
    }
    
    [bool] DeleteTimeEntry([string]$entryId) {
        if (-not $this._timeEntryIndex.ContainsKey($entryId)) {
            # Write-Verbose "DataManager: Time entry '$entryId' not found for deletion"
            return $false
        }
        
        $entry = $this._timeEntryIndex[$entryId]
        $this._timeEntryIndex.Remove($entryId) | Out-Null
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("TimeEntries.Changed", @{ Action = "Deleted"; TimeEntryId = $entryId })
        }
        
        # Write-Verbose "DataManager: Deleted time entry with ID '$entryId'"
        return $true
    }
    
    # Utility methods
    [datetime] GetLastSaveTime() {
        return $this._lastSaveTime
    }
    
    [void] ForceSave() {
        $originalTransactionCount = $this._updateTransactionCount
        $this._updateTransactionCount = 0
        try {
            $this.SaveData()
        }
        finally {
            $this._updateTransactionCount = $originalTransactionCount
        }
    }
    
    # IDisposable implementation
    [void] Dispose() {
        # Write-Verbose "DataManager: Disposing - checking for unsaved data"
        
        if ($this._dataModified) {
            $originalTransactionCount = $this._updateTransactionCount
            $this._updateTransactionCount = 0
            try {
                $this.SaveData()
                # Write-Verbose "DataManager: Performed final save during dispose"
            }
            catch {
                Write-Warning "DataManager: Failed to save data during dispose: $($_.Exception.Message)"
            }
            finally {
                $this._updateTransactionCount = $originalTransactionCount
            }
        }
    }
    
    # Cleanup method (alias for Dispose)
    [void] Cleanup() {
        $this.Dispose()
    }
}

#endregion
#<!-- END_PAGE: ASE.003 -->
