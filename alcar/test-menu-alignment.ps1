#!/usr/bin/env pwsh
# Visual test for menu alignment

# Direct test of menu rendering
. "$PSScriptRoot/Core/vt100.ps1"
. "$PSScriptRoot/Base/Screen.ps1"
. "$PSScriptRoot/Screens/MainMenuScreen.ps1"

# Create a test screen
$menu = [MainMenuScreen]::new()

# Simulate different window sizes
$sizes = @(
    @{Width=80; Height=25; Name="Standard"},
    @{Width=120; Height=30; Name="Large"},
    @{Width=60; Height=20; Name="Small"}
)

foreach ($size in $sizes) {
    Write-Host "`nTesting $($size.Name) size ($($size.Width)x$($size.Height)):" -ForegroundColor Cyan
    
    # Mock console size
    $originalWidth = [Console]::WindowWidth
    $originalHeight = [Console]::WindowHeight
    
    try {
        # This won't actually resize the console, but will test the calculations
        [Console]::SetWindowSize($size.Width, $size.Height)
        
        # Test render without actually displaying
        $output = $menu.RenderContent()
        
        # Check for proper alignment markers
        $lines = $output -split "`e\["
        $boxCount = ($lines | Where-Object { $_ -match "┌" }).Count
        
        Write-Host "  - Box elements found: $boxCount" -ForegroundColor $(if ($boxCount -gt 0) { "Green" } else { "Red" })
        Write-Host "  - Content length: $($output.Length) chars" -ForegroundColor Gray
        
    } catch {
        Write-Host "  - Error: $_" -ForegroundColor Red
    }
}

Write-Host "`nAlignment test complete." -ForegroundColor Green
Write-Host "Run ./bolt.ps1 to see the actual rendering." -ForegroundColor Yellow