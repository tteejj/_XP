# ==============================================================================
# Test Script for Hybrid Window Model
# Tests that Tab navigation and component input handling work correctly
# ==============================================================================

param(
    [switch]$UseOriginal
)

# Load the framework
. "$PSScriptRoot\Start.ps1" -Theme "Synthwave"

Write-Host "`n`nTesting Hybrid Window Model..." -ForegroundColor Cyan
Write-Host "This test will:" -ForegroundColor Yellow
Write-Host "  1. Load NewTaskScreen with hybrid focus model" -ForegroundColor White
Write-Host "  2. Verify Tab navigation works automatically" -ForegroundColor White
Write-Host "  3. Verify components handle their own input" -ForegroundColor White
Write-Host "  4. Verify global shortcuts still work`n" -ForegroundColor White

# Wait for user
Write-Host "Press any key to start test..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

try {
    # Get services
    $container = $global:TuiState.ServiceContainer
    $navService = $container.GetService("NavigationService")
    
    # Create the screen to test
    if ($UseOriginal) {
        Write-Host "Loading ORIGINAL NewTaskScreen (direct input)..." -ForegroundColor Yellow
        . "$PSScriptRoot\Screens\ASC.004_NewTaskScreen.ps1"
    } else {
        Write-Host "Loading HYBRID NewTaskScreen..." -ForegroundColor Green
        . "$PSScriptRoot\Screens\ASC.004_NewTaskScreen_HYBRID.ps1"
    }
    
    $screen = [NewTaskScreen]::new($container)
    $screen.Initialize()
    
    # Create a simple test harness screen
    $testScreen = [Screen]::new("TestHarness", $container)
    
    # Override Initialize to show test info
    $testScreen | Add-Member -MemberType ScriptMethod -Name Initialize -Value {
        $panel = [Panel]::new("TestPanel")
        $panel.X = 0
        $panel.Y = 0
        $panel.Width = $this.Width
        $panel.Height = $this.Height
        $panel.Title = " Hybrid Model Test "
        $panel.BorderStyle = "Double"
        $this.AddChild($panel)
        
        $info = [LabelComponent]::new("Info")
        $info.X = 2
        $info.Y = 2
        $info.Text = "Test Instructions:"
        $info.ForegroundColor = "#FFD700"
        $panel.AddChild($info)
        
        $instructions = @(
            "1. Press [Enter] to open NewTaskScreen",
            "2. Use [Tab] to navigate between fields - should work automatically",
            "3. Type text in fields - components should handle input",
            "4. Press [P] to cycle priority - screen shortcut",
            "5. Press [Esc] to cancel - screen shortcut",
            "",
            "Expected Behavior:",
            "- Tab/Shift+Tab cycles focus automatically",
            "- Text boxes handle their own typing/backspace",
            "- Buttons respond to Enter/Space when focused",
            "- Visual focus indicators update (blue borders)",
            "- Global shortcuts (P, S, C, Esc) work from any field"
        )
        
        $y = 4
        foreach ($line in $instructions) {
            $label = [LabelComponent]::new("Line$y")
            $label.X = 4
            $label.Y = $y
            $label.Text = $line
            $label.ForegroundColor = if ($line -match "Expected") { "#00FF88" } else { "#E0E0E0" }
            $panel.AddChild($label)
            $y++
        }
        
        $prompt = [LabelComponent]::new("Prompt")
        $prompt.X = 2
        $prompt.Y = $panel.Height - 3
        $prompt.Text = "Press [Enter] to start test, [Q] to quit"
        $prompt.ForegroundColor = "#00D4FF"
        $panel.AddChild($prompt)
    } -Force
    
    # Override HandleInput
    $testScreen | Add-Member -MemberType ScriptMethod -Name HandleInput -Value {
        param([System.ConsoleKeyInfo]$keyInfo)
        
        if ($keyInfo.Key -eq [ConsoleKey]::Enter) {
            # Navigate to NewTaskScreen
            $newTaskScreen = [NewTaskScreen]::new($this.ServiceContainer)
            $newTaskScreen.Initialize()
            $navService = $this.ServiceContainer.GetService("NavigationService")
            $navService.NavigateTo($newTaskScreen)
            return $true
        }
        
        if ($keyInfo.KeyChar -eq 'q' -or $keyInfo.KeyChar -eq 'Q') {
            # Exit
            $actionService = $this.ServiceContainer.GetService("ActionService")
            $actionService.ExecuteAction("app.exit", @{})
            return $true
        }
        
        return $false
    } -Force
    
    # Initialize and show test screen
    $testScreen.Initialize()
    
    # Navigate to test screen
    $navService.NavigateTo($testScreen)
    
    Write-Host "`nTest screen loaded. The TUI should now be active." -ForegroundColor Green
    Write-Host "Follow the on-screen instructions to test the hybrid model." -ForegroundColor Yellow
    
} catch {
    Write-Host "`nERROR: Test failed!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}
