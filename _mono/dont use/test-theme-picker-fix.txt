# Test the theme picker fix
Write-Host "Testing ThemePickerScreen fix..." -ForegroundColor Green

# Load all files
$files = @(
    "AllBaseClasses.ps1",
    "AllModels.ps1", 
    "AllComponents.ps1",
    "AllScreens.ps1",
    "AllFunctions.ps1",
    "AllServices.ps1",
    "AllRuntime.ps1"
)

foreach ($file in $files) {
    Write-Host "Loading $file..." -ForegroundColor Cyan
    . (Join-Path $PSScriptRoot $file)
}

# Create a minimal test
try {
    Write-Host "`nCreating ScrollablePanel test..." -ForegroundColor Yellow
    
    # Test ScrollablePanel methods exist with correct signatures
    $panel = [ScrollablePanel]::new("TestPanel")
    
    # Check if ScrollDown method exists and accepts parameter
    $scrollDownMethod = $panel.GetType().GetMethod("ScrollDown")
    if ($scrollDownMethod) {
        $params = $scrollDownMethod.GetParameters()
        Write-Host "ScrollDown method found with $($params.Count) parameter(s)" -ForegroundColor Green
        if ($params.Count -gt 0) {
            Write-Host "  - Parameter: $($params[0].Name) (Type: $($params[0].ParameterType), Default: $($params[0].DefaultValue))" -ForegroundColor Gray
        }
    }
    
    # Check if ScrollUp method exists and accepts parameter  
    $scrollUpMethod = $panel.GetType().GetMethod("ScrollUp")
    if ($scrollUpMethod) {
        $params = $scrollUpMethod.GetParameters()
        Write-Host "ScrollUp method found with $($params.Count) parameter(s)" -ForegroundColor Green
        if ($params.Count -gt 0) {
            Write-Host "  - Parameter: $($params[0].Name) (Type: $($params[0].ParameterType), Default: $($params[0].DefaultValue))" -ForegroundColor Gray
        }
    }
    
    # Test calling methods
    Write-Host "`nTesting method calls..." -ForegroundColor Yellow
    try {
        $panel.ScrollDown(1)
        Write-Host "ScrollDown(1) - Success" -ForegroundColor Green
    } catch {
        Write-Host "ScrollDown(1) - Failed: $_" -ForegroundColor Red
    }
    
    try {
        $panel.ScrollUp(1)
        Write-Host "ScrollUp(1) - Success" -ForegroundColor Green
    } catch {
        Write-Host "ScrollUp(1) - Failed: $_" -ForegroundColor Red
    }
    
    # Test ThemeManager
    Write-Host "`nTesting ThemeManager..." -ForegroundColor Yellow
    $themeManager = [ThemeManager]::new()
    $themes = $themeManager.GetAvailableThemes()
    Write-Host "Available themes: $($themes -join ', ')" -ForegroundColor Green
    
    Write-Host "`nAll tests completed!" -ForegroundColor Green
    
} catch {
    Write-Host "Error during testing: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}
