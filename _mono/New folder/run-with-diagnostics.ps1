# Run Start.ps1 with comprehensive error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    Write-Host "Running syntax check first..." -ForegroundColor Yellow
    
    # First check syntax of all files
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
    
    $syntaxOk = $true
    foreach ($file in $files) {
        $filePath = Join-Path $projectPath $file
        try {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $filePath,
                [ref]$null,
                [ref]$errors
            )
            
            if ($errors -and $errors.Count -gt 0) {
                $syntaxOk = $false
                Write-Host "Syntax error in $file`:" -ForegroundColor Red
                foreach ($error in $errors) {
                    Write-Host "  Line $($error.Extent.StartLineNumber): $($error.Message)" -ForegroundColor Red
                }
            }
        } catch {
            $syntaxOk = $false
            Write-Host "Failed to parse $file`: $_" -ForegroundColor Red
        }
    }
    
    if (-not $syntaxOk) {
        Write-Host "`nSyntax errors found. Cannot proceed." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "All syntax checks passed!" -ForegroundColor Green
    Write-Host "`nLaunching application..." -ForegroundColor Cyan
    
    # Now run the actual application
    & "$projectPath\Start.ps1"
    
} catch {
    Write-Host "`nERROR: Failed to run application" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    
    # If it's a parse error, show more details
    if ($_.Exception -is [System.Management.Automation.ParseException]) {
        Write-Host "`nParse Error Details:" -ForegroundColor Red
        Write-Host "  Position: $($_.Exception.ErrorRecord.InvocationInfo.PositionMessage)" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
