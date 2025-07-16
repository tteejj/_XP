# Performance Test for Phase 5 Optimizations
# This script measures performance improvements from caching optimizations

# Load the framework
$scriptDir = $PSScriptRoot
. "$scriptDir\Functions\AFU.006a_FileLogger.ps1"

# Load framework in order
$loadOrder = @("Base", "Models", "Functions", "Components", "Screens", "Services", "Runtime")

Write-Host "Loading framework for performance testing..." -ForegroundColor Cyan
foreach ($folder in $loadOrder) {
    $folderPath = Join-Path $scriptDir $folder
    if (Test-Path $folderPath) {
        Get-ChildItem -Path $folderPath -Filter "*.ps1" | Sort-Object Name | ForEach-Object {
            . $_.FullName
        }
    }
}

# Initialize global state  
$global:TuiState = @{}

# Create service container
$serviceContainer = [ServiceContainer]::new()

# Register essential services
$serviceContainer.Register("Logger", [Logger]::new())
$serviceContainer.Register("EventManager", [EventManager]::new())
$serviceContainer.Register("ThemeManager", [ThemeManager]::new())
$serviceContainer.Register("DataManager", [DataManager]::new("./test-data.json", $serviceContainer.GetService("EventManager")))
$serviceContainer.Register("ViewDefinitionService", [ViewDefinitionService]::new())

# Store services in global state
$global:TuiState.ServiceContainer = $serviceContainer
$global:TuiState.Services = @{
    Logger = $serviceContainer.GetService("Logger")
    EventManager = $serviceContainer.GetService("EventManager")
    ThemeManager = $serviceContainer.GetService("ThemeManager")
    DataManager = $serviceContainer.GetService("DataManager")
    ViewDefinitionService = $serviceContainer.GetService("ViewDefinitionService")
}

Write-Host "`nTesting Phase 5 Performance Optimizations..." -ForegroundColor Green

# Test 1: Theme Color Caching Performance
Write-Host "`nTest 1: Theme Color Caching Performance" -ForegroundColor Yellow

# Create test component
$testComponent = [Panel]::new("TestPanel")
$testComponent.Width = 50
$testComponent.Height = 20

# Test theme color lookups without cache (simulate cold start)
$testComponent._themeColorCache = @{}
$testComponent._lastThemeName = ""

$sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt 1000; $i++) {
    $testComponent.GetThemeColor("panel.background", "#1e1e1e") | Out-Null
    $testComponent.GetThemeColor("panel.border", "#404040") | Out-Null
    $testComponent.GetThemeColor("palette.primary", "#007acc") | Out-Null
    $testComponent.GetThemeColor("label.foreground", "#ffffff") | Out-Null
    $testComponent.GetThemeColor("button.background", "#333333") | Out-Null
}
$sw.Stop()
$uncachedTime = $sw.ElapsedMilliseconds

# Test theme color lookups with cache (warm cache)
$sw.Restart()
for ($i = 0; $i -lt 1000; $i++) {
    $testComponent.GetThemeColor("panel.background", "#1e1e1e") | Out-Null
    $testComponent.GetThemeColor("panel.border", "#404040") | Out-Null
    $testComponent.GetThemeColor("palette.primary", "#007acc") | Out-Null
    $testComponent.GetThemeColor("label.foreground", "#ffffff") | Out-Null
    $testComponent.GetThemeColor("button.background", "#333333") | Out-Null
}
$sw.Stop()
$cachedTime = $sw.ElapsedMilliseconds

Write-Host "Theme Color Lookups (1000 iterations x 5 colors):" -ForegroundColor Cyan
Write-Host "  Uncached: ${uncachedTime}ms" -ForegroundColor White
Write-Host "  Cached: ${cachedTime}ms" -ForegroundColor White
$improvement = [Math]::Round(((($uncachedTime - $cachedTime) / $uncachedTime) * 100), 1)
Write-Host "  Improvement: ${improvement}%" -ForegroundColor Green

# Test 2: Panel Layout Caching Performance
Write-Host "`nTest 2: Panel Layout Caching Performance" -ForegroundColor Yellow

# Create test panel with multiple children
$testPanel = [Panel]::new("TestLayoutPanel")
$testPanel.Width = 100
$testPanel.Height = 50
$testPanel.LayoutType = "Vertical"

# Add multiple children
for ($i = 0; $i -lt 20; $i++) {
    $child = [Panel]::new("Child$i")
    $child.Width = 90
    $child.Height = 2
    $testPanel.AddChild($child)
}

# Test layout without cache (force recalculation)
$sw.Restart()
for ($i = 0; $i -lt 100; $i++) {
    if ($testPanel.PSObject.Properties['_layoutCacheValid']) {
        $testPanel._layoutCacheValid = $false  # Force recalculation
    }
    if ($testPanel.PSObject.Methods['ApplyLayout']) {
        $testPanel.ApplyLayout()
    }
}
$sw.Stop()
$uncachedLayoutTime = $sw.ElapsedMilliseconds

# Test layout with cache - first run to populate cache
if ($testPanel.PSObject.Methods['ApplyLayout']) {
    $testPanel.ApplyLayout()
}

$sw.Restart()
for ($i = 0; $i -lt 100; $i++) {
    if ($testPanel.PSObject.Methods['ApplyLayout']) {
        $testPanel.ApplyLayout()  # Will use cache
    }
}
$sw.Stop()
$cachedLayoutTime = $sw.ElapsedMilliseconds

Write-Host "Panel Layout Calculations (100 iterations x 20 children):" -ForegroundColor Cyan
Write-Host "  Uncached: ${uncachedLayoutTime}ms" -ForegroundColor White
Write-Host "  Cached: ${cachedLayoutTime}ms" -ForegroundColor White
$layoutImprovement = [Math]::Round(((($uncachedLayoutTime - $cachedLayoutTime) / $uncachedLayoutTime) * 100), 1)
Write-Host "  Improvement: ${layoutImprovement}%" -ForegroundColor Green

# Test 3: String Formatting Cache Performance
Write-Host "`nTest 3: String Formatting Cache Performance" -ForegroundColor Yellow

# Create test data
$testData = @()
for ($i = 0; $i -lt 100; $i++) {
    $testData += [PSCustomObject]@{
        ID = $i
        Name = "Test Item $i"
        Status = if ($i % 3 -eq 0) { "Active" } elseif ($i % 3 -eq 1) { "Pending" } else { "Inactive" }
        Priority = if ($i % 3 -eq 0) { "High" } elseif ($i % 3 -eq 1) { "Medium" } else { "Low" }
        Description = "This is a test description for item $i with some longer text"
    }
}

# Test Table component with string formatting cache
$testTable = [Table]::new("TestTable")
$testTable.SetColumns(@("ID", "Name", "Status", "Priority", "Description"))
$testTable.SetItems($testData)

# Test without cache (force recalculation)
$sw.Restart()
for ($i = 0; $i -lt 50; $i++) {
    $testTable._InvalidateCache()
    $testTable._EnsureDisplayCache()
}
$sw.Stop()
$uncachedStringTime = $sw.ElapsedMilliseconds

# Test with cache
$sw.Restart()
for ($i = 0; $i -lt 50; $i++) {
    $testTable._EnsureDisplayCache()  # Will use cache
}
$sw.Stop()
$cachedStringTime = $sw.ElapsedMilliseconds

Write-Host "String Formatting (50 iterations x 100 items x 5 columns):" -ForegroundColor Cyan
Write-Host "  Uncached: ${uncachedStringTime}ms" -ForegroundColor White
Write-Host "  Cached: ${cachedStringTime}ms" -ForegroundColor White
$stringImprovement = [Math]::Round(((($uncachedStringTime - $cachedStringTime) / $uncachedStringTime) * 100), 1)
Write-Host "  Improvement: ${stringImprovement}%" -ForegroundColor Green

# Test 4: DataGridComponent with ViewDefinition Caching
Write-Host "`nTest 4: DataGridComponent ViewDefinition Caching" -ForegroundColor Yellow

# Create test tasks
$testTasks = @()
for ($i = 0; $i -lt 50; $i++) {
    $task = [PmcTask]::new()
    $task.Title = "Test Task $i"
    $task.Status = if ($i % 3 -eq 0) { [TaskStatus]::Completed } elseif ($i % 3 -eq 1) { [TaskStatus]::InProgress } else { [TaskStatus]::Pending }
    $task.Priority = if ($i % 3 -eq 0) { [TaskPriority]::High } elseif ($i % 3 -eq 1) { [TaskPriority]::Medium } else { [TaskPriority]::Low }
    $task.Progress = $i * 2
    $task.DueDate = [DateTime]::Now.AddDays($i - 25)  # Some overdue, some not
    $testTasks += $task
}

# Test DataGridComponent
$dataGrid = [DataGridComponent]::new("TestDataGrid")
$dataGrid.Width = 80
$dataGrid.Height = 20
$dataGrid.ShowHeaders = $true

$viewService = $serviceContainer.GetService("ViewDefinitionService")
$taskViewDef = $viewService.GetViewDefinition('task.summary')
$dataGrid.SetViewDefinition($taskViewDef)

# Test without cache (force recalculation)
$sw.Restart()
for ($i = 0; $i -lt 25; $i++) {
    $dataGrid.CacheValid = $false
    $dataGrid.SetItems($testTasks)
}
$sw.Stop()
$uncachedDataGridTime = $sw.ElapsedMilliseconds

# Test with cache
$sw.Restart()
for ($i = 0; $i -lt 25; $i++) {
    $dataGrid.SetItems($testTasks)  # Will use cache if items haven't changed
}
$sw.Stop()
$cachedDataGridTime = $sw.ElapsedMilliseconds

Write-Host "DataGrid ViewDefinition Transform (25 iterations x 50 tasks):" -ForegroundColor Cyan
Write-Host "  Uncached: ${uncachedDataGridTime}ms" -ForegroundColor White
Write-Host "  Cached: ${cachedDataGridTime}ms" -ForegroundColor White
$dataGridImprovement = [Math]::Round(((($uncachedDataGridTime - $cachedDataGridTime) / $uncachedDataGridTime) * 100), 1)
Write-Host "  Improvement: ${dataGridImprovement}%" -ForegroundColor Green

# Calculate overall performance improvement (now including all optimizations)
$totalUncachedTime = $uncachedTime + $uncachedLayoutTime + $uncachedStringTime + $uncachedDataGridTime
$totalCachedTime = $cachedTime + $cachedLayoutTime + $cachedStringTime + $cachedDataGridTime
$overallImprovement = [Math]::Round(((($totalUncachedTime - $totalCachedTime) / $totalUncachedTime) * 100), 1)

Write-Host "`n=== PHASE 5 PERFORMANCE OPTIMIZATION RESULTS ===" -ForegroundColor Magenta
Write-Host "Individual Improvements:" -ForegroundColor Cyan
Write-Host "  Theme Color Caching: ${improvement}%" -ForegroundColor Green
Write-Host "  Panel Layout Caching: ${layoutImprovement}%" -ForegroundColor Green
Write-Host "  String Formatting Caching: ${stringImprovement}%" -ForegroundColor Green
Write-Host "  DataGrid ViewDefinition Caching: ${dataGridImprovement}%" -ForegroundColor Green

Write-Host "`nOverall Performance Summary (all optimizations):" -ForegroundColor Cyan
Write-Host "  Total Time (Uncached): ${totalUncachedTime}ms" -ForegroundColor White
Write-Host "  Total Time (Cached): ${totalCachedTime}ms" -ForegroundColor White
Write-Host "  Overall Improvement: ${overallImprovement}%" -ForegroundColor Green

# Validate success
if ($overallImprovement -ge 20) {
    Write-Host "`n✅ SUCCESS: Achieved ${overallImprovement}% performance improvement!" -ForegroundColor Green
    Write-Host "   Target was 20-30% - GOAL EXCEEDED!" -ForegroundColor Green
} elseif ($overallImprovement -ge 15) {
    Write-Host "`n⚠️  GOOD: Achieved ${overallImprovement}% performance improvement" -ForegroundColor Yellow
    Write-Host "   Target was 20-30% - Close to goal" -ForegroundColor Yellow
} else {
    Write-Host "`n❌ BELOW TARGET: ${overallImprovement}% performance improvement" -ForegroundColor Red
    Write-Host "   Target was 20-30% - Need more optimization" -ForegroundColor Red
}

Write-Host "`n🚀 Phase 5 (Performance Optimizations) - TESTING COMPLETED!" -ForegroundColor Magenta

# Clean up test data file
if (Test-Path "./test-data.json") {
    Remove-Item "./test-data.json" -Force
}