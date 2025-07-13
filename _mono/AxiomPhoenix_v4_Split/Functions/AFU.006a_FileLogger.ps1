# AFU.006a_FileLogger.ps1 - File-based logging to replace console output

# Global variable to store the log file path
$global:AxiomPhoenixLogFile = Join-Path ([System.IO.Path]::GetDirectoryName($PSCommandPath)) "..\axiom-phoenix-debug.log"

# Initialize the log file
if (-not (Test-Path $global:AxiomPhoenixLogFile)) {
    $null = New-Item -Path $global:AxiomPhoenixLogFile -ItemType File -Force
}

# Clear log file at startup (optional - comment out to append)
Clear-Content -Path $global:AxiomPhoenixLogFile -Force -ErrorAction SilentlyContinue

function Write-FileLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "VERBOSE", "HOST")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory=$false)]
        [string]$Component = "",
        
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $callStack = (Get-PSCallStack)[1]
        $caller = if ($callStack.Command -ne '<ScriptBlock>') { 
            $callStack.Command 
        } else { 
            "Line $($callStack.ScriptLineNumber)" 
        }
        
        # Format the log entry
        $logEntry = "[$timestamp] [$Level] [$caller]"
        if ($Component) {
            $logEntry += " [$Component]"
        }
        $logEntry += " $Message"
        
        # Add error details if provided
        if ($ErrorRecord) {
            $logEntry += "`n    Exception: $($ErrorRecord.Exception.Message)"
            $logEntry += "`n    Category: $($ErrorRecord.CategoryInfo.Category)"
            $logEntry += "`n    Target: $($ErrorRecord.TargetObject)"
            $logEntry += "`n    Stack: $($ErrorRecord.ScriptStackTrace -replace "`n", "`n           ")"
        }
        
        # Write to log file
        Add-Content -Path $global:AxiomPhoenixLogFile -Value $logEntry -Encoding UTF8
        
    } catch {
        # If logging fails, at least try to capture it somewhere
        $emergencyLog = Join-Path $env:TEMP "axiom-phoenix-emergency.log"
        Add-Content -Path $emergencyLog -Value "[$timestamp] LOGGING ERROR: $_" -ErrorAction SilentlyContinue
    }
}

# Redirect Write-Host
function global:Write-Host {
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [System.Object]$Object,
        [ConsoleColor]$ForegroundColor,
        [ConsoleColor]$BackgroundColor,
        [switch]$NoNewline
    )
    
    $message = if ($Object) { $Object.ToString() } else { "" }
    Write-FileLog -Message $message -Level "HOST"
}

# Redirect Write-Warning
function global:Write-Warning {
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Message
    )
    
    Write-FileLog -Message $Message -Level "WARNING"
}

# Redirect Write-Error
function global:Write-Error {
    param(
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [System.Object]$InputObject,
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Message,
        [System.Exception]$Exception,
        [string]$Category,
        [string]$ErrorId,
        [System.Object]$TargetObject,
        [string]$RecommendedAction,
        [string]$CategoryActivity,
        [string]$CategoryReason,
        [string]$CategoryTargetName,
        [string]$CategoryTargetType
    )
    
    if ($ErrorRecord) {
        Write-FileLog -Message "Error occurred" -Level "ERROR" -ErrorRecord $ErrorRecord
    } elseif ($Exception) {
        Write-FileLog -Message $Exception.Message -Level "ERROR"
    } elseif ($Message) {
        Write-FileLog -Message $Message -Level "ERROR"
    } elseif ($InputObject) {
        Write-FileLog -Message $InputObject.ToString() -Level "ERROR"
    }
}

# Redirect Write-Verbose
function global:Write-Verbose {
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Message
    )
    
    Write-FileLog -Message $Message -Level "VERBOSE"
}

# Redirect Write-Debug
function global:Write-Debug {
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Message
    )
    
    Write-FileLog -Message $Message -Level "DEBUG"
}

# Enhanced Write-Log function that uses file logging
function global:Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info", "Warning", "Error", "Debug", "Verbose")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory=$false)]
        [string]$Component = ""
    )
    
    # Map old level names to new ones
    $levelMap = @{
        "Info" = "INFO"
        "Warning" = "WARNING"
        "Error" = "ERROR"
        "Debug" = "DEBUG"
        "Verbose" = "VERBOSE"
    }
    
    Write-FileLog -Message $Message -Level $levelMap[$Level] -Component $Component
}

# Function to get current log file path
function Get-AxiomPhoenixLogPath {
    return $global:AxiomPhoenixLogFile
}

# Function to view recent log entries
function Get-AxiomPhoenixLog {
    param(
        [int]$Last = 50
    )
    
    if (Test-Path $global:AxiomPhoenixLogFile) {
        Get-Content -Path $global:AxiomPhoenixLogFile -Tail $Last
    } else {
        Write-FileLog -Message "Log file not found at: $global:AxiomPhoenixLogFile" -Level "WARNING"
    }
}

# Function to clear the log
function Clear-AxiomPhoenixLog {
    if (Test-Path $global:AxiomPhoenixLogFile) {
        Clear-Content -Path $global:AxiomPhoenixLogFile -Force
        Write-FileLog -Message "Log file cleared" -Level "INFO"
    }
}

# Log that file logger is initialized
Write-FileLog -Message "Axiom Phoenix File Logger initialized. Log file: $global:AxiomPhoenixLogFile" -Level "INFO"
