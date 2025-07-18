# ==============================================================================
# Enhanced Audit Logger - Comprehensive Validation Tracking
# ==============================================================================

class AuditLogger {
    [string] $LogFile
    [string] $ResultsFile  
    [hashtable] $TestResults
    [hashtable] $ComponentState
    [hashtable] $PerformanceMetrics
    [int] $TestCounter
    
    AuditLogger([string]$baseFileName) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $this.LogFile = "$baseFileName-$timestamp.log"
        $this.ResultsFile = "$baseFileName-results-$timestamp.json"
        $this.TestResults = @{}
        $this.ComponentState = @{}
        $this.PerformanceMetrics = @{}
        $this.TestCounter = 0
        
        # Initialize log file
        $this.WriteLog("=== COMPREHENSIVE SYSTEM AUDIT STARTED ===", "SYSTEM")
        $this.WriteLog("Timestamp: $(Get-Date)", "SYSTEM")
        $this.WriteLog("PowerShell Version: $($PSVersionTable.PSVersion)", "SYSTEM")
        $this.WriteLog("OS: $([System.Environment]::OSVersion)", "SYSTEM")
        $this.WriteLog("", "SYSTEM")
    }
    
    [void] WriteLog([string]$message, [string]$level = "INFO", [hashtable]$metadata = @{}) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = "[$timestamp] [$level] $message"
        
        # Add metadata if provided
        if ($metadata.Count -gt 0) {
            $metaString = ($metadata.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
            $logEntry += " | $metaString"
        }
        
        # Console output with colors
        $color = switch($level) {
            "PASS" { "Green" }
            "FAIL" { "Red" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            "PERF" { "Cyan" }
            "DATA" { "Magenta" }
            "SYSTEM" { "White" }
            default { "Gray" }
        }
        
        Write-Host $logEntry -ForegroundColor $color
        
        # File output
        Add-Content -Path $this.LogFile -Value $logEntry
    }
    
    [hashtable] StartTest([string]$category, [string]$testName, [string]$description = "") {
        $this.TestCounter++
        $testId = "T$($this.TestCounter.ToString().PadLeft(4, '0'))"
        
        $testInfo = @{
            TestId = $testId
            Category = $category
            Name = $testName
            Description = $description
            StartTime = Get-Date
            Status = "RUNNING"
            Duration = $null
            Result = $null
            Error = $null
            Metadata = @{}
            Screenshots = @()
            PerformanceData = @{}
        }
        
        if (-not $this.TestResults.ContainsKey($category)) {
            $this.TestResults[$category] = @{}
        }
        
        $this.TestResults[$category][$testName] = $testInfo
        
        $this.WriteLog "STARTING TEST: $testId - $category/$testName", "INFO", @{
            TestId = $testId
            Description = $description
        }
        
        return $testInfo
    }
    
    [void] EndTest([hashtable]$testInfo, [bool]$passed, [string]$result = "", [string]$error = "", [hashtable]$metadata = @{}) {
        $testInfo.Status = if ($passed) { "PASSED" } else { "FAILED" }
        $testInfo.Result = $result
        $testInfo.Error = $error
        $testInfo.Duration = (Get-Date) - $testInfo.StartTime
        $testInfo.Metadata = $metadata
        
        $level = if ($passed) { "PASS" } else { "FAIL" }
        $durationMs = [Math]::Round($testInfo.Duration.TotalMilliseconds, 2)
        
        $logMetadata = @{
            TestId = $testInfo.TestId
            Duration = "${durationMs}ms"
            Result = $result
        }
        
        if ($error) { $logMetadata.Error = $error }
        
        $this.WriteLog "COMPLETED TEST: $($testInfo.TestId) - $($testInfo.Category)/$($testInfo.Name)", $level, $logMetadata
        
        if ($metadata.Count -gt 0) {
            $this.WriteLog "  Test Metadata: $($metadata | ConvertTo-Json -Compress)", "DATA"
        }
    }
    
    [void] LogPerformance([string]$operation, [hashtable]$metrics) {
        if (-not $this.PerformanceMetrics.ContainsKey($operation)) {
            $this.PerformanceMetrics[$operation] = @()
        }
        
        $metrics.Timestamp = Get-Date
        $this.PerformanceMetrics[$operation] += $metrics
        
        $this.WriteLog "PERFORMANCE: $operation", "PERF", $metrics
    }
    
    [void] LogComponentState([string]$component, [hashtable]$state) {
        $this.ComponentState[$component] = $state
        $state.Timestamp = Get-Date
        
        $this.WriteLog "COMPONENT STATE: $component", "DATA", $state
    }
    
    [void] TakeScreenshot([string]$testId, [string]$description = "") {
        # Capture current screen state
        $screenshot = @{
            TestId = $testId
            Description = $description
            Timestamp = Get-Date
            ScreenDimensions = @{
                Width = [Console]::WindowWidth
                Height = [Console]::WindowHeight
            }
            CursorPosition = @{
                X = [Console]::CursorLeft
                Y = [Console]::CursorTop
            }
        }
        
        # Try to capture actual screen content if possible
        try {
            if ($global:TuiState -and $global:TuiState.CurrentScreen) {
                $screenshot.CurrentScreen = $global:TuiState.CurrentScreen.GetType().Name
                
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
        } catch {
            $screenshot.CaptureError = $_.Exception.Message
        }
        
        $this.WriteLog "SCREENSHOT: $testId - $description", "DATA", $screenshot
    }
    
    [hashtable] GetSummary() {
        $totalTests = 0
        $passedTests = 0
        $failedTests = 0
        $categories = @{}
        
        foreach ($category in $this.TestResults.Keys) {
            $categoryStats = @{
                Total = 0
                Passed = 0
                Failed = 0
                Tests = @{}
            }
            
            foreach ($testName in $this.TestResults[$category].Keys) {
                $test = $this.TestResults[$category][$testName]
                $totalTests++
                $categoryStats.Total++
                
                if ($test.Status -eq "PASSED") {
                    $passedTests++
                    $categoryStats.Passed++
                } elseif ($test.Status -eq "FAILED") {
                    $failedTests++
                    $categoryStats.Failed++
                }
                
                $categoryStats.Tests[$testName] = $test
            }
            
            $categories[$category] = $categoryStats
        }
        
        $successRate = if ($totalTests -gt 0) { 
            [Math]::Round(($passedTests / $totalTests) * 100, 2) 
        } else { 0 }
        
        return @{
            Summary = @{
                TotalTests = $totalTests
                PassedTests = $passedTests
                FailedTests = $failedTests
                SuccessRate = $successRate
                TestDuration = (Get-Date) - (Get-Date $this.TestResults.Values[0].Values[0].StartTime)
            }
            Categories = $categories
            PerformanceMetrics = $this.PerformanceMetrics
            ComponentState = $this.ComponentState
            LogFile = $this.LogFile
            ResultsFile = $this.ResultsFile
        }
    }
    
    [void] SaveResults() {
        $summary = $this.GetSummary()
        $summary | ConvertTo-Json -Depth 10 | Out-File $this.ResultsFile
        
        $this.WriteLog "=== AUDIT COMPLETED ===", "SYSTEM"
        $this.WriteLog "Total Tests: $($summary.Summary.TotalTests)", "SYSTEM"
        $this.WriteLog "Passed: $($summary.Summary.PassedTests)", "SYSTEM"
        $this.WriteLog "Failed: $($summary.Summary.FailedTests)", "SYSTEM"
        $this.WriteLog "Success Rate: $($summary.Summary.SuccessRate)%", "SYSTEM"
        $this.WriteLog "Results saved to: $($this.ResultsFile)", "SYSTEM"
    }
}

# ==============================================================================
# Enhanced Keystroke Testing System
# ==============================================================================

class KeystrokeTester {
    [AuditLogger] $Logger
    [string] $ScreenName
    [object] $Screen
    [hashtable] $KeystrokeMap
    [hashtable] $TestResults
    
    KeystrokeTester([AuditLogger]$logger, [string]$screenName, [object]$screen) {
        $this.Logger = $logger
        $this.ScreenName = $screenName
        $this.Screen = $screen
        $this.TestResults = @{}
        
        # Define comprehensive keystroke mapping
        $this.KeystrokeMap = @{
            # Navigation Keys
            Navigation = @{
                UpArrow = @{ Key = [ConsoleKey]::UpArrow; Description = "Move up/previous item"; Critical = $true }
                DownArrow = @{ Key = [ConsoleKey]::DownArrow; Description = "Move down/next item"; Critical = $true }
                LeftArrow = @{ Key = [ConsoleKey]::LeftArrow; Description = "Move left/previous column"; Critical = $true }
                RightArrow = @{ Key = [ConsoleKey]::RightArrow; Description = "Move right/next column"; Critical = $true }
                Home = @{ Key = [ConsoleKey]::Home; Description = "Move to beginning"; Critical = $false }
                End = @{ Key = [ConsoleKey]::End; Description = "Move to end"; Critical = $false }
                PageUp = @{ Key = [ConsoleKey]::PageUp; Description = "Page up"; Critical = $false }
                PageDown = @{ Key = [ConsoleKey]::PageDown; Description = "Page down"; Critical = $false }
            }
            
            # Action Keys
            Action = @{
                Enter = @{ Key = [ConsoleKey]::Enter; Description = "Activate/Select"; Critical = $true }
                Space = @{ Key = [ConsoleKey]::Spacebar; Description = "Toggle/Select"; Critical = $true }
                Tab = @{ Key = [ConsoleKey]::Tab; Description = "Next focus"; Critical = $true }
                Escape = @{ Key = [ConsoleKey]::Escape; Description = "Cancel/Back"; Critical = $true }
                Backspace = @{ Key = [ConsoleKey]::Backspace; Description = "Delete previous"; Critical = $true }
                Delete = @{ Key = [ConsoleKey]::Delete; Description = "Delete current"; Critical = $true }
                Insert = @{ Key = [ConsoleKey]::Insert; Description = "Insert/New"; Critical = $false }
            }
            
            # Function Keys
            Function = @{
                F1 = @{ Key = [ConsoleKey]::F1; Description = "Help"; Critical = $false }
                F2 = @{ Key = [ConsoleKey]::F2; Description = "Edit"; Critical = $false }
                F3 = @{ Key = [ConsoleKey]::F3; Description = "Search"; Critical = $false }
                F4 = @{ Key = [ConsoleKey]::F4; Description = "Action"; Critical = $false }
                F5 = @{ Key = [ConsoleKey]::F5; Description = "Refresh"; Critical = $false }
                F6 = @{ Key = [ConsoleKey]::F6; Description = "Switch"; Critical = $false }
                F7 = @{ Key = [ConsoleKey]::F7; Description = "Create"; Critical = $false }
                F8 = @{ Key = [ConsoleKey]::F8; Description = "Delete"; Critical = $false }
                F9 = @{ Key = [ConsoleKey]::F9; Description = "Menu"; Critical = $false }
                F10 = @{ Key = [ConsoleKey]::F10; Description = "Menu"; Critical = $false }
                F11 = @{ Key = [ConsoleKey]::F11; Description = "Fullscreen"; Critical = $false }
                F12 = @{ Key = [ConsoleKey]::F12; Description = "Settings"; Critical = $false }
            }
            
            # Control Keys
            Control = @{
                "Ctrl+S" = @{ Key = [ConsoleKey]::S; Modifiers = @{ Ctrl = $true }; Description = "Save"; Critical = $true }
                "Ctrl+N" = @{ Key = [ConsoleKey]::N; Modifiers = @{ Ctrl = $true }; Description = "New"; Critical = $true }
                "Ctrl+O" = @{ Key = [ConsoleKey]::O; Modifiers = @{ Ctrl = $true }; Description = "Open"; Critical = $false }
                "Ctrl+P" = @{ Key = [ConsoleKey]::P; Modifiers = @{ Ctrl = $true }; Description = "Print/Palette"; Critical = $false }
                "Ctrl+F" = @{ Key = [ConsoleKey]::F; Modifiers = @{ Ctrl = $true }; Description = "Find"; Critical = $false }
                "Ctrl+Z" = @{ Key = [ConsoleKey]::Z; Modifiers = @{ Ctrl = $true }; Description = "Undo"; Critical = $false }
                "Ctrl+Y" = @{ Key = [ConsoleKey]::Y; Modifiers = @{ Ctrl = $true }; Description = "Redo"; Critical = $false }
                "Ctrl+A" = @{ Key = [ConsoleKey]::A; Modifiers = @{ Ctrl = $true }; Description = "Select All"; Critical = $false }
                "Ctrl+C" = @{ Key = [ConsoleKey]::C; Modifiers = @{ Ctrl = $true }; Description = "Copy"; Critical = $false }
                "Ctrl+V" = @{ Key = [ConsoleKey]::V; Modifiers = @{ Ctrl = $true }; Description = "Paste"; Critical = $false }
                "Ctrl+X" = @{ Key = [ConsoleKey]::X; Modifiers = @{ Ctrl = $true }; Description = "Cut"; Critical = $false }
            }
            
            # Alt Keys
            Alt = @{
                "Alt+F4" = @{ Key = [ConsoleKey]::F4; Modifiers = @{ Alt = $true }; Description = "Close"; Critical = $true }
                "Alt+Tab" = @{ Key = [ConsoleKey]::Tab; Modifiers = @{ Alt = $true }; Description = "Switch"; Critical = $false }
                "Alt+Enter" = @{ Key = [ConsoleKey]::Enter; Modifiers = @{ Alt = $true }; Description = "Properties"; Critical = $false }
            }
            
            # Shift Keys
            Shift = @{
                "Shift+Tab" = @{ Key = [ConsoleKey]::Tab; Modifiers = @{ Shift = $true }; Description = "Previous focus"; Critical = $true }
                "Shift+F10" = @{ Key = [ConsoleKey]::F10; Modifiers = @{ Shift = $true }; Description = "Context menu"; Critical = $false }
                "Shift+Delete" = @{ Key = [ConsoleKey]::Delete; Modifiers = @{ Shift = $true }; Description = "Force delete"; Critical = $false }
            }
        }
    }
    
    [void] TestAllKeystrokes() {
        $this.Logger.WriteLog "Starting comprehensive keystroke testing for screen: $($this.ScreenName)", "INFO"
        
        # Test each category
        foreach ($category in $this.KeystrokeMap.Keys) {
            $this.Logger.WriteLog "Testing $category keys...", "INFO"
            
            foreach ($keyName in $this.KeystrokeMap[$category].Keys) {
                $keyInfo = $this.KeystrokeMap[$category][$keyName]
                $this.TestKeystroke($category, $keyName, $keyInfo)
            }
        }
        
        # Test character input
        $this.TestCharacterInput()
        
        # Generate summary
        $this.GenerateSummary()
    }
    
    [void] TestKeystroke([string]$category, [string]$keyName, [hashtable]$keyInfo) {
        $testInfo = $this.Logger.StartTest("Keystroke-$category", "$($this.ScreenName)-$keyName", $keyInfo.Description)
        
        try {
            # Take screenshot before
            $this.Logger.TakeScreenshot($testInfo.TestId, "Before $keyName")
            
            # Capture screen state before keystroke
            $preState = $this.CaptureScreenState()
            
            # Create the key info object
            $modifiers = $keyInfo.Modifiers
            $keyInfo_obj = [System.ConsoleKeyInfo]::new(
                [char]0,
                $keyInfo.Key,
                $modifiers.Shift -eq $true,
                $modifiers.Alt -eq $true,
                $modifiers.Ctrl -eq $true
            )
            
            # Execute the keystroke
            $startTime = Get-Date
            $result = $null
            
            if ($this.Screen.PSObject.Methods['HandleInput']) {
                $result = $this.Screen.HandleInput($keyInfo_obj)
            } else {
                throw "Screen does not have HandleInput method"
            }
            
            $executionTime = (Get-Date) - $startTime
            
            # Capture screen state after keystroke
            $postState = $this.CaptureScreenState()
            
            # Take screenshot after
            $this.Logger.TakeScreenshot($testInfo.TestId, "After $keyName")
            
            # Analyze the result
            $stateChanges = $this.CompareStates($preState, $postState)
            
            # Log performance
            $this.Logger.LogPerformance("Keystroke-$keyName", @{
                ExecutionTime = $executionTime.TotalMilliseconds
                StateChanges = $stateChanges.Count
                Result = $result
            })
            
            # Record successful test
            $this.TestResults["$category-$keyName"] = @{
                Success = $true
                ExecutionTime = $executionTime
                Result = $result
                StateChanges = $stateChanges
                PreState = $preState
                PostState = $postState
            }
            
            $this.Logger.EndTest($testInfo, $true, $result, "", @{
                ExecutionTime = $executionTime.TotalMilliseconds
                StateChanges = $stateChanges.Count
                Critical = $keyInfo.Critical
            })
            
        } catch {
            $error = $_.Exception.Message
            
            # Record failed test
            $this.TestResults["$category-$keyName"] = @{
                Success = $false
                Error = $error
                Critical = $keyInfo.Critical
            }
            
            $this.Logger.EndTest($testInfo, $false, "", $error, @{
                Critical = $keyInfo.Critical
                KeyCategory = $category
            })
        }
    }
    
    [void] TestCharacterInput() {
        $this.Logger.WriteLog "Testing character input...", "INFO"
        
        # Test various character types
        $charCategories = @{
            Lowercase = @('a', 'b', 'c', 'm', 'x', 'z')
            Uppercase = @('A', 'B', 'C', 'M', 'X', 'Z')
            Numbers = @('0', '1', '2', '5', '9')
            Symbols = @('!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '-', '_', '=', '+')
            Punctuation = @('.', ',', ';', ':', '?', '/', '\', '|', '[', ']', '{', '}')
            Whitespace = @(' ', "`t")
        }
        
        foreach ($category in $charCategories.Keys) {
            foreach ($char in $charCategories[$category]) {
                $testInfo = $this.Logger.StartTest("Character-$category", "$($this.ScreenName)-Char-$([int][char]$char)", "Character input: '$char'")
                
                try {
                    $keyInfo = [System.ConsoleKeyInfo]::new($char, [ConsoleKey]::A, $false, $false, $false)
                    
                    if ($this.Screen.PSObject.Methods['HandleInput']) {
                        $result = $this.Screen.HandleInput($keyInfo)
                        $this.Logger.EndTest($testInfo, $true, $result, "", @{
                            Character = $char
                            CharCode = [int][char]$char
                            Category = $category
                        })
                    } else {
                        throw "Screen does not have HandleInput method"
                    }
                } catch {
                    $this.Logger.EndTest($testInfo, $false, "", $_.Exception.Message, @{
                        Character = $char
                        CharCode = [int][char]$char
                        Category = $category
                    })
                }
            }
        }
    }
    
    [hashtable] CaptureScreenState() {
        $state = @{
            Timestamp = Get-Date
            ScreenType = $this.Screen.GetType().Name
            Properties = @{}
        }
        
        # Capture relevant properties
        $props = @('Name', 'Title', 'Width', 'Height', 'HasFocus', 'IsVisible', 'SelectedIndex', 'CurrentIndex', 'Items', 'Text', 'Value', 'Children')
        
        foreach ($prop in $props) {
            if ($this.Screen.PSObject.Properties[$prop]) {
                try {
                    $value = $this.Screen.$prop
                    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
                        $state.Properties[$prop] = @($value).Count
                    } else {
                        $state.Properties[$prop] = $value
                    }
                } catch {
                    $state.Properties[$prop] = "Error: $($_.Exception.Message)"
                }
            }
        }
        
        return $state
    }
    
    [array] CompareStates([hashtable]$before, [hashtable]$after) {
        $changes = @()
        
        foreach ($prop in $before.Properties.Keys) {
            if ($after.Properties.ContainsKey($prop)) {
                if ($before.Properties[$prop] -ne $after.Properties[$prop]) {
                    $changes += @{
                        Property = $prop
                        Before = $before.Properties[$prop]
                        After = $after.Properties[$prop]
                    }
                }
            }
        }
        
        return $changes
    }
    
    [void] GenerateSummary() {
        $totalTests = $this.TestResults.Count
        $successfulTests = ($this.TestResults.Values | Where-Object { $_.Success }).Count
        $failedTests = $totalTests - $successfulTests
        $criticalFailures = ($this.TestResults.Values | Where-Object { -not $_.Success -and $_.Critical }).Count
        
        $this.Logger.WriteLog "Keystroke testing summary for $($this.ScreenName):", "INFO"
        $this.Logger.WriteLog "  Total keystrokes tested: $totalTests", "INFO"
        $this.Logger.WriteLog "  Successful: $successfulTests", "PASS"
        $this.Logger.WriteLog "  Failed: $failedTests", "FAIL"
        $this.Logger.WriteLog "  Critical failures: $criticalFailures", "ERROR"
        
        $successRate = if ($totalTests -gt 0) { [Math]::Round(($successfulTests / $totalTests) * 100, 2) } else { 0 }
        $this.Logger.WriteLog "  Success rate: $successRate%", "INFO"
        
        # Log failed tests
        $failedTests = $this.TestResults.GetEnumerator() | Where-Object { -not $_.Value.Success }
        foreach ($failedTest in $failedTests) {
            $level = if ($failedTest.Value.Critical) { "ERROR" } else { "WARN" }
            $this.Logger.WriteLog "  Failed: $($failedTest.Key) - $($failedTest.Value.Error)", $level
        }
        
        # Store summary in logger
        $this.Logger.LogComponentState("KeystrokeTesting-$($this.ScreenName)", @{
            TotalTests = $totalTests
            SuccessfulTests = $successfulTests
            FailedTests = $failedTests
            CriticalFailures = $criticalFailures
            SuccessRate = $successRate
            TestResults = $this.TestResults
        })
    }
}

# ==============================================================================
# Enhanced Screen Testing Functions
# ==============================================================================

function Test-ScreenComprehensively {
    param(
        [AuditLogger]$Logger,
        [string]$ScreenName,
        [object]$Screen
    )
    
    $Logger.WriteLog "Starting comprehensive testing of screen: $ScreenName", "INFO"
    
    # Test basic screen functionality
    Test-ScreenBasicFunctionality -Logger $Logger -ScreenName $ScreenName -Screen $Screen
    
    # Test all keystrokes
    $keystrokeTester = [KeystrokeTester]::new($Logger, $ScreenName, $Screen)
    $keystrokeTester.TestAllKeystrokes()
    
    # Test screen navigation
    Test-ScreenNavigation -Logger $Logger -ScreenName $ScreenName -Screen $Screen
    
    # Test screen rendering
    Test-ScreenRendering -Logger $Logger -ScreenName $ScreenName -Screen $Screen
    
    $Logger.WriteLog "Completed comprehensive testing of screen: $ScreenName", "INFO"
}

function Test-ScreenBasicFunctionality {
    param(
        [AuditLogger]$Logger,
        [string]$ScreenName,
        [object]$Screen
    )
    
    # Test screen instantiation
    $testInfo = $Logger.StartTest("Screen-Basic", "$ScreenName-Instantiation", "Screen object instantiation")
    if ($Screen) {
        $Logger.EndTest($testInfo, $true, $Screen.GetType().Name, "", @{
            ScreenType = $Screen.GetType().Name
            Assembly = $Screen.GetType().Assembly.GetName().Name
        })
    } else {
        $Logger.EndTest($testInfo, $false, "", "Screen object is null")
    }
    
    # Test common methods
    $commonMethods = @('Initialize', 'OnEnter', 'OnExit', 'Render', 'HandleInput', 'Dispose')
    foreach ($method in $commonMethods) {
        $testInfo = $Logger.StartTest("Screen-Methods", "$ScreenName-$method", "Method: $method")
        
        if ($Screen.PSObject.Methods[$method]) {
            # Method exists
            $methodInfo = $Screen.PSObject.Methods[$method]
            $paramCount = $methodInfo.OverloadDefinitions.Count
            $Logger.EndTest($testInfo, $true, "Method exists", "", @{
                ParameterCount = $paramCount
                OverloadDefinitions = $methodInfo.OverloadDefinitions
            })
        } else {
            $Logger.EndTest($testInfo, $false, "", "Method not found")
        }
    }
    
    # Test common properties
    $commonProps = @('Name', 'Title', 'Width', 'Height', 'HasFocus', 'IsVisible', 'Children')
    foreach ($prop in $commonProps) {
        $testInfo = $Logger.StartTest("Screen-Properties", "$ScreenName-$prop", "Property: $prop")
        
        if ($Screen.PSObject.Properties[$prop]) {
            try {
                $value = $Screen.$prop
                $Logger.EndTest($testInfo, $true, "$value", "", @{
                    PropertyType = $Screen.PSObject.Properties[$prop].TypeNameOfValue
                    Value = $value
                })
            } catch {
                $Logger.EndTest($testInfo, $false, "", $_.Exception.Message)
            }
        } else {
            $Logger.EndTest($testInfo, $false, "", "Property not found")
        }
    }
}

function Test-ScreenNavigation {
    param(
        [AuditLogger]$Logger,
        [string]$ScreenName,
        [object]$Screen
    )
    
    $Logger.WriteLog "Testing screen navigation for: $ScreenName", "INFO"
    
    # Test navigation to this screen
    $testInfo = $Logger.StartTest("Screen-Navigation", "$ScreenName-NavigateToScreen", "Navigate to screen")
    
    try {
        if ($global:TuiState -and $global:TuiState.PSObject.Properties['NavigationService']) {
            $navService = $global:TuiState.NavigationService
            if ($navService -and $navService.PSObject.Methods['NavigateToScreen']) {
                $navService.NavigateToScreen($ScreenName)
                $Logger.EndTest($testInfo, $true, "Navigation successful", "", @{
                    NavigationService = $navService.GetType().Name
                    CurrentScreen = $global:TuiState.CurrentScreen.GetType().Name
                })
            } else {
                $Logger.EndTest($testInfo, $false, "", "NavigationService.NavigateToScreen method not found")
            }
        } else {
            $Logger.EndTest($testInfo, $false, "", "NavigationService not found in TuiState")
        }
    } catch {
        $Logger.EndTest($testInfo, $false, "", $_.Exception.Message)
    }
}

function Test-ScreenRendering {
    param(
        [AuditLogger]$Logger,
        [string]$ScreenName,
        [object]$Screen
    )
    
    $Logger.WriteLog "Testing screen rendering for: $ScreenName", "INFO"
    
    # Test render method
    $testInfo = $Logger.StartTest("Screen-Rendering", "$ScreenName-Render", "Screen render method")
    
    try {
        if ($Screen.PSObject.Methods['Render']) {
            $startTime = Get-Date
            $Screen.Render()
            $renderTime = (Get-Date) - $startTime
            
            $Logger.LogPerformance("Screen-Render-$ScreenName", @{
                RenderTime = $renderTime.TotalMilliseconds
                ScreenType = $Screen.GetType().Name
            })
            
            $Logger.EndTest($testInfo, $true, "Render completed", "", @{
                RenderTime = $renderTime.TotalMilliseconds
            })
        } else {
            $Logger.EndTest($testInfo, $false, "", "Render method not found")
        }
    } catch {
        $Logger.EndTest($testInfo, $false, "", $_.Exception.Message)
    }
    
    # Test buffer state if available
    if ($Screen.PSObject.Properties['Buffer']) {
        $testInfo = $Logger.StartTest("Screen-Buffer", "$ScreenName-Buffer", "Screen buffer state")
        
        try {
            $buffer = $Screen.Buffer
            if ($buffer) {
                $Logger.EndTest($testInfo, $true, "Buffer available", "", @{
                    BufferType = $buffer.GetType().Name
                    Width = $buffer.Width
                    Height = $buffer.Height
                    IsDirty = $buffer.IsDirty
                })
            } else {
                $Logger.EndTest($testInfo, $false, "", "Buffer is null")
            }
        } catch {
            $Logger.EndTest($testInfo, $false, "", $_.Exception.Message)
        }
    }
}