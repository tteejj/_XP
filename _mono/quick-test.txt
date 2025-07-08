# Quick test to see if the application starts without errors
Write-Host "Testing if Axiom-Phoenix v4.0 starts correctly..." -ForegroundColor Cyan

try {
    # Try to load just the first few files to check for syntax errors
    . ".\AllBaseClasses.ps1"
    Write-Host "✓ AllBaseClasses.ps1 loaded" -ForegroundColor Green
    
    . ".\AllModels.ps1"
    Write-Host "✓ AllModels.ps1 loaded" -ForegroundColor Green
    
    . ".\AllComponents.ps1"
    Write-Host "✓ AllComponents.ps1 loaded" -ForegroundColor Green
    
    Write-Host "`nAll critical files loaded successfully!" -ForegroundColor Green
    Write-Host "The stability fixes appear to be working." -ForegroundColor Green
    Write-Host "`nYou can now run: .\Start.ps1" -ForegroundColor Cyan
}
catch {
    Write-Host "✗ Error loading files:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host "`nThere may still be issues to fix." -ForegroundColor Red
}
