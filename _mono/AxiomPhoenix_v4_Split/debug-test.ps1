#!/usr/bin/env pwsh
# Debug test script to isolate the startup issue

param(
    [string]$Theme = "Synthwave",
    [switch]$Debug
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Initialize scriptDir
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = Get-Location
}

try {
    Write-Host "Starting debug test..." -ForegroundColor Yellow
    
    # Test 1: Load file logger
    Write-Host "Test 1: Loading file logger..." -ForegroundColor Cyan
    $fileLoggerPath = Join-Path $scriptDir "Functions\AFU.006a_FileLogger.ps1"
    if (Test-Path $fileLoggerPath) {
        . $fileLoggerPath
        Write-Host "✓ File logger loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ File logger not found" -ForegroundColor Red
    }
    
    # Test 2: Load framework files
    Write-Host "Test 2: Loading framework files..." -ForegroundColor Cyan
    $loadOrder = @("Base", "Models", "Functions", "Components", "Screens", "Services", "Runtime")
    
    foreach ($folder in $loadOrder) {
        Write-Host "  Loading $folder..." -ForegroundColor Gray
        $folderPath = Join-Path $scriptDir $folder
        if (-not (Test-Path $folderPath)) { 
            Write-Host "  ✗ Folder not found: $folder" -ForegroundColor Red
            continue 
        }
        
        $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | 
            Where-Object { -not $_.Name.EndsWith('.backup') -and -not $_.Name.EndsWith('.old') } |
            Sort-Object Name
        
        foreach ($file in $files) {
            try {
                . $file.FullName
            } catch {
                Write-Host "  ✗ Failed to load $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
        Write-Host "  ✓ $folder loaded successfully" -ForegroundColor Green
    }
    
    # Test 3: Create service container
    Write-Host "Test 3: Creating service container..." -ForegroundColor Cyan
    $container = [ServiceContainer]::new()
    Write-Host "✓ Service container created" -ForegroundColor Green
    
    # Test 4: Register logger
    Write-Host "Test 4: Registering logger..." -ForegroundColor Cyan
    $isWindowsOS = [System.Environment]::OSVersion.Platform -eq 'Win32NT'
    if ($isWindowsOS) {
        $logPath = Join-Path $env:TEMP "axiom-phoenix.log"
    } else {
        $userHome = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        if ([string]::IsNullOrEmpty($userHome)) {
            $userHome = $env:HOME
        }
        $logDir = Join-Path $userHome ".local/share/AxiomPhoenix"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $logPath = Join-Path $logDir "axiom-phoenix.log"
    }
    
    $logger = [Logger]::new($logPath)
    $logger.EnableFileLogging = $true
    $logger.MinimumLevel = if ($Debug.IsPresent) { "Debug" } else { "Info" }
    $logger.EnableConsoleLogging = $false
    $container.Register("Logger", $logger)
    Write-Host "✓ Logger registered" -ForegroundColor Green
    
    # Test 5: Register other services
    Write-Host "Test 5: Registering other services..." -ForegroundColor Cyan
    $container.Register("EventManager", [EventManager]::new())
    $container.Register("ThemeManager", [ThemeManager]::new())
    $container.Register("NavigationService", [NavigationService]::new($container))
    Write-Host "✓ Services registered" -ForegroundColor Green
    
    # Test 6: Initialize global state
    Write-Host "Test 6: Initializing global state..." -ForegroundColor Cyan
    $global:TuiState = @{
        ServiceContainer = $container
        Services = @{
            Logger = $container.GetService("Logger")
            EventManager = $container.GetService("EventManager") 
            ThemeManager = $container.GetService("ThemeManager")
            NavigationService = $container.GetService("NavigationService")
        }
    }
    Write-Host "✓ Global state initialized" -ForegroundColor Green
    
    # Test 7: Create dashboard screen
    Write-Host "Test 7: Creating dashboard screen..." -ForegroundColor Cyan
    $dashboardScreen = [DashboardScreen]::new($container)
    Write-Host "✓ Dashboard screen created" -ForegroundColor Green
    
    # Test 8: Initialize dashboard
    Write-Host "Test 8: Initializing dashboard..." -ForegroundColor Cyan
    $dashboardScreen.Initialize()
    Write-Host "✓ Dashboard initialized" -ForegroundColor Green
    
    Write-Host "All tests passed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "STACK: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    exit 1
}