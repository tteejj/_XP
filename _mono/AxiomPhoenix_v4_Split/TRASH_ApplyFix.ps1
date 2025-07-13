# ==============================================================================
# APPLY FINAL FIX - Replace ProjectsListScreen with robust version
# ==============================================================================

$projectDir = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AxiomPhoenix_v4_Split\Screens"
$originalFile = Join-Path $projectDir "ASC.008_ProjectsListScreen.ps1"
$finalFile = Join-Path $projectDir "ASC.008_ProjectsListScreen_FINAL.ps1"
$backupFile = Join-Path $projectDir "ASC.008_ProjectsListScreen.ps1.backup"

Write-Host "Applying final fix to ProjectsListScreen..." -ForegroundColor Cyan

try {
    # Create backup
    if (Test-Path $originalFile) {
        Copy-Item $originalFile $backupFile -Force
        Write-Host "✓ Created backup: ASC.008_ProjectsListScreen.ps1.backup" -ForegroundColor Green
    }
    
    # Replace with final version
    Copy-Item $finalFile $originalFile -Force
    Write-Host "✓ Applied final fix with robust Panel creation" -ForegroundColor Green
    
    # Clean up
    Remove-Item $finalFile -Force
    Write-Host "✓ Cleanup completed" -ForegroundColor Green
    
    Write-Host "`nFIX APPLIED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "The ProjectsListScreen now has:" -ForegroundColor Yellow
    Write-Host "  • Robust Panel creation with multiple fallback methods" -ForegroundColor Gray
    Write-Host "  • Safe property setting with existence checks" -ForegroundColor Gray
    Write-Host "  • Comprehensive error handling and logging" -ForegroundColor Gray
    Write-Host "  • Full project management functionality" -ForegroundColor Gray
    Write-Host "`nYou can now test by running: .\Start.ps1" -ForegroundColor Cyan
    
} catch {
    Write-Host "✗ Error applying fix: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Manual steps:" -ForegroundColor Yellow
    Write-Host "1. Stop any running instances" -ForegroundColor Gray
    Write-Host "2. Copy ASC.008_ProjectsListScreen_FINAL.ps1 to ASC.008_ProjectsListScreen.ps1" -ForegroundColor Gray
    Write-Host "3. Restart the application" -ForegroundColor Gray
}
