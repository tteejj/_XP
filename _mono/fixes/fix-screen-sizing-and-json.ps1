# Fix for screen sizing and JSON serialization issues
# This script addresses:
# 1. Screens not using full console space
# 2. Dashboard menu not rendering properly
# 3. JSON truncation warnings

Write-Host "=== Fixing Axiom-Phoenix Screen Sizing and JSON Issues ===" -ForegroundColor Cyan

# Fix 1: Initialize BufferWidth and BufferHeight with actual console dimensions
Write-Host "`n1. Fixing initial buffer size in AllRuntime.ps1..." -ForegroundColor Yellow

$file = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllRuntime.ps1"
$content = Get-Content $file -Raw

# Replace the initialization to include actual console dimensions
$oldInit = @'
$global:TuiState = @{
    Running = $false
    BufferWidth = 0
    BufferHeight = 0
'@

$newInit = @'
$global:TuiState = @{
    Running = $false
    BufferWidth = [Math]::Max(80, [Console]::Window