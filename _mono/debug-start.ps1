# Debug startup script
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

Write-Host "Starting in debug mode..." -ForegroundColor Yellow

try {
    & "$PSScriptRoot\Start.ps1"
} catch {
    Write-Host "`nDetailed error information:" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nException:" -ForegroundColor Yellow
    Write-Host $_.Exception -ForegroundColor Gray
    Write-Host "`nStack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    Write-Host "`nInvocation Info:" -ForegroundColor Yellow
    Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor Gray
    
    # Keep console open
    Write-Host "`nPress any key to exit..." -ForegroundColor White
    [Console]::ReadKey($true) | Out-Null
}
