# Test if the AllComponents.ps1 file loads without syntax errors

try {
    Write-Host "Testing AllComponents.ps1..." -ForegroundColor Cyan
    . "$PSScriptRoot\AllComponents.ps1"
    Write-Host "SUCCESS: AllComponents.ps1 loaded without syntax errors!" -ForegroundColor Green
    
    # Test creating a CommandPalette to verify the fixed HandleInput method
    Write-Host "`nTesting CommandPalette class..." -ForegroundColor Cyan
    $testPalette = [CommandPalette]::new()
    Write-Host "SUCCESS: CommandPalette instantiated successfully!" -ForegroundColor Green
    
    # Test the HandleInput method with a dummy key
    $testKey = [System.ConsoleKeyInfo]::new('A', [System.ConsoleKey]::A, $false, $false, $false)
    $result = $testPalette.HandleInput($testKey)
    Write-Host "SUCCESS: HandleInput method executed (returned: $result)" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "At: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nAll tests passed!" -ForegroundColor Green
