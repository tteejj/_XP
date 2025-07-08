# Test script to verify the mono application loads correctly
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Testing Axiom-Phoenix v4.0 mono..." -ForegroundColor Cyan
    
    # Change to the directory
    Set-Location "C:\Users\jhnhe\Documents\GitHub\_XP\_mono"
    
    # Load all files in order
    Write-Host "Loading framework files..." -ForegroundColor Yellow
    
    . .\AllBaseClasses.ps1
    Write-Host "✓ AllBaseClasses.ps1 loaded" -ForegroundColor Green
    
    . .\AllModels.ps1
    Write-Host "✓ AllModels.ps1 loaded" -ForegroundColor Green
    
    . .\AllComponents.ps1
    Write-Host "✓ AllComponents.ps1 loaded" -ForegroundColor Green
    
    . .\AllScreens.ps1
    Write-Host "✓ AllScreens.ps1 loaded" -ForegroundColor Green
    
    . .\AllFunctions.ps1
    Write-Host "✓ AllFunctions.ps1 loaded" -ForegroundColor Green
    
    . .\AllServices.ps1
    Write-Host "✓ AllServices.ps1 loaded" -ForegroundColor Green
    
    . .\AllRuntime.ps1
    Write-Host "✓ AllRuntime.ps1 loaded" -ForegroundColor Green
    
    Write-Host "`nAll framework files loaded successfully!" -ForegroundColor Green
    
    # Test creating some objects
    Write-Host "`nTesting object creation..." -ForegroundColor Yellow
    
    $task = [PmcTask]::new("Test Task")
    Write-Host "✓ Created PmcTask: $($task.Title)" -ForegroundColor Green
    
    $project = [PmcProject]::new("TEST", "Test Project")
    Write-Host "✓ Created PmcProject: $($project.Name)" -ForegroundColor Green
    
    $buffer = [TuiBuffer]::new(80, 25, "TestBuffer")
    Write-Host "✓ Created TuiBuffer: $($buffer.Name) ($($buffer.Width)x$($buffer.Height))" -ForegroundColor Green
    
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    
} catch {
    Write-Host "`nError occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
