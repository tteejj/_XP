#!/usr/bin/env pwsh
# Test the ACTUAL running app with comprehensive debugging

Write-Host "=== REAL APP DEBUG TEST ===" -ForegroundColor Cyan
Write-Host "This will start the actual app and inject debugging into the input pipeline" -ForegroundColor Yellow

# Modify the TUI engine input processing to add comprehensive debugging
$enginePath = "./Runtime/ART.002_EngineManagement.ps1"
$tempEnginePath = "./Runtime/ART.002_EngineManagement.ps1.backup"

# Backup original
Copy-Item $enginePath $tempEnginePath

try {
    # Inject debug logging into the input processing
    $engineContent = Get-Content $enginePath -Raw
    
    # Add debug to the input detection section
    $engineContent = $engineContent -replace 
        'if \(\$keyAvailable\) \{',
        'if ($keyAvailable) {
            Write-Host "ENGINE-DEBUG: Key detected, about to ReadKey" -ForegroundColor Red'
    
    # Add debug to the ReadKey section
    $engineContent = $engineContent -replace 
        '\$keyInfo = \[Console\]::ReadKey\(\$true\)',
        '$keyInfo = [Console]::ReadKey($true)
                                    Write-Host "ENGINE-DEBUG: ReadKey successful - Key=$($keyInfo.Key)" -ForegroundColor Red'
    
    # Add debug to the Process-TuiInput call
    $engineContent = $engineContent -replace 
        'Process-TuiInput -KeyInfo \$keyInfo',
        'Write-Host "ENGINE-DEBUG: About to call Process-TuiInput with $($keyInfo.Key)" -ForegroundColor Red
                                    Process-TuiInput -KeyInfo $keyInfo
                                    Write-Host "ENGINE-DEBUG: Process-TuiInput completed" -ForegroundColor Red'
    
    # Write the modified engine
    Set-Content $enginePath -Value $engineContent
    
    Write-Host "Injected debugging into TUI engine" -ForegroundColor Green
    
    # Now also inject debugging into the input processing file
    $inputPath = "./Runtime/ART.004_InputProcessing.ps1"
    $tempInputPath = "./Runtime/ART.004_InputProcessing.ps1.backup"
    
    if (Test-Path $inputPath) {
        Copy-Item $inputPath $tempInputPath
        
        $inputContent = Get-Content $inputPath -Raw
        
        # Add debug to Process-TuiInput
        $inputContent = $inputContent -replace 
            'function Process-TuiInput \{',
            'function Process-TuiInput {
    Write-Host "INPUT-DEBUG: Process-TuiInput called with Key=$($KeyInfo.Key)" -ForegroundColor Blue'
        
        Set-Content $inputPath -Value $inputContent
        Write-Host "Injected debugging into input processing" -ForegroundColor Green
    }
    
    # Start the app
    Write-Host "`nStarting app with debugging enabled..." -ForegroundColor Cyan
    Write-Host "Try pressing arrow keys and watch for debug output" -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to exit when done testing" -ForegroundColor Yellow
    
    . ./Start.ps1 -Debug
}
finally {
    # Restore original files
    Write-Host "`nRestoring original files..." -ForegroundColor Yellow
    if (Test-Path $tempEnginePath) {
        Move-Item $tempEnginePath $enginePath -Force
    }
    if (Test-Path $tempInputPath) {
        Move-Item $tempInputPath $inputPath -Force
    }
    Write-Host "Files restored" -ForegroundColor Green
}