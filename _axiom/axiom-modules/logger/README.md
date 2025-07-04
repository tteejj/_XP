# logger Module

## Overview
The `logger` module provides a comprehensive logging system for PMC Terminal with support for multiple log levels, call tracing, performance metrics, and in-memory log queuing.

## Features
- Multiple log levels (Trace, Debug, Verbose, Info, Warning, Error, Fatal)
- File-based and in-memory logging
- Automatic log rotation
- Call stack tracing
- Performance profiling
- Component lifecycle tracking
- Service call monitoring
- Log statistics and filtering

## Functions

### Core Logging

#### Initialize-Logger
Initialize the logging system with configuration.

```powershell
Initialize-Logger -LogDirectory "C:\Logs" -LogFileName "app.log" -Level "Debug"
```

#### Write-Log
Write a log entry with optional data.

```powershell
Write-Log -Level Info -Message "Application started" -Data @{Version="1.0"}
Write-Log -Level Error -Message "Operation failed" -Data $exception
```

### Tracing Functions

#### Trace-FunctionEntry / Trace-FunctionExit
Track function execution flow.

```powershell
function Do-Something {
    param($Value)
    Trace-FunctionEntry -FunctionName $MyInvocation.MyCommand -Parameters $PSBoundParameters
    try {
        # Function logic
        $result = $Value * 2
        Trace-FunctionExit -FunctionName $MyInvocation.MyCommand -ReturnValue $result
        return $result
    } catch {
        Trace-FunctionExit -FunctionName $MyInvocation.MyCommand -WithError
        throw
    }
}
```

#### Trace-Step
Log individual steps within a function.

```powershell
Trace-Step -StepName "ValidateInput" -StepData @{InputValue=$input}
```

#### Trace-StateChange
Track state modifications.

```powershell
Trace-StateChange -StateType "Configuration" -PropertyPath "Theme.Color" -OldValue "Dark" -NewValue "Light"
```

#### Trace-ComponentLifecycle
Track UI component lifecycle events.

```powershell
Trace-ComponentLifecycle -ComponentType "Button" -ComponentId "btn1" -Phase "Create"
```

#### Trace-ServiceCall
Monitor service method invocations.

```powershell
Trace-ServiceCall -ServiceName "DataManager" -MethodName "SaveTask" -Parameters @{TaskId=123}
```

### Management Functions

#### Get-LogEntries
Retrieve filtered log entries.

```powershell
# Get last 50 error entries
Get-LogEntries -Count 50 -Level "Error"

# Get entries from specific module
Get-LogEntries -Module "tui-engine"
```

#### Get-LogStatistics
Get logging statistics.

```powershell
$stats = Get-LogStatistics
Write-Host "Total entries: $($stats.TotalEntries)"
Write-Host "Errors: $($stats.EntriesByLevel.Error)"
```

#### Set-LogLevel
Change log level at runtime.

```powershell
Set-LogLevel -Level "Warning"
```

#### Enable-CallTracing / Disable-CallTracing
Toggle detailed function call tracing.

```powershell
Enable-CallTracing  # Enables Trace-FunctionEntry/Exit
# ... perform operations ...
Disable-CallTracing
```

## Configuration

### Log Levels
- **Trace**: Detailed execution flow
- **Debug**: Debugging information
- **Verbose**: Detailed operational info
- **Info**: General information
- **Warning**: Warning conditions
- **Error**: Error conditions
- **Fatal**: Critical failures

### Log Rotation
Logs automatically rotate when reaching 5MB. Old logs are renamed with timestamp.

## Dependencies
None - This module is self-contained.

## Performance Considerations
- In-memory queue limited to 2000 entries
- Automatic pruning removes oldest 1000 when limit reached
- File I/O is synchronous - consider async wrapper for high-volume scenarios

## Example Usage
```powershell
Import-Module logger

# Initialize
Initialize-Logger -Level "Debug"

# Basic logging
Write-Log -Level Info -Message "Starting application"

# Error handling
try {
    # Some operation
} catch {
    Write-Log -Level Error -Message "Operation failed" -Data $_
}

# Performance tracking
Enable-CallTracing
# ... operations to profile ...
$stats = Get-LogStatistics
Write-Host "Function calls: $($stats.EntriesByAction.FunctionEntry)"
Disable-CallTracing
```
