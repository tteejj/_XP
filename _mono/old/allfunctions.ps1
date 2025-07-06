# ==============================================================================
# Axiom-Phoenix v4.0 - All Functions Consolidated
# Contains all standalone functions from the entire project (excluding class methods)
# ==============================================================================

#region Panic Handler Functions

# Module-scoped variables for panic handler
$script:CrashLogDirectory = $null
$script:ScreenshotsDirectory = $null
$script:LogDirectoryForPanic = $null

function Get-DetailedSystemInfo {
    [CmdletBinding()]
    param()

    try {
        $process = Get-Process -Id $PID -ErrorAction SilentlyContinue
        
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

function Get-TerminalScreenshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$outputPath
    )

    try {
        if (-not $global:TuiState -or -not $global:TuiState.CompositorBuffer) {
            Write-Warning "PanicHandler: TUI state or compositor buffer not available for screenshot."
            return $null
        }

        if (-not (Test-Path $outputPath)) {
            New-Item -ItemType Directory -Path $outputPath -Force -ErrorAction Stop | Out-Null
            Write-Verbose "PanicHandler: Created screenshot directory: $outputPath"
        }

        $buffer = $global:TuiState.CompositorBuffer
        $screenshotFileName = "screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $screenshotPath = Join-Path $outputPath $screenshotFileName
        
        $sb = [System.Text.StringBuilder]::new($buffer.Width * $buffer.Height * 2)
        
        for ($y = 0; $y -lt $buffer.Height; $y++) {
            for ($x = 0; $x -lt $buffer.Width; $x++) {
                [void]$sb.Append($buffer.GetCell($x, $y).Char)
            }
            [void]$sb.Append("`n")
        }
        
        $sb.ToString() | Out-File -FilePath $screenshotPath -Encoding UTF8 -Force
        Write-Verbose "PanicHandler: Terminal screenshot saved to: $screenshotPath"
        return $screenshotPath
    } catch {
        Write-Warning "PanicHandler: Failed to capture terminal screenshot: $($_.Exception.Message)"
        return $null
    }
}

function Restore-Terminal {
    [CmdletBinding()]
    param()

    try {
        [Console]::ResetColor()
        [Console]::Clear()
        [Console]::CursorVisible = $true
        [Console]::TreatControlCAsInput = $false

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
        
        if ($Host.UI.RawUI) {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
        Write-Verbose "PanicHandler: Terminal restoration complete."
    } catch {
        Write-Host "CRITICAL: PanicHandler failed to restore terminal: $($_.Exception.Message)" -ForegroundColor Red
        try { [Console]::Write("`e[0m`e[H`e[J") } catch {}
        Start-Sleep -Milliseconds 500
    }
}

function Initialize-PanicHandler {
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [hashtable]$AdditionalContext = @{}
    )
    
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

        $detailedError = $null
        if (Get-Command '_Get-DetailedError' -ErrorAction SilentlyContinue) {
            $detailedError = _Get-DetailedError -ErrorRecord $ErrorRecord -AdditionalContext $AdditionalContext
            Write-Verbose "PanicHandler: Detailed error record processed."
        } else {
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

        $systemInfo = Get-DetailedSystemInfo
        $screenshotPath = Get-TerminalScreenshot -outputPath $script:ScreenshotsDirectory

        $crashReport = @{
            Timestamp = (Get-Date -Format "o");
            Event = "ApplicationPanic";
            Reason = $ErrorRecord.Exception.Message;
            ErrorDetails = $detailedError;
            SystemInfo = $systemInfo;
            ScreenshotFile = $screenshotPath;
            LastLogEntries = if (Get-Command 'Get-LogEntries' -ErrorAction SilentlyContinue) { (Get-LogEntries -Count 50 | Select-Object -ExpandProperty UserData) } else { $null };
            ErrorHistory = if (Get-Command 'Get-ErrorHistory' -ErrorAction SilentlyContinue) { Get-ErrorHistory -Count 25 } else { $null };
        }

        $crashReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $crashReportPath -Encoding UTF8 -Force
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Fatal -Message "Crash report saved to: $crashReportPath" -Data @{ Path = $crashReportPath } -Force
        }
        Write-Verbose "PanicHandler: Crash report saved to: $crashReportPath"

    } catch {
        $criticalFailMessage = "$(Get-Date -Format 'o') [CRITICAL PANIC] PANIC HANDLER FAILED: $($_.Exception.Message)`nOriginal Error: $($ErrorRecord.Exception.Message)"
        try {
            $panicFailLogPath = Join-Path $script:CrashLogDirectory "panic_handler_fail_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Add-Content -Path $panicFailLogPath -Value $criticalFailMessage -Encoding UTF8 -Force
            Write-Host "CRITICAL: Panic handler failed to create full report. Basic failure logged to: $panicFailLogPath" -ForegroundColor Red
        } catch {
            Write-Host "CRITICAL: Panic handler failed and could not log its own failure to disk. Error: $($_.Exception.Message)" -ForegroundColor DarkRed
        }
    } finally {
        Restore-Terminal
        Write-Verbose "PanicHandler: Exiting application with code 1."
        exit 1
    }
}

#endregion

#region Logger Functions

# Module-scoped variables for logger
$script:LogPath = $null
$script:LogLevel = "Info"
$script:LogQueue = [System.Collections.Generic.List[object]]::new()
$script:MaxLogSize = 5MB
$script:LogInitialized = $false
$script:CallDepth = 0
$script:TraceAllCalls = $false

function ConvertTo-SerializableObject {
    param([object]$Object)

    if ($null -eq $Object) { return $null }

    $visited = New-Object 'System.Collections.Generic.HashSet[object]'

    function Convert-Internal {
        param([Parameter(Mandatory)][object]$InputObject, [int]$Depth)

        if ($null -eq $InputObject) { return $null }
        if ($Depth -gt 5) { return '<MaxDepthExceeded>' }
        if ($InputObject -is [System.Management.Automation.ScriptBlock]) { return '<ScriptBlock>' }
        
        if (-not $InputObject.GetType().IsValueType -and -not ($InputObject -is [string])) {
            if ($visited.Contains($InputObject)) { return '<CircularReference>' }
            [void]$visited.Add($InputObject)
        }
        
        switch ($InputObject.GetType().Name) {
            'Hashtable' {
                $r = @{}
                foreach ($k in $InputObject.Keys) {
                    try { $r[$k] = Convert-Internal $InputObject[$k] ($Depth+1) }
                    catch { $r[$k] = "<Err: $($_.Exception.Message)>" }
                }
                return $r
            }
            'PSCustomObject' {
                $r = @{}
                foreach ($p in $InputObject.PSObject.Properties) {
                    try {
                        if ($p.MemberType -ne 'ScriptMethod') {
                            $r[$p.Name] = Convert-Internal $p.Value ($Depth+1)
                        }
                    } catch { $r[$p.Name] = "<Err: $($_.Exception.Message)>" }
                }
                return $r
            }
            'Object[]' {
                $r = [System.Collections.Generic.List[object]]::new()
                for ($i=0; $i -lt [Math]::Min($InputObject.Count,10); $i++) {
                    try { [void]$r.Add((Convert-Internal $InputObject[$i] ($Depth+1))) }
                    catch { [void]$r.Add("<Err: $($_.Exception.Message)>") }
                }
                if($InputObject.Count -gt 10) { [void]$r.Add("<...>") }
                return $r.ToArray()
            }
            default {
                try {
                    if ($InputObject -is [ValueType] -or $InputObject -is [string] -or $InputObject -is [datetime]) {
                        return $InputObject
                    } else {
                        return $InputObject.ToString()
                    }
                } catch {
                    return "<Err: $($_.Exception.Message)>"
                }
            }
        }
    }
    
    return Convert-Internal -InputObject $Object -Depth 0
}

function Initialize-Logger {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$LogDirectory = (Join-Path $env:TEMP "PMCTerminal"),
        
        [ValidateNotNullOrEmpty()]
        [string]$LogFileName = "pmc_terminal_{0:yyyy-MM-dd}.log" -f (Get-Date),
        
        [ValidateSet("Debug", "Verbose", "Info", "Warning", "Error", "Fatal", "Trace")]
        [string]$Level = "Info"
    )

    try {
        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force -ErrorAction Stop | Out-Null
        }
        $script:LogPath = Join-Path $LogDirectory $LogFileName
        $script:LogLevel = $Level
        $script:LogInitialized = $true
        
        Write-Log -Level Info -Message "Logger initialized" -Data @{
            LogPath = $script:LogPath;
            LogLevel = $script:LogLevel;
            PowerShellVersion = $PSVersionTable.PSVersion.ToString();
            OS = $PSVersionTable.OS;
            PID = $PID
        } -Force
    } catch {
        Write-Warning "Failed to initialize logger: $($_.Exception.Message)"
        $script:LogInitialized = $false
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [ValidateSet("Debug", "Verbose", "Info", "Warning", "Error", "Fatal", "Trace")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        
        [object]$Data,
        
        [switch]$Force
    )
    
    if (-not $script:LogInitialized -and -not $Force) { return }

    $levelPriority = @{ Debug=0; Trace=0; Verbose=1; Info=2; Warning=3; Error=4; Fatal=5 }

    if (-not $Force -and $levelPriority[$Level] -lt $levelPriority[$script:LogLevel]) { return }

    try {
        $caller = (Get-PSCallStack)[1]
        
        $logContext = @{
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff");
            Level = $Level;
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId;
            CallDepth = $script:CallDepth;
            Message = $Message;
            Caller = @{
                Command = $caller.Command;
                Location = $caller.Location;
                ScriptName = $caller.ScriptName;
                LineNumber = $caller.ScriptLineNumber;
            }
        }
        
        if ($PSBoundParameters.ContainsKey('Data')) {
            $logContext.UserData = if ($Data -is [Exception]) {
                $innerExceptions = [System.Collections.Generic.List[object]]::new()
                $currentInner = $Data.InnerException
                while ($currentInner) {
                    [void]$innerExceptions.Add(@{ Message = $currentInner.Message; Type = $currentInner.GetType().FullName; StackTrace = $currentInner.StackTrace })
                    $currentInner = $currentInner.InnerException
                }
                @{
                    Type = $Data.GetType().FullName;
                    Message = $Data.Message;
                    StackTrace = $Data.StackTrace;
                    TargetSite = $Data.TargetSite.Name;
                    InnerExceptions = $innerExceptions.ToArray()
                }
            } else {
                ConvertTo-SerializableObject -Object $Data
            }

            if ($Data -is [hashtable] -and $Data.ContainsKey('Component')) {
                $logContext.Caller.Command = $Data.Component
                $logContext.Caller.Location = ""
                $logContext.Caller.ScriptName = ""
                $logContext.Caller.LineNumber = 0
            }
            elseif ($logContext.UserData -is [hashtable] -and $logContext.UserData.ContainsKey('Component')) {
                 $logContext.Caller.Command = $logContext.UserData.Component
                 $logContext.Caller.Location = ""
                 $logContext.Caller.ScriptName = ""
                 $logContext.Caller.LineNumber = 0
            }
        }

        $indent = "  " * $script:CallDepth
        $callerInfo = if ($logContext.Caller.ScriptName) {
            "$([System.IO.Path]::GetFileName($logContext.Caller.ScriptName)):$($logContext.Caller.LineNumber)"
        } elseif ($logContext.Caller.Command) {
            $logContext.Caller.Command
        } else {
            "UnknownCaller"
        }
        
        $logEntry = "$($logContext.Timestamp) [$($Level.PadRight(7))] $indent [$callerInfo] $Message"
        
        if ($PSBoundParameters.ContainsKey('Data')) {
            if ($Data -is [Exception]) {
                $logEntry += "`n${indent}  Exception: $($Data.Message)`n${indent}  StackTrace: $($Data.StackTrace)"
                if ($Data.InnerException) { $logEntry += "`n${indent}  InnerException: $($Data.InnerException.Message)" }
            } else {
                try {
                    $logEntry += "`n${indent}  Data: $(ConvertTo-SerializableObject -Object $Data | ConvertTo-Json -Compress -Depth 4 -WarningAction SilentlyContinue)"
                } catch {
                    $logEntry += "`n${indent}  Data: $($Data.ToString()) (JSON conversion failed: $($_.Exception.Message))"
                }
            }
        }
        
        $script:LogQueue.Add($logContext)
        
        if ($script:LogQueue.Count -gt 2000) {
            $script:LogQueue.RemoveRange(0, 1000)
        }
        
        if ($script:LogPath) {
            try {
                if ((Test-Path $script:LogPath) -and (Get-Item $script:LogPath).Length -gt $script:MaxLogSize) {
                    $newLogFileName = ($script:LogPath -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log")
                    Move-Item -Path $script:LogPath -Destination $newLogFileName -Force -ErrorAction SilentlyContinue
                    Write-Host "Log file '$([System.IO.Path]::GetFileName($script:LogPath))' rolled to '$([System.IO.Path]::GetFileName($newLogFileName))'." -ForegroundColor DarkYellow
                }
                Add-Content -Path $script:LogPath -Value $logEntry -Encoding UTF8 -Force
            } catch {
                Write-Host "LOG FILE WRITE FAILED FOR '$($script:LogPath)': $logEntry`nError: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        if ($Level -in @('Error', 'Fatal')) {
            Write-Host $logEntry -ForegroundColor Red
        } elseif ($Level -eq 'Warning') {
            Write-Host $logEntry -ForegroundColor Yellow
        }

    } catch {
        try {
            $errorEntry = "$(Get-Date -Format 'o') [CRITICAL LOGGER ERROR] Failed to log: $($_.Exception.Message)"
            if ($script:LogPath) { Add-Content -Path $script:LogPath -Value $errorEntry -Encoding UTF8 -Force }
            Write-Host $errorEntry -ForegroundColor Red
        } catch {
            Write-Host "CRITICAL: Logger failed completely, cannot log its own failure: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Trace-FunctionEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$FunctionName,
        [object]$Parameters
    )
    if (-not $script:TraceAllCalls) { return }
    $script:CallDepth++
    Write-Log -Level Trace -Message "ENTER: $FunctionName" -Data @{ Parameters = ConvertTo-SerializableObject $Parameters; Action = "FunctionEntry" }
}

function Trace-FunctionExit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$FunctionName,
        [object]$ReturnValue,
        [switch]$WithError
    )
    if (-not $script:TraceAllCalls) { return }
    $script:CallDepth = [Math]::Max(0, $script:CallDepth - 1)
    Write-Log -Level Trace -Message "EXIT: $FunctionName" -Data @{ ReturnValue = ConvertTo-SerializableObject $ReturnValue; Action = ($WithError ? "FunctionExitWithError" : "FunctionExit"); HasError = $WithError.IsPresent }
}

function Trace-Step {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$StepName,
        [object]$StepData,
        [string]$Module
    )
    $caller = (Get-PSCallStack)[1]
    $moduleInfo = $Module ?? ($caller.ScriptName ? [System.IO.Path]::GetFileNameWithoutExtension($caller.ScriptName) : "Unknown");
    Write-Log -Level Debug -Message "STEP: $StepName" -Data @{ StepData = ConvertTo-SerializableObject $StepData; Module = $moduleInfo; Action = "Step" }
}

function Trace-StateChange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$StateType,
        [object]$OldValue,
        [object]$NewValue,
        [string]$PropertyPath
    )
    Write-Log -Level Debug -Message "STATE: $StateType changed" -Data @{ StateType = $StateType; PropertyPath = $PropertyPath; OldValue = ConvertTo-SerializableObject $OldValue; NewValue = ConvertTo-SerializableObject $NewValue; Action = "StateChange" }
}

function Trace-ComponentLifecycle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ComponentType,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ComponentId,
        [Parameter(Mandatory)][ValidateSet('Create','Initialize','Render','Update','Destroy')][string]$Phase,
        [object]$ComponentData
    )
    Write-Log -Level Debug -Message "COMPONENT: $ComponentType [$ComponentId] $Phase" -Data @{ ComponentType = $ComponentType; ComponentId = $ComponentId; Phase = $Phase; ComponentData = ConvertTo-SerializableObject $ComponentData; Action = "ComponentLifecycle" }
}

function Trace-ServiceCall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ServiceName,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$MethodName,
        [object]$Parameters,
        [object]$Result,
        [switch]$IsError
    )
    Write-Log -Level Debug -Message "SERVICE: $ServiceName.$MethodName" -Data @{ ServiceName = $ServiceName; MethodName = $MethodName; Parameters = ConvertTo-SerializableObject $Parameters; Result = ConvertTo-SerializableObject $Result; Action = ($IsError ? "ServiceCallError" : "ServiceCall"); IsError = $IsError.IsPresent }
}

function Get-LogEntries {
    [CmdletBinding()]
    param(
        [int]$Count = 100,
        [ValidateSet("Debug", "Verbose", "Info", "Warning", "Error", "Fatal", "Trace")][string]$Level,
        [string]$Module,
        [string]$Action
    )
    try {
        $entries = $script:LogQueue.ToArray()
        
        if ($Level) { $entries = $entries | Where-Object { $_.Level -eq $Level } }
        if ($Module) { $entries = $entries | Where-Object { $_.Caller.ScriptName -and ([System.IO.Path]::GetFileNameWithoutExtension($_.Caller.ScriptName) -like "*$Module*") } }
        if ($Action) { $entries = $entries | Where-Object { $_.UserData.Action -eq $Action } }
        
        return $entries | Select-Object -Last $Count
    } catch {
        Write-Warning "Error getting log entries: $($_.Exception.Message)"
        return @()
    }
}

function Get-CallTrace {
    [CmdletBinding()]
    param([int]$Depth = 10)
    try {
        $callStack = Get-PSCallStack
        $trace = [System.Collections.Generic.List[object]]::new()
        
        for ($i = 1; $i -lt [Math]::Min($callStack.Count, $Depth + 1); $i++) {
            $call = $callStack[$i]
            [void]$trace.Add(@{
                Level = $i - 1;
                Command = $call.Command;
                Location = $call.Location;
                ScriptName = $call.ScriptName;
                LineNumber = $call.ScriptLineNumber
            })
        }
        return $trace.ToArray()
    } catch {
        Write-Warning "Error getting call trace: $($_.Exception.Message)"
        return @()
    }
}

function Clear-LogQueue {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("in-memory log queue", "Clear")) {
        try {
            $script:LogQueue.Clear()
            Write-Verbose "In-memory log queue cleared."
        } catch {
            Write-Warning "Error clearing log queue: $($_.Exception.Message)"
        }
    }
}

function Set-LogLevel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Debug","Verbose","Info","Warning","Error","Fatal","Trace")]
        [string]$Level
    )
    try {
        $oldLevel = $script:LogLevel
        $script:LogLevel = $Level
        Write-Log -Level Info -Message "Log level changed from '$oldLevel' to '$Level'" -Force
        Write-Verbose "Log level set to '$Level'."
    } catch {
        Write-Warning "Error setting log level to '$Level': $($_.Exception.Message)"
    }
}

function Enable-CallTracing {
    [CmdletBinding()]
    param()
    $script:TraceAllCalls = $true
    Write-Log -Level Info -Message "Call tracing enabled" -Force
}

function Disable-CallTracing {
    [CmdletBinding()]
    param()
    $script:TraceAllCalls = $false
    $script:CallDepth = 0
    Write-Log -Level Info -Message "Call tracing disabled" -Force
}

function Get-LogPath {
    [CmdletBinding()]
    param()
    return $script:LogPath
}

function Get-LogStatistics {
    [CmdletBinding()]
    param()
    try {
        $stats = [PSCustomObject]@{
            TotalEntries = $script:LogQueue.Count;
            LogPath = $script:LogPath;
            LogLevel = $script:LogLevel;
            CallTracingEnabled = $script:TraceAllCalls;
            LogFileSize = ($script:LogPath -and (Test-Path $script:LogPath) ? (Get-Item $script:LogPath).Length : 0);
            EntriesByLevel = @{};
            EntriesByModule = @{};
            EntriesByAction = @{}
        }
        
        foreach ($entry in $script:LogQueue) {
            $level = $entry.Level;
            if (-not $stats.EntriesByLevel.ContainsKey($level)) { $stats.EntriesByLevel[$level]=0 }
            $stats.EntriesByLevel[$level]++

            if ($entry.Caller.ScriptName) {
                $module = [System.IO.Path]::GetFileNameWithoutExtension($entry.Caller.ScriptName);
                if (-not $stats.EntriesByModule.ContainsKey($module)) { $stats.EntriesByModule[$module]=0 }
                $stats.EntriesByModule[$module]++
            }

            if ($entry.UserData -is [hashtable] -and $entry.UserData.ContainsKey('Action')) {
                $action = $entry.UserData.Action;
                if (-not $stats.EntriesByAction.ContainsKey($action)) { $stats.EntriesByAction[$action]=0 }
                $stats.EntriesByAction[$action]++
            }
        }
        Write-Verbose "Retrieved logger statistics."
        return $stats
    } catch {
        Write-Warning "Error getting log statistics: $($_.Exception.Message)"
        return [PSCustomObject]@{}
    }
}

#endregion

#region TUI Primitives Functions

function Write-TuiText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][TuiBuffer]$Buffer,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][string]$Text,
        $ForegroundColor = [ConsoleColor]::White,
        $BackgroundColor = [ConsoleColor]::Black,
        [bool]$Bold = $false,
        [bool]$Underline = $false,
        [bool]$Italic = $false
    )
    try {
        if ($Y -lt 0 -or $Y -ge $Buffer.Height) {
            Write-Warning "Skipping Write-TuiText: Y coordinate ($Y) for text '$Text' is out of buffer '$($Buffer.Name)' vertical bounds (0..$($Buffer.Height-1))."
            return
        }
        $baseCell = [TuiCell]::new(' ', $ForegroundColor, $BackgroundColor)
        $baseCell.Bold = $Bold
        $baseCell.Underline = $Underline
        $baseCell.Italic = $Italic
        
        if ($X -ge 0 -and $X -lt $Buffer.Width -and $Y -ge 0 -and $Y -lt $Buffer.Height) {
            $existingCell = $Buffer.GetCell($X, $Y)
            if ($existingCell -and $existingCell.ZIndex -gt 0) {
                $baseCell.ZIndex = $existingCell.ZIndex
            }
        }
        $currentX = $X
        foreach ($char in $Text.ToCharArray()) {
            if ($currentX -ge $Buffer.Width) { break } 
            if ($currentX -ge 0) {
                $charCell = [TuiCell]::new($baseCell)
                $charCell.Char = $char
                $Buffer.SetCell($currentX, $Y, $charCell)
            }
            $currentX++
        }
        Write-Verbose "Write-TuiText: Wrote '$Text' to buffer '$($Buffer.Name)' at ($X, $Y)."
    }
    catch {
        Write-Error "Failed to write text to TUI buffer '$($Buffer.Name)' at ($X, $Y): $($_.Exception.Message)"
        throw
    }
}

function Write-TuiBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][TuiBuffer]$Buffer,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$Width,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$Height,
        [ValidateSet("Single", "Double", "Rounded", "Thick")][string]$BorderStyle = "Single",
        $BorderColor = [ConsoleColor]::White,
        $BackgroundColor = [ConsoleColor]::Black,
        [string]$Title = ""
    )
    try {
        if ($X -ge $Buffer.Width -or ($X + $Width) -le 0 -or $Y -ge $Buffer.Height -or ($Y + $Height) -le 0) {
            Write-Verbose "Skipping Write-TuiBox: Box at ($X, $Y) with dimensions $($Width)x$($Height) is entirely outside buffer '$($Buffer.Name)'."
            return
        }
        $borders = Get-TuiBorderChars -Style $BorderStyle
        $drawStartX = [Math]::Max(0, $X)
        $drawStartY = [Math]::Max(0, $Y)
        $drawEndX = [Math]::Min($Buffer.Width, $X + $Width)
        $drawEndY = [Math]::Min($Buffer.Height, $Y + $Height)
        $effectiveWidth = $drawEndX - $drawStartX
        $effectiveHeight = $drawEndY - $drawStartY
        if ($effectiveWidth -le 0 -or $effectiveHeight -le 0) {
            Write-Verbose "Write-TuiBox: Effective drawing area is invalid after clipping. Skipping."
            return
        }
        $fillCell = [TuiCell]::new(' ', $BorderColor, $BackgroundColor)
        
        $existingCell = $Buffer.GetCell($drawStartX, $drawStartY)
        if ($existingCell -and $existingCell.ZIndex -gt 0) {
            $fillCell.ZIndex = $existingCell.ZIndex
        }
        for ($currentY = $drawStartY; $currentY -lt $drawEndY; $currentY++) {
            for ($currentX = $drawStartX; $currentX -lt $drawEndX; $currentX++) {
                $Buffer.SetCell($currentX, $currentY, [TuiCell]::new($fillCell))
            }
        }
        if ($X -ge 0 -and $Y -ge 0) { 
            $borderCell = [TuiCell]::new($borders.TopLeft, $BorderColor, $BackgroundColor)
            $borderCell.ZIndex = $fillCell.ZIndex
            $Buffer.SetCell($X, $Y, $borderCell) 
        }
        if (($X + $Width - 1) -lt $Buffer.Width -and $Y -ge 0) { 
            $borderCell = [TuiCell]::new($borders.TopRight, $BorderColor, $BackgroundColor)
            $borderCell.ZIndex = $fillCell.ZIndex
            $Buffer.SetCell($X + $Width - 1, $Y, $borderCell) 
        }
        if ($X -ge 0 -and ($Y + $Height - 1) -lt $Buffer.Height) { 
            $borderCell = [TuiCell]::new($borders.BottomLeft, $BorderColor, $BackgroundColor)
            $borderCell.ZIndex = $fillCell.ZIndex
            $Buffer.SetCell($X, $Y + $Height - 1, $borderCell) 
        }
        if (($X + $Width - 1) -lt $Buffer.Width -and ($Y + $Height - 1) -lt $Buffer.Height) { 
            $borderCell = [TuiCell]::new($borders.BottomRight, $BorderColor, $BackgroundColor)
            $borderCell.ZIndex = $fillCell.ZIndex
            $Buffer.SetCell($X + $Width - 1, $Y + $Height - 1, $borderCell) 
        }
        for ($cx = 1; $cx -lt ($Width - 1); $cx++) {
            if (($X + $cx) -ge 0 -and ($X + $cx) -lt $Buffer.Width) {
                if ($Y -ge 0 -and $Y -lt $Buffer.Height) { $Buffer.SetCell($X + $cx, $Y, [TuiCell]::new($borders.Horizontal, $BorderColor, $BackgroundColor)) }
                if ($Height -gt 1 -and ($Y + $Height - 1) -ge 0 -and ($Y + $Height - 1) -lt $Buffer.Height) { $Buffer.SetCell($X + $cx, $Y + $Height - 1, [TuiCell]::new($borders.Horizontal, $BorderColor, $BackgroundColor)) }
            }
        }
        for ($cy = 1; $cy -lt ($Height - 1); $cy++) {
            if (($Y + $cy) -ge 0 -and ($Y + $cy) -lt $Buffer.Height) {
                if ($X -ge 0 -and $X -lt $Buffer.Width) { $Buffer.SetCell($X, $Y + $cy, [TuiCell]::new($borders.Vertical, $BorderColor, $BackgroundColor)) }
                if ($Width -gt 1 -and ($X + $Width - 1) -ge 0 -and ($X + $Width - 1) -lt $Buffer.Width) { $Buffer.SetCell($X + $Width - 1, $Y + $cy, [TuiCell]::new($borders.Vertical, $BorderColor, $BackgroundColor)) }
            }
        }
        if (-not [string]::IsNullOrEmpty($Title) -and $Y -ge 0 -and $Y -lt $Buffer.Height) {
            $titleText = " $Title "
            if ($titleText.Length -le ($Width - 2)) { 
                $titleX = $X + [Math]::Floor(($Width - $titleText.Length) / 2)
                Write-TuiText -Buffer $Buffer -X $titleX -Y $Y -Text $titleText -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
            }
        }
        Write-Verbose "Write-TuiBox: Drew '$BorderStyle' box on buffer '$($Buffer.Name)' at ($X, $Y) with dimensions $($Width)x$($Height)."
    }
    catch {
        Write-Error "Failed to draw TUI box on buffer '$($Buffer.Name)' at ($X, $Y), $($Width)x$($Height): $($_.Exception.Message)"
        throw
    }
}

function Get-TuiBorderChars {
    [CmdletBinding()]
    param(
        [ValidateSet("Single", "Double", "Rounded", "Thick")][string]$Style = "Single"
    )
    try {
        $styles = @{
            Single = @{ TopLeft = '┌'; TopRight = '┐'; BottomLeft = '└'; BottomRight = '┘'; Horizontal = '─'; Vertical = '│' }
            Double = @{ TopLeft = '╔'; TopRight = '╗'; BottomLeft = '╚'; BottomRight = '╝'; Horizontal = '═'; Vertical = '║' }
            Rounded = @{ TopLeft = '╭'; TopRight = '╮'; BottomLeft = '╰'; BottomRight = '╯'; Horizontal = '─'; Vertical = '│' }
            Thick = @{ TopLeft = '┏'; TopRight = '┓'; BottomLeft = '┗'; BottomRight = '┛'; Horizontal = '━'; Vertical = '┃' }
        }
        $selectedStyle = $styles[$Style]
        if ($null -eq $selectedStyle) {
            Write-Warning "Get-TuiBorderChars: Border style '$Style' not found. Returning 'Single' style."
            return $styles.Single
        }
        Write-Verbose "Get-TuiBorderChars: Retrieved TUI border characters for style: $Style."
        return $selectedStyle
    }
    catch {
        Write-Error "Failed to get TUI border characters for style '$Style': $($_.Exception.Message)"
        throw
    }
}

function New-TuiBuffer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Width,
        [Parameter(Mandatory)][int]$Height,
        [string]$Name = "Unnamed"
    )
    return [TuiBuffer]::new($Width, $Height, $Name)
}

#endregion

#region TUI Engine Functions

function Initialize-TuiEngine {
    [CmdletBinding()]
    param(
        [int]$Width = [Console]::WindowWidth,
        [int]$Height = [Console]::WindowHeight - 1
    )
    
    try {
        Write-Log -Level Info -Message "Initializing TUI Engine with dimensions $Width x $Height"
        
        $global:TuiState.BufferWidth = $Width
        $global:TuiState.BufferHeight = $Height
        $global:TuiState.LastWindowWidth = [Console]::WindowWidth
        $global:TuiState.LastWindowHeight = [Console]::WindowHeight
        
        $global:TuiState.CompositorBuffer = [TuiBuffer]::new($Width, $Height, "CompositorBuffer")
        $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($Width, $Height, "PreviousCompositorBuffer")
        
        [Console]::CursorVisible = $false
        [Console]::TreatControlCAsInput = $true
        
        Initialize-InputThread
        Initialize-PanicHandler
        
        Write-Log -Level Info -Message "TUI Engine initialized successfully"
    }
    catch {
        Write-Error "Failed to initialize TUI Engine: $($_.Exception.Message)"
        throw
    }
}

function Initialize-InputThread {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log -Level Debug -Message "Input system initialized (synchronous mode)"
    }
    catch {
        Write-Error "Failed to initialize input system: $($_.Exception.Message)"
        throw
    }
}

function Start-TuiLoop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InitialScreen
    )
    
    try {
        if (-not $global:TuiState.BufferWidth) { Initialize-TuiEngine }
        if ($InitialScreen) { Push-Screen -Screen $InitialScreen }
        if (-not $global:TuiState.CurrentScreen) { throw "No screen available to start TUI loop" }
        
        $global:TuiState.Running = $true
        $frameTimer = [System.Diagnostics.Stopwatch]::new()
        $targetFrameTime = 1000.0 / $global:TuiState.RenderStats.TargetFPS
        
        Write-Log -Level Info -Message "Starting TUI main loop"
        
        while ($global:TuiState.Running) {
            try {
                $frameTimer.Restart()
                Check-ForResize
                $hadInput = Process-TuiInput
                if ($global:TuiState.IsDirty -or $hadInput) {
                    Render-Frame
                    $global:TuiState.IsDirty = $false
                }
                $elapsed = $frameTimer.ElapsedMilliseconds
                if ($elapsed -lt $targetFrameTime) {
                    $sleepTime = [Math]::Max(1, [int]($targetFrameTime - $elapsed))
                    Start-Sleep -Milliseconds $sleepTime
                }
                $global:TuiState.RenderStats.LastFrameTime = $frameTimer.ElapsedMilliseconds
                $global:TuiState.RenderStats.FrameCount++
                if ($global:TuiState.RenderStats.FrameCount % 60 -eq 0) {
                    $global:TuiState.RenderStats.AverageFrameTime = $global:TuiState.RenderStats.LastFrameTime
                }
            }
            catch {
                Write-Error "Error in TUI main loop: $($_.Exception.Message)"
                Invoke-PanicHandler -ErrorRecord $_ -AdditionalContext @{ Context = "TUI Main Loop" }
                $global:TuiState.Running = $false
                break
            }
        }
        
        Write-Log -Level Info -Message "TUI main loop ended"
    }
    catch {
        Write-Error "Fatal error in TUI loop: $($_.Exception.Message)"
        throw
    }
    finally {
        Cleanup-TuiEngine
    }
}

function Check-ForResize {
    [CmdletBinding()]
    param()
    
    try {
        $currentWidth = [Console]::WindowWidth
        $currentHeight = [Console]::WindowHeight - 1
        
        if ($currentWidth -ne $global:TuiState.BufferWidth -or $currentHeight -ne $global:TuiState.BufferHeight) {
            Write-Log -Level Info -Message "Terminal resized from $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight) to $($currentWidth)x$($currentHeight)"
            
            $global:TuiState.BufferWidth = $currentWidth
            $global:TuiState.BufferHeight = $currentHeight
            
            $global:TuiState.CompositorBuffer.Resize($currentWidth, $currentHeight)
            $global:TuiState.PreviousCompositorBuffer.Resize($currentWidth, $currentHeight)
            
            if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.Resize($currentWidth, $currentHeight) }
            
            foreach ($overlay in $global:TuiState.OverlayStack) {
                if ($overlay.PSObject.TypeNames -contains 'Dialog') {
                    $overlay.X = [Math]::Floor(($currentWidth - $overlay.Width) / 2)
                    $overlay.Y = [Math]::Floor(($currentHeight - $overlay.Height) / 4)
                }
                $overlay.Resize($overlay.Width, $overlay.Height)
            }
            
            if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
                Publish-Event -EventName "TUI.Resized" -Data @{ Width = $currentWidth; Height = $currentHeight; PreviousWidth = $global:TuiState.LastWindowWidth; PreviousHeight = $global:TuiState.LastWindowHeight }
            }
            
            $global:TuiState.LastWindowWidth = $currentWidth
            $global:TuiState.LastWindowHeight = $currentHeight
            Request-TuiRefresh
        }
    }
    catch { Write-Error "Error checking for resize: $($_.Exception.Message)" }
}

function Process-TuiInput {
    [CmdletBinding()]
    param()
    
    $hadInput = $false
    
    try {
        while ([Console]::KeyAvailable) {
            $hadInput = $true
            $keyInfo = [Console]::ReadKey($true)
            
            if (Handle-GlobalShortcuts -KeyInfo $keyInfo) { continue }
            if ($global:TuiState.OverlayStack.Count -gt 0) {
                if ($global:TuiState.OverlayStack[-1].HandleInput($keyInfo)) { continue }
            }
            if ($global:TuiState.FocusedComponent) {
                if ($global:TuiState.FocusedComponent.HandleInput($keyInfo)) { continue }
            }
            if ($global:TuiState.CurrentScreen) {
                if ($global:TuiState.CurrentScreen.HandleInput($keyInfo)) { continue }
            }
            Write-Verbose "Unhandled input: $($keyInfo.Key)"
        }
    }
    catch { Write-Error "Error processing input: $($_.Exception.Message)" }
    
    return $hadInput
}

function Handle-GlobalShortcuts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$KeyInfo
    )
    
    try {
        if ($KeyInfo.Key -eq [ConsoleKey]::C -and $KeyInfo.Modifiers -band [ConsoleModifiers]::Control) {
            Write-Log -Level Info -Message "Received Ctrl+C, initiating graceful shutdown"
            $global:TuiState.Running = $false
            return $true
        }
        if ($KeyInfo.Key -eq [ConsoleKey]::P -and $KeyInfo.Modifiers -band [ConsoleModifiers]::Control) {
            if (Get-Command Publish-Event -ErrorAction SilentlyContinue) {
                Publish-Event -EventName "CommandPalette.Open"
                return $true
            }
        }
        if ($KeyInfo.Key -eq [ConsoleKey]::F12) {
            Show-DebugInfo
            return $true
        }
        return $false
    }
    catch {
        Write-Error "Error handling global shortcuts: $($_.Exception.Message)"
        return $false
    }
}

function Render-Frame {
    [CmdletBinding()]
    param()
    
    try {
        $global:TuiState.CompositorBuffer.Clear()
        
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.Render()
            $global:TuiState.CompositorBuffer.BlendBuffer($global:TuiState.CurrentScreen.GetBuffer(), 0, 0)
        }
        
        foreach ($overlay in $global:TuiState.OverlayStack) {
            $overlayBuffer = $overlay.GetBuffer()
            if ($overlayBuffer) {
                for ($y = 0; $y -lt $overlay.Height; $y++) {
                    for ($x = 0; $x -lt $overlay.Width; $x++) {
                        $compX = $overlay.X + $x
                        $compY = $overlay.Y + $y
                        if ($compX -ge 0 -and $compX -lt $global:TuiState.BufferWidth -and 
                            $compY -ge 0 -and $compY -lt $global:TuiState.BufferHeight) {
                            $clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black)
                            $clearCell.ZIndex = 1000
                            $global:TuiState.CompositorBuffer.SetCell($compX, $compY, $clearCell)
                        }
                    }
                }
                
                $overlay.Render()
                $global:TuiState.CompositorBuffer.BlendBuffer($overlayBuffer, $overlay.X, $overlay.Y)
            }
        }
        
        Render-CompositorToConsole
        
        $temp = $global:TuiState.PreviousCompositorBuffer
        $global:TuiState.PreviousCompositorBuffer = $global:TuiState.CompositorBuffer
        $global:TuiState.CompositorBuffer = $temp
    }
    catch { Write-Error "Error rendering frame: $($_.Exception.Message)" }
}

function Render-CompositorToConsole {
    [CmdletBinding()]
    param()
    
    try {
        $output = [System.Text.StringBuilder]::new()
        for ($y = 0; $y -lt $global:TuiState.BufferHeight; $y++) {
            for ($x = 0; $x -lt $global:TuiState.BufferWidth; $x++) {
                $currentCell = $global:TuiState.CompositorBuffer.GetCell($x, $y)
                $previousCell = $global:TuiState.PreviousCompositorBuffer.GetCell($x, $y)
                if ($currentCell.DiffersFrom($previousCell)) {
                    [void]$output.Append("`e[" + ($y + 1) + ";" + ($x + 1) + "H")
                    [void]$output.Append([TuiAnsiHelper]::Reset())
                    [void]$output.Append([TuiAnsiHelper]::GetForegroundCode($currentCell.ForegroundColor))
                    [void]$output.Append([TuiAnsiHelper]::GetBackgroundCode($currentCell.BackgroundColor))
                    if ($currentCell.Bold) { [void]$output.Append([TuiAnsiHelper]::Bold()) }
                    if ($currentCell.Underline) { [void]$output.Append([TuiAnsiHelper]::Underline()) }
                    if ($currentCell.Italic) { [void]$output.Append([TuiAnsiHelper]::Italic()) }
                    [void]$output.Append($currentCell.Char)
                }
            }
        }
        if ($output.Length -gt 0) {
            [void]$output.Append([TuiAnsiHelper]::Reset())
            [Console]::Write($output.ToString())
        }
    }
    catch { Write-Error "Error rendering to console: $($_.Exception.Message)" }
}

function Cleanup-TuiEngine {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log -Level Info -Message "Cleaning up TUI Engine"
        if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.Cleanup() }
        while ($global:TuiState.ScreenStack.Count -gt 0) { $global:TuiState.ScreenStack.Pop().Cleanup() }
        foreach ($overlay in $global:TuiState.OverlayStack) { $overlay.Cleanup() }
        $global:TuiState.OverlayStack.Clear()
        
        [Console]::CursorVisible = $true
        [Console]::TreatControlCAsInput = $false
        [Console]::Clear()
        
        Write-Log -Level Info -Message "TUI Engine cleanup completed"
    }
    catch { Write-Error "Error during TUI cleanup: $($_.Exception.Message)" }
}

function Push-Screen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Screen
    )
    if (-not $Screen) { Write-Error "Push-Screen: Screen parameter is null"; return }
    try {
        $screenName = $Screen.Name ?? "UnknownScreen"
        Write-Log -Level Debug -Message "Pushing screen: $screenName"
        if ($global:TuiState.FocusedComponent) { $global:TuiState.FocusedComponent.OnBlur() }
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.OnExit()
            [void]$global:TuiState.ScreenStack.Push($global:TuiState.CurrentScreen)
        }
        $global:TuiState.CurrentScreen = $Screen
        $global:TuiState.FocusedComponent = $null
        $Screen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)
        if ($Screen.PSObject.Methods['Initialize']) { $Screen.Initialize() }
        $Screen.OnEnter()
        $Screen.RequestRedraw()
        Request-TuiRefresh
        if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
            Publish-Event -EventName "Screen.Pushed" -Data @{ ScreenName = $screenName }
        }
        Write-Log -Level Debug -Message "Screen pushed successfully: $screenName"
    }
    catch {
        $errorMsg = $_.Exception.Message ?? "Unknown error"
        $screenName = if ($Screen -and $Screen.PSObject.Properties['Name']) { $Screen.Name } else { "UnknownScreen" }
        Write-Error "Error pushing screen '$screenName': $errorMsg"
        $global:TuiState.Running = $false
    }
}

function Pop-Screen {
    [CmdletBinding()]
    param()
    
    if ($global:TuiState.ScreenStack.Count -eq 0) {
        Write-Log -Level Warning -Message "Cannot pop screen: screen stack is empty"
        return $false
    }
    try {
        Write-Log -Level Debug -Message "Popping screen"
        if ($global:TuiState.FocusedComponent) { $global:TuiState.FocusedComponent.OnBlur() }
        $screenToExit = $global:TuiState.CurrentScreen
        $global:TuiState.CurrentScreen = $global:TuiState.ScreenStack.Pop()
        $global:TuiState.FocusedComponent = $null
        if ($screenToExit) {
            $screenToExit.OnExit()
            if ($screenToExit.PSObject.Methods['Cleanup']) { $screenToExit.Cleanup() }
        }
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.OnResume()
            if ($global:TuiState.CurrentScreen.LastFocusedComponent) { Set-ComponentFocus -Component $global:TuiState.CurrentScreen.LastFocusedComponent }
        }
        Request-TuiRefresh
        if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
            Publish-Event -EventName "Screen.Popped" -Data @{ ScreenName = $global:TuiState.CurrentScreen.Name }
        }
        Write-Log -Level Debug -Message "Screen popped successfully"
        return $true
    }
    catch {
        Write-Error "Error popping screen: $($_.Exception.Message)"
        return $false
    }
}

function Show-TuiOverlay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Element
    )
    try {
        Write-Log -Level Debug -Message "Showing overlay: $($Element.Name)"
        if ($Element.PSObject.Methods['Initialize']) { $Element.Initialize() }
        $global:TuiState.OverlayStack.Add($Element)
        Request-TuiRefresh
        Write-Log -Level Debug -Message "Overlay shown successfully: $($Element.Name)"
    }
    catch { Write-Error "Error showing overlay '$($Element.Name)': $($_.Exception.Message)" }
}

function Close-TopTuiOverlay {
    [CmdletBinding()]
    param()
    
    try {
        if ($global:TuiState.OverlayStack.Count -gt 0) {
            $overlay = $global:TuiState.OverlayStack[-1]
            $global:TuiState.OverlayStack.RemoveAt($global:TuiState.OverlayStack.Count - 1)
            if ($overlay.PSObject.Methods['Cleanup']) { $overlay.Cleanup() }
            Request-TuiRefresh
            Write-Log -Level Debug -Message "Overlay closed: $($overlay.Name)"
        }
    }
    catch { Write-Error "Error closing overlay: $($_.Exception.Message)" }
}

function Set-ComponentFocus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Component
    )
    try {
        if (-not $Component.IsFocusable) {
            Write-Log -Level Warning -Message "Cannot focus non-focusable component: $($Component.Name)"
            return
        }
        if ($global:TuiState.FocusedComponent) { $global:TuiState.FocusedComponent.OnBlur() }
        $global:TuiState.FocusedComponent = $Component
        $Component.OnFocus()
        if ($global:TuiState.CurrentScreen) {
            $global:TuiState.CurrentScreen.LastFocusedComponent = $Component
        }
        Request-TuiRefresh
        Write-Log -Level Debug -Message "Focus set to component: $($Component.Name)"
    }
    catch { Write-Error "Error setting focus to component '$($Component.Name)': $($_.Exception.Message)" }
}

function Get-FocusedComponent {
    [CmdletBinding()]
    param()
    
    return $global:TuiState.FocusedComponent
}

function Request-TuiRefresh {
    [CmdletBinding()]
    param()
    
    $global:TuiState.IsDirty = $true
}

function Show-DebugInfo {
    [CmdletBinding()]
    param()
    
    try {
        $debugInfo = @"
=== TUI Engine Debug Information ===
Running: $($global:TuiState.Running)
Buffer Size: $($global:TuiState.BufferWidth) x $($global:TuiState.BufferHeight)
Frame Count: $($global:TuiState.RenderStats.FrameCount)
Last Frame Time: $($global:TuiState.RenderStats.LastFrameTime)ms
Average Frame Time: $($global:TuiState.RenderStats.AverageFrameTime)ms
Target FPS: $($global:TuiState.RenderStats.TargetFPS)
Screen Stack Count: $($global:TuiState.ScreenStack.Count)
Overlay Count: $($global:TuiState.OverlayStack.Count)
Current Screen: $($global:TuiState.CurrentScreen?.Name ?? 'None')
Focused Component: $($global:TuiState.FocusedComponent?.Name ?? 'None')
Input Queue Size: $($global:TuiState.InputQueue.Count)
Memory Usage: $([math]::round([GC]::GetTotalMemory($false) / 1MB, 2)) MB
=== End Debug Information ===
"@
        
        Write-Log -Level Info -Message $debugInfo
        if (Get-Command Show-AlertDialog -ErrorAction SilentlyContinue) {
            Show-AlertDialog -Title "Debug Information" -Message $debugInfo
        }
    }
    catch { Write-Error "Error showing debug info: $($_.Exception.Message)" }
}

#endregion

#region Service Container Functions

function Initialize-ServiceContainer {
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "ServiceContainer: Initializing new instance."
        return [ServiceContainer]::new()
    }
    catch {
        Write-Error "ServiceContainer: Failed to initialize: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Exception Handling Functions

# Module-scoped variables for exceptions
$script:ErrorHistory = [System.Collections.Generic.List[object]]::new()
$script:MaxErrorHistory = 100

# Custom exception types initialization
try {
    if (-not ('Helios.HeliosException' -as [type])) {
        Add-Type -TypeDefinition @"
        using System;
        using System.Management.Automation;
        using System.Collections;
        using System.Collections.Generic;

        namespace Helios {
            public class HeliosException : System.Management.Automation.RuntimeException {
                public Hashtable DetailedContext { get; set; }
                public string Component { get; set; }
                public DateTime Timestamp { get; set; }

                public HeliosException(string message, string component, Hashtable detailedContext, Exception innerException)
                    : base(message, innerException) {
                    this.Component = component ?? "Unknown";
                    this.DetailedContext = detailedContext ?? new Hashtable();
                    this.Timestamp = DateTime.Now;
                }
            }

            public class NavigationException : HeliosException { public NavigationException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
            public class ServiceInitializationException : HeliosException { public ServiceInitializationException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
            public class ComponentRenderException : HeliosException { public ComponentRenderException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
            public class StateMutationException : HeliosException { public StateMutationException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
            public class InputHandlingException : HeliosException { public InputHandlingException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
            public class DataLoadException : HeliosException { public DataLoadException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
        }
"@ -ErrorAction Stop
        Write-Verbose "Custom Helios exception types compiled and loaded."
    }
} catch {
    Write-Warning "CRITICAL: Failed to compile custom Helios exception types: $($_.Exception.Message). The application will lack detailed error information and custom error handling features."
}

function _Identify-HeliosComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNull()][System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    try {
        $scriptPath = $null
        if ($ErrorRecord.InvocationInfo.ScriptName) {
            $scriptPath = $ErrorRecord.InvocationInfo.ScriptName
        } else {
            $callStack = Get-PSCallStack
            foreach ($call in $callStack) {
                if ($call.ScriptName) {
                    $scriptPath = $call.ScriptName
                    break
                }
            }
        }

        if (-not $scriptPath) {
            Write-Verbose "_Identify-HeliosComponent: Could not determine script path from error record or call stack. Returning 'Interactive/Unknown'."
            return "Interactive/Unknown"
        }

        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)

        $componentMap = @{
            'tui-engine' = 'TUI Engine'; 'navigation' = 'Navigation Service'; 'keybindings' = 'Keybinding Service'
            'task-service' = 'Task Service'; 'helios-components' = 'Helios UI Components'; 'helios-panels' = 'Helios UI Panels'
            'dashboard-screen' = 'Dashboard Screen'; 'task-screen' = 'Task Screen'; 'exceptions' = 'Exception Module'
            'logger' = 'Logger Module'; 'Start-PMCTerminal' = 'Application Entry'; 'models' = 'Data Models'
            'data-manager' = 'Data Manager'; 'dialog-system' = 'Dialog System'; 'theme-manager' = 'Theme Manager'
            'ui-classes' = 'UI Base Classes'; 'tui-primitives' = 'TUI Primitives'; 'service-container' = 'Service Container'
            'action-service' = 'Action Service'; 'command-palette' = 'Command Palette'; 'panic-handler' = 'Panic Handler'
        }

        foreach ($pattern in $componentMap.Keys) {
            if ($fileName -like "*$pattern*") {
                Write-Verbose "_Identify-HeliosComponent: Identified component '$($componentMap[$pattern])' from script '$fileName'."
                return $componentMap[$pattern]
            }
        }
        
        Write-Verbose "_Identify-HeliosComponent: No specific component map found for script '$fileName'. Returning 'Unknown ($fileName)'."
        return "Unknown ($fileName)"
    } catch {
        Write-Warning "Failed to identify component for error: $($_.Exception.Message). Returning 'Component Identification Failed'."
        return "Component Identification Failed"
    }
}

function _Get-DetailedError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNull()][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [hashtable]$AdditionalContext = @{}
    )
    
    try {
        $errorInfo = [PSCustomObject]@{
            Timestamp = (Get-Date -Format "o");
            Summary = $ErrorRecord.Exception.Message;
            Type = $ErrorRecord.Exception.GetType().FullName;
            Category = $ErrorRecord.CategoryInfo.Category.ToString();
            TargetObject = $ErrorRecord.TargetObject;
            InvocationInfo = @{
                ScriptName = $ErrorRecord.InvocationInfo.ScriptName;
                LineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber;
                Line = $ErrorRecord.InvocationInfo.Line;
                PositionMessage = $ErrorRecord.InvocationInfo.PositionMessage;
                BoundParameters = $ErrorRecord.InvocationInfo.BoundParameters
            };
            StackTrace = $ErrorRecord.Exception.StackTrace;
            InnerExceptions = [System.Collections.Generic.List[object]]::new();
            AdditionalContext = $AdditionalContext;
            SystemContext = @{
                ProcessId = $PID;
                ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId;
                PowerShellVersion = $PSVersionTable.PSVersion.ToString();
                OS = $PSVersionTable.OS;
                HostName = $Host.Name;
                HostVersion = $Host.Version.ToString();
            }
        }

        $innerEx = $ErrorRecord.Exception.InnerException
        while ($innerEx) {
            [void]$errorInfo.InnerExceptions.Add([PSCustomObject]@{
                Message = $innerEx.Message;
                Type = $innerEx.GetType().FullName;
                StackTrace = $innerEx.StackTrace;
            })
            $innerEx = $innerEx.InnerException
        }
        Write-Verbose "_Get-DetailedError: Successfully processed error for logging."
        return $errorInfo
    } catch {
        Write-Warning "CRITICAL: Error analysis failed for an original error: $($_.Exception.Message). Original error was: '$($ErrorRecord.Exception.Message)'."
        return [PSCustomObject]@{
            Timestamp = (Get-Date -Format "o");
            Summary = "CRITICAL: Error analysis failed for an original error.";
            OriginalErrorMessage = $ErrorRecord.Exception.Message;
            AnalysisErrorMessage = $_.Exception.Message;
            Type = "ErrorAnalysisFailure";
            AdditionalContext = $AdditionalContext;
        }
    }
}

function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Component,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Context,
        
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [scriptblock]$ScriptBlock,
        
        [hashtable]$AdditionalData = @{}
    )

    if (-not $ScriptBlock) {
        throw [System.ArgumentNullException]::new("ScriptBlock", "Invoke-WithErrorHandling: ScriptBlock parameter cannot be null.")
    }
    $Component = [string]::IsNullOrWhiteSpace($Component) ? "Unknown Component" : $Component
    $Context = [string]::IsNullOrWhiteSpace($Context) ? "Unknown Operation" : $Context
    
    Write-Verbose "Invoke-WithErrorHandling: Entering wrapper for Component '$Component', Context '$Context'."

    try {
        return & $ScriptBlock
    }
    catch {
        $originalErrorRecord = $_
        
        $identifiedComponent = _Identify-HeliosComponent -ErrorRecord $originalErrorRecord
        $finalComponent = if ($Component -ne "Unknown Component") { $Component } else { $identifiedComponent }

        $errorContextForDetail = @{ Operation = $Context }
        foreach ($key in $AdditionalData.Keys) {
            $value = $AdditionalData[$key]
            if ($value -is [string] -or $value -is [int] -or $value -is [bool] -or $value -is [datetime] -or $value -is [enum]) {
                $errorContextForDetail[$key] = $value
            } else {
                $errorContextForDetail["Raw_$key"] = $value
            }
        }
        
        $detailedError = _Get-DetailedError -ErrorRecord $originalErrorRecord -AdditionalContext $errorContextForDetail

        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "Error in '$finalComponent' during '$Context': $($originalErrorRecord.Exception.Message)" -Data $detailedError
        } else {
            Write-Error "CRITICAL: Logger not available. Error in '$finalComponent' during '$Context': $($originalErrorRecord.Exception.Message). Full Error: $_"
        }

        [void]$script:ErrorHistory.Add($detailedError)
        if ($script:ErrorHistory.Count -gt $script:MaxErrorHistory) {
            $script:ErrorHistory.RemoveAt(0)
        }
        
        $heliosException = New-Object Helios.HeliosException(
            $originalErrorRecord.Exception.Message,
            $finalComponent,
            $errorContextForDetail,
            $originalErrorRecord.Exception
        )
        Write-Verbose "Invoke-WithErrorHandling: Re-throwing HeliosException for Component '$finalComponent', Context '$Context'."
        throw $heliosException
    }
}

function Get-ErrorHistory {
    [CmdletBinding()]
    param([int]$Count = 25)
    
    try {
        $historySnapshot = $script:ErrorHistory.ToArray()
        
        $total = $historySnapshot.Count
        if ($Count -ge $total) {
            Write-Verbose "Get-ErrorHistory: Returning all $total error entries."
            return $historySnapshot
        }
        $start = $total - $Count
        Write-Verbose "Get-ErrorHistory: Returning last $Count error entries from $total total."
        return $historySnapshot | Select-Object -Last $Count
    }
    catch {
        Write-Warning "Error getting error history: $($_.Exception.Message)"
        return @()
    }
}

#endregion

#region Theme Manager Functions

# Module-scoped variables for theme manager
$script:CurrentTheme = $null 
$script:BuiltinThemes = @{
    Modern = @{ Name="Modern"; Colors=@{ Background=[ConsoleColor]::Black; Foreground=[ConsoleColor]::White; Primary=[ConsoleColor]::White; Secondary=[ConsoleColor]::Gray; Accent=[ConsoleColor]::Cyan; Success=[ConsoleColor]::Green; Warning=[ConsoleColor]::Yellow; Error=[ConsoleColor]::Red; Info=[ConsoleColor]::Blue; Header=[ConsoleColor]::Cyan; Border=[ConsoleColor]::DarkGray; Selection=[ConsoleColor]::Yellow; Highlight=[ConsoleColor]::Cyan; Subtle=[ConsoleColor]::DarkGray; Keyword=[ConsoleColor]::Blue; String=[ConsoleColor]::Green; Number=[ConsoleColor]::Magenta; Comment=[ConsoleColor]::DarkGray } }
    Dark   = @{ Name="Dark"; Colors=@{ Background=[ConsoleColor]::Black; Foreground=[ConsoleColor]::Gray; Primary=[ConsoleColor]::Gray; Secondary=[ConsoleColor]::DarkGray; Accent=[ConsoleColor]::DarkCyan; Success=[ConsoleColor]::DarkGreen; Warning=[ConsoleColor]::DarkYellow; Error=[ConsoleColor]::DarkRed; Info=[ConsoleColor]::DarkBlue; Header=[ConsoleColor]::DarkCyan; Border=[ConsoleColor]::DarkGray; Selection=[ConsoleColor]::Yellow; Highlight=[ConsoleColor]::Cyan; Subtle=[ConsoleColor]::DarkGray; Keyword=[ConsoleColor]::DarkBlue; String=[ConsoleColor]::DarkGreen; Number=[ConsoleColor]::DarkMagenta; Comment=[ConsoleColor]::DarkGray } }
    Light  = @{ Name="Light"; Colors=@{ Background=[ConsoleColor]::White; Foreground=[ConsoleColor]::Black; Primary=[ConsoleColor]::Black; Secondary=[ConsoleColor]::DarkGray; Accent=[ConsoleColor]::Blue; Success=[ConsoleColor]::Green; Warning=[ConsoleColor]::DarkYellow; Error=[ConsoleColor]::Red; Info=[ConsoleColor]::Blue; Header=[ConsoleColor]::Blue; Border=[ConsoleColor]::Gray; Selection=[ConsoleColor]::Cyan; Highlight=[ConsoleColor]::Yellow; Subtle=[ConsoleColor]::Gray; Keyword=[ConsoleColor]::Blue; String=[ConsoleColor]::Green; Number=[ConsoleColor]::Magenta; Comment=[ConsoleColor]::Gray } }
    Retro  = @{ Name="Retro"; Colors=@{ Background=[ConsoleColor]::Black; Foreground=[ConsoleColor]::Green; Primary=[ConsoleColor]::Green; Secondary=[ConsoleColor]::DarkGreen; Accent=[ConsoleColor]::Yellow; Success=[ConsoleColor]::Green; Warning=[ConsoleColor]::Yellow; Error=[ConsoleColor]::Red; Info=[ConsoleColor]::Cyan; Header=[ConsoleColor]::Yellow; Border=[ConsoleColor]::DarkGreen; Selection=[ConsoleColor]::Yellow; Highlight=[ConsoleColor]::White; Subtle=[ConsoleColor]::DarkGreen; Keyword=[ConsoleColor]::Yellow; String=[ConsoleColor]::Cyan; Number=[ConsoleColor]::White; Comment=[ConsoleColor]::DarkGreen } }
}
$script:ExternalThemesDirectory = $null

function _Resolve-ThemeColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $ColorValue,
        
        [hashtable]$Palette = @{}
    )
    
    if ($ColorValue -is [string] -and $ColorValue.StartsWith('$')) {
        $paletteKey = $ColorValue.Substring(1)
        if ($Palette.ContainsKey($paletteKey)) {
            return $Palette[$paletteKey]
        } else {
            Write-Warning "Palette key '$paletteKey' not found in theme palette."
            return "#FF00FF"
        }
    }
    
    return $ColorValue
}

function _Test-HexColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$HexColor
    )
    
    return $HexColor -match '^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$'
}

function Initialize-ThemeManager {
    [CmdletBinding()]
    param(
        [string]$ExternalThemesDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\Themes")
    )

    try {
        $script:ExternalThemesDirectory = $ExternalThemesDirectory
        if (-not (Test-Path $script:ExternalThemesDirectory)) {
            try {
                New-Item -ItemType Directory -Path $script:ExternalThemesDirectory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "ThemeManager: Created external themes directory: $script:ExternalThemesDirectory"
            } catch {
                Write-Warning "ThemeManager: Could not create external themes directory: $($_.Exception.Message). External themes will not be available."
                $script:ExternalThemesDirectory = $null
            }
        }
        
        Set-TuiTheme -ThemeName "Modern"
        
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "Theme manager initialized." -Data @{
                ExternalThemesDirectory = $script:ExternalThemesDirectory
                BuiltinThemes = ($script:BuiltinThemes.Keys -join ', ')
            }
        }
        Write-Verbose "ThemeManager: Successfully initialized."
    } catch {
        Write-Error "ThemeManager: Failed to initialize: $($_.Exception.Message)"
        throw
    }
}

function Set-TuiTheme {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ThemeName
    )

    if ($PSCmdlet.ShouldProcess("theme '$ThemeName'", "Set active theme")) {
        try {
            $themeFound = $false
            
            if ($script:BuiltinThemes.ContainsKey($ThemeName)) {
                $script:CurrentTheme = $script:BuiltinThemes[$ThemeName]
                $themeFound = $true
                Write-Verbose "ThemeManager: Loaded builtin theme '$ThemeName'."
            }
            elseif ($script:ExternalThemesDirectory) {
                $themePath = Join-Path $script:ExternalThemesDirectory "$ThemeName.theme.json"
                if (Test-Path $themePath) {
                    try {
                        $themeContent = Get-Content $themePath -Raw | ConvertFrom-Json -AsHashtable
                        
                        if ($themeContent.ContainsKey('palette') -and $themeContent.ContainsKey('styles')) {
                            $script:CurrentTheme = @{
                                Name = $ThemeName
                                Type = 'Advanced'
                                Palette = $themeContent.palette
                                Styles = $themeContent.styles
                            }
                        } elseif ($themeContent.ContainsKey('Colors')) {
                            $script:CurrentTheme = @{
                                Name = $ThemeName
                                Type = 'Simple'
                                Colors = $themeContent.Colors
                            }
                        } else {
                            throw "Invalid theme format. Theme must contain 'Colors' or both 'palette' and 'styles' keys."
                        }
                        
                        $themeFound = $true
                        Write-Verbose "ThemeManager: Loaded external theme '$ThemeName' from '$themePath'."
                    } catch {
                        throw "Failed to load external theme '$ThemeName': $($_.Exception.Message)"
                    }
                }
            }
            
            if ($themeFound) {
                if ($script:CurrentTheme.Type -ne 'Advanced' -and $Host.UI.RawUI) {
                    $bgColor = Get-ThemeColor -ColorName 'Background' -Default ([ConsoleColor]::Black)
                    $fgColor = Get-ThemeColor -ColorName 'Foreground' -Default ([ConsoleColor]::White)
                    
                    if ($bgColor -is [ConsoleColor]) { $Host.UI.RawUI.BackgroundColor = $bgColor }
                    if ($fgColor -is [ConsoleColor]) { $Host.UI.RawUI.ForegroundColor = $fgColor }
                    Write-Verbose "ThemeManager: Applied console colors for theme '$ThemeName'."
                }
                
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Debug -Message "Theme set to: $ThemeName"
                }
                
                if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) {
                    Publish-Event -EventName "Theme.Changed" -Data @{ ThemeName = $ThemeName; Theme = $script:CurrentTheme }
                }
                Write-Verbose "ThemeManager: Theme '$ThemeName' activated and 'Theme.Changed' event published."
            } else {
                $availableThemes = Get-AvailableThemes
                if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Warning -Message "Theme not found: $ThemeName. Available themes: $($availableThemes -join ', '). Active theme remains unchanged."
                }
                Write-Verbose "ThemeManager: Theme '$ThemeName' not found."
            }
        } catch {
            Write-Error "ThemeManager: Failed to set theme '$ThemeName': $($_.Exception.Message)"
            throw
        }
    }
}

function Get-ThemeColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ColorName,
        
        $Default = [ConsoleColor]::Gray
    )
    
    try {
        if ($null -eq $script:CurrentTheme) {
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Warning -Message "No active theme set. Returning default color for '$ColorName'."
            }
            Write-Verbose "ThemeManager: No active theme, returning default color '$Default' for '$ColorName'."
            return $Default
        }
        
        if ($script:CurrentTheme.Type -eq 'Advanced') {
            $styleValue = $script:CurrentTheme.Styles.$ColorName
            if ($null -ne $styleValue) {
                $resolvedColor = _Resolve-ThemeColor -ColorValue $styleValue -Palette $script:CurrentTheme.Palette
                Write-Verbose "ThemeManager: Retrieved advanced style '$ColorName' as '$resolvedColor'."
                return $resolvedColor
            }
        } else {
            $colors = $script:CurrentTheme.Colors
            if ($colors -and $colors.ContainsKey($ColorName)) {
                $color = $colors[$ColorName]
                Write-Verbose "ThemeManager: Retrieved color '$ColorName' as '$color'."
                return $color
            }
        }
        
        Write-Verbose "ThemeManager: Color '$ColorName' not found in current theme, returning default '$Default'."
        return $Default
    } catch {
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Warning -Message "Error in Get-ThemeColor for '$ColorName'. Returning default '$Default'. Error: $($_.Exception.Message)"
        }
        Write-Verbose "ThemeManager: Failed to get color '$ColorName', returning default. Error: $($_.Exception.Message)."
        return $Default
    }
}

function Get-TuiTheme {
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "ThemeManager: Retrieving current theme."
        return $script:CurrentTheme
    } catch {
        Write-Error "ThemeManager: Failed to get current theme: $($_.Exception.Message)"
        throw
    }
}

function Get-AvailableThemes {
    [CmdletBinding()]
    param()

    try {
        $themes = [System.Collections.Generic.List[string]]::new()
        
        $themes.AddRange($script:BuiltinThemes.Keys)
        
        if ($script:ExternalThemesDirectory -and (Test-Path $script:ExternalThemesDirectory)) {
            $externalThemes = Get-ChildItem -Path $script:ExternalThemesDirectory -Filter "*.theme.json" -ErrorAction SilentlyContinue | 
                ForEach-Object { $_.BaseName -replace '\.theme$' }
            $themes.AddRange($externalThemes)
        }
        
        Write-Verbose "ThemeManager: Found $($themes.Count) available themes."
        return $themes.ToArray() | Sort-Object -Unique
    } catch {
        Write-Error "ThemeManager: Failed to get available themes: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region TUI Component Factory Functions

function New-TuiLabel {
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $labelName = $Props.Name ?? "Label_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $label = [LabelComponent]::new($labelName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($label.PSObject.Properties.Match($_.Name)) {
                $label.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created label '$labelName' with $($Props.Count) properties"
        return $label
    }
    catch {
        Write-Error "Failed to create label: $($_.Exception.Message)"
        throw
    }
}

function New-TuiButton {
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $buttonName = $Props.Name ?? "Button_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $button = [ButtonComponent]::new($buttonName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($button.PSObject.Properties.Match($_.Name)) {
                $button.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created button '$buttonName' with $($Props.Count) properties"
        return $button
    }
    catch {
        Write-Error "Failed to create button: $($_.Exception.Message)"
        throw
    }
}

function New-TuiTextBox {
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $textBoxName = $Props.Name ?? "TextBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $textBox = [TextBoxComponent]::new($textBoxName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($textBox.PSObject.Properties.Match($_.Name)) {
                $textBox.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created textbox '$textBoxName' with $($Props.Count) properties"
        return $textBox
    }
    catch {
        Write-Error "Failed to create textbox: $($_.Exception.Message)"
        throw
    }
}

function New-TuiCheckBox {
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $checkBoxName = $Props.Name ?? "CheckBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $checkBox = [CheckBoxComponent]::new($checkBoxName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($checkBox.PSObject.Properties.Match($_.Name)) {
                $checkBox.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created checkbox '$checkBoxName' with $($Props.Count) properties"
        return $checkBox
    }
    catch {
        Write-Error "Failed to create checkbox: $($_.Exception.Message)"
        throw
    }
}

function New-TuiRadioButton {
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $radioButtonName = $Props.Name ?? "RadioButton_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $radioButton = [RadioButtonComponent]::new($radioButtonName)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($radioButton.PSObject.Properties.Match($_.Name)) {
                $radioButton.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created radio button '$radioButtonName' with $($Props.Count) properties"
        return $radioButton
    }
    catch {
        Write-Error "Failed to create radio button: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Command Palette Functions

function Register-CommandPalette {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ActionService,
        [Parameter(Mandatory)]
        [object]$KeybindingService
    )

    try {
        Write-Log -Level Info -Message "Registering Command Palette"
        $palette = [CommandPalette]::new($ActionService)
        $palette.Initialize()
        $ActionService.RegisterAction("app.showCommandPalette", "Show the command palette for quick action access", { if (Get-Command 'Publish-Event' -ErrorAction SilentlyContinue) { Publish-Event -EventName "CommandPalette.Open" } }, "Application", $false)
        $KeybindingService.SetBinding("app.showCommandPalette", [System.ConsoleKey]::P, @('Ctrl'))
        Write-Log -Level Info -Message "Command Palette registered successfully with Ctrl+P keybinding"
        return $palette
    }
    catch {
        Write-Error "Failed to register Command Palette: $($_.Exception.Message)"
        throw
    }
}

#endregion