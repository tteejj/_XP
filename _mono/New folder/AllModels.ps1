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

# ==============================================================================
# CLASS: ValidationBase
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   - None
#
# PURPOSE:
#   A static utility class providing common validation logic for other model
#   classes to inherit. This promotes code reuse for data integrity checks.
#
# KEY LOGIC:
#   - Contains static methods like `ValidateNotEmpty` to enforce data integrity
#     rules (e.g., a task title cannot be empty) in a consistent way across
#     the data model layer.
# ==============================================================================
class ValidationBase {
    static [void] ValidateNotEmpty(
        [string]$value,
        [string]$parameterName
    ) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw [System.ArgumentException]::new("Parameter '$($parameterName)' cannot be null or empty.", $parameterName)
        }
    }
}

#endregion
#<!-- END_PAGE: AMO.002 -->

#<!-- PAGE: AMO.003 - Core Model Classes -->
#region Core Model Classes

# ==============================================================================
# CLASS: PmcTask
#
# INHERITS:
#   - ValidationBase (AMO.002)
#
# DEPENDENCIES:
#   Enums:
#     - TaskStatus (AMO.001)
#     - TaskPriority (AMO.001)
#
# PURPOSE:
#   Represents the core data entity for a single task. It is a plain data
#   object with its own internal business logic, holding no references to UI
#   components.
#
# KEY LOGIC:
#   - Contains properties for all task attributes (Title, Status, Priority, etc.).
#   - Provides business logic methods for state transitions, such as `Complete()`,
#     `SetProgress()`, and checks like `IsOverdue()`.
#   - Includes `ToLegacyFormat()` and `FromLegacyFormat()` static methods for
#     robust JSON serialization/deserialization, decoupling the live class
#     from the on-disk data format.
# ==============================================================================
class PmcTask : ValidationBase {
    [string]$Id = [Guid]::NewGuid().ToString()
    [string]$Title
    [string]$Description
    [TaskStatus]$Status = [TaskStatus]::Pending
    [TaskPriority]$Priority = [TaskPriority]::Medium
    [string]$ProjectKey = "General"
    [string]$Category
    [datetime]$CreatedAt = [datetime]::Now
    [datetime]$UpdatedAt = [datetime]::Now
    [Nullable[datetime]]$DueDate
    [string[]]$Tags = @()
    [int]$Progress = 0
    [bool]$Completed = $false

    PmcTask() {}
    PmcTask([string]$title) {
        [ValidationBase]::ValidateNotEmpty($title, "Title"); $this.Title = $title
    }
    PmcTask([string]$title, [string]$description, [TaskPriority]$priority, [string]$projectKey) {
        [ValidationBase]::ValidateNotEmpty($title, "Title"); [ValidationBase]::ValidateNotEmpty($projectKey, "ProjectKey")
        $this.Title = $title; $this.Description = $description; $this.Priority = $priority; $this.ProjectKey = $projectKey
        $this.Category = $projectKey
    }

    [void] Complete() {
        $this.Status = [TaskStatus]::Completed; $this.Progress = 100; $this.Completed = $true; $this.UpdatedAt = [datetime]::Now
    }
    
    [void] SetProgress([int]$progress) {
        if ($progress -lt 0 -or $progress -gt 100) { throw [System.ArgumentOutOfRangeException]::new("progress", "Progress must be between 0 and 100.") }
        $this.Progress = $progress
        if ($progress -eq 100) { $this.Complete() }
        elseif ($progress -gt 0) { $this.Status = [TaskStatus]::InProgress }
        $this.UpdatedAt = [datetime]::Now
    }
    
    [bool] IsOverdue() {
        if (-not $this.DueDate) { return $false }
        if ($this.Status -in @([TaskStatus]::Completed, [TaskStatus]::Cancelled)) { return $false }
        return [datetime]::Now -gt $this.DueDate
    }
    
    [hashtable] ToLegacyFormat() {
        return @{
            Id = $this.Id; Title = $this.Title; Description = $this.Description; Status = $this.Status.ToString(); Priority = $this.Priority.ToString()
            ProjectKey = $this.ProjectKey; Category = $this.Category; CreatedAt = $this.CreatedAt.ToString("o"); UpdatedAt = $this.UpdatedAt.ToString("o")
            DueDate = if ($this.DueDate) { $this.DueDate.Value.ToString("o") } else { $null }
            Tags = $this.Tags; Progress = $this.Progress; Completed = $this.Completed
        }
    }
    
    static [PmcTask] FromLegacyFormat([hashtable]$data) {
        $task = [PmcTask]::new()
        foreach ($prop in @('Id','Title','Description','ProjectKey','Category')) { if ($data.ContainsKey($prop)) { $task.$prop = $data.$prop } }
        if ($data.Status) { $task.Status = [TaskStatus]$data.Status }
        if ($data.Priority) { $task.Priority = [TaskPriority]$data.Priority }
        if ($data.CreatedAt) { $task.CreatedAt = [DateTime]::Parse($data.CreatedAt) }
        if ($data.UpdatedAt) { $task.UpdatedAt = [DateTime]::Parse($data.UpdatedAt) }
        if ($data.DueDate) { $task.DueDate = [DateTime]::Parse($data.DueDate) }
        if ($data.Tags) { $task.Tags = @($data.Tags) }
        if ($data.ContainsKey('Progress')) { $task.Progress = [int]$data.Progress }
        if ($data.ContainsKey('Completed')) { $task.Completed = [bool]$data.Completed }
        return $task
    }
}

# ==============================================================================
# CLASS: PmcProject
#
# INHERITS:
#   - ValidationBase (AMO.002)
#
# DEPENDENCIES:
#   - None
#
# PURPOSE:
#   Represents a project, which acts as a logical container or category for a
#   group of tasks. It is a plain data object.
#
# KEY LOGIC:
#   - Contains properties like `Key` (a unique identifier), `Name`, and an
#     `IsActive` flag for archival purposes.
#   - Provides methods like `Archive()` and `Activate()` to manage its lifecycle.
#   - Includes `ToLegacyFormat()` and `FromLegacyFormat()` for robust JSON
#     serialization/deserialization.
# ==============================================================================
class PmcProject : ValidationBase {
    [string]$Key
    [string]$Name
    [string]$Description
    [DateTime]$CreatedAt = [DateTime]::Now
    [DateTime]$UpdatedAt = [DateTime]::Now
    [string]$Owner
    [bool]$IsActive = $true
    
    PmcProject([string]$key, [string]$name) {
        [ValidationBase]::ValidateNotEmpty($key, "Key"); [ValidationBase]::ValidateNotEmpty($name, "Name")
        $this.Key = $key; $this.Name = $name
    }

    [void] Archive() { $this.IsActive = $false; $this.UpdatedAt = [DateTime]::Now }
    [void] Activate() { $this.IsActive = $true; $this.UpdatedAt = [DateTime]::Now }
}

# ==============================================================================
# CLASS: TimeEntry
#
# INHERITS:
#   - ValidationBase (AMO.002)
#
# DEPENDENCIES:
#   Enums:
#     - BillingType (AMO.001)
#
# PURPOSE:
#   Represents a discrete block of time logged against a specific task.
#
# KEY LOGIC:
#   - Links to a `TaskId` and `ProjectKey`.
#   - `GetDuration()` calculates the time elapsed between `StartTime` and
#     `EndTime` (or `Now` if the timer is still running).
#   - `Stop()` method finalizes the entry by setting the `EndTime`.
# ==============================================================================
class TimeEntry : ValidationBase {
    [string]$Id = [Guid]::NewGuid().ToString()
    [string]$TaskId
    [string]$ProjectKey
    [DateTime]$StartTime
    [Nullable[DateTime]]$EndTime
    [string]$Description
    [BillingType]$BillingType = [BillingType]::Billable
    
    TimeEntry([string]$taskId, [string]$projectKey, [DateTime]$startTime) {
        [ValidationBase]::ValidateNotEmpty($taskId, "TaskId"); [ValidationBase]::ValidateNotEmpty($projectKey, "ProjectKey")
        $this.TaskId = $taskId; $this.ProjectKey = $projectKey; $this.StartTime = $startTime
    }

    [TimeSpan] GetDuration() {
        if ($this.EndTime) { return $this.EndTime.Value - $this.StartTime }
        return [DateTime]::Now - $this.StartTime
    }

    [void] Stop() { if (-not $this.EndTime) { $this.EndTime = [DateTime]::Now } }
}

#endregion
#<!-- END_PAGE: AMO.003 -->

#<!-- PAGE: AMO.004 - Exception Classes -->
#region Exception Classes

# ==============================================================================
# CLASS: HeliosException
#
# INHERITS:
#   - System.Exception
#
# DEPENDENCIES:
#   - None
#
# PURPOSE:
#   The base exception for all custom exceptions within the Axiom-Phoenix
#   framework. This allows for a single `catch [HeliosException]` block to
#   handle all known framework errors.
#
# KEY LOGIC:
#   - Extends `System.Exception` to add framework-specific diagnostic data,
#     such as the `Component` where the error originated and additional `Context`
#     information, making debugging significantly easier.
# ==============================================================================
class HeliosException : System.Exception {
    [string]$Component
    [hashtable]$Context = @{}
    
    HeliosException([string]$message, [string]$component = "Framework", [hashtable]$context = @{}, [Exception]$innerException = $null) : base($message, $innerException) {
        $this.Component = $component
        $this.Context = $context
    }
}
class NavigationException : HeliosException { }
class ServiceInitializationException : HeliosException { }
class ComponentRenderException : HeliosException { }
class StateMutationException : HeliosException { }
class InputHandlingException : HeliosException { }
class DataLoadException : HeliosException { }

#endregion
#<!-- END_PAGE: AMO.004 -->

#<!-- PAGE: AMO.005 - Navigation Classes -->
#region Navigation Classes

# ==============================================================================
# CLASS: NavigationItem
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   - None
#
# PURPOSE:
#   A data model representing a single clickable or selectable item within a
#   `NavigationMenu` component. It decouples the menu's visual representation
#   from the action that is performed.
#
# KEY LOGIC:
#   - Encapsulates the display text (`Label`), the action to perform (`Action`
#     scriptblock), a unique `Key`, and its state (`Enabled`, `Visible`).
# ==============================================================================
class NavigationItem {
    [string]$Key
    [string]$Label
    [scriptblock]$Action
    [bool]$Enabled = $true
    [bool]$Visible = $true
    [string]$Description = ""

    NavigationItem([string]$key, [string]$label, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($key)) { throw [System.ArgumentException]::new("key") }
        if ([string]::IsNullOrWhiteSpace($label)) { throw [System.ArgumentException]::new("label") }
        if (-not $action) { throw [System.ArgumentNullException]::new("action") }

        $this.Key = $key.ToUpper(); $this.Label = $label; $this.Action = $action
    }

    [void] Execute() { if ($this.Enabled) { & $this.Action } }
}

#endregion
#<!-- END_PAGE: AMO.005 -->