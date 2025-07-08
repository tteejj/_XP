# ==============================================================================
# Axiom-Phoenix v4.0 - All Models (No UI Dependencies) - UPDATED
# Data models, enums, and validation classes
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: AMO.###" to find specific sections.
# Each section ends with "END_PAGE: AMO.###"
# ==============================================================================

#<!-- PAGE: AMO.001 - Enums -->
#region Enums

enum TaskStatus {
    Pending
    InProgress
    Completed
    Cancelled
}

enum TaskPriority {
    Low
    Medium
    High
}

enum BillingType {
    Billable
    NonBillable
}

enum DialogResult {
    None
    OK
    Cancel
    Yes
    No
    Abort
    Retry
    Ignore
}

#endregion
#<!-- END_PAGE: AMO.001 -->

#<!-- PAGE: AMO.002 - ValidationBase Class -->
#region Base Validation Class

# ===== CLASS: ValidationBase =====
# Module: models (from axiom)
# Dependencies: None
# Purpose: Provides common validation methods used across model classes
class ValidationBase {
    # Validates that a string value is not null, empty, or whitespace.
    # Throws an ArgumentException if the validation fails.
    static [void] ValidateNotEmpty(
        [string]$value,
        [string]$parameterName
    ) {
        try {
            if ([string]::IsNullOrWhiteSpace($value)) {
                $errorMessage = "Parameter '$($parameterName)' cannot be null or empty."
                throw [System.ArgumentException]::new($errorMessage, $parameterName)
            }
        }
        catch {
            # Re-throw to ensure calling context handles the exception
            throw
        }
    }
}

#endregion
#<!-- END_PAGE: AMO.002 -->

#<!-- PAGE: AMO.003 - Core Model Classes -->
#region Core Model Classes

# ===== CLASS: PmcTask =====
# Module: models (from axiom)
# Dependencies: ValidationBase, TaskStatus, TaskPriority enums
# Purpose: Represents a single task with lifecycle methods
class PmcTask : ValidationBase {
    [string]$Id = [Guid]::NewGuid().ToString() # Unique identifier for the task
    [string]$Title                            # Short descriptive title
    [string]$Description                      # Detailed description
    [TaskStatus]$Status = [TaskStatus]::Pending # Current status of the task
    [TaskPriority]$Priority = [TaskPriority]::Medium # Importance level
    [string]$ProjectKey = "General"           # Associated project (key)
    [string]$Category                         # Alias for ProjectKey, for broader use
    [datetime]$CreatedAt = [datetime]::Now   # Timestamp of creation
    [datetime]$UpdatedAt = [datetime]::Now   # Last update timestamp
    [Nullable[datetime]]$DueDate             # Optional due date
    [string[]]$Tags = @()                     # Array of tags
    [int]$Progress = 0                        # Progress percentage (0-100)
    [bool]$Completed = $false                 # Convenience flag for completed status

    # Default constructor: Initializes a new task with default values.
    PmcTask() {}
    
    # Constructor: Initializes a new task with a title.
    PmcTask([string]$title) {
        [ValidationBase]::ValidateNotEmpty($title, "Title")
        $this.Title = $title
    }
    
    # Constructor: Initializes a new task with common detailed properties.
    PmcTask(
        [string]$title,
        [string]$description,
        [TaskPriority]$priority,
        [string]$projectKey
    ) {
        [ValidationBase]::ValidateNotEmpty($title, "Title")
        [ValidationBase]::ValidateNotEmpty($projectKey, "ProjectKey")

        $this.Title = $title
        $this.Description = $description
        $this.Priority = $priority
        $this.ProjectKey = $projectKey
        $this.Category = $projectKey # Category is often an alias for ProjectKey
    }

    # Complete: Marks the task as completed, setting progress to 100% and updating timestamp.
    [void] Complete() {
        $this.Status = [TaskStatus]::Completed
        $this.Progress = 100
        $this.Completed = $true
        $this.UpdatedAt = [datetime]::Now
    }
    
    # Cancel: Marks the task as cancelled and updates timestamp.
    [void] Cancel() {
        $this.Status = [TaskStatus]::Cancelled
        $this.UpdatedAt = [datetime]::Now
    }
    
    # SetProgress: Updates the progress percentage and adjusts status accordingly.
    [void] SetProgress([int]$progress) {
        if ($progress -lt 0 -or $progress -gt 100) {
            throw [System.ArgumentOutOfRangeException]::new("progress", "Progress must be between 0 and 100.")
        }
        
        $this.Progress = $progress
        
        # Auto-update status based on progress
        if ($progress -eq 0 -and $this.Status -eq [TaskStatus]::InProgress) {
            $this.Status = [TaskStatus]::Pending
        }
        elseif ($progress -gt 0 -and $progress -lt 100) {
            $this.Status = [TaskStatus]::InProgress
        }
        elseif ($progress -eq 100) {
            $this.Complete()
        }
        
        $this.UpdatedAt = [datetime]::Now
    }
    
    # AddTag: Adds a tag to the task if not already present.
    [void] AddTag([string]$tag) {
        [ValidationBase]::ValidateNotEmpty($tag, "Tag")
        if ($this.Tags -notcontains $tag) {
            $this.Tags += $tag
            $this.UpdatedAt = [datetime]::Now
        }
    }
    
    # RemoveTag: Removes a tag from the task.
    [void] RemoveTag([string]$tag) {
        $this.Tags = $this.Tags | Where-Object { $_ -ne $tag }
        $this.UpdatedAt = [datetime]::Now
    }
    
    # GetAge: Returns the age of the task as a TimeSpan.
    [TimeSpan] GetAge() {
        return [datetime]::Now - $this.CreatedAt
    }
    
    # IsOverdue: Checks if the task is overdue based on DueDate.
    [bool] IsOverdue() {
        if ($null -eq $this.DueDate) { return $false }
        if ($this.Status -in @([TaskStatus]::Completed, [TaskStatus]::Cancelled)) { return $false }
        return [datetime]::Now -gt $this.DueDate
    }
    
    # Clone: Creates a deep copy of the task with a new ID.
    [PmcTask] Clone() {
        $clone = [PmcTask]::new()
        $clone.Title = $this.Title
        $clone.Description = $this.Description
        $clone.Status = $this.Status
        $clone.Priority = $this.Priority
        $clone.ProjectKey = $this.ProjectKey
        $clone.Category = $this.Category
        $clone.DueDate = $this.DueDate
        $clone.Tags = $this.Tags.Clone()
        $clone.Progress = $this.Progress
        $clone.Completed = $this.Completed
        # New task gets new timestamps and ID
        $clone.CreatedAt = [datetime]::Now
        $clone.UpdatedAt = [datetime]::Now
        return $clone
    }
    
    # ToLegacyFormat: Converts task to hashtable for JSON serialization
    [hashtable] ToLegacyFormat() {
        return @{
            Id = $this.Id
            Title = $this.Title
            Description = $this.Description
            Status = $this.Status.ToString()
            Priority = $this.Priority.ToString()
            ProjectKey = $this.ProjectKey
            Category = $this.Category
            CreatedAt = $this.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ss")
            UpdatedAt = $this.UpdatedAt.ToString("yyyy-MM-ddTHH:mm:ss")
            DueDate = if ($this.DueDate) { $this.DueDate.ToString("yyyy-MM-ddTHH:mm:ss") } else { $null }
            Tags = $this.Tags
            Progress = $this.Progress
            Completed = $this.Completed
        }
    }
    
    # FromLegacyFormat: Creates task from hashtable (JSON deserialization)
    static [PmcTask] FromLegacyFormat([hashtable]$data) {
        $task = [PmcTask]::new()
        
        if ($data.ContainsKey('Id')) { $task.Id = $data.Id }
        if ($data.ContainsKey('Title')) { $task.Title = $data.Title }
        if ($data.ContainsKey('Description')) { $task.Description = $data.Description }
        if ($data.ContainsKey('Status')) { 
            $task.Status = [System.Enum]::Parse([TaskStatus], $data.Status, $true)
        }
        if ($data.ContainsKey('Priority')) { 
            $task.Priority = [System.Enum]::Parse([TaskPriority], $data.Priority, $true)
        }
        if ($data.ContainsKey('ProjectKey')) { $task.ProjectKey = $data.ProjectKey }
        if ($data.ContainsKey('Category')) { $task.Category = $data.Category }
        if ($data.ContainsKey('CreatedAt')) { 
            $task.CreatedAt = [DateTime]::Parse($data.CreatedAt)
        }
        if ($data.ContainsKey('UpdatedAt')) { 
            $task.UpdatedAt = [DateTime]::Parse($data.UpdatedAt)
        }
        if ($data.ContainsKey('DueDate') -and $data.DueDate) { 
            $task.DueDate = [DateTime]::Parse($data.DueDate)
        }
        if ($data.ContainsKey('Tags')) { $task.Tags = @($data.Tags) }
        if ($data.ContainsKey('Progress')) { $task.Progress = [int]$data.Progress }
        if ($data.ContainsKey('Completed')) { $task.Completed = [bool]$data.Completed }
        
        return $task
    }
    
    # ToString: Returns a string representation of the task.
    [string] ToString() {
        $statusSymbol = switch ($this.Status) {
            ([TaskStatus]::Pending) { "○" }
            ([TaskStatus]::InProgress) { "◐" }
            ([TaskStatus]::Completed) { "●" }
            ([TaskStatus]::Cancelled) { "✕" }
            default { "?" }
        }
        
        $prioritySymbol = switch ($this.Priority) {
            ([TaskPriority]::Low) { "↓" }
            ([TaskPriority]::Medium) { "→" }
            ([TaskPriority]::High) { "↑" }
            default { "-" }
        }
        
        $overdueFlag = if ($this.IsOverdue()) { " [OVERDUE]" } else { "" }
        
        return "$statusSymbol $prioritySymbol $($this.Title) ($($this.Progress)%)$overdueFlag"
    }
}

# ===== CLASS: PmcProject =====
# Module: models (from axiom)
# Dependencies: ValidationBase
# Purpose: Represents a project that contains multiple tasks
class PmcProject : ValidationBase {
    [string]$Key                              # Unique project key (e.g., "PROJ-001")
    [string]$Name                             # Project name
    [string]$Description                      # Project description
    [DateTime]$CreatedAt = [DateTime]::Now  # Creation timestamp
    [DateTime]$UpdatedAt = [DateTime]::Now  # Last update timestamp
    [string]$Owner                           # Project owner
    [string[]]$Tags = @()                    # Project tags
    [hashtable]$Metadata = @{}               # Additional project metadata
    [bool]$IsActive = $true                  # Whether project is active
    
    # Enhanced properties from reference implementation
    [string]$ID1                             # Optional secondary identifier
    [Nullable[datetime]]$BFDate              # Bring-Forward date for follow-ups
    [string]$ProjectFolderPath               # Full path to the project's root folder on disk
    [string]$CaaFileName                     # Relative name of the associated CAA file
    [string]$RequestFileName                 # Relative name of the associated Request file
    [string]$T2020FileName                   # Relative name of the associated T2020 file

    # Default constructor
    PmcProject() {}

    # Constructor with key and name
    PmcProject([string]$key, [string]$name) {
        [ValidationBase]::ValidateNotEmpty($key, "Key")
        [ValidationBase]::ValidateNotEmpty($name, "Name")
        $this.Key = $key
        $this.Name = $name
    }

    # Constructor with full details
    PmcProject([string]$key, [string]$name, [string]$description, [string]$owner) {
        [ValidationBase]::ValidateNotEmpty($key, "Key")
        [ValidationBase]::ValidateNotEmpty($name, "Name")
        [ValidationBase]::ValidateNotEmpty($owner, "Owner")
        
        $this.Key = $key
        $this.Name = $name
        $this.Description = $description
        $this.Owner = $owner
    }

    # Archive: Marks the project as inactive
    [void] Archive() {
        $this.IsActive = $false
        $this.UpdatedAt = [DateTime]::Now
    }

    # Activate: Marks the project as active
    [void] Activate() {
        $this.IsActive = $true
        $this.UpdatedAt = [DateTime]::Now
    }

    # AddTag: Adds a tag to the project if not already present
    [void] AddTag([string]$tag) {
        [ValidationBase]::ValidateNotEmpty($tag, "Tag")
        if ($this.Tags -notcontains $tag) {
            $this.Tags += $tag
            $this.UpdatedAt = [DateTime]::Now
        }
    }

    # RemoveTag: Removes a tag from the project
    [void] RemoveTag([string]$tag) {
        $this.Tags = $this.Tags | Where-Object { $_ -ne $tag }
        $this.UpdatedAt = [DateTime]::Now
    }

    # SetMetadata: Sets a metadata key-value pair
    [void] SetMetadata([string]$key, $value) {
        [ValidationBase]::ValidateNotEmpty($key, "Key")
        $this.Metadata[$key] = $value
        $this.UpdatedAt = [DateTime]::Now
    }

    # GetMetadata: Gets a metadata value by key
    [object] GetMetadata([string]$key) {
        return $this.Metadata[$key]
    }
    
    # ToLegacyFormat: Converts project to hashtable for JSON serialization
    [hashtable] ToLegacyFormat() {
        return @{
            Key = $this.Key
            Name = $this.Name
            Description = $this.Description
            CreatedAt = $this.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ss")
            UpdatedAt = $this.UpdatedAt.ToString("yyyy-MM-ddTHH:mm:ss")
            Owner = $this.Owner
            Tags = $this.Tags
            Metadata = $this.Metadata.Clone()
            IsActive = $this.IsActive
        }
    }
    
    # FromLegacyFormat: Creates project from hashtable (JSON deserialization)
    static [PmcProject] FromLegacyFormat([hashtable]$data) {
        $project = [PmcProject]::new()
        
        if ($data.ContainsKey('Key')) { $project.Key = $data.Key }
        if ($data.ContainsKey('Name')) { $project.Name = $data.Name }
        if ($data.ContainsKey('Description')) { $project.Description = $data.Description }
        if ($data.ContainsKey('CreatedAt')) { 
            $project.CreatedAt = [DateTime]::Parse($data.CreatedAt)
        }
        if ($data.ContainsKey('UpdatedAt')) { 
            $project.UpdatedAt = [DateTime]::Parse($data.UpdatedAt)
        }
        if ($data.ContainsKey('Owner')) { $project.Owner = $data.Owner }
        if ($data.ContainsKey('Tags')) { $project.Tags = @($data.Tags) }
        if ($data.ContainsKey('Metadata')) { $project.Metadata = $data.Metadata.Clone() }
        if ($data.ContainsKey('IsActive')) { $project.IsActive = [bool]$data.IsActive }
        
        return $project
    }

    # ToString: Returns a string representation of the project
    [string] ToString() {
        $status = if ($this.IsActive) { "Active" } else { "Archived" }
        return "[$($this.Key)] $($this.Name) - $status"
    }
}

# ===== CLASS: TimeEntry =====
# Module: models (from axiom)
# Dependencies: ValidationBase, BillingType enum
# Purpose: Represents a time entry for a task
class TimeEntry : ValidationBase {
    [string]$Id = [Guid]::NewGuid().ToString()  # Unique identifier
    [string]$TaskId                              # Associated task ID
    [string]$ProjectKey                          # Associated project key
    [DateTime]$StartTime                         # When work started
    [Nullable[DateTime]]$EndTime                 # When work ended (null if ongoing)
    [string]$Description                         # What was done
    [BillingType]$BillingType = [BillingType]::Billable # Billing classification
    [string]$UserId                              # Who logged the time
    [decimal]$HourlyRate = 0                    # Rate per hour (if applicable)
    [hashtable]$Metadata = @{}                   # Additional metadata

    # Default constructor
    TimeEntry() {}

    # Constructor with basic details
    TimeEntry([string]$taskId, [string]$projectKey, [DateTime]$startTime) {
        [ValidationBase]::ValidateNotEmpty($taskId, "TaskId")
        [ValidationBase]::ValidateNotEmpty($projectKey, "ProjectKey")
        
        $this.TaskId = $taskId
        $this.ProjectKey = $projectKey
        $this.StartTime = $startTime
    }

    # GetDuration: Returns the duration of the time entry
    [TimeSpan] GetDuration() {
        if ($null -eq $this.EndTime) {
            return [DateTime]::Now - $this.StartTime
        }
        return $this.EndTime - $this.StartTime
    }

    # GetHours: Returns the duration in decimal hours
    [decimal] GetHours() {
        return [decimal]($this.GetDuration().TotalHours)
    }

    # GetTotalValue: Returns the monetary value of the time entry
    [decimal] GetTotalValue() {
        if ($this.BillingType -eq [BillingType]::NonBillable) {
            return 0
        }
        return $this.GetHours() * $this.HourlyRate
    }

    # Stop: Stops the timer on this entry
    [void] Stop() {
        if ($null -eq $this.EndTime) {
            $this.EndTime = [DateTime]::Now
        }
    }

    # IsRunning: Checks if the time entry is still running
    [bool] IsRunning() {
        return $null -eq $this.EndTime
    }

    # ToString: Returns a string representation of the time entry
    [string] ToString() {
        $duration = $this.GetDuration()
        $status = if ($this.IsRunning()) { "Running" } else { "Completed" }
        return "$($this.ProjectKey) - $($duration.ToString('hh\:mm\:ss')) [$status]"
    }
}

#endregion
#<!-- END_PAGE: AMO.003 -->

#<!-- PAGE: AMO.004 - Exception Classes -->
#region Exception Classes

# ===== CLASS: HeliosException =====
# Module: exceptions (from axiom)
# Dependencies: None (inherits from System.Exception)
# Purpose: Base exception for all framework exceptions
class HeliosException : System.Exception {
    [string]$ErrorCode
    [hashtable]$Context = @{}
    [string]$Component
    [DateTime]$Timestamp
    
    HeliosException([string]$message) : base($message) {
        $this.Timestamp = [DateTime]::Now
    }
    
    HeliosException([string]$message, [string]$component) : base($message) {
        $this.Component = $component
        $this.Timestamp = [DateTime]::Now
    }
    
    HeliosException([string]$message, [string]$component, [hashtable]$context) : base($message) {
        $this.Component = $component
        $this.Context = $context
        $this.Timestamp = [DateTime]::Now
    }
    
    HeliosException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $innerException) {
        $this.Component = $component
        $this.Context = $context
        $this.Timestamp = [DateTime]::Now
    }
}

# ===== CLASS: NavigationException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for navigation-related errors
class NavigationException : HeliosException {
    NavigationException([string]$message) : base($message) {}
    NavigationException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

# ===== CLASS: ServiceInitializationException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for service initialization failures
class ServiceInitializationException : HeliosException {
    ServiceInitializationException([string]$message) : base($message) {}
    ServiceInitializationException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

# ===== CLASS: ComponentRenderException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for component rendering failures
class ComponentRenderException : HeliosException {
    ComponentRenderException([string]$message) : base($message) {}
    ComponentRenderException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

# ===== CLASS: StateMutationException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for state mutation errors
class StateMutationException : HeliosException {
    StateMutationException([string]$message) : base($message) {}
    StateMutationException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

# ===== CLASS: InputHandlingException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for input handling errors
class InputHandlingException : HeliosException {
    InputHandlingException([string]$message) : base($message) {}
    InputHandlingException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

# ===== CLASS: DataLoadException =====
# Module: exceptions (from axiom)
# Dependencies: HeliosException
# Purpose: Exception for data loading errors
class DataLoadException : HeliosException {
    DataLoadException([string]$message) : base($message) {}
    DataLoadException([string]$message, [string]$component, [hashtable]$context, [Exception]$innerException) : base($message, $component, $context, $innerException) {}
}

#endregion
#<!-- END_PAGE: AMO.004 -->

#<!-- PAGE: AMO.005 - Navigation Classes -->
#region Navigation Classes

# ===== CLASS: NavigationItem =====
# Module: navigation-class (from axiom)
# Dependencies: None
# Purpose: Represents a menu item for local/contextual navigation
class NavigationItem {
    [string]$Key
    [string]$Label
    [scriptblock]$Action
    [bool]$Enabled = $true
    [bool]$Visible = $true
    [string]$Description = ""

    NavigationItem([string]$key, [string]$label, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw [System.ArgumentException]::new("Navigation key cannot be null or empty")
        }
        if ([string]::IsNullOrWhiteSpace($label)) {
            throw [System.ArgumentException]::new("Navigation label cannot be null or empty")
        }
        if (-not $action) {
            throw [System.ArgumentNullException]::new("action", "Navigation action cannot be null")
        }

        $this.Key = $key.ToUpper()
        $this.Label = $label
        $this.Action = $action
    }

    [void] Execute() {
        try {
            if (-not $this.Enabled) {
                return
            }
            
            & $this.Action
        }
        catch {
            throw
        }
    }

    [string] ToString() {
        return "NavigationItem(Key='$($this.Key)', Label='$($this.Label)', Enabled=$($this.Enabled))"
    }
}

#endregion
#<!-- END_PAGE: AMO.005 -->
