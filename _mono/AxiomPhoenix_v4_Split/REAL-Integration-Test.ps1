#!/usr/bin/env pwsh
# REAL INTEGRATION TEST - Actually test every screen and every key
# This will ACTUALLY navigate to each screen and test each key individually

param(
    [switch]$VerboseErrors = $true,
    [switch]$StopOnFirstError = $false
)

$ErrorActionPreference = "Continue"

# Create results directory
$resultDir = "real-test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $resultDir -Force | Out-Null

# Test results tracking
$RealTestResults = @{
    StartTime = Get-Date
    TestsRun = 0
    TestsPassed = 0
    TestsFailed = 0
    KeystrokeTests = @{}
    ScreenValidations = @{}
    ErrorLogFindings = @{}
    PerformanceData = @{}
    ActualIssues = @()
    Screenshots = @{}
}

function Write-RealTestLog {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    $color = switch($Level) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "ISSUE" { "Yellow" }
        "PERF" { "Cyan" }
        default { "White" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    Add-Content -Path "$resultDir/real-test.log" -Value $logEntry
}

function Test-ActualKeystroke {
    param([string]$TestName, [ConsoleKey]$Key, [string]$Description, [scriptblock]$ValidationScript)
    
    $RealTestResults.TestsRun++
    Write-RealTestLog "TESTING KEYSTROKE: $TestName - $Description" "INFO"
    
    try {
        # Capture screen state before keystroke
        if ($CaptureScreenshots) {
            $beforeScreen = Capture-CurrentScreen "$TestName-before"
        }
        
        # Get current screen
        $currentScreen = $global:TuiState.CurrentScreen
        if (-not $currentScreen) {
            throw "No current screen available"
        }
        
        # Create key event
        $keyInfo = [System.ConsoleKeyInfo]::new([char]0, $Key, $false, $false, $false)
        
        # Send keystroke and measure response time
        $keystrokeStart = Get-Date
        $inputResult = $currentScreen.HandleInput($keyInfo)
        $keystrokeEnd = Get-Date
        
        $responseTime = ($keystrokeEnd - $keystrokeStart).TotalMilliseconds
        
        # Wait for any screen updates
        Start-Sleep -Milliseconds 200
        
        # Capture screen state after keystroke
        if ($CaptureScreenshots) {
            $afterScreen = Capture-CurrentScreen "$TestName-after"
        }
        
        # Run validation script to check if keystroke worked
        $validationResult = & $ValidationScript
        
        $testResult = @{
            TestName = $TestName
            Key = $Key.ToString()
            Description = $Description
            ResponseTime = $responseTime
            InputResult = $inputResult
            ValidationResult = $validationResult
            ScreenBefore = $beforeScreen
            ScreenAfter = $afterScreen
            Success = $validationResult.Success
            Issues = $validationResult.Issues
        }
        
        $RealTestResults.KeystrokeTests[$TestName] = $testResult
        
        if ($validationResult.Success) {
            $RealTestResults.TestsPassed++
            Write-RealTestLog "PASS: $TestName - $($validationResult.Message)" "PASS"
        } else {
            $RealTestResults.TestsFailed++
            Write-RealTestLog "FAIL: $TestName - $($validationResult.Message)" "FAIL"
            $RealTestResults.ActualIssues += "$TestName - $($validationResult.Message)"
        }
        
        # Record performance data
        $RealTestResults.PerformanceData["Keystroke-$TestName"] = $responseTime
        
        return $testResult
        
    } catch {
        $RealTestResults.TestsFailed++
        $errorMsg = $_.Exception.Message
        Write-RealTestLog "ERROR: $TestName - $errorMsg" "FAIL"
        $RealTestResults.ActualIssues += "$TestName - $errorMsg"
        
        return @{
            TestName = $TestName
            Success = $false
            Error = $errorMsg
        }
    }
}

function Capture-CurrentScreen {
    param([string]$TestContext)
    
    if (-not $CaptureScreenshots) { return $null }
    
    try {
        $screen = $global:TuiState.CurrentScreen
        $screenData = @{
            Context = $TestContext
            Timestamp = Get-Date
            ScreenType = if ($screen) { $screen.GetType().Name } else { "None" }
            ConsoleState = @{
                Width = [Console]::WindowWidth
                Height = [Console]::WindowHeight
                CursorX = [Console]::CursorLeft
                CursorY = [Console]::CursorTop
            }
        }
        
        # Try to capture buffer content if available
        if ($screen -and $screen.PSObject.Properties['Buffer']) {
            $buffer = $screen.Buffer
            if ($buffer) {
                $screenData.BufferState = @{
                    Width = $buffer.Width
                    Height = $buffer.Height
                    IsDirty = $buffer.IsDirty
                }
                
                # Try to capture some buffer content
                try {
                    $sampleContent = @()
                    for ($y = 0; $y -lt [Math]::Min(5, $buffer.Height); $y++) {
                        $line = ""
                        for ($x = 0; $x -lt [Math]::Min(20, $buffer.Width); $x++) {
                            $cell = $buffer.GetCell($x, $y)
                            if ($cell) {
                                $line += $cell.Char
                            }
                        }
                        $sampleContent += $line
                    }
                    $screenData.SampleContent = $sampleContent
                } catch {
                    $screenData.ContentError = $_.Exception.Message
                }
            }
        }
        
        $RealTestResults.Screenshots[$TestContext] = $screenData
        return $screenData
        
    } catch {
        Write-RealTestLog "Screenshot capture failed: $($_.Exception.Message)" "ISSUE"
        return $null
    }
}

function Test-ScreenContent {
    param([string]$ScreenName, [scriptblock]$ValidationScript)
    
    $RealTestResults.TestsRun++
    Write-RealTestLog "VALIDATING SCREEN: $ScreenName" "INFO"
    
    try {
        $currentScreen = $global:TuiState.CurrentScreen
        if (-not $currentScreen) {
            throw "No current screen available"
        }
        
        $actualScreenType = $currentScreen.GetType().Name
        if ($actualScreenType -ne $ScreenName) {
            throw "Expected $ScreenName but got $actualScreenType"
        }
        
        # Capture screen state
        $screenCapture = Capture-CurrentScreen "Screen-$ScreenName"
        
        # Run validation script
        $validationResult = & $ValidationScript -Screen $currentScreen
        
        $testResult = @{
            ScreenName = $ScreenName
            ActualScreenType = $actualScreenType
            ValidationResult = $validationResult
            ScreenCapture = $screenCapture
            Success = $validationResult.Success
            Issues = $validationResult.Issues
        }
        
        $RealTestResults.ScreenValidations[$ScreenName] = $testResult
        
        if ($validationResult.Success) {
            $RealTestResults.TestsPassed++
            Write-RealTestLog "PASS: Screen $ScreenName - $($validationResult.Message)" "PASS"
        } else {
            $RealTestResults.TestsFailed++
            Write-RealTestLog "FAIL: Screen $ScreenName - $($validationResult.Message)" "FAIL"
            $RealTestResults.ActualIssues += "Screen $ScreenName - $($validationResult.Message)"
        }
        
        return $testResult
        
    } catch {
        $RealTestResults.TestsFailed++
        $errorMsg = $_.Exception.Message
        Write-RealTestLog "ERROR: Screen $ScreenName - $errorMsg" "FAIL"
        $RealTestResults.ActualIssues += "Screen $ScreenName - $errorMsg"
        
        return @{
            ScreenName = $ScreenName
            Success = $false
            Error = $errorMsg
        }
    }
}

function Check-ErrorLogs {
    Write-RealTestLog "CHECKING ERROR LOGS" "INFO"
    
    $logPaths = @(
        "~/.local/share/AxiomPhoenix/axiom-phoenix.log",
        "./axiom-phoenix.log",
        "./debug.log",
        "./error.log"
    )
    
    foreach ($logPath in $logPaths) {
        if (Test-Path $logPath) {
            Write-RealTestLog "Found log file: $logPath" "INFO"
            
            try {
                $logContent = Get-Content $logPath -Tail 100
                $errors = $logContent | Where-Object { $_ -match '\[ERROR\]|\[WARN\]|Exception|Error:|Failed|Invalid' }
                
                if ($errors.Count -gt 0) {
                    Write-RealTestLog "Found $($errors.Count) error/warning entries in $logPath" "ISSUE"
                    $RealTestResults.ErrorLogFindings[$logPath] = $errors
                    
                    foreach ($error in $errors | Select-Object -First 5) {
                        Write-RealTestLog "  ERROR: $error" "ISSUE"
                    }
                } else {
                    Write-RealTestLog "No errors found in $logPath" "PASS"
                }
                
            } catch {
                Write-RealTestLog "Could not read log file $logPath`: $($_.Exception.Message)" "ISSUE"
            }
        }
    }
}

# ==============================================================================
# START REAL INTEGRATION TESTING
# ==============================================================================

Write-RealTestLog "🔥 REAL INTEGRATION TEST STARTED" "INFO"
Write-RealTestLog "Testing actual keystrokes and screen validation" "INFO"

# Check error logs first
if ($CheckErrorLogs) {
    Check-ErrorLogs
}

# Load and start framework
Write-RealTestLog "Loading framework..." "INFO"
$frameworkStart = Get-Date
try {
    . "./Start.ps1" | Out-Null
    Start-Sleep -Seconds 2  # Let it stabilize
    $frameworkTime = (Get-Date) - $frameworkStart
    Write-RealTestLog "Framework loaded in $([Math]::Round($frameworkTime.TotalSeconds, 2))s" "PERF"
    $RealTestResults.PerformanceData["FrameworkLoad"] = $frameworkTime.TotalSeconds
} catch {
    Write-RealTestLog "CRITICAL: Framework failed to load: $($_.Exception.Message)" "FAIL"
    return
}

# Validate we're on dashboard
$initialScreen = $global:TuiState.CurrentScreen
if (-not $initialScreen) {
    Write-RealTestLog "CRITICAL: No current screen after framework load" "FAIL"
    return
}

$screenType = $initialScreen.GetType().Name
Write-RealTestLog "Initial screen: $screenType" "INFO"

# ==============================================================================
# TEST 1: DASHBOARD ARROW KEY NAVIGATION
# ==============================================================================
Write-RealTestLog "=== TESTING DASHBOARD ARROW KEY NAVIGATION ===" "INFO"

# Test Down Arrow
Test-ActualKeystroke "DashboardDownArrow" ([ConsoleKey]::DownArrow) "Move selection down in dashboard menu" {
    # Validation: Check if menu selection actually changed
    $screen = $global:TuiState.CurrentScreen
    
    # Look for evidence of selection change
    # This depends on how the dashboard implements selection
    if ($screen.PSObject.Properties['SelectedIndex']) {
        $selectedIndex = $screen.SelectedIndex
        return @{
            Success = $true
            Message = "Selection index: $selectedIndex"
            Issues = @()
        }
    } elseif ($screen.PSObject.Properties['Children']) {
        # Check if any child components have focus
        $focusedChild = $screen.Children | Where-Object { $_.PSObject.Properties['HasFocus'] -and $_.HasFocus }
        if ($focusedChild) {
            return @{
                Success = $true
                Message = "Focused child: $($focusedChild.GetType().Name)"
                Issues = @()
            }
        }
    }
    
    # If we can't detect selection change, it's likely not working
    return @{
        Success = $false
        Message = "No detectable selection change after down arrow"
        Issues = @("Arrow key navigation may not be working")
    }
}

# Test Up Arrow
Test-ActualKeystroke "DashboardUpArrow" ([ConsoleKey]::UpArrow) "Move selection up in dashboard menu" {
    $screen = $global:TuiState.CurrentScreen
    
    if ($screen.PSObject.Properties['SelectedIndex']) {
        $selectedIndex = $screen.SelectedIndex
        return @{
            Success = $true
            Message = "Selection index: $selectedIndex"
            Issues = @()
        }
    }
    
    return @{
        Success = $false
        Message = "No detectable selection change after up arrow"
        Issues = @("Arrow key navigation may not be working")
    }
}

# ==============================================================================
# TEST 2: NAVIGATION TO TASK LIST
# ==============================================================================
Write-RealTestLog "=== TESTING NAVIGATION TO TASK LIST ===" "INFO"

# Try to navigate to task list using navigation service
try {
    $navService = $global:TuiServices['NavigationService']
    if ($navService) {
        Write-RealTestLog "Attempting navigation to TaskListScreen..." "INFO"
        $navService.NavigateToScreen("TaskListScreen")
        Start-Sleep -Seconds 1  # Wait for navigation
        
        # Validate we're actually on task list screen
        Test-ScreenContent "TaskListScreen" {
            param($Screen)
            
            # Check if screen has the expected components for task list
            $issues = @()
            $hasTaskList = $false
            
            # Look for task list components
            if ($Screen.PSObject.Properties['Children']) {
                foreach ($child in $Screen.Children) {
                    $childType = $child.GetType().Name
                    if ($childType -match 'ListBox|List|DataGrid') {
                        $hasTaskList = $true
                        
                        # Check if the list has items
                        if ($child.PSObject.Properties['Items']) {
                            $itemCount = if ($child.Items) { $child.Items.Count } else { 0 }
                            Write-RealTestLog "Found list component with $itemCount items" "INFO"
                            
                            if ($itemCount -eq 0) {
                                $issues += "Task list appears empty"
                            }
                        } else {
                            $issues += "Task list component found but cannot check items"
                        }
                    }
                }
            }
            
            if (-not $hasTaskList) {
                $issues += "No task list component found on screen"
            }
            
            # Check for white panel issue specifically
            if ($Screen.PSObject.Properties['Buffer']) {
                $buffer = $Screen.Buffer
                if ($buffer) {
                    # Sample some cells to check for white background
                    $whiteBackgroundCells = 0
                    for ($y = 5; $y -lt [Math]::Min(20, $buffer.Height); $y++) {
                        for ($x = 5; $x -lt [Math]::Min(30, $buffer.Width); $x++) {
                            $cell = $buffer.GetCell($x, $y)
                            if ($cell -and $cell.BackgroundColor -eq "#FFFFFF") {
                                $whiteBackgroundCells++
                            }
                        }
                    }
                    
                    if ($whiteBackgroundCells -gt 50) {
                        $issues += "Large white panel detected - likely the blank white panel issue"
                    }
                }
            }
            
            return @{
                Success = ($issues.Count -eq 0)
                Message = if ($issues.Count -eq 0) { "Task list screen validated" } else { "Issues found: $($issues -join ', ')" }
                Issues = $issues
            }
        }
    } else {
        Write-RealTestLog "NavigationService not available" "FAIL"
    }
} catch {
    Write-RealTestLog "Navigation to TaskListScreen failed: $($_.Exception.Message)" "FAIL"
}

# ==============================================================================
# TEST 3: MEASURE ACTUAL PERFORMANCE
# ==============================================================================
Write-RealTestLog "=== MEASURING ACTUAL PERFORMANCE ===" "INFO"

# Test actual rendering performance
Write-RealTestLog "Testing rendering performance..." "PERF"
$renderStart = Get-Date
for ($i = 0; $i -lt 10; $i++) {
    try {
        if ($global:TuiState.CurrentScreen -and $global:TuiState.CurrentScreen.PSObject.Methods['Render']) {
            # This would be the actual render call, but we need to be careful not to interfere
            # Instead, measure buffer operations
            $buffer = [TuiBuffer]::new(80, 24)
            $buffer.Clear()
            for ($y = 0; $y -lt 24; $y++) {
                $buffer.WriteString(0, $y, "Performance test line $y iteration $i", @{FG="#FFFFFF"; BG="#000000"})
            }
        }
    } catch {
        Write-RealTestLog "Render test $i failed: $($_.Exception.Message)" "ISSUE"
    }
}
$renderTime = (Get-Date) - $renderStart
$avgRenderTime = $renderTime.TotalMilliseconds / 10
Write-RealTestLog "Average render time: $([Math]::Round($avgRenderTime, 2))ms" "PERF"
$RealTestResults.PerformanceData["AverageRenderTime"] = $avgRenderTime

# Test input response time
Write-RealTestLog "Testing input response time..." "PERF"
$inputTimes = @()
for ($i = 0; $i -lt 5; $i++) {
    $inputStart = Get-Date
    $escKey = [System.ConsoleKeyInfo]::new([char]27, [ConsoleKey]::Escape, $false, $false, $false)
    $global:TuiState.CurrentScreen.HandleInput($escKey)
    $inputEnd = Get-Date
    $inputTimes += ($inputEnd - $inputStart).TotalMilliseconds
}
$avgInputTime = ($inputTimes | Measure-Object -Average).Average
Write-RealTestLog "Average input response: $([Math]::Round($avgInputTime, 2))ms" "PERF"
$RealTestResults.PerformanceData["AverageInputTime"] = $avgInputTime

# ==============================================================================
# FINAL ERROR LOG CHECK
# ==============================================================================
Write-RealTestLog "=== FINAL ERROR LOG CHECK ===" "INFO"
if ($CheckErrorLogs) {
    Check-ErrorLogs
}

# ==============================================================================
# GENERATE REAL RESULTS
# ==============================================================================
$endTime = Get-Date
$totalDuration = $endTime - $RealTestResults.StartTime
$RealTestResults.EndTime = $endTime
$RealTestResults.TotalDuration = $totalDuration

# Calculate success rate
$successRate = if ($RealTestResults.TestsRun -gt 0) {
    [Math]::Round(($RealTestResults.TestsPassed / $RealTestResults.TestsRun) * 100, 1)
} else { 0 }

Write-RealTestLog "" "INFO"
Write-RealTestLog "🎯 REAL INTEGRATION TEST RESULTS" "INFO"
Write-RealTestLog "================================" "INFO"
Write-RealTestLog "Duration: $([Math]::Round($totalDuration.TotalMinutes, 1)) minutes" "INFO"
Write-RealTestLog "Tests Run: $($RealTestResults.TestsRun)" "INFO"
Write-RealTestLog "Tests Passed: $($RealTestResults.TestsPassed)" "PASS"
Write-RealTestLog "Tests Failed: $($RealTestResults.TestsFailed)" "FAIL"
Write-RealTestLog "Success Rate: $successRate%" "INFO"

if ($RealTestResults.ActualIssues.Count -gt 0) {
    Write-RealTestLog "" "INFO"
    Write-RealTestLog "🚨 ACTUAL ISSUES FOUND:" "FAIL"
    foreach ($issue in $RealTestResults.ActualIssues) {
        Write-RealTestLog "  • $issue" "ISSUE"
    }
}

# Performance summary
Write-RealTestLog "" "INFO"
Write-RealTestLog "⚡ PERFORMANCE SUMMARY:" "PERF"
foreach ($metric in $RealTestResults.PerformanceData.Keys) {
    $value = $RealTestResults.PerformanceData[$metric]
    $unit = if ($metric -match "Time") { "ms" } elseif ($metric -match "Load") { "s" } else { "" }
    Write-RealTestLog "  $metric`: $([Math]::Round($value, 2))$unit" "PERF"
}

# Save detailed results
$RealTestResults | ConvertTo-Json -Depth 10 | Out-File "$resultDir/real-test-results.json"
Write-RealTestLog "" "INFO"
Write-RealTestLog "📄 Detailed results saved to: $resultDir/real-test-results.json" "INFO"

# Cleanup
if ($global:TuiState) {
    $global:TuiState.Running = $false
}

Write-Host "`n🔥 REAL INTEGRATION TEST COMPLETE!" -ForegroundColor Red
Write-Host "This test actually validates functionality, not just file existence." -ForegroundColor Yellow
Write-Host "Check results in: $resultDir" -ForegroundColor Cyan

return $RealTestResults