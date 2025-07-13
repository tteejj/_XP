# Test logging and current state

$logPath = Join-Path $env:TEMP "axiom-phoenix.log"

Write-Host "Checking log file: $logPath" -ForegroundColor Cyan

if (Test-Path $logPath) {
    Write-Host "`nLast 50 lines of log:" -ForegroundColor Yellow
    Get-Content $logPath -Tail 50
    
    Write-Host "`nLog file size: $((Get-Item $logPath).Length) bytes" -ForegroundColor Gray
    Write-Host "Last modified: $((Get-Item $logPath).LastWriteTime)" -ForegroundColor Gray
} else {
    Write-Host "Log file does not exist!" -ForegroundColor Red
}

Write-Host "`nPress any key to delete log and start fresh..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

if (Test-Path $logPath) {
    Remove-Item $logPath -Force
    Write-Host "Log file deleted." -ForegroundColor Green
}

Write-Host "`nNow run Start.ps1 to test the application with fresh logging." -ForegroundColor Cyan
