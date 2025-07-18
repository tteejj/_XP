#!/usr/bin/env pwsh

# Test if the global state is being set up correctly
Write-Host "Testing global state setup..."

# Clear any existing logs
Remove-Item -Path ~/.local/share/AxiomPhoenix/app.log -Force -ErrorAction SilentlyContinue

# Start loading the application framework
. ./Start.ps1

# Check if global state is set up
if ($global:TuiState) {
    Write-Host "TuiState exists"
    if ($global:TuiState.Services) {
        Write-Host "TuiState.Services exists"
        if ($global:TuiState.Services.ContainsKey('Logger')) {
            Write-Host "Logger found in TuiState.Services"
            $logger = $global:TuiState.Services['Logger']
            Write-Host "Logger type: $($logger.GetType().Name)"
            Write-Host "Logger path: $($logger.LogPath)"
        } else {
            Write-Host "Logger NOT found in TuiState.Services"
            Write-Host "Available services: $($global:TuiState.Services.Keys -join ', ')"
        }
    } else {
        Write-Host "TuiState.Services is null"
    }
} else {
    Write-Host "TuiState is null"
}

# Now test the Write-Log function
Write-Host "Testing Write-Log function..."
try {
    Write-Log -Level Info -Message "Test message from global state debug"
    Write-Host "Write-Log function worked!"
} catch {
    Write-Host "Write-Log function failed: $_"
}

# Check if log file was created
if (Test-Path ~/.local/share/AxiomPhoenix/app.log) {
    Write-Host "Log file contents:"
    Get-Content ~/.local/share/AxiomPhoenix/app.log | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "Log file was not created"
}