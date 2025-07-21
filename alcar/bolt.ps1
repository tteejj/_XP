#!/usr/bin/env pwsh
# BOLT-AXIOM - The ONE launcher that works

param(
    [switch]$Debug,
    [switch]$AsyncInput
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Disable strict mode for class loading
Set-StrictMode -Off

try {
    Write-Host "Loading BOLT-AXIOM..." -ForegroundColor Cyan
    
    # Define loading order (dependencies first)
    $loadOrder = @(
        "Core",
        "Base",
        "Models",
        "Services",
        "Components",
        "FastComponents",
        "Screens"
    )
    
    # Load all files in correct order
    foreach ($folder in $loadOrder) {
        $folderPath = Join-Path $PSScriptRoot $folder
        if (-not (Test-Path $folderPath)) { 
            Write-Warning "Folder not found: $folder"
            continue 
        }
        
        if ($Debug) { Write-Host "Loading $folder..." -ForegroundColor Gray }
        
        # For Core folder, load vt100.ps1 first, then layout2.ps1
        if ($folder -eq "Core") {
            $vt100File = Join-Path $folderPath "vt100.ps1"
            if (Test-Path $vt100File) {
                if ($Debug) { Write-Host "  - Loading vt100.ps1 (priority)" -ForegroundColor DarkGray }
                . $vt100File
            }
            
            # Load Cell and Buffer for double buffering
            $cellFile = Join-Path $folderPath "Cell.ps1"
            if (Test-Path $cellFile) {
                if ($Debug) { Write-Host "  - Loading Cell.ps1" -ForegroundColor DarkGray }
                . $cellFile
            }
            
            $bufferFile = Join-Path $folderPath "Buffer.ps1"
            if (Test-Path $bufferFile) {
                if ($Debug) { Write-Host "  - Loading Buffer.ps1" -ForegroundColor DarkGray }
                . $bufferFile
            }
            
            $layout2File = Join-Path $folderPath "layout2.ps1"
            if (Test-Path $layout2File) {
                if ($Debug) { Write-Host "  - Loading layout2.ps1" -ForegroundColor DarkGray }
                . $layout2File
            }
            
            
            $dateparserFile = Join-Path $folderPath "dateparser.ps1"
            if (Test-Path $dateparserFile) {
                if ($Debug) { Write-Host "  - Loading dateparser.ps1" -ForegroundColor DarkGray }
                . $dateparserFile
            }
            
            $renderOptimizerFile = Join-Path $folderPath "RenderOptimizer.ps1"
            if (Test-Path $renderOptimizerFile) {
                if ($Debug) { Write-Host "  - Loading RenderOptimizer.ps1" -ForegroundColor DarkGray }
                . $renderOptimizerFile
            }
            
            # Load LazyGit components in dependency order
            $lazyGitFiles = @(
                "ILazyGitView.ps1",
                "LazyGitRenderer.ps1", 
                "LazyGitLayout.ps1",
                "LazyGitPanel.ps1",
                "LazyGitFocusManager.ps1",
                "EnhancedCommandBar.ps1"
            )
            
            foreach ($lazyGitFile in $lazyGitFiles) {
                $filePath = Join-Path $folderPath $lazyGitFile
                if (Test-Path $filePath) {
                    if ($Debug) { Write-Host "  - Loading $lazyGitFile (LazyGit)" -ForegroundColor DarkGray }
                    . $filePath
                }
            }
            
            # Skip the rest of Core files
            continue
        } elseif ($folder -eq "Base") {
            # Load Screen.ps1 first (base classes)
            $screenFile = Join-Path $folderPath "Screen.ps1"
            if (Test-Path $screenFile) {
                if ($Debug) { Write-Host "  - Loading Screen.ps1 (base classes)" -ForegroundColor DarkGray }
                . $screenFile
            }
            
            # Load Dialog base class (contains DialogResult enum)
            $dialogFile = Join-Path $folderPath "Dialog.ps1"
            if (Test-Path $dialogFile) {
                if ($Debug) { Write-Host "  - Loading Dialog.ps1 (dialog base)" -ForegroundColor DarkGray }
                . $dialogFile
            }
            
            # Load Component base class
            $componentFile = Join-Path $folderPath "Component.ps1"
            if (Test-Path $componentFile) {
                if ($Debug) { Write-Host "  - Loading Component.ps1 (component base)" -ForegroundColor DarkGray }
                . $componentFile
            }
            
            # Load AsyncInputManager before ScreenManager
            $asyncInputFile = Join-Path $PSScriptRoot "Core/AsyncInputManager.ps1"
            if (Test-Path $asyncInputFile) {
                if ($Debug) { Write-Host "  - Loading AsyncInputManager.ps1" -ForegroundColor DarkGray }
                . $asyncInputFile
            }
            
            # Now load ScreenManager after base classes
            $screenManagerFile = Join-Path $PSScriptRoot "Core/ScreenManager.ps1"
            if (Test-Path $screenManagerFile) {
                if ($Debug) { Write-Host "  - Loading ScreenManager.ps1" -ForegroundColor DarkGray }
                . $screenManagerFile
            }
            
            # Load NavigationStandard after Screen class is defined
            $navigationStandardFile = Join-Path $PSScriptRoot "Core/NavigationStandard.ps1"
            if (Test-Path $navigationStandardFile) {
                if ($Debug) { Write-Host "  - Loading NavigationStandard.ps1" -ForegroundColor DarkGray }
                . $navigationStandardFile
            }
            
            # Load EnhancedInputManager after Screen class
            $enhancedInputFile = Join-Path $PSScriptRoot "Core/EnhancedInputManager.ps1"
            if (Test-Path $enhancedInputFile) {
                if ($Debug) { Write-Host "  - Loading EnhancedInputManager.ps1" -ForegroundColor DarkGray }
                . $enhancedInputFile
            }
            
            continue
        } elseif ($folder -eq "Screens") {
            # Load dialog screens first
            $deleteConfirmFile = Join-Path $folderPath "DeleteConfirmDialog.ps1"
            if (Test-Path $deleteConfirmFile) {
                if ($Debug) { Write-Host "  - Loading DeleteConfirmDialog.ps1" -ForegroundColor DarkGray }
                . $deleteConfirmFile
            }
            
            $editDialogFile = Join-Path $folderPath "EditDialog.ps1"
            if (Test-Path $editDialogFile) {
                if ($Debug) { Write-Host "  - Loading EditDialog.ps1" -ForegroundColor DarkGray }
                . $editDialogFile
            }
            
            # Load all screens (dialogs first, then screens that reference them)
            $screenFiles = @(
                "ProjectCreationDialog.ps1",
                "TimeTrackingScreen.ps1",
                "TimeEntryDialog.ps1",
                "QuickTimeEntryDialog.ps1",
                "TimesheetExportDialog.ps1",
                "ProjectSelectionDialog.ps1",
                "KanbanScreen.ps1",
                "TaskScreen.ps1",
                "TaskScreenLazyGit.ps1",
                "TaskScreenLazyGitTest.ps1",
                "EnhancedTaskScreen.ps1",
                "PTUIDemoScreen.ps1",
                "ProjectsScreen.ps1",
                "ProjectsScreenNew.ps1",
                "ProjectDetailsDialog.ps1",
                "GuidedTimeEntryDialog.ps1",
                "EditTimeEntryDialog.ps1",
                "DashboardScreen.ps1",
                "SettingsScreen.ps1",
                "SettingsScreen_v2.ps1",
                "TextEditorScreen.ps1",
                "TextEditorScreen_v2.ps1",
                "SimpleTextEditor.ps1",
                "FileBrowserScreen.ps1",
                "ProjectContextScreen.ps1",
                "ProjectContextScreenV2.ps1",
                "ProjectContextScreenV3.ps1",
                "ProjectContextScreenV3_Enhanced.ps1",
                "ProjectContextScreenV3_Fixed.ps1",
                "ProjectContextScreenV3_Final.ps1",
                "ALCARLazyGitScreen.ps1",
                "MainMenuScreen.ps1"
            )
            
            foreach ($screenFile in $screenFiles) {
                $fullPath = Join-Path $folderPath $screenFile
                if (Test-Path $fullPath) {
                    if ($Debug) { Write-Host "  - Loading $screenFile" -ForegroundColor DarkGray }
                    . $fullPath
                }
            }
            continue
        } elseif ($folder -eq "Services") {
            # Load services in specific order
            $serviceFiles = @(
                "ServiceContainer.ps1",
                "ViewDefinitionService.ps1",
                "TaskService.ps1",
                "ProjectService.ps1",
                "TimeTrackingService.ps1",
                "UnifiedDataService.ps1"
            )
            
            foreach ($serviceFile in $serviceFiles) {
                $fullPath = Join-Path $folderPath $serviceFile
                if (Test-Path $fullPath) {
                    if ($Debug) { Write-Host "  - Loading $serviceFile" -ForegroundColor DarkGray }
                    . $fullPath
                }
            }
            continue
        } elseif ($folder -eq "Components") {
            # Load base components first (dependency order)
            $baseComponents = @("ListBox.ps1", "SearchableListBox.ps1", "KanbanColumn.ps1")
            foreach ($baseComponent in $baseComponents) {
                $baseFile = Join-Path $folderPath $baseComponent
                if (Test-Path $baseFile) {
                    if ($Debug) { Write-Host "  - Loading $baseComponent (base class)" -ForegroundColor DarkGray }
                    . $baseFile
                }
            }
            
            # Load all other components except CommandPalette and base components (already loaded)
            $excludeFiles = @("CommandPalette.ps1") + $baseComponents
            $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | Where-Object { $_.Name -notin $excludeFiles } | Sort-Object Name
            foreach ($file in $files) {
                if ($Debug) { Write-Host "  - Loading $($file.Name)" -ForegroundColor DarkGray }
                . $file.FullName
            }
            continue
        } elseif ($folder -eq "FastComponents") {
            # Load FastComponentBase first
            $baseFile = Join-Path $folderPath "FastComponentBase.ps1"
            if (Test-Path $baseFile) {
                if ($Debug) { Write-Host "  - Loading FastComponentBase.ps1 (base class)" -ForegroundColor DarkGray }
                . $baseFile
            }
            
            # Then load all other FastComponents
            $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | Where-Object { $_.Name -ne "FastComponentBase.ps1" } | Sort-Object Name
            foreach ($file in $files) {
                if ($Debug) { Write-Host "  - Loading $($file.Name)" -ForegroundColor DarkGray }
                . $file.FullName
            }
            continue
        } else {
            $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | Sort-Object Name
        }
        
        foreach ($file in $files) {
            if ($Debug) { Write-Host "  - Loading $($file.Name)" -ForegroundColor DarkGray }
            . $file.FullName
        }
    }
    
    # Load CommandPalette after all screens are loaded
    $commandPaletteFile = Join-Path $PSScriptRoot "Components/CommandPalette.ps1"
    if (Test-Path $commandPaletteFile) {
        if ($Debug) { Write-Host "Loading CommandPalette.ps1 (after screens)" -ForegroundColor DarkGray }
        . $commandPaletteFile
    }
    
    Write-Host "Framework loaded!" -ForegroundColor Green
    
    # Initialize global data service
    $global:UnifiedDataService = [UnifiedDataService]::new()
    Write-Host "Global data service initialized" -ForegroundColor Green
    
    # Create and run screen manager
    $global:ScreenManager = [ScreenManager]::new()
    
    # Enable async input if requested
    if ($AsyncInput) {
        Write-Host "Async input mode enabled" -ForegroundColor Yellow
        $global:ScreenManager.AsyncInputEnabled = $true
    }
    
    # Start with main menu
    $mainMenu = [MainMenuScreen]::new()
    $global:ScreenManager.SetRoot($mainMenu)
    
    # Run the application
    $global:ScreenManager.Run()
}
catch {
    Write-Host "`nError: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    [Console]::ReadKey($true) | Out-Null
}
finally {
    # Cleanup is handled by ScreenManager
    Write-Host "BOLT ⚡" -ForegroundColor Cyan
}