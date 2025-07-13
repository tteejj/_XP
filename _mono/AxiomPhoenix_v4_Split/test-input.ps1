# ==============================================================================
# Debug Dashboard Test Script
# Run this to test dashboard input with full debug logging
# ==============================================================================

# Clear the console and show what we're doing
Clear-Host
Write-Host "=== AXIOM-PHOENIX DEBUG TEST ===" -ForegroundColor Cyan
Write-Host "Starting dashboard with full debug logging..." -ForegroundColor Yellow
Write-Host "Log file: $env:TEMP\axiom-phoenix.log" -ForegroundColor Gray
Write-Host "Watch console for debug output..." -ForegroundColor Yellow
Write-Host ""

# Start the application
try {
    . .\Start.ps1 -Theme "Synthwave" -Debug
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
}
