# Syntax checker for mono framework files

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

$filesToCheck = @(
    'AllBaseClasses.ps1',
    'AllModels.ps1',  
    'AllFunctions.ps1',
    'AllComponents.ps1',
    'AllScreens.ps1',
    'AllServices.ps1',
    'AllRuntime.ps1'
)

Write-Host "Checking syntax for all mono framework files..." -ForegroundColor Cyan

$errors = @()

foreach ($file in $filesToCheck) {
    $filePath = Join-Path $scriptRoot $file
    Write-Host "`nChecking $file..." -ForegroundColor Yellow
    
    try {
        $tokens = $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $filePath,
            [ref]$tokens,
            [ref]$parseErrors
        )
        
        if ($parseErrors.Count -gt 0) {
            Write-Host "  ERRORS FOUND:" -ForegroundColor Red
            foreach ($err in $parseErrors) {
                Write-Host "    Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Red
                $errors += @{
                    File = $file
                    Line = $err.Extent.StartLineNumber
                    Message = $err.Message
                    Text = $err.Extent.Text
                }
            }
        } else {
            Write-Host "  OK" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  FAILED TO PARSE: $($_.Exception.Message)" -ForegroundColor Red
        $errors += @{
            File = $file
            Line = 0
            Message = $_.Exception.Message
            Text = ""
        }
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
if ($errors.Count -eq 0) {
    Write-Host "No syntax errors found!" -ForegroundColor Green
} else {
    Write-Host "Found $($errors.Count) error(s):" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "`n$($err.File), Line $($err.Line):" -ForegroundColor Yellow
        Write-Host "  $($err.Message)" -ForegroundColor Red
        if ($err.Text) {
            Write-Host "  Text: $($err.Text)" -ForegroundColor Gray
        }
    }
}
