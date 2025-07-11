# CommandPalette Integration Test
# This script tests the CommandPalette fixes in a controlled manner

param(
    [switch]$AutoTest
)

Write-Host "`n===== CommandPalette Fix Test =====" -ForegroundColor Cyan
Write-Host "This test will verify that the CommandPalette:" -ForegroundColor Yellow
Write-Host "1. Opens without issues" -ForegroundColor Gray
Write-Host "2. Allows action selection" -ForegroundColor Gray
Write-Host "3. Closes cleanly without visual artifacts" -ForegroundColor Gray
Write-Host "4. Executes the selected action properly" -ForegroundColor Gray
Write-Host "5. Returns input control to the main screen" -ForegroundColor Gray

Write-Host "`nPress any key to start the test..." -ForegroundColor Green
if (-not $AutoTest) {
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

try {
    # Load the framework
    Write-Host "`nLoading Axiom-Phoenix..." -ForegroundColor Cyan
    . "$PSScriptRoot\Start.ps1" -Debug
    
    Write-Host "`nFramework loaded. Testing sequence:" -ForegroundColor Green
    Write-Host "1. Press Ctrl+P to open CommandPalette" -ForegroundColor Yellow
    Write-Host "2. Use arrows to select 'Go to Task List'" -ForegroundColor Yellow
    Write-Host "3. Press Enter to execute" -ForegroundColor Yellow
    Write-Host "4. Verify no visual artifacts appear" -ForegroundColor Yellow
    Write-Host "5. Press 'q' to exit when done testing" -ForegroundColor Yellow
    
    Write-Host "`nStarting application..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    
} catch {
    Write-Host "`nTest failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}
