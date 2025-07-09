# Quick test script to verify CommandPalette class is now available
try {
    # Test if we can reference the CommandPalette type
    [CommandPalette] | Out-Null
    Write-Host "SUCCESS: CommandPalette type is available!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: CommandPalette type still not found: $_" -ForegroundColor Red
    exit 1
}

# Test creating an instance
try {
    $testCP = [CommandPalette]::new("Test", $null)
    Write-Host "SUCCESS: CommandPalette instance created!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to create CommandPalette instance: $_" -ForegroundColor Red
}
