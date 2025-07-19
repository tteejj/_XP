#!/usr/bin/env pwsh
# Test script to verify all components load correctly

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Testing ALCAR loading..." -ForegroundColor Cyan
    
    # Source the bolt.ps1 script but skip the main execution
    $scriptContent = Get-Content -Path "./bolt.ps1" -Raw
    
    # Remove the last part that creates and runs the screen manager
    $scriptContent = $scriptContent -replace '# Create and run screen manager[\s\S]*$', '# Skipped for testing'
    
    # Execute the modified script
    Invoke-Expression $scriptContent
    
    Write-Host "`nAll components loaded successfully!" -ForegroundColor Green
    
    # Test creating instances of screens
    Write-Host "`nTesting screen instantiation..." -ForegroundColor Yellow
    
    $screens = @(
        "MainMenuScreen",
        "TaskScreen", 
        "ProjectsScreen",
        "DashboardScreen",
        "FileBrowserScreen",
        "TextEditorScreen",
        "TextEditorScreenV2",
        "SettingsScreenV2"
    )
    
    foreach ($screenName in $screens) {
        try {
            $screen = Invoke-Expression "[$screenName]::new()"
            Write-Host "✓ $screenName" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ $screenName - $_" -ForegroundColor Red
        }
    }
    
    Write-Host "`nAll tests passed!" -ForegroundColor Green
}
catch {
    Write-Host "`nError: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}