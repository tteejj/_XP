# ==============================================================================
# Axiom-Phoenix v4.0 - All Functions (Load After Classes)
# Standalone functions for TUI operations and utilities
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: AFU.###" to find specific sections.
# Each section ends with "END_PAGE: AFU.###"
# ==============================================================================

#region Logging Functions

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Trace', 'Debug', 'Info', 'Warning', 'Error', 'Fatal')]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [object]$Data = $null
    )
    
    # Try to get logger from global state first
    $logger = $null
    try {
        if ($global:TuiState -and 
            $global:TuiState.Services -and 
            $global:TuiState.Services -is [hashtable] -and
            $global:TuiState.Services.ContainsKey('Logger')) {
            $logger = $global:TuiState.Services['Logger']
        }
    }
    catch {
        # Silently ignore any errors accessing global state
        $logger = $null
    }
    
    if ($logger) {
        # Combine message and data into a single log entry for better correlation
        $finalMessage = $Message
        if ($Data) {
            try {
                # Handle UIElement objects specially to avoid circular reference issues
                if ($Data -is [UIElement]) {
                    $finalMessage = "$Message | Data: [UIElement: Name=$($Data.Name), Type=$($Data.GetType().Name)]"
                }
                elseif ($Data -is [System.Collections.IEnumerable] -and -not ($Data -is [string])) {
                    # Handle collections
                    $count = 0
                    try { $count = @($Data).Count } catch { }
                    $finalMessage = "$Message | Data: [Collection with $count items]"
                }
                else {
                    # For other objects, try to serialize but catch any errors
                    $dataJson = $null
                    try {
                        $dataJson = $Data | ConvertTo-Json -Compress -Depth 10 -ErrorAction Stop
                    } catch {
                        # Serialization failed, use simple representation
                    }
                    
                    if ($dataJson) {
                        $finalMessage = "$Message | Data: $dataJson"
                    } else {
                        $finalMessage = "$Message | Data: $($Data.ToString())"
                    }
                }
            }
            catch {
                # If all else fails, just use type name
                $finalMessage = "$Message | Data: [Object of type $($Data.GetType().Name)]"
            }
        }
        # Logger.Log method signature is: Log([string]$message, [string]$level = "Info")
        $logger.Log($finalMessage, $Level)
    }
    else {
        # Fallback to console if logger not available
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $prefix = "[$timestamp] [$Level]"
        
        switch ($Level) {
            'Error' { Write-Host "$prefix $Message" -ForegroundColor Red }
            'Warning' { Write-Host "$prefix $Message" -ForegroundColor Yellow }
            'Info' { Write-Host "$prefix $Message" -ForegroundColor Cyan }
            'Debug' { Write-Host "$prefix $Message" -ForegroundColor Gray }
            default { Write-Host "$prefix $Message" }
        }
    }
}

#endregion
#<!-- END_PAGE: AFU.006 -->
