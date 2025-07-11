# Trace CommandPalette Execution
# This script adds detailed logging to trace where the execution is failing

$ErrorActionPreference = 'Stop'
$env:AXIOM_LOG_LEVEL = "Debug"

# Load the framework
. "$PSScriptRoot\Start.ps1" -NoAutoStart

# Add detailed tracing to key points
Write-Host "`n=== TRACING COMMANDPALETTE EXECUTION ===" -ForegroundColor Cyan

# Check if services are loaded
Write-Host "`nChecking services..." -ForegroundColor Yellow
Write-Host "ActionService exists: $($null -ne $global:TuiState.Services.ActionService)"
Write-Host "EventManager exists: $($null -ne $global:TuiState.Services.EventManager)"
Write-Host "NavigationService exists: $($null -ne $global:TuiState.Services.NavigationService)"

# Check if DeferredActions queue exists
Write-Host "`nChecking DeferredActions queue..." -ForegroundColor Yellow
Write-Host "DeferredActions exists: $($null -ne $global:TuiState.DeferredActions)"
Write-Host "DeferredActions type: $($global:TuiState.DeferredActions.GetType().FullName)"

# Check if deferred action handler is registered
Write-Host "`nChecking event subscriptions..." -ForegroundColor Yellow
$eventManager = $global:TuiState.Services.EventManager
if ($eventManager) {
    Write-Host "EventManager has handlers for DeferredAction: $($eventManager.EventHandlers.ContainsKey('DeferredAction'))"
    if ($eventManager.EventHandlers.ContainsKey('DeferredAction')) {
        Write-Host "Number of DeferredAction handlers: $($eventManager.EventHandlers['DeferredAction'].Count)"
    }
}

# Test the flow manually
Write-Host "`n=== TESTING FLOW MANUALLY ===" -ForegroundColor Cyan

# 1. Test EventManager publishing
Write-Host "`n1. Testing EventManager publish..." -ForegroundColor Yellow
$testReceived = $false
$testHandler = $eventManager.Subscribe("TestEvent", {
    param($sender, $data)
    $script:testReceived = $true
    Write-Host "   - Test event received!" -ForegroundColor Green
})
$eventManager.Publish("TestEvent", @{Test = "Data"})
Write-Host "   Test event publish works: $testReceived"
$eventManager.Unsubscribe("TestEvent", $testHandler)

# 2. Test DeferredAction publishing
Write-Host "`n2. Testing DeferredAction publish..." -ForegroundColor Yellow
$deferredReceived = $false
$originalCount = $global:TuiState.DeferredActions.Count
$eventManager.Publish("DeferredAction", @{ActionName = "test.manual"})
Start-Sleep -Milliseconds 100
$newCount = $global:TuiState.DeferredActions.Count
Write-Host "   DeferredActions queue count before: $originalCount"
Write-Host "   DeferredActions queue count after: $newCount"
Write-Host "   DeferredAction enqueued: $($newCount -gt $originalCount)"

# 3. Test CommandPalette Complete flow
Write-Host "`n3. Testing CommandPalette Complete flow..." -ForegroundColor Yellow
$container = $global:TuiState.ServiceContainer
$palette = [CommandPalette]::new("TestPalette", $container)

# Set up OnClose to trace
$palette.OnClose = {
    param($result)
    Write-Host "   - OnClose called with result: $($result | ConvertTo-Json -Compress)" -ForegroundColor Green
    
    $evtMgr = $global:TuiState.Services.EventManager
    if ($evtMgr) {
        Write-Host "   - EventManager found, publishing DeferredAction" -ForegroundColor Green
        $evtMgr.Publish("DeferredAction", @{ActionName = "test.fromPalette"})
    } else {
        Write-Host "   - EventManager NOT FOUND!" -ForegroundColor Red
    }
}

# Call Complete directly
Write-Host "   Calling palette.Complete(@{Name='test.action'})..."
$beforeQueue = $global:TuiState.DeferredActions.Count
$palette.Complete(@{Name = "test.action"})
Start-Sleep -Milliseconds 100
$afterQueue = $global:TuiState.DeferredActions.Count

Write-Host "   Queue count before Complete: $beforeQueue"
Write-Host "   Queue count after Complete: $afterQueue"
Write-Host "   Action queued: $($afterQueue -gt $beforeQueue)"

# 4. Check what's in the deferred actions queue
Write-Host "`n4. Checking deferred actions queue contents..." -ForegroundColor Yellow
$tempQueue = @()
while ($global:TuiState.DeferredActions.Count -gt 0) {
    $action = $null
    if ($global:TuiState.DeferredActions.TryDequeue([ref]$action)) {
        Write-Host "   Found action: $($action | ConvertTo-Json -Compress)" -ForegroundColor Green
        $tempQueue += $action
    }
}
# Put them back
foreach ($action in $tempQueue) {
    $global:TuiState.DeferredActions.Enqueue($action)
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "EventManager works: $testReceived"
Write-Host "DeferredAction handler exists: $($eventManager.EventHandlers.ContainsKey('DeferredAction'))"
Write-Host "DeferredActions queue works: $($afterQueue -gt $beforeQueue)"
Write-Host "Total actions in queue: $($global:TuiState.DeferredActions.Count)"

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
