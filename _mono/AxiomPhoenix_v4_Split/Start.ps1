#!/usr/bin/env pwsh
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

# Initialize scriptDir FIRST
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = Get-Location
}

try {
    # Load the file logger FIRST before any other logging
    $fileLoggerPath = Join-Path $scriptDir "Functions\AFU.006a_FileLogger.ps1"
    if (Test-Path $fileLoggerPath) {
        . $fileLoggerPath
        Write-Host "File logger initialized. Log file: $global:AxiomPhoenixLogFile" -ForegroundColor Yellow
    }
    
    Write-Host "Loading Axiom-Phoenix v4.0 (Split Architecture)..." -ForegroundColor Cyan

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
        $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | 
            Where-Object { -not $_.Name.EndsWith('.backup') -and -not $_.Name.EndsWith('.old') } |
            Sort-Object Name
        foreach ($file in $files) {
            Write-Verbose "  - Dot-sourcing $($file.FullName)"
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
    # Cross-platform log path
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
    
    # --- PERFORMANCE CONTROL SWITCH ---
    if ($Debug.IsPresent) {
        $logger.MinimumLevel = "Debug"
        Write-Host "DEBUG logging enabled. Performance will be impacted." -ForegroundColor Yellow
    } else {
        $logger.MinimumLevel = "Warning" # Default to high-performance mode
    }
    # --- END OF SWITCH ---
    
    $logger.EnableConsoleLogging = $false  # Never enable console logging in TUI apps
    $container.Register("Logger", $logger)
    
    # Write initial log entry
    $logger.Log("Axiom-Phoenix v4.0 starting up at $(Get-Date)", "Info")
    
    Write-Host "  • Registering EventManager..." -ForegroundColor Gray  
    $container.Register("EventManager", [EventManager]::new())
    
    Write-Host "  • Registering ThemeManager..." -ForegroundColor Gray
    $container.Register("ThemeManager", [ThemeManager]::new())
    
    Write-Host "  • Registering DataManager..." -ForegroundColor Gray
    # Cross-platform data path
    if ($isWindowsOS) {
        $dataPath = Join-Path $env:TEMP "axiom-data.json"
    } else {
        $dataPath = Join-Path $logDir "axiom-data.json"
    }
    $container.Register("DataManager", [DataManager]::new($dataPath, $container.GetService("EventManager")))
    
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
    
    Write-Host "  • Registering TimeSheetService..." -ForegroundColor Gray
    $container.Register("TimeSheetService", [TimeSheetService]::new($container.GetService("DataManager"), $container.GetService("EventManager")))
    
    Write-Host "  • Registering CommandService..." -ForegroundColor Gray
    $container.Register("CommandService", [CommandService]::new($container.GetService("DataManager"), $container.GetService("EventManager")))
    
    Write-Host "Services initialized successfully!" -ForegroundColor Green

    # Initialize global state (CRITICAL FIX)
    $global:TuiState = @{
        ServiceContainer = $container
        Services = @{
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
            TimeSheetService = $container.GetService("TimeSheetService")
            CommandService = $container.GetService("CommandService")
        }
    }

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
    $project1.Contact = "Alice Johnson"
    $project1.ContactPhone = "(555) 123-4567"
    $project1.Category = "System Integration"
    $project1.AssignedDate = (Get-Date).AddDays(-45)
    $project1.BFDate = (Get-Date).AddDays(30)
    $project1.SetMetadata("ClientID", "BN-789456")
    $project1.SetMetadata("Budget", "$450,000")
    $project1.SetMetadata("Phase", "Development")
    
    # Create project folder (cross-platform)
    if ($isWindowsOS) {
        $projectsBasePath = Join-Path $env:TEMP "AxiomPhoenix_Projects"
    } else {
        $projectsBasePath = Join-Path $userHome "AxiomPhoenix_Projects"
    }
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
    $dataManager.AddProject($project1) | Out-Null
    
    $project2 = [PmcProject]::new("PROJ-002", "Mobile App Redesign")
    $project2.Description = "Complete UI/UX overhaul of the mobile application to improve user engagement and modernize the interface."
    $project2.Owner = "Michael Torres"
    $project2.ID1 = "MOB-2024-B"
    $project2.ID2 = "MAIN-MOB-002"
    $project2.Contact = "Bob Martinez"
    $project2.ContactPhone = "(555) 987-6543"
    $project2.Category = "Mobile Development"
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
    $dataManager.AddProject($project2) | Out-Null
    
    $project3 = [PmcProject]::new("PROJ-003", "Data Analytics Platform")
    $project3.Description = "Build a comprehensive data analytics platform with real-time dashboards and predictive analytics capabilities."
    $project3.Owner = "Dr. Emily Watson"
    $project3.ID1 = "DATA-2024-C"
    $project3.ID2 = "MAIN-DATA-003"
    $project3.Contact = "Dr. Carol Stevens"
    $project3.ContactPhone = "(555) 555-1234"
    $project3.Category = "Data Analytics"
    $project3.AssignedDate = (Get-Date).AddDays(-90)
    $project3.BFDate = (Get-Date).AddDays(60)
    $project3.CompletedDate = (Get-Date).AddDays(-10)  # Recently completed
    $project3.SetMetadata("ClientID", "BN-321789")
    $project3.SetMetadata("Technology", "PowerBI, Azure ML")
    $project3.IsActive = $false  # Archived project
    
    $project3FolderPath = Join-Path $projectsBasePath "PROJ-003_Data_Analytics_Platform"
    if (-not (Test-Path $project3FolderPath)) {
        New-Item -ItemType Directory -Path $project3FolderPath -Force | Out-Null
    }
    $project3.ProjectFolderPath = $project3FolderPath
    $dataManager.AddProject($project3) | Out-Null
    
    $project4 = [PmcProject]::new("PROJ-004", "Security Audit 2024")
    $project4.Description = "Annual security audit and penetration testing for all client-facing applications and infrastructure."
    $project4.Owner = "James Mitchell"
    $project4.ID1 = "SEC-2024-D"
    $project4.ID2 = "MAIN-SEC-004"
    $project4.Contact = "David Kim"
    $project4.ContactPhone = "(555) 789-0123"
    $project4.Category = "Security & Compliance"
    $project4.AssignedDate = (Get-Date).AddDays(-10)
    $project4.BFDate = (Get-Date).AddDays(7)
    $project4.SetMetadata("ClientID", "BN-654987")
    $project4.SetMetadata("Compliance", "SOC2, ISO27001")
    
    $project4FolderPath = Join-Path $projectsBasePath "PROJ-004_Security_Audit_2024"
    if (-not (Test-Path $project4FolderPath)) {
        New-Item -ItemType Directory -Path $project4FolderPath -Force | Out-Null
    }
    $project4.ProjectFolderPath = $project4FolderPath
    $dataManager.AddProject($project4) | Out-Null
    
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
        $dataManager.AddTask($task) | Out-Null
    }
    
    # Create sample time entries for the current week
    Write-Host "Creating sample time entries..." -ForegroundColor Gray
    $timeSheetService = $container.GetService("TimeSheetService")
    $currentWeekStart = $timeSheetService.GetWeekStartDate([DateTime]::Now)
    
    # Time entries for various projects throughout the week
    $sampleTimeEntries = @()
    
    # Monday entries
    $entry1 = [TimeEntry]::new()
    $entry1.ProjectKey = "PROJ-001"
    $entry1.TaskId = $sampleTasks[0].Id  # Database design task
    $entry1.StartTime = $currentWeekStart.AddHours(9)
    $entry1.EndTime = $currentWeekStart.AddHours(12)
    $entry1.Description = "Database schema design and modeling"
    $entry1.BillingType = [BillingType]::Billable
    $entry1.UserId = "CurrentUser"
    $sampleTimeEntries += $entry1
    
    $entry2 = [TimeEntry]::new()
    $entry2.ProjectKey = "PROJ-002"
    $entry2.TaskId = $sampleTasks[5].Id  # Mobile UI task
    $entry2.StartTime = $currentWeekStart.AddHours(13)
    $entry2.EndTime = $currentWeekStart.AddHours(17)
    $entry2.Description = "Mobile UI component refactoring"
    $entry2.BillingType = [BillingType]::Billable
    $entry2.UserId = "CurrentUser"
    $sampleTimeEntries += $entry2
    
    # Tuesday entries
    $entry3 = [TimeEntry]::new()
    $entry3.ProjectKey = "PROJ-001"
    $entry3.TaskId = $sampleTasks[1].Id  # API development
    $entry3.StartTime = $currentWeekStart.AddDays(1).AddHours(9)
    $entry3.EndTime = $currentWeekStart.AddDays(1).AddHours(17)
    $entry3.Description = "REST API development and testing"
    $entry3.BillingType = [BillingType]::Billable
    $entry3.UserId = "CurrentUser"
    $sampleTimeEntries += $entry3
    
    # Wednesday entries
    $entry4 = [TimeEntry]::new()
    $entry4.ProjectKey = "PROJ-003"
    $entry4.TaskId = $sampleTasks[2].Id  # Cloud migration
    $entry4.StartTime = $currentWeekStart.AddDays(2).AddHours(9)
    $entry4.EndTime = $currentWeekStart.AddDays(2).AddHours(15)
    $entry4.Description = "Cloud infrastructure setup and configuration"
    $entry4.BillingType = [BillingType]::Billable
    $entry4.UserId = "CurrentUser"
    $sampleTimeEntries += $entry4
    
    # Administrative/non-billable time
    $entry5 = [TimeEntry]::new()
    $entry5.ProjectKey = "PROJ-001"
    $entry5.StartTime = $currentWeekStart.AddDays(2).AddHours(15)
    $entry5.EndTime = $currentWeekStart.AddDays(2).AddHours(17)
    $entry5.Description = "Team meetings and project planning"
    $entry5.BillingType = [BillingType]::NonBillable
    $entry5.UserId = "CurrentUser"
    $sampleTimeEntries += $entry5
    
    # Thursday entries
    $entry6 = [TimeEntry]::new()
    $entry6.ProjectKey = "PROJ-004"
    $entry6.TaskId = $sampleTasks[4].Id  # Security audit
    $entry6.StartTime = $currentWeekStart.AddDays(3).AddHours(9)
    $entry6.EndTime = $currentWeekStart.AddDays(3).AddHours(13)
    $entry6.Description = "Security vulnerability assessment"
    $entry6.BillingType = [BillingType]::Billable
    $entry6.UserId = "CurrentUser"
    $sampleTimeEntries += $entry6
    
    # Friday entries
    $entry7 = [TimeEntry]::new()
    $entry7.ProjectKey = "PROJ-001"
    $entry7.TaskId = $sampleTasks[0].Id  # Database design follow-up
    $entry7.StartTime = $currentWeekStart.AddDays(4).AddHours(9)
    $entry7.EndTime = $currentWeekStart.AddDays(4).AddHours(12)
    $entry7.Description = "Database optimization and performance tuning"
    $entry7.BillingType = [BillingType]::Billable
    $entry7.UserId = "CurrentUser"
    $sampleTimeEntries += $entry7
    
    # ID1-based (non-project) time entries for administrative work
    $adminEntry1 = [TimeEntry]::new("ADM-MEET", $currentWeekStart.AddDays(1).AddHours(15), "Team standup and sprint planning", [BillingType]::Meeting)
    $adminEntry1.EndTime = $currentWeekStart.AddDays(1).AddHours(16)
    $adminEntry1.UserId = "CurrentUser"
    $sampleTimeEntries += $adminEntry1
    
    $adminEntry2 = [TimeEntry]::new("ADM-TRAIN", $currentWeekStart.AddDays(2).AddHours(8), "PowerShell training course", [BillingType]::Training)
    $adminEntry2.EndTime = $currentWeekStart.AddDays(2).AddHours(10)
    $adminEntry2.UserId = "CurrentUser"
    $sampleTimeEntries += $adminEntry2
    
    $adminEntry3 = [TimeEntry]::new("ADM-ADMIN", $currentWeekStart.AddDays(3).AddHours(14), "Timesheet and expense report submission", [BillingType]::Administrative)
    $adminEntry3.EndTime = $currentWeekStart.AddDays(3).AddHours(15)
    $adminEntry3.UserId = "CurrentUser"
    $sampleTimeEntries += $adminEntry3
    
    $researchEntry = [TimeEntry]::new("RES-TECH", $currentWeekStart.AddDays(4).AddHours(13), "Research new automation frameworks", [BillingType]::Research)
    $researchEntry.EndTime = $currentWeekStart.AddDays(4).AddHours(15)
    $researchEntry.UserId = "CurrentUser"
    $sampleTimeEntries += $researchEntry
    
    # Add all time entries to data manager
    foreach ($entry in $sampleTimeEntries) {
        $dataManager.AddTimeEntry($entry) | Out-Null
    }
    
    Write-Host "Sample data created: $($dataManager.GetProjects().Count) projects, $($dataManager.GetTasks().Count) tasks, $($dataManager.GetTimeEntries().Count) time entries" -ForegroundColor Green

    # Launch the application
    Write-Host "`nStarting Axiom-Phoenix v4.0..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+P to open command palette, Ctrl+Q to quit" -ForegroundColor Yellow
    Write-Host "Press 3 from Dashboard to view Projects (full CRUD support)" -ForegroundColor Yellow
    Write-Host "Log file: $logPath" -ForegroundColor Gray
    Start-Sleep -Seconds 1
    
    # Write log before creating dashboard
    $logger.Log("Creating Dashboard screen instance", "Debug")
    
    $dashboardScreen = [DashboardScreen]::new($container)
    Write-Host "Initializing Dashboard screen..." -ForegroundColor Yellow
    
    $logger.Log("Initializing Dashboard screen", "Debug")
    $dashboardScreen.Initialize()
    $logger.Log("Dashboard initialized successfully", "Debug")
    
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
