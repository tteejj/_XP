# Run Axiom-Phoenix with warning suppression as last resort
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'

try {
    # Load the safe logging wrapper
    . ".\Write-LogSafe.ps1"
    
    # Run the application
    . ".\Start.ps1"
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Gray
} finally {
    # Restore preferences
    $WarningPreference = 'Continue'
    $VerbosePreference = 'Continue'
}
