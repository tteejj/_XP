#!/usr/bin/env pwsh
# Test the fixed input detection

Write-Host "=== TESTING FIXED INPUT DETECTION ===" -ForegroundColor Cyan

# Test Host.UI.RawUI.KeyAvailable directly
Write-Host "Testing Host.UI.RawUI.KeyAvailable..." -ForegroundColor Yellow
try {
    $available = $Host.UI.RawUI.KeyAvailable
    Write-Host "Host.UI.RawUI.KeyAvailable = $available" -ForegroundColor Green
    
    if ($available) {
        Write-Host "Key is available! Reading..." -ForegroundColor Green
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-Host "Key read: VirtualKeyCode=$($key.VirtualKeyCode) Character='$($key.Character)'" -ForegroundColor Green
    } else {
        Write-Host "No key available" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Host.UI.RawUI.KeyAvailable failed: $_" -ForegroundColor Red
}

Write-Host "`nNow testing the app with fixed input detection..." -ForegroundColor Cyan
Write-Host "Arrow keys should now work!" -ForegroundColor Green

# Start the app
. ./Start.ps1