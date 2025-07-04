# logger Module

## Overview
The `logger` module provides a comprehensive and robust logging system for PMC Terminal. It is designed for high performance and detailed diagnostics, featuring multiple log levels, structured data logging, automatic file rotation, and a suite of powerful tracing functions.

## Features
- **Granular Log Levels**: Supports Trace, Debug, Verbose, Info, Warning, Error, and Fatal levels.
- **In-Memory & File Logging**: Buffers logs in memory for fast access and writes to a file for persistence.
- **Automatic Log Rotation**: Log files are automatically rolled over when they exceed a configurable size limit (default 5MB).
- **Rich Structured Data**: Attach any PowerShell object as data to a log entry. Exceptions are automatically serialized with full stack trace and inner exception details.
- **Intelligent Caller Context**: Automatically captures caller information. Prioritizes an explicit `Component` name passed in the `-Data` parameter for better integration with application frameworks.
- **Advanced Call Tracing**: A suite of `Trace-*` functions to log function entry/exit, state changes, component lifecycles, and service calls.
- **Cmdlet Best Practices**: Functions support common parameters. `Clear-LogQueue` supports `-WhatIf` and `-Confirm` for safe operations.
- **Runtime Configuration**: Change the log level or toggle call tracing on-the-fly.
- **Comprehensive Statistics**: Retrieve detailed statistics on logged entries, grouped by level, module, or action.

## Core Functions

### Initialize-Logger
Configures and starts the logging system. This should be called once at application startup.

```powershell
Initialize-Logger -Level "Info" -LogDirectory "C:\Logs\PMCTerminal"
```

### Write-Log
The primary function for writing a log entry.

```powershell
# Simple informational log
Write-Log -Level Info -Message "Application startup complete."

# Log with structured data
$user = @{ Name = "JSmith"; Role = "Admin" }
Write-Log -Level Debug -Message "User login attempt." -Data $user

# Log an error, passing the exception object directly
try {
    1 / 0
} catch {
    # The logger will automatically serialize the exception details
    Write-Log -Level Error -Message "A calculation error occurred." -Data $_.Exception
}
```

## Tracing Functions

These functions provide a standardized way to log detailed diagnostic information.

### Trace-FunctionEntry / Trace-FunctionExit
Track the execution flow of a function. `Enable-CallTracing` must be called first.

```powershell
function Get-UserData {
    param($UserId)
    Trace-FunctionEntry -FunctionName "Get-UserData" -Parameters $PSBoundParameters
    
    # ... function logic ...
    $result = @{ UserId = $UserId; Data = "..." }

    Trace-FunctionExit -FunctionName "Get-UserData" -ReturnValue $result
    return $result
}
```

### Trace-Step
Log a specific checkpoint or step within a longer process.

```powershell
Write-Log -Level Info "Starting data import..."
Trace-Step -StepName "ReadingFile" -StepData @{ File = "import.csv" }
# ... read file ...
Trace-Step -StepName "ParsingData" -StepData @{ Rows = 1000 }
# ... parse data ...
Trace-Step -StepName "SavingToDatabase"
# ... save ...
Write-Log -Level Info "Data import finished."
```

### Other Trace Functions
- **`Trace-StateChange`**: Logs when an important application state value changes.
- **`Trace-ComponentLifecycle`**: Logs UI component events like `Create`, `Render`, and `Destroy`.
- **`Trace-ServiceCall`**: Logs calls to internal application services, including parameters and results.

## Management and Diagnostics

### Set-LogLevel
Change the active log level at runtime to increase or decrease logging verbosity.
```powershell
# Reduce logging to only show warnings and errors
Set-LogLevel -Level "Warning"
```

### Enable-CallTracing / Disable-CallTracing
Globally enable or disable the `Trace-FunctionEntry` and `Trace-FunctionExit` functions.
```powershell
# Start detailed tracing for a specific operation
Enable-CallTracing
Invoke-SomeComplexOperation
Disable-CallTracing
```

### Get-LogEntries
Query the in-memory log queue to inspect recent log entries.
```powershell
# Get the last 20 error entries
Get-LogEntries -Level "Error" -Count 20

# Find all logs related to a specific component or module
Get-LogEntries -Module "DataManager"
```

### Get-LogStatistics
Retrieve a summary of all logs currently in the in-memory queue.
```powershell
$stats = Get-LogStatistics
$stats.EntriesByLevel

# Output:
# Name                           Value
# ----                           -----
# Info                           150
# Debug                          450
# Error                          5
```

### Clear-LogQueue
Clear the in-memory log queue. Supports `-WhatIf` to preview the action.
```powershell
Clear-LogQueue -WhatIf
# What if: Performing the operation "Clear" on target "in-memory log queue".
```