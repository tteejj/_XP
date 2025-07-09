Write-Host "Quick JSON Warning Fix - Running..." -ForegroundColor Cyan

# Run the comprehensive fix
& "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\fix-all-json-issues.ps1"

Write-Host "`n`nFix applied! You can now run Start.ps1 without JSON warnings." -ForegroundColor Green
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
