class DataManager {
    #region Private State
    hidden [hashtable] $_dataStore
    hidden [string] $_dataFilePath
    hidden [string] $_backupPath
    hidden [datetime] $_lastSaveTime
    hidden [bool] $_dataModified = $false
    #endregion

    #region Constructor and Initialization
    DataManager() {
        $this.{_dataStore} = @{
            Projects = [System.Collections.ArrayList]::new()
            Tasks = [System.Collections.ArrayList]::new()
            TimeEntries = @()
            ActiveTimers = @{}
            TodoTemplates = @{}
            Settings = @{
                DefaultView = "Dashboard"
                Theme = "Modern"
                AutoSave = $true
                BackupCount = 5
            }
            time_entries = @() # underscore format for action compatibility
            timers = @()       # for action compatibility
        }

        $this.{_dataFilePath} = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\pmc-data.json"
        $this.{_backupPath} = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\backups"

        Invoke-WithErrorHandling -Component "DataManager.Constructor" -Context "DataManager initialization" -ScriptBlock {
            $dataDirectory = Split-Path $this.{_dataFilePath} -Parent
            if (-not (Test-Path $dataDirectory)) {
                New-Item -ItemType Directory -Path $dataDirectory -Force | Out-Null
                Write-Log -Level Info -Message "Created data directory: $dataDirectory"
            }
            
            if (-not (Test-Path $this.{_backupPath})) {
                New-Item -ItemType Directory -Path $this.{_backupPath} -Force | Out-Null
                Write-Log -Level Info -Message "Created backup directory: $($this.{_backupPath})"
            }
            
            $this.LoadData()
            $this.InitializeEventHandlers()
            
            Write-Log -Level Info -Message "DataManager initialized successfully"
        }
    }

    hidden [void] InitializeEventHandlers() {
        # Capture the current instance ($this) into a local variable so the
        # scriptblocks below can access it.
        $local:self = $this
        Invoke-WithErrorHandling -Component "DataManager.InitializeEventHandlers" -Context "Initializing data event handlers" -ScriptBlock {
            # The handler scriptblock captures $local:self from its parent scope.
            Subscribe-Event -EventName "Tasks.RefreshRequested" -Handler {
                param($EventData)
                Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Refreshed"; Tasks = @($local:self.{_dataStore}.Tasks) }
            }
            Write-Log -Level Debug -Message "Data event handlers initialized"
        }
    }
    #endregion

    #region Data Persistence
    hidden [void] LoadData() {
        Invoke-WithErrorHandling -Component "DataManager.LoadData" -Context "Loading unified data from disk" -ScriptBlock {
            if (Test-Path $this.{_dataFilePath}) {
                try {
                    $loadedData = Get-Content -Path $this.{_dataFilePath} -Raw | ConvertFrom-Json -AsHashtable
                    
                    if ($loadedData -is [hashtable]) {
                        if ($loadedData.Tasks) {
                            $this.{_dataStore}.Tasks.Clear()
                            foreach ($taskData in $loadedData.Tasks) {
                                if ($taskData -is [hashtable]) { 
                                    try {
                                        $task = [PmcTask]::FromLegacyFormat($taskData)
                                        $this.{_dataStore}.Tasks.Add($task) | Out-Null
                                    } catch {
                                        Write-Log -Level Warning -Message "Failed to load task: $_"
                                    }
                                }
                            }
                            Write-Log -Level Debug -Message "Loaded $($this.{_dataStore}.Tasks.Count) tasks as PmcTask objects"
                        }
                        
                        if ($loadedData.Projects -is [hashtable]) {
                            $this.{_dataStore}.Projects.Clear()
                            foreach ($projectKey in $loadedData.Projects.Keys) {
                                $projectData = $loadedData.Projects[$projectKey]
                                if ($projectData -is [hashtable]) { $this.{_dataStore}.Projects.Add([PmcProject]::FromLegacyFormat($projectData)) }
                            }
                            Write-Log -Level Debug -Message "Re-hydrated $($this.{_dataStore}.Projects.Count) projects as PmcProject objects"
                        }
                        
                        foreach ($key in 'TimeEntries', 'ActiveTimers', 'TodoTemplates', 'Settings', 'time_entries', 'timers') {
                            if ($loadedData.ContainsKey($key)) { $this.{_dataStore}[$key] = $loadedData[$key] }
                        }
                        
                        Write-Log -Level Info -Message "Data loaded successfully from disk"
                    } else {
                        Write-Log -Level Warning -Message "Invalid data format in file, using defaults"
                    }
                } catch {
                    Write-Log -Level Error -Message "Failed to parse data file: $_"
                }
            } else {
                Write-Log -Level Info -Message "No existing data file found, creating sample data"
                
                $defaultProject = [PmcProject]::new("GENERAL", "General Tasks")
                $this.{_dataStore}.Projects.Add($defaultProject)
                
                $sampleTasks = @(
                    [PmcTask]::new("Welcome to PMC Terminal!", "This is your task management system", [TaskPriority]::High, "GENERAL"),
                    [PmcTask]::new("Review the documentation", "Check out the help files to learn more", [TaskPriority]::Medium, "GENERAL"),
                    [PmcTask]::new("Create your first project", "Use the project management features", [TaskPriority]::Low, "GENERAL")
                )
                
                foreach ($task in $sampleTasks) { $this.{_dataStore}.Tasks.Add($task) }
                
                Write-Log -Level Info -Message "Created $($sampleTasks.Count) sample tasks"
                $this.SaveData()
            }
            
            $this.{_lastSaveTime} = Get-Date
        }
    }

    hidden [void] SaveData() {
        Invoke-WithErrorHandling -Component "DataManager.SaveData" -Context "Saving unified data to disk" -ScriptBlock {
            if (Test-Path $this.{_dataFilePath}) {
                $backupName = "pmc-data_{0:yyyyMMdd_HHmmss}.json" -f (Get-Date)
                Copy-Item -Path $this.{_dataFilePath} -Destination (Join-Path $this.{_backupPath} $backupName) -Force
                
                $backups = Get-ChildItem -Path $this.{_backupPath} -Filter "pmc-data_*.json" | Sort-Object LastWriteTime -Descending
                if ($backups.Count -gt $this.{_dataStore}.Settings.BackupCount) {
                    $backups | Select-Object -Skip $this.{_dataStore}.Settings.BackupCount | Remove-Item -Force
                }
            }
            
            $dataToSave = @{
                Tasks = @($this.{_dataStore}.Tasks | ForEach-Object { $_.ToLegacyFormat() })
                Projects = @{}
                TimeEntries = $this.{_dataStore}.TimeEntries
                ActiveTimers = $this.{_dataStore}.ActiveTimers
                TodoTemplates = $this.{_dataStore}.TodoTemplates
                Settings = $this.{_dataStore}.Settings
                time_entries = $this.{_dataStore}.time_entries
                timers = $this.{_dataStore}.timers
            }
            
            foreach ($project in $this.{_dataStore}.Projects) { $dataToSave.Projects[$project.Key] = $project.ToLegacyFormat() }
            
            $dataToSave | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.{_dataFilePath} -Encoding UTF8
            $this.{_lastSaveTime} = Get-Date; $this.{_dataModified} = $false
            Write-Log -Level Debug -Message "Data saved successfully"
        }
    }
    #endregion

    #region Task Management Methods
    [PmcTask] AddTask([string]$Title, [string]$Description, [string]$Priority, [string]$ProjectKey, [string]$DueDate = "") {
        return Invoke-WithErrorHandling -Component "DataManager.AddTask" -Context "Adding new task" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($Title)) { 
                throw "Task title cannot be empty"
            }
            $taskPriority = [TaskPriority]::$Priority
            $newTask = [PmcTask]::new($Title, $Description, $taskPriority, $ProjectKey)
            if ($DueDate -and $DueDate -ne "N/A") {
                try { $newTask.DueDate = [datetime]::Parse($DueDate) } catch { }
            }
            $this.{_dataStore}.Tasks.Add($newTask); $this.{_dataModified} = $true
            if ($this.{_dataStore}.Settings.AutoSave) { $this.SaveData() }
            Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Created"; TaskId = $newTask.Id; Task = $newTask }
            return $newTask
        }
    }

    [PmcTask] UpdateTask([hashtable]$UpdateParameters) {
        return Invoke-WithErrorHandling -Component "DataManager.UpdateTask" -Context "Updating task" -ScriptBlock {
            if (-not $UpdateParameters.ContainsKey('Task')) {
                throw "The 'UpdateParameters' hashtable must contain a 'Task' key with the task object to update."
            }
            $Task = $UpdateParameters.Task
            $managedTask = $this.{_dataStore}.Tasks.Find({$_.Id -eq $Task.Id})
            if (-not $managedTask) { throw "Task not found in data store" }
            
            $updatedFields = @()
            if ($UpdateParameters.ContainsKey('Title')) { $managedTask.Title = $UpdateParameters.Title.Trim(); $updatedFields += "Title" }
            if ($UpdateParameters.ContainsKey('Description')) { $managedTask.Description = $UpdateParameters.Description; $updatedFields += "Description" }
            if ($UpdateParameters.ContainsKey('Priority')) { $managedTask.Priority = [TaskPriority]::$($UpdateParameters.Priority); $updatedFields += "Priority" }
            if ($UpdateParameters.ContainsKey('Category')) { $managedTask.ProjectKey = $UpdateParameters.Category; $managedTask.Category = $UpdateParameters.Category; $updatedFields += "Category" }
            if ($UpdateParameters.ContainsKey('DueDate')) {
                try { $managedTask.DueDate = ($UpdateParameters.DueDate -and $UpdateParameters.DueDate -ne "N/A") ? [datetime]::Parse($UpdateParameters.DueDate) : $null } catch { Write-Log -Level Warning -Message "Invalid due date format: $($UpdateParameters.DueDate)" }
                $updatedFields += "DueDate"
            }
            if ($UpdateParameters.ContainsKey('Progress')) { $managedTask.UpdateProgress($UpdateParameters.Progress); $updatedFields += "Progress" }
            if ($UpdateParameters.ContainsKey('Completed')) {
                if ($UpdateParameters.Completed) { $managedTask.Complete() } else { $managedTask.Status = [TaskStatus]::Pending; $managedTask.Completed = $false; $managedTask.Progress = 0 }
                $updatedFields += "Completed"
            }
            
            $managedTask.UpdatedAt = [datetime]::Now; $this.{_dataModified} = $true
            Write-Log -Level Info -Message "Updated task $($managedTask.Id) - Fields: $($updatedFields -join ', ')"
            
            if ($this.{_dataStore}.Settings.AutoSave) { $this.SaveData() }
            
            Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Updated"; TaskId = $managedTask.Id; Task = $managedTask; UpdatedFields = $updatedFields }
            return $managedTask
        }
    }

    [bool] RemoveTask([PmcTask]$Task) {
        return Invoke-WithErrorHandling -Component "DataManager.RemoveTask" -Context "Removing task" -ScriptBlock {
            $taskToRemove = $this.{_dataStore}.Tasks.Find({param($t) $t.Id -eq $Task.Id})
            if ($taskToRemove) {
                [void]$this.{_dataStore}.Tasks.Remove($taskToRemove)
                $this.{_dataModified} = $true
                Write-Log -Level Info -Message "Deleted task $($Task.Id)"
                if ($this.{_dataStore}.Settings.AutoSave) { $this.SaveData() }
                Publish-Event -EventName "Tasks.Changed" -Data @{ Action = "Deleted"; TaskId = $Task.Id; Task = $Task }
                return $true
            }
            Write-Log -Level Warning -Message "Task not found with ID $($Task.Id)"; return $false
        }
    }

        [PmcTask[]] GetTasks([bool]$Completed = $null, [string]$Priority = $null, [string]$Category = $null) {
        return Invoke-WithErrorHandling -Component "DataManager.GetTasks" -Context "Retrieving tasks" -ScriptBlock {
            $tasks = $this.{_dataStore}.Tasks
                        if ($null -ne $Completed) { $tasks = $tasks | Where-Object { $_.Completed -eq $Completed } }
            if ($Priority) { $priorityEnum = [TaskPriority]::$Priority; $tasks = $tasks | Where-Object { $_.Priority -eq $priorityEnum } }
            if ($Category) { $tasks = $tasks | Where-Object { $_.ProjectKey -eq $Category -or $_.Category -eq $Category } }
            return @($tasks)
        }
    }
    #endregion

    #region Project Management Methods
    [PmcProject[]] GetProjects() { return @($this.{_dataStore}.Projects) }
    [PmcProject] GetProject([string]$Key) { return $this.{_dataStore}.Projects.Find({$_.Key -eq $Key}) }

    [PmcProject] AddProject([PmcProject]$Project) {
        return Invoke-WithErrorHandling -Component "DataManager.AddProject" -Context "Adding project" -ScriptBlock {
            if ($this.{_dataStore}.Projects.Exists({$_.Key -eq $Project.Key})) { 
                throw "Project with key '$($Project.Key)' already exists"
            }
            $this.{_dataStore}.Projects.Add($Project); $this.{_dataModified} = $true
            Write-Log -Level Info -Message "Created project '$($Project.Name)' with key $($Project.Key)"
            if ($this.{_dataStore}.Settings.AutoSave) { $this.SaveData() }
            Publish-Event -EventName "Projects.Changed" -Data @{ Action = "Created"; ProjectKey = $Project.Key; Project = $Project }
            return $Project
        }
    }
    #endregion
}
