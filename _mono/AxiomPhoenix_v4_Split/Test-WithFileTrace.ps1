# Run app with file-based debug tracing
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Clear any existing debug log
$debugLog = "$PSScriptRoot\debug-trace.log"
if (Test-Path $debugLog) {
    Remove-Item $debugLog -Force
}

# Create initial log entry
Add-Content -Path $debugLog -Value "=== COMMANDPALETTE DEBUG TRACE - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
Add-Content -Path $debugLog -Value ""

Clear-Host
Write-Host "CommandPalette Execution Debugger" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Debug output will be written to: " -NoNewline
Write-Host "debug-trace.log" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1: Run this script in one window, then open another PowerShell window and run:" -ForegroundColor Green
Write-Host "  .\Watch-DebugLog.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 2: Just run this script and check debug-trace.log after" -ForegroundColor Green
Write-Host ""
Write-Host "Test Instructions:" -ForegroundColor Cyan
Write-Host "1. The app will start and clear the screen"
Write-Host "2. Press '4' to open Command Palette"
Write-Host "3. Select 'test.simple' action (or any action)"
Write-Host "4. Press Enter to execute it"
Write-Host "5. Press Ctrl+Q to exit the app"
Write-Host ""
Write-Host "Expected debug trace flow:" -ForegroundColor Gray
Write-Host "  - Setting up DeferredActions queue..."
Write-Host "  - DeferredAction handler registered!"
Write-Host "  - CommandPalette calling Complete()..."
Write-Host "  - Dialog.Complete called..."
Write-Host "  - CommandPalette OnClose called!"
Write-Host "  - Publishing DeferredAction event..."
Write-Host "  - DeferredAction received..."
Write-Host "  - Processing deferred action..."
Write-Host "  - Executing action..."
Write-Host ""
Write-Host "Press any key to start the app..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Run the app
& .\Start.ps1

# After app exits, show the log
Write-Host ""
Write-Host "=== DEBUG TRACE LOG ===" -ForegroundColor Cyan
if (Test-Path $debugLog) {
    Get-Content $debugLog | ForEach-Object {
        if ($_ -match "ERROR|WARNING") {
            Write-Host $_ -ForegroundColor Red
        } elseif ($_ -match "OnClose|Complete|DeferredAction") {
            Write-Host $_ -ForegroundColor Yellow
        } else {
            Write-Host $_
        }
    }
} else {
    Write-Host "No debug log found!" -ForegroundColor Red
}
