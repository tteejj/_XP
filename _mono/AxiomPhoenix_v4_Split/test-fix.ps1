# Test script to verify the DashboardScreen fix
# This will try to load the classes and create a minimal test

try {
    Write-Host "Testing DashboardScreen fix..." -ForegroundColor Green
    
    # Load required base classes first
    . "$PSScriptRoot\Base\ABA.001_UIElement.ps1"
    . "$PSScriptRoot\Base\ABA.002_Component.ps1" 
    . "$PSScriptRoot\Base\ABA.003_Screen.ps1"
    
    # Load components
    . "$PSScriptRoot\Components\ACO.001_LabelComponent.ps1"
    . "$PSScriptRoot\Components\ACO.011_Panel.ps1"
    
    # Load functions
    . "$PSScriptRoot\Functions\Get-ThemeColor.ps1"
    . "$PSScriptRoot\Functions\Write-Log.ps1"
    
    Write-Host "Base classes loaded successfully" -ForegroundColor Green
    
    # Try to load the DashboardScreen
    . "$PSScriptRoot\Screens\ASC.001_DashboardScreen.ps1"
    
    Write-Host "DashboardScreen loaded successfully" -ForegroundColor Green
    
    # Try to create a mock service container
    $mockServices = @{}
    
    # Try to create the DashboardScreen instance
    $dashboard = [DashboardScreen]::new($mockServices)
    
    Write-Host "DashboardScreen instance created successfully" -ForegroundColor Green
    
    Write-Host "✅ FIX VERIFIED: No ambiguous property errors!" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    exit 1
}
