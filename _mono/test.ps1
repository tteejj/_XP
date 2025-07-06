# Test if classes and functions load
cd "C:\Users\jhnhe\Documents\GitHub\_XP\_mono"
.\Start.ps1 -LoadOnly

# Check if critical components exist
Write-Host "`nChecking critical components:" -ForegroundColor Cyan
Write-Host "TuiBuffer class: $([TuiBuffer] -ne $null)" -ForegroundColor Yellow
Write-Host "TuiCell class: $([TuiCell] -ne $null)" -ForegroundColor Yellow
Write-Host "ServiceContainer class: $([ServiceContainer] -ne $null)" -ForegroundColor Yellow
Write-Host "Start-TuiEngine function: $(Get-Command Start-TuiEngine -ErrorAction SilentlyContinue)" -ForegroundColor Yellow
Write-Host "Initialize-TuiEngine function: $(Get-Command Initialize-TuiEngine -ErrorAction SilentlyContinue)" -ForegroundColor Yellow
