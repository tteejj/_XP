# Fix service load order by renaming files based on dependencies
$servicesPath = Join-Path $PSScriptRoot "Services"

# Define the correct load order based on dependencies
$renameMap = @{
    # Independent services first
    "ASE.006_Logger.ps1"              = "ASE.001_Logger.ps1"
    "ASE.007_EventManager.ps1"        = "ASE.002_EventManager.ps1"
    "ASE.005_ThemeManager.ps1"        = "ASE.003_ThemeManager.ps1"
    
    # Services that depend on EventManager
    "ASE.001_ActionService.ps1"       = "ASE.004_ActionService.ps1"
    "ASE.003_DataManager.ps1"         = "ASE.005_DataManager.ps1"
    "ASE.009_FocusManager.ps1"        = "ASE.006_FocusManager.ps1"
    
    # Services that depend on other services
    "ASE.002_KeybindingService.ps1"   = "ASE.007_KeybindingService.ps1"
    "ASE.004_NavigationService.ps1"   = "ASE.008_NavigationService.ps1"
    "ASE.012_DialogManager.ps1"       = "ASE.009_DialogManager.ps1"
    
    # Other services
    "ASE.010_TuiFrameworkService.ps1" = "ASE.010_TuiFrameworkService.ps1"
    "ASE.011_ViewDefinitionService.ps1" = "ASE.011_ViewDefinitionService.ps1"
    "ASE.008_AsyncJobService.ps1"     = "ASE.012_AsyncJobService.ps1"
}

Write-Host "Fixing service load order..." -ForegroundColor Cyan

# First pass: rename to temporary names to avoid conflicts
foreach ($oldName in $renameMap.Keys) {
    $oldPath = Join-Path $servicesPath $oldName
    if (Test-Path $oldPath) {
        $tempName = $oldName + ".temp"
        $tempPath = Join-Path $servicesPath $tempName
        Write-Host "  Staging: $oldName" -ForegroundColor Gray
        Move-Item -Path $oldPath -Destination $tempPath -Force
    }
}

# Second pass: rename from temp to final names
foreach ($oldName in $renameMap.Keys) {
    $tempName = $oldName + ".temp"
    $tempPath = Join-Path $servicesPath $tempName
    $newName = $renameMap[$oldName]
    $newPath = Join-Path $servicesPath $newName
    
    if (Test-Path $tempPath) {
        Write-Host "  Renaming: $oldName -> $newName" -ForegroundColor Green
        Move-Item -Path $tempPath -Destination $newPath -Force
    }
}

Write-Host "`nService files renamed successfully!" -ForegroundColor Green
Write-Host "The new load order is:"
Write-Host "  1. Logger (no dependencies)"
Write-Host "  2. EventManager (no dependencies)"
Write-Host "  3. ThemeManager (no dependencies)"
Write-Host "  4. ActionService (depends on EventManager)"
Write-Host "  5. DataManager (depends on EventManager)"
Write-Host "  6. FocusManager (depends on EventManager)"
Write-Host "  7. KeybindingService (depends on ActionService)"
Write-Host "  8. NavigationService (depends on ServiceContainer)"
Write-Host "  9. DialogManager (depends on EventManager, FocusManager)"
Write-Host " 10. TuiFrameworkService"
Write-Host " 11. ViewDefinitionService"
Write-Host " 12. AsyncJobService"
