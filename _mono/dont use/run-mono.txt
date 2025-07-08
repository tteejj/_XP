# Test running the actual Start.ps1
Set-Location "C:\Users\jhnhe\Documents\GitHub\_XP\_mono"

try {
    Write-Host "Running mono Start.ps1..." -ForegroundColor Cyan
    & .\Start.ps1
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}
