#!/usr/bin/env pwsh

# Simple test to check if logging is working
Write-Host "Testing logging system..."

# Load the logger
. ./Services/ASE.001_Logger.ps1

# Create a logger instance
$logger = [Logger]::new()

Write-Host "Logger created. Log path: $($logger.LogPath)"
Write-Host "EnableFileLogging: $($logger.EnableFileLogging)"
Write-Host "MinimumLevel: $($logger.MinimumLevel)"

# Test logging
$logger.Log("Test message from debug script", "Info")
$logger.Log("Debug message from debug script", "Debug")
$logger.Log("Error message from debug script", "Error")

# Force flush
$logger.Flush()

Write-Host "Logging test complete. Checking log file..."

if (Test-Path $logger.LogPath) {
    Write-Host "Log file exists:"
    Get-Content $logger.LogPath | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "Log file does not exist at: $($logger.LogPath)"
}

# Also test the global Write-Log function
try {
    . ./Functions/AFU.002_LoggingFunctions.ps1
    Write-Log -Level Info -Message "Test message from Write-Log function"
    Write-Host "Write-Log function test complete"
} catch {
    Write-Host "Error testing Write-Log function: $_"
}