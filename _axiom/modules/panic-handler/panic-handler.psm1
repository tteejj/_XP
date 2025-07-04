# MODULE: panic-handler/panic-handler.psm1
# PURPOSE: Provides a robust error recovery and crash reporting system for the PMC Terminal application.
# This module is designed to catch unhandled exceptions, restore the terminal, and generate detailed diagnostics.

# ------------------------------------------------------------------------------
# Module-Scoped State Variables
# ------------------------------------------------------------------------------
$script:CrashLogDirectory = $null # Directory where crash reports are saved
$script:ScreenshotsDirectory = $null # Directory for last-frame screenshots
$script:LogDirectoryForPanic = $null # The main application log directory, used for panic messages

# ------------------------------------------------------------------------------
# Private Helper Functions
# ------------------------------------------------------------------------------

# Gathers detailed system and application state information for crash reports.
function Get-DetailedSystemInfo {
    [CmdletBinding()]
    param()

    try {
        $process = Get-Process -Id $PID -ErrorAction SilentlyContinue # Get current process info
        
        # Collect system and PowerShell environment details
        $systemInfo = [PSCustomObject]@{
            Timestamp = (Get-Date -Format "o");
            PowerShellVersion = $PSVersionTable.PSVersion.ToString();
            OS = $PSVersionTable.OS;
            HostName = $Host.Name;
            HostVersion = $Host.Version.ToString();
            ProcessId = $PID;
            ProcessName = $process?.ProcessName;
            WorkingSetMB = if ($process) { [Math]::Round($process.WorkingSet64 / 1MB, 2) } else { $null };
            CommandLine = ([Environment]::CommandLine);
            CurrentDirectory = (Get-Location).Path;
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId;
            Culture = [System.Threading.Thread]::CurrentThread.CurrentCulture.Name;
        }

        # Add application-specific state if available (assuming global access)
        if ($global:TuiState) {
            $systemInfo | Add-Member -MemberType NoteProperty -Name "TUIState" -Value @{
                Running = $global:TuiState.Running;
                BufferWidth = $global:TuiState.BufferWidth;
                BufferHeight = $global:TuiState.BufferHeight;
                CurrentScreen = $global:TuiState.CurrentScreen?.Name;
                OverlayCount = $global:TuiState.OverlayStack.Count;
                IsDirty = $global:TuiState.IsDirty;
                FocusedComponent = $global:TuiState.FocusedComponent?.Name;
                FrameCount = $global:TuiState.RenderStats.FrameCount;
            } -Force
        }
        if (Get-Variable -Name 'appStartTime' -ErrorAction SilentlyContinue) {
            $appUptime = (Get-Date) - $global:appStartTime
            $systemInfo | Add-Member -MemberType NoteProperty -Name "AppUptime" -Value $appUptime.ToString('hh\:mm\:ss\.fff') -Force
        }
        if (Get-Command 'Get-LogPath' -ErrorAction SilentlyContinue) {
            $logPath = Get-LogPath
            if ($logPath -and (Test-Path $logPath)) {
                $systemInfo | Add-Member -MemberType NoteProperty -Name "LogFileSizeMB" -Value ([Math]::Round((Get-Item $logPath).Length / 1MB, 2)) -Force
            }
        }
        if (Get-Command 'Get-LogEntries' -ErrorAction SilentlyContinue) {
             $systemInfo | Add-Member -MemberType NoteProperty -Name "LogHistoryCount" -Value (Get-LogEntries -Count 1000).Count -Force
        }
        if (Get-Command 'Get-ErrorHistory' -ErrorAction SilentlyContinue) {
             $systemInfo | Add-Member -MemberType NoteProperty -Name "ErrorHistoryCount" -Value (Get-ErrorHistory -Count 1000).Count -Force
        }

        Write-Verbose "PanicHandler: Detailed system info collected."
        return $systemInfo
    } catch {
        Write-Warning "PanicHandler: Failed to collect all system information: $($_.Exception.Message)"
        return [PSCustomObject]@{ Timestamp = (Get-Date -Format "o"); Error = "Failed to collect system info: $($_.Exception.Message)" }
    }
}

# Captures the last rendered frame from the TUI Engine's compositor buffer as a screenshot (text-based).
function Get-TerminalScreenshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$outputPath # Directory to save the screenshot
    )

    try {
        if (-not $global:TuiState -or -not $global:TuiState.CompositorBuffer) {
            Write-Warning "PanicHandler: TUI state or compositor buffer not available for screenshot."
            return $null
        }

        # Ensure screenshot directory exists
        if (-not (Test-Path $outputPath)) {
            New-Item -ItemType Directory -Path $outputPath -Force -ErrorAction Stop | Out-Null
            Write-Verbose "PanicHandler: Created screenshot directory: $outputPath"
        }

        $buffer = $global:TuiState.CompositorBuffer
        $screenshotFileName = "screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $screenshotPath = Join-Path $outputPath $screenshotFileName
        
        $sb = [System.Text.StringBuilder]::new($buffer.Width * $buffer.Height * 2) # Estimate size
        
        # Build the screenshot string directly from the buffer's cells.
        # This is a simplified text-based screenshot, not an actual graphical image.
        for ($y = 0; $y -lt $buffer.Height; $y++) {
            for ($x = 0; $x -lt $buffer.Width; $x++) {
                [void]$sb.Append($buffer.GetCell($x, $y).Char)
            }
            [void]$sb.Append("`n") # New line after each row
        }
        
        # Write the text screenshot to file.
        $sb.ToString() | Out-File -FilePath $screenshotPath -Encoding UTF8 -Force
        Write-Verbose "PanicHandler: Terminal screenshot saved to: $screenshotPath"
        return $screenshotPath
    } catch {
        Write-Warning "PanicHandler: Failed to capture terminal screenshot: $($_.Exception.Message)"
        return $null
    }
}

# Restores the terminal to a usable state after a crash.
function Restore-Terminal {
    [CmdletBinding()]
    param()

    try {
        # Reset console colors and state
        [Console]::ResetColor()
        [Console]::Clear()
        [Console]::CursorVisible = $true
        [Console]::TreatControlCAsInput = $false # Ensure Ctrl+C doesn't just pass through

        # Output to console directly, bypassing any potentially broken logger.
        Write-Host ""
        Write-Host "===============================================" -ForegroundColor Red
        Write-Host "    A CRITICAL APPLICATION ERROR OCCURRED!   " -ForegroundColor Red
        Write-Host "===============================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "The application has encountered an unrecoverable error and must close." -ForegroundColor White
        Write-Host "A diagnostic crash report has been generated." -ForegroundColor White
        Write-Host ""
        Write-Host "  Crash Report Path: $($script:CrashLogDirectory)" -ForegroundColor Yellow
        Write-Host ""

        # Attempt to log to the application's main log file one last time if possible
        if ($script:LogDirectoryForPanic) {
            try {
                $lastLogPath = Join-Path $script:LogDirectoryForPanic "pmc_terminal_$(Get-Date -Format 'yyyy-MM-dd').log"
                if (Test-Path $lastLogPath) {
                    Add-Content -Path $lastLogPath -Value "`n[CRITICAL PANIC] Application terminated due to unhandled error. See crash dump in $($script:CrashLogDirectory)" -Encoding UTF8 -Force
                    Write-Host "  Last application log: $lastLogPath" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  (Failed to write last message to main application log: $($_.Exception.Message))" -ForegroundColor DarkRed
            }
        }
        
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        
        # Wait for user input to keep the console window open.
        if ($Host.UI.RawUI) {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
        Write-Verbose "PanicHandler: Terminal restoration complete."
    } catch {
        # Last ditch effort if terminal restoration itself fails.
        Write-Host "CRITICAL: PanicHandler failed to restore terminal: $($_.Exception.Message)" -ForegroundColor Red
        # Attempt a raw reset if supported
        try { [Console]::Write("`e[0m`e[H`e[J") } catch {} # ANSI reset, home, clear screen
        Start-Sleep -Milliseconds 500
    }
}

# ------------------------------------------------------------------------------
# Public Functions
# ------------------------------------------------------------------------------

function Initialize-PanicHandler {
    <#
    .SYNOPSIS
    Initializes the Panic Handler, setting up directories for crash reports.
    .DESCRIPTION
    This function sets the paths for storing crash logs and screenshots, and ensures
    these directories exist. It should be called early in the application startup.
    .PARAMETER CrashLogDirectory
    The base directory where individual crash reports (JSON files) will be saved.
    Defaults to 'PMCTerminal\CrashDumps' in the user's Local Application Data folder.
    .PARAMETER ScreenshotsDirectory
    The directory where last-frame text screenshots will be saved.
    Defaults to 'PMCTerminal\Screenshots' in the user's Local Application Data folder.
    .PARAMETER ApplicationLogDirectory
    The main application log directory, used for writing a final message to the main log file.
    Defaults to 'PMCTerminal' in the user's Local Application Data folder.
    #>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$CrashLogDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\CrashDumps"),
        
        [ValidateNotNullOrEmpty()]
        [string]$ScreenshotsDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\Screenshots"),
        
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationLogDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal")
    )
    
    try {
        $script:CrashLogDirectory = $CrashLogDirectory
        $script:ScreenshotsDirectory = $ScreenshotsDirectory
        $script:LogDirectoryForPanic = $ApplicationLogDirectory

        # Ensure directories exist
        if (-not (Test-Path $script:CrashLogDirectory)) {
            New-Item -ItemType Directory -Path $script:CrashLogDirectory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path $script:ScreenshotsDirectory)) {
            New-Item -ItemType Directory -Path $script:ScreenshotsDirectory -Force -ErrorAction Stop | Out-Null
        }
        
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "Panic Handler initialized." -Data @{
                CrashLogDir = $script:CrashLogDirectory;
                ScreenshotsDir = $script:ScreenshotsDirectory;
                AppLogDir = $script:LogDirectoryForPanic;
            }
        }
        Write-Verbose "PanicHandler: Initialization complete."
    } catch {
        Write-Warning "PanicHandler: Failed to initialize: $($_.Exception.Message). Crash dumping might not work."
    }
}

function Invoke-PanicHandler {
    <#
    .SYNOPSIS
    Handles an unhandled critical error, generating a crash report and restoring the terminal.
    .DESCRIPTION
    This is the primary entry point for global exception handling. It should be called
    when an unhandled error occurs in the main application loop. It collects diagnostic
    information, saves it to a crash log, restores the terminal, and then exits the application.
    .PARAMETER ErrorRecord
    The System.Management.Automation.ErrorRecord object representing the unhandled error.
    This is typically the automatic variable $_ from a catch block.
    .PARAMETER AdditionalContext
    Optional. A hashtable containing any extra context relevant to the crash (e.g., current screen, user input).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [hashtable]$AdditionalContext = @{}
    )
    
    # Log the panic immediately
    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
        Write-Log -Level Fatal -Message "Panic handler invoked due to unhandled error." -Data @{ 
            ErrorMessage = $ErrorRecord.Exception.Message; 
            Type = $ErrorRecord.Exception.GetType().FullName; 
            Stage = "PanicHandlerEntry" 
        } -Force
    }

    try {
        $crashTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $crashReportFileName = "crash_report_${crashTimestamp}.json"
        $crashReportPath = Join-Path $script:CrashLogDirectory $crashReportFileName

        Write-Verbose "PanicHandler: Starting crash dump generation."

        # Collect detailed error info using the helper from the Exceptions module.
        # This assumes _Get-DetailedError is available in the session scope.
        $detailedError = $null
        if (Get-Command '_Get-DetailedError' -ErrorAction SilentlyContinue) {
            $detailedError = _Get-DetailedError -ErrorRecord $ErrorRecord -AdditionalContext $AdditionalContext
            Write-Verbose "PanicHandler: Detailed error record processed."
        } else {
            # Fallback if _Get-DetailedError is not available.
            $detailedError = [PSCustomObject]@{
                Timestamp = (Get-Date -Format "o");
                Summary = $ErrorRecord.Exception.Message;
                Type = $ErrorRecord.Exception.GetType().FullName;
                StackTrace = $ErrorRecord.Exception.StackTrace;
                RawErrorRecord = $ErrorRecord.ToString();
                AdditionalContext = $AdditionalContext;
                Warning = "Warning: _Get-DetailedError function was not available for full error context."
            }
            Write-Warning "PanicHandler: _Get-DetailedError not found. Using simplified error info."
        }

        # Get system and application state info.
        $systemInfo = Get-DetailedSystemInfo

        # Attempt to capture a screenshot of the last terminal state.
        $screenshotPath = Get-TerminalScreenshot -outputPath $script:ScreenshotsDirectory

        # Assemble the full crash report.
        $crashReport = @{
            Timestamp = (Get-Date -Format "o");
            Event = "ApplicationPanic";
            Reason = $ErrorRecord.Exception.Message;
            ErrorDetails = $detailedError;
            SystemInfo = $systemInfo;
            ScreenshotFile = $screenshotPath;
            LastLogEntries = if (Get-Command 'Get-LogEntries' -ErrorAction SilentlyContinue) { (Get-LogEntries -Count 50 -Level '*' | Select-Object -ExpandProperty UserData) } else { $null };
            ErrorHistory = if (Get-Command 'Get-ErrorHistory' -ErrorAction SilentlyContinue) { Get-ErrorHistory -Count 25 } else { $null };
        }

        # Write the crash report to a JSON file.
        $crashReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $crashReportPath -Encoding UTF8 -Force
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Fatal -Message "Crash report saved to: $crashReportPath" -Data @{ Path = $crashReportPath } -Force
        }
        Write-Verbose "PanicHandler: Crash report saved to: $crashReportPath"

    } catch {
        # Critical: If crash dumping fails, log to file system directly and try to restore.
        $criticalFailMessage = "$(Get-Date -Format 'o') [CRITICAL PANIC] PANIC HANDLER FAILED: $($_.Exception.Message)`nOriginal Error: $($ErrorRecord.Exception.Message)"
        try {
            $panicFailLogPath = Join-Path $script:CrashLogDirectory "panic_handler_fail_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Add-Content -Path $panicFailLogPath -Value $criticalFailMessage -Encoding UTF8 -Force
            Write-Host "CRITICAL: Panic handler failed to create full report. Basic failure logged to: $panicFailLogPath" -ForegroundColor Red
        } catch {
            Write-Host "CRITICAL: Panic handler failed and could not log its own failure to disk. Error: $($_.Exception.Message)" -ForegroundColor DarkRed
        }
    } finally {
        # Always attempt to restore the terminal, even if crash dumping failed.
        Restore-Terminal
        # Ensure the application process exits.
        Write-Verbose "PanicHandler: Exiting application with code 1."
        exit 1
    }
}

# ------------------------------------------------------------------------------
# Module Export
# ------------------------------------------------------------------------------
# Export public functions from this module.
Export-ModuleMember -Function Initialize-PanicHandler, Invoke-PanicHandler, Get-DetailedSystemInfo
