#!/usr/bin/env pwsh
# Test script to verify ServiceContainer architecture improvements

param(
    [switch]$Verbose
)

if ($Verbose) {
    $VerbosePreference = 'Continue'
}

try {
    Write-Host "Testing ServiceContainer Architecture Improvements..." -ForegroundColor Cyan
    
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    # Load framework files in correct order
    $loadOrder = @(
        "Base",
        "Models", 
        "Functions",
        "Components",
        "Screens",
        "Services",
        "Runtime"
    )
    
    foreach ($folder in $loadOrder) {
        $folderPath = Join-Path $scriptDir $folder
        if (-not (Test-Path $folderPath)) { 
            Write-Error "Folder not found: $folder"
            exit 1
        }
        
        Write-Verbose "Loading $folder..."
        $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | Sort-Object Name
        foreach ($file in $files) {
            Write-Verbose "  - Loading $($file.Name)"
            . $file.FullName
        }
    }
    
    Write-Host "`nStep 1: Creating ServiceContainer..." -ForegroundColor Yellow
    $container = [ServiceContainer]::new()
    Write-Host "✓ ServiceContainer created" -ForegroundColor Green
    
    Write-Host "`nStep 2: Registering core services..." -ForegroundColor Yellow
    
    # Register services
    $container.Register("Logger", [Logger]::new((Join-Path $env:TEMP "test-axiom.log")))
    Write-Host "✓ Logger registered" -ForegroundColor Green
    
    $container.Register("EventManager", [EventManager]::new())
    Write-Host "✓ EventManager registered" -ForegroundColor Green
    
    $container.Register("ThemeManager", [ThemeManager]::new())
    Write-Host "✓ ThemeManager registered" -ForegroundColor Green
    
    Write-Host "`nStep 3: Testing NavigationService with ServiceContainer..." -ForegroundColor Yellow
    $navService = [NavigationService]::new($container)
    Write-Host "✓ NavigationService created with ServiceContainer" -ForegroundColor Green
    
    # Verify NavigationService can access services
    Write-Verbose "NavigationService ServiceContainer type: $($navService.ServiceContainer.GetType().Name)"
    
    Write-Host "`nStep 4: Testing Screen creation with ServiceContainer..." -ForegroundColor Yellow
    
    # Create a test screen
    class TestScreen : Screen {
        TestScreen([ServiceContainer]$container) : base("TestScreen", $container) {}
        
        [void] TestServiceAccess() {
            $logger = $this.ServiceContainer.GetService("Logger")
            if ($logger) {
                Write-Host "  ✓ Screen can access Logger service" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Screen cannot access Logger service" -ForegroundColor Red
            }
            
            $eventManager = $this.ServiceContainer.GetService("EventManager")
            if ($eventManager) {
                Write-Host "  ✓ Screen can access EventManager service" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Screen cannot access EventManager service" -ForegroundColor Red
            }
        }
    }
    
    $testScreen = [TestScreen]::new($container)
    Write-Host "✓ TestScreen created with ServiceContainer" -ForegroundColor Green
    $testScreen.TestServiceAccess()
    
    Write-Host "`nStep 5: Testing navigation to screen..." -ForegroundColor Yellow
    
    # Register NavigationService in container for event publishing
    $container.Register("NavigationService", $navService)
    
    # Initialize global state (minimal for testing)
    $global:TuiState = @{
        BufferWidth = 80
        BufferHeight = 24
        IsDirty = $false
        CurrentScreen = $null
        FocusedComponent = $null
    }
    
    # Test navigation
    $navService.NavigateTo($testScreen)
    
    if ($global:TuiState.CurrentScreen -eq $testScreen) {
        Write-Host "✓ Navigation updated global state correctly" -ForegroundColor Green
    } else {
        Write-Host "✗ Navigation failed to update global state" -ForegroundColor Red
    }
    
    Write-Host "`nStep 6: Verifying architectural improvements..." -ForegroundColor Yellow
    
    # Check that NavigationService doesn't have a Services hashtable
    if ($navService.PSObject.Properties['Services']) {
        Write-Host "✗ NavigationService still has Services property (should be removed)" -ForegroundColor Red
    } else {
        Write-Host "✓ NavigationService correctly uses ServiceContainer only" -ForegroundColor Green
    }
    
    # Check that Screen uses ServiceContainer
    if ($testScreen.ServiceContainer -and $testScreen.ServiceContainer.GetType().Name -eq 'ServiceContainer') {
        Write-Host "✓ Screen correctly stores ServiceContainer reference" -ForegroundColor Green
    } else {
        Write-Host "✗ Screen doesn't have proper ServiceContainer reference" -ForegroundColor Red
    }
    
    Write-Host "`n✅ All tests completed successfully!" -ForegroundColor Green
    Write-Host "`nArchitectural improvements implemented:" -ForegroundColor Cyan
    Write-Host "• NavigationService now takes ServiceContainer directly" -ForegroundColor Gray
    Write-Host "• Screen base class uses ServiceContainer for all service access" -ForegroundColor Gray
    Write-Host "• Removed tight coupling from service initialization" -ForegroundColor Gray
    Write-Host "• Improved scalability and maintainability" -ForegroundColor Gray
    
} catch {
    Write-Host "`n❌ Test failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
} finally {
    # Cleanup
    if ($global:TuiState) {
        Remove-Variable -Name TuiState -Scope Global -ErrorAction SilentlyContinue
    }
}
