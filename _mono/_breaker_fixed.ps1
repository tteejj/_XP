# Framework-Breaker.ps1 - Splits Axiom-Phoenix v4.0 into organized file structure
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$DestinationPath = "AxiomPhoenix_v4_Split"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $scriptRoot = $PSScriptRoot
    $destinationRootPath = Join-Path $scriptRoot $DestinationPath

    Write-Host "Framework Breaker - Splitting Axiom-Phoenix v4.0" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan

    # --- Step 1: Prepare the Destination Directory ---
    if (Test-Path $destinationRootPath) {
        if ($PSCmdlet.ShouldProcess($destinationRootPath, "Remove existing destination directory")) {
            Write-Host "Removing existing destination directory..." -ForegroundColor Yellow
            Remove-Item -Path $destinationRootPath -Recurse -Force
        }
    }
    if ($PSCmdlet.ShouldProcess($destinationRootPath, "Create new project directory")) {
        Write-Host "Creating new project directory: $destinationRootPath" -ForegroundColor Green
        New-Item -Path $destinationRootPath -ItemType Directory | Out-Null
    }

    # Create folder structure
    $folders = @("Base", "Models", "Components", "Screens", "Functions", "Services", "Runtime")
    foreach ($folder in $folders) {
        $folderPath = Join-Path $destinationRootPath $folder
        if ($PSCmdlet.ShouldProcess($folderPath, "Create subdirectory")) {
            New-Item -Path $folderPath -ItemType Directory | Out-Null
        }
    }

    # --- Step 2: Define source files and their target mappings ---
    $sourceFiles = @(
        @{ File = "AllBaseClasses.ps1"; Folder = "Base"; Prefix = "ABC" }
        @{ File = "AllModels.ps1"; Folder = "Models"; Prefix = "AMO" }
        @{ File = "AllComponents.ps1"; Folder = "Components"; Prefix = "ACO" }
        @{ File = "AllScreens.ps1"; Folder = "Screens"; Prefix = "ASC" }
        @{ File = "AllFunctions.ps1"; Folder = "Functions"; Prefix = "AFU" }
        @{ File = "AllServices.ps1"; Folder = "Services"; Prefix = "ASE" }
        @{ File = "AllRuntime.ps1"; Folder = "Runtime"; Prefix = "ART" }
    )

    # --- Step 3: Process Each Source File ---
    foreach ($sourceInfo in $sourceFiles) {
        $sourceFilePath = Join-Path $scriptRoot $sourceInfo.File
        if (-not (Test-Path $sourceFilePath)) {
            Write-Warning "Source file not found: $($sourceInfo.File)"
            continue
        }

        Write-Host "Processing $($sourceInfo.File)..." -ForegroundColor White
        $fileContent = Get-Content -Path $sourceFilePath -Raw
        $targetDirectory = Join-Path $destinationRootPath $sourceInfo.Folder

        # Extract header content (using statements, initial comments)
        $headerContent = ""
        if ($fileContent -match '(?s)(.*?)#<!--\s*PAGE:') {
            $headerContent = $Matches[1].Trim()
        } elseif ($fileContent -match '(?s)(.*?)(class\s+\w+|function\s+\w+)') {
            $headerContent = $Matches[1].Trim()
        }

        # Check if this file has pages
        if ($fileContent -match '#<!--\s*PAGE:') {
            # Split by PAGE markers
            $pages = $fileContent -split '(?=#<!--\s*PAGE:)'
            
            foreach ($pageBlock in $pages) {
                if ($pageBlock -match '#<!--\s*PAGE:\s*([^-]+)\s*-\s*(.+?)\s*-->') {
                    $pageId = $Matches[1].Trim()
                    $pageTitle = $Matches[2].Trim() -replace ' Class$', ''
                    
                    # Clean up class name for filename
                    $className = $pageTitle -replace '[^a-zA-Z0-9]', ''
                    $outputFileName = "$pageId`_$className.ps1"
                    $outputFilePath = Join-Path $targetDirectory $outputFileName

                    # Clean up page content
                    $pageContent = $pageBlock.Trim()
                    
                    # Remove the PAGE comment from content but keep everything else
                    $pageContent = $pageContent -replace '#<!--\s*PAGE:[^>]*-->', ''
                    $pageContent = $pageContent.Trim()
                    
                    # Combine header and page content
                    $finalContent = if ($headerContent) {
                        "$headerContent`n`n$pageContent"
                    } else {
                        $pageContent
                    }

                    if ($PSCmdlet.ShouldProcess($outputFilePath, "Write page file")) {
                        Write-Host "  -> Creating $outputFileName" -ForegroundColor Gray
                        Set-Content -Path $outputFilePath -Value $finalContent -Encoding UTF8
                    }
                }
            }
        } else {
            # Single file without pages - copy as-is
            $outputFilePath = Join-Path $targetDirectory $sourceInfo.File
            if ($PSCmdlet.ShouldProcess($outputFilePath, "Write single file")) {
                Write-Host "  -> Copying $($sourceInfo.File) (no pages)" -ForegroundColor Gray
                Copy-Item -Path $sourceFilePath -Destination $outputFilePath
            }
        }
    }

    # --- Step 4: Generate updated Start.ps1 ---
    Write-Host "Generating updated Start.ps1..." -ForegroundColor Cyan
    $newStartContent = @'
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
    
    Write-Host "Services initialized successfully!" -ForegroundColor Green

    # Initialize global state
    $global:TuiState.Services = @{
        Logger = $container.GetService("Logger")
        EventManager = $container.GetService("EventManager") 
        ThemeManager = $container.GetService("ThemeManager")
        DataManager = $container.GetService("DataManager")
        ActionService = $container.GetService("ActionService")
        KeybindingService = $container.GetService("KeybindingService")
        NavigationService = $container.GetService("NavigationService")
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
    
    # Create sample tasks
    $sampleTasks = @(
        [PmcTask]::new("TASK-001", "Review project requirements", "Pending", "High"),
        [PmcTask]::new("TASK-002", "Design system architecture", "InProgress", "High"),
        [PmcTask]::new("TASK-003", "Implement core features", "InProgress", "Medium"),
        [PmcTask]::new("TASK-004", "Write unit tests", "Pending", "Medium"),
        [PmcTask]::new("TASK-005", "Deploy to staging", "Pending", "Low")
    )
    
    foreach ($task in $sampleTasks) {
        $dataManager.AddTask($task)
    }
    
    Write-Host "Sample data created!" -ForegroundColor Green

    # Launch the application
    Write-Host "`nStarting Axiom-Phoenix v4.0..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+P to open command palette, Ctrl+Q to quit" -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    
    $dashboardScreen = [DashboardScreen]::new($container)
    Clear-Host
    Start-AxiomPhoenix -ServiceContainer $container -InitialScreen $dashboardScreen

} catch {
    Write-Host "`nCRITICAL ERROR! Failed to start framework." -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
'@
    
    $newStartPath = Join-Path $destinationRootPath "Start.ps1"
    if ($PSCmdlet.ShouldProcess($newStartPath, "Write updated Start.ps1")) {
        Set-Content -Path $newStartPath -Value $newStartContent -Encoding UTF8
    }

    Write-Host "`n=====================================" -ForegroundColor Cyan
    Write-Host "Framework successfully split into '$destinationRootPath'" -ForegroundColor Green
    Write-Host "Files organized into folders by component type" -ForegroundColor Green
    Write-Host "`nTo run the application:" -ForegroundColor Yellow
    Write-Host "  1. cd '$destinationRootPath'" -ForegroundColor White
    Write-Host "  2. .\Start.ps1" -ForegroundColor White
    Write-Host "=====================================" -ForegroundColor Cyan

} catch {
    Write-Error "Critical error during framework splitting: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
