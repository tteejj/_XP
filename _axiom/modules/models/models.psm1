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
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$value,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$parameterName
    ) {
        try {
            if ([string]::IsNullOrWhiteSpace($value)) {
                $errorMessage = "Parameter '$($parameterName)' cannot be null or empty."
                Write-Error $errorMessage -ErrorAction Stop # Log as error and stop if called directly as a cmdlet
                throw [System.ArgumentException]::new($errorMessage, $parameterName)
            }
            Write-Verbose "ValidationBase::ValidateNotEmpty: Parameter '$($parameterName)' passed validation."
        }
        catch {
            Write-Error "ValidationBase::ValidateNotEmpty failed for parameter '$($parameterName)': $($_.Exception.Message)"
            throw # Re-throw to ensure calling context handles the exception
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
    PmcTask() {
        Write-Verbose "PmcTask: Default constructor called. ID: $($this.Id)"
    }
    
    # Constructor: Initializes a new task with a title.
    PmcTask([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$title) {
        [ValidationBase]::ValidateNotEmpty($title, "Title")
        $this.Title = $title
        Write-Verbose "PmcTask: Created task with title '$title'. ID: $($this.Id)"
    }
    
    # Constructor: Initializes a new task with common detailed properties.
    PmcTask(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$title,
        [string]$description, # Can be empty
        [Parameter(Mandatory)][ValidateSet("Low", "Medium", "High")][TaskPriority]$priority,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$projectKey
    ) {
        [ValidationBase]::ValidateNotEmpty($title, "Title")
        [ValidationBase]::ValidateNotEmpty($projectKey, "ProjectKey")

        $this.Title = $title
        $this.Description = $description
        $this.Priority = $priority
        $this.ProjectKey = $projectKey
        $this.Category = $projectKey # Category is often an alias for ProjectKey
        Write-Verbose "PmcTask: Created detailed task '$title' for project '$projectKey'. ID: $($this.Id)"
    }

    # Complete: Marks the task as completed, setting progress to 100% and updating timestamp.
    [void] Complete() {
        $this.Status = [TaskStatus]::Completed
        $this.Completed = $true
        $this.Progress = 100
        $this.UpdatedAt = [datetime]::Now
        Write-Verbose "PmcTask '$($this.Id)': Marked as Completed."
    }

    # UpdateProgress: Updates the task's progress and adjusts status accordingly.
    # Throws an ArgumentOutOfRangeException if newProgress is outside 0-100.
    [void] UpdateProgress([Parameter(Mandatory)][ValidateRange(0, 100)][int]$newProgress) {
        try {
            $this.Progress = $newProgress
            # Update status based on progress: Completed (100), InProgress (>0), Pending (0)
            $this.Status = switch ($newProgress) {
                100 { [TaskStatus]::Completed }
                { $_ -gt 0 } { [TaskStatus]::InProgress }
                default { [TaskStatus]::Pending }
            }
            $this.Completed = ($this.Status -eq [TaskStatus]::Completed)
            $this.UpdatedAt = [datetime]::Now
            Write-Verbose "PmcTask '$($this.Id)': Progress updated to $($newProgress)% (Status: $($this.Status))."
        }
        catch {
            # Throwing a proper exception type for out-of-range arguments
            throw [System.ArgumentOutOfRangeException]::new("newProgress", $newProgress, "Progress must be between 0 and 100.")
        }
    }

    # GetDueDateString: Returns the due date as a formatted string, or "N/A" if null.
    [string] GetDueDateString() {
        $dueDateString = $this.DueDate ? $this.DueDate.Value.ToString("yyyy-MM-dd") : "N/A"
        Write-Verbose "PmcTask '$($this.Id)': DueDate string is '$dueDateString'."
        return $dueDateString
    }

    # ToLegacyFormat: Converts the PmcTask object to a hashtable compatible with older data structures.
    [hashtable] ToLegacyFormat() {
        $legacyData = @{
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
        Write-Verbose "PmcTask '$($this.Id)': Converted to legacy format."
        return $legacyData
    }

    # FromLegacyFormat: Static method to create a PmcTask object from a legacy hashtable format.
    static [PmcTask] FromLegacyFormat([Parameter(Mandatory)][ValidateNotNull()][hashtable]$legacyData) {
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
                Write-Warning "PmcTask.FromLegacyFormat: Could not parse priority '$($legacyData.priority)' for task ID '$($task.Id)'. Using default 'Medium'. Error: $($_.Exception.Message)"
                $task.Priority = [TaskPriority]::Medium # Fallback to default
            }
        }
        
        $task.ProjectKey = $legacyData.project ?? $legacyData.Category ?? "General"
        $task.Category = $task.ProjectKey
        
        # Handle datetime conversions with error handling
        if ($legacyData.created_at) {
            try {
                $task.CreatedAt = [datetime]::Parse($legacyData.created_at)
            } catch {
                Write-Warning "PmcTask.FromLegacyFormat: Could not parse CreatedAt '$($legacyData.created_at)' for task ID '$($task.Id)'. Using current time. Error: $($_.Exception.Message)"
                $task.CreatedAt = [datetime]::Now # Fallback to current time
            }
        }
        
        if ($legacyData.updated_at) {
            try {
                $task.UpdatedAt = [datetime]::Parse($legacyData.updated_at)
            } catch {
                Write-Warning "PmcTask.FromLegacyFormat: Could not parse UpdatedAt '$($legacyData.updated_at)' for task ID '$($task.Id)'. Using CreatedAt. Error: $($_.Exception.Message)"
                $task.UpdatedAt = $task.CreatedAt # Fallback to CreatedAt
            }
        }
        
        if ($legacyData.due_date -and $legacyData.due_date -ne "N/A") {
            try {
                $task.DueDate = [datetime]::Parse($legacyData.due_date)
            } catch {
                Write-Warning "PmcTask.FromLegacyFormat: Could not parse DueDate '$($legacyData.due_date)' for task ID '$($task.Id)'. Setting to null. Error: $($_.Exception.Message)"
                $task.DueDate = $null # Fallback to null
            }
        }
        
        # Apply completed status if present and true
        if ($legacyData.completed -is [bool] -and $legacyData.completed) {
            $task.Complete()
        } else {
            # Ensure status is correctly set based on progress if 'completed' flag is false or absent
            $task.UpdateProgress($task.Progress)
        }
        
        Write-Verbose "PmcTask.FromLegacyFormat: Converted legacy data for task ID '$($task.Id)'."
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
    PmcProject() {
        Write-Verbose "PmcProject: Default constructor called. Key: $($this.Key)"
    }
    
    # Constructor: Initializes a new project with a key and name.
    PmcProject(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$key,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$name
    ) {
        [ValidationBase]::ValidateNotEmpty($key, "Key")
        [ValidationBase]::ValidateNotEmpty($name, "Name")
        $this.Key = $key.ToUpper() # Ensure key is always uppercase
        $this.Name = $name
        Write-Verbose "PmcProject: Created project '$name' with key '$key'."
    }

    # ToLegacyFormat: Converts the PmcProject object to a hashtable compatible with older data structures.
    [hashtable] ToLegacyFormat() {
        $legacyData = @{
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
        Write-Verbose "PmcProject '$($this.Key)': Converted to legacy format."
        return $legacyData
    }

    # FromLegacyFormat: Static method to create a PmcProject object from a legacy hashtable format.
    static [PmcProject] FromLegacyFormat([Parameter(Mandatory)][ValidateNotNull()][hashtable]$legacyData) {
        $project = [PmcProject]::new() # Start with a default PmcProject instance
        
        # Populate properties, using null-coalescing where appropriate
        $project.Key = ($legacyData.Key ?? $project.Key).ToUpper() # Key from legacy, or default
        $project.Name = $legacyData.Name ?? ""
        $project.Client = $legacyData.Client ?? ""
        
        if ($legacyData.Rate) {
            try { $project.Rate = [double]$legacyData.Rate }
            catch { Write-Warning "PmcProject.FromLegacyFormat: Could not parse Rate '$($legacyData.Rate)' for project '$($project.Key)'. Using 0.0. Error: $($_.Exception.Message)" }
        }
        
        if ($legacyData.Budget) {
            try { $project.Budget = [double]$legacyData.Budget }
            catch { Write-Warning "PmcProject.FromLegacyFormat: Could not parse Budget '$($legacyData.Budget)' for project '$($project.Key)'. Using 0.0. Error: $($_.Exception.Message)" }
        }
        
        if ($legacyData.Active -is [bool]) {
            $project.Active = $legacyData.Active
        }
        
        # Handle BillingType conversion with error handling
        if ($legacyData.BillingType) {
            try {
                $project.BillingType = [BillingType]::$($legacyData.BillingType)
            } catch {
                Write-Warning "PmcProject.FromLegacyFormat: Could not parse BillingType '$($legacyData.BillingType)' for project '$($project.Key)'. Using default 'NonBillable'. Error: $($_.Exception.Message)"
                $project.BillingType = [BillingType]::NonBillable # Fallback to default
            }
        }
        
        # Handle CreatedAt conversion with error handling
        if ($legacyData.CreatedAt) {
            try {
                $project.CreatedAt = [datetime]::Parse($legacyData.CreatedAt)
            } catch {
                Write-Warning "PmcProject.FromLegacyFormat: Could not parse CreatedAt '$($legacyData.CreatedAt)' for project '$($project.Key)'. Using current time. Error: $($_.Exception.Message)"
                $project.CreatedAt = [datetime]::Now # Fallback to current time
            }
        }
        
        if ($legacyData.UpdatedAt) {
             try {
                $project.UpdatedAt = [datetime]::Parse($legacyData.UpdatedAt)
            } catch {
                Write-Warning "PmcProject.FromLegacyFormat: Could not parse UpdatedAt '$($legacyData.UpdatedAt)' for project '$($project.Key)'. Using CreatedAt. Error: $($_.Exception.Message)"
                $project.UpdatedAt = $project.CreatedAt # Fallback to CreatedAt for consistency
            }
        } else {
            $project.UpdatedAt = $project.CreatedAt # Defaulting to CreatedAt for consistency
        }
        
        Write-Verbose "PmcProject.FromLegacyFormat: Converted legacy data for project key '$($project.Key)'."
        return $project
    }

    # ToString: Provides a human-readable string representation of the PmcProject object.
    [string] ToString() {
        return "PmcProject(Key: $($this.Key), Name: '$($this.Name)', Active: $($this.Active))"
    }
}

#endregion

# Export all public classes and enums so they are available when the module is imported.
Export-ModuleMember -Class PmcTask, PmcProject -Enum TaskStatus, TaskPriority, BillingType