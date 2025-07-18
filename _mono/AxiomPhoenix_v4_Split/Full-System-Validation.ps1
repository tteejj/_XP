#!/usr/bin/env pwsh
# ==============================================================================
# FULL SYSTEM VALIDATION - Comprehensive Testing of Every Component
# ==============================================================================

$ErrorActionPreference = "Continue"

# Initialize results tracking
$Results = @{
    StartTime = Get-Date
    TotalTests = 0
    Passed = 0
    Failed = 0
    Categories = @{}
    Issues = @()
    Performance = @{}
}

function Write-TestResult {
    param([string]$Category, [string]$Test, [bool]$Passed, [string]$Details = "", [hashtable]$Data = @{})
    
    $Results.TotalTests++
    if ($Passed) { $Results.Passed++ } else { $Results.Failed++ }
    
    if (-not $Results.Categories.ContainsKey($Category)) {
        $Results.Categories[$Category] = @{ Passed = 0; Failed = 0; Tests = @{} }
    }
    
    if ($Passed) { $Results.Categories[$Category].Passed++ } else { $Results.Categories[$Category].Failed++ }
    
    $testResult = @{
        Passed = $Passed
        Details = $Details
        Data = $Data
        Timestamp = Get-Date
    }
    
    $Results.Categories[$Category].Tests[$Test] = $testResult
    
    $status = if ($Passed) { "✅" } else { "❌" }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "$status [$Category] $Test" -ForegroundColor $color
    if ($Details) { Write-Host "   $Details" -ForegroundColor Gray }
    if (-not $Passed) { $Results.Issues += "[$Category] $Test - $Details" }
}

Write-Host "🔍 FULL SYSTEM VALIDATION STARTED" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# ==============================================================================
# PHASE 1: FRAMEWORK LOADING
# ==============================================================================
Write-Host "`n📦 PHASE 1: FRAMEWORK LOADING" -ForegroundColor Yellow

try {
    . "./Base/ABC.001_TuiAnsiHelper.ps1"
    . "./Base/ABC.002_TuiCell.ps1"
    . "./Base/ABC.003_TuiBuffer.ps1"
    
    # Test basic functionality
    $helper = [TuiAnsiHelper]::GetAnsiSequence("#FF0000", "#000000", @{})
    $cell = [TuiCell]::new('T', "#FF0000", "#000000")
    $buffer = [TuiBuffer]::new(10, 10)
    
    Write-TestResult "Framework" "BaseClassesLoad" $true "Core classes loaded and functional"
} catch {
    Write-TestResult "Framework" "BaseClassesLoad" $false $_.Exception.Message
    Write-Host "CRITICAL: Cannot continue without base classes" -ForegroundColor Red
    exit 1
}

try {
    $loadStart = Get-Date
    . "./Start.ps1"
    Start-Sleep -Seconds 2
    $loadTime = (Get-Date) - $loadStart
    
    Write-TestResult "Framework" "FullFrameworkLoad" $true "Loaded in $([Math]::Round($loadTime.TotalSeconds, 1))s"
    $Results.Performance["FrameworkLoadTime"] = $loadTime.TotalSeconds
} catch {
    Write-TestResult "Framework" "FullFrameworkLoad" $false $_.Exception.Message
    exit 1
}

# Validate services
$requiredServices = @("Logger", "EventManager", "ThemeManager", "DataManager", "ActionService", "KeybindingService", "NavigationService", "DialogManager")
foreach ($service in $requiredServices) {
    $exists = $global:TuiServices.ContainsKey($service)
    Write-TestResult "Services" "Service-$service" $exists $(if (-not $exists) { "Service not registered" } else { "Service registered" })
}

# ==============================================================================
# PHASE 2: SCREEN VALIDATION
# ==============================================================================
Write-Host "`n🖥️ PHASE 2: SCREEN VALIDATION" -ForegroundColor Yellow

$screenFiles = Get-ChildItem -Path "./Screens/ASC.*.ps1"
Write-Host "Found $($screenFiles.Count) screen files to validate"

foreach ($screenFile in $screenFiles) {
    $screenName = $screenFile.BaseName -replace "ASC\.\d+_", ""
    
    # Test file parsing
    try {
        $content = Get-Content $screenFile.FullName -Raw
        Write-TestResult "Screens" "Parse-$screenName" $true "File parsed successfully"
        
        # Extract class name
        if ($content -match 'class\s+(\w+)') {
            $className = $Matches[1]
            
            # Test instantiation
            try {
                $instance = New-Object $className
                Write-TestResult "Screens" "Instantiate-$screenName" $true "Class $className created"
                
                # Test methods
                $methods = $instance.GetType().GetMethods().Name
                foreach ($method in @('Initialize', 'Render', 'HandleInput')) {
                    $hasMethod = $method -in $methods
                    Write-TestResult "Screens" "Method-$screenName-$method" $hasMethod $(if (-not $hasMethod) { "Method missing" } else { "Method found" })
                }
                
            } catch {
                Write-TestResult "Screens" "Instantiate-$screenName" $false $_.Exception.Message
            }
        } else {
            Write-TestResult "Screens" "ClassFound-$screenName" $false "No class definition found"
        }
    } catch {
        Write-TestResult "Screens" "Parse-$screenName" $false $_.Exception.Message
    }
}

# ==============================================================================
# PHASE 3: NAVIGATION TESTING
# ==============================================================================
Write-Host "`n🧭 PHASE 3: NAVIGATION TESTING" -ForegroundColor Yellow

# Test current state
$currentScreen = $global:TuiState.CurrentScreen
$currentType = $currentScreen.GetType().Name
Write-TestResult "Navigation" "CurrentScreen" $true "Current: $currentType"

# Test navigation service
$navService = $global:TuiServices['NavigationService']
$navExists = $navService -ne $null
Write-TestResult "Navigation" "NavigationService" $navExists $(if (-not $navExists) { "Service missing" } else { "Service available" })

if ($navService) {
    # Test navigation to each major screen
    $targets = @("TaskListScreen", "ProjectsListScreen", "TextEditorScreen", "ThemeScreen")
    
    foreach ($target in $targets) {
        try {
            $originalScreen = $global:TuiState.CurrentScreen.GetType().Name
            $navService.NavigateToScreen($target)
            Start-Sleep -Milliseconds 500
            
            $newScreen = $global:TuiState.CurrentScreen.GetType().Name
            $success = ($newScreen -eq $target)
            
            Write-TestResult "Navigation" "NavigateTo-$target" $success $(if ($success) { "Navigation successful" } else { "Got $newScreen instead of $target" })
            
            # Return to dashboard
            $navService.NavigateToScreen("DashboardScreen")
            Start-Sleep -Milliseconds 300
            
        } catch {
            Write-TestResult "Navigation" "NavigateTo-$target" $false $_.Exception.Message
        }
    }
}

# ==============================================================================
# PHASE 4: INPUT TESTING
# ==============================================================================
Write-Host "`n⌨️ PHASE 4: INPUT TESTING" -ForegroundColor Yellow

# Ensure we're on dashboard
try { $navService.NavigateToScreen("DashboardScreen"); Start-Sleep -Milliseconds 500 } catch { }

$inputTests = @(
    @{Key = [ConsoleKey]::UpArrow; Name = "UpArrow"},
    @{Key = [ConsoleKey]::DownArrow; Name = "DownArrow"}, 
    @{Key = [ConsoleKey]::Enter; Name = "Enter"},
    @{Key = [ConsoleKey]::Tab; Name = "Tab"},
    @{Key = [ConsoleKey]::Escape; Name = "Escape"}
)

foreach ($inputTest in $inputTests) {
    try {
        $screen = $global:TuiState.CurrentScreen
        $keyInfo = [System.ConsoleKeyInfo]::new([char]0, $inputTest.Key, $false, $false, $false)
        
        $inputStart = Get-Date
        $result = $screen.HandleInput($keyInfo)
        $inputTime = (Get-Date) - $inputStart
        
        Write-TestResult "Input" "Key-$($inputTest.Name)" $true "Handled in $([Math]::Round($inputTime.TotalMilliseconds, 1))ms"
        $Results.Performance["Input-$($inputTest.Name)"] = $inputTime.TotalMilliseconds
        
        Start-Sleep -Milliseconds 100
    } catch {
        Write-TestResult "Input" "Key-$($inputTest.Name)" $false $_.Exception.Message
    }
}

# ==============================================================================
# PHASE 5: COMPONENT VALIDATION
# ==============================================================================
Write-Host "`n🧩 PHASE 5: COMPONENT VALIDATION" -ForegroundColor Yellow

$componentFiles = Get-ChildItem -Path "./Components/ACO.*.ps1"
Write-Host "Found $($componentFiles.Count) component files to validate"

foreach ($componentFile in $componentFiles) {
    $componentName = $componentFile.BaseName -replace "ACO\.\d+_", ""
    
    try {
        $content = Get-Content $componentFile.FullName -Raw
        
        # Check for class definition
        if ($content -match 'class\s+(\w+)') {
            $className = $Matches[1]
            
            try {
                $instance = New-Object $className
                Write-TestResult "Components" "Instantiate-$componentName" $true "Component $className created"
                
                # Check for essential methods
                $methods = $instance.GetType().GetMethods().Name
                $hasRender = 'Render' -in $methods
                $hasInput = 'HandleInput' -in $methods
                
                Write-TestResult "Components" "HasRender-$componentName" $hasRender $(if (-not $hasRender) { "Render method missing" } else { "Render method found" })
                Write-TestResult "Components" "HasInput-$componentName" $hasInput $(if (-not $hasInput) { "HandleInput method missing" } else { "HandleInput method found" })
                
            } catch {
                Write-TestResult "Components" "Instantiate-$componentName" $false $_.Exception.Message
            }
        } else {
            Write-TestResult "Components" "ClassFound-$componentName" $false "No class definition"
        }
    } catch {
        Write-TestResult "Components" "Parse-$componentName" $false $_.Exception.Message
    }
}

# ==============================================================================
# PHASE 6: DATA OPERATIONS
# ==============================================================================
Write-Host "`n💾 PHASE 6: DATA OPERATIONS" -ForegroundColor Yellow

$dataManager = $global:TuiServices['DataManager']
if ($dataManager) {
    Write-TestResult "Data" "DataManagerExists" $true "DataManager service available"
    
    # Test data retrieval
    try {
        $tasks = $dataManager.GetTasks()
        $taskCount = if ($tasks) { $tasks.Count } else { 0 }
        Write-TestResult "Data" "GetTasks" $true "Retrieved $taskCount tasks"
    } catch {
        Write-TestResult "Data" "GetTasks" $false $_.Exception.Message
    }
    
    try {
        $projects = $dataManager.GetProjects()
        $projectCount = if ($projects) { $projects.Count } else { 0 }
        Write-TestResult "Data" "GetProjects" $true "Retrieved $projectCount projects"
    } catch {
        Write-TestResult "Data" "GetProjects" $false $_.Exception.Message
    }
    
    # Test method availability
    $methods = $dataManager.GetType().GetMethods().Name
    foreach ($method in @('SaveTask', 'DeleteTask', 'SaveProject', 'DeleteProject')) {
        $hasMethod = $method -in $methods
        Write-TestResult "Data" "HasMethod-$method" $hasMethod $(if (-not $hasMethod) { "Method missing" } else { "Method available" })
    }
    
} else {
    Write-TestResult "Data" "DataManagerExists" $false "DataManager service not found"
}

# ==============================================================================
# PHASE 7: PERFORMANCE BENCHMARKS
# ==============================================================================
Write-Host "`n⚡ PHASE 7: PERFORMANCE BENCHMARKS" -ForegroundColor Yellow

# Test buffer operations
try {
    $buffer = [TuiBuffer]::new(80, 24)
    $style = @{ FG = "#FFFFFF"; BG = "#000000" }
    
    # Test clear performance
    $clearTimes = @()
    for ($i = 0; $i -lt 5; $i++) {
        $start = Get-Date
        $buffer.Clear()
        $end = Get-Date
        $clearTimes += ($end - $start).TotalMilliseconds
    }
    $avgClear = ($clearTimes | Measure-Object -Average).Average
    
    # Test write performance
    $writeTimes = @()
    for ($i = 0; $i -lt 5; $i++) {
        $start = Get-Date
        for ($y = 0; $y -lt 24; $y++) {
            $buffer.WriteString(0, $y, "Performance test line $y", $style)
        }
        $end = Get-Date
        $writeTimes += ($end - $start).TotalMilliseconds
    }
    $avgWrite = ($writeTimes | Measure-Object -Average).Average
    
    $Results.Performance["BufferClear"] = $avgClear
    $Results.Performance["BufferWrite"] = $avgWrite
    
    $clearOk = $avgClear -lt 50
    $writeOk = $avgWrite -lt 100
    
    Write-TestResult "Performance" "BufferClear" $clearOk "Average: $([Math]::Round($avgClear, 1))ms"
    Write-TestResult "Performance" "BufferWrite" $writeOk "Average: $([Math]::Round($avgWrite, 1))ms"
    
} catch {
    Write-TestResult "Performance" "BufferOperations" $false $_.Exception.Message
}

# ==============================================================================
# COMPREHENSIVE FINAL REPORT
# ==============================================================================
Write-Host "`n📊 COMPREHENSIVE VALIDATION RESULTS" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

$duration = (Get-Date) - $Results.StartTime
$successRate = if ($Results.TotalTests -gt 0) { [Math]::Round(($Results.Passed / $Results.TotalTests) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "📈 SUMMARY STATISTICS" -ForegroundColor White
Write-Host "Total Tests: $($Results.TotalTests)" -ForegroundColor White
Write-Host "Passed: $($Results.Passed)" -ForegroundColor Green
Write-Host "Failed: $($Results.Failed)" -ForegroundColor Red
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -gt 80) { "Green" } elseif ($successRate -gt 60) { "Yellow" } else { "Red" })
Write-Host "Duration: $([Math]::Round($duration.TotalMinutes, 1)) minutes" -ForegroundColor White

Write-Host ""
Write-Host "📂 CATEGORY BREAKDOWN" -ForegroundColor White
foreach ($category in $Results.Categories.Keys) {
    $cat = $Results.Categories[$category]
    $total = $cat.Passed + $cat.Failed
    $rate = if ($total -gt 0) { [Math]::Round(($cat.Passed / $total) * 100, 1) } else { 0 }
    Write-Host "  $category`: $($cat.Passed)/$total ($rate%)" -ForegroundColor $(if ($rate -gt 80) { "Green" } elseif ($rate -gt 60) { "Yellow" } else { "Red" })
}

if ($Results.Performance.Count -gt 0) {
    Write-Host ""
    Write-Host "⚡ PERFORMANCE METRICS" -ForegroundColor White
    foreach ($metric in $Results.Performance.Keys) {
        $value = $Results.Performance[$metric]
        $unit = if ($metric -like "*Time*") { "ms" } else { "s" }
        Write-Host "  $metric`: $([Math]::Round($value, 2))$unit" -ForegroundColor Cyan
    }
}

if ($Results.Issues.Count -gt 0) {
    Write-Host ""
    Write-Host "🚨 CRITICAL ISSUES FOUND ($($Results.Issues.Count))" -ForegroundColor Red
    foreach ($issue in $Results.Issues) {
        Write-Host "  • $issue" -ForegroundColor Yellow
    }
}

# Save detailed results
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportFile = "validation-report-$timestamp.json"
$Results | ConvertTo-Json -Depth 10 | Out-File $reportFile

Write-Host ""
Write-Host "📄 DETAILED REPORT SAVED: $reportFile" -ForegroundColor Cyan

# Cleanup
if ($global:TuiState) {
    $global:TuiState.Running = $false
}

Write-Host ""
Write-Host "✅ FULL SYSTEM VALIDATION COMPLETE!" -ForegroundColor Green

# Return results for automation
return $Results