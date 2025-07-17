# Simple test to check if key detection is working
Write-Host "Testing key detection..." -ForegroundColor Green

# Set up console like the TUI does
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

try {
    [Console]::TreatControlCAsInput = $true
    Write-Host "TreatControlCAsInput set to true" -ForegroundColor Green
} catch {
    Write-Host "Could not set TreatControlCAsInput: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Press any key (or Ctrl+C to exit)..." -ForegroundColor Yellow

$testCount = 0
while ($testCount -lt 10) {
    $keyAvailable = $false
    try {
        $keyAvailable = [Console]::KeyAvailable
    } catch {
        try { $keyAvailable = [Console]::In.Peek() -ne -1 } catch { $keyAvailable = $false }
    }
    
    if ($keyAvailable) {
        $keyInfo = [Console]::ReadKey($true)
        Write-Host "Key detected: $($keyInfo.Key), Char: '$($keyInfo.KeyChar)', Modifiers: $($keyInfo.Modifiers)" -ForegroundColor Cyan
        
        if ($keyInfo.Key -eq [ConsoleKey]::C -and ($keyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
            Write-Host "Ctrl+C detected - exiting" -ForegroundColor Red
            break
        }
        
        $testCount++
    }
    
    Start-Sleep -Milliseconds 50
}

[Console]::CursorVisible = $true
Write-Host "Test completed" -ForegroundColor Green