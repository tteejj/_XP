# Simple test runner
$ErrorActionPreference = 'Stop'

try {
    Set-Location $PSScriptRoot
    
    # Load all files
    . .\AllBaseClasses.ps1
    . .\AllModels.ps1
    . .\AllComponents.ps1
    . .\AllScreens.ps1
    . .\AllFunctions.ps1
    . .\AllServices.ps1
    . .\AllRuntime.ps1
    
    # Create services
    $container = [ServiceContainer]::new()
    $container.Register("Logger", [Logger]::new())
    $container.Register("ThemeManager", [ThemeManager]::new())
    $container.Register("EventManager", [EventManager]::new())
    $container.Register("DataManager", [DataManager]::new())
    $container.Register("ActionService", [ActionService]::new())
    $container.Register("KeybindingService", [KeybindingService]::new())
    $container.Register("NavigationService", [NavigationService]::new())
    
    # Initialize theme
    $themeManager = $container.GetService("ThemeManager")
    $themeManager.LoadDefaultTheme()
    
    # Create and start application
    $dashboardScreen = [DashboardScreen]::new($container)
    Start-AxiomPhoenix -ServiceContainer $container -InitialScreen $dashboardScreen
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Gray
    Read-Host "Press Enter to exit"
}
