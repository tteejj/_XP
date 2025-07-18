#!/usr/bin/env pwsh

# Test Dashboard initialization with logging
Write-Host "Testing Dashboard initialization with logging..."

# Clear any existing logs
Remove-Item -Path ~/.local/share/AxiomPhoenix/app.log -Force -ErrorAction SilentlyContinue

# Load required components step by step
. ./Models/AMO.001_Enums.ps1
. ./Models/AMO.002_ValidationBase.ps1
. ./Models/AMO.003_CoreModelClasses.ps1
. ./Models/AMO.004_ExceptionClasses.ps1
. ./Models/AMO.005_NavigationClasses.ps1
. ./Base/ABC.001_TuiAnsiHelper.ps1
. ./Base/ABC.002_TuiCell.ps1
. ./Base/ABC.003_TuiBuffer.ps1
. ./Base/ABC.004_UIElement.ps1
. ./Base/ABC.006_Screen.ps1
. ./Base/ABC.001b_DependencyInjection.ps1
. ./Services/ASE.001_Logger.ps1
. ./Functions/AFU.006_LoggingFunctions.ps1
. ./Functions/AFU.004_ThemeFunctions.ps1
. ./Components/ACO.001_LabelComponent.ps1
. ./Components/ACO.011_Panel.ps1
. ./Components/ACO.014_ListBox.ps1
. ./Screens/ASC.001_DashboardScreen.ps1

# Set up global state
$global:TuiState = @{
    Services = @{}
}

# Create and register logger
$logger = [Logger]::new()
$global:TuiState.Services['Logger'] = $logger

Write-Host "Logger registered. Testing Write-Log function..."

# Test Write-Log directly
Write-Log -Level Info -Message "Direct Write-Log test from debug script"

# Create a mock service container
$mockContainer = @{
    GetService = { param($name) return $null }
}

# Create Dashboard instance
Write-Host "Creating Dashboard instance..."
try {
    $dashboard = [DashboardScreen]::new($mockContainer)
    Write-Host "Dashboard created successfully"
    
    # Test initialization
    Write-Host "Testing Dashboard initialization..."
    $dashboard.Initialize()
    Write-Host "Dashboard initialized successfully"
    
    # Test OnEnter
    Write-Host "Testing Dashboard OnEnter..."
    $dashboard.OnEnter()
    Write-Host "Dashboard OnEnter completed"
    
} catch {
    Write-Host "Error with Dashboard: $_"
}

# Check log file
if (Test-Path $logger.LogPath) {
    Write-Host "Log file contents:"
    Get-Content $logger.LogPath | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "Log file was not created at: $($logger.LogPath)"
}