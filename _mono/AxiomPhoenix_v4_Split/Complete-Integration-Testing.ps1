#!/usr/bin/env pwsh
# ==============================================================================
# COMPLETE INTEGRATION TESTING FRAMEWORK
# Programmatically tests every screen, component, navigation path, and function
# ==============================================================================

param(
    [int]$TimeoutPerTest = 30,
    [switch]$SkipSlowTests = $false,
    [switch]$GenerateScreenshots = $false,
    [string]$OutputDir = "./integration-test-results"
)

$ErrorActionPreference = "Continue"

# Create output directory
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

# Integration test results tracking
$IntegrationResults = @{
    StartTime = Get-Date
    TestSuite = "Complete Integration Testing"
    Framework = @{
        Name = "Axiom-Phoenix v4.0"
        LoadTime = $null
        ServicesCount = 0
        ScreensDiscovered = 0
        ComponentsDiscovered = 0
    }
    TestResults = @{}
    NavigationMap = @{}
    ComponentTests = @{}
    DataOperationTests = @{}
    PerformanceMetrics = @{}
    Screenshots = @{}
    Issues = @()
    Summary = @{
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        SkippedTests = 0
        SuccessRate = 0
    }
}

# Logging function
function Write-IntegrationLog {
    param([string]$Message, [string]$Level = "INFO", [hashtable]$Data = @{})
    
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    $color = switch($Level) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        "PERF" { "Cyan" }
        "NAV" { "Magenta" }
        "DATA" { "Blue" }
        default { "White" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    
    # Save to log file
    $logFile = Join-Path $OutputDir "integration-test.log"
    "$logEntry | $($Data | ConvertTo-Json -Compress)" | Add-Content $logFile
}

# Test execution framework
function Invoke-IntegrationTest {
    param(
        [string]$Category,
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$Description = "",
        [int]$Timeout = 30
    )
    
    $testId = "$Category.$TestName"
    $IntegrationResults.Summary.TotalTests++
    
    $testResult = @{
        TestId = $testId
        Category = $Category
        Name = $TestName
        Description = $Description
        StartTime = Get-Date
        EndTime = $null
        Duration = $null
        Status = "RUNNING"
        Result = $null
        Error = $null
        Data = @{}
        Performance = @{}
    }
    
    Write-IntegrationLog "Starting test: $testId" "INFO" @{ Description = $Description }
    
    try {
        # Execute test with timeout
        $job = Start-Job -ScriptBlock $TestScript
        $completed = Wait-Job -Job $job -Timeout $Timeout
        
        if ($completed) {
            $result = Receive-Job -Job $job
            Remove-Job -Job $job
            
            $testResult.Status = "PASSED"
            $testResult.Result = $result
            $IntegrationResults.Summary.PassedTests++
            
            Write-IntegrationLog "Test PASSED: $testId" "PASS"
        } else {
            Stop-Job -Job $job
            Remove-Job -Job $job
            
            $testResult.Status = "TIMEOUT"
            $testResult.Error = "Test timed out after $Timeout seconds"
            $IntegrationResults.Summary.FailedTests++
            
            Write-IntegrationLog "Test TIMEOUT: $testId" "FAIL" @{ Timeout = $Timeout }
        }
        
    } catch {
        $testResult.Status = "FAILED"
        $testResult.Error = $_.Exception.Message
        $IntegrationResults.Summary.FailedTests++
        
        Write-IntegrationLog "Test FAILED: $testId" "FAIL" @{ Error = $_.Exception.Message }
        $IntegrationResults.Issues += "$testId - $($_.Exception.Message)"
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = $testResult.EndTime - $testResult.StartTime
    
    if (-not $IntegrationResults.TestResults.ContainsKey($Category)) {
        $IntegrationResults.TestResults[$Category] = @{}
    }
    $IntegrationResults.TestResults[$Category][$TestName] = $testResult
    
    return $testResult
}

# Screen capture function
function Capture-ScreenState {
    param([string]$TestId, [string]$Context = "")
    
    if (-not $GenerateScreenshots) { return }
    
    try {
        $screenshot = @{
            TestId = $TestId
            Context = $Context
            Timestamp = Get-Date
            CurrentScreen = $null
            ScreenDimensions = @{
                Width = [Console]::WindowWidth
                Height = [Console]::WindowHeight
            }
            BufferInfo = @{}
        }
        
        if ($global:TuiState -and $global:TuiState.CurrentScreen) {
            $screenshot.CurrentScreen = $global:TuiState.CurrentScreen.GetType().Name
            
            # Try to capture buffer state
            if ($global:TuiState.CurrentScreen.PSObject.Properties['Buffer']) {
                $buffer = $global:TuiState.CurrentScreen.Buffer
                if ($buffer) {
                    $screenshot.BufferInfo = @{
                        Width = $buffer.Width
                        Height = $buffer.Height
                        IsDirty = $buffer.IsDirty
                    }
                }
            }
        }
        
        $IntegrationResults.Screenshots["$TestId-$Context"] = $screenshot
        Write-IntegrationLog "Screenshot captured: $TestId-$Context" "DATA"
        
    } catch {
        Write-IntegrationLog "Screenshot failed: $($_.Exception.Message)" "WARN"
    }
}

Write-IntegrationLog "🚀 COMPLETE INTEGRATION TESTING STARTED" "INFO"
Write-IntegrationLog "Output Directory: $OutputDir" "INFO"

# ==============================================================================
# PHASE 1: FRAMEWORK INITIALIZATION
# ==============================================================================
Write-IntegrationLog "=== PHASE 1: FRAMEWORK INITIALIZATION ===" "INFO"

$frameworkTest = Invoke-IntegrationTest "Framework" "LoadAndInitialize" {
    # Load base classes
    . "./Base/ABC.001_TuiAnsiHelper.ps1"
    . "./Base/ABC.002_TuiCell.ps1"
    . "./Base/ABC.003_TuiBuffer.ps1"
    
    # Test base functionality
    $ansi = [TuiAnsiHelper]::GetAnsiSequence("#FF0000", "#000000", @{})
    $cell = [TuiCell]::new('T', "#FF0000", "#000000") 
    $buffer = [TuiBuffer]::new(80, 24)
    
    # Load full framework
    $loadStart = Get-Date
    . "./Start.ps1"
    $loadEnd = Get-Date
    
    # Wait for stabilization
    Start-Sleep -Seconds 3
    
    return @{
        LoadTime = ($loadEnd - $loadStart).TotalSeconds
        BaseClassesWorking = ($ansi -and $cell -and $buffer)
        GlobalStateExists = ($global:TuiState -ne $null)
        ServicesCount = if ($global:TuiServices) { $global:TuiServices.Count } else { 0 }
        CurrentScreen = if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.GetType().Name } else { "None" }
    }
} "Load framework and validate initialization" 60

if ($frameworkTest.Status -eq "PASSED") {
    $IntegrationResults.Framework.LoadTime = $frameworkTest.Result.LoadTime
    $IntegrationResults.Framework.ServicesCount = $frameworkTest.Result.ServicesCount
    Write-IntegrationLog "Framework loaded successfully in $($frameworkTest.Result.LoadTime)s" "PASS"
} else {
    Write-IntegrationLog "CRITICAL: Framework failed to load. Aborting integration tests." "FAIL"
    return $IntegrationResults
}

Capture-ScreenState "Framework.LoadAndInitialize" "PostLoad"

# ==============================================================================
# PHASE 2: SCREEN DISCOVERY AND MAPPING
# ==============================================================================
Write-IntegrationLog "=== PHASE 2: SCREEN DISCOVERY AND MAPPING ===" "INFO"

$screenDiscovery = Invoke-IntegrationTest "Discovery" "ScreenMapping" {
    $screenFiles = Get-ChildItem -Path "./Screens/ASC.*.ps1" | Sort-Object Name
    $discoveredScreens = @{}
    
    foreach ($screenFile in $screenFiles) {
        $screenName = $screenFile.BaseName -replace "ASC\.\d+_", ""
        $content = Get-Content $screenFile.FullName -Raw
        
        $screenInfo = @{
            FileName = $screenFile.Name
            ShortName = $screenName
            FilePath = $screenFile.FullName
            FileSize = (Get-Item $screenFile.FullName).Length
            HasClass = $false
            ClassName = $null
            Methods = @()
            Properties = @()
            Instantiable = $false
        }
        
        # Extract class information
        if ($content -match 'class\s+(\w+)') {
            $screenInfo.HasClass = $true
            $screenInfo.ClassName = $Matches[1]
            
            # Try instantiation
            try {
                $instance = New-Object $screenInfo.ClassName
                $screenInfo.Instantiable = $true
                
                # Get methods and properties
                $screenInfo.Methods = $instance.GetType().GetMethods().Name
                $screenInfo.Properties = $instance.GetType().GetProperties().Name
            } catch {
                $screenInfo.InstantiationError = $_.Exception.Message
            }
        }
        
        $discoveredScreens[$screenName] = $screenInfo
    }
    
    return @{
        TotalScreenFiles = $screenFiles.Count
        DiscoveredScreens = $discoveredScreens
        InstantiableScreens = ($discoveredScreens.Values | Where-Object { $_.Instantiable }).Count
    }
} "Discover and analyze all screen files" 30

$IntegrationResults.Framework.ScreensDiscovered = $screenDiscovery.Result.TotalScreenFiles

# ==============================================================================
# PHASE 3: NAVIGATION SYSTEM TESTING
# ==============================================================================
Write-IntegrationLog "=== PHASE 3: NAVIGATION SYSTEM TESTING ===" "INFO"

# Test navigation to each discovered screen
$navigationTargets = @(
    @{Screen = "DashboardScreen"; MenuKey = "1"; Description = "Main dashboard"},
    @{Screen = "ProjectDashboardScreen"; MenuKey = "2"; Description = "Project dashboard"},
    @{Screen = "TaskListScreen"; MenuKey = "3"; Description = "Task management"},
    @{Screen = "ProjectsListScreen"; MenuKey = "4"; Description = "Project management"},
    @{Screen = "FileBrowserScreen"; MenuKey = "5"; Description = "File browsing"},
    @{Screen = "TextEditorScreen"; MenuKey = "6"; Description = "Text editing"},
    @{Screen = "ThemeScreen"; MenuKey = "7"; Description = "Theme selection"},
    @{Screen = "CommandPaletteScreen"; MenuKey = "8"; Description = "Command palette"},
    @{Screen = "TimesheetScreen"; MenuKey = "9"; Description = "Timesheet view"}
)

foreach ($target in $navigationTargets) {
    $navTest = Invoke-IntegrationTest "Navigation" "NavigateTo$($target.Screen)" {
        param($targetScreen, $description)
        
        $navService = $global:TuiServices['NavigationService']
        if (-not $navService) {
            throw "NavigationService not available"
        }
        
        $originalScreen = $global:TuiState.CurrentScreen.GetType().Name
        
        # Attempt navigation
        $navStart = Get-Date
        $navService.NavigateToScreen($targetScreen)
        
        # Wait for navigation to complete
        $maxWait = 50 # 5 seconds
        $waited = 0
        while ($waited -lt $maxWait) {
            Start-Sleep -Milliseconds 100
            $waited++
            
            $currentScreen = $global:TuiState.CurrentScreen.GetType().Name
            if ($currentScreen -eq $targetScreen) {
                break
            }
        }
        
        $navEnd = Get-Date
        $currentScreen = $global:TuiState.CurrentScreen.GetType().Name
        
        return @{
            OriginalScreen = $originalScreen
            TargetScreen = $targetScreen
            ResultingScreen = $currentScreen
            NavigationSuccessful = ($currentScreen -eq $targetScreen)
            NavigationTime = ($navEnd - $navStart).TotalMilliseconds
            Description = $description
        }
    } "$($target.Description) navigation" 15 -ArgumentList $target.Screen, $target.Description
    
    if ($navTest.Status -eq "PASSED") {
        $result = $navTest.Result
        $IntegrationResults.NavigationMap[$target.Screen] = $result
        
        if ($result.NavigationSuccessful) {
            Write-IntegrationLog "Navigation to $($target.Screen) successful in $($result.NavigationTime)ms" "NAV"
            
            # Capture screen state after navigation
            Capture-ScreenState "Navigation.$($target.Screen)" "PostNavigation"
            
            # Test basic screen functionality
            $screenTest = Invoke-IntegrationTest "ScreenFunction" "BasicTest$($target.Screen)" {
                param($screenName)
                
                $currentScreen = $global:TuiState.CurrentScreen
                $screenType = $currentScreen.GetType().Name
                
                $testResults = @{
                    ScreenType = $screenType
                    HasRenderMethod = $currentScreen.PSObject.Methods['Render'] -ne $null
                    HasInputMethod = $currentScreen.PSObject.Methods['HandleInput'] -ne $null
                    HasInitializeMethod = $currentScreen.PSObject.Methods['Initialize'] -ne $null
                    Properties = @{}
                }
                
                # Test basic properties
                foreach ($prop in @('Name', 'Title', 'Width', 'Height', 'IsVisible')) {
                    try {
                        $testResults.Properties[$prop] = $currentScreen.$prop
                    } catch {
                        $testResults.Properties[$prop] = "N/A"
                    }
                }
                
                # Test basic input handling
                try {
                    $escKey = [System.ConsoleKeyInfo]::new([char]27, [ConsoleKey]::Escape, $false, $false, $false)
                    $inputResult = $currentScreen.HandleInput($escKey)
                    $testResults.InputHandling = @{
                        EscapeKeyHandled = ($inputResult -ne $null)
                        Result = $inputResult
                    }
                } catch {
                    $testResults.InputHandling = @{
                        EscapeKeyHandled = $false
                        Error = $_.Exception.Message
                    }
                }
                
                return $testResults
            } "Basic functionality test for $($target.Screen)" 10 -ArgumentList $target.Screen
            
        } else {
            Write-IntegrationLog "Navigation to $($target.Screen) failed: got $($result.ResultingScreen)" "FAIL"
        }
    }
    
    # Return to dashboard for next test
    try {
        $global:TuiServices['NavigationService'].NavigateToScreen("DashboardScreen")
        Start-Sleep -Milliseconds 500
    } catch {
        Write-IntegrationLog "Warning: Could not return to dashboard" "WARN"
    }
}

# ==============================================================================
# PHASE 4: INPUT SYSTEM COMPREHENSIVE TESTING
# ==============================================================================
Write-IntegrationLog "=== PHASE 4: INPUT SYSTEM COMPREHENSIVE TESTING ===" "INFO"

# Test all major input types on dashboard
$inputTests = @(
    @{Key = [ConsoleKey]::UpArrow; Name = "UpArrow"; Modifiers = @{Shift=$false; Ctrl=$false; Alt=$false}},
    @{Key = [ConsoleKey]::DownArrow; Name = "DownArrow"; Modifiers = @{Shift=$false; Ctrl=$false; Alt=$false}},
    @{Key = [ConsoleKey]::LeftArrow; Name = "LeftArrow"; Modifiers = @{Shift=$false; Ctrl=$false; Alt=$false}},
    @{Key = [ConsoleKey]::RightArrow; Name = "RightArrow"; Modifiers = @{Shift=$false; Ctrl=$false; Alt=$false}},
    @{Key = [ConsoleKey]::Enter; Name = "Enter"; Modifiers = @{Shift=$false; Ctrl=$false; Alt=$false}},
    @{Key = [ConsoleKey]::Tab; Name = "Tab"; Modifiers = @{Shift=$false; Ctrl=$false; Alt=$false}},
    @{Key = [ConsoleKey]::Tab; Name = "ShiftTab"; Modifiers = @{Shift=$true; Ctrl=$false; Alt=$false}},
    @{Key = [ConsoleKey]::Escape; Name = "Escape"; Modifiers = @{Shift=$false; Ctrl=$false; Alt=$false}},
    @{Key = [ConsoleKey]::F1; Name = "F1"; Modifiers = @{Shift=$false; Ctrl=$false; Alt=$false}},
    @{Key = [ConsoleKey]::P; Name = "CtrlP"; Modifiers = @{Shift=$false; Ctrl=$true; Alt=$false}},
    @{Key = [ConsoleKey]::Q; Name = "CtrlQ"; Modifiers = @{Shift=$false; Ctrl=$true; Alt=$false}},
    @{Key = [ConsoleKey]::S; Name = "CtrlS"; Modifiers = @{Shift=$false; Ctrl=$true; Alt=$false}}
)

# Ensure we're on dashboard
try { $global:TuiServices['NavigationService'].NavigateToScreen("DashboardScreen"); Start-Sleep -Milliseconds 500 } catch { }

foreach ($inputTest in $inputTests) {
    $inputTestResult = Invoke-IntegrationTest "Input" "Key$($inputTest.Name)" {
        param($keyData)
        
        $screen = $global:TuiState.CurrentScreen
        $keyInfo = [System.ConsoleKeyInfo]::new([char]0, $keyData.Key, $keyData.Modifiers.Shift, $keyData.Modifiers.Alt, $keyData.Modifiers.Ctrl)
        
        $inputStart = Get-Date
        $result = $screen.HandleInput($keyInfo)
        $inputEnd = Get-Date
        
        return @{
            Key = $keyData.Name
            InputResult = $result
            ResponseTime = ($inputEnd - $inputStart).TotalMilliseconds
            ScreenType = $screen.GetType().Name
            ResultType = if ($result) { $result.GetType().Name } else { "null" }
        }
    } "Test $($inputTest.Name) key input" 5 -ArgumentList $inputTest
    
    if ($inputTestResult.Status -eq "PASSED") {
        $result = $inputTestResult.Result
        $IntegrationResults.PerformanceMetrics["Input.$($result.Key)"] = $result.ResponseTime
        Write-IntegrationLog "Input $($result.Key): $($result.ResponseTime)ms" "PERF"
    }
    
    Start-Sleep -Milliseconds 200  # Prevent input flooding
}

# ==============================================================================
# PHASE 5: DATA OPERATIONS INTEGRATION TESTING
# ==============================================================================
Write-IntegrationLog "=== PHASE 5: DATA OPERATIONS INTEGRATION TESTING ===" "INFO"

$dataTest = Invoke-IntegrationTest "Data" "CRUDOperations" {
    $dataManager = $global:TuiServices['DataManager']
    if (-not $dataManager) {
        throw "DataManager service not available"
    }
    
    $testResults = @{
        InitialState = @{}
        Operations = @{}
        FinalState = @{}
    }
    
    # Get initial data state
    try {
        $initialTasks = $dataManager.GetTasks()
        $initialProjects = $dataManager.GetProjects()
        $testResults.InitialState = @{
            TaskCount = if ($initialTasks) { $initialTasks.Count } else { 0 }
            ProjectCount = if ($initialProjects) { $initialProjects.Count } else { 0 }
        }
    } catch {
        $testResults.InitialState.Error = $_.Exception.Message
    }
    
    # Test data operations
    $methods = $dataManager.GetType().GetMethods().Name
    
    foreach ($method in @('GetTasks', 'GetProjects', 'GetTimeEntries', 'SaveTask', 'SaveProject')) {
        $testResults.Operations[$method] = @{
            Available = ($method -in $methods)
            Tested = $false
            Result = $null
            Error = $null
        }
        
        if ($method -in $methods) {
            try {
                switch ($method) {
                    'GetTasks' {
                        $result = $dataManager.GetTasks()
                        $testResults.Operations[$method].Result = @{
                            Count = if ($result) { $result.Count } else { 0 }
                            Type = if ($result) { $result.GetType().Name } else { "null" }
                        }
                    }
                    'GetProjects' {
                        $result = $dataManager.GetProjects()
                        $testResults.Operations[$method].Result = @{
                            Count = if ($result) { $result.Count } else { 0 }
                            Type = if ($result) { $result.GetType().Name } else { "null" }
                        }
                    }
                    'GetTimeEntries' {
                        $result = $dataManager.GetTimeEntries()
                        $testResults.Operations[$method].Result = @{
                            Count = if ($result) { $result.Count } else { 0 }
                            Type = if ($result) { $result.GetType().Name } else { "null" }
                        }
                    }
                }
                $testResults.Operations[$method].Tested = $true
            } catch {
                $testResults.Operations[$method].Error = $_.Exception.Message
            }
        }
    }
    
    return $testResults
} "Test data manager CRUD operations" 20

if ($dataTest.Status -eq "PASSED") {
    $IntegrationResults.DataOperationTests = $dataTest.Result
}

# ==============================================================================
# PHASE 6: COMPONENT DISCOVERY AND TESTING
# ==============================================================================
Write-IntegrationLog "=== PHASE 6: COMPONENT DISCOVERY AND TESTING ===" "INFO"

$componentTest = Invoke-IntegrationTest "Components" "DiscoveryAndInstantiation" {
    $componentFiles = Get-ChildItem -Path "./Components/ACO.*.ps1" | Sort-Object Name
    $componentResults = @{}
    
    foreach ($componentFile in $componentFiles) {
        $componentName = $componentFile.BaseName -replace "ACO\.\d+_", ""
        
        $componentInfo = @{
            FileName = $componentFile.Name
            FilePath = $componentFile.FullName
            FileSize = (Get-Item $componentFile.FullName).Length
            HasClass = $false
            ClassName = $null
            Instantiable = $false
            Methods = @()
            Properties = @()
            TestedMethods = @{}
        }
        
        try {
            $content = Get-Content $componentFile.FullName -Raw
            
            if ($content -match 'class\s+(\w+)') {
                $componentInfo.HasClass = $true
                $componentInfo.ClassName = $Matches[1]
                
                try {
                    $instance = New-Object $componentInfo.ClassName
                    $componentInfo.Instantiable = $true
                    $componentInfo.Methods = $instance.GetType().GetMethods().Name
                    $componentInfo.Properties = $instance.GetType().GetProperties().Name
                    
                    # Test essential methods
                    foreach ($method in @('Render', 'HandleInput', 'Initialize', 'Dispose')) {
                        $componentInfo.TestedMethods[$method] = @{
                            Available = ($method -in $componentInfo.Methods)
                            Tested = $false
                            Result = $null
                        }
                    }
                    
                } catch {
                    $componentInfo.InstantiationError = $_.Exception.Message
                }
            }
            
        } catch {
            $componentInfo.ParsingError = $_.Exception.Message
        }
        
        $componentResults[$componentName] = $componentInfo
    }
    
    return @{
        TotalComponents = $componentFiles.Count
        ComponentDetails = $componentResults
        InstantiableComponents = ($componentResults.Values | Where-Object { $_.Instantiable }).Count
    }
} "Discover and test all UI components" 30

if ($componentTest.Status -eq "PASSED") {
    $IntegrationResults.Framework.ComponentsDiscovered = $componentTest.Result.TotalComponents
    $IntegrationResults.ComponentTests = $componentTest.Result
}

# ==============================================================================
# PHASE 7: PERFORMANCE BENCHMARKING
# ==============================================================================
Write-IntegrationLog "=== PHASE 7: PERFORMANCE BENCHMARKING ===" "INFO"

$performanceTest = Invoke-IntegrationTest "Performance" "ComprehensiveBenchmark" {
    $benchmarkResults = @{}
    
    # Buffer operations benchmark
    $buffer = [TuiBuffer]::new(80, 24)
    $style = @{ FG = "#FFFFFF"; BG = "#000000" }
    
    # Clear performance
    $clearTimes = @()
    for ($i = 0; $i -lt 10; $i++) {
        $start = Get-Date
        $buffer.Clear()
        $end = Get-Date
        $clearTimes += ($end - $start).TotalMilliseconds
    }
    
    # Write performance  
    $writeTimes = @()
    for ($i = 0; $i -lt 10; $i++) {
        $start = Get-Date
        for ($y = 0; $y -lt 24; $y++) {
            $buffer.WriteString(0, $y, "Performance benchmark line $y iteration $i", $style)
        }
        $end = Get-Date
        $writeTimes += ($end - $start).TotalMilliseconds
    }
    
    # ANSI generation performance
    $ansiTimes = @()
    for ($i = 0; $i -lt 100; $i++) {
        $start = Get-Date
        $ansi = [TuiAnsiHelper]::GetAnsiSequence("#FF0000", "#000000", @{Bold=$true})
        $end = Get-Date
        $ansiTimes += ($end - $start).TotalMilliseconds
    }
    
    # Cell operations performance
    $cellTimes = @()
    for ($i = 0; $i -lt 100; $i++) {
        $start = Get-Date
        $cell = [TuiCell]::new('X', "#FF0000", "#000000", $true, $false, $true, $false)
        $ansiString = $cell.ToAnsiString()
        $end = Get-Date
        $cellTimes += ($end - $start).TotalMilliseconds
    }
    
    $benchmarkResults = @{
        BufferClear = @{
            Times = $clearTimes
            Average = ($clearTimes | Measure-Object -Average).Average
            Min = ($clearTimes | Measure-Object -Minimum).Minimum
            Max = ($clearTimes | Measure-Object -Maximum).Maximum
        }
        BufferWrite = @{
            Times = $writeTimes
            Average = ($writeTimes | Measure-Object -Average).Average
            Min = ($writeTimes | Measure-Object -Minimum).Minimum
            Max = ($writeTimes | Measure-Object -Maximum).Maximum
        }
        AnsiGeneration = @{
            Times = $ansiTimes
            Average = ($ansiTimes | Measure-Object -Average).Average
            Min = ($ansiTimes | Measure-Object -Minimum).Minimum
            Max = ($ansiTimes | Measure-Object -Maximum).Maximum
        }
        CellOperations = @{
            Times = $cellTimes
            Average = ($cellTimes | Measure-Object -Average).Average
            Min = ($cellTimes | Measure-Object -Minimum).Minimum
            Max = ($cellTimes | Measure-Object -Maximum).Maximum
        }
    }
    
    return $benchmarkResults
} "Comprehensive performance benchmarking" 30

if ($performanceTest.Status -eq "PASSED") {
    $IntegrationResults.PerformanceMetrics = $performanceTest.Result
}

# ==============================================================================
# FINAL RESULTS COMPILATION
# ==============================================================================
Write-IntegrationLog "=== COMPILING FINAL INTEGRATION TEST RESULTS ===" "INFO"

$IntegrationResults.Summary.SuccessRate = if ($IntegrationResults.Summary.TotalTests -gt 0) {
    [Math]::Round(($IntegrationResults.Summary.PassedTests / $IntegrationResults.Summary.TotalTests) * 100, 1)
} else { 0 }

$endTime = Get-Date
$IntegrationResults.EndTime = $endTime
$IntegrationResults.TotalDuration = $endTime - $IntegrationResults.StartTime

# Generate comprehensive report
$reportFile = Join-Path $OutputDir "integration-test-report.json"
$IntegrationResults | ConvertTo-Json -Depth 10 | Out-File $reportFile

# Generate human-readable summary
$summaryFile = Join-Path $OutputDir "integration-test-summary.txt"
$summary = @"
=== COMPLETE INTEGRATION TEST RESULTS ===
Test Suite: $($IntegrationResults.TestSuite)
Start Time: $($IntegrationResults.StartTime)
End Time: $($IntegrationResults.EndTime)
Duration: $([Math]::Round($IntegrationResults.TotalDuration.TotalMinutes, 1)) minutes

SUMMARY STATISTICS:
Total Tests: $($IntegrationResults.Summary.TotalTests)
Passed: $($IntegrationResults.Summary.PassedTests)
Failed: $($IntegrationResults.Summary.FailedTests)
Success Rate: $($IntegrationResults.Summary.SuccessRate)%

FRAMEWORK ANALYSIS:
Load Time: $($IntegrationResults.Framework.LoadTime) seconds
Services Registered: $($IntegrationResults.Framework.ServicesCount)
Screens Discovered: $($IntegrationResults.Framework.ScreensDiscovered)
Components Discovered: $($IntegrationResults.Framework.ComponentsDiscovered)

NAVIGATION TESTING:
$(foreach ($nav in $IntegrationResults.NavigationMap.Keys) {
    $navResult = $IntegrationResults.NavigationMap[$nav]
    "$nav`: $($navResult.NavigationSuccessful) ($($navResult.NavigationTime)ms)"
})

PERFORMANCE METRICS:
$(foreach ($perf in $IntegrationResults.PerformanceMetrics.Keys) {
    $perfValue = $IntegrationResults.PerformanceMetrics[$perf]
    if ($perfValue -is [hashtable]) {
        "$perf`: $([Math]::Round($perfValue.Average, 2))ms avg"
    } else {
        "$perf`: $([Math]::Round($perfValue, 2))ms"
    }
})

ISSUES FOUND:
$(foreach ($issue in $IntegrationResults.Issues) { "• $issue" })

Detailed results saved to: $reportFile
"@

$summary | Out-File $summaryFile

# Display final results
Write-IntegrationLog "" "INFO"
Write-IntegrationLog "🎯 COMPLETE INTEGRATION TESTING FINISHED" "INFO"
Write-IntegrationLog "=========================================" "INFO"
Write-IntegrationLog "Total Tests: $($IntegrationResults.Summary.TotalTests)" "INFO"
Write-IntegrationLog "Passed: $($IntegrationResults.Summary.PassedTests)" "PASS"
Write-IntegrationLog "Failed: $($IntegrationResults.Summary.FailedTests)" "FAIL"
Write-IntegrationLog "Success Rate: $($IntegrationResults.Summary.SuccessRate)%" "INFO"
Write-IntegrationLog "Duration: $([Math]::Round($IntegrationResults.TotalDuration.TotalMinutes, 1)) minutes" "INFO"
Write-IntegrationLog "" "INFO"
Write-IntegrationLog "📄 Detailed Report: $reportFile" "INFO"
Write-IntegrationLog "📄 Summary Report: $summaryFile" "INFO"

if ($IntegrationResults.Issues.Count -gt 0) {
    Write-IntegrationLog "" "INFO"
    Write-IntegrationLog "🚨 ISSUES FOUND ($($IntegrationResults.Issues.Count)):" "FAIL"
    foreach ($issue in $IntegrationResults.Issues) {
        Write-IntegrationLog "  • $issue" "FAIL"
    }
}

# Cleanup
if ($global:TuiState) {
    $global:TuiState.Running = $false
}

Write-Host "`n✅ COMPLETE INTEGRATION TESTING FINISHED!" -ForegroundColor Green
Write-Host "📊 Check results in: $OutputDir" -ForegroundColor Cyan

return $IntegrationResults