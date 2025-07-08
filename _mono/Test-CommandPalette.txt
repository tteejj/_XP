# ==============================================================================
# Test-CommandPalette.ps1
# Quick test to verify CommandPalette is working correctly
# ==============================================================================

Write-Host "`nTesting CommandPalette functionality..." -ForegroundColor Green

# Load all required files
Write-Host "Loading framework files..." -ForegroundColor Yellow
. (Join-Path $PSScriptRoot "AllBaseClasses.ps1")
. (Join-Path $PSScriptRoot "AllModels.ps1")
. (Join-Path $PSScriptRoot "AllComponents.ps1")
. (Join-Path $PSScriptRoot "AllFunctions.ps1")
. (Join-Path $PSScriptRoot "AllServices.ps1")

Write-Host "Creating test services..." -ForegroundColor Yellow

# Create a simple action service for testing
$actionService = [ActionService]::new()

# Register some test actions
$actionService.RegisterAction("test.action1", "Test Action 1", "First test action", { 
    Write-Host "Action 1 executed!" -ForegroundColor Green 
}, "Test")

$actionService.RegisterAction("test.action2", "Test Action 2", "Second test action", { 
    Write-Host "Action 2 executed!" -ForegroundColor Green 
}, "Test")

$actionService.RegisterAction("app.exit", "Exit Application", "Close the application", { 
    Write-Host "Exit action executed!" -ForegroundColor Red 
}, "Application")

$actionService.RegisterAction("navigation.dashboard", "Go to Dashboard", "Navigate to dashboard", { 
    Write-Host "Navigate to dashboard executed!" -ForegroundColor Cyan 
}, "Navigation")

Write-Host "`nCreating CommandPalette instance..." -ForegroundColor Yellow

# Create command palette
$commandPalette = [CommandPalette]::new("TestCommandPalette", $actionService)

# Test initialization
Write-Host "`nChecking initialization:" -ForegroundColor Yellow
Write-Host "  - Width: $($commandPalette.Width)" -ForegroundColor Gray
Write-Host "  - Height: $($commandPalette.Height)" -ForegroundColor Gray
Write-Host "  - Visible: $($commandPalette.Visible)" -ForegroundColor Gray
Write-Host "  - IsOverlay: $($commandPalette.IsOverlay)" -ForegroundColor Gray

# Test refresh actions
Write-Host "`nTesting RefreshActions..." -ForegroundColor Yellow
$commandPalette.RefreshActions()
Write-Host "  - All actions count: $($commandPalette._allActions.Count)" -ForegroundColor Green

# Test filtering
Write-Host "`nTesting FilterActions..." -ForegroundColor Yellow
$commandPalette.FilterActions("")
Write-Host "  - Filtered actions (empty search): $($commandPalette._filteredActions.Count)" -ForegroundColor Green

$commandPalette.FilterActions("test")
Write-Host "  - Filtered actions (search 'test'): $($commandPalette._filteredActions.Count)" -ForegroundColor Green

$commandPalette.FilterActions("exit")
Write-Host "  - Filtered actions (search 'exit'): $($commandPalette._filteredActions.Count)" -ForegroundColor Green

# Check components
Write-Host "`nChecking child components:" -ForegroundColor Yellow
Write-Host "  - Panel created: $($null -ne $commandPalette._panel)" -ForegroundColor Gray
Write-Host "  - SearchBox created: $($null -ne $commandPalette._searchBox)" -ForegroundColor Gray
Write-Host "  - ListBox created: $($null -ne $commandPalette._listBox)" -ForegroundColor Gray

# Test action display formatting
Write-Host "`nTesting action display formatting:" -ForegroundColor Yellow
$testAction = @{
    Name = "test.action"
    Description = "Test description"
    Category = "Testing"
}
$display = $commandPalette.FormatActionDisplay($testAction)
Write-Host "  - Formatted display: '$display'" -ForegroundColor Green

Write-Host "`n✓ CommandPalette basic tests completed!" -ForegroundColor Green
Write-Host "`nNOTE: To fully test the CommandPalette:" -ForegroundColor Yellow
Write-Host "  1. Run .\Apply-CommandPaletteFix.ps1 to apply the fix" -ForegroundColor Gray
Write-Host "  2. Run .\Start.ps1 to start the application" -ForegroundColor Gray
Write-Host "  3. Press Ctrl+P to open the Command Palette" -ForegroundColor Gray
Write-Host "  4. Test typing, navigation, and Enter key" -ForegroundColor Gray
