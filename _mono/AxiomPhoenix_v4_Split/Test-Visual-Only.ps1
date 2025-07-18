#!/usr/bin/env pwsh
# Test if visual rendering works by programmatically changing selection

Write-Host "=== VISUAL RENDERING TEST ===" -ForegroundColor Cyan
Write-Host "This will start the app and programmatically change the selection to test visual updates" -ForegroundColor Yellow
Write-Host "You should see the selection move automatically without any input" -ForegroundColor Yellow

# Start the app normally
. ./Start.ps1

Write-Host "App should be running now - this test will force selection changes..." -ForegroundColor Yellow

# Wait for app to start
Start-Sleep -Seconds 2

# Get the dashboard and change selection programmatically
$dashboard = $global:TuiState.Services.NavigationService.CurrentScreen
$listBox = $dashboard._menuListBox

if ($listBox) {
    Write-Host "Forcing selection changes..." -ForegroundColor Green
    
    # Change selection every second to test visual updates
    for ($i = 0; $i -lt 5; $i++) {
        Start-Sleep -Seconds 1
        $newIndex = ($listBox.SelectedIndex + 1) % $listBox.Items.Count
        Write-Host "Changing selection from $($listBox.SelectedIndex) to $newIndex" -ForegroundColor Yellow
        $listBox.SelectedIndex = $newIndex
        $global:TuiState.IsDirty = $true
        
        # Force a render
        if (Get-Command Request-OptimizedRedraw -ErrorAction SilentlyContinue) {
            Request-OptimizedRedraw -Source "VisualTest" -Immediate
        }
    }
}

Write-Host "Visual test complete - press any key to exit" -ForegroundColor Yellow