try {
    Write-Host "`n=== PMC Terminal v5 - Starting (Classy Loader) ===" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    
    # Initialize core services that have no dependencies
    Write-Host "`nInitializing services..." -ForegroundColor Yellow
    Initialize-Logger -Level $(if ($Debug) { "Debug" } else { "Info" })
    Initialize-EventSystem
    Initialize-ThemeManager
    
    # Create the service container
    $services = @{}
    
    # Initialize services that depend on others, passing the container
    $services.KeybindingService = New-KeybindingService
    $services.DataManager = Initialize-DataManager
    
    # Create sample tasks for testing
    Write-Host "Creating sample tasks..." -ForegroundColor Yellow
    try {
        $sampleTasks = @(
            @{Title = "Review project documentation"; Description = "Review and update project documentation"; Priority = "High"; Project = "ProjectA"},
            @{Title = "Fix critical bug in login system"; Description = "Address authentication issues"; Priority = "Critical"; Project = "ProjectB"},
            @{Title = "Implement new feature"; Description = "Add user profile management"; Priority = "Medium"; Project = "ProjectA"},
            @{Title = "Update dependencies"; Description = "Update all NPM packages"; Priority = "Low"; Project = "ProjectC"},
            @{Title = "Write unit tests"; Description = "Increase test coverage"; Priority = "Medium"; Project = "ProjectB"}
        )
        
        foreach ($taskData in $sampleTasks) {
            $services.DataManager.AddTask($taskData.Title, $taskData.Description, $taskData.Priority, $taskData.Project)
        }
        Write-Host "Sample tasks created successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not create sample tasks: $_" -ForegroundColor Yellow
    }
    
    # NavigationService needs the $services container to pass to screens
    $services.Navigation = Initialize-NavigationService -Services $services
    
    # Register screen classes with the navigation service
    $services.Navigation.RegisterScreenClass("DashboardScreen", [DashboardScreen])
    $services.Navigation.RegisterScreenClass("TaskListScreen", [TaskListScreen])
    
    # Initialize the dialog system
    Initialize-DialogSystem
    
    Write-Host "All services initialized!" -ForegroundColor Green
    
    if (-not $SkipLogo) {
        Write-Host @"
    
    ╔═══════════════════════════════════════╗
    ║      PMC Terminal v5.0                ║
    ║      PowerShell Management Console    ║
    ╚═══════════════════════════════════════╝
    
"@ -ForegroundColor Cyan
    }
    
    # Initialize the TUI Engine which orchestrates the UI
    Write-Host "Starting TUI Engine..." -ForegroundColor Yellow
    Initialize-TuiEngine
    Write-Host "TUI Engine initialized successfully" -ForegroundColor Green
    
    # Create and initialize the first screen
    Write-Host "Creating DashboardScreen..." -ForegroundColor Yellow
    $dashboard = [DashboardScreen]::new($services)
    Write-Host "DashboardScreen created, initializing..." -ForegroundColor Yellow
    $dashboard.Initialize()
    Write-Host "DashboardScreen initialized successfully" -ForegroundColor Green
    
    # Push the screen to the engine and start the main loop
    Write-Host "Pushing screen to TUI engine..." -ForegroundColor Yellow
    Push-Screen -Screen $dashboard
    Write-Host "Screen pushed, starting main loop..." -ForegroundColor Yellow
    
    # Force an initial refresh to ensure rendering
    $global:TuiState.IsDirty = $true
    
    Start-TuiLoop
    
} catch {
    Write-Host "`n=== FATAL ERROR ===" -ForegroundColor Red
    Write-Host "An error occurred during application startup."
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor DarkRed
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    if ($Host.UI.RawUI) {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    exit 1
} finally {
    # Cleanup logic if needed
    Pop-Location -ErrorAction SilentlyContinue
   
}
