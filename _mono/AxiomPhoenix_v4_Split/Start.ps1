# ==============================================================================
# Axiom-Phoenix v4.0 - Application Startup (Generated from Split Structure)
# This script loads the framework from its organized file structure.
# ==============================================================================

param(
    [string]$Theme = "Synthwave",
    [switch]$Debug
)

# Set error action preference
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($env:AXIOM_VERBOSE -eq '1') { 'Continue' } else { 'SilentlyContinue' }
$WarningPreference = $VerbosePreference

try {
    Write-Host "Loading Axiom-Phoenix v4.0 (Split Architecture)..." -ForegroundColor Cyan
    
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Get-Location
    }

    # Define the correct loading order for the framework directories
    $loadOrder = @(
        "Base",
        "Models", 
        "Functions",
        "Components",
        "Screens",
        "Services",
        "Runtime"
    )

    # Load all framework files in the correct order
    foreach ($folder in $loadOrder) {
        $folderPath = Join-Path $scriptDir $folder
        if (-not (Test-Path $folderPath)) { 
            Write-Warning "Folder not found: $folder"
            continue 
        }

        Write-Host "Loading $folder..." -ForegroundColor Gray
        $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | Sort-Object Name
        foreach ($file in $files) {
            Write-Verbose "  - Dot-sourcing $($file.Name)"
            try {
                . $file.FullName
            } catch {
                Write-Error "Failed to load $($file.Name): $($_.Exception.Message)"
                throw
            }
        }
    }

    Write-Host "`nFramework loaded successfully!`n" -ForegroundColor Green

    # Service container setup and application startup
    Write-Host "Initializing services..." -ForegroundColor Cyan
    $container = [ServiceContainer]::new()
    
    # Register core services
    Write-Host "  • Registering Logger..." -ForegroundColor Gray
    $container.Register("Logger", [Logger]::new((Join-Path $env:TEMP "axiom-phoenix.log")))
    
    Write-Host "  • Registering EventManager..." -ForegroundColor Gray  
    $container.Register("EventManager", [EventManager]::new())
    
    Write-Host "  • Registering ThemeManager..." -ForegroundColor Gray
    $container.Register("ThemeManager", [ThemeManager]::new())
    
    Write-Host "  • Registering DataManager..." -ForegroundColor Gray
    $container.Register("DataManager", [DataManager]::new((Join-Path $env:TEMP "axiom-data.json"), $container.GetService("EventManager")))
    
    Write-Host "  • Registering ActionService..." -ForegroundColor Gray
    $container.Register("ActionService", [ActionService]::new($container.GetService("EventManager")))
    
    Write-Host "  • Registering KeybindingService..." -ForegroundColor Gray
    $container.Register("KeybindingService", [KeybindingService]::new($container.GetService("ActionService")))
    
    Write-Host "  • Registering NavigationService..." -ForegroundColor Gray
    $container.Register("NavigationService", [NavigationService]::new($container))
    
    Write-Host "  • Registering DialogManager..." -ForegroundColor Gray
    $container.Register("DialogManager", [DialogManager]::new($container))
    
    Write-Host "  • Registering ViewDefinitionService..." -ForegroundColor Gray
    $container.Register("ViewDefinitionService", [ViewDefinitionService]::new())
    
    Write-Host "  • Registering FileSystemService..." -ForegroundColor Gray
    $container.Register("FileSystemService", [FileSystemService]::new($container.GetService("Logger")))
    
    Write-Host "Services initialized successfully!" -ForegroundColor Green

    # Initialize global state
    $global:TuiState.ServiceContainer = $container
    $global:TuiState.Services = @{
        Logger = $container.GetService("Logger")
        EventManager = $container.GetService("EventManager") 
        ThemeManager = $container.GetService("ThemeManager")
        DataManager = $container.GetService("DataManager")
        ActionService = $container.GetService("ActionService")
        KeybindingService = $container.GetService("KeybindingService")
        NavigationService = $container.GetService("NavigationService")
        DialogManager = $container.GetService("DialogManager")
        ViewDefinitionService = $container.GetService("ViewDefinitionService")
        FileSystemService = $container.GetService("FileSystemService")
    }
    $global:TuiState.ServiceContainer = $container

    # Apply theme and register default actions
    $themeManager = $container.GetService("ThemeManager")
    if ($themeManager -and $Theme) { 
        $themeManager.LoadTheme($Theme)
        Write-Host "Theme '$Theme' activated!" -ForegroundColor Magenta 
    }
    
    $actionService = $container.GetService("ActionService")
    if ($actionService) { 
        $actionService.RegisterDefaultActions()
        Write-Host "Default actions registered!" -ForegroundColor Green 
    }

    # Create sample data
    Write-Host "Generating sample data..." -ForegroundColor Cyan
    $dataManager = $container.GetService("DataManager")
    
    # Create sample projects first
    $project1 = [PmcProject]::new("PROJ-001", "Phoenix CRM System")
    $project1.Description = "Complete CRM system rewrite using modern architecture patterns. This project involves migrating legacy systems to a cloud-native solution with microservices."
    $project1.Owner = "Sarah Chen"
    $project1.ID1 = "CRM-2024-A"
    $project1.ID2 = "MAIN-CRM-001"
    $project1.AssignedDate = (Get-Date).AddDays(-45)
    $project1.BFDate = (Get-Date).AddDays(30)
    $project1.SetMetadata("ClientID", "BN-789456")
    $project1.SetMetadata("Budget", "$450,000")
    $project1.SetMetadata("Phase", "Development")
    
    # Create project folder
    $projectsBasePath = Join-Path $env:TEMP "AxiomPhoenix_Projects"
    $project1FolderPath = Join-Path $projectsBasePath "PROJ-001_Phoenix_CRM_System"
    if (-not (Test-Path $project1FolderPath)) {
        New-Item -ItemType Directory -Path $project1FolderPath -Force | Out-Null
    }
    $project1.ProjectFolderPath = $project1FolderPath
    # Create sample files
    Set-Content -Path (Join-Path $project1FolderPath "CRM_Requirements_v2.docx") -Value "Requirements document" -Force
    Set-Content -Path (Join-Path $project1FolderPath "Architecture_Diagram.pdf") -Value "Architecture diagram" -Force
    Set-Content -Path (Join-Path $project1FolderPath "Development_Timeline.xlsx") -Value "Timeline spreadsheet" -Force
    $project1.CaaFileName = "CRM_Requirements_v2.docx"
    $project1.RequestFileName = "Architecture_Diagram.pdf"
    $project1.T2020FileName = "Development_Timeline.xlsx"
    $dataManager.AddProject($project1)
    
    $project2 = [PmcProject]::new("PROJ-002", "Mobile App Redesign")
    $project2.Description = "Complete UI/UX overhaul of the mobile application to improve user engagement and modernize the interface."
    $project2.Owner = "Michael Torres"
    $project2.ID1 = "MOB-2024-B"
    $project2.ID2 = "MAIN-MOB-002"
    $project2.AssignedDate = (Get-Date).AddDays(-20)
    $project2.BFDate = (Get-Date).AddDays(-5)  # Overdue
    $project2.SetMetadata("ClientID", "BN-456123")
    $project2.SetMetadata("Platform", "iOS/Android")
    
    $project2FolderPath = Join-Path $projectsBasePath "PROJ-002_Mobile_App_Redesign"
    if (-not (Test-Path $project2FolderPath)) {
        New-Item -ItemType Directory -Path $project2FolderPath -Force | Out-Null
    }
    $project2.ProjectFolderPath = $project2FolderPath
    # Create sample files
    Set-Content -Path (Join-Path $project2FolderPath "UI_Mockups.pdf") -Value "UI mockups" -Force
    Set-Content -Path (Join-Path $project2FolderPath "User_Research.docx") -Value "User research" -Force
    Set-Content -Path (Join-Path $project2FolderPath "Budget_Estimate.xlsx") -Value "Budget estimate" -Force
    $project2.CaaFileName = "UI_Mockups.pdf"
    $project2.RequestFileName = "User_Research.docx"
    $dataManager.AddProject($project2)
    
    $project3 = [PmcProject]::new("PROJ-003", "Data Analytics Platform")
    $project3.Description = "Build a comprehensive data analytics platform with real-time dashboards and predictive analytics capabilities."
    $project3.Owner = "Dr. Emily Watson"
    $project3.ID1 = "DATA-2024-C"
    $project3.ID2 = "MAIN-DATA-003"
    $project3.AssignedDate = (Get-Date).AddDays(-90)
    $project3.BFDate = (Get-Date).AddDays(60)
    $project3.SetMetadata("ClientID", "BN-321789")
    $project3.SetMetadata("Technology", "PowerBI, Azure ML")
    $project3.IsActive = $false  # Archived project
    
    $project3FolderPath = Join-Path $projectsBasePath "PROJ-003_Data_Analytics_Platform"
    if (-not (Test-Path $project3FolderPath)) {
        New-Item -ItemType Directory -Path $project3FolderPath -Force | Out-Null
    }
    $project3.ProjectFolderPath = $project3FolderPath
    $dataManager.AddProject($project3)
    
    $project4 = [PmcProject]::new("PROJ-004", "Security Audit 2024")
    $project4.Description = "Annual security audit and penetration testing for all client-facing applications and infrastructure."
    $project4.Owner = "James Mitchell"
    $project4.ID1 = "SEC-2024-D"
    $project4.ID2 = "MAIN-SEC-004"
    $project4.AssignedDate = (Get-Date).AddDays(-10)
    $project4.BFDate = (Get-Date).AddDays(7)
    $project4.SetMetadata("ClientID", "BN-654987")
    $project4.SetMetadata("Compliance", "SOC2, ISO27001")
    
    $project4FolderPath = Join-Path $projectsBasePath "PROJ-004_Security_Audit_2024"
    if (-not (Test-Path $project4FolderPath)) {
        New-Item -ItemType Directory -Path $project4FolderPath -Force | Out-Null
    }
    $project4.ProjectFolderPath = $project4FolderPath
    $dataManager.AddProject($project4)
    
    # Create sample tasks
    $sampleTasks = @()
    
    $task1 = [PmcTask]::new("Review project requirements")
    $task1.Status = [TaskStatus]::Pending
    $task1.Priority = [TaskPriority]::High
    $task1.ProjectKey = "PROJ-001"  # Assign to Phoenix CRM
    $sampleTasks += $task1
    
    $task2 = [PmcTask]::new("Design system architecture")
    $task2.Status = [TaskStatus]::InProgress
    $task2.Priority = [TaskPriority]::High
    $task2.SetProgress(30)
    $task2.ProjectKey = "PROJ-001"  # Assign to Phoenix CRM
    $task2.DueDate = (Get-Date).AddDays(14)
    $sampleTasks += $task2
    
    $task3 = [PmcTask]::new("Implement core features")
    $task3.Status = [TaskStatus]::InProgress
    $task3.Priority = [TaskPriority]::Medium
    $task3.SetProgress(60)
    $task3.ProjectKey = "PROJ-001"  # Assign to Phoenix CRM
    $sampleTasks += $task3
    
    $task4 = [PmcTask]::new("Fix responsive design issues")
    $task4.Status = [TaskStatus]::Completed
    $task4.Priority = [TaskPriority]::High
    $task4.ProjectKey = "PROJ-002"  # Assign to Mobile App
    $task4.SetProgress(100)
    $sampleTasks += $task4
    
    $task5 = [PmcTask]::new("Conduct penetration testing")
    $task5.Status = [TaskStatus]::Pending
    $task5.Priority = [TaskPriority]::High
    $task5.ProjectKey = "PROJ-004"  # Assign to Security Audit
    $task5.DueDate = (Get-Date).AddDays(5)
    $sampleTasks += $task5
    
    $task6 = [PmcTask]::new("Update mobile UI components")
    $task6.Status = [TaskStatus]::InProgress
    $task6.Priority = [TaskPriority]::Medium
    $task6.SetProgress(25)
    $task6.ProjectKey = "PROJ-002"  # Assign to Mobile App
    $sampleTasks += $task6
    
    foreach ($task in $sampleTasks) {
        $dataManager.AddTask($task)
    }
    
    Write-Host "Sample data created: $($dataManager.GetProjects().Count) projects, $($dataManager.GetTasks().Count) tasks" -ForegroundColor Green

    # Launch the application
    Write-Host "`nStarting Axiom-Phoenix v4.0..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+P to open command palette, Ctrl+Q to quit" -ForegroundColor Yellow
    Write-Host "Press 3 from Dashboard to view Projects (full CRUD support)" -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    
    $dashboardScreen = [DashboardScreen]::new($container)
    Write-Host "Initializing Dashboard screen..." -ForegroundColor Yellow
    $dashboardScreen.Initialize()
    
    # Ensure theme is applied after services are available
    Write-Host "Applying theme to dashboard..." -ForegroundColor Yellow
    if ($dashboardScreen -and [bool]($dashboardScreen | Get-Member -Name "RefreshThemeColors" -MemberType Method)) {
        $dashboardScreen.RefreshThemeColors()
    }
    
    Write-Host "Dashboard initialized. Starting engine..." -ForegroundColor Yellow
    Clear-Host
    Start-AxiomPhoenix -ServiceContainer $container -InitialScreen $dashboardScreen

} catch {
    Write-Host "`nCRITICAL ERROR! Failed to start framework." -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
