# Final diagnostic - trace exact error location
$ErrorActionPreference = 'Continue'  # Don't stop on first error
$VerbosePreference = 'Continue'      # Show verbose output

Write-Host "=== AXIOM-PHOENIX DIAGNOSTIC ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "Platform: $($PSVersionTable.Platform)" -ForegroundColor Gray

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Load files one by one and test
$files = @(
    'AllBaseClasses.ps1'
    'AllModels.ps1'
    'AllFunctions.ps1'
    'AllComponents.ps1'
    'AllScreens.ps1'
    'AllServices.ps1'
    'AllRuntime.ps1'
)

Write-Host "`nLoading framework files..." -ForegroundColor Yellow
foreach ($file in $files) {
    $filePath = Join-Path $scriptRoot $file
    Write-Host "  Loading $file..." -NoNewline
    try {
        . $filePath
        Write-Host " OK" -ForegroundColor Green
    } catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nTesting ServiceContainer..." -ForegroundColor Yellow
try {
    Write-Host "  Creating instance..." -NoNewline
    $container = [ServiceContainer]::new()
    Write-Host " OK" -ForegroundColor Green
    
    Write-Host "  Testing Register method..." -NoNewline
    $container.Register("TestService", "TestValue")
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "    Error: $_" -ForegroundColor Red
    Write-Host "    Stack: $($_.ScriptStackTrace)" -ForegroundColor Gray
}

Write-Host "`nTesting Logger..." -ForegroundColor Yellow
try {
    Write-Host "  Step 1: Creating Logger instance..." -NoNewline
    $logger = $null
    $logger = [Logger]::new()
    Write-Host " OK (Logger created)" -ForegroundColor Green
    
    Write-Host "  Step 2: Checking Logger properties..." -NoNewline
    Write-Host " LogPath=$($logger.LogPath)" -ForegroundColor Gray
    
    Write-Host "  Step 3: Registering Logger in container..." -NoNewline
    $container.Register("Logger", $logger)
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " FAILED at step" -ForegroundColor Red
    Write-Host "`n    Full Error: $_" -ForegroundColor Red
    Write-Host "    Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "    Target Site: $($_.Exception.TargetSite)" -ForegroundColor Red
    Write-Host "    Stack Trace:" -ForegroundColor Gray
    $_.ScriptStackTrace -split "`n" | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    
    # Check if it's really about a property
    if ($_.Exception.Message -like "*property*") {
        Write-Host "`n    This is a PROPERTY error!" -ForegroundColor Yellow
        Write-Host "    Checking error details..." -ForegroundColor Yellow
        Write-Host "    InvocationInfo: $($_.InvocationInfo.Line)" -ForegroundColor Yellow
    }
}

Write-Host "`nTesting inline Logger syntax variations..." -ForegroundColor Yellow
try {
    Write-Host "  Test 1: Two-step creation..." -NoNewline
    $testLogger1 = [Logger]::new()
    $container.Register("Logger1", $testLogger1)
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

try {
    Write-Host "  Test 2: Direct in Register call..." -NoNewline
    $container.Register("Logger2", [Logger]::new())
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
    Write-Host "    This is the exact syntax from start.ps1!" -ForegroundColor Yellow
}

Write-Host "`nPress any key to exit..."
[Console]::ReadKey($true) | Out-Null
