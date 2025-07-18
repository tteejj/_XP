#!/usr/bin/env pwsh

# Test just the logger setup without starting the full TUI
Write-Host "Testing logger setup..."

# Clear any existing logs
Remove-Item -Path ~/.local/share/AxiomPhoenix/app.log -Force -ErrorAction SilentlyContinue

# Load required components
. ./Base/ABC.001b_DependencyInjection.ps1
. ./Services/ASE.001_Logger.ps1
. ./Functions/AFU.006_LoggingFunctions.ps1

# Set up global state
$global:TuiState = @{
    Services = @{}
}

# Create and register logger
$logger = [Logger]::new()
$global:TuiState.Services['Logger'] = $logger

Write-Host "Logger registered in global state"
Write-Host "Logger path: $($logger.LogPath)"

# Test the Write-Log function
Write-Host "Testing Write-Log function..."
try {
    Write-Log -Level Info -Message "Test message from logger setup debug"
    Write-Host "Write-Log function worked!"
} catch {
    Write-Host "Write-Log function failed: $_"
}

# Check if log file was created
if (Test-Path $logger.LogPath) {
    Write-Host "Log file contents:"
    Get-Content $logger.LogPath | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "Log file was not created at: $($logger.LogPath)"
}