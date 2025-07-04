# data-manager Module

## Overview
The `data-manager` module provides a high-performance, transaction-safe data persistence service for the PMC Terminal application. It handles all task and project data with comprehensive error handling, automatic backups, and event-driven updates.

## Features
- **High-Performance Indexing** - O(1) lookups using dictionary indexes
- **Transactional Operations** - BeginUpdate/EndUpdate for bulk operations
- **Automatic Backups** - Configurable backup retention and rotation
- **Event Integration** - Publishes data change events
- **Type Safety** - Strong typing with PmcTask and PmcProject models
- **Lifecycle Management** - IDisposable implementation for resource cleanup
- **Auto-Save Support** - Configurable automatic saving
- **Error Recovery** - Robust error handling with detailed logging

## DataManager Class

The `DataManager` class is the core service that manages all data operations.

### Initialization
```powershell
# Initialize through factory function
$dataManager = Initialize-DataManager

# The service automatically:
# - Sets up data file paths
# - Creates backup directories
# - Loads existing data
# - Builds performance indexes
# - Initializes event handlers
```

### Data Storage Structure
The DataManager maintains data in a structured format:
```powershell
@{
    Projects = [System.Collections.ArrayList] # List of PmcProject objects
    Tasks = [System.Collections.ArrayList]    # List of PmcTask objects
    Settings = @{
        AutoSave = $true
        BackupCount = 5
        LastSaveTime = [datetime]
    }
}
```

## Task Management

### Adding Tasks
```powershell
# Create new task
$task = [PmcTask]@{
    Id = [guid]::NewGuid().ToString()
    Title = "Complete project documentation"
    Description = "Write comprehensive documentation for the new feature"
    Status = "InProgress"
    Priority = "High"
    ProjectKey = "PROJ-001"
    CreatedAt = [datetime]::Now
}

# Add to data manager
$addedTask = $dataManager.AddTask($task)
```

### Updating Tasks
```powershell
# Get existing task
$task = $dataManager.GetTask("task-id-here")

# Modify properties
$task.Status = "Completed"
$task.CompletedAt = [datetime]::Now

# Update in data manager
$updatedTask = $dataManager.UpdateTask($task)
```

### Removing Tasks
```powershell
# Remove by ID
$success = $dataManager.RemoveTask("task-id-here")

if ($success) {
    Write-Host "Task removed successfully"
}
```

### Querying Tasks
```powershell
# Get all tasks
$allTasks = $dataManager.GetTasks()

# Filter by project
$projectTasks = $dataManager.GetTasks() | Where-Object { $_.ProjectKey -eq "PROJ-001" }

# Filter by status
$inProgressTasks = $dataManager.GetTasks() | Where-Object { $_.Status -eq "InProgress" }

# Get single task by ID (high-performance indexed lookup)
$task = $dataManager.GetTask("task-id-here")
```

## Project Management

### Adding Projects
```powershell
# Create new project
$project = [PmcProject]@{
    Key = "PROJ-002"
    Name = "Mobile App Development"
    Description = "Develop cross-platform mobile application"
    Status = "Active"
    CreatedAt = [datetime]::Now
}

# Add to data manager
$addedProject = $dataManager.AddProject($project)
```

### Updating Projects
```powershell
# Get existing project
$project = $dataManager.GetProject("PROJ-002")

# Modify properties
$project.Status = "Completed"
$project.CompletedAt = [datetime]::Now

# Update in data manager
$updatedProject = $dataManager.UpdateProject($project)
```

### Querying Projects
```powershell
# Get all projects
$allProjects = $dataManager.GetProjects()

# Filter by status
$activeProjects = $dataManager.GetProjects() | Where-Object { $_.Status -eq "Active" }

# Get single project by key (high-performance indexed lookup)
$project = $dataManager.GetProject("PROJ-001")
```

## Transactional Operations

For bulk operations, use transactions to improve performance and ensure data consistency:

```powershell
# Begin transaction (disables auto-save)
$dataManager.BeginUpdate()

try {
    # Perform multiple operations
    $dataManager.AddTask($task1)
    $dataManager.AddTask($task2)
    $dataManager.UpdateTask($existingTask)
    $dataManager.RemoveTask($oldTaskId)
    
    # Commit transaction (single save operation)
    $dataManager.EndUpdate()
} catch {
    # Handle errors - transaction is automatically rolled back
    $dataManager.EndUpdate()
    throw
}
```

### Nested Transactions
Transactions can be nested safely:
```powershell
$dataManager.BeginUpdate()  # Level 1
try {
    $dataManager.AddTask($task1)
    
    $dataManager.BeginUpdate()  # Level 2
    try {
        $dataManager.AddTask($task2)
        $dataManager.AddTask($task3)
        $dataManager.EndUpdate()  # End Level 2
    } catch {
        $dataManager.EndUpdate()
        throw
    }
    
    $dataManager.EndUpdate()  # End Level 1 - triggers save
} catch {
    $dataManager.EndUpdate()
    throw
}
```

## Event System Integration

The DataManager publishes events for all data changes:

### Task Events
```powershell
# Subscribe to task changes
Subscribe-Event -EventName "Tasks.Changed" -Handler {
    param($EventData)
    $action = $EventData.Data.Action  # "Created", "Updated", "Deleted"
    $task = $EventData.Data.Task      # Task object (for Created/Updated)
    $taskId = $EventData.Data.TaskId  # Task ID (for Deleted)
    
    Write-Host "Task $action`: $($task?.Title ?? $taskId)"
    
    # Refresh UI
    Request-TuiRefresh
}
```

### Project Events
```powershell
# Subscribe to project changes
Subscribe-Event -EventName "Projects.Changed" -Handler {
    param($EventData)
    $action = $EventData.Data.Action      # "Created", "Updated", "Deleted"
    $project = $EventData.Data.Project    # Project object
    
    Write-Host "Project $action`: $($project.Name)"
}
```

## Data Persistence

### File Locations
Default file paths (configurable):
- **Data File:** `%LOCALAPPDATA%\PMCTerminal\pmc-data.json`
- **Backups:** `%LOCALAPPDATA%\PMCTerminal\backups\`

### Backup System
```powershell
# Automatic backups are created on save
# - Backups are timestamped: pmc-data-20250101-120000.json
# - Configurable retention count (default: 5)
# - Old backups are automatically cleaned up

# Manual backup
$dataManager.CreateBackup()

# Restore from backup
$dataManager.RestoreFromBackup("pmc-data-20250101-120000.json")
```

### Auto-Save Configuration
```powershell
# Check auto-save status
$autoSave = $dataManager.IsAutoSaveEnabled()

# Enable/disable auto-save
$dataManager.SetAutoSave($true)
$dataManager.SetAutoSave($false)

# Manual save
$dataManager.SaveData()
```

## Performance Features

### High-Performance Indexing
The DataManager uses dictionary indexes for O(1) lookups:
```powershell
# These operations are O(1) - constant time regardless of data size
$task = $dataManager.GetTask($taskId)           # Direct dictionary lookup
$project = $dataManager.GetProject($projectKey) # Direct dictionary lookup

# These operations are O(n) - use sparingly for large datasets
$tasks = $dataManager.GetTasks() | Where-Object { $_.Status -eq "InProgress" }
```

### Memory Management
```powershell
# The DataManager implements IDisposable
using ($dataManager = Initialize-DataManager) {
    # Use data manager
    $dataManager.AddTask($task)
} # Automatically disposed - final save if needed
```

## Error Handling

### Structured Error Handling
```powershell
try {
    $task = $dataManager.AddTask($invalidTask)
} catch [Helios.DataLoadException] {
    Write-Host "Data error: $($_.Exception.Message)"
} catch [System.IO.IOException] {
    Write-Host "File I/O error: $($_.Exception.Message)"
} catch {
    Write-Host "Unexpected error: $($_.Exception.Message)"
}
```

### Error Recovery
```powershell
# If data file is corrupted, DataManager attempts recovery
# 1. Try to load from most recent backup
# 2. If backups fail, create empty data store
# 3. Log all recovery attempts
```

## Advanced Usage

### Custom Data Paths
```powershell
# Initialize with custom paths
$dataManager = [DataManager]::new()
$dataManager.SetDataPath("C:\MyApp\data.json")
$dataManager.SetBackupPath("C:\MyApp\backups")
```

### Bulk Import/Export
```powershell
# Export all data
$allData = @{
    Tasks = $dataManager.GetTasks()
    Projects = $dataManager.GetProjects()
    ExportDate = [datetime]::Now
}
$allData | ConvertTo-Json -Depth 10 | Set-Content "export.json"

# Import data
$importData = Get-Content "export.json" | ConvertFrom-Json
$dataManager.BeginUpdate()
try {
    foreach ($task in $importData.Tasks) {
        $dataManager.AddTask([PmcTask]$task)
    }
    foreach ($project in $importData.Projects) {
        $dataManager.AddProject([PmcProject]$project)
    }
    $dataManager.EndUpdate()
} catch {
    $dataManager.EndUpdate()
    throw
}
```

### Statistics and Reporting
```powershell
# Get data statistics
$stats = @{
    TotalTasks = $dataManager.GetTasks().Count
    TotalProjects = $dataManager.GetProjects().Count
    CompletedTasks = ($dataManager.GetTasks() | Where-Object { $_.Status -eq "Completed" }).Count
    ActiveProjects = ($dataManager.GetProjects() | Where-Object { $_.Status -eq "Active" }).Count
    LastSaveTime = $dataManager.GetLastSaveTime()
}
```

## Best Practices

1. **Use Transactions** - For bulk operations, always use BeginUpdate/EndUpdate
2. **Handle Events** - Subscribe to data change events for UI updates
3. **Error Handling** - Always wrap data operations in try/catch blocks
4. **Resource Cleanup** - Use `using` blocks or call Dispose() when done
5. **Backup Management** - Regularly verify backup integrity
6. **Performance** - Use GetTask/GetProject for single-item lookups
7. **Validation** - Validate data before adding to the data manager

## Integration Example

```powershell
# Complete example: Task management with UI integration
class TaskListScreen : Screen {
    [DataManager]$DataManager
    
    TaskListScreen([ServiceContainer]$container) : base("TaskList", $container) {
        $this.DataManager = $container.GetService("DataManager")
    }
    
    [void] Initialize() {
        # Subscribe to data changes
        $this.SubscribeToEvent("Tasks.Changed", {
            param($EventData)
            $this.RefreshTaskList()
        })
        
        # Load initial data
        $this.RefreshTaskList()
    }
    
    [void] RefreshTaskList() {
        $tasks = $this.DataManager.GetTasks()
        # Update UI with tasks
        $this.UpdateTaskDisplay($tasks)
    }
    
    [void] AddNewTask([string]$title) {
        $task = [PmcTask]@{
            Id = [guid]::NewGuid().ToString()
            Title = $title
            Status = "New"
            CreatedAt = [datetime]::Now
        }
        
        try {
            $this.DataManager.AddTask($task)
            # UI will automatically refresh via event
        } catch {
            Show-ErrorDialog -Message "Failed to add task: $($_.Exception.Message)"
        }
    }
}
```

The DataManager provides a robust, high-performance foundation for all data operations in the PMC Terminal application, ensuring data integrity, performance, and seamless integration with the UI system.
