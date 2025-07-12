# Quick Debug Script for Dashboard Input
# Run this after starting the app to verify input is working

$logFile = Join-Path $env:TEMP "axiom-phoenix.log"

Write-Host "`nChecking latest input log entries..." -ForegroundColor Cyan
Write-Host "Log file: $logFile" -ForegroundColor Gray
Write-Host ""

if (Test-Path $logFile) {
    # Get last 50 lines and filter for input-related entries
    $inputLogs = Get-Content $logFile -Tail 50 | Where-Object { 
        $_ -match "HandleInput|Process-TuiInput|Key=|Routing input|keyboard|KeyInfo"
    }
    
    if ($inputLogs) {
        Write-Host "Recent input events:" -ForegroundColor Green
        $inputLogs | ForEach-Object {
            if ($_ -match "HandleInput") {
                Write-Host $_ -ForegroundColor Yellow
            } elseif ($_ -match "Process-TuiInput") {
                Write-Host $_ -ForegroundColor Cyan
            } else {
                Write-Host $_ -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "No input events found in recent logs!" -ForegroundColor Red
        Write-Host "This indicates keyboard input is NOT being processed." -ForegroundColor Red
    }
} else {
    Write-Host "Log file not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Gray
Read-Host
