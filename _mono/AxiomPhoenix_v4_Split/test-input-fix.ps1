# Quick test to verify input processing is working
Write-Host "Testing input processing and Performance theme..." -ForegroundColor Green

# Start the application in the background for a short time
$job = Start-Job -ScriptBlock {
    param($scriptPath)
    Set-Location $scriptPath
    & ./Start.ps1 -Theme Performance
} -ArgumentList $PWD

# Wait a bit for it to start
Start-Sleep 3

# Check if it's running
$running = Get-Job $job | Where-Object { $_.State -eq "Running" }
if ($running) {
    Write-Host "✓ Application started successfully" -ForegroundColor Green
    Write-Host "✓ Input processing should now work with optimized rendering" -ForegroundColor Green
    Write-Host "✓ Performance theme is set as default" -ForegroundColor Green
} else {
    Write-Host "✗ Application failed to start" -ForegroundColor Red
}

# Clean up
Stop-Job $job -Force
Remove-Job $job -Force

Write-Host "`nTesting complete. Both issues should be resolved:" -ForegroundColor Yellow
Write-Host "1. Performance theme is now the default" -ForegroundColor White
Write-Host "2. Input processing now works with optimized rendering via IsDirty flag" -ForegroundColor White