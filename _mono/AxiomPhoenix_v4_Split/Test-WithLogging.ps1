# Test application startup and key handling

$ErrorActionPreference = 'Stop'

Write-Host "Starting Axiom-Phoenix with debugging..." -ForegroundColor Cyan

# Clear log file
$logPath = Join-Path $env:TEMP "axiom-phoenix.log"
if (Test-Path $logPath) {
    Remove-Item $logPath -Force
}

# Set verbose logging
$env:AXIOM_VERBOSE = '1'

try {
    # Start the application
    & "$PSScriptRoot\Start.ps1"
}
catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}
finally {
    # Check the log
    if (Test-Path $logPath) {
        Write-Host "`nRecent log entries:" -ForegroundColor Yellow
        Get-Content $logPath -Tail 50 | ForEach-Object {
            if ($_ -match "ERROR") {
                Write-Host $_ -ForegroundColor Red
            }
            elseif ($_ -match "WARNING") {
                Write-Host $_ -ForegroundColor Yellow
            }
            elseif ($_ -match "HandleInput|Process-TuiInput|ExecuteAction") {
                Write-Host $_ -ForegroundColor Cyan
            }
            else {
                Write-Host $_ -ForegroundColor Gray
            }
        }
    }
    
    # Reset environment
    Remove-Item env:AXIOM_VERBOSE -ErrorAction SilentlyContinue
}
