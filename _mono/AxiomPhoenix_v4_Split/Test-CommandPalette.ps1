# ==============================================================================
# CommandPalette Test Instructions
# ==============================================================================

Write-Host @"
CommandPalette Action Execution Test
===================================

This test verifies that the CommandPalette can execute actions correctly.

SETUP:
"@ -ForegroundColor Cyan

# Enable debug logging
$env:AXIOM_LOG_LEVEL = "Debug"
Write-Host "✓ Debug logging enabled" -ForegroundColor Green

# Show where to find logs
$logPath = Join-Path $env:TEMP "axiom-phoenix.log"
Write-Host "✓ Log file: $logPath" -ForegroundColor Green

Write-Host @"

TEST STEPS:
1. Run Start.ps1 to launch the application
2. Press Ctrl+P (or select option 4) to open Command Palette
3. Type 'test' to filter for test actions
4. Use arrow keys to select 'test.simple'
5. Press Enter

EXPECTED RESULT:
- The action should execute
- The dashboard should refresh (new instance)
- Check the log file for these messages:
  * "CommandPalette: Enter key pressed"
  * "CommandPalette: Selected action: test.simple"
  * "Dialog.Complete called"
  * "Engine: DeferredAction event received"
  * "TEST ACTION EXECUTED"

TROUBLESHOOTING:
- If Enter doesn't work, check if:
  * The listbox has focus (should be highlighted)
  * An item is selected (should be highlighted differently)
- Tail the log file in another window:
  Get-Content "$logPath" -Wait -Tail 20

"@ -ForegroundColor White

Write-Host "Press any key to open the log file location..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Open log folder
Start-Process explorer.exe -ArgumentList "/select,`"$logPath`""

Write-Host "`nNow run Start.ps1 to begin the test." -ForegroundColor Green
