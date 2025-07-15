#!/usr/bin/env pwsh
# Final focus system test - comprehensive debugging

Write-Host "=== AXIOM PHOENIX FOCUS SYSTEM TEST ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "This test will:" -ForegroundColor Cyan
Write-Host "1. Start the application" -ForegroundColor White
Write-Host "2. Check if services are properly initialized" -ForegroundColor White
Write-Host "3. Test Tab navigation" -ForegroundColor White
Write-Host "4. Test button Enter key handling" -ForegroundColor White
Write-Host "5. Test theme switching" -ForegroundColor White
Write-Host ""

# Clear old log
$logPath = "$PSScriptRoot/axiom-phoenix-debug.log"
if (Test-Path $logPath) {
    Remove-Item $logPath -Force
}

Write-Host "Starting application..." -ForegroundColor Green
Write-Host "INSTRUCTIONS FOR TESTING:" -ForegroundColor Yellow
Write-Host ""
Write-Host "STEP 1: Service Verification" -ForegroundColor Cyan
Write-Host "  - When app starts, press Ctrl+P (Command Palette)" -ForegroundColor White
Write-Host "  - If it opens: Services are working" -ForegroundColor White
Write-Host "  - If nothing happens: Service initialization failed" -ForegroundColor White
Write-Host ""
Write-Host "STEP 2: Focus Test" -ForegroundColor Cyan
Write-Host "  - Navigate to 'New Task' screen" -ForegroundColor White
Write-Host "  - Check if cursor is visible in title text box" -ForegroundColor White
Write-Host "  - Press Tab ONCE - should move to description box" -ForegroundColor White
Write-Host "  - Press Tab ONCE - should move to Save button" -ForegroundColor White
Write-Host "  - Press Enter on Save button - should show error about empty title" -ForegroundColor White
Write-Host ""
Write-Host "STEP 3: Theme Test" -ForegroundColor Cyan
Write-Host "  - Go to Settings -> Themes" -ForegroundColor White
Write-Host "  - Switch to different theme" -ForegroundColor White
Write-Host "  - Navigate to different screens" -ForegroundColor White
Write-Host "  - Verify all screens update colors immediately" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to start the application..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Start the application
try {
    & "$PSScriptRoot/Start.ps1"
} catch {
    Write-Host "Error starting application: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== POST-TEST LOG ANALYSIS ===" -ForegroundColor Yellow

if (Test-Path $logPath) {
    Write-Host "Checking debug log for key issues..." -ForegroundColor Cyan
    
    # Check for service issues
    $serviceErrors = Select-String -Path $logPath -Pattern "KeybindingService is NULL|ActionService not found" -Quiet
    if ($serviceErrors) {
        Write-Host "❌ SERVICE ISSUE DETECTED" -ForegroundColor Red
        Write-Host "KeybindingService or ActionService not properly initialized" -ForegroundColor Red
    } else {
        Write-Host "✅ Services appear to be working" -ForegroundColor Green
    }
    
    # Check for focus issues
    $focusLogs = Select-String -Path $logPath -Pattern "navigation\.nextComponent" -AllMatches
    if ($focusLogs.Count -gt 0) {
        Write-Host "✅ Tab navigation is being processed ($($focusLogs.Count) times)" -ForegroundColor Green
    } else {
        Write-Host "❌ FOCUS ISSUE: No Tab navigation detected in logs" -ForegroundColor Red
    }
    
    # Check for button issues
    $buttonLogs = Select-String -Path $logPath -Pattern "Button.*Processing Enter/Space key" -AllMatches
    if ($buttonLogs.Count -gt 0) {
        Write-Host "✅ Button Enter key handling is working ($($buttonLogs.Count) times)" -ForegroundColor Green
    } else {
        Write-Host "❌ BUTTON ISSUE: No button Enter key processing detected" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Check $logPath for detailed logs" -ForegroundColor Yellow
} else {
    Write-Host "❌ No debug log found - logging may not be working" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test completed." -ForegroundColor Green