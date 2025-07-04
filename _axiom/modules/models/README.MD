# models Module

## Overview
The `models` module defines the core business entities for the PMC Terminal application, primarily the `PmcTask` and `PmcProject` classes. This module provides a robust foundation for data handling, featuring strict, built-in validation, transparent error handling for data parsing, and enhanced diagnostics.

## Features
- **Strict Validation**: Utilizes PowerShell parameter validation attributes (`[ValidateNotNullOrEmpty]`, `[ValidateRange]`, etc.) in constructors and methods to ensure data integrity at the point of creation and modification.
- **Robust Error Handling**: Methods that parse data (e.g., `FromLegacyFormat`) no longer fail silently. They now issue clear `Write-Warning` messages for malformed data, ensuring developers are aware of potential data integrity issues.
- **Legacy Data Compatibility**: Includes `ToLegacyFormat` and `FromLegacyFormat` static methods on each class to ensure seamless serialization and deserialization with older data structures.
- **Enhanced Diagnostics**: All constructors and key methods include `Write-Verbose` output for detailed tracing.
- **Informative Debugging**: Classes override the `ToString()` method to provide a concise, human-readable summary, making debugging and inspection easier.
- **Core Enumerations**: Defines standard enums for `TaskStatus`, `TaskPriority`, and `BillingType`.

## Core Classes

### PmcTask
Represents a single actionable task within the application.

#### Key Properties
- `Id`, `Title`, `Description`
- `Status` ([TaskStatus])
- `Priority` ([TaskPriority])
- `ProjectKey`
- `CreatedAt`, `UpdatedAt`, `DueDate`
- `Progress` (0-100)
- `Completed` (bool)

#### Key Methods & Constructors
```powershell
# Create a new task with validation
$task = [PmcTask]::new("A new validated task title")

# Create a more detailed task
$task = [PmcTask]::new(
    "Design new UI", 
    "Detailed description here", 
    [TaskPriority]::High, 
    "PROJECT-X"
)

# Update a task's progress (value is validated to be 0-100)
$task.UpdateProgress(50)

# Mark a task as complete
$task.Complete()

# Convert to a legacy hashtable for saving
$legacyHashtable = $task.ToLegacyFormat()

# Create a task from a legacy hashtable
$newTask = [PmcTask]::FromLegacyFormat($legacyHashtable)
```

### PmcProject
Represents a project, which acts as a container for tasks.

#### Key Properties
- `Key`, `Name`, `Client`
- `BillingType` ([BillingType])
- `Rate`, `Budget`
- `Active` (bool)
- `CreatedAt`, `UpdatedAt`

#### Key Methods & Constructors
```powershell
# Create a new project with validation
$project = [PmcProject]::new("PROJECT-Y", "Project Ypsilon")

# Convert to a legacy hashtable for saving
$legacyHashtable = $project.ToLegacyFormat()

# Create a project from a legacy hashtable
$newProject = [PmcProject]::FromLegacyFormat($legacyHashtable)
```

## Enumerations
This module exports the following enumerations for use throughout the application:
- `[TaskStatus]`: Pending, InProgress, Completed, Cancelled
- `[TaskPriority]`: Low, Medium, High
- `[BillingType]`: Billable, NonBillable

## Data Integrity and Error Handling

A key enhancement in this module is its focus on data integrity.

### Strict Validation
Constructors and methods fail *early* if you provide invalid data. For example, creating a task with an empty title or updating progress with a value outside 0-100 will immediately throw an exception.

```powershell
# This will fail immediately with a parameter validation error
$task = [PmcTask]::new("") 

# This will also fail immediately
$task.UpdateProgress(150)
```

### Transparent Parsing
The `FromLegacyFormat` static methods are designed to be resilient. If they encounter malformed data (e.g., an invalid date string or an unrecognized priority), they will:
1.  **Log a `Write-Warning`** message to the console, detailing the specific field and value that caused the issue.
2.  **Apply a sensible default value** to the property.
3.  **Continue creating the object**, allowing the application to load the rest of its data without crashing.

This behavior ensures that data corruption in a storage file does not prevent the application from starting, while still alerting the developer to the problem.

```powershell
# Example: $legacyTask has a 'priority' of "Urgent" which is not a valid enum value
$legacyTask = @{
    id = "abc-123"
    title = "My Task"
    priority = "Urgent" # Invalid value
}

# This will succeed, but with a warning in the console
$task = [PmcTask]::FromLegacyFormat($legacyTask)
# WARNING: PmcTask.FromLegacyFormat: Could not parse priority 'Urgent' for task ID 'abc-123'. Using default 'Medium'.

# The resulting object is valid and can be used
# $task.Priority will be [TaskPriority]::Medium
```