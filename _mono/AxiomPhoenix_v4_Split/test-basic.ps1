#!/usr/bin/env pwsh
# ==============================================================================
# Axiom-Phoenix v4.0 - Basic Pre-flight Test
# Tests basic loading and class instantiation without running the full TUI
# ==============================================================================

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "=== Axiom-Phoenix v4.0 Pre-flight Test ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Initialize scriptDir
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Get-Location
    }
    
    Write-Host "✓ Script directory: $scriptDir" -ForegroundColor Green
    
    # Test 1: Load file logger first
    Write-Host "1. Testing file logger..." -ForegroundColor Yellow
    $fileLoggerPath = Join-Path $scriptDir "Functions\AFU.006a_FileLogger.ps1"
    if (Test-Path $fileLoggerPath) {
        . $fileLoggerPath
        Write-Host "   ✓ File logger loaded" -ForegroundColor Green
    } else {
        Write-Host "   ✗ File logger not found" -ForegroundColor Red
        return
    }
    
    # Test 2: Load framework files in order
    $loadOrder = @("Base", "Models", "Functions", "Components", "Screens", "Services", "Runtime")
    
    foreach ($folder in $loadOrder) {
        Write-Host "2. Testing $folder..." -ForegroundColor Yellow
        $folderPath = Join-Path $scriptDir $folder
        
        if (-not (Test-Path $folderPath)) {
            Write-Host "   ✗ Folder not found: $folder" -ForegroundColor Red
            continue
        }
        
        $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | 
            Where-Object { -not $_.Name.EndsWith('.backup') -and -not $_.Name.EndsWith('.old') } |
            Sort-Object Name
            
        $loadedCount = 0
        foreach ($file in $files) {
            try {
                if ($Verbose) { 
                    Write-Host "   Loading $($file.Name)..." -ForegroundColor Gray 
                }
                . $file.FullName
                $loadedCount++
            } catch {
                Write-Host "   ✗ Failed to load $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
        
        Write-Host "   ✓ Loaded $loadedCount files from $folder" -ForegroundColor Green
    }
    
    # Test 3: Test key class instantiation
    Write-Host "3. Testing class instantiation..." -ForegroundColor Yellow
    
    # Test ServiceContainer
    try {
        $container = [ServiceContainer]::new()
        Write-Host "   ✓ ServiceContainer instantiated" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ ServiceContainer failed: $_" -ForegroundColor Red
        throw
    }
    
    # Test PmcProject
    try {
        $project = [PmcProject]::new("TEST-001", "Test Project")
        $project.Contact = "Test Contact"
        $project.ContactPhone = "555-1234"
        $project.Category = "Testing"
        Write-Host "   ✓ PmcProject with enhanced fields instantiated" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ PmcProject failed: $_" -ForegroundColor Red
        throw
    }
    
    # Test TimeEntry with ID1
    try {
        $timeEntry = [TimeEntry]::new("TEST-ID1", [DateTime]::Now, "Test activity", [BillingType]::Administrative)
        if ($timeEntry.IsID1Entry()) {
            Write-Host "   ✓ TimeEntry with ID1 support instantiated" -ForegroundColor Green
        } else {
            Write-Host "   ✗ TimeEntry ID1 support not working" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ✗ TimeEntry with ID1 failed: $_" -ForegroundColor Red
        throw
    }
    
    # Test StoredCommand
    try {
        $command = [StoredCommand]::new("test", "Get-Process", "Test command")
        Write-Host "   ✓ StoredCommand instantiated" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ StoredCommand failed: $_" -ForegroundColor Red
        throw
    }
    
    # Test 4: Test service registration
    Write-Host "4. Testing service registration..." -ForegroundColor Yellow
    
    try {
        # Register Logger
        $logPath = Join-Path $PWD "test.log"
        $logger = [Logger]::new($logPath)
        $logger.EnableFileLogging = $false
        $logger.EnableConsoleLogging = $false
        $container.Register("Logger", $logger)
        
        # Register EventManager
        $container.Register("EventManager", [EventManager]::new())
        
        # Register DataManager
        $dataPath = Join-Path $PWD "test-data.json"
        $container.Register("DataManager", [DataManager]::new($dataPath, $container.GetService("EventManager")))
        
        # Register CommandService
        $container.Register("CommandService", [CommandService]::new($container.GetService("DataManager"), $container.GetService("EventManager")))
        
        Write-Host "   ✓ Core services registered successfully" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Service registration failed: $_" -ForegroundColor Red
        throw
    }
    
    # Test 5: Test screen instantiation (without initialization)
    Write-Host "5. Testing screen instantiation..." -ForegroundColor Yellow
    
    try {
        $dashboardScreen = [DashboardScreen]::new($container)
        Write-Host "   ✓ DashboardScreen instantiated" -ForegroundColor Green
        
        $projectDashboardScreen = [ProjectDashboardScreen]::new($container)
        Write-Host "   ✓ ProjectDashboardScreen instantiated" -ForegroundColor Green
        
        $projectDetailScreen = [ProjectDetailScreen]::new($container, $project)
        Write-Host "   ✓ ProjectDetailScreen instantiated" -ForegroundColor Green
        
        $commandPaletteScreen = [CommandPaletteScreen]::new($container)
        Write-Host "   ✓ CommandPaletteScreen instantiated" -ForegroundColor Green
        
    } catch {
        Write-Host "   ✗ Screen instantiation failed: $_" -ForegroundColor Red
        throw
    }
    
    Write-Host ""
    Write-Host "=== ALL TESTS PASSED ===" -ForegroundColor Green
    Write-Host "The framework should be ready to run with './Start.ps1'" -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "=== TEST FAILED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please fix the issues above before running the full application." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}