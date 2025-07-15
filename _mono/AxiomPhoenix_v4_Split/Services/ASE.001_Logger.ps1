# ==============================================================================
# Axiom-Phoenix v4.0 - All Services (Load After Components)
# Core application services: action, navigation, data, theming, logging, events
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASE.###" to find specific sections.
# Each section ends with "END_PAGE: ASE.###"
# ==============================================================================

#region Logger Class

# ===== CLASS: Logger =====
# Module: logger (from axiom)
# Dependencies: None
# Purpose: Application-wide logging with multiple outputs
class Logger {
    [string]$LogPath
    [System.Collections.Queue]$LogQueue
    [int]$MaxQueueSize = 1000
    [bool]$EnableFileLogging = $true
    [bool]$EnableConsoleLogging = $false
    [string]$MinimumLevel = "Info"
    [hashtable]$LevelPriority = @{
        'Trace' = 0
        'Debug' = 1
        'Info' = 2
        'Warning' = 3
        'Error' = 4
        'Fatal' = 5
    }
    
    Logger() {
        # Cross-platform log path
        $isWindowsOS = [System.Environment]::OSVersion.Platform -eq 'Win32NT'
        if ($isWindowsOS) {
            $this.LogPath = Join-Path $env:APPDATA "AxiomPhoenix\app.log"
        } else {
            $userHome = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
            if ([string]::IsNullOrEmpty($userHome)) {
                $userHome = $env:HOME
            }
            $logDir = Join-Path $userHome ".local/share/AxiomPhoenix"
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            $this.LogPath = Join-Path $logDir "app.log"
        }
        $this._Initialize()
    }
    
    Logger([string]$logPath) {
        $this.LogPath = $logPath
        $this._Initialize()
    }
    
    hidden [void] _Initialize() {
        $this.LogQueue = [System.Collections.Queue]::new()
        
        # Check for environment variable to set log level
        if ($env:AXIOM_LOG_LEVEL) {
            if ($this.LevelPriority.ContainsKey($env:AXIOM_LOG_LEVEL)) {
                $this.MinimumLevel = $env:AXIOM_LOG_LEVEL
            }
        }
        
        # Don't enable console logging for TUI apps - it interferes with display
        # Use file logging instead
        
        $logDir = Split-Path -Parent $this.LogPath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Write-Verbose "Logger: Initialized with log path: $($this.LogPath), MinimumLevel: $($this.MinimumLevel)"
    }
    
    [void] Log([string]$message, [string]$level = "Info") {
        # Check if we should log this level
        if ($this.LevelPriority[$level] -lt $this.LevelPriority[$this.MinimumLevel]) {
            return
        }
        
        $logEntry = @{
            Timestamp = [DateTime]::Now
            Level = $level
            Message = $message
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }
        
        # Add to queue
        $this.LogQueue.Enqueue($logEntry)
        
        # FIXED: Always write to file immediately for TUI apps
        if ($this.EnableFileLogging) {
            $this.Flush()
        }
        
        # Console logging if enabled
        if ($this.EnableConsoleLogging) {
            $this._WriteToConsole($logEntry)
        }
    }
    
    [void] LogException([Exception]$exception, [string]$message = "") {
        $logMessage = "Exception occurred"
        if ($message) { $logMessage = $message }
        
        $exceptionDetails = @{
            Message = $logMessage
            ExceptionType = $exception.GetType().FullName
            ExceptionMessage = $exception.Message
            StackTrace = $exception.StackTrace
            InnerException = if ($exception.InnerException) { 
                $exception.InnerException.Message 
            } else { 
                $null 
            }
        }
        
        $detailsJson = $exceptionDetails | ConvertTo-Json -Compress -Depth 10 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if (-not $detailsJson) {
            # If serialization fails, create a simple string representation
            $detailsJson = "ExceptionType: $($exceptionDetails.ExceptionType), Message: $($exceptionDetails.ExceptionMessage)"
        }
        $this.Log($detailsJson, "Error")
    }
    
    [void] Flush() {
        if ($this.LogQueue.Count -eq 0 -or -not $this.EnableFileLogging) {
            return
        }
        
        try {
            $logContent = [System.Text.StringBuilder]::new()
            
            while ($this.LogQueue.Count -gt 0) {
                $entry = $this.LogQueue.Dequeue()
                $logLine = "$($entry.Timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff')) [$($entry.Level.ToUpper().PadRight(7))] [Thread:$($entry.ThreadId)] $($entry.Message)"
                [void]$logContent.AppendLine($logLine)
            }
            
            if ($logContent.Length -gt 0) {
                Add-Content -Path $this.LogPath -Value $logContent.ToString() -NoNewline
            }
        }
        catch {
            Write-Warning "Logger: Failed to flush logs: $_"
        }
    }
    
    hidden [void] _WriteToConsole([hashtable]$logEntry) {
        $color = switch ($logEntry.Level) {
            'Trace' { [ConsoleColor]::DarkGray }
            'Debug' { [ConsoleColor]::Gray }
            'Info' { [ConsoleColor]::White }
            'Warning' { [ConsoleColor]::Yellow }
            'Error' { [ConsoleColor]::Red }
            'Fatal' { [ConsoleColor]::Magenta }
            default { [ConsoleColor]::White }
        }
        
        $timestamp = $logEntry.Timestamp.ToString('HH:mm:ss')
        $prefix = "[$timestamp] [$($logEntry.Level.ToUpper())]"
        
        # Write-Host $prefix -ForegroundColor $color -NoNewline
        # Write-Host " $($logEntry.Message)" -ForegroundColor White
    }
    
    [void] Cleanup() {
        $this.Flush()
        # Write-Verbose "Logger: Cleanup complete"
    }
}

#endregion
#<!-- END_PAGE: ASE.006 -->
