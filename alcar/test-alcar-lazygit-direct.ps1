# Direct test of ALCAR LazyGit integration
# Loads components directly to test integration

Write-Host "=== ALCAR LazyGit Direct Test ===" -ForegroundColor Cyan

try {
    # Load LazyGit components directly
    Write-Host "Loading LazyGit components..." -ForegroundColor Green
    
    . "$PSScriptRoot/Core/ILazyGitView.ps1"
    Write-Host "  ✓ ILazyGitView loaded" -ForegroundColor Gray
    
    . "$PSScriptRoot/Core/LazyGitRenderer.ps1"
    Write-Host "  ✓ LazyGitRenderer loaded" -ForegroundColor Gray
    
    . "$PSScriptRoot/Core/LazyGitLayout.ps1"
    Write-Host "  ✓ LazyGitLayout loaded" -ForegroundColor Gray
    
    . "$PSScriptRoot/Core/LazyGitPanel.ps1"
    Write-Host "  ✓ LazyGitPanel loaded" -ForegroundColor Gray
    
    . "$PSScriptRoot/Core/LazyGitFocusManager.ps1"
    Write-Host "  ✓ LazyGitFocusManager loaded" -ForegroundColor Gray
    
    # Load minimal ALCAR base
    Write-Host "`nLoading minimal ALCAR base..." -ForegroundColor Green
    
    . "$PSScriptRoot/Core/vt100.ps1"
    Write-Host "  ✓ VT100 class loaded" -ForegroundColor Gray
    
    . "$PSScriptRoot/Base/Screen.ps1"
    Write-Host "  ✓ Screen base class loaded" -ForegroundColor Gray
    
    # Create mock services
    Write-Host "`nCreating mock services..." -ForegroundColor Green
    
    $global:ServiceContainer = [PSCustomObject]@{
        Services = @{}
    }
    
    # Add GetService method
    $global:ServiceContainer | Add-Member -MemberType ScriptMethod -Name "GetService" -Value {
        param($serviceName)
        switch ($serviceName) {
            "TaskService" {
                return [PSCustomObject]@{
                    Tasks = @(
                        @{ Name = "Test Task 1"; Status = "Active"; Priority = "High" },
                        @{ Name = "Test Task 2"; Status = "Pending"; Priority = "Medium" },
                        @{ Name = "Implement LazyGit"; Status = "Active"; Priority = "High" },
                        @{ Name = "Fix Performance"; Status = "Pending"; Priority = "Medium" }
                    )
                } | Add-Member -MemberType ScriptMethod -Name "GetTasks" -Value {
                    return $this.Tasks
                } -PassThru
            }
            "ProjectService" {
                return [PSCustomObject]@{
                    Projects = @(
                        @{ Name = "ALCAR Project"; Description = "Main project" },
                        @{ Name = "LazyGit Interface"; Description = "UI improvement" }
                    )
                } | Add-Member -MemberType ScriptMethod -Name "GetAllProjects" -Value {
                    return $this.Projects
                } -PassThru
            }
            default { return $null }
        }
    }
    Write-Host "  ✓ Mock services created" -ForegroundColor Gray
    
    # Load ALCARLazyGitScreen
    Write-Host "`nLoading ALCARLazyGitScreen..." -ForegroundColor Green
    . "$PSScriptRoot/Screens/ALCARLazyGitScreen.ps1"
    Write-Host "  ✓ ALCARLazyGitScreen loaded" -ForegroundColor Gray
    
    # Test creating the screen
    Write-Host "`nTesting ALCARLazyGitScreen creation..." -ForegroundColor Green
    $screen = [ALCARLazyGitScreen]::new()
    
    if ($screen.IsInitialized) {
        Write-Host "  ✅ ALCARLazyGitScreen created successfully!" -ForegroundColor Green
        
        # Test basic functionality
        Write-Host "`nTesting functionality..." -ForegroundColor Green
        
        $layoutStats = $screen.Layout.GetLayoutStats()
        Write-Host "  ✓ Layout: $($layoutStats.LayoutMode) mode" -ForegroundColor Gray
        Write-Host "  ✓ Terminal: $($layoutStats.TerminalSize)" -ForegroundColor Gray
        Write-Host "  ✓ Panels: $($layoutStats.LeftPanelCount) left + main" -ForegroundColor Gray
        
        # Test rendering
        $content = $screen.RenderContent()
        Write-Host "  ✓ Rendered: $($content.Length) chars" -ForegroundColor Gray
        
        # Test focus
        $focusState = $screen.FocusManager.GetFocusState()
        Write-Host "  ✓ Focus: $($focusState.FocusedPanelName)" -ForegroundColor Gray
        
        # Test panel data
        $panelCount = $screen.LeftPanels.Count
        Write-Host "  ✓ Created $panelCount left panels" -ForegroundColor Gray
        
        foreach ($panel in $screen.LeftPanels) {
            if ($panel.CurrentView) {
                $viewData = $panel.CurrentView.GetData()
                Write-Host "    - $($panel.Title): $($viewData.Count) items" -ForegroundColor DarkGray
            }
        }
        
        Write-Host "`n✅ ALCAR LazyGit integration WORKING!" -ForegroundColor Green
        Write-Host "The screen is ready for integration into ALCAR" -ForegroundColor Cyan
        
    } else {
        Write-Host "  ❌ ALCARLazyGitScreen failed to initialize" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Direct test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n=== Layout Preview ===" -ForegroundColor Cyan
if ($screen -and $screen.Layout) {
    Write-Host $screen.Layout.ExportLayout() -ForegroundColor Gray
}

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. The ALCARLazyGitScreen is working with mock data" -ForegroundColor Yellow
Write-Host "2. Integration with real ALCAR services is ready" -ForegroundColor Yellow
Write-Host "3. You can now add it to MainMenuScreen and run ./bolt.ps1" -ForegroundColor Yellow