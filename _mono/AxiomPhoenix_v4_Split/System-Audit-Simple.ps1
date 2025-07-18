#!/usr/bin/env pwsh
# ==============================================================================
# COMPREHENSIVE SYSTEM AUDIT - Simplified Version
# Tests every screen, component, function, and navigation path
# ==============================================================================

$ErrorActionPreference = "Continue"
$AuditResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Issues = @()
}

function Write-AuditResult {
    param([string]$Test, [bool]$Passed, [string]$Error = "")
    
    $AuditResults.TotalTests++
    if ($Passed) { 
        $AuditResults.PassedTests++
        Write-Host "✅ $Test" -ForegroundColor Green
    } else { 
        $AuditResults.FailedTests++
        Write-Host "❌ $Test" -ForegroundColor Red
        if ($Error) { Write-Host "   Error: $Error" -ForegroundColor Yellow }
        $AuditResults.Issues += "$Test - $Error"
    }
}

Write-Host "🔍 STARTING COMPREHENSIVE SYSTEM AUDIT" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# ==============================================================================
# PHASE 1: FRAMEWORK LOADING
# ==============================================================================
Write-Host "`n📦 PHASE 1: FRAMEWORK LOADING" -ForegroundColor Yellow

try {
    # Load essential components quietly
    . "./Base/ABC.001_TuiAnsiHelper.ps1" 2>$null
    . "./Base/ABC.002_TuiCell.ps1" 2>$null  
    . "./Base/ABC.003_TuiBuffer.ps1" 2>$null
    Write-AuditResult "Base classes loaded" $true
} catch {
    Write-AuditResult "Base classes loading" $false $_.Exception.Message
    exit 1
}

try {
    # Load full framework
    . "./Start.ps1" 2>$null
    Start-Sleep -Seconds 2
    Write-AuditResult "Full framework loaded" $true
} catch {
    Write-AuditResult "Full framework loading" $false $_.Exception.Message
    exit 1
}

# ==============================================================================
# PHASE 2: SCREEN DISCOVERY
# ==============================================================================
Write-Host "`n🖥️ PHASE 2: SCREEN DISCOVERY AND TESTING" -ForegroundColor Yellow

$ScreenFiles = Get-ChildItem -Path "./Screens/ASC.*.ps1" | Sort-Object Name

foreach ($screenFile in $ScreenFiles) {
    $screenName = $screenFile.BaseName -replace "ASC\.\d+_", ""
    Write-Host "`n  Testing Screen: $screenName" -ForegroundColor Cyan
    
    # Test 1: File readability
    try {
        $content = Get-Content $screenFile.FullName -Raw
        Write-AuditResult "  $screenName - File readable" $true
    } catch {
        Write-AuditResult "  $screenName - File readable" $false $_.Exception.Message
        continue
    }
    
    # Test 2: Class detection
    try {
        if ($content -match 'class\s+(\w+)') {
            $className = $Matches[1]
            Write-AuditResult "  $screenName - Class '$className' found" $true
            
            # Test 3: Class instantiation
            try {
                $instance = New-Object $className
                Write-AuditResult "  $screenName - Class instantiation" $true
                
                # Test 4: Essential methods
                $methods = $instance.GetType().GetMethods().Name
                foreach ($method in @('Initialize', 'HandleInput', 'Render')) {
                    if ($method -in $methods) {
                        Write-AuditResult "  $screenName - Has $method method" $true
                    } else {
                        Write-AuditResult "  $screenName - Has $method method" $false "Method not found"
                    }
                }
                
                # Test 5: Properties
                $properties = $instance.GetType().GetProperties().Name
                foreach ($prop in @('Name', 'Title', 'Width', 'Height')) {
                    if ($prop -in $properties) {
                        Write-AuditResult "  $screenName - Has $prop property" $true
                    } else {
                        Write-AuditResult "  $screenName - Has $prop property" $false "Property not found"
                    }
                }
                
            } catch {
                Write-AuditResult "  $screenName - Class instantiation" $false $_.Exception.Message
            }
        } else {
            Write-AuditResult "  $screenName - Class definition found" $false "No class definition"
        }
    } catch {
        Write-AuditResult "  $screenName - Class detection" $false $_.Exception.Message
    }
}

# ==============================================================================
# PHASE 3: NAVIGATION TESTING
# ==============================================================================
Write-Host "`n🧭 PHASE 3: NAVIGATION TESTING" -ForegroundColor Yellow

# Test current state
if ($global:TuiState) {
    Write-AuditResult "Global TuiState exists" $true
    
    if ($global:TuiState.CurrentScreen) {
        $currentScreenType = $global:TuiState.CurrentScreen.GetType().Name
        Write-AuditResult "Current screen accessible ($currentScreenType)" $true
    } else {
        Write-AuditResult "Current screen accessible" $false "CurrentScreen is null"
    }
    
    # Test navigation service
    if ($global:TuiServices -and $global:TuiServices.ContainsKey('NavigationService')) {
        Write-AuditResult "NavigationService accessible" $true
        
        $navService = $global:TuiServices['NavigationService']
        
        # Test navigation to different screens
        $screens = @("DashboardScreen", "TaskListScreen", "ProjectsListScreen")
        foreach ($screenName in $screens) {
            try {
                if ($navService.PSObject.Methods['NavigateToScreen']) {
                    $navService.NavigateToScreen($screenName)
                    Start-Sleep -Milliseconds 500
                    Write-AuditResult "Navigate to $screenName" $true
                } else {
                    Write-AuditResult "Navigate to $screenName" $false "NavigateToScreen method not found"
                }
            } catch {
                Write-AuditResult "Navigate to $screenName" $false $_.Exception.Message
            }
        }
    } else {
        Write-AuditResult "NavigationService accessible" $false "Service not found"
    }
} else {
    Write-AuditResult "Global TuiState exists" $false "TuiState is null"
}

# ==============================================================================
# PHASE 4: INPUT TESTING
# ==============================================================================
Write-Host "`n⌨️ PHASE 4: INPUT TESTING" -ForegroundColor Yellow

if ($global:TuiState -and $global:TuiState.CurrentScreen) {
    $currentScreen = $global:TuiState.CurrentScreen
    
    # Test various key inputs
    $testKeys = @(
        @{Key = [ConsoleKey]::UpArrow; Name = "UpArrow"},
        @{Key = [ConsoleKey]::DownArrow; Name = "DownArrow"},
        @{Key = [ConsoleKey]::LeftArrow; Name = "LeftArrow"},
        @{Key = [ConsoleKey]::RightArrow; Name = "RightArrow"},
        @{Key = [ConsoleKey]::Enter; Name = "Enter"},
        @{Key = [ConsoleKey]::Tab; Name = "Tab"},
        @{Key = [ConsoleKey]::Escape; Name = "Escape"}
    )
    
    foreach ($testKey in $testKeys) {
        try {
            $keyInfo = [System.ConsoleKeyInfo]::new([char]0, $testKey.Key, $false, $false, $false)
            $result = $currentScreen.HandleInput($keyInfo)
            Write-AuditResult "Input handling - $($testKey.Name)" $true
        } catch {
            Write-AuditResult "Input handling - $($testKey.Name)" $false $_.Exception.Message
        }
    }
} else {
    Write-AuditResult "Input testing" $false "No current screen available"
}

# ==============================================================================
# PHASE 5: SERVICE TESTING
# ==============================================================================
Write-Host "`n🔧 PHASE 5: SERVICE TESTING" -ForegroundColor Yellow

$requiredServices = @(
    "DataManager", "ThemeManager", "NavigationService", 
    "ActionService", "KeybindingService", "EventManager"
)

foreach ($serviceName in $requiredServices) {
    if ($global:TuiServices -and $global:TuiServices.ContainsKey($serviceName)) {
        Write-AuditResult "Service $serviceName exists" $true
        
        $service = $global:TuiServices[$serviceName]
        
        # Test service methods
        $methods = $service.GetType().GetMethods().Name
        $expectedMethods = switch ($serviceName) {
            "DataManager" { @("GetTasks", "SaveTask", "GetProjects") }
            "ThemeManager" { @("GetColor", "ApplyTheme") }
            "NavigationService" { @("NavigateToScreen") }
            "ActionService" { @("ExecuteAction") }
            default { @() }
        }
        
        foreach ($method in $expectedMethods) {
            if ($method -in $methods) {
                Write-AuditResult "Service $serviceName has $method" $true
            } else {
                Write-AuditResult "Service $serviceName has $method" $false "Method not found"
            }
        }
    } else {
        Write-AuditResult "Service $serviceName exists" $false "Service not registered"
    }
}

# ==============================================================================
# PHASE 6: COMPONENT TESTING
# ==============================================================================
Write-Host "`n🧩 PHASE 6: COMPONENT TESTING" -ForegroundColor Yellow

$ComponentFiles = Get-ChildItem -Path "./Components/ACO.*.ps1" | Sort-Object Name

foreach ($componentFile in $ComponentFiles) {
    $componentName = $componentFile.BaseName -replace "ACO\.\d+_", ""
    
    try {
        $content = Get-Content $componentFile.FullName -Raw
        if ($content -match 'class\s+(\w+)') {
            $className = $Matches[1]
            
            try {
                $instance = New-Object $className
                Write-AuditResult "Component $componentName instantiation" $true
                
                # Test essential component methods
                $methods = $instance.GetType().GetMethods().Name
                foreach ($method in @('Render', 'HandleInput')) {
                    if ($method -in $methods) {
                        Write-AuditResult "Component $componentName has $method" $true
                    } else {
                        Write-AuditResult "Component $componentName has $method" $false "Method missing"
                    }
                }
            } catch {
                Write-AuditResult "Component $componentName instantiation" $false $_.Exception.Message
            }
        }
    } catch {
        Write-AuditResult "Component $componentName file parsing" $false $_.Exception.Message
    }
}

# ==============================================================================
# PHASE 7: INTEGRATION TESTING
# ==============================================================================
Write-Host "`n🔗 PHASE 7: INTEGRATION TESTING" -ForegroundColor Yellow

# Test screen-to-screen navigation flow
if ($global:TuiState -and $global:TuiServices) {
    $navService = $global:TuiServices['NavigationService']
    
    $navigationFlow = @(
        "DashboardScreen",
        "TaskListScreen", 
        "NewTaskScreen",
        "DashboardScreen",
        "ProjectsListScreen",
        "DashboardScreen"
    )
    
    $flowSuccess = $true
    foreach ($screen in $navigationFlow) {
        try {
            $navService.NavigateToScreen($screen)
            Start-Sleep -Milliseconds 300
            
            if ($global:TuiState.CurrentScreen.GetType().Name -eq $screen) {
                Write-AuditResult "Navigation flow to $screen" $true
            } else {
                Write-AuditResult "Navigation flow to $screen" $false "Wrong screen type"
                $flowSuccess = $false
            }
        } catch {
            Write-AuditResult "Navigation flow to $screen" $false $_.Exception.Message
            $flowSuccess = $false
        }
    }
    
    Write-AuditResult "Complete navigation flow" $flowSuccess
}

# ==============================================================================
# RESULTS SUMMARY
# ==============================================================================
Write-Host "`n📊 AUDIT RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

$successRate = if ($AuditResults.TotalTests -gt 0) { 
    [Math]::Round(($AuditResults.PassedTests / $AuditResults.TotalTests) * 100, 1)
} else { 0 }

Write-Host "Total Tests: $($AuditResults.TotalTests)" -ForegroundColor White
Write-Host "Passed: $($AuditResults.PassedTests)" -ForegroundColor Green  
Write-Host "Failed: $($AuditResults.FailedTests)" -ForegroundColor Red
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -gt 80) { "Green" } elseif ($successRate -gt 60) { "Yellow" } else { "Red" })

if ($AuditResults.Issues.Count -gt 0) {
    Write-Host "`n🚨 CRITICAL ISSUES FOUND:" -ForegroundColor Red
    foreach ($issue in $AuditResults.Issues) {
        Write-Host "  • $issue" -ForegroundColor Yellow
    }
}

# Cleanup
if ($global:TuiState) {
    $global:TuiState.Running = $false
}

Write-Host "`n✅ Audit Complete!" -ForegroundColor Green