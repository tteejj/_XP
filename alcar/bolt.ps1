#!/usr/bin/env pwsh
# BOLT-AXIOM - The ONE launcher that works

param(
    [switch]$Debug
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
            
            $navigationStandardFile = Join-Path $folderPath "NavigationStandard.ps1"
            if (Test-Path $navigationStandardFile) {
                if ($Debug) { Write-Host "  - Loading NavigationStandard.ps1" -ForegroundColor DarkGray }
                . $navigationStandardFile
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
            
            # Load Component base class
            $componentFile = Join-Path $folderPath "Component.ps1"
            if (Test-Path $componentFile) {
                if ($Debug) { Write-Host "  - Loading Component.ps1 (component base)" -ForegroundColor DarkGray }
                . $componentFile
            }
            
            # Now load ScreenManager after base classes
            $screenManagerFile = Join-Path $PSScriptRoot "Core/ScreenManager.ps1"
            if (Test-Path $screenManagerFile) {
                if ($Debug) { Write-Host "  - Loading ScreenManager.ps1" -ForegroundColor DarkGray }
                . $screenManagerFile
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
            
            # Load all screens
            $screenFiles = @(
                "TaskScreen.ps1",
                "MainMenuScreen.ps1",
                "ProjectsScreen.ps1",
                "DashboardScreen.ps1",
                "SettingsScreen.ps1",
                "SettingsScreen_v2.ps1",
                "FileBrowserScreen.ps1",
                "TextEditorScreen.ps1",
                "TextEditorScreen_v2.ps1"
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
                "ProjectService.ps1"
            )
            
            foreach ($serviceFile in $serviceFiles) {
                $fullPath = Join-Path $folderPath $serviceFile
                if (Test-Path $fullPath) {
                    if ($Debug) { Write-Host "  - Loading $serviceFile" -ForegroundColor DarkGray }
                    . $fullPath
                }
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
    
    Write-Host "Framework loaded!" -ForegroundColor Green
    
    # Create and run screen manager
    $global:ScreenManager = [ScreenManager]::new()
    
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