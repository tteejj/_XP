# Complete syntax test - run Start.ps1 with minimal operations
param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
Clear-Host

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Axiom-Phoenix v4.0 Syntax Test" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Files to load in order
$files = @(
    @{ File = "AllBaseClasses.ps1"; Description = "Base Classes" },
    @{ File = "AllModels.ps1"; Description = "Data Models" },
    @{ File = "AllComponents.ps1"; Description = "UI Components" },
    @{ File = "AllScreens.ps1"; Description = "Application Screens" },
    @{ File = "AllFunctions.ps1"; Description = "Utility Functions" },
    @{ File = "AllServices.ps1"; Description = "Services" },
    @{ File = "AllRuntime.ps1"; Description = "Runtime Engine" }
)

$loadedFiles = 0
$totalFiles = $files.Count

foreach ($fileInfo in $files) {
    $percent = [Math]::Floor(($loadedFiles / $totalFiles) * 100)
    
    Write-Host "[$percent%] " -NoNewline -ForegroundColor Green
    Write-Host "Loading $($fileInfo.Description)... " -NoNewline -ForegroundColor Gray
    
    $filePath = Join-Path $scriptDir $fileInfo.File
    if (Test-Path $filePath) {
        try {
            . $filePath
            Write-Host "✓" -ForegroundColor Green
            $loadedFiles++
        }
        catch {
            Write-Host "✗" -ForegroundColor Red
            Write-Host "`nERROR in $($fileInfo.File):" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Host "`nLocation:" -ForegroundColor Cyan
            Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor Gray
            
            if ($Verbose) {
                Write-Host "`nStack Trace:" -ForegroundColor Cyan
                Write-Host $_.ScriptStackTrace -ForegroundColor Gray
            }
            
            Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
    } else {
        Write-Host "✗ FILE NOT FOUND" -ForegroundColor Red
        exit 1
    }
}

Write-Host "[100%] " -NoNewline -ForegroundColor Green
Write-Host "All files loaded successfully!" -ForegroundColor Green

Write-Host "`n✓ SYNTAX TEST PASSED!" -ForegroundColor Green
Write-Host "`nAll Axiom-Phoenix framework files loaded without syntax errors." -ForegroundColor Gray
Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
