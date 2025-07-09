# Comprehensive fix for JSON serialization depth warnings in Axiom-Phoenix
Write-Host "=== Fixing JSON Serialization Depth Warnings ===" -ForegroundColor Cyan

# First, run the Write-Log fix
Write-Host "`n1. Fixing Write-Log function..." -ForegroundColor Yellow
& "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\fix-write-log.ps1"

# Then apply additional fixes
Write-Host "`n2. Applying additional fixes..." -ForegroundColor Yellow
& "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\apply-json-fixes.ps1"

# Test the application
Write-Host "`n3. Testing the application..." -ForegroundColor Yellow
Write-Host "   Press Ctrl+C to stop if errors occur" -ForegroundColor Gray

try {
    & "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\Start.ps1"
} catch {
    Write-Host "`nError occurred: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
}

Write-Host "`nFix application complete!" -ForegroundColor Green
