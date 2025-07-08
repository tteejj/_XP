# Test runner to check if the fixes work
Push-Location "C:\Users\jhnhe\Documents\GitHub\_XP\_mono"
try {
    Write-Host "Starting test run..." -ForegroundColor Cyan
    & .\Start.ps1
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
finally {
    Pop-Location
}
