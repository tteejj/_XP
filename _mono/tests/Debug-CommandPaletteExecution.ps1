# Comprehensive test to debug CommandPalette execution
$ErrorActionPreference = 'Stop'

Write-Host "=== COMMANDPALETTE EXECUTION DEBUGGER ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if all files load without syntax errors
Write-Host "Step 1: Loading framework files..." -ForegroundColor Yellow

$files = @(
    "Base\ABC.001_TuiAnsiHelper.ps1",
    "Base\ABC.002_TuiCell.ps1", 
    "Base\ABC.003_TuiBuffer.ps1",
    "Base\ABC.004_UIElement.ps1",
    "Base\ABC.005_Component.ps1",
    "Base\ABC.006_Screen.ps1",
    "Base\ABC.007_ServiceContainer.ps1",
    "Runtime\ART.001_GlobalState.ps1"
)

$hasErrors = $false
foreach ($file in $files) {
    try {
        . "$PSScriptRoot\$file"
        Write-Host "  ✓ $file" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ $file - ERROR: $_" -ForegroundColor Red
        $hasErrors = $true
    }
}

# Step 2: Test engine management specifically
Write-Host "`nStep 2: Testing engine management file..." -ForegroundColor Yellow
try {
    . "$PSScriptRoot\Runtime\ART.002_EngineManagement.ps1"
    Write-Host "  ✓ Engine management loaded" -ForegroundColor Green
    
    # Check if Start-TuiEngine function exists
    if (Get-Command Start-TuiEngine -ErrorAction SilentlyContinue) {
        Write-Host "  ✓ Start-TuiEngine function exists" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Start-TuiEngine function NOT FOUND" -ForegroundColor Red
        $hasErrors = $true
    }
} catch {
    Write-Host "  ✗ Engine management ERROR: $_" -ForegroundColor Red
    Write-Host "    Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host "    Statement: $($_.InvocationInfo.Line)" -ForegroundColor Yellow
    $hasErrors = $true
}

if ($hasErrors) {
    Write-Host "`nErrors found. Cannot continue." -ForegroundColor Red
    exit 1
}

# Step 3: Create minimal test environment
Write-Host "`nStep 3: Creating minimal test environment..." -ForegroundColor Yellow

# Initialize global state
$global:TuiState = @{
    Services = @{}
    ServiceContainer = $null
}

# Create EventManager
$eventManager = [EventManager]::new()
$global:TuiState.Services.EventManager = $eventManager

# Test event system
Write-Host "`nStep 4: Testing event system..." -ForegroundColor Yellow
$testWorked = $false
$handler = $eventManager.Subscribe("TestEvent", {
    param($sender, $data)
    $script:testWorked = $true
})
$eventManager.Publish("TestEvent", @{})
if ($testWorked) {
    Write-Host "  ✓ Event system works" -ForegroundColor Green
} else {
    Write-Host "  ✗ Event system NOT working" -ForegroundColor Red
}

# Step 5: Test deferred action setup
Write-Host "`nStep 5: Testing deferred action setup..." -ForegroundColor Yellow

# Manually set up deferred actions queue
$global:TuiState.DeferredActions = New-Object 'System.Collections.Concurrent.ConcurrentQueue[hashtable]'
Write-Host "  ✓ DeferredActions queue created" -ForegroundColor Green

# Set up handler
$deferredHandler = $eventManager.Subscribe("DeferredAction", {
    param($sender, $data)
    if ($data -and $data.ActionName) {
        Write-Host "  → DeferredAction received: $($data.ActionName)" -ForegroundColor Cyan
        $global:TuiState.DeferredActions.Enqueue($data)
    }
})
Write-Host "  ✓ DeferredAction handler registered" -ForegroundColor Green

# Test publishing
$eventManager.Publish("DeferredAction", @{ActionName = "test.action"})
Start-Sleep -Milliseconds 100

$count = $global:TuiState.DeferredActions.Count
if ($count -gt 0) {
    Write-Host "  ✓ DeferredAction successfully enqueued (count: $count)" -ForegroundColor Green
} else {
    Write-Host "  ✗ DeferredAction NOT enqueued!" -ForegroundColor Red
}

# Step 6: Full application test
Write-Host "`nStep 6: Ready to test full application" -ForegroundColor Yellow
Write-Host "Press any key to start the application..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host "`nInstructions:" -ForegroundColor Yellow
Write-Host "1. Press '4' to open Command Palette"
Write-Host "2. Select 'test.simple' action" 
Write-Host "3. Press Enter"
Write-Host "4. Should see a dialog confirming execution"
Write-Host ""

$env:AXIOM_LOG_LEVEL = "Debug"
& "$PSScriptRoot\Start.ps1"
