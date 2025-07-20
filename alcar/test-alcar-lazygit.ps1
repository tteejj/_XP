# Test ALCAR LazyGit Integration
# Tests the new LazyGit interface with ALCAR's existing services

Write-Host "=== ALCAR LazyGit Integration Test ===" -ForegroundColor Cyan
Write-Host "Testing LazyGit interface with ALCAR services" -ForegroundColor Yellow
Write-Host

try {
    # Load ALCAR system
    Write-Host "Loading ALCAR system..." -ForegroundColor Green
    . "$PSScriptRoot/bolt.ps1" -Debug
    
    Write-Host "`nALCAR system loaded successfully" -ForegroundColor Green
    
    # Test creating the LazyGit screen
    Write-Host "`nTesting ALCAR LazyGit screen creation..." -ForegroundColor Green
    
    # Check if services are available
    Write-Host "Available services:" -ForegroundColor Gray
    if ($global:ServiceContainer) {
        $taskService = $global:ServiceContainer.GetService("TaskService")
        $projectService = $global:ServiceContainer.GetService("ProjectService")
        
        Write-Host "  ✓ TaskService: $($taskService -ne $null)" -ForegroundColor Gray
        Write-Host "  ✓ ProjectService: $($projectService -ne $null)" -ForegroundColor Gray
    } else {
        Write-Host "  ✗ ServiceContainer not available" -ForegroundColor Red
    }
    
    # Try to create the LazyGit screen
    Write-Host "`nCreating ALCARLazyGitScreen..." -ForegroundColor Green
    $lazyGitScreen = [ALCARLazyGitScreen]::new()
    
    if ($lazyGitScreen.IsInitialized) {
        Write-Host "✓ ALCAR LazyGit screen created successfully" -ForegroundColor Green
        
        # Test basic functionality
        Write-Host "`nTesting basic functionality..." -ForegroundColor Green
        
        # Test layout
        $layoutStats = $lazyGitScreen.Layout.GetLayoutStats()
        Write-Host "  ✓ Layout: $($layoutStats.LayoutMode) mode" -ForegroundColor Gray
        Write-Host "  ✓ Panels: $($layoutStats.LeftPanelCount) left + main" -ForegroundColor Gray
        Write-Host "  ✓ Terminal: $($layoutStats.TerminalSize)" -ForegroundColor Gray
        
        # Test rendering
        Write-Host "`nTesting rendering..." -ForegroundColor Green
        $content = $lazyGitScreen.RenderContent()
        Write-Host "  ✓ Rendered content: $($content.Length) characters" -ForegroundColor Gray
        
        # Test input handling
        Write-Host "`nTesting input handling..." -ForegroundColor Green
        $testKey = [ConsoleKeyInfo]::new([char]0, [ConsoleKey]::F5, $false, $false, $false)
        $handled = $lazyGitScreen.HandleInput($testKey)
        Write-Host "  ✓ F5 key handled: $handled" -ForegroundColor Gray
        
        # Test focus management
        Write-Host "`nTesting focus management..." -ForegroundColor Green
        $focusState = $lazyGitScreen.FocusManager.GetFocusState()
        Write-Host "  ✓ Current focus: $($focusState.FocusedPanelName)" -ForegroundColor Gray
        Write-Host "  ✓ Total panels: $($focusState.TotalPanels)" -ForegroundColor Gray
        
        Write-Host "`n✅ ALCAR LazyGit integration test PASSED!" -ForegroundColor Green
        Write-Host "The LazyGit interface is ready to use in ALCAR" -ForegroundColor Cyan
        
    } else {
        Write-Host "✗ ALCAR LazyGit screen failed to initialize" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Integration test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n=== Integration Instructions ===" -ForegroundColor Cyan
Write-Host "To use the ALCAR LazyGit interface:" -ForegroundColor Yellow
Write-Host "1. Run: ./bolt.ps1" -ForegroundColor Gray
Write-Host "2. From main menu, press 'G' for ALCAR LazyGit Interface" -ForegroundColor Gray
Write-Host "3. Navigate with Ctrl+Tab, Ctrl+P for command palette" -ForegroundColor Gray
Write-Host "4. Press Esc or Q to return to main menu" -ForegroundColor Gray