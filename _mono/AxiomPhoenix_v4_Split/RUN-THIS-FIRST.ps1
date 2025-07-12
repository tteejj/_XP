Clear-Host
Write-Host @"
 █████╗ ██╗  ██╗██╗ ██████╗ ███╗   ███╗      ██████╗ ██╗  ██╗ ██████╗ ███████╗███╗   ██╗██╗██╗  ██╗
██╔══██╗╚██╗██╔╝██║██╔═══██╗████╗ ████║      ██╔══██╗██║  ██║██╔═══██╗██╔════╝████╗  ██║██║╚██╗██╔╝
███████║ ╚███╔╝ ██║██║   ██║██╔████╔██║█████╗██████╔╝███████║██║   ██║█████╗  ██╔██╗ ██║██║ ╚███╔╝ 
██╔══██║ ██╔██╗ ██║██║   ██║██║╚██╔╝██║╚════╝██╔═══╝ ██╔══██║██║   ██║██╔══╝  ██║╚██╗██║██║ ██╔██╗ 
██║  ██║██╔╝ ██╗██║╚██████╔╝██║ ╚═╝ ██║      ██║     ██║  ██║╚██████╔╝███████╗██║ ╚████║██║██╔╝ ██╗
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝      ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝
                                    INPUT FIX COMPLETE                                                
"@ -ForegroundColor Red

Write-Host "`nI'VE FIXED THE FOLLOWING ISSUES:" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow

Write-Host "`n✓ MISSING SERVICE FILE" -ForegroundColor Green
Write-Host "  - Restored FocusManager.ps1 from backup" -ForegroundColor White

Write-Host "`n✓ THEME NAME MISMATCH" -ForegroundColor Green
Write-Host "  - Fixed 'SynthWave' → 'Synthwave' (case sensitive)" -ForegroundColor White

Write-Host "`n✓ ENGINE NOT READING KEYBOARD" -ForegroundColor Green
Write-Host "  - Added Console.KeyAvailable check" -ForegroundColor White
Write-Host "  - Added Console.ReadKey call with KeyInfo parameter" -ForegroundColor White

Write-Host "`n✓ DUPLICATE SERVICE FILES" -ForegroundColor Green
Write-Host "  - Renamed duplicate ThemeManager to .duplicate" -ForegroundColor White

Write-Host "`n`nTO TEST IF IT WORKS:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

Write-Host "`n1. RUN THE APP:" -ForegroundColor Yellow
Write-Host "   .\Start.ps1" -ForegroundColor White -BackgroundColor DarkGray

Write-Host "`n2. YOU SHOULD SEE:" -ForegroundColor Yellow
Write-Host "   • Synthwave theme (purple/pink colors)" -ForegroundColor Magenta
Write-Host "   • NOT green theme" -ForegroundColor Gray

Write-Host "`n3. TEST THESE INPUTS:" -ForegroundColor Yellow
Write-Host "   • Press 1-7 to navigate" -ForegroundColor White
Write-Host "   • Press Q to quit" -ForegroundColor White
Write-Host "   • Use ↑↓ arrows to move selection" -ForegroundColor White
Write-Host "   • Press Enter to activate selection" -ForegroundColor White

Write-Host "`n4. IF INPUT STILL DOESN'T WORK:" -ForegroundColor Red
Write-Host "   a) Run: .\verify-fixes.ps1" -ForegroundColor White
Write-Host "      (checks if all fixes are in place)" -ForegroundColor Gray
Write-Host "`n   b) Run: .\test-console-input.ps1" -ForegroundColor White
Write-Host "      (tests if PowerShell can read keys at all)" -ForegroundColor Gray
Write-Host "`n   c) Run: .\check-input-flow.ps1" -ForegroundColor White
Write-Host "      (shows where input chain breaks)" -ForegroundColor Gray

Write-Host "`n`nPRESS ENTER TO RUN THE APP NOW..." -ForegroundColor Yellow -BackgroundColor DarkRed
Read-Host

# Clear the log first
$logFile = Join-Path $env:TEMP "axiom-phoenix.log"
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}

# Run the app
& "$PSScriptRoot\Start.ps1"
