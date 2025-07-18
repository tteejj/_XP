#!/usr/bin/env pwsh
# Test basic console input detection

Write-Host "=== CONSOLE INPUT DETECTION TEST ===" -ForegroundColor Cyan
Write-Host "Testing Console.KeyAvailable and Console.ReadKey directly" -ForegroundColor Yellow

# Test Console input detection outside the TUI framework
Write-Host "Press any key (5 second timeout):" -ForegroundColor Green

$timeout = 5
$startTime = Get-Date

while (((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
    if ([Console]::KeyAvailable) {
        Write-Host "Console.KeyAvailable detected input!" -ForegroundColor Green
        $key = [Console]::ReadKey($true)
        Write-Host "Key detected: $($key.Key) Char='$($key.KeyChar)' Modifiers=$($key.Modifiers)" -ForegroundColor Green
        break
    }
    Start-Sleep -Milliseconds 10
}

Write-Host "`nDirect test complete. Now testing Host.UI.RawUI.KeyAvailable..." -ForegroundColor Yellow

Write-Host "Press any key again (5 second timeout):" -ForegroundColor Green
$startTime = Get-Date

while (((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
    if ($Host.UI.RawUI.KeyAvailable) {
        Write-Host "Host.UI.RawUI.KeyAvailable detected input!" -ForegroundColor Green
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-Host "Key detected: $($key.VirtualKeyCode) Char='$($key.Character)'" -ForegroundColor Green
        break
    }
    Start-Sleep -Milliseconds 10
}

Write-Host "`n=== INPUT DETECTION TEST COMPLETE ===" -ForegroundColor Cyan