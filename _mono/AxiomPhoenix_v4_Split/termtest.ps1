    
     # Test console setup that TUI engine uses
     Write-Host "=== CONSOLE SETUP TEST ===" -ForegroundColor Cyan

     try {
         Write-Host "Testing console configuration..." -ForegroundColor Yellow

         # Store original state
#         Write-Host "Original cursor visible: $([Console]::CursorVisible)"
     -ForegroundColor Green
         Write-Host "Original window title: $($Host.UI.RawUI.WindowTitle)"
     -ForegroundColor Green

         # Test the same configuration as TUI engine
         Write-Host "Setting up console like TUI engine..." -ForegroundColor Yellow

         [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
         [Console]::InputEncoding = [System.Text.Encoding]::UTF8
         Write-Host "✓ Encoding set to UTF8" -ForegroundColor Green

         [Console]::CursorVisible = $false
         Write-Host "✓ Cursor hidden" -ForegroundColor Green

         [Console]::TreatControlCAsInput = $true
         Write-Host "✓ Control-C as input enabled" -ForegroundColor Green

         $Host.UI.RawUI.WindowTitle = "Test TUI Framework"
         Write-Host "✓ Window title set" -ForegroundColor Green

         Write-Host "Testing key availability..." -ForegroundColor Yellow
         Write-Host "KeyAvailable: $([Console]::KeyAvailable)" -ForegroundColor Green

         Write-Host "Testing basic loop simulation..." -ForegroundColor Yellow
         $testRunning = $true
         $iterations = 0
         $maxIterations = 5

         while ($testRunning -and $iterations -lt $maxIterations) {
             Write-Host "Loop iteration $iterations" -ForegroundColor Gray

             if ([Console]::KeyAvailable) {
                 Write-Host "Key is available!" -ForegroundColor Green
                 $key = [Console]::ReadKey($true)
                 Write-Host "Read key: $($key.Key)" -ForegroundColor Green
                 if ($key.Key -eq 'q') {
                     $testRunning = $false
                     Write-Host "Quit key pressed" -ForegroundColor Yellow
                 }
             }

             Start-Sleep -Milliseconds 100
             $iterations++
         }

         Write-Host "✓ Basic loop completed successfully" -ForegroundColor Green

     } catch {
         Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
         Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
     } finally {
         # Restore console
         [Console]::CursorVisible = $true
         Write-Host "`n=== TEST COMPLETED ===" -ForegroundColor Cyan
     }
