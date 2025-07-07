# Step-by-step test of mono loading
$ErrorActionPreference = 'Stop'
Set-Location "C:\Users\jhnhe\Documents\GitHub\_XP\_mono"

Write-Host "=== Testing Mono Framework Loading ===" -ForegroundColor Cyan

# Test 1: Load AllBaseClasses.ps1
try {
    Write-Host "`n1. Loading AllBaseClasses.ps1..." -ForegroundColor Yellow
    . .\AllBaseClasses.ps1
    Write-Host "   ✓ Success" -ForegroundColor Green
    
    # Test creating basic objects
    $cell = [TuiCell]::new('A', "#FFFFFF", "#000000")
    Write-Host "   ✓ Created TuiCell: $($cell.Char)" -ForegroundColor Green
    
    $buffer = [TuiBuffer]::new(10, 10, "Test")
    Write-Host "   ✓ Created TuiBuffer: $($buffer.Name)" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed: $_" -ForegroundColor Red
    exit
}

# Test 2: Load AllModels.ps1
try {
    Write-Host "`n2. Loading AllModels.ps1..." -ForegroundColor Yellow
    . .\AllModels.ps1
    Write-Host "   ✓ Success" -ForegroundColor Green
    
    # Test creating model objects
    $task = [PmcTask]::new("Test Task")
    Write-Host "   ✓ Created PmcTask: $($task.Title)" -ForegroundColor Green
    
    # Test ToLegacyFormat
    $legacy = $task.ToLegacyFormat()
    Write-Host "   ✓ ToLegacyFormat works" -ForegroundColor Green
    
    # Test FromLegacyFormat
    $restored = [PmcTask]::FromLegacyFormat($legacy)
    Write-Host "   ✓ FromLegacyFormat works: $($restored.Title)" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed: $_" -ForegroundColor Red
    exit
}

# Test 3: Load AllComponents.ps1
try {
    Write-Host "`n3. Loading AllComponents.ps1..." -ForegroundColor Yellow
    . .\AllComponents.ps1
    Write-Host "   ✓ Success" -ForegroundColor Green
    
    $button = [ButtonComponent]::new("TestButton")
    $button.Text = "Click Me"
    Write-Host "   ✓ Created ButtonComponent: $($button.Text)" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed: $_" -ForegroundColor Red
    exit
}

# Test 4: Load AllScreens.ps1
try {
    Write-Host "`n4. Loading AllScreens.ps1..." -ForegroundColor Yellow
    . .\AllScreens.ps1
    Write-Host "   ✓ Success" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed: $_" -ForegroundColor Red
    exit
}

# Test 5: Load AllFunctions.ps1
try {
    Write-Host "`n5. Loading AllFunctions.ps1..." -ForegroundColor Yellow
    . .\AllFunctions.ps1
    Write-Host "   ✓ Success" -ForegroundColor Green
    
    # Test Get-ThemeColor
    $color = Get-ThemeColor "Background"
    Write-Host "   ✓ Get-ThemeColor works: $color" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed: $_" -ForegroundColor Red
    exit
}

# Test 6: Load AllServices.ps1
try {
    Write-Host "`n6. Loading AllServices.ps1..." -ForegroundColor Yellow
    . .\AllServices.ps1
    Write-Host "   ✓ Success" -ForegroundColor Green
    
    # Test creating services
    $em = [EventManager]::new()
    Write-Host "   ✓ Created EventManager" -ForegroundColor Green
    
    $dm = [DataManager]::new("test.json", $em)
    Write-Host "   ✓ Created DataManager" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed: $_" -ForegroundColor Red
    Write-Host "   Stack trace:" -ForegroundColor DarkGray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit
}

# Test 7: Load AllRuntime.ps1
try {
    Write-Host "`n7. Loading AllRuntime.ps1..." -ForegroundColor Yellow
    . .\AllRuntime.ps1
    Write-Host "   ✓ Success" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed: $_" -ForegroundColor Red
    exit
}

Write-Host "`n=== All Framework Files Loaded Successfully! ===" -ForegroundColor Green
