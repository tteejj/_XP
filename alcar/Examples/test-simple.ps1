#!/usr/bin/env pwsh
# Simple test to verify bolt.ps1 loads without errors

$ErrorActionPreference = 'Stop'

Write-Host "Testing ALCAR loading..." -ForegroundColor Cyan

# Set a flag to skip the main execution
$global:ALCAR_TEST_MODE = $true

try {
    # Source bolt.ps1
    . ./bolt.ps1
    
    Write-Host "`nFramework loaded successfully!" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "`nError during loading: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}