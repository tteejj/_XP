# ==============================================================================
# Axiom-Phoenix v4.0 - Minimal Test Application
# Tests basic navigation without full framework overhead
# ==============================================================================

param(
    [switch]$Debug
)

$ErrorActionPreference = 'Stop'

Write-Host "Axiom-Phoenix v4.0 - Minimal Navigation Test" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "  Press 1-4 to test navigation" -ForegroundColor White
Write-Host "  Press Q to quit" -ForegroundColor White
Write-Host "  Press any other key to see it logged" -ForegroundColor White
Write-Host ""

# Create a minimal console app to test input
$running = $true

while ($running) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        
        Write-Host "`nKey pressed: Key='$($key.Key)', KeyChar='$($key.KeyChar)', Modifiers='$($key.Modifiers)'" -ForegroundColor Cyan
        
        switch ($key.KeyChar) {
            '1' { Write-Host "  → Would navigate to: Dashboard" -ForegroundColor Green }
            '2' { Write-Host "  → Would navigate to: Task List" -ForegroundColor Green }
            '3' { Write-Host "  → Would navigate to: Theme Picker" -ForegroundColor Green }
            '4' { Write-Host "  → Would open: Command Palette" -ForegroundColor Green }
            'q' { 
                Write-Host "  → Exiting..." -ForegroundColor Yellow
                $running = $false
            }
            'Q' { 
                Write-Host "  → Exiting..." -ForegroundColor Yellow
                $running = $false
            }
            default {
                Write-Host "  → No action for this key" -ForegroundColor Gray
            }
        }
    }
    
    Start-Sleep -Milliseconds 50
}

Write-Host "`nConsole input test completed." -ForegroundColor Green
Write-Host "If keys were detected correctly, the issue is in the framework." -ForegroundColor Yellow
Write-Host "If keys were NOT detected, the issue is with your terminal." -ForegroundColor Yellow
