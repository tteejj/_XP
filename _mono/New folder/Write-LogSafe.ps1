# Defensive wrapper for Write-Log to prevent ANY JSON serialization issues
function Write-LogSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Trace', 'Debug', 'Info', 'Warning', 'Error', 'Fatal')]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [object]$Data = $null
    )
    
    try {
        # Never pass complex objects to Write-Log
        if ($Data -ne $null) {
            $safeData = switch ($Data.GetType().Name) {
                'String' { $Data }
                'Int32' { $Data }
                'Int64' { $Data }
                'Boolean' { $Data }
                'DateTime' { $Data.ToString() }
                default { "[Object: $($Data.GetType().Name)]" }
            }
            Write-Log -Level $Level -Message $Message -Data $safeData
        } else {
            Write-Log -Level $Level -Message $Message
        }
    } catch {
        # Fallback to console
        Write-Host "[$Level] $Message" -ForegroundColor Yellow
    }
}

# Alias for compatibility
Set-Alias -Name Write-Log-Safe -Value Write-LogSafe
