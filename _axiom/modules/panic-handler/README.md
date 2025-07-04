# panic-handler Module

## Overview
The `panic-handler` module provides a robust error recovery and crash reporting system for the PMC Terminal application. It handles unhandled critical errors, captures diagnostic information, restores the terminal to a usable state, and generates comprehensive crash reports.

## Features
- Comprehensive crash reporting with system and application state
- Terminal restoration after critical failures
- Text-based screenshot capture of last rendered frame
- Detailed diagnostic information collection
- Graceful application termination with proper exit codes
- Robust error handling that handles its own failures

## Functions

### Initialize-PanicHandler
Initializes the panic handler by setting up directories for crash reports and screenshots.

```powershell
# Use default directories
Initialize-PanicHandler

# Custom directories
Initialize-PanicHandler -CrashLogDirectory "C:\MyApp\Crashes" -ScreenshotsDirectory "C:\MyApp\Screenshots"
```

**Parameters:**
- `CrashLogDirectory` (Optional) - Directory for crash reports (default: `%LOCALAPPDATA%\PMCTerminal\CrashDumps`)
- `ScreenshotsDirectory` (Optional) - Directory for screenshots (default: `%LOCALAPPDATA%\PMCTerminal\Screenshots`)
- `ApplicationLogDirectory` (Optional) - Main application log directory (default: `%LOCALAPPDATA%\PMCTerminal`)

### Invoke-PanicHandler
Handles unhandled critical errors by generating crash reports and restoring the terminal.

```powershell
# Basic usage (typically in a catch block)
try {
    # Application code
} catch {
    Invoke-PanicHandler -ErrorRecord $_ -AdditionalContext @{
        Screen = "Dashboard"
        Operation = "Loading data"
        UserInput = "Ctrl+R"
    }
}
```

**Parameters:**
- `ErrorRecord` (Required) - The System.Management.Automation.ErrorRecord from the catch block
- `AdditionalContext` (Optional) - Hashtable with additional context information

### Get-DetailedSystemInfo
Collects comprehensive system and application state information for diagnostics.

```powershell
$systemInfo = Get-DetailedSystemInfo
```

**Returns:** PSCustomObject with system information including:
- PowerShell version and host information
- Process details (PID, memory usage, command line)
- TUI state (if available)
- Application uptime
- Log file sizes and entry counts
- Error history statistics

## Crash Report Structure

Each crash report is saved as a JSON file containing:

```json
{
  "Timestamp": "2025-01-01T12:00:00.000Z",
  "Event": "ApplicationPanic",
  "Reason": "Error message",
  "ErrorDetails": {
    "Summary": "Detailed error information",
    "Type": "Exception type",
    "StackTrace": "Full stack trace",
    "InvocationInfo": { "ScriptName": "...", "LineNumber": 42 },
    "AdditionalContext": { "Custom": "context" }
  },
  "SystemInfo": {
    "PowerShellVersion": "7.4.0",
    "OS": "Windows 10",
    "ProcessId": 1234,
    "WorkingSetMB": 150.5,
    "TUIState": { "Running": true, "BufferWidth": 80 }
  },
  "ScreenshotFile": "C:\\path\\to\\screenshot.txt",
  "LastLogEntries": [...],
  "ErrorHistory": [...]
}
```

## Terminal Restoration

The panic handler restores the terminal by:

1. **Resetting Console State:**
   - Clears the screen
   - Resets colors to default
   - Makes cursor visible
   - Disables Ctrl+C passthrough

2. **Displaying User Message:**
   - Shows error notification
   - Displays crash report location
   - Prompts user to press any key

3. **Final Logging:**
   - Attempts to write final message to main application log
   - Ensures process exits with non-zero code (1)

## Screenshot Capture

The module can capture text-based screenshots of the last rendered TUI frame:

- Requires `$global:TuiState.CompositorBuffer` to be available
- Saves as plain text file with character-by-character representation
- Includes timestamp in filename
- Useful for post-mortem analysis of UI state

## Error Handling Strategy

The panic handler implements multiple layers of error handling:

1. **Primary Error Handling:** Catches and processes the original application error
2. **Secondary Error Handling:** Handles failures in crash report generation
3. **Terminal Restoration:** Always attempts to restore terminal, even if other steps fail
4. **Guaranteed Exit:** Ensures process terminates with proper exit code

## Integration with Other Modules

The panic handler integrates with several other modules:

- **exceptions** - Uses `_Get-DetailedError` for comprehensive error analysis
- **logger** - Retrieves log entries and writes final panic messages
- **tui-engine** - Captures terminal screenshots from compositor buffer

## Usage Examples

### Basic Setup
```powershell
# Initialize during application startup
Initialize-PanicHandler

# Set up global error handling
$global:ErrorActionPreference = "Stop"
try {
    # Start application
    Start-TuiLoop
} catch {
    Invoke-PanicHandler -ErrorRecord $_ -AdditionalContext @{
        Phase = "Application Startup"
        Screen = "Initial"
    }
}
```

### Custom Crash Handling
```powershell
# Handle specific error types
try {
    # Critical operation
    Process-CriticalData
} catch [System.UnauthorizedAccessException] {
    Invoke-PanicHandler -ErrorRecord $_ -AdditionalContext @{
        Operation = "File Access"
        File = $filePath
        Permissions = (Get-Acl $filePath).Access
    }
} catch {
    Invoke-PanicHandler -ErrorRecord $_ -AdditionalContext @{
        Operation = "Unknown Critical Error"
        Context = "Data Processing"
    }
}
```

### Diagnostic Information
```powershell
# Get system info for debugging
$systemInfo = Get-DetailedSystemInfo
Write-Host "Memory Usage: $($systemInfo.WorkingSetMB) MB"
Write-Host "App Uptime: $($systemInfo.AppUptime)"
```

## File Locations

Default file locations (can be customized):

- **Crash Reports:** `%LOCALAPPDATA%\PMCTerminal\CrashDumps\crash_report_YYYYMMDD_HHMMSS.json`
- **Screenshots:** `%LOCALAPPDATA%\PMCTerminal\Screenshots\screenshot_YYYYMMDD_HHMMSS.txt`
- **Panic Logs:** `%LOCALAPPDATA%\PMCTerminal\panic_handler_fail_YYYYMMDD_HHMMSS.log`

## Dependencies
- **exceptions** (optional) - For detailed error analysis
- **logger** (optional) - For log retrieval and final messages
- **tui-engine** (optional) - For terminal screenshot capture

## Best Practices

1. **Initialize Early:** Call `Initialize-PanicHandler` during application startup
2. **Provide Context:** Always include relevant context in `AdditionalContext`
3. **Global Coverage:** Wrap main application loop in try/catch with panic handler
4. **Test Paths:** Ensure crash directories are writable and accessible
5. **Monitor Size:** Clean up old crash reports periodically
6. **Review Reports:** Regularly review crash reports for patterns

## Performance Considerations

- Crash reporting is optimized for failure scenarios, not normal operation
- System information collection is comprehensive but only occurs during crashes
- Screenshot capture is text-based and relatively fast
- Directory creation is lazy (only when needed)

## Thread Safety

The panic handler is designed to be thread-safe:
- Uses atomic operations for critical state
- Handles concurrent access to file system
- Ensures single exit point for application termination
