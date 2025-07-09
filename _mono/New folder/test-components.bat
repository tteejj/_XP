@echo off
echo Testing AllComponents.ps1 syntax...
pwsh -NoProfile -ExecutionPolicy Bypass -Command "& { try { . 'C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllComponents.ps1'; Write-Host 'SUCCESS: File loaded without errors!' -ForegroundColor Green } catch { Write-Host 'ERROR: ' -NoNewline -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Yellow; Write-Host 'At: ' -NoNewline -ForegroundColor Red; Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor Gray } }"
pause
