# ==============================================================================
# PMC Terminal v5 - Core Data Models
# Defines all core business entity classes with built-in validation and improved diagnostics.
# ==============================================================================

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

#endregion

#region Base Validation Class

# Provides common validation methods used across model classes.
class ValidationBase {
    # Validates that a string value is not null, empty, or whitespace.
    # Throws an ArgumentException if the validation fails.
    static [void] ValidateNotEmpty(
        [string]$value, # FIX: Removed [Parameter(Mandatory)] and [ValidateNotNullOrEmpty()] attributes. They are not valid on method parameters.
        [string]$parameterName
    ) {
        try {
            if ([string]::IsNullOrWhiteSpace($value)) {
                $errorMessage = "Parameter '$($parameterName)' cannot be null or empty."
                # Write-Error is not appropriate here, as this is a library class. Throwing is correct.
                throw [System.ArgumentException]::new($errorMessage, $parameterName)
            }
            # Write-Verbose is for cmdlets, not ideal for class methods. The throw is sufficient.
        }
        catch {
            # Re-throw to ensure calling context handles the exception
            throw
        }
    }
}

#endregion

#region Core Model Classes

# Represents a single task with various attributes and lifecycle methods.
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
    PmcTask([string]$title) { # FIX: Removed [Parameter(Mandatory)] and [ValidateNotNullOrEmpty()] attributes from the constructor parameter.
        [ValidationBase]::ValidateNotEmpty($title, "Title")
        $this.Title = $title
    }
    
    # Constructor: Initializes a new task with common detailed properties.
    PmcTask(
        [string]$title, # FIX: Removed all cmdlet-style attributes from the constructor parameters.
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
        $this.Completed = $true
        $this.Progress = 100
        $this.UpdatedAt = [datetime]::Now
    }

    # UpdateProgress: Updates the task's progress and adjusts status accordingly.
    # Throws an ArgumentOutOfRangeException if newProgress is outside 0-100.
    [void] UpdateProgress([int]$newProgress) { # FIX: Removed [Parameter(Mandatory)] and [ValidateRange(0,100)]. The validation is done manually inside.
        if ($newProgress -lt 0 -or $newProgress -gt 100) {
            throw [System.ArgumentOutOfRangeException]::new("newProgress", $newProgress, "Progress must be between 0 and 100.")
        }

        $this.Progress = $newProgress
        # Update status based on progress: Completed (100), InProgress (>0), Pending (0)
        $this.Status = switch ($newProgress) {
            100 { [TaskStatus]::Completed }
            { $_ -gt 0 } { [TaskStatus]::InProgress }
            default { [TaskStatus]::Pending }
        }
        $this.Completed = ($this.Status -eq [TaskStatus]::Completed)
        $this.UpdatedAt = [datetime]::Now
    }

    # GetDueDateString: Returns the due date as a formatted string, or "N/A" if null.
    [string] GetDueDateString() {
        return $this.DueDate ? $this.DueDate.Value.ToString("yyyy-MM-dd") : "N/A"
    }

    # ToLegacyFormat: Converts the PmcTask object to a hashtable compatible with older data structures.
    [hashtable] ToLegacyFormat() {
        return @{
            id = $this.Id
            title = $this.Title
            description = $this.Description
            completed = $this.Completed
            priority = $this.Priority.ToString().ToLower() # Convert enum to lowercase string
            project = $this.ProjectKey
            due_date = $this.DueDate ? $this.GetDueDateString() : $null
            created_at = $this.CreatedAt.ToString("o") # ISO 8601 format
            updated_at = $this.UpdatedAt.ToString("o")
        }
    }

    # FromLegacyFormat: Static method to create a PmcTask object from a legacy hashtable format.
    static [PmcTask] FromLegacyFormat([hashtable]$legacyData) { # FIX: Removed [Parameter(Mandatory)] and [ValidateNotNull()] attributes.
        $task = [PmcTask]::new() # Start with a default PmcTask instance
        
        # Populate properties, using null-coalescing where appropriate
        $task.Id = $legacyData.id ?? $task.Id
        $task.Title = $legacyData.title ?? "" # Ensure title is not null
        $task.Description = $legacyData.description ?? ""

        # Handle priority conversion with error handling
        if ($legacyData.priority) {
            try {
                $task.Priority = [TaskPriority]::$($legacyData.priority)
            } catch {
                # Silently fallback to default, logging should be handled by a higher-level system if needed
                $task.Priority = [TaskPriority]::Medium
            }
        }
        
        $task.ProjectKey = $legacyData.project ?? $legacyData.Category ?? "General"
        $task.Category = $task.ProjectKey
        
        if ($legacyData.created_at) {
            try { $task.CreatedAt = [datetime]::Parse($legacyData.created_at) }
            catch { $task.CreatedAt = [datetime]::Now }
        }
        
        if ($legacyData.updated_at) {
            try { $task.UpdatedAt = [datetime]::Parse($legacyData.updated_at) }
            catch { $task.UpdatedAt = $task.CreatedAt }
        }
        
        if ($legacyData.due_date -and $legacyData.due_date -ne "N/A") {
            try { $task.DueDate = [datetime]::Parse($legacyData.due_date) }
            catch { $task.DueDate = $null }
        }
        
        if ($legacyData.completed -is [bool] -and $legacyData.completed) {
            $task.Complete()
        } else {
            $task.UpdateProgress($task.Progress)
        }
        return $task
    }

    # ToString: Provides a human-readable string representation of the PmcTask object.
    [string] ToString() {
        return "PmcTask(ID: $($this.Id.Substring(0, 8)), Title: '$($this.Title)', Status: $($this.Status), Priority: $($this.Priority))"
    }
}

# Represents a project with various attributes.
class PmcProject : ValidationBase {
    [string]$Key = ([Guid]::NewGuid().ToString().Split('-')[0]).ToUpper() # Unique short key (e.g., "ABCD123")
    [string]$Name                                                    # Full project name
    [string]$Client                                                  # Client associated with the project
    [BillingType]$BillingType = [BillingType]::NonBillable           # Billing status
    [double]$Rate = 0.0                                             # Billing rate per hour/unit
    [double]$Budget = 0.0                                           # Project budget
    [bool]$Active = $true                                           # Is the project currently active?
    [datetime]$CreatedAt = [datetime]::Now                         # Timestamp of creation
    [datetime]$UpdatedAt = [datetime]::Now                         # Last update timestamp

    # Default constructor: Initializes a new project with default values.
    PmcProject() {}
    
    # Constructor: Initializes a new project with a key and name.
    PmcProject(
        [string]$key, # FIX: Removed [Parameter(Mandatory)] and [ValidateNotNullOrEmpty()] attributes.
        [string]$name
    ) {
        [ValidationBase]::ValidateNotEmpty($key, "Key")
        [ValidationBase]::ValidateNotEmpty($name, "Name")
        $this.Key = $key.ToUpper() # Ensure key is always uppercase
        $this.Name = $name
    }

    # ToLegacyFormat: Converts the PmcProject object to a hashtable compatible with older data structures.
    [hashtable] ToLegacyFormat() {
        return @{
            Key = $this.Key
            Name = $this.Name
            Client = $this.Client
            BillingType = $this.BillingType.ToString() # Convert enum to string
            Rate = $this.Rate
            Budget = $this.Budget
            Active = $this.Active
            CreatedAt = $this.CreatedAt.ToString("o") # ISO 8601 format
            UpdatedAt = $this.UpdatedAt.ToString("o") # Include UpdatedAt for consistency
        }
    }

    # FromLegacyFormat: Static method to create a PmcProject object from a legacy hashtable format.
    static [PmcProject] FromLegacyFormat([hashtable]$legacyData) { # FIX: Removed [Parameter(Mandatory)] and [ValidateNotNull()] attributes.
        $project = [PmcProject]::new() # Start with a default PmcProject instance
        
        $project.Key = ($legacyData.Key ?? $project.Key).ToUpper()
        $project.Name = $legacyData.Name ?? ""
        $project.Client = $legacyData.Client ?? ""
        
        if ($legacyData.Rate) {
            try { $project.Rate = [double]$legacyData.Rate } catch {}
        }
        
        if ($legacyData.Budget) {
            try { $project.Budget = [double]$legacyData.Budget } catch {}
        }
        
        if ($legacyData.Active -is [bool]) {
            $project.Active = $legacyData.Active
        }
        
        if ($legacyData.BillingType) {
            try { $project.BillingType = [BillingType]::$($legacyData.BillingType) }
            catch { $project.BillingType = [BillingType]::NonBillable }
        }
        
        if ($legacyData.CreatedAt) {
            try { $project.CreatedAt = [datetime]::Parse($legacyData.CreatedAt) }
            catch { $project.CreatedAt = [datetime]::Now }
        }
        
        if ($legacyData.UpdatedAt) {
             try { $project.UpdatedAt = [datetime]::Parse($legacyData.UpdatedAt) }
             catch { $project.UpdatedAt = $project.CreatedAt }
        } else {
            $project.UpdatedAt = $project.CreatedAt
        }
        
        return $project
    }

    # ToString: Provides a human-readable string representation of the PmcProject object.
    [string] ToString() {
        return "PmcProject(Key: $($this.Key), Name: '$($this.Name)', Active: $($this.Active))"
    }
}

#endregion

# Export all public classes and enums so they are available when the module is imported.
# This part is handled by the .psd1 manifest, but leaving it here for clarity.
# Export-ModuleMember -Class PmcTask, PmcProject -Enum TaskStatus, TaskPriority, BillingType