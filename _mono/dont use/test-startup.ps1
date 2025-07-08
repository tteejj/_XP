# Quick test to check if the framework can load without errors
try {
    Write-Host "Testing framework startup..." -ForegroundColor Cyan
    
    $scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    
    # Test loading each file in order
    $filesToLoad = @(
        'AllBaseClasses.ps1'
        'AllModels.ps1'
        'AllComponents.ps1'
        'AllScreens.ps1'
        'AllFunctions.ps1'
        'AllServices.ps1'
        'AllRuntime.ps1'
    )
    
    foreach ($file in $filesToLoad) {
        $filePath = Join-Path $scriptRoot $file
        Write-Host "Loading: $file" -ForegroundColor Yellow
        . $filePath
        Write-Host "✓ Success: $file" -ForegroundColor Green
    }
    
    Write-Host "`nTesting service instantiation..." -ForegroundColor Cyan
    
    # Test creating basic services
    $container = [ServiceContainer]::new()
    Write-Host "✓ ServiceContainer created" -ForegroundColor Green
    
    $eventManager = [EventManager]::new()
    Write-Host "✓ EventManager created" -ForegroundColor Green
    
    $dataManager = [DataManager]::new("test.json", $eventManager)
    Write-Host "✓ DataManager created" -ForegroundColor Green
    
    $focusManager = [FocusManager]::new($eventManager)
    Write-Host "✓ FocusManager created" -ForegroundColor Green
    
    Write-Host "`nFramework test completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "`nFramework test FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Location: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    throw
}
