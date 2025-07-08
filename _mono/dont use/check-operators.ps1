# Simple test to check for operator issues
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Checking for operator issues in mono files..." -ForegroundColor Cyan
    
    $files = @(
        "AllBaseClasses.ps1",
        "AllModels.ps1", 
        "AllComponents.ps1",
        "AllScreens.ps1",
        "AllFunctions.ps1",
        "AllServices.ps1",
        "AllRuntime.ps1",
        "Start.ps1"
    )
    
    $issuesFound = $false
    
    foreach ($file in $files) {
        $content = Get-Content -Path "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\$file" -Raw
        $lines = $content -split "`n"
        $lineNum = 0
        
        Write-Host "`nChecking $file..." -ForegroundColor Yellow
        
        foreach ($line in $lines) {
            $lineNum++
            # Check for C-style operators
            if ($line -match '(?<![<>!=])([<>]=?|==|!=)(?![<>!=])' -and 
                $line -notmatch '#|".*[<>!=].*"|''.*[<>!=].*''|Write-|Out-|>\s*\$null') {
                Write-Host "  Line $lineNum`: $($line.Trim())" -ForegroundColor Red
                $issuesFound = $true
            }
        }
    }
    
    if (-not $issuesFound) {
        Write-Host "`nNo operator issues found!" -ForegroundColor Green
    }
    
    # Now try to load the first file
    Write-Host "`nTrying to load AllBaseClasses.ps1..." -ForegroundColor Cyan
    . "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllBaseClasses.ps1"
    Write-Host "Success!" -ForegroundColor Green
    
} catch {
    Write-Host "`nError: $_" -ForegroundColor Red
}
