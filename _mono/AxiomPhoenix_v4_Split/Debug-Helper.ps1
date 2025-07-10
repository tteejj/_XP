# Debug Helper Script for Axiom-Phoenix
Write-Host "Axiom-Phoenix Debug Helper" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Set debug logging
$env:AXIOM_LOG_LEVEL = "Debug"
Write-Host "`nDebug logging enabled" -ForegroundColor Green

# Show log location
$logPath = Join-Path $env:TEMP "axiom-phoenix.log"
Write-Host "Log file: $logPath" -ForegroundColor Yellow

# Clear existing log
if (Test-Path $logPath) {
    Remove-Item $logPath -Force
    Write-Host "Cleared existing log" -ForegroundColor Gray
}

Write-Host "`nStarting Axiom-Phoenix..." -ForegroundColor Cyan
Write-Host "1. Press Ctrl+P to open Command Palette" -ForegroundColor Yellow
Write-Host "2. Select 'test.simple' action" -ForegroundColor Yellow
Write-Host "3. Press Enter" -ForegroundColor Yellow
Write-Host "4. Press Ctrl+Q to exit" -ForegroundColor Yellow
Write-Host "`nPress any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Run the app
& "$PSScriptRoot\Start.ps1"

# Show log tail
Write-Host "`n`nShowing last 50 lines of log:" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
if (Test-Path $logPath) {
    Get-Content $logPath -Tail 50 | ForEach-Object {
        if ($_ -match "\[DEBUG\s*\]") {
            Write-Host $_ -ForegroundColor Gray
        } elseif ($_ -match "\[INFO\s*\]") {
            Write-Host $_ -ForegroundColor White
        } elseif ($_ -match "\[WARNING\]") {
            Write-Host $_ -ForegroundColor Yellow
        } elseif ($_ -match "\[ERROR\s*\]") {
            Write-Host $_ -ForegroundColor Red
        } else {
            Write-Host $_
        }
    }
} else {
    Write-Host "No log file found" -ForegroundColor Red
}

Write-Host "`nFull log saved to: $logPath" -ForegroundColor Yellow
