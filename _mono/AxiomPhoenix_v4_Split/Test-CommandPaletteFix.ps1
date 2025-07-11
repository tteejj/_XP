# Quick test of the fix
Clear-Host
Write-Host "TESTING COMMANDPALETTE FIX" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The bug was: EventManager was passing 1 parameter but handlers expect 2" -ForegroundColor Yellow
Write-Host "Fixed by changing:" -ForegroundColor Yellow
Write-Host "  & `$handlerData.Handler `$eventData" -ForegroundColor Red
Write-Host "To:" -ForegroundColor Yellow  
Write-Host "  & `$handlerData.Handler `$this `$eventData" -ForegroundColor Green
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Cyan
Write-Host "1. Press '4' to open Command Palette"
Write-Host "2. Select 'test.simple' action"
Write-Host "3. Press Enter"
Write-Host "4. You should see a dialog confirming execution!"
Write-Host ""
Write-Host "Press any key to start..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Clear the debug log
$debugLog = "$PSScriptRoot\debug-trace.log"
if (Test-Path $debugLog) {
    Clear-Content $debugLog
}

# Run the app
& "$PSScriptRoot\Start.ps1"
