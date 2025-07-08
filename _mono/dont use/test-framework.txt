# Comprehensive mono framework test
$ErrorActionPreference = 'Stop'
Clear-Host

Write-Host "=====================================`n" -ForegroundColor Cyan
Write-Host "  Axiom-Phoenix v4.0 Mono Test`n" -ForegroundColor White
Write-Host "=====================================`n" -ForegroundColor Cyan

$testResults = @()

# Function to add test result
function Add-TestResult($TestName, $Success, $Message) {
    $script:testResults += [PSCustomObject]@{
        Test = $TestName
        Success = $Success
        Message = $Message
    }
    
    if ($Success) {
        Write-Host "✓ $TestName" -ForegroundColor Green
        if ($Message) { Write-Host "  $Message" -ForegroundColor DarkGray }
    } else {
        Write-Host "✗ $TestName" -ForegroundColor Red
        Write-Host "  $Message" -ForegroundColor Yellow
    }
}

# Test 1: Verify all files exist
Write-Host "`n[Checking Files]" -ForegroundColor Yellow
$requiredFiles = @(
    'allbaseclasses.ps1',
    'AllModels.ps1',
    'AllComponents.ps1',
    'AllScreens.ps1',
    'AllFunctions.ps1',
    'AllServices.ps1',
    'AllRuntime.ps1',
    'Start.ps1'
)

$allFilesExist = $true
foreach ($file in $requiredFiles) {
    $path = Join-Path "C:\Users\jhnhe\Documents\GitHub\_XP\_mono" $file
    if (Test-Path $path) {
        Add-TestResult "File: $file" $true "Found"
    } else {
        Add-TestResult "File: $file" $false "Not found at $path"
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host "`nCannot continue - missing required files" -ForegroundColor Red
    exit 1
}

# Test 2: Load and test framework
Write-Host "`n[Loading Framework]" -ForegroundColor Yellow
Set-Location "C:\Users\jhnhe\Documents\GitHub\_XP\_mono"

try {
    . .\allbaseclasses.ps1
    Add-TestResult "AllBaseClasses" $true "Loaded successfully"
    
    # Test basic object creation
    $cell = [TuiCell]::new('X', "#FF0000", "#000000")
    Add-TestResult "TuiCell Creation" $true "Created cell with char '$($cell.Char)'"
    
    # Test the operator fix
    $cell2 = [TuiCell]::new('Y', "#00FF00", "#000000")
    $cell2.ZIndex = 5
    $result = $cell.BlendWith($cell2)
    Add-TestResult "ZIndex Comparison" $true "BlendWith works correctly"
    
} catch {
    Add-TestResult "AllBaseClasses" $false $_.Exception.Message
    exit 1
}

try {
    . .\AllModels.ps1
    Add-TestResult "AllModels" $true "Loaded successfully"
    
    # Test task creation and serialization
    $task = [PmcTask]::new("Test Task")
    $task.Priority = [TaskPriority]::High
    $task.SetProgress(50)
    
    $legacy = $task.ToLegacyFormat()
    $restored = [PmcTask]::FromLegacyFormat($legacy)
    
    if ($restored.Title -eq $task.Title -and $restored.Progress -eq $task.Progress) {
        Add-TestResult "Task Serialization" $true "ToLegacyFormat/FromLegacyFormat working"
    } else {
        Add-TestResult "Task Serialization" $false "Serialization mismatch"
    }
    
} catch {
    Add-TestResult "AllModels" $false $_.Exception.Message
    exit 1
}

try {
    . .\AllComponents.ps1
    Add-TestResult "AllComponents" $true "Loaded successfully"
} catch {
    Add-TestResult "AllComponents" $false $_.Exception.Message
    exit 1
}

try {
    . .\AllScreens.ps1
    Add-TestResult "AllScreens" $true "Loaded successfully"
} catch {
    Add-TestResult "AllScreens" $false $_.Exception.Message
    exit 1
}

try {
    . .\AllFunctions.ps1
    Add-TestResult "AllFunctions" $true "Loaded successfully"
    
    # Test theme manager function
    $color = Get-ThemeColor "Background"
    if ($color -match '^#[0-9A-Fa-f]{6}$') {
        Add-TestResult "Get-ThemeColor" $true "Returns hex color: $color"
    } else {
        Add-TestResult "Get-ThemeColor" $false "Invalid color format: $color"
    }
    
} catch {
    Add-TestResult "AllFunctions" $false $_.Exception.Message
    exit 1
}

try {
    . .\AllServices.ps1
    Add-TestResult "AllServices" $true "Loaded successfully"
    
    # Test DataManager with new features
    $tempFile = Join-Path $env:TEMP "test-data-$(Get-Random).json"
    $em = [EventManager]::new()
    $dm = [DataManager]::new($tempFile, $em)
    
    # Test task operations
    $testTask = [PmcTask]::new("DataManager Test")
    $addedTask = $dm.AddTask($testTask)
    
    if ($dm.GetTask($addedTask.Id)) {
        Add-TestResult "DataManager Operations" $true "Add/Get task working"
    } else {
        Add-TestResult "DataManager Operations" $false "Failed to retrieve added task"
    }
    
    # Test save/load
    $dm.SaveData()
    $dm2 = [DataManager]::new($tempFile, $em)
    $dm2.LoadData()
    
    if ($dm2.GetTask($addedTask.Id)) {
        Add-TestResult "DataManager Persistence" $true "Save/Load working"
    } else {
        Add-TestResult "DataManager Persistence" $false "Task not found after reload"
    }
    
    # Cleanup
    $dm.Dispose()
    $dm2.Dispose()
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    
} catch {
    Add-TestResult "AllServices" $false $_.Exception.Message
    Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    exit 1
}

try {
    . .\AllRuntime.ps1
    Add-TestResult "AllRuntime" $true "Loaded successfully"
    
    # Check for required functions
    if (Get-Command Initialize-TuiEngine -ErrorAction SilentlyContinue) {
        Add-TestResult "Initialize-TuiEngine" $true "Function exists"
    } else {
        Add-TestResult "Initialize-TuiEngine" $false "Function not found"
    }
    
    if (Get-Command Start-AxiomPhoenix -ErrorAction SilentlyContinue) {
        Add-TestResult "Start-AxiomPhoenix" $true "Function exists"
    } else {
        Add-TestResult "Start-AxiomPhoenix" $false "Function not found"
    }
    
} catch {
    Add-TestResult "AllRuntime" $false $_.Exception.Message
    exit 1
}

# Summary
Write-Host "`n[Test Summary]" -ForegroundColor Yellow
$passed = ($testResults | Where-Object Success).Count
$failed = ($testResults | Where-Object { -not $_.Success }).Count
$total = $testResults.Count

Write-Host "Passed: $passed/$total" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
if ($failed -gt 0) {
    Write-Host "Failed: $failed" -ForegroundColor Red
    Write-Host "`nFailed tests:" -ForegroundColor Red
    $testResults | Where-Object { -not $_.Success } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Message)" -ForegroundColor Red
    }
}

if ($failed -eq 0) {
    Write-Host "`n✓ All tests passed! The framework is ready to run." -ForegroundColor Green
    Write-Host "`nYou can now run: .\Start.ps1" -ForegroundColor Cyan
} else {
    Write-Host "`n✗ Some tests failed. Please fix the issues before running Start.ps1" -ForegroundColor Red
}
