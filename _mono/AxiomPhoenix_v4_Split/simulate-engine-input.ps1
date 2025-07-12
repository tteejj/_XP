# Simulate Engine Input Loop
# ==========================

Write-Host "SIMULATING ENGINE INPUT LOOP" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This simulates exactly what the engine should do." -ForegroundColor Yellow
Write-Host "Press keys and see if they're detected." -ForegroundColor Yellow
Write-Host "Press ESC to exit." -ForegroundColor Yellow
Write-Host ""

# Set up console like the engine does
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false
[Console]::TreatControlCAsInput = $true

Write-Host "Console configured. Waiting for input..." -ForegroundColor Green
Write-Host ""

$frameCount = 0
$running = $true

while ($running) {
    $frameCount++
    
    # Simulate engine input phase
    if ([Console]::KeyAvailable) {
        Write-Host "[Frame $frameCount] KeyAvailable = TRUE" -ForegroundColor Yellow
        
        try {
            $keyInfo = [Console]::ReadKey($true)
            
            if ($keyInfo) {
                Write-Host "[Frame $frameCount] ReadKey SUCCESS:" -ForegroundColor Green
                Write-Host "  Key: $($keyInfo.Key)" -ForegroundColor White
                Write-Host "  Char: '$($keyInfo.KeyChar)' (ASCII: $([int]$keyInfo.KeyChar))" -ForegroundColor White
                Write-Host "  Modifiers: $($keyInfo.Modifiers)" -ForegroundColor White
                
                # Check for ESC
                if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
                    Write-Host "`nESC pressed - exiting" -ForegroundColor Red
                    $running = $false
                }
                
                # Simulate what Process-TuiInput would do
                Write-Host "  [Would call Process-TuiInput with this KeyInfo]" -ForegroundColor Gray
                Write-Host ""
            } else {
                Write-Host "[Frame $frameCount] ReadKey returned NULL!" -ForegroundColor Red
            }
        } catch {
            Write-Host "[Frame $frameCount] ReadKey EXCEPTION: $_" -ForegroundColor Red
        }
    }
    
    # Simulate frame delay
    Start-Sleep -Milliseconds 33  # ~30 FPS
}

# Reset console
[Console]::TreatControlCAsInput = $false
[Console]::CursorVisible = $true

Write-Host ""
Write-Host "Simulation complete." -ForegroundColor Green
Write-Host ""
Write-Host "If keys were detected above, the engine input loop SHOULD work." -ForegroundColor Cyan
Write-Host "If not, there's a fundamental issue with Console.KeyAvailable or ReadKey." -ForegroundColor Red
Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Gray
Read-Host
