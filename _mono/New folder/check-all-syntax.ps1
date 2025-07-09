# Comprehensive syntax check for all PowerShell files in the project
$projectPath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono"
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

$hasErrors = $false

foreach ($file in $files) {
    $filePath = Join-Path $projectPath $file
    Write-Host "Checking $file..." -ForegroundColor Yellow
    
    try {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $filePath,
            [ref]$tokens,
            [ref]$errors
        )
        
        if ($errors -and $errors.Count -gt 0) {
            $hasErrors = $true
            Write-Host "  ERROR in $file`:" -ForegroundColor Red
            foreach ($error in $errors) {
                Write-Host "    Line $($error.Extent.StartLineNumber): $($error.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  OK" -ForegroundColor Green
        }
    } catch {
        $hasErrors = $true
        Write-Host "  CRITICAL ERROR in $file`:" -ForegroundColor Red
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
    }
}

if (-not $hasErrors) {
    Write-Host "`nAll files have valid syntax!" -ForegroundColor Green
} else {
    Write-Host "`nSome files have syntax errors. Please fix them before running the application." -ForegroundColor Red
}
