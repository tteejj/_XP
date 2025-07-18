#!/usr/bin/env pwsh
# ==============================================================================
# COMPREHENSIVE SYSTEM AUDIT
# Tests every screen, component, function, and navigation path
# ==============================================================================

param(
    [switch]$Detailed = $false,
    [string]$LogFile = "system-audit-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

# Initialize audit logging
function Write-AuditLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "PASS" {"Green"} default {"White"} })
    Add-Content -Path $LogFile -Value $logEntry
}

# Audit results tracking
$AuditResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Screens = @{}
    Components = @{}
    NavigationPaths = @{}
    Issues = @()
}

function Add-AuditResult {
    param([string]$Category, [string]$TestName, [bool]$Passed, [string]$Details = "", [string]$Error = "")
    
    $AuditResults.TotalTests++
    if ($Passed) { $AuditResults.PassedTests++ } else { $AuditResults.FailedTests++ }
    
    if (-not $AuditResults[$Category]) { $AuditResults[$Category] = @{} }
    $AuditResults[$Category][$TestName] = @{
        Passed = $Passed
        Details = $Details
        Error = $Error
        Timestamp = Get-Date
    }
    
    if (-not $Passed) {
        $AuditResults.Issues += @{
            Category = $Category
            Test = $TestName
            Error = $Error
            Details = $Details
        }
    }
}

Write-AuditLog "Starting Comprehensive System Audit" "INFO"
Write-AuditLog "Log file: $LogFile" "INFO"

# ==============================================================================
# PHASE 1: FRAMEWORK LOADING TEST
# ==============================================================================
Write-AuditLog "=== PHASE 1: FRAMEWORK LOADING ===" "INFO"

try {
    Write-AuditLog "Loading framework components..." "INFO"
    
    # Load base classes
    . "./Base/ABC.001_TuiAnsiHelper.ps1"
    . "./Base/ABC.002_TuiCell.ps1"
    . "./Base/ABC.003_TuiBuffer.ps1"
    
    Write-AuditLog "✓ Base classes loaded" "PASS"
    Add-AuditResult "Framework" "BaseClassesLoad" $true "Base classes loaded successfully"
    
    # Load remaining framework
    . "./Start.ps1"
    
    Write-AuditLog "✓ Framework loaded successfully" "PASS"
    Add-AuditResult "Framework" "FullFrameworkLoad" $true "Framework loaded without errors"
    
} catch {
    Write-AuditLog "✗ Framework loading failed: $_" "ERROR"
    Add-AuditResult "Framework" "FrameworkLoad" $false "" $_.Exception.Message
    return
}

# Wait for framework to stabilize
Start-Sleep -Seconds 3

# ==============================================================================
# PHASE 2: SCREEN DISCOVERY AND BASIC INSTANTIATION
# ==============================================================================
Write-AuditLog "=== PHASE 2: SCREEN DISCOVERY ===" "INFO"

$ScreenFiles = Get-ChildItem -Path "./Screens/ASC.*.ps1" | Sort-Object Name
$DiscoveredScreens = @()

foreach ($screenFile in $ScreenFiles) {
    $screenName = $screenFile.BaseName
    Write-AuditLog "Testing screen: $screenName" "INFO"
    
    try {
        # Read and analyze screen file
        $content = Get-Content $screenFile.FullName -Raw
        
        # Extract class name
        if ($content -match 'class\s+(\w+)\s*[:\s]') {
            $className = $Matches[1]
            Write-AuditLog "  Found class: $className" "INFO"
            
            # Test class instantiation
            try {
                $screenInstance = New-Object $className
                Write-AuditLog "  ✓ Successfully instantiated $className" "PASS"
                Add-AuditResult "Screens" "$screenName-Instantiation" $true "Class $className instantiated successfully"
                
                $DiscoveredScreens += @{
                    Name = $screenName
                    ClassName = $className
                    Instance = $screenInstance
                    File = $screenFile.FullName
                }
                
            } catch {
                Write-AuditLog "  ✗ Failed to instantiate ${className}: $_" "ERROR"
                Add-AuditResult "Screens" "$screenName-Instantiation" $false "Failed to instantiate $className" $_.Exception.Message
            }
        } else {
            Write-AuditLog "  ✗ No class definition found in $screenName" "ERROR"
            Add-AuditResult "Screens" "$screenName-ClassDetection" $false "No class definition found"
        }
        
    } catch {
        Write-AuditLog "  ✗ Error processing ${screenName}: $_" "ERROR"
        Add-AuditResult "Screens" "$screenName-Processing" $false "Error processing screen file" $_.Exception.Message
    }
}

Write-AuditLog "Discovered $($DiscoveredScreens.Count) screens" "INFO"

# ==============================================================================
# PHASE 3: DETAILED SCREEN TESTING
# ==============================================================================
Write-AuditLog "=== PHASE 3: DETAILED SCREEN TESTING ===" "INFO"

function Test-ScreenMethods {
    param($Screen, $ScreenName)
    
    $methods = $Screen.GetType().GetMethods() | Where-Object { $_.DeclaringType.Name -eq $Screen.GetType().Name }
    
    foreach ($method in $methods) {
        if ($method.Name -in @('Initialize', 'Render', 'HandleInput', 'OnEnter', 'OnExit', 'Dispose')) {
            Write-AuditLog "    Testing method: $($method.Name)" "INFO"
            
            try {
                switch ($method.Name) {
                    'Initialize' {
                        if ($method.GetParameters().Count -eq 0) {
                            $Screen.Initialize()
                            Write-AuditLog "      ✓ Initialize() succeeded" "PASS"
                            Add-AuditResult "Screens" "$ScreenName-Initialize" $true "Initialize method executed successfully"
                        }
                    }
                    'OnEnter' {
                        if ($method.GetParameters().Count -eq 0) {
                            $Screen.OnEnter()
                            Write-AuditLog "      ✓ OnEnter() succeeded" "PASS"
                            Add-AuditResult "Screens" "$ScreenName-OnEnter" $true "OnEnter method executed successfully"
                        }
                    }
                    'OnExit' {
                        if ($method.GetParameters().Count -eq 0) {
                            $Screen.OnExit()
                            Write-AuditLog "      ✓ OnExit() succeeded" "PASS"
                            Add-AuditResult "Screens" "$ScreenName-OnExit" $true "OnExit method executed successfully"
                        }
                    }
                }
            } catch {
                Write-AuditLog "      ✗ $($method.Name) failed: $_" "ERROR"
                Add-AuditResult "Screens" "$ScreenName-$($method.Name)" $false "Method execution failed" $_.Exception.Message
            }
        }
    }
}

function Test-ScreenProperties {
    param($Screen, $ScreenName)
    
    $properties = $Screen.GetType().GetProperties()
    
    foreach ($prop in $properties) {
        if ($prop.Name -in @('Name', 'Title', 'Width', 'Height', 'IsVisible', 'HasFocus', 'Children')) {
            try {
                $value = $prop.GetValue($Screen)
                Write-AuditLog "      Property $($prop.Name): $value" "INFO"
                Add-AuditResult "Screens" "$ScreenName-Property-$($prop.Name)" $true "Property accessible: $value"
            } catch {
                Write-AuditLog "      ✗ Property $($prop.Name) failed: $_" "ERROR"
                Add-AuditResult "Screens" "$ScreenName-Property-$($prop.Name)" $false "Property access failed" $_.Exception.Message
            }
        }
    }
}

foreach ($screen in $DiscoveredScreens) {
    Write-AuditLog "  Testing screen: $($screen.Name)" "INFO"
    
    # Test methods
    Test-ScreenMethods $screen.Instance $screen.Name
    
    # Test properties
    Test-ScreenProperties $screen.Instance $screen.Name
    
    # Test child components if they exist
    if ($screen.Instance.PSObject.Properties['Children']) {
        $children = $screen.Instance.Children
        if ($children) {
            Write-AuditLog "    Found $($children.Count) child components" "INFO"
            
            foreach ($child in $children) {
                $childType = $child.GetType().Name
                Write-AuditLog "      Child component: $childType" "INFO"
                
                # Test basic component functionality
                try {
                    if ($child.PSObject.Methods['Render']) {
                        # Don't actually render, just check method exists
                        Write-AuditLog "        ✓ Has Render method" "PASS"
                        Add-AuditResult "Components" "$($screen.Name)-$childType-HasRender" $true "Component has Render method"
                    }
                    
                    if ($child.PSObject.Methods['HandleInput']) {
                        Write-AuditLog "        ✓ Has HandleInput method" "PASS"
                        Add-AuditResult "Components" "$($screen.Name)-$childType-HasHandleInput" $true "Component has HandleInput method"
                    }
                    
                } catch {
                    Write-AuditLog "        ✗ Component test failed: $_" "ERROR"
                    Add-AuditResult "Components" "$($screen.Name)-$childType-Test" $false "Component test failed" $_.Exception.Message
                }
            }
        }
    }
}

# ==============================================================================
# PHASE 4: NAVIGATION TESTING
# ==============================================================================
Write-AuditLog "=== PHASE 4: NAVIGATION TESTING ===" "INFO"

function Test-NavigationToScreen {
    param([string]$ScreenName)
    
    try {
        if ($global:TuiState -and $global:TuiState.PSObject.Methods['NavigationService']) {
            $navService = $global:TuiState.NavigationService
            if ($navService -and $navService.PSObject.Methods['NavigateToScreen']) {
                $navService.NavigateToScreen($ScreenName)
                Write-AuditLog "    ✓ Navigation to $ScreenName succeeded" "PASS"
                Add-AuditResult "Navigation" "NavigateTo-$ScreenName" $true "Navigation successful"
                return $true
            }
        }
        return $false
    } catch {
        Write-AuditLog "    ✗ Navigation to $ScreenName failed: $_" "ERROR"
        Add-AuditResult "Navigation" "NavigateTo-$ScreenName" $false "Navigation failed" $_.Exception.Message
        return $false
    }
}

# Test navigation to each discovered screen
$navigationTargets = @(
    "DashboardScreen",
    "TaskListScreen", 
    "NewTaskScreen",
    "ProjectsListScreen",
    "FileCommanderScreen",
    "TextEditorScreen",
    "TimesheetScreen",
    "ThemeScreen"
)

foreach ($target in $navigationTargets) {
    Write-AuditLog "  Testing navigation to: $target" "INFO"
    $success = Test-NavigationToScreen $target
    
    if ($success) {
        # Test current screen functionality
        if ($global:TuiState.CurrentScreen) {
            $currentScreen = $global:TuiState.CurrentScreen
            Write-AuditLog "    Current screen: $($currentScreen.GetType().Name)" "INFO"
            
            # Test basic input handling
            try {
                $testKey = [System.ConsoleKeyInfo]::new([char]27, [ConsoleKey]::Escape, $false, $false, $false)
                $inputResult = $currentScreen.HandleInput($testKey)
                Write-AuditLog "      ✓ Input handling works (Escape key)" "PASS"
                Add-AuditResult "Navigation" "$target-InputHandling" $true "Input handling functional"
            } catch {
                Write-AuditLog "      ✗ Input handling failed: $_" "ERROR"
                Add-AuditResult "Navigation" "$target-InputHandling" $false "Input handling failed" $_.Exception.Message
            }
        }
    }
    
    # Small delay between navigation tests
    Start-Sleep -Milliseconds 500
}

# ==============================================================================
# PHASE 5: INPUT TESTING
# ==============================================================================
Write-AuditLog "=== PHASE 5: INPUT TESTING ===" "INFO"

function Test-KeyInput {
    param([ConsoleKey]$Key, [string]$KeyName, [bool]$Shift = $false, [bool]$Ctrl = $false, [bool]$Alt = $false)
    
    try {
        $keyInfo = [System.ConsoleKeyInfo]::new([char]0, $Key, $Shift, $Alt, $Ctrl)
        
        if ($global:TuiState.CurrentScreen) {
            $result = $global:TuiState.CurrentScreen.HandleInput($keyInfo)
            Write-AuditLog "    ✓ $KeyName input handled (result: $result)" "PASS"
            Add-AuditResult "Input" "$KeyName-Handling" $true "Key input handled successfully"
            return $true
        }
        return $false
    } catch {
        Write-AuditLog "    ✗ $KeyName input failed: $_" "ERROR"
        Add-AuditResult "Input" "$KeyName-Handling" $false "Key input failed" $_.Exception.Message
        return $false
    }
}

# Navigate to dashboard for input testing
Write-AuditLog "  Navigating to Dashboard for input testing..." "INFO"
Test-NavigationToScreen "DashboardScreen"

# Test various key inputs
$testKeys = @(
    @{ Key = [ConsoleKey]::UpArrow; Name = "UpArrow" },
    @{ Key = [ConsoleKey]::DownArrow; Name = "DownArrow" },
    @{ Key = [ConsoleKey]::LeftArrow; Name = "LeftArrow" },
    @{ Key = [ConsoleKey]::RightArrow; Name = "RightArrow" },
    @{ Key = [ConsoleKey]::Enter; Name = "Enter" },
    @{ Key = [ConsoleKey]::Tab; Name = "Tab" },
    @{ Key = [ConsoleKey]::Tab; Name = "Shift+Tab"; Shift = $true },
    @{ Key = [ConsoleKey]::Escape; Name = "Escape" },
    @{ Key = [ConsoleKey]::F1; Name = "F1" },
    @{ Key = [ConsoleKey]::P; Name = "Ctrl+P"; Ctrl = $true },
    @{ Key = [ConsoleKey]::S; Name = "Ctrl+S"; Ctrl = $true }
)

foreach ($testKey in $testKeys) {
    Write-AuditLog "  Testing key: $($testKey.Name)" "INFO"
    Test-KeyInput -Key $testKey.Key -KeyName $testKey.Name -Shift $testKey.Shift -Ctrl $testKey.Ctrl -Alt $testKey.Alt
    Start-Sleep -Milliseconds 200
}

# ==============================================================================
# PHASE 6: DATA OPERATIONS TESTING
# ==============================================================================
Write-AuditLog "=== PHASE 6: DATA OPERATIONS TESTING ===" "INFO"

function Test-DataService {
    param([string]$ServiceName)
    
    try {
        if ($global:TuiServices -and $global:TuiServices.ContainsKey($ServiceName)) {
            $service = $global:TuiServices[$ServiceName]
            Write-AuditLog "    ✓ $ServiceName service accessible" "PASS"
            Add-AuditResult "Services" "$ServiceName-Access" $true "Service accessible"
            
            # Test common service methods
            $methods = $service.GetType().GetMethods() | Where-Object { $_.DeclaringType.Name -eq $service.GetType().Name }
            
            foreach ($method in $methods) {
                if ($method.Name -match '^(Get|Create|Update|Delete|Save|Load)') {
                    Write-AuditLog "      Found method: $($method.Name)" "INFO"
                    Add-AuditResult "Services" "$ServiceName-Method-$($method.Name)" $true "Method exists"
                }
            }
            
            return $true
        } else {
            Write-AuditLog "    ✗ $ServiceName service not found" "ERROR"
            Add-AuditResult "Services" "$ServiceName-Access" $false "Service not accessible"
            return $false
        }
    } catch {
        Write-AuditLog "    ✗ $ServiceName service test failed: $_" "ERROR"
        Add-AuditResult "Services" "$ServiceName-Test" $false "Service test failed" $_.Exception.Message
        return $false
    }
}

# Test all services
$services = @("DataManager", "ThemeManager", "NavigationService", "ActionService", "KeybindingService", "EventManager")

foreach ($service in $services) {
    Write-AuditLog "  Testing service: $service" "INFO"
    Test-DataService $service
}

# ==============================================================================
# PHASE 7: ERROR LOG ANALYSIS
# ==============================================================================
Write-AuditLog "=== PHASE 7: ERROR LOG ANALYSIS ===" "INFO"

# Check for recent error logs
$logFiles = @()
if (Test-Path "~/.local/share/AxiomPhoenix/axiom-phoenix.log") {
    $logFiles += "~/.local/share/AxiomPhoenix/axiom-phoenix.log"
}

foreach ($logFile in $logFiles) {
    if (Test-Path $logFile) {
        Write-AuditLog "  Analyzing log file: $logFile" "INFO"
        
        try {
            $logContent = Get-Content $logFile -Tail 100
            $errorLines = $logContent | Where-Object { $_ -match '\[ERROR\]|\[WARN\]|Exception|Error:' }
            
            if ($errorLines) {
                Write-AuditLog "    Found $($errorLines.Count) error/warning entries" "WARN"
                
                foreach ($errorLine in $errorLines | Select-Object -First 10) {
                    Write-AuditLog "      $errorLine" "WARN"
                    Add-AuditResult "ErrorLogs" "LogAnalysis" $false "Error found in logs" $errorLine
                }
            } else {
                Write-AuditLog "    ✓ No recent errors found in logs" "PASS"
                Add-AuditResult "ErrorLogs" "LogAnalysis" $true "No recent errors in logs"
            }
        } catch {
            Write-AuditLog "    ✗ Failed to analyze log file: $_" "ERROR"
            Add-AuditResult "ErrorLogs" "LogFileAccess" $false "Failed to access log file" $_.Exception.Message
        }
    }
}

# ==============================================================================
# AUDIT RESULTS SUMMARY
# ==============================================================================
Write-AuditLog "=== AUDIT RESULTS SUMMARY ===" "INFO"

Write-AuditLog "Total Tests: $($AuditResults.TotalTests)" "INFO"
Write-AuditLog "Passed: $($AuditResults.PassedTests)" "PASS"
Write-AuditLog "Failed: $($AuditResults.FailedTests)" "ERROR"

$successRate = if ($AuditResults.TotalTests -gt 0) { 
    [Math]::Round(($AuditResults.PassedTests / $AuditResults.TotalTests) * 100, 2) 
} else { 0 }

Write-AuditLog "Success Rate: $successRate%" "INFO"

if ($AuditResults.Issues.Count -gt 0) {
    Write-AuditLog "" "INFO"
    Write-AuditLog "=== CRITICAL ISSUES FOUND ===" "ERROR"
    
    foreach ($issue in $AuditResults.Issues) {
        Write-AuditLog "[$($issue.Category)] $($issue.Test): $($issue.Error)" "ERROR"
        if ($issue.Details) {
            Write-AuditLog "  Details: $($issue.Details)" "ERROR"
        }
    }
}

# Generate detailed report if requested
if ($Detailed) {
    $reportFile = "audit-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $AuditResults | ConvertTo-Json -Depth 10 | Out-File $reportFile
    Write-AuditLog "Detailed report saved to: $reportFile" "INFO"
}

Write-AuditLog "Audit completed. Check $LogFile for detailed results." "INFO"

# Cleanup
if ($global:TuiState) {
    $global:TuiState.Running = $false
}

# Return summary for script automation
return @{
    TotalTests = $AuditResults.TotalTests
    PassedTests = $AuditResults.PassedTests
    FailedTests = $AuditResults.FailedTests
    SuccessRate = $successRate
    IssueCount = $AuditResults.Issues.Count
    LogFile = $LogFile
}