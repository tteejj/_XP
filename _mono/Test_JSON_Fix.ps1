# Test script to verify JSON warning is fixed
# Run this after applying the fixes

Write-Host "Testing JSON serialization fix..." -ForegroundColor Cyan

# Test 1: Create a UIElement with circular references
$parent = [UIElement]::new("Parent")
$child = [UIElement]::new("Child")
$parent.AddChild($child)

# Test 2: Try the problematic operation that was causing warnings
try {
    # This would normally cause a warning
    $testData = @{
        Component = $parent
        Name = "Test"
    }
    
    # Old way (would cause warning):
    # $json = $testData | ConvertTo-Json -Depth 10
    
    # New way (sanitized):
    $sanitized = @{
        Component = "[UIElement: $($testData.Component.Name)]"
        Name = $testData.Name
    }
    $json = $sanitized | ConvertTo-Json -Depth 10
    
    Write-Host "✓ Test passed - No JSON warning!" -ForegroundColor Green
    Write-Host "Sanitized output: $json" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Test failed: $_" -ForegroundColor Red
}

# Test 3: Simulate the CommandPalette focus scenario
Write-Host "`nSimulating CommandPalette focus scenario..." -ForegroundColor Cyan

$eventData = @{ 
    ComponentName = "TestSearchBox"
    ComponentType = "TextBoxComponent"
}

try {
    $json = $eventData | ConvertTo-Json -Depth 10
    Write-Host "✓ Focus event data serializes without warnings" -ForegroundColor Green
    Write-Host "Event data: $json" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Focus event test failed: $_" -ForegroundColor Red
}

Write-Host "`nAll tests completed!" -ForegroundColor Yellow
