#!/usr/bin/env pwsh
# ==============================================================================
# FOCUSED INTEGRATION TEST - Comprehensive Screen-by-Screen Audit
# Tests every screen, every keypress, and every function with detailed logging
# ==============================================================================

param(
    [switch]$StopOnFirstError = $false,
    [switch]$DetailedLogging = $true,
    [string]$SpecificScreen = "",
    [switch]$SkipFrameworkLoad = $false
)

$ErrorActionPreference = "Continue"

# Import the enhanced audit logger
. "./Enhanced-Audit-Logger.ps1"

# Initialize comprehensive logging
$auditLogger = [AuditLogger]::new("focused-integration-test")
$auditLogger.WriteLog("=== STARTING FOCUSED INTEGRATION TEST ===", "SYSTEM")

function Test-ScreenNavigation {
    param([string]$TargetScreen, [string]$Description)
    
    $testInfo = $auditLogger.StartTest("Navigation", "$TargetScreen", "Navigate to $TargetScreen")
    
    try {
        $navService = $global:TuiServices['NavigationService']
        if (-not $navService) {
            $auditLogger.EndTest($testInfo, $false, "", "NavigationService not available")
            return @{ Success = $false; Error = "NavigationService not available" }
        }
        
        $originalScreen = $global:TuiState.CurrentScreen.GetType().Name
        $auditLogger.WriteLog("Current screen: $originalScreen", "INFO")
        
        # Clear any existing errors
        $Error.Clear()
        
        # Attempt navigation
        $navService.NavigateToScreen($TargetScreen)
        Start-Sleep -Milliseconds 800
        
        $newScreen = $global:TuiState.CurrentScreen.GetType().Name
        $success = ($newScreen -eq $TargetScreen)
        
        if ($success) {
            # Test basic screen functionality
            $screen = $global:TuiState.CurrentScreen
            $hasRender = $screen.PSObject.Methods['Render'] -ne $null
            $hasInput = $screen.PSObject.Methods['HandleInput'] -ne $null
            $hasInit = $screen.PSObject.Methods['Initialize'] -ne $null
            
            $auditLogger.EndTest($testInfo, $true, "Navigation successful", "", @{
                OriginalScreen = $originalScreen
                NewScreen = $newScreen
                HasRender = $hasRender
                HasInput = $hasInput
                HasInit = $hasInit
            })
            
            # Test basic input
            try {
                $escKey = [System.ConsoleKeyInfo]::new([char]27, [ConsoleKey]::Escape, $false, $false, $false)
                $inputResult = $screen.HandleInput($escKey)
                $auditLogger.WriteLog("Input handling: Working", "PASS")
            } catch {
                $auditLogger.WriteLog("Input handling: Error - $($_.Exception.Message)", "WARN")
            }
            
            return @{ 
                Success = $true; 
                OriginalScreen = $originalScreen; 
                NewScreen = $newScreen;
                Methods = @{ Render = $hasRender; HandleInput = $hasInput; Initialize = $hasInit }
            }
        } else {
            $errorMsg = "Expected $TargetScreen but got $newScreen"
            $auditLogger.EndTest($testInfo, $false, "", $errorMsg)
            return @{ Success = $false; Error = $errorMsg; Errors = $Error }
        }
        
    } catch {
        $auditLogger.EndTest($testInfo, $false, "", $_.Exception.Message)
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-InputOnScreen {
    param([string]$ScreenName, [ConsoleKey]$Key, [string]$KeyName)
    
    $testInfo = $auditLogger.StartTest("Input", "$ScreenName-$KeyName", "Test $KeyName on $ScreenName")
    
    try {
        $screen = $global:TuiState.CurrentScreen
        $keyInfo = [System.ConsoleKeyInfo]::new([char]0, $Key, $false, $false, $false)
        
        $inputStart = Get-Date
        $result = $screen.HandleInput($keyInfo)
        $inputTime = (Get-Date) - $inputStart
        
        $auditLogger.EndTest($testInfo, $true, $result, "", @{
            ResponseTime = $inputTime.TotalMilliseconds
            ScreenName = $ScreenName
            KeyName = $KeyName
        })
        
        # Log performance
        $auditLogger.LogPerformance("Input-$ScreenName-$KeyName", @{
            ResponseTime = $inputTime.TotalMilliseconds
            Key = $KeyName
            Screen = $ScreenName
        })
        
        return @{ Success = $true; ResponseTime = $inputTime.TotalMilliseconds; Result = $result }
    } catch {
        $auditLogger.EndTest($testInfo, $false, "", $_.Exception.Message)
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

Write-Host "🎯 FOCUSED INTEGRATION TEST STARTED" -ForegroundColor Yellow
Write-Host "===================================" -ForegroundColor Yellow

# Load framework
Write-Host "`n📦 Loading Framework..." -ForegroundColor Yellow
$loadStart = Get-Date
. "./Start.ps1"
Start-Sleep -Seconds 2
$loadTime = (Get-Date) - $loadStart
Write-Host "✅ Framework loaded in $([Math]::Round($loadTime.TotalSeconds, 1))s" -ForegroundColor Green

# Validate initial state
$initialScreen = $global:TuiState.CurrentScreen.GetType().Name
Write-Host "Initial screen: $initialScreen" -ForegroundColor White

# Test navigation to every screen systematically
Write-Host "`n🧭 NAVIGATION TESTING" -ForegroundColor Yellow
Write-Host "===================" -ForegroundColor Yellow

$screens = @(
    @{ Name = "DashboardScreen"; Description = "Main dashboard" },
    @{ Name = "TaskListScreen"; Description = "Task list management" },
    @{ Name = "NewTaskScreen"; Description = "New task creation" },
    @{ Name = "EditTaskScreen"; Description = "Task editing" },
    @{ Name = "NewTaskEntryScreen"; Description = "Task entry creation" },
    @{ Name = "ProjectsListScreen"; Description = "Project management" },
    @{ Name = "ProjectDashboardScreen"; Description = "Project dashboard" },
    @{ Name = "ProjectDetailScreen"; Description = "Project details" },
    @{ Name = "ProjectInfoScreen"; Description = "Project information" },
    @{ Name = "FileCommanderScreen"; Description = "File commander" },
    @{ Name = "FileBrowserScreen"; Description = "File browser" },
    @{ Name = "TextEditorScreen"; Description = "Text editor" },
    @{ Name = "TextEditScreen"; Description = "Text edit" },
    @{ Name = "ThemeScreen"; Description = "Theme picker" },
    @{ Name = "CommandPaletteScreen"; Description = "Command palette" },
    @{ Name = "TimesheetScreen"; Description = "Timesheet view" }
)

$navigationResults = @{}
foreach ($screen in $screens) {
    $result = Test-ScreenNavigation $screen.Name $screen.Description
    $navigationResults[$screen.Name] = $result
    
    if ($result.Success) {
        # Test basic inputs on this screen
        Write-Host "   Testing inputs on $($screen.Name):" -ForegroundColor Gray
        $inputTests = @(
            @{ Key = [ConsoleKey]::UpArrow; Name = "UpArrow" },
            @{ Key = [ConsoleKey]::DownArrow; Name = "DownArrow" },
            @{ Key = [ConsoleKey]::Enter; Name = "Enter" },
            @{ Key = [ConsoleKey]::Escape; Name = "Escape" }
        )
        
        foreach ($inputTest in $inputTests) {
            $inputResult = Test-InputOnScreen $screen.Name $inputTest.Key $inputTest.Name
            Start-Sleep -Milliseconds 100
        }
    }
    
    # Always return to dashboard
    try {
        $global:TuiServices['NavigationService'].NavigateToScreen("DashboardScreen")
        Start-Sleep -Milliseconds 400
    } catch {
        Write-Host "   ⚠️  Could not return to dashboard" -ForegroundColor Yellow
    }
    
    Write-Host "" # Blank line for readability
}

# Test specific issues from error log
Write-Host "`n🔍 SPECIFIC ISSUE TESTING" -ForegroundColor Yellow
Write-Host "=========================" -ForegroundColor Yellow

# Test NewTaskScreen SetFocus issue
Write-Host "🔹 Testing NewTaskScreen SetFocus issue..." -ForegroundColor Cyan
$navResult = $navigationResults["NewTaskScreen"]
if ($navResult -and $navResult.Success) {
    Write-Host "   NewTaskScreen navigation works - SetFocus issue may be resolved" -ForegroundColor Green
} else {
    Write-Host "   NewTaskScreen navigation failed - SetFocus issue persists" -ForegroundColor Red
    if ($navResult.Error) {
        Write-Host "   Error: $($navResult.Error)" -ForegroundColor Yellow
    }
}

# Check current error log
Write-Host "`n🔹 Checking current error log..." -ForegroundColor Cyan
$logPath = "~/.local/share/AxiomPhoenix/axiom-phoenix.log"
if (Test-Path $logPath) {
    $recentErrors = Get-Content $logPath -Tail 10 | Where-Object { $_ -match 'ERROR|WARN' }
    if ($recentErrors) {
        Write-Host "   Recent errors found:" -ForegroundColor Yellow
        foreach ($error in $recentErrors) {
            Write-Host "     $error" -ForegroundColor Red
        }
    } else {
        Write-Host "   No recent errors found" -ForegroundColor Green
    }
} else {
    Write-Host "   Log file not found" -ForegroundColor Yellow
}

# Summary
Write-Host "`n📊 SUMMARY" -ForegroundColor Yellow
Write-Host "=========" -ForegroundColor Yellow

$successfulNavigations = ($navigationResults.Values | Where-Object { $_.Success }).Count
$totalNavigations = $navigationResults.Count

Write-Host "Navigation Tests: $successfulNavigations/$totalNavigations successful" -ForegroundColor White
Write-Host "Success Rate: $([Math]::Round(($successfulNavigations / $totalNavigations) * 100, 1))%" -ForegroundColor White

$failedNavigations = $navigationResults.Values | Where-Object { -not $_.Success }
if ($failedNavigations) {
    Write-Host "`nFailed Navigations:" -ForegroundColor Red
    foreach ($failed in $failedNavigations) {
        $screenName = ($navigationResults.Keys | Where-Object { $navigationResults[$_] -eq $failed })[0]
        Write-Host "  • $screenName`: $($failed.Error)" -ForegroundColor Yellow
    }
}

# Cleanup
if ($global:TuiState) {
    $global:TuiState.Running = $false
}

Write-Host "`n✅ FOCUSED INTEGRATION TEST COMPLETE!" -ForegroundColor Green
return $navigationResults