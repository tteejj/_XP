#!/usr/bin/env pwsh
# ==============================================================================
# QUICK INTEGRATION TEST - Fast validation of all core functionality
# ==============================================================================

$ErrorActionPreference = "Continue"
$Results = @{
    StartTime = Get-Date
    Tests = @{}
    Issues = @()
    Summary = @{ Total = 0; Passed = 0; Failed = 0 }
}

function Test-Integration {
    param([string]$Name, [scriptblock]$Test, [string]$Description = "")
    
    $Results.Summary.Total++
    Write-Host "🧪 Testing: $Name" -ForegroundColor Cyan
    
    try {
        $result = & $Test
        $Results.Tests[$Name] = @{
            Status = "PASSED"
            Result = $result
            Description = $Description
        }
        $Results.Summary.Passed++
        Write-Host "✅ PASSED: $Name" -ForegroundColor Green
        return $result
    } catch {
        $Results.Tests[$Name] = @{
            Status = "FAILED"
            Error = $_.Exception.Message
            Description = $Description
        }
        $Results.Summary.Failed++
        $Results.Issues += "$Name - $($_.Exception.Message)"
        Write-Host "❌ FAILED: $Name - $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

Write-Host "🚀 QUICK INTEGRATION TEST STARTED" -ForegroundColor Yellow

# Test 1: Framework Loading
Test-Integration "FrameworkLoad" {
    . "./Base/ABC.001_TuiAnsiHelper.ps1"
    . "./Base/ABC.002_TuiCell.ps1"  
    . "./Base/ABC.003_TuiBuffer.ps1"
    
    # Test basic functionality
    $ansi = [TuiAnsiHelper]::GetAnsiSequence("#FF0000", "#000000", @{})
    $cell = [TuiCell]::new('T', "#FF0000", "#000000")
    $buffer = [TuiBuffer]::new(80, 24)
    
    # Load framework in background
    $loadStart = Get-Date
    . "./Start.ps1" | Out-Null
    $loadTime = (Get-Date) - $loadStart
    
    # Brief stabilization
    Start-Sleep -Seconds 1
    
    return @{
        LoadTime = $loadTime.TotalSeconds
        AnsiWorking = ($ansi -ne $null)
        CellWorking = ($cell.Char -eq 'T')
        BufferWorking = ($buffer.Width -eq 80)
        GlobalState = ($global:TuiState -ne $null)
        Services = if ($global:TuiServices) { $global:TuiServices.Count } else { 0 }
    }
} "Load and initialize framework"

# Test 2: Current Screen State
Test-Integration "CurrentScreen" {
    if (-not $global:TuiState) { throw "TuiState not available" }
    
    $screen = $global:TuiState.CurrentScreen
    if (-not $screen) { throw "No current screen" }
    
    return @{
        Type = $screen.GetType().Name
        HasRender = $screen.PSObject.Methods['Render'] -ne $null
        HasInput = $screen.PSObject.Methods['HandleInput'] -ne $null
        HasInitialize = $screen.PSObject.Methods['Initialize'] -ne $null
    }
} "Validate current screen state"

# Test 3: Navigation Service
Test-Integration "NavigationService" {
    $navService = $global:TuiServices['NavigationService']
    if (-not $navService) { throw "NavigationService not found" }
    
    return @{
        Service = $navService.GetType().Name
        HasNavigateToScreen = $navService.PSObject.Methods['NavigateToScreen'] -ne $null
        HasGoBack = $navService.PSObject.Methods['GoBack'] -ne $null
    }
} "Validate navigation service"

# Test 4: Basic Navigation
Test-Integration "BasicNavigation" {
    $navService = $global:TuiServices['NavigationService']
    $originalScreen = $global:TuiState.CurrentScreen.GetType().Name
    
    # Test navigation to TaskListScreen
    $navService.NavigateToScreen("TaskListScreen")
    Start-Sleep -Milliseconds 800
    
    $newScreen = $global:TuiState.CurrentScreen.GetType().Name
    $taskNavSuccess = ($newScreen -eq "TaskListScreen")
    
    # Return to dashboard
    $navService.NavigateToScreen("DashboardScreen")
    Start-Sleep -Milliseconds 800
    
    $returnScreen = $global:TuiState.CurrentScreen.GetType().Name
    $returnSuccess = ($returnScreen -eq "DashboardScreen")
    
    return @{
        OriginalScreen = $originalScreen
        TaskNavigation = $taskNavSuccess
        ReturnNavigation = $returnSuccess
        FinalScreen = $returnScreen
    }
} "Test basic navigation flow"

# Test 5: Input Handling
Test-Integration "InputHandling" {
    $screen = $global:TuiState.CurrentScreen
    
    # Test arrow keys
    $upKey = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::UpArrow, $false, $false, $false)
    $downKey = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)
    $enterKey = [System.ConsoleKeyInfo]::new([char]13, [ConsoleKey]::Enter, $false, $false, $false)
    
    $upResult = $screen.HandleInput($upKey)
    Start-Sleep -Milliseconds 100
    $downResult = $screen.HandleInput($downKey)
    Start-Sleep -Milliseconds 100
    $enterResult = $screen.HandleInput($enterKey)
    
    return @{
        UpArrow = ($upResult -ne $null)
        DownArrow = ($downResult -ne $null)
        Enter = ($enterResult -ne $null)
        ScreenType = $screen.GetType().Name
    }
} "Test keyboard input handling"

# Test 6: Data Manager
Test-Integration "DataManager" {
    $dataManager = $global:TuiServices['DataManager']
    if (-not $dataManager) { throw "DataManager not found" }
    
    $tasks = $dataManager.GetTasks()
    $projects = $dataManager.GetProjects()
    
    return @{
        Service = $dataManager.GetType().Name
        TaskCount = if ($tasks) { $tasks.Count } else { 0 }
        ProjectCount = if ($projects) { $projects.Count } else { 0 }
        HasGetTasks = $dataManager.PSObject.Methods['GetTasks'] -ne $null
        HasSaveTask = $dataManager.PSObject.Methods['SaveTask'] -ne $null
    }
} "Test data manager operations"

# Test 7: Screen Discovery
Test-Integration "ScreenDiscovery" {
    $screenFiles = Get-ChildItem -Path "./Screens/ASC.*.ps1"
    $screens = @{}
    
    foreach ($file in $screenFiles) {
        $name = $file.BaseName -replace "ASC\.\d+_", ""
        $content = Get-Content $file.FullName -Raw
        
        $screens[$name] = @{
            HasClass = ($content -match 'class\s+(\w+)')
            ClassName = if ($content -match 'class\s+(\w+)') { $Matches[1] } else { $null }
            FileSize = (Get-Item $file.FullName).Length
        }
    }
    
    return @{
        TotalScreens = $screenFiles.Count
        ScreensWithClass = ($screens.Values | Where-Object { $_.HasClass }).Count
        Screens = $screens
    }
} "Discover all application screens"

# Test 8: Component Discovery
Test-Integration "ComponentDiscovery" {
    $componentFiles = Get-ChildItem -Path "./Components/ACO.*.ps1"
    $components = @{}
    
    foreach ($file in $componentFiles) {
        $name = $file.BaseName -replace "ACO\.\d+_", ""
        $content = Get-Content $file.FullName -Raw
        
        $components[$name] = @{
            HasClass = ($content -match 'class\s+(\w+)')
            HasRender = ($content -match 'Render\s*\(')
            HasInput = ($content -match 'HandleInput\s*\(')
            FileSize = (Get-Item $file.FullName).Length
        }
    }
    
    return @{
        TotalComponents = $componentFiles.Count
        ComponentsWithRender = ($components.Values | Where-Object { $_.HasRender }).Count
        ComponentsWithInput = ($components.Values | Where-Object { $_.HasInput }).Count
        Components = $components
    }
} "Discover all UI components"

# Test 9: Performance Benchmark
Test-Integration "PerformanceBenchmark" {
    $buffer = [TuiBuffer]::new(80, 24)
    $style = @{ FG = "#FFFFFF"; BG = "#000000" }
    
    # Test buffer clear
    $clearStart = Get-Date
    for ($i = 0; $i -lt 5; $i++) { $buffer.Clear() }
    $clearTime = (Get-Date) - $clearStart
    
    # Test buffer write
    $writeStart = Get-Date
    for ($i = 0; $i -lt 5; $i++) {
        for ($y = 0; $y -lt 24; $y++) {
            $buffer.WriteString(0, $y, "Performance test $i $y", $style)
        }
    }
    $writeTime = (Get-Date) - $writeStart
    
    # Test ANSI generation
    $ansiStart = Get-Date
    for ($i = 0; $i -lt 50; $i++) {
        $ansi = [TuiAnsiHelper]::GetAnsiSequence("#FF0000", "#000000", @{Bold=$true})
    }
    $ansiTime = (Get-Date) - $ansiStart
    
    return @{
        ClearTime = $clearTime.TotalMilliseconds
        WriteTime = $writeTime.TotalMilliseconds
        AnsiTime = $ansiTime.TotalMilliseconds
        ClearPerformance = if ($clearTime.TotalMilliseconds -lt 100) { "Good" } else { "Slow" }
        WritePerformance = if ($writeTime.TotalMilliseconds -lt 200) { "Good" } else { "Slow" }
    }
} "Benchmark core performance"

# Test 10: Service Integration
Test-Integration "ServiceIntegration" {
    $requiredServices = @("Logger", "EventManager", "ThemeManager", "DataManager", "ActionService", "KeybindingService", "NavigationService")
    $serviceStatus = @{}
    
    foreach ($service in $requiredServices) {
        $serviceStatus[$service] = $global:TuiServices.ContainsKey($service)
    }
    
    return @{
        RequiredServices = $requiredServices.Count
        RegisteredServices = ($serviceStatus.Values | Where-Object { $_ }).Count
        ServiceStatus = $serviceStatus
        AllServicesRegistered = ($serviceStatus.Values | Where-Object { -not $_ }).Count -eq 0
    }
} "Validate service integration"

# Generate Results
$duration = (Get-Date) - $Results.StartTime
$successRate = if ($Results.Summary.Total -gt 0) { [Math]::Round(($Results.Summary.Passed / $Results.Summary.Total) * 100, 1) } else { 0 }

Write-Host "`n📊 QUICK INTEGRATION TEST RESULTS" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Duration: $([Math]::Round($duration.TotalSeconds, 1)) seconds" -ForegroundColor White
Write-Host "Total Tests: $($Results.Summary.Total)" -ForegroundColor White
Write-Host "Passed: $($Results.Summary.Passed)" -ForegroundColor Green
Write-Host "Failed: $($Results.Summary.Failed)" -ForegroundColor Red
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -gt 80) { "Green" } else { "Yellow" })

if ($Results.Issues.Count -gt 0) {
    Write-Host "`n🚨 ISSUES FOUND:" -ForegroundColor Red
    foreach ($issue in $Results.Issues) {
        Write-Host "  • $issue" -ForegroundColor Yellow
    }
}

# Save detailed results
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportFile = "quick-integration-results-$timestamp.json"
$Results | ConvertTo-Json -Depth 8 | Out-File $reportFile

Write-Host "`n📄 Detailed results saved to: $reportFile" -ForegroundColor Cyan

# Key findings summary
Write-Host "`n🔍 KEY FINDINGS:" -ForegroundColor White
foreach ($testName in $Results.Tests.Keys) {
    $test = $Results.Tests[$testName]
    if ($test.Status -eq "PASSED" -and $test.Result) {
        $result = $test.Result
        switch ($testName) {
            "FrameworkLoad" { Write-Host "  • Framework loads in $([Math]::Round($result.LoadTime, 1))s with $($result.Services) services" -ForegroundColor Green }
            "CurrentScreen" { Write-Host "  • Current screen: $($result.Type)" -ForegroundColor Green }
            "DataManager" { Write-Host "  • Data: $($result.TaskCount) tasks, $($result.ProjectCount) projects" -ForegroundColor Green }
            "ScreenDiscovery" { Write-Host "  • Discovered: $($result.TotalScreens) screens, $($result.ScreensWithClass) with classes" -ForegroundColor Green }
            "ComponentDiscovery" { Write-Host "  • Components: $($result.TotalComponents) total, $($result.ComponentsWithRender) with Render" -ForegroundColor Green }
            "PerformanceBenchmark" { Write-Host "  • Performance: Clear $([Math]::Round($result.ClearTime, 1))ms, Write $([Math]::Round($result.WriteTime, 1))ms" -ForegroundColor Green }
        }
    }
}

# Cleanup
if ($global:TuiState) {
    $global:TuiState.Running = $false
}

Write-Host "`n✅ QUICK INTEGRATION TEST COMPLETE!" -ForegroundColor Green
return $Results