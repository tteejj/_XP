# Simple test to check class loading order
$ErrorActionPreference = 'Stop'

Write-Host "Testing class instantiation order..." -ForegroundColor Cyan

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Load only the essential files
try {
    Write-Host "`nLoading AllServices.ps1..." -ForegroundColor Yellow
    . (Join-Path $scriptRoot 'AllServices.ps1')
    
    Write-Host "Creating Logger instance..." -ForegroundColor Yellow
    $logger = [Logger]::new()
    Write-Host "✓ Logger created successfully!" -ForegroundColor Green
    
    Write-Host "`nNow loading AllBaseClasses.ps1..." -ForegroundColor Yellow
    . (Join-Path $scriptRoot 'AllBaseClasses.ps1')
    
    Write-Host "Creating ServiceContainer instance..." -ForegroundColor Yellow
    $container = [ServiceContainer]::new()
    Write-Host "✓ ServiceContainer created successfully!" -ForegroundColor Green
    
    Write-Host "`nTrying to register Logger..." -ForegroundColor Yellow
    $container.Register("Logger", $logger)
    Write-Host "✓ Logger registered successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "`n✗ Error occurred:" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Stack:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}

Write-Host "`nPress any key to exit..."
[Console]::ReadKey($true) | Out-Null
