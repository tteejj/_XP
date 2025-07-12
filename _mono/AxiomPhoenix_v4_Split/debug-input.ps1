# Axiom-Phoenix Input Debug Script
# ================================

Clear-Host
Write-Host "AXIOM-PHOENIX INPUT DEBUGGING" -ForegroundColor Red
Write-Host "=============================" -ForegroundColor Red
Write-Host ""

Write-Host "FIXES APPLIED:" -ForegroundColor Yellow
Write-Host "1. Fixed theme name case: 'SynthWave' -> 'Synthwave'" -ForegroundColor Green
Write-Host "2. Added extensive debug logging to track input flow" -ForegroundColor Green
Write-Host "3. Fixed syntax error in Start-AxiomPhoenix function" -ForegroundColor Green
Write-Host ""

Write-Host "TO TEST:" -ForegroundColor Cyan
Write-Host "1. Run: .\Start.ps1" -ForegroundColor White
Write-Host "2. Try pressing any key (1, 2, 3, Q, arrows, etc.)" -ForegroundColor White
Write-Host "3. Watch the log file for debug output" -ForegroundColor White
Write-Host ""

Write-Host "THEN CHECK THE LOG:" -ForegroundColor Yellow
Write-Host "Run: .\check-input-flow.ps1" -ForegroundColor White
Write-Host ""

Write-Host "The log should show:" -ForegroundColor Cyan
Write-Host "1. Engine: Read key - Key=D1, Char='1'..." -ForegroundColor Gray
Write-Host "2. Engine: CurrentScreen=DashboardScreen" -ForegroundColor Gray
Write-Host "3. Process-TuiInput: Key=D1..." -ForegroundColor Gray
Write-Host "4. Routing input to current screen: DashboardScreen" -ForegroundColor Gray
Write-Host "5. DashboardScreen.HandleInput: START..." -ForegroundColor Gray
Write-Host ""

Write-Host "If any of these are missing, we know where the chain breaks." -ForegroundColor Red
Write-Host ""
Write-Host "Press Enter to continue..." -ForegroundColor Yellow
Read-Host

# Create the log checker script
$checkerScript = @'
# Check Input Flow in Log
$logFile = Join-Path $env:TEMP "axiom-phoenix.log"

Write-Host "`nChecking input flow in log..." -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

if (Test-Path $logFile) {
    # Get last 100 lines
    $lines = Get-Content $logFile -Tail 100
    
    # Check for each step in the input chain
    $foundEngine = $lines | Where-Object { $_ -match "Engine: Read key" } | Select-Object -Last 5
    $foundCurrentScreen = $lines | Where-Object { $_ -match "Engine: CurrentScreen=" } | Select-Object -Last 5
    $foundProcessInput = $lines | Where-Object { $_ -match "Process-TuiInput:" } | Select-Object -Last 5
    $foundRouting = $lines | Where-Object { $_ -match "Routing input to current screen:" } | Select-Object -Last 5
    $foundHandleInput = $lines | Where-Object { $_ -match "DashboardScreen.HandleInput: START" } | Select-Object -Last 5
    $foundNavigation = $lines | Where-Object { $_ -match "NavigationService: Setting CurrentScreen" } | Select-Object -Last 5
    
    Write-Host "`n1. ENGINE KEY READING:" -ForegroundColor Yellow
    if ($foundEngine) {
        $foundEngine | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
    } else {
        Write-Host "   NOT FOUND - Engine is not reading keys!" -ForegroundColor Red
    }
    
    Write-Host "`n2. CURRENT SCREEN CHECK:" -ForegroundColor Yellow
    if ($foundCurrentScreen) {
        $foundCurrentScreen | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
    } else {
        Write-Host "   NOT FOUND - CurrentScreen might not be set!" -ForegroundColor Red
    }
    
    Write-Host "`n3. PROCESS-TUIINPUT CALLED:" -ForegroundColor Yellow
    if ($foundProcessInput) {
        $foundProcessInput | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
    } else {
        Write-Host "   NOT FOUND - Process-TuiInput not being called!" -ForegroundColor Red
    }
    
    Write-Host "`n4. INPUT ROUTING:" -ForegroundColor Yellow
    if ($foundRouting) {
        $foundRouting | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
    } else {
        Write-Host "   NOT FOUND - Input not being routed to screen!" -ForegroundColor Red
    }
    
    Write-Host "`n5. SCREEN HANDLEINPUT:" -ForegroundColor Yellow
    if ($foundHandleInput) {
        $foundHandleInput | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
    } else {
        Write-Host "   NOT FOUND - Screen HandleInput not being called!" -ForegroundColor Red
    }
    
    Write-Host "`n6. NAVIGATION SERVICE:" -ForegroundColor Yellow
    if ($foundNavigation) {
        $foundNavigation | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
    } else {
        Write-Host "   NOT FOUND - NavigationService might not be setting CurrentScreen!" -ForegroundColor Red
    }
} else {
    Write-Host "Log file not found at: $logFile" -ForegroundColor Red
}

Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
Read-Host
'@

Set-Content -Path "$PSScriptRoot\check-input-flow.ps1" -Value $checkerScript -Force
Write-Host "Created: check-input-flow.ps1" -ForegroundColor Green
