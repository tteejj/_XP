# Simple input test to diagnose the issue

Write-Host "Simple Input Test" -ForegroundColor Cyan
Write-Host "Press keys and see what PowerShell receives:" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to exit" -ForegroundColor Yellow
Write-Host ""

while ($true) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        
        Write-Host "Key: $($key.Key)" -ForegroundColor Green -NoNewline
        Write-Host " | KeyChar: '$($key.KeyChar)'" -ForegroundColor Yellow -NoNewline
        Write-Host " | ASCII: $([int]$key.KeyChar)" -ForegroundColor Cyan -NoNewline
        Write-Host " | Modifiers: $($key.Modifiers)" -ForegroundColor Magenta
        
        if ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
            break
        }
    }
    Start-Sleep -Milliseconds 50
}

Write-Host "`nTest complete." -ForegroundColor Green
