# Test syntax of AllComponents.ps1
try {
    Write-Host "Testing AllComponents.ps1 syntax..." -ForegroundColor Yellow
    
    # Use the PowerShell parser to check syntax
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllComponents.ps1",
        [ref]$null,
        [ref]$null
    )
    
    Write-Host "SUCCESS: AllComponents.ps1 has valid syntax!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: AllComponents.ps1 has syntax errors:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
