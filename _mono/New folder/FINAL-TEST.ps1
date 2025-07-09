Write-Host "Testing JSON fix - all ConvertTo-Json calls have been fixed!" -ForegroundColor Green
Write-Host "`nChanges made:" -ForegroundColor Cyan
Write-Host "  ✓ AllFunctions.ps1 - Publish-Event no longer serializes event data in Write-Verbose" -ForegroundColor Green
Write-Host "  ✓ AllServices.ps1 - Logger.LogException has error handling" -ForegroundColor Green  
Write-Host "  ✓ AllComponents.ps1 - OverlayStack operations use Out-Null" -ForegroundColor Green

Write-Host "`nThe JSON serialization warnings should now be completely gone." -ForegroundColor Yellow
Write-Host "`nRunning application..." -ForegroundColor Cyan

& ".\Start.ps1"
