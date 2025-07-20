#!/usr/bin/env pwsh
# Debug ALCAR LazyGit Screen

Write-Host "=== ALCAR LazyGit Debug Test ===" -ForegroundColor Cyan

# Set debug preference
$DebugPreference = "Continue"

try {
    # Load ALCAR components
    Write-Host "Loading ALCAR components..." -ForegroundColor Green
    
    # Load in dependency order
    . "$PSScriptRoot/Core/vt100.ps1"
    . "$PSScriptRoot/Core/Cell.ps1"
    . "$PSScriptRoot/Core/Buffer.ps1"
    . "$PSScriptRoot/Core/dateparser.ps1"
    . "$PSScriptRoot/Core/ILazyGitView.ps1"
    . "$PSScriptRoot/Core/LazyGitRenderer.ps1"
    . "$PSScriptRoot/Core/LazyGitLayout.ps1"
    . "$PSScriptRoot/Core/LazyGitPanel.ps1"
    . "$PSScriptRoot/Core/LazyGitFocusManager.ps1"
    . "$PSScriptRoot/Base/Screen.ps1"
    . "$PSScriptRoot/Base/Dialog.ps1"
    . "$PSScriptRoot/Base/Component.ps1"
    . "$PSScriptRoot/Core/ScreenManager.ps1"
    . "$PSScriptRoot/Models/task.ps1"
    . "$PSScriptRoot/Models/Project.ps1"
    . "$PSScriptRoot/Services/ServiceContainer.ps1"
    . "$PSScriptRoot/Services/TaskService.ps1"
    . "$PSScriptRoot/Services/ProjectService.ps1"
    . "$PSScriptRoot/Services/ViewDefinitionService.ps1"
    . "$PSScriptRoot/Screens/EditDialog.ps1"
    . "$PSScriptRoot/Screens/ProjectCreationDialog.ps1"
    . "$PSScriptRoot/Screens/ALCARLazyGitScreen.ps1"
    
    Write-Host "Components loaded successfully" -ForegroundColor Green
    
    # Initialize services
    $global:ServiceContainer = [ServiceContainer]::new()
    $global:ServiceContainer.RegisterService("TaskService", [TaskService]::new())
    $global:ServiceContainer.RegisterService("ProjectService", [ProjectService]::new())
    $global:ServiceContainer.RegisterService("ViewDefinitionService", [ViewDefinitionService]::new())
    
    # Create LazyGit screen
    Write-Host "`nCreating ALCARLazyGitScreen..." -ForegroundColor Green
    $screen = [ALCARLazyGitScreen]::new()
    
    # Test initialization
    Write-Host "IsInitialized: $($screen.IsInitialized)" -ForegroundColor Yellow
    Write-Host "Active: $($screen.Active)" -ForegroundColor Yellow
    Write-Host "Layout Mode: $($screen.Layout.LayoutMode)" -ForegroundColor Yellow
    Write-Host "Left Panels: $($screen.LeftPanels.Count)" -ForegroundColor Yellow
    Write-Host "Focus Index: $($screen.FocusManager.FocusedPanelIndex)" -ForegroundColor Yellow
    
    # Activate the screen
    Write-Host "`nActivating screen..." -ForegroundColor Green
    $screen.OnActivate()
    
    Write-Host "Focus Index after activate: $($screen.FocusManager.FocusedPanelIndex)" -ForegroundColor Yellow
    
    # Test rendering
    Write-Host "`nTesting render..." -ForegroundColor Green
    $content = $screen.RenderContent()
    Write-Host "Rendered $($content.Length) characters" -ForegroundColor Yellow
    
    # Test input handling
    Write-Host "`nTesting input handling..." -ForegroundColor Green
    
    # Create test keys
    $keys = @(
        [ConsoleKeyInfo]::new('q', [ConsoleKey]::Q, $false, $false, $false),
        [ConsoleKeyInfo]::new([char]0, [ConsoleKey]::Tab, $false, $false, $true),  # Ctrl+Tab
        [ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)
    )
    
    foreach ($key in $keys) {
        Write-Host "  Testing key: $($key.Key) Mod: $($key.Modifiers)" -ForegroundColor Gray
        $handled = $screen.HandleInput($key)
        Write-Host "  Handled: $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
        Write-Host "  Status: $($screen.StatusMessage)" -ForegroundColor Gray
        Write-Host "  Active: $($screen.Active)" -ForegroundColor Gray
    }
    
    Write-Host "`n✅ Debug test completed" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}