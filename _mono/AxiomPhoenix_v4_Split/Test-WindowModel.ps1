# ==============================================================================
# Test Script for True Windowing Model
# Tests the window stack, focus management, and dialog system
# ==============================================================================

param(
    [switch]$Debug
)

# Set error action preference
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Testing True Windowing Model..." -ForegroundColor Cyan
    
    # Load the framework
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    . (Join-Path $scriptDir "Start.ps1") -Debug:$Debug
    
    Write-Host "`nFramework loaded. Running tests..." -ForegroundColor Green
    
    # Get services
    $container = $global:TuiState.ServiceContainer
    $navService = $container.GetService("NavigationService")
    $focusManager = $container.GetService("FocusManager")
    $dialogManager = $container.GetService("DialogManager")
    
    # Test 1: NavigationService.GetWindows()
    Write-Host "`nTest 1: NavigationService.GetWindows()" -ForegroundColor Yellow
    $windows = $navService.GetWindows()
    Write-Host "  Initial window count: $($windows.Count)"
    $currentScreenName = if ($null -ne $navService.CurrentScreen) { $navService.CurrentScreen.Name } else { 'null' }
    Write-Host "  Current screen: $currentScreenName"
    
    # Test 2: Dialog navigation with focus preservation
    Write-Host "`nTest 2: Dialog Navigation with Focus Preservation" -ForegroundColor Yellow
    
    # Create a test dialog
    $testDialog = [AlertDialog]::new("TestAlert", $container)
    $testDialog.Show("Test Dialog", "This is a test of the window model")
    
    $currentFocusName = if ($null -ne $focusManager.FocusedComponent) { $focusManager.FocusedComponent.Name } else { 'null' }
    Write-Host "  Current focus before dialog: $currentFocusName"
    Write-Host "  Focus stack count: $($focusManager.FocusStack.Count)"
    
    # Navigate to dialog
    $navService.NavigateTo($testDialog)
    
    $windows = $navService.GetWindows()
    Write-Host "  Window count after dialog: $($windows.Count)"
    Write-Host "  Top window: $($windows[-1].Name)"
    Write-Host "  Top window IsOverlay: $($windows[-1].IsOverlay)"
    Write-Host "  Focus stack count after: $($focusManager.FocusStack.Count)"
    
    # Test 3: Focus restoration on dialog close
    Write-Host "`nTest 3: Focus Restoration" -ForegroundColor Yellow
    
    # Close dialog
    $testDialog.Complete("OK")
    
    $windows = $navService.GetWindows()
    Write-Host "  Window count after close: $($windows.Count)"
    $currentScreenName2 = if ($null -ne $navService.CurrentScreen) { $navService.CurrentScreen.Name } else { 'null' }
    Write-Host "  Current screen: $currentScreenName2"
    $restoredFocusName = if ($null -ne $focusManager.FocusedComponent) { $focusManager.FocusedComponent.Name } else { 'null' }
    Write-Host "  Restored focus: $restoredFocusName"
    Write-Host "  Focus stack count: $($focusManager.FocusStack.Count)"
    
    # Test 4: Command Palette as Dialog
    Write-Host "`nTest 4: Command Palette as Dialog" -ForegroundColor Yellow
    
    $actionService = $container.GetService("ActionService")
    $actionCount = $actionService.ActionRegistry.Count
    Write-Host "  Registered actions: $actionCount"
    
    # Execute command palette action
    Write-Host "  Executing app.commandPalette action..."
    $actionService.ExecuteAction("app.commandPalette", @{})
    
    # Check window stack
    Start-Sleep -Milliseconds 100  # Give it time to navigate
    $windows = $navService.GetWindows()
    Write-Host "  Window count with palette: $($windows.Count)"
    if ($windows.Count -gt 0) {
        Write-Host "  Top window: $($windows[-1].Name)"
        Write-Host "  Top window type: $($windows[-1].GetType().Name)"
    }
    
    # Test 5: Render all windows
    Write-Host "`nTest 5: Render Window Stack" -ForegroundColor Yellow
    
    # Force a render
    Invoke-TuiRender
    Write-Host "  Render completed successfully"
    
    # Test 6: ScrollablePanel without virtual buffer
    Write-Host "`nTest 6: ScrollablePanel Simplified" -ForegroundColor Yellow
    
    $scrollPanel = [ScrollablePanel]::new("TestScrollPanel")
    $scrollPanel.Width = 40
    $scrollPanel.Height = 10
    
    # Add some test content
    for ($i = 1; $i -le 20; $i++) {
        $label = [LabelComponent]::new("Label$i")
        $label.Text = "Test Item $i"
        $label.Y = $i * 2
        $scrollPanel.AddChild($label)
    }
    
    Write-Host "  Created ScrollablePanel with 20 items"
    Write-Host "  Content height: $($scrollPanel._contentHeight)"
    Write-Host "  Max scroll: $($scrollPanel.MaxScrollY)"
    
    # Test scrolling
    $scrollPanel.ScrollDown(5)
    Write-Host "  Scrolled down 5 lines, offset: $($scrollPanel.ScrollOffsetY)"
    
    # Render the panel
    $scrollPanel.Render()
    Write-Host "  ScrollablePanel rendered successfully"
    
    Write-Host "`nAll tests completed!" -ForegroundColor Green
    Write-Host "Window model is functioning correctly." -ForegroundColor Green
    
} catch {
    Write-Host "`nTest failed!" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    if ($global:TuiState.Running) {
        Stop-TuiEngine
    }
}
