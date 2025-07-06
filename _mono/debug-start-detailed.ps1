# Debug startup script with detailed error tracing
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    # Set location
    Set-Location $PSScriptRoot
    
    Write-Host "Loading framework files..." -ForegroundColor Cyan
    
    # Load in dependency order
    . .\AllBaseClasses.ps1
    Write-Host "✓ AllBaseClasses.ps1 loaded" -ForegroundColor Green
    
    . .\AllModels.ps1
    Write-Host "✓ AllModels.ps1 loaded" -ForegroundColor Green
    
    . .\AllComponents.ps1
    Write-Host "✓ AllComponents.ps1 loaded" -ForegroundColor Green
    
    . .\AllScreens.ps1
    Write-Host "✓ AllScreens.ps1 loaded" -ForegroundColor Green
    
    . .\AllFunctions.ps1
    Write-Host "✓ AllFunctions.ps1 loaded" -ForegroundColor Green
    
    . .\AllServices.ps1
    Write-Host "✓ AllServices.ps1 loaded" -ForegroundColor Green
    
    . .\AllRuntime.ps1
    Write-Host "✓ AllRuntime.ps1 loaded" -ForegroundColor Green
    
    Write-Host "`nInitializing services..." -ForegroundColor Cyan
    
    # Create service container
    $container = [ServiceContainer]::new()
    
    # Register services
    $container.Register("Logger", [Logger]::new())
    $container.Register("ThemeManager", [ThemeManager]::new())
    $container.Register("EventManager", [EventManager]::new())
    $container.Register("DataManager", [DataManager]::new())
    $container.Register("ActionService", [ActionService]::new())
    $container.Register("KeybindingService", [KeybindingService]::new())
    $container.Register("NavigationService", [NavigationService]::new())
    
    Write-Host "✓ Services registered" -ForegroundColor Green
    
    # Initialize theme
    $themeManager = $container.GetService("ThemeManager")
    $themeManager.LoadDefaultTheme()
    
    # Create dashboard
    Write-Host "`nCreating dashboard screen..." -ForegroundColor Cyan
    $dashboardScreen = [DashboardScreen]::new($container)
    Write-Host "✓ Dashboard created" -ForegroundColor Green
    
    # Start with detailed error catching
    Write-Host "`nStarting application..." -ForegroundColor Cyan
    
    # Override Process-TuiInput temporarily for debugging
    $originalProcessInput = Get-Command Process-TuiInput
    function Process-TuiInput {
        [CmdletBinding()]
        param()
        
        try {
            Write-Host "DEBUG: Process-TuiInput called" -ForegroundColor Yellow
            
            if ([Console]::KeyAvailable) {
                $keyInfo = [Console]::ReadKey($true)
                Write-Host "DEBUG: Key pressed: $($keyInfo.Key)" -ForegroundColor Yellow
                
                # Check command palette first
                if ($global:TuiState.CommandPalette -and $global:TuiState.CommandPalette.Visible) {
                    Write-Host "DEBUG: Passing to CommandPalette" -ForegroundColor Yellow
                    $handled = $global:TuiState.CommandPalette.HandleInput($keyInfo)
                    if ($handled) {
                        $global:TuiState.IsDirty = $true
                        return
                    }
                }
                
                # Pass to current screen
                if ($global:TuiState.CurrentScreen) {
                    Write-Host "DEBUG: Passing to CurrentScreen: $($global:TuiState.CurrentScreen.GetType().Name)" -ForegroundColor Yellow
                    
                    # Check if HandleInput exists
                    if ($global:TuiState.CurrentScreen.PSObject.Methods['HandleInput']) {
                        Write-Host "DEBUG: HandleInput method exists" -ForegroundColor Yellow
                        $global:TuiState.CurrentScreen.HandleInput($keyInfo)
                    } else {
                        Write-Host "DEBUG: HandleInput method NOT FOUND!" -ForegroundColor Red
                    }
                    
                    $global:TuiState.IsDirty = $true
                }
            }
        }
        catch {
            Write-Host "DEBUG ERROR in Process-TuiInput:" -ForegroundColor Red
            Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "  Target: $($_.Exception.TargetSite)" -ForegroundColor Red
            Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
            
            # Check for property access errors
            if ($_.Exception.Message -like "*property*cannot be found*") {
                Write-Host "  Property Access Error Detected!" -ForegroundColor Magenta
                Write-Host "  Attempting to access: $($_.Exception.Message -replace '.*property ''(.*)'' cannot.*', '$1')" -ForegroundColor Magenta
            }
            
            throw
        }
    }
    
    Start-AxiomPhoenix -ServiceContainer $container -InitialScreen $dashboardScreen
}
catch {
    Write-Host "`nDETAILED ERROR INFORMATION:" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "ScriptStackTrace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    Write-Host "`nInvocationInfo:" -ForegroundColor Red
    Write-Host "  Line: $($_.InvocationInfo.Line)" -ForegroundColor Gray
    Write-Host "  ScriptLineNumber: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    Write-Host "  ScriptName: $($_.InvocationInfo.ScriptName)" -ForegroundColor Gray
    Write-Host "  PositionMessage: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Gray
    
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
