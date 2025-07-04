# MODULE: exceptions.psm1
# PURPOSE: Provides custom exception types and a centralized error handling wrapper.
# This module integrates closely with the logging system to provide detailed error diagnostics.

# ------------------------------------------------------------------------------
# Module-Scoped State Variables
# ------------------------------------------------------------------------------

$script:ErrorHistory = [System.Collections.Generic.List[object]]::new() # In-memory history of detailed error records
$script:MaxErrorHistory = 100 # Maximum number of error records to keep in history

# ------------------------------------------------------------------------------
# Custom Exception Type Definition
# ------------------------------------------------------------------------------

try {
    # Check if the custom type already exists to prevent errors on re-import/re-execution
    if (-not ('Helios.HeliosException' -as [type])) {
        Add-Type -TypeDefinition @"
        using System;
        using System.Management.Automation;
        using System.Collections;
        using System.Collections.Generic; // For List<object> if needed in context

        namespace Helios {
            // Base custom exception for PMC Terminal.
            // Inherits from RuntimeException to be caught by PowerShell's error pipeline.
            public class HeliosException : System.Management.Automation.RuntimeException {
                public Hashtable DetailedContext { get; set; } // Simplified context for the exception object itself
                public string Component { get; set; }
                public DateTime Timestamp { get; set; }

                public HeliosException(string message, string component, Hashtable detailedContext, Exception innerException)
                    : base(message, innerException) {
                    this.Component = component ?? "Unknown";
                    this.DetailedContext = detailedContext ?? new Hashtable();
                    this.Timestamp = DateTime.Now;
                }
            }

            // Specific exception types for different error domains within the application.
            public class NavigationException : HeliosException { public NavigationException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
            public class ServiceInitializationException : HeliosException { public ServiceInitializationException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
            public class ComponentRenderException : HeliosException { public ComponentRenderException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
            public class StateMutationException : HeliosException { public StateMutationException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
            public class InputHandlingException : HeliosException { public InputHandlingException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
            public class DataLoadException : HeliosException { public DataLoadException(string m, string c, Hashtable ctx, Exception i) : base(m, c, ctx, i) { } }
        }
"@ -ErrorAction Stop # Use ErrorAction Stop to ensure failure is caught by the try/catch
        Write-Verbose "Custom Helios exception types compiled and loaded."
    }
} catch {
    # This is a critical failure. Application might not function correctly without custom exceptions.
    Write-Warning "CRITICAL: Failed to compile custom Helios exception types: $($_.Exception.Message). The application will lack detailed error information and custom error handling features."
}

# ------------------------------------------------------------------------------
# Private Helper Functions
# ------------------------------------------------------------------------------

# Identifies the PMC Terminal component where an error originated based on the call stack.
function _Identify-HeliosComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNull()][System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    try {
        $scriptPath = $null
        # Prioritize the script name from the immediate invocation info.
        if ($ErrorRecord.InvocationInfo.ScriptName) {
            $scriptPath = $ErrorRecord.InvocationInfo.ScriptName
        } else {
            # If not available there, search the PSCallStack for the first script with a name.
            # This is more robust for errors originating deeper in calls from interactive console or other modules.
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

        # Extract file name without extension for mapping.
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)

        # Map file names/patterns to user-friendly component names.
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
        return "Unknown ($fileName)" # Fallback if no specific mapping
    } catch {
        # Log the internal failure of component identification itself.
        Write-Warning "Failed to identify component for error: $($_.Exception.Message). Returning 'Component Identification Failed'."
        return "Component Identification Failed"
    }
}

# Gathers detailed information about an error record for logging and context.
function _Get-DetailedError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNull()][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [hashtable]$AdditionalContext = @{} # Additional context provided by the caller (e.g., operation name)
    )
    
    try {
        $errorInfo = [PSCustomObject]@{
            Timestamp = (Get-Date -Format "o"); # ISO 8601 format
            Summary = $ErrorRecord.Exception.Message;
            Type = $ErrorRecord.Exception.GetType().FullName;
            Category = $ErrorRecord.CategoryInfo.Category.ToString();
            TargetObject = $ErrorRecord.TargetObject; # Object that caused the error, if applicable
            InvocationInfo = @{ # Detailed info about where the error occurred in the script
                ScriptName = $ErrorRecord.InvocationInfo.ScriptName;
                LineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber;
                Line = $ErrorRecord.InvocationInfo.Line;
                PositionMessage = $ErrorRecord.InvocationInfo.PositionMessage;
                BoundParameters = $ErrorRecord.InvocationInfo.BoundParameters # Capture bound parameters
            };
            StackTrace = $ErrorRecord.Exception.StackTrace;
            InnerExceptions = [System.Collections.Generic.List[object]]::new(); # List to hold inner exception details
            AdditionalContext = $AdditionalContext; # Context provided by the wrapping function
            SystemContext = @{ # System-level context for diagnostics
                ProcessId = $PID;
                ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId;
                PowerShellVersion = $PSVersionTable.PSVersion.ToString();
                OS = $PSVersionTable.OS;
                HostName = $Host.Name;
                HostVersion = $Host.Version.ToString();
            }
        }

        # Recursively collect inner exception details.
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
        # If error analysis itself fails, return a simplified error object.
        Write-Warning "CRITICAL: Error analysis failed for an original error: $($_.Exception.Message). Original error was: '$($ErrorRecord.Exception.Message)'."
        return [PSCustomObject]@{
            Timestamp = (Get-Date -Format "o");
            Summary = "CRITICAL: Error analysis failed for an original error.";
            OriginalErrorMessage = $ErrorRecord.Exception.Message;
            AnalysisErrorMessage = $_.Exception.Message; # The error that occurred during analysis
            Type = "ErrorAnalysisFailure";
            AdditionalContext = $AdditionalContext;
        }
    }
}

# ------------------------------------------------------------------------------
# Public Functions
# ------------------------------------------------------------------------------

function Invoke-WithErrorHandling {
    <#
    .SYNOPSIS
    Executes a script block within a robust error handling wrapper.
    .DESCRIPTION
    This function catches any errors thrown by the provided script block,
    logs them in detail using the application's logger, stores them in an
    in-memory history, and then re-throws them as a custom HeliosException
    for structured error propagation.
    .PARAMETER Component
    A string identifying the application component (e.g., "NavigationService", "DashboardScreen")
    where the operation is taking place. This is used for error logging and context.
    .PARAMETER Context
    A string describing the specific operation or context (e.g., "Loading data", "Rendering panel")
    that is being executed. Used for error logging and user messages.
    .PARAMETER ScriptBlock
    The script block containing the code to be executed. Any errors thrown within this
    script block will be caught and processed by this wrapper.
    .PARAMETER AdditionalData
    Optional hashtable to provide additional context-specific data that should be included
    in the detailed error log. This data will be serialized by the logger.
    #>
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
        return & $ScriptBlock # Execute the provided script block
    }
    catch {
        $originalErrorRecord = $_ # Capture the raw error record
        
        # Identify the component more accurately if it wasn't explicitly provided or if it's 'Unknown'.
        $identifiedComponent = _Identify-HeliosComponent -ErrorRecord $originalErrorRecord
        $finalComponent = if ($Component -ne "Unknown Component") { $Component } else { $identifiedComponent }

        # Prepare context for detailed error.
        $errorContextForDetail = @{ Operation = $Context }
        # Merge AdditionalData into error context, prioritizing simple types for context hashtable
        foreach ($key in $AdditionalData.Keys) {
            $value = $AdditionalData[$key]
            # Prioritize primitive types for the DetailedContext of the HeliosException itself
            if ($value -is [string] -or $value -is [int] -or $value -is [bool] -or $value -is [datetime] -or $value -is [enum]) {
                $errorContextForDetail[$key] = $value
            } else {
                # For complex types, ensure they are handled by the logger's serialization.
                # The _Get-DetailedError will include this in its 'AdditionalContext' property.
                $errorContextForDetail["Raw_$key"] = $value # Prefix to differentiate from primitives in HeliosException's context
            }
        }
        
        # Get the full detailed error object for comprehensive logging.
        $detailedError = _Get-DetailedError -ErrorRecord $originalErrorRecord -AdditionalContext $errorContextForDetail

        # Log the error using the application's logger (if available).
        # Write-Log is expected to be globally available from logger.psm1
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "Error in '$finalComponent' during '$Context': $($originalErrorRecord.Exception.Message)" -Data $detailedError
        } else {
            Write-Error "CRITICAL: Logger not available. Error in '$finalComponent' during '$Context': $($originalErrorRecord.Exception.Message). Full Error: $_"
        }

        # Add the detailed error object to the in-memory error history.
        [void]$script:ErrorHistory.Add($detailedError)
        # Manage the size of the error history.
        if ($script:ErrorHistory.Count -gt $script:MaxErrorHistory) {
            $script:ErrorHistory.RemoveAt(0) # Efficiently remove oldest entry
        }
        
        # Re-throw as a custom HeliosException for structured error propagation.
        # The HeliosException itself gets a simplified context, while the full details go to the logger.
        $heliosException = New-Object Helios.HeliosException(
            $originalErrorRecord.Exception.Message,
            $finalComponent,
            $errorContextForDetail, # Pass the detailed context to the exception
            $originalErrorRecord.Exception # Pass the original exception as the inner exception
        )
        Write-Verbose "Invoke-WithErrorHandling: Re-throwing HeliosException for Component '$finalComponent', Context '$Context'."
        throw $heliosException
    }
}

function Get-ErrorHistory {
    <#
    .SYNOPSIS
    Retrieves recent entries from the in-memory error history.
    .PARAMETER Count
    The maximum number of recent error entries to retrieve. Defaults to 25.
    #>
    [CmdletBinding()]
    param(
        [int]$Count = 25
    )
    
    try {
        # Take a snapshot of the error history list before getting a range.
        $historySnapshot = $script:ErrorHistory.ToArray()
        
        $total = $historySnapshot.Count
        if ($Count -ge $total) {
            Write-Verbose "Get-ErrorHistory: Returning all $total error entries."
            return $historySnapshot
        }
        $start = $total - $Count
        Write-Verbose "Get-ErrorHistory: Returning last $Count error entries from $total total."
        return $historySnapshot | Select-Object -Last $Count # Use Select-Object -Last for simplicity and consistency
    }
    catch {
        Write-Warning "Error getting error history: $($_.Exception.Message)"
        return @() # Return empty array on error
    }
}

# Export all public functions from this module.
# Custom exception classes are defined via Add-Type and are globally available once added.
Export-ModuleMember -Function Invoke-WithErrorHandling, Get-ErrorHistory
