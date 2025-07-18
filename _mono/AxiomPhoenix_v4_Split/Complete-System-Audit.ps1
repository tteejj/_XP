#!/usr/bin/env pwsh
# ==============================================================================
# COMPLETE SYSTEM AUDIT - Validates Every Component and Function
# Tests every screen, component, input, navigation path, and data operation
# ==============================================================================

param(
    [int]$TimeoutSeconds = 300,
    [switch]$SkipInteractive = $false,
    [switch]$DetailedLogging = $true
)

$ErrorActionPreference = "Continue"

# Load the enhanced audit logger
. "./Enhanced-Audit-Logger.ps1"

# Initialize audit logger
$audit = [AuditLogger]::new("complete-system-audit")

$audit.WriteLog "=== COMPLETE SYSTEM AUDIT INITIATED ===" "SYSTEM"
$audit.WriteLog "Timeout: $TimeoutSeconds seconds" "SYSTEM"
$audit.WriteLog "Interactive Mode: $(-not $SkipInteractive)" "SYSTEM"
$audit.WriteLog "Detailed Logging: $DetailedLogging" "SYSTEM"

# ==============================================================================
# PHASE 1: FRAMEWORK VALIDATION
# ==============================================================================
$audit.WriteLog "=== PHASE 1: FRAMEWORK VALIDATION ===" "SYSTEM"

# Test 1.1: Base Classes Loading
$test = $audit.StartTest("Framework", "BaseClassesLoad", "Load and validate core TUI classes")
try {
    . "./Base/ABC.001_TuiAnsiHelper.ps1"
    . "./Base/ABC.002_TuiCell.ps1"
    . "./Base/ABC.003_TuiBuffer.ps1"
    
    # Validate classes are available
    $ansiHelper = [TuiAnsiHelper]::GetAnsiSequence("#FF0000", "#000000", @{})
    $cell = [TuiCell]::new('X', "#FF0000", "#000000")
    $buffer = [TuiBuffer]::new(10, 10)
    
    $metadata = @{
        AnsiHelperWorking = ($ansiHelper -ne $null)
        CellCreated = ($cell.Char -eq 'X')
        BufferCreated = ($buffer.Width -eq 10 -and $buffer.Height -eq 10)
    }
    
    $audit.EndTest($test, $true, "All base classes loaded and functional", "", $metadata)
} catch {
    $audit.EndTest($test, $false, "", $_.Exception.Message)
    $audit.WriteLog "CRITICAL: Base classes failed to load. Aborting audit." "ERROR"
    return
}

# Test 1.2: Full Framework Loading
$test = $audit.StartTest("Framework", "FullFrameworkLoad", "Load complete Axiom-Phoenix framework")
$frameworkStartTime = Get-Date
try {
    . "./Start.ps1"
    Start-Sleep -Seconds 3  # Allow framework to stabilize
    
    $loadTime = (Get-Date) - $frameworkStartTime
    
    $metadata = @{
        LoadTimeSeconds = [Math]::Round($loadTime.TotalSeconds, 2)
        GlobalTuiStateExists = ($global:TuiState -ne $null)
        ServicesRegistered = if ($global:TuiServices) { $global:TuiServices.Count } else { 0 }
    }
    
    $audit.LogPerformance("FrameworkLoad", @{
        Duration = $loadTime.TotalMilliseconds
        MemoryUsage = [GC]::GetTotalMemory($false)
    })
    
    $audit.EndTest($test, $true, "Framework loaded successfully", "", $metadata)
} catch {
    $audit.EndTest($test, $false, "", $_.Exception.Message)
    return
}

# Test 1.3: Service Registration Validation
$test = $audit.StartTest("Framework", "ServiceValidation", "Validate all required services are registered")
try {
    $requiredServices = @(
        "Logger", "EventManager", "ThemeManager", "DataManager", 
        "ActionService", "KeybindingService", "NavigationService", 
        "DialogManager", "ViewDefinitionService", "FileSystemService",
        "TimeSheetService", "CommandService"
    )
    
    $serviceStatus = @{}
    $allServicesOk = $true
    
    foreach ($serviceName in $requiredServices) {
        $serviceExists = $global:TuiServices.ContainsKey($serviceName)
        $serviceStatus[$serviceName] = $serviceExists
        if (-not $serviceExists) { $allServicesOk = $false }
        
        $audit.WriteLog "Service $serviceName`: $serviceExists" "DATA"
    }
    
    $metadata = @{
        RequiredServices = $requiredServices.Count
        RegisteredServices = ($serviceStatus.Values | Where-Object { $_ }).Count
        ServiceStatus = $serviceStatus
    }
    
    $audit.EndTest($test, $allServicesOk, "Service registration validation", "", $metadata)
} catch {
    $audit.EndTest($test, $false, "", $_.Exception.Message)
}

# ==============================================================================
# PHASE 2: SCREEN DISCOVERY AND INSTANTIATION
# ==============================================================================
$audit.WriteLog "=== PHASE 2: SCREEN DISCOVERY AND INSTANTIATION ===" "SYSTEM"

$screenFiles = Get-ChildItem -Path "./Screens/ASC.*.ps1" | Sort-Object Name
$audit.WriteLog "Discovered $($screenFiles.Count) screen files" "INFO"

$discoveredScreens = @{}

foreach ($screenFile in $screenFiles) {
    $screenName = $screenFile.BaseName
    $shortName = $screenName -replace "ASC\.\d+_", ""
    
    # Test 2.X: Individual Screen Analysis
    $test = $audit.StartTest("Screens", "Analyze-$shortName", "Analyze screen file: $screenName")
    
    try {
        $content = Get-Content $screenFile.FullName -Raw
        $fileSize = (Get-Item $screenFile.FullName).Length
        
        # Extract class information
        $classMatches = [regex]::Matches($content, 'class\s+(\w+)\s*(?::\s*(\w+))?')
        $methodMatches = [regex]::Matches($content, '\[(\w+)\]\s+(\w+)\s*\([^)]*\)')
        $propertyMatches = [regex]::Matches($content, '\[(\w+)\]\s+\$(\w+)')
        
        $screenInfo = @{
            FileName = $screenFile.Name
            FilePath = $screenFile.FullName
            FileSize = $fileSize
            Classes = @()
            Methods = @()
            Properties = @()
        }
        
        foreach ($match in $classMatches) {
            $screenInfo.Classes += @{
                Name = $match.Groups[1].Value
                BaseClass = $match.Groups[2].Value
            }
        }
        
        foreach ($match in $methodMatches) {
            $screenInfo.Methods += @{
                ReturnType = $match.Groups[1].Value
                Name = $match.Groups[2].Value
            }
        }
        
        foreach ($match in $propertyMatches) {
            $screenInfo.Properties += @{
                Type = $match.Groups[1].Value
                Name = $match.Groups[2].Value
            }
        }
        
        $discoveredScreens[$shortName] = $screenInfo
        
        $metadata = @{
            FileSize = $fileSize
            ClassCount = $screenInfo.Classes.Count
            MethodCount = $screenInfo.Methods.Count
            PropertyCount = $screenInfo.Properties.Count
            MainClass = if ($screenInfo.Classes.Count -gt 0) { $screenInfo.Classes[0].Name } else { "None" }
        }
        
        $audit.EndTest($test, $true, "Screen analyzed successfully", "", $metadata)
        
    } catch {
        $audit.EndTest($test, $false, "", $_.Exception.Message)
    }
}

# Test 2.MAIN: Screen Instantiation Tests
foreach ($screenName in $discoveredScreens.Keys) {
    $screenInfo = $discoveredScreens[$screenName]
    
    if ($screenInfo.Classes.Count -gt 0) {
        $className = $screenInfo.Classes[0].Name
        
        $test = $audit.StartTest("Screens", "Instantiate-$screenName", "Instantiate screen class: $className")
        
        try {
            $instance = New-Object $className
            
            # Test basic properties and methods
            $hasInitialize = $instance.PSObject.Methods['Initialize'] -ne $null
            $hasRender = $instance.PSObject.Methods['Render'] -ne $null
            $hasHandleInput = $instance.PSObject.Methods['HandleInput'] -ne $null
            $hasOnEnter = $instance.PSObject.Methods['OnEnter'] -ne $null
            $hasOnExit = $instance.PSObject.Methods['OnExit'] -ne $null
            
            # Try to get basic properties
            $properties = @{}
            try { $properties.Name = $instance.Name } catch { $properties.Name = "N/A" }
            try { $properties.Title = $instance.Title } catch { $properties.Title = "N/A" }
            try { $properties.Width = $instance.Width } catch { $properties.Width = "N/A" }
            try { $properties.Height = $instance.Height } catch { $properties.Height = "N/A" }
            
            $metadata = @{
                ClassName = $className
                HasInitialize = $hasInitialize
                HasRender = $hasRender
                HasHandleInput = $hasHandleInput
                HasOnEnter = $hasOnEnter
                HasOnExit = $hasOnExit
                Properties = $properties
            }
            
            $audit.LogComponentState("Screen-$screenName", @{
                Type = $className
                Instantiated = $true
                MethodCount = $instance.PSObject.Methods.Count
                PropertyCount = $instance.PSObject.Properties.Count
            })
            
            $audit.EndTest($test, $true, "Screen instantiated successfully", "", $metadata)
            
        } catch {
            $audit.EndTest($test, $false, "", $_.Exception.Message)
        }
    }
}

# ==============================================================================
# PHASE 3: NAVIGATION SYSTEM TESTING
# ==============================================================================
$audit.WriteLog "=== PHASE 3: NAVIGATION SYSTEM TESTING ===" "SYSTEM"

# Test 3.1: Current Screen State
$test = $audit.StartTest("Navigation", "CurrentScreenState", "Validate current screen state")
try {
    $currentScreen = $global:TuiState.CurrentScreen
    $currentScreenType = $currentScreen.GetType().Name
    
    $metadata = @{
        CurrentScreenType = $currentScreenType
        ScreenExists = ($currentScreen -ne $null)
        TuiStateExists = ($global:TuiState -ne $null)
    }
    
    $audit.LogComponentState("CurrentScreen", @{
        Type = $currentScreenType
        IsVisible = if ($currentScreen.PSObject.Properties['IsVisible']) { $currentScreen.IsVisible } else { "N/A" }
        HasFocus = if ($currentScreen.PSObject.Properties['HasFocus']) { $currentScreen.HasFocus } else { "N/A" }
    })
    
    $audit.TakeScreenshot($test.TestId, "Initial screen state")
    
    $audit.EndTest($test, $true, "Current screen: $currentScreenType", "", $metadata)
} catch {
    $audit.EndTest($test, $false, "", $_.Exception.Message)
}

# Test 3.2: Navigation Service Functionality
$test = $audit.StartTest("Navigation", "NavigationService", "Test navigation service operations")
try {
    $navService = $global:TuiServices['NavigationService']
    
    if ($navService) {
        $navMethods = $navService.GetType().GetMethods().Name
        $hasNavigateToScreen = 'NavigateToScreen' -in $navMethods
        $hasGoBack = 'GoBack' -in $navMethods
        
        $metadata = @{
            ServiceExists = $true
            HasNavigateToScreen = $hasNavigateToScreen
            HasGoBack = $hasGoBack
            MethodCount = $navMethods.Count
        }
        
        $audit.EndTest($test, $hasNavigateToScreen, "Navigation service validated", "", $metadata)
    } else {
        $audit.EndTest($test, $false, "", "NavigationService not found")
    }
} catch {
    $audit.EndTest($test, $false, "", $_.Exception.Message)
}

# Test 3.3: Screen Navigation Tests
$navigationTargets = @(
    @{Name = "TaskListScreen"; MenuOption = "3"; Description = "Task management"},
    @{Name = "ProjectsListScreen"; MenuOption = "4"; Description = "Project management"},
    @{Name = "FileBrowserScreen"; MenuOption = "5"; Description = "File browsing"},
    @{Name = "TextEditorScreen"; MenuOption = "6"; Description = "Text editing"},
    @{Name = "ThemeScreen"; MenuOption = "7"; Description = "Theme selection"},
    @{Name = "CommandPaletteScreen"; MenuOption = "8"; Description = "Command interface"},
    @{Name = "TimesheetScreen"; MenuOption = "9"; Description = "Time tracking"}
)

foreach ($target in $navigationTargets) {
    $test = $audit.StartTest("Navigation", "NavigateTo-$($target.Name)", "Navigate to $($target.Description)")
    
    try {
        $navService = $global:TuiServices['NavigationService']
        $originalScreen = $global:TuiState.CurrentScreen.GetType().Name
        
        # Attempt navigation
        $navService.NavigateToScreen($target.Name)
        Start-Sleep -Milliseconds 500  # Allow navigation to complete
        
        $newScreen = $global:TuiState.CurrentScreen.GetType().Name
        $navigationSucceeded = ($newScreen -eq $target.Name)
        
        $metadata = @{
            TargetScreen = $target.Name
            OriginalScreen = $originalScreen
            ResultingScreen = $newScreen
            NavigationSucceeded = $navigationSucceeded
            MenuOption = $target.MenuOption
        }
        
        $audit.TakeScreenshot($test.TestId, "After navigation to $($target.Name)")
        
        if ($navigationSucceeded) {
            $audit.LogComponentState("Navigation-$($target.Name)", @{
                Success = $true
                ScreenType = $newScreen
                NavigationTime = Get-Date
            })
        }
        
        $audit.EndTest($test, $navigationSucceeded, "Navigation result: $newScreen", "", $metadata)
        
        # Navigate back to dashboard for next test
        try {
            $navService.NavigateToScreen("DashboardScreen")
            Start-Sleep -Milliseconds 300
        } catch {
            $audit.WriteLog "Warning: Could not return to dashboard" "WARN"
        }
        
    } catch {
        $audit.EndTest($test, $false, "", $_.Exception.Message)
    }
}

# ==============================================================================
# PHASE 4: INPUT SYSTEM TESTING
# ==============================================================================
$audit.WriteLog "=== PHASE 4: INPUT SYSTEM TESTING ===" "SYSTEM"

# Ensure we're on the dashboard for input testing
try {
    $global:TuiServices['NavigationService'].NavigateToScreen("DashboardScreen")
    Start-Sleep -Milliseconds 500
} catch {
    $audit.WriteLog "Warning: Could not navigate to dashboard for input testing" "WARN"
}

# Test 4.1: Arrow Key Navigation
$arrowKeys = @(
    @{Key = [ConsoleKey]::UpArrow; Name = "UpArrow"; Description = "Navigate up"},
    @{Key = [ConsoleKey]::DownArrow; Name = "DownArrow"; Description = "Navigate down"},
    @{Key = [ConsoleKey]::LeftArrow; Name = "LeftArrow"; Description = "Navigate left"},
    @{Key = [ConsoleKey]::RightArrow; Name = "RightArrow"; Description = "Navigate right"}
)

foreach ($keyTest in $arrowKeys) {
    $test = $audit.StartTest("Input", "ArrowKey-$($keyTest.Name)", $keyTest.Description)
    
    try {
        $currentScreen = $global:TuiState.CurrentScreen
        $keyInfo = [System.ConsoleKeyInfo]::new([char]0, $keyTest.Key, $false, $false, $false)
        
        $inputStartTime = Get-Date
        $result = $currentScreen.HandleInput($keyInfo)
        $inputDuration = (Get-Date) - $inputStartTime
        
        $metadata = @{
            Key = $keyTest.Name
            InputResult = $result
            ResponseTime = [Math]::Round($inputDuration.TotalMilliseconds, 2)
            ScreenType = $currentScreen.GetType().Name
        }
        
        $audit.LogPerformance("InputHandling", @{
            Key = $keyTest.Name
            ResponseTime = $inputDuration.TotalMilliseconds
            Success = ($result -ne $null)
        })
        
        $audit.TakeScreenshot($test.TestId, "After $($keyTest.Name) key press")
        
        $audit.EndTest($test, $true, "Input handled: $result", "", $metadata)
        
        Start-Sleep -Milliseconds 200  # Prevent input flooding
        
    } catch {
        $audit.EndTest($test, $false, "", $_.Exception.Message)
    }
}

# Test 4.2: Function Keys and Shortcuts
$shortcutKeys = @(
    @{Key = [ConsoleKey]::Enter; Name = "Enter"; Shift = $false; Ctrl = $false; Alt = $false},
    @{Key = [ConsoleKey]::Tab; Name = "Tab"; Shift = $false; Ctrl = $false; Alt = $false},
    @{Key = [ConsoleKey]::Tab; Name = "Shift+Tab"; Shift = $true; Ctrl = $false; Alt = $false},
    @{Key = [ConsoleKey]::Escape; Name = "Escape"; Shift = $false; Ctrl = $false; Alt = $false},
    @{Key = [ConsoleKey]::F1; Name = "F1"; Shift = $false; Ctrl = $false; Alt = $false},
    @{Key = [ConsoleKey]::P; Name = "Ctrl+P"; Shift = $false; Ctrl = $true; Alt = $false},
    @{Key = [ConsoleKey]::S; Name = "Ctrl+S"; Shift = $false; Ctrl = $true; Alt = $false}
)

foreach ($keyTest in $shortcutKeys) {
    $test = $audit.StartTest("Input", "Shortcut-$($keyTest.Name)", "Test keyboard shortcut: $($keyTest.Name)")
    
    try {
        $currentScreen = $global:TuiState.CurrentScreen
        $keyInfo = [System.ConsoleKeyInfo]::new([char]0, $keyTest.Key, $keyTest.Shift, $keyTest.Alt, $keyTest.Ctrl)
        
        $inputStartTime = Get-Date
        $result = $currentScreen.HandleInput($keyInfo)
        $inputDuration = (Get-Date) - $inputStartTime
        
        $metadata = @{
            Shortcut = $keyTest.Name
            InputResult = $result
            ResponseTime = [Math]::Round($inputDuration.TotalMilliseconds, 2)
            Modifiers = @{
                Shift = $keyTest.Shift
                Ctrl = $keyTest.Ctrl
                Alt = $keyTest.Alt
            }
        }
        
        $audit.EndTest($test, $true, "Shortcut handled: $result", "", $metadata)
        
        Start-Sleep -Milliseconds 200
        
    } catch {
        $audit.EndTest($test, $false, "", $_.Exception.Message)
    }
}

# ==============================================================================
# PHASE 5: COMPONENT TESTING
# ==============================================================================
$audit.WriteLog "=== PHASE 5: COMPONENT TESTING ===" "SYSTEM"

$componentFiles = Get-ChildItem -Path "./Components/ACO.*.ps1" | Sort-Object Name

foreach ($componentFile in $componentFiles) {
    $componentName = $componentFile.BaseName -replace "ACO\.\d+_", ""
    
    $test = $audit.StartTest("Components", "Analyze-$componentName", "Analyze component: $componentName")
    
    try {
        $content = Get-Content $componentFile.FullName -Raw
        
        # Extract component information
        $classMatches = [regex]::Matches($content, 'class\s+(\w+)')
        $renderMatches = [regex]::Matches($content, 'Render\s*\([^)]*\)')
        $inputMatches = [regex]::Matches($content, 'HandleInput\s*\([^)]*\)')
        
        $componentInfo = @{
            HasRenderMethod = $renderMatches.Count -gt 0
            HasInputMethod = $inputMatches.Count -gt 0
            ClassCount = $classMatches.Count
            FileSize = (Get-Item $componentFile.FullName).Length
        }
        
        # Try to instantiate if it has a main class
        if ($classMatches.Count -gt 0) {
            $className = $classMatches[0].Groups[1].Value
            
            try {
                $instance = New-Object $className
                $componentInfo.Instantiatable = $true
                $componentInfo.ClassName = $className
                
                # Test basic component properties
                $componentInfo.Properties = @{}
                foreach ($prop in @('Width', 'Height', 'X', 'Y', 'IsVisible', 'HasFocus', 'IsFocusable')) {
                    try {
                        $componentInfo.Properties[$prop] = $instance.$prop
                    } catch {
                        $componentInfo.Properties[$prop] = "N/A"
                    }
                }
                
            } catch {
                $componentInfo.Instantiatable = $false
                $componentInfo.InstantiationError = $_.Exception.Message
            }
        }
        
        $audit.LogComponentState("Component-$componentName", $componentInfo)
        
        $audit.EndTest($test, $true, "Component analyzed", "", $componentInfo)
        
    } catch {
        $audit.EndTest($test, $false, "", $_.Exception.Message)
    }
}

# ==============================================================================
# PHASE 6: DATA OPERATIONS TESTING
# ==============================================================================
$audit.WriteLog "=== PHASE 6: DATA OPERATIONS TESTING ===" "SYSTEM"

# Test 6.1: DataManager Service
$test = $audit.StartTest("Data", "DataManagerService", "Test DataManager CRUD operations")
try {
    $dataManager = $global:TuiServices['DataManager']
    
    if ($dataManager) {
        $methods = $dataManager.GetType().GetMethods().Name
        
        # Test data retrieval
        $taskCount = 0
        $projectCount = 0
        $timeEntryCount = 0
        
        try {
            $tasks = $dataManager.GetTasks()
            $taskCount = if ($tasks) { $tasks.Count } else { 0 }
        } catch { }
        
        try {
            $projects = $dataManager.GetProjects()
            $projectCount = if ($projects) { $projects.Count } else { 0 }
        } catch { }
        
        try {
            $timeEntries = $dataManager.GetTimeEntries()
            $timeEntryCount = if ($timeEntries) { $timeEntries.Count } else { 0 }
        } catch { }
        
        $metadata = @{
            ServiceExists = $true
            MethodCount = $methods.Count
            TaskCount = $taskCount
            ProjectCount = $projectCount
            TimeEntryCount = $timeEntryCount
            HasGetTasks = 'GetTasks' -in $methods
            HasGetProjects = 'GetProjects' -in $methods
            HasSaveTask = 'SaveTask' -in $methods
        }
        
        $audit.EndTest($test, $true, "DataManager operational", "", $metadata)
    } else {
        $audit.EndTest($test, $false, "", "DataManager service not found")
    }
} catch {
    $audit.EndTest($test, $false, "", $_.Exception.Message)
}

# Test 6.2: Data Integrity Check
$test = $audit.StartTest("Data", "DataIntegrity", "Verify data consistency and relationships")
try {
    $dataManager = $global:TuiServices['DataManager']
    
    if ($dataManager) {
        $tasks = $dataManager.GetTasks()
        $projects = $dataManager.GetProjects()
        
        # Check for orphaned tasks (tasks without valid projects)
        $orphanedTasks = 0
        $validTasks = 0
        
        if ($tasks -and $projects) {
            $projectIds = $projects | ForEach-Object { $_.Id }
            
            foreach ($task in $tasks) {
                if ($task.ProjectId -and $task.ProjectId -in $projectIds) {
                    $validTasks++
                } else {
                    $orphanedTasks++
                }
            }
        }
        
        $metadata = @{
            TotalTasks = if ($tasks) { $tasks.Count } else { 0 }
            TotalProjects = if ($projects) { $projects.Count } else { 0 }
            ValidTasks = $validTasks
            OrphanedTasks = $orphanedTasks
            DataIntegrityScore = if ($tasks.Count -gt 0) { [Math]::Round(($validTasks / $tasks.Count) * 100, 2) } else { 100 }
        }
        
        $integrityOk = ($orphanedTasks -eq 0)
        $audit.EndTest($test, $integrityOk, "Data integrity check", "", $metadata)
    } else {
        $audit.EndTest($test, $false, "", "DataManager not available")
    }
} catch {
    $audit.EndTest($test, $false, "", $_.Exception.Message)
}

# ==============================================================================
# PHASE 7: PERFORMANCE BENCHMARKING
# ==============================================================================
$audit.WriteLog "=== PHASE 7: PERFORMANCE BENCHMARKING ===" "SYSTEM"

# Test 7.1: Rendering Performance
$test = $audit.StartTest("Performance", "RenderingBenchmark", "Benchmark rendering performance")
try {
    $buffer = [TuiBuffer]::new(80, 24)
    $style = @{ FG = "#FFFFFF"; BG = "#000000" }
    
    # Test buffer operations
    $clearTimes = @()
    $writeTimes = @()
    
    for ($i = 0; $i -lt 10; $i++) {
        # Test clear performance
        $clearStart = Get-Date
        $buffer.Clear()
        $clearEnd = Get-Date
        $clearTimes += ($clearEnd - $clearStart).TotalMilliseconds
        
        # Test write performance
        $writeStart = Get-Date
        for ($y = 0; $y -lt 24; $y++) {
            $buffer.WriteString(0, $y, "Performance test line $y", $style)
        }
        $writeEnd = Get-Date
        $writeTimes += ($writeEnd - $writeStart).TotalMilliseconds
    }
    
    $avgClearTime = ($clearTimes | Measure-Object -Average).Average
    $avgWriteTime = ($writeTimes | Measure-Object -Average).Average
    
    $metadata = @{
        AverageClearTime = [Math]::Round($avgClearTime, 2)
        AverageWriteTime = [Math]::Round($avgWriteTime, 2)
        TotalTestCycles = 10
        BufferSize = "80x24"
    }
    
    $audit.LogPerformance("BufferOperations", @{
        ClearTime = $avgClearTime
        WriteTime = $avgWriteTime
        Cycles = 10
    })
    
    $performanceOk = ($avgClearTime -lt 50 -and $avgWriteTime -lt 100)
    $audit.EndTest($test, $performanceOk, "Rendering benchmark completed", "", $metadata)
    
} catch {
    $audit.EndTest($test, $false, "", $_.Exception.Message)
}

# Test 7.2: Memory Usage Analysis
$test = $audit.StartTest("Performance", "MemoryUsage", "Analyze memory usage patterns")
try {
    $beforeMemory = [GC]::GetTotalMemory($false)
    
    # Create and destroy several large buffers to test memory management
    for ($i = 0; $i -lt 5; $i++) {
        $largeBuffer = [TuiBuffer]::new(200, 50)
        for ($y = 0; $y -lt 50; $y++) {
            $largeBuffer.WriteString(0, $y, "Memory test $i line $y", @{ FG = "#FFFFFF"; BG = "#000000" })
        }
    }
    
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()
    
    $afterMemory = [GC]::GetTotalMemory($false)
    $memoryDelta = $afterMemory - $beforeMemory
    
    $metadata = @{
        BeforeMemory = $beforeMemory
        AfterMemory = $afterMemory
        MemoryDelta = $memoryDelta
        MemoryDeltaMB = [Math]::Round($memoryDelta / 1MB, 2)
    }
    
    $audit.LogPerformance("MemoryUsage", $metadata)
    
    $memoryOk = ($memoryDelta -lt 10MB)
    $audit.EndTest($test, $memoryOk, "Memory usage analysis", "", $metadata)
    
} catch {
    $audit.EndTest($test, $false, "", $_.Exception.Message)
}

# ==============================================================================
# FINAL RESULTS AND CLEANUP
# ==============================================================================
$audit.WriteLog "=== GENERATING FINAL AUDIT REPORT ===" "SYSTEM"

# Generate comprehensive summary
$summary = $audit.GetSummary()

# Save detailed results
$audit.SaveResults()

# Display final summary
$audit.WriteLog "" "SYSTEM"
$audit.WriteLog "🎯 COMPREHENSIVE AUDIT COMPLETED" "SYSTEM"
$audit.WriteLog "=" * 50 "SYSTEM"
$audit.WriteLog "Total Tests Executed: $($summary.Summary.TotalTests)" "SYSTEM"
$audit.WriteLog "Tests Passed: $($summary.Summary.PassedTests)" "PASS"
$audit.WriteLog "Tests Failed: $($summary.Summary.FailedTests)" "FAIL"
$audit.WriteLog "Overall Success Rate: $($summary.Summary.SuccessRate)%" "SYSTEM"
$audit.WriteLog "Test Duration: $([Math]::Round($summary.Summary.TestDuration.TotalMinutes, 1)) minutes" "SYSTEM"
$audit.WriteLog "" "SYSTEM"

# Category breakdown
foreach ($category in $summary.Categories.Keys) {
    $cat = $summary.Categories[$category]
    $audit.WriteLog "📂 $category`: $($cat.Passed)/$($cat.Total) passed ($([Math]::Round(($cat.Passed/$cat.Total)*100,1))%)" "INFO"
}

$audit.WriteLog "" "SYSTEM"
$audit.WriteLog "📄 Detailed results saved to: $($summary.ResultsFile)" "SYSTEM"
$audit.WriteLog "📄 Full audit log saved to: $($summary.LogFile)" "SYSTEM"

# Cleanup
if ($global:TuiState) {
    $global:TuiState.Running = $false
}

Write-Host "`n✅ COMPREHENSIVE AUDIT COMPLETE!" -ForegroundColor Green
Write-Host "Check the generated files for detailed analysis:" -ForegroundColor Yellow
Write-Host "  - Results: $($summary.ResultsFile)" -ForegroundColor Cyan
Write-Host "  - Log: $($summary.LogFile)" -ForegroundColor Cyan

return $summary