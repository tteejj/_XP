# start.ps1
#Requires -Version 7.0

Set-Location $PSScriptRoot
$ErrorActionPreference = 'Stop'

try {
    # This command reads the manifest and loads every script from NestedModules
    # in the specified order into a single, cohesive module context.
    # -Force is essential for development to ensure changes are always reloaded.
    Import-Module .\PMCTerminal.psd1 -Force

    # If Import-Module succeeds, all classes are defined and all functions
    # from the RootModule are exported and available.
    Start-PMCTerminal
    
} catch {
    Write-Host "`n"
    Write-Host "=======================" -ForegroundColor Red
    Write-Host "  FATAL ERROR ON STARTUP " -ForegroundColor Red
    Write-Host "=======================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "`n--- Stack Trace ---" -ForegroundColor DarkGray
    Write-Host $_.ScriptStackTrace
    Write-Host "`n--- Full Exception Details ---" -ForegroundColor DarkGray
    $_ | Format-List * -Force
    Read-Host "`nPress ENTER to exit"
}