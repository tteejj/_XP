# Direct test of the fixed syntax
Clear-Host
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Testing AllComponents.ps1 syntax..." -ForegroundColor Cyan
    
    # Use AST parsing to check for syntax errors without executing
    $scriptPath = "$PSScriptRoot\AllComponents.ps1"
    $tokens = $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
    
    if ($errors.Count -gt 0) {
        Write-Host "SYNTAX ERRORS FOUND:" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "  Line $($error.Extent.StartLineNumber): $($error.Message)" -ForegroundColor Yellow
        }
        exit 1
    }
    
    Write-Host "✓ No syntax errors found!" -ForegroundColor Green
    
    # Now try to actually load it
    Write-Host "`nLoading AllComponents.ps1..." -ForegroundColor Cyan
    . $scriptPath
    Write-Host "✓ Successfully loaded!" -ForegroundColor Green
    
    # Test the specific class that had the issue
    Write-Host "`nTesting CommandPalette instantiation..." -ForegroundColor Cyan
    $cp = [CommandPalette]::new()
    Write-Host "✓ CommandPalette created successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "`nERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nDetails:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
