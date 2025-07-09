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
        # Build message without JSON serialization to avoid circular reference warnings
        $finalMessage = $Message
        if ($Data) {
            try {
                # Handle different data types safely without JSON serialization
                if ($Data -is [UIElement]) {
                    # UIElement objects have circular references, so just log basic info
                    $finalMessage = "$Message | Data: [UIElement: Name=$($Data.Name), Type=$($Data.GetType().Name), Visible=$($Data.Visible)]"
                }
                elseif ($Data -is [System.Management.Automation.ErrorRecord]) {
                    # Error records need special handling
                    $finalMessage = "$Message | Error: $($Data.Exception.Message) at $($Data.InvocationInfo.PositionMessage)"
                }
                elseif ($Data -is [System.Collections.IEnumerable] -and -not ($Data -is [string])) {
                    # Handle collections without serialization
                    $count = 0
                    try { $count = @($Data).Count } catch { }
                    $itemTypes = @()
                    foreach ($item in $Data | Select-Object -First 3) {
                        $itemTypes += $item.GetType().Name
                    }
                    $typeInfo = if ($itemTypes.Count -gt 0) { " (Types: $($itemTypes -join ', ')...)" } else { "" }
                    $finalMessage = "$Message | Data: [Collection with $count items$typeInfo]"
                }
                elseif ($Data -is [hashtable]) {
                    # Handle hashtables specially
                    $keys = @($Data.Keys) | Select-Object -First 5
                    $keyList = if ($keys.Count -gt 0) { " (Keys: $($keys -join ', ')...)" } else { "" }
                    $finalMessage = "$Message | Data: [Hashtable with $($Data.Count) entries$keyList]"
                }
                elseif ($Data -is [PSCustomObject] -or $Data.GetType().IsClass) {
                    # For complex objects, list properties instead of serializing
                    $props = @()
                    foreach ($prop in $Data.PSObject.Properties | Select-Object -First 5) {
                        try {
                            $value = $prop.Value
                            if ($value -is [UIElement] -or $value -is [System.Collections.IEnumerable]) {
                                $props += "$($prop.Name)=[Complex]"
                            } else {
                                $props += "$($prop.Name)=$($value -replace '\s+', ' ')"
                            }
                        } catch {
                            $props += "$($prop.Name)=[Error]"
                        }
                    }
                    $propInfo = if ($props.Count -gt 0) { " {$($props -join ', ')...}" } else { "" }
                    $finalMessage = "$Message | Data: [$($Data.GetType().Name)$propInfo]"
                }
                elseif ($Data -is [string] -or $Data -is [int] -or $Data -is [double] -or $Data -is [bool]) {
                    # Simple types can be converted directly
                    $finalMessage = "$Message | Data: $Data"
                }
                else {
                    # Fallback for unknown types
                    $finalMessage = "$Message | Data: [$($Data.GetType().Name): $($Data.ToString())]"
                }
            }
            catch {
                # If all else fails, just log the type
                $typeName = "Unknown"
                try { $typeName = $Data.GetType().Name } catch { }
                $finalMessage = "$Message | Data: [Object of type $typeName]"
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
            'Trace' { Write-Host "$prefix $Message" -ForegroundColor DarkGray }
            'Fatal' { Write-Host "$prefix $Message" -ForegroundColor DarkRed }
            default { Write-Host "$prefix $Message" }
        }
    }
}
