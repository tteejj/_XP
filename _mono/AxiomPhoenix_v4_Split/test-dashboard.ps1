# Test script to verify dashboard input is working

Write-Host "Testing Axiom-Phoenix Dashboard Input Fix" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Key fixes applied:" -ForegroundColor Yellow
Write-Host "1. Added keyboard reading logic to engine loop (Process-TuiInput now gets KeyInfo)" -ForegroundColor Green
Write-Host "2. Changed default theme from Green to SynthWave" -ForegroundColor Green
Write-Host ""
Write-Host "To test:" -ForegroundColor Yellow
Write-Host "1. Run: .\Start.ps1" -ForegroundColor White
Write-Host "2. The dashboard should appear with SynthWave theme (purple/pink colors)" -ForegroundColor White
Write-Host "3. Press number keys (1-7) or Q to navigate" -ForegroundColor White
Write-Host "4. Use arrow keys to move selection and Enter to activate" -ForegroundColor White
Write-Host ""
Write-Host "If input still doesn't work, check:" -ForegroundColor Yellow
Write-Host "- The debug log at: $env:TEMP\axiom-phoenix.log" -ForegroundColor White
Write-Host "- Look for 'HandleInput' entries to see if keys are being received" -ForegroundColor White
Write-Host ""
Write-Host "Press Enter to continue..." -ForegroundColor Cyan
Read-Host
