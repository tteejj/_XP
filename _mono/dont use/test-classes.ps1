# Test script to verify class instantiation
# This helps debug which class is causing the issue

$ErrorActionPreference = 'Continue'

Write-Host "Testing Axiom-Phoenix class instantiation..." -ForegroundColor Cyan

# Load files
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$filesToLoad = @(
    'AllBaseClasses.ps1'
    'AllModels.ps1'
    'AllFunctions.ps1'
    'AllComponents.ps1'
    'AllScreens.ps1'
    'AllServices.ps1'
    'AllRuntime.ps1'
)

foreach ($file in $filesToLoad) {
    $filePath = Join-Path $scriptRoot $file
    if (Test-Path $filePath) {
        Write-Host "Loading $file..." -ForegroundColor Gray
        . $filePath
    } else {
        Write-Host "File not found: $file" -ForegroundColor Red
    }
}

Write-Host "`nTesting ServiceContainer..." -ForegroundColor Yellow
try {
    $container = [ServiceContainer]::new()
    Write-Host "✓ ServiceContainer instantiated successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ ServiceContainer failed: $_" -ForegroundColor Red
}

Write-Host "`nTesting Logger..." -ForegroundColor Yellow
try {
    $logger = [Logger]::new()
    Write-Host "✓ Logger instantiated successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Logger failed: $_" -ForegroundColor Red
}

Write-Host "`nTesting EventManager..." -ForegroundColor Yellow
try {
    $eventManager = [EventManager]::new()
    Write-Host "✓ EventManager instantiated successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ EventManager failed: $_" -ForegroundColor Red
}

Write-Host "`nTesting ThemeManager..." -ForegroundColor Yellow
try {
    $themeManager = [ThemeManager]::new()
    Write-Host "✓ ThemeManager instantiated successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ ThemeManager failed: $_" -ForegroundColor Red
}

Write-Host "`nTesting ActionService..." -ForegroundColor Yellow
try {
    $actionService = [ActionService]::new()
    Write-Host "✓ ActionService instantiated successfully (no EventManager)" -ForegroundColor Green
} catch {
    Write-Host "✗ ActionService failed: $_" -ForegroundColor Red
}

Write-Host "`nTesting container.Register..." -ForegroundColor Yellow
try {
    if ($container -and $logger) {
        $container.Register("Logger", $logger)
        Write-Host "✓ container.Register worked for Logger" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ container.Register failed: $_" -ForegroundColor Red
    Write-Host "Exception type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
}

Write-Host "`nPress any key to exit..."
[Console]::ReadKey($true) | Out-Null
