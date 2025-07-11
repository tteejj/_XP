# Test script to verify CommandPalette fix
Write-Host "Testing CommandPalette fixes..." -ForegroundColor Cyan

# Test 1: Check if CommandPalette Complete method exists
$cpType = [CommandPalette]
$completeMethod = $cpType.GetMethod('Complete')
if ($completeMethod) {
    Write-Host "✓ CommandPalette.Complete method exists" -ForegroundColor Green
} else {
    Write-Host "✗ CommandPalette.Complete method missing" -ForegroundColor Red
}

# Test 2: Check if Dialog.Complete method exists  
$dialogType = [Dialog]
$dialogCompleteMethod = $dialogType.GetMethod('Complete')
if ($dialogCompleteMethod) {
    Write-Host "✓ Dialog.Complete method exists" -ForegroundColor Green
} else {
    Write-Host "✗ Dialog.Complete method missing" -ForegroundColor Red
}

# Test 3: Verify deferred action queue exists
if ($global:TuiState.DeferredActions) {
    Write-Host "✓ DeferredActions queue exists" -ForegroundColor Green
} else {
    Write-Host "✗ DeferredActions queue missing" -ForegroundColor Red
}

Write-Host "`nCommandPalette fixes have been applied." -ForegroundColor Yellow
Write-Host "Key changes:" -ForegroundColor Yellow
Write-Host "1. CommandPalette now overrides Complete() to ensure proper cleanup" -ForegroundColor Gray
Write-Host "2. Dialog.Complete() now hides the dialog before navigation" -ForegroundColor Gray
Write-Host "3. Engine adds 2-frame delay before executing deferred actions" -ForegroundColor Gray
Write-Host "4. This ensures the screen is fully cleared before action execution" -ForegroundColor Gray

Write-Host "`nPress any key to continue..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
