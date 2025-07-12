# Test Console Input Directly
# ==========================

Write-Host "TESTING CONSOLE INPUT DIRECTLY" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This tests if PowerShell can read keyboard input at all." -ForegroundColor Yellow
Write-Host ""

# Set console mode
[Console]::TreatControlCAsInput = $true
[Console]::CursorVisible = $false

Write-Host "Press any key (or Ctrl+C to exit):" -ForegroundColor Green

$count = 0
while ($count -lt 10) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        Write-Host ""
        Write-Host "Key Read #$($count + 1):" -ForegroundColor Yellow
        Write-Host "  Key: $($key.Key)" -ForegroundColor White
        Write-Host "  Char: '$($key.KeyChar)'" -ForegroundColor White
        Write-Host "  Modifiers: $($key.Modifiers)" -ForegroundColor White
        Write-Host "  KeyAvailable worked: YES" -ForegroundColor Green
        $count++
        
        if ($key.Modifiers -band [ConsoleModifiers]::Control -and $key.Key -eq [ConsoleKey]::C) {
            Write-Host "`nCtrl+C detected - exiting" -ForegroundColor Red
            break
        }
    }
    Start-Sleep -Milliseconds 50
}

Write-Host ""
Write-Host "Console input test complete." -ForegroundColor Green
Write-Host ""

# Reset console
[Console]::TreatControlCAsInput = $false
[Console]::CursorVisible = $true

Write-Host "If keys were detected above, then basic console input WORKS." -ForegroundColor Cyan
Write-Host "If not, there's a fundamental console configuration issue." -ForegroundColor Red
Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Gray
Read-Host
