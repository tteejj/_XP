# exceptions Module

## Overview
The `exceptions` module provides the foundation for error handling throughout the PMC Terminal application. It defines custom exception types and provides a centralized error handling wrapper that integrates with the logging system.

## Features
- Custom exception hierarchy with structured error context
- Centralized error handling with component identification
- Comprehensive error logging integration
- In-memory error history tracking
- Detailed error analysis and system context capture
- Robust error propagation with custom exception types

## Custom Exception Types

### Helios.HeliosException (Base)
The base exception class for all PMC Terminal custom exceptions.

**Properties:**
- `DetailedContext` - Hashtable containing error-specific context
- `Component` - String identifying the component where error occurred
- `Timestamp` - DateTime when the exception was created

### Specialized Exception Types
- `NavigationException` - Navigation-related errors
- `ServiceInitializationException` - Service startup/initialization errors
- `ComponentRenderException` - UI rendering errors
- `StateMutationException` - State management errors
- `InputHandlingException` - Input processing errors
- `DataLoadException` - Data loading/persistence errors

## Functions

### Invoke-WithErrorHandling
Executes a script block within a robust error handling wrapper.

```powershell
# Basic usage
Invoke-WithErrorHandling -Component "TaskService" -Context "Loading tasks" -ScriptBlock {
    # Code that might throw errors
    Get-Tasks
}

# With additional context
Invoke-WithErrorHandling -Component "UIComponent" -Context "Rendering panel" -AdditionalData @{
    PanelName = "Dashboard"
    Width = 80
    Height = 25
} -ScriptBlock {
    Render-DashboardPanel
}
```

**Parameters:**
- `Component` (Required) - Component name for error identification
- `Context` (Required) - Operation description for error context
- `ScriptBlock` (Required) - Code to execute within error handling
- `AdditionalData` (Optional) - Additional context data for error logging

### Get-ErrorHistory
Retrieves recent entries from the in-memory error history.

```powershell
# Get last 25 errors (default)
$errors = Get-ErrorHistory

# Get last 50 errors
$errors = Get-ErrorHistory -Count 50

# Each error contains:
# - Timestamp
# - Summary
# - Type
# - Category
# - InvocationInfo
# - StackTrace
# - InnerExceptions
# - AdditionalContext
# - SystemContext
```

## Error Processing Pipeline

1. **Error Capture** - `Invoke-WithErrorHandling` catches all exceptions
2. **Component Identification** - Analyzes call stack to identify source component
3. **Detail Extraction** - Gathers comprehensive error information
4. **Logging** - Writes structured error data to application log
5. **History Storage** - Adds error to in-memory history (max 100 entries)
6. **Re-throwing** - Creates and throws custom `HeliosException`

## Component Identification

The module automatically identifies error sources by analyzing:
- `ErrorRecord.InvocationInfo.ScriptName`
- PowerShell call stack
- File name patterns

**Component Mapping:**
- `tui-engine` → "TUI Engine"
- `navigation` → "Navigation Service"
- `keybindings` → "Keybinding Service"
- `task-service` → "Task Service"
- `dashboard-screen` → "Dashboard Screen"
- `data-manager` → "Data Manager"
- `theme-manager` → "Theme Manager"
- And many more...

## Error Context Structure

Each error includes comprehensive context:

```powershell
@{
    Timestamp = "2025-01-01T12:00:00.000Z"
    Summary = "Error message"
    Type = "System.Exception"
    Category = "NotSpecified"
    TargetObject = $null
    InvocationInfo = @{
        ScriptName = "C:\path\to\script.ps1"
        LineNumber = 42
        Line = "Get-Data"
        PositionMessage = "At line:42..."
        BoundParameters = @{}
    }
    StackTrace = "Full stack trace..."
    InnerExceptions = @()
    AdditionalContext = @{
        Operation = "Loading data"
        # ... additional context
    }
    SystemContext = @{
        ProcessId = 1234
        ThreadId = 5
        PowerShellVersion = "7.4.0"
        OS = "Windows 10"
        HostName = "ConsoleHost"
        HostVersion = "5.1.0"
    }
}
```

## Dependencies
- **logger** (optional) - For structured error logging
- **PowerShell 7.0+** - For advanced language features

## Usage Example

```powershell
Import-Module exceptions

# Basic error handling
try {
    $result = Invoke-WithErrorHandling -Component "MyService" -Context "Processing data" -ScriptBlock {
        # Code that might fail
        Process-Data
    }
} catch [Helios.HeliosException] {
    Write-Host "Service error in $($_.Component): $($_.Message)"
    # Error is already logged and tracked
}

# Check error history
$recentErrors = Get-ErrorHistory -Count 10
$recentErrors | Format-Table Timestamp, Summary, Type
```

## Best Practices

1. **Always use Invoke-WithErrorHandling** for any operation that might fail
2. **Provide meaningful component names** that clearly identify the source
3. **Include relevant context** in the Context parameter
4. **Add structured data** via AdditionalData for complex operations
5. **Handle HeliosException** specifically in catch blocks when needed
6. **Use Get-ErrorHistory** for debugging and diagnostics

## Error Handling Strategy

The module implements a comprehensive error handling strategy:

- **Fail Fast** - Invalid parameters are caught at binding time
- **Rich Context** - Comprehensive error information is captured
- **Structured Logging** - All errors are logged with detailed context
- **History Tracking** - Recent errors are kept in memory for analysis
- **Clean Propagation** - Errors are re-thrown as structured exceptions

## Thread Safety

The module is designed for thread safety:
- Error history uses thread-safe collections
- History retrieval creates snapshots to prevent modification issues
- Component identification is stateless

## Performance Considerations

- Error history is limited to 100 entries (configurable)
- Component identification uses efficient string matching
- Error context is captured only when errors occur
- Structured logging minimizes performance impact during normal operation
