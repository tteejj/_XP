# Axiom Phoenix File Logging System

## Overview
All console output (Write-Host, Write-Warning, Write-Error, Write-Verbose, Write-Debug) has been redirected to a log file to prevent interference with the TUI display.

## Log File Location
The debug log is written to: `axiom-phoenix-debug.log` in the project root folder.

## Monitoring the Log

### Real-time Monitoring
Open a separate PowerShell window and run:
```powershell
.\Monitor-AxiomLog.ps1 -Follow
```

### View Recent Entries
```powershell
.\Monitor-AxiomLog.ps1 -Lines 100
```

### From Within PowerShell
```powershell
# View last 50 entries
Get-AxiomPhoenixLog

# View last 100 entries
Get-AxiomPhoenixLog -Last 100

# Clear the log
Clear-AxiomPhoenixLog

# Get log file path
Get-AxiomPhoenixLogPath
```

## Log Levels
- **INFO** - General information
- **WARNING** - Warning messages
- **ERROR** - Error messages with stack traces
- **DEBUG** - Debug information
- **VERBOSE** - Verbose output
- **HOST** - Former Write-Host output

## Log Format
```
[YYYY-MM-DD HH:MM:SS.fff] [LEVEL] [Caller] [Component] Message
```

Example:
```
[2024-01-15 10:23:45.123] [INFO] [Initialize] [Screen] Initializing HomeScreen
[2024-01-15 10:23:45.234] [ERROR] [HandleInput] Component not found: textBox1
    Exception: Object reference not set to an instance of an object
    Category: InvalidOperation
    Target: textBox1
    Stack: at HandleInput, line 45
```

## Adding More Debug Info

### In Your Code
```powershell
# Old way (still works, redirected to log)
Write-Host "Processing item: $itemName"
Write-Verbose "Item details: $($item | ConvertTo-Json)"
Write-Warning "Item count low: $count"
Write-Error "Failed to process: $_"

# New way (more control)
Write-Log -Message "Processing item: $itemName" -Level Info -Component "ItemProcessor"
Write-Log -Message "Detailed state: $($state | ConvertTo-Json -Depth 2)" -Level Debug
```

### Enhanced Debugging
For more detailed debugging, set verbose preference before running:
```powershell
$VerbosePreference = 'Continue'
.\Start.ps1
```

## Tips
1. Keep the log monitor running in a separate window while developing
2. Use color coding in the monitor to quickly spot errors (red) and warnings (yellow)
3. Clear the log before each test run for cleaner output
4. The log includes caller information to help track where messages originate
5. Error entries include full stack traces for easier debugging

## Emergency Logging
If the main log file fails, emergency logs are written to: `$env:TEMP\axiom-phoenix-emergency.log`
