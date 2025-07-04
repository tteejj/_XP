# Quick-Test-Module.ps1
# Quick test to verify module loading in isolated PowerShell session

param(
    [string]$ModuleName = "tui-primitives"
)

$testScript = @'
$ErrorActionPreference = "Stop"
try {
    # Add axiom modules to path
    $env:PSModulePath = "C:\Users\jhnhe\Documents\GitHub\_XP\_axiom\axiom-modules;$env:PSModulePath"
    
    # Import module
    Import-Module tui-primitives -Force
    
    # Test basic functionality
    $buffer = [TuiBuffer]::new(10, 10, "Test")
    $cell = [TuiCell]::new('X')
    
    Write-Host "SUCCESS: Module loaded and classes work!" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
    exit 1
}
'@

# Run in separate PowerShell process to ensure clean environment
$result = pwsh -NoProfile -Command $testScript

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Module test passed!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Module test failed!" -ForegroundColor Red
}
