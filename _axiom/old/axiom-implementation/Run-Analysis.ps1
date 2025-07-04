# Run-Analysis.ps1
# Quick script to run dependency analysis and save results

$scriptPath = $PSScriptRoot
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
$analyzerPath = Join-Path $scriptPath "tools\Dependency-Analyzer.ps1"

Write-Host "Running dependency analysis on: $projectRoot" -ForegroundColor Cyan

# Run with JSON output
& $analyzerPath -ProjectRoot $projectRoot -OutputJson -ShowCircular -Verbose

# Also run without JSON for visual output
Write-Host "`n`nVisual Dependency Graph:" -ForegroundColor Cyan
& $analyzerPath -ProjectRoot $projectRoot -ShowCircular
