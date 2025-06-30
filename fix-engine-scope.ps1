# Engine Scope Fix Script
# This script updates the TUI engine to use global state

$enginePath = "C:\Users\jhnhe\Documents\GitHub\_XP\modules\tui-engine-v2.psm1"

Write-Host "Reading engine file..." -ForegroundColor Cyan
$content = Get-Content $enginePath -Raw

Write-Host "Creating backup..." -ForegroundColor Cyan
$backupPath = "$enginePath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$content | Set-Content $backupPath

Write-Host "Replacing script:TuiState with global:TuiState..." -ForegroundColor Cyan
$updatedContent = $content -replace '\$script:TuiState', '$global:TuiState'

# Count replacements
$originalCount = ([regex]::Matches($content, '\$script:TuiState')).Count
$newCount = ([regex]::Matches($updatedContent, '\$global:TuiState')).Count

Write-Host "Replaced $originalCount instances of `$script:TuiState with `$global:TuiState" -ForegroundColor Green

Write-Host "Writing updated file..." -ForegroundColor Cyan
$updatedContent | Set-Content $enginePath

Write-Host "Engine update complete!" -ForegroundColor Green
Write-Host "Backup saved to: $backupPath" -ForegroundColor Yellow
