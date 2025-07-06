# launcher.ps1 - Loads all classes then runs the application
param(
    [switch]$Debug,
    [switch]$SkipLogo
)

$ErrorActionPreference = 'Stop'
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "🚀 Axiom-Phoenix Launcher" -ForegroundColor Cyan

# STAGE 1: Load all class definitions
Write-Host "Loading class definitions..." -ForegroundColor Gray
. "$PSScriptRoot\all-classes.ps1"

# STAGE 2: Now we can safely run the main script
Write-Host "Starting main application..." -ForegroundColor Gray

# The run.ps1 can now assume all classes exist
$runScript = Join-Path $PSScriptRoot "run.ps1"
if (Test-Path $runScript) {
    & $runScript @PSBoundParameters
} else {
    Write-Host "ERROR: run.ps1 not found!" -ForegroundColor Red
    Write-Host "Expected location: $runScript" -ForegroundColor Red
}
