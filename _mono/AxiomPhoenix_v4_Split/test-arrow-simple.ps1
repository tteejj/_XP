# Simple test to verify arrow key fixes
try {
    # Quick test - just run startup through dashboard creation
    . "./Start.ps1" -Theme "Performance" -Debug 2>&1 | Select-String -Pattern "(DASHBOARD|SCREEN|LISTBOX|CRITICAL|Arrow|HandleInput)" | head -20
} catch {
    Write-Host "Test complete or error: $_" -ForegroundColor Red
}
EOF < /dev/null