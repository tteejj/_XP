# Create-Monolith.ps1 (v14 - BRUTAL CLEANING)
# This script builds a single, runnable monolithic script. It has been completely
# rewritten to programmatically PATCH the source code in memory and AGGRESSIVELY
# clean all files to remove any and all module-specific commands.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PSScriptRoot = Get-Location
$OutputScript = Join-Path $PSScriptRoot "Monolithic-PMCTerminal.ps1"

# ----------------------------------------------------------------------------------
# CRITICAL: This is the DEFINITIVE, manually-verified load order for all files.
# ----------------------------------------------------------------------------------
$FileLoadOrder = @(
    # Level 0: Core Primitives & Models
    'modules\logger\logger.psm1',
    'modules\exceptions\exceptions.psm1',
    'modules\models\models.psm1',
    'components\tui-primitives\tui-primitives.psm1',

    # Level 1: Foundational Systems
    'modules\event-system\event-system.psm1',
    'modules\theme-manager\theme-manager.psm1',
    'components\ui-classes\ui-classes.psm1', # Defines UIElement, Screen. MUST be loaded before anything that inherits from them.

    # Level 2: Layout & Core Component Classes
    'layout\panels-class\panels-class.psm1',
    'components\navigation-class\navigation-class.psm1',
    'components\tui-components\tui-components.psm1',
    'components\advanced-data-components\advanced-data-components.psm1',
    'components\advanced-input-components\advanced-input-components.psm1',
    
    # Level 3: Service and Dialog Classes
    'modules\data-manager-class\data-manager-class.psm1',
    'services\keybinding-service-class\keybinding-service-class.psm1',
    'modules\dialog-system-class\dialog-system-class.psm1',
    
    # Level 4: Screen Classes (which must be defined before the factory uses them)
    'screens\dashboard-screen\dashboard-screen.psm1',
    'screens\task-list-screen\task-list-screen.psm1',
    
    # Level 5: Navigation Service (which uses the Screen classes)
    'services\navigation-service-class\navigation-service-class.psm1',

    # Level 6: Service Implementation Functions & TUI Engine
    'modules\data-manager\data-manager.psm1',
    'services\keybinding-service\keybinding-service.psm1',
    'services\navigation-service\navigation-service.psm1',
    'modules\tui-engine\tui-engine.psm1',
    'modules\tui-framework\tui-framework.psm1'
)

# --- Script Logic ---

Write-Host "Starting monolithic script creation..." -ForegroundColor Yellow

if (Test-Path $OutputScript) { Remove-Item $OutputScript -Force }

# --- Stage 1: Define a robust cleaning function ---
function Clean-FileContent {
    param(
        [string]$RawContent
    )
    # This regex aggressively finds and removes lines containing the forbidden statements,
    # even if they are commented out or have leading/trailing whitespace.
    $forbiddenPatterns = 'using\s+module', 'using\s+namespace', 'Export-ModuleMember', 'Set-StrictMode', '`?\$ErrorActionPreference'
    $regex = '(?im)^\s*(#\s*)?(' + ($forbiddenPatterns -join '|') + ').*$'

    $cleanedContent = $RawContent -replace $regex, ''
    return $cleanedContent.Trim()
}

# --- Stage 2: Extract and CLEAN main script logic and its param() block ---
$mainScriptPath = Join-Path $PSScriptRoot '_CLASSY-MAIN.ps1'
if (-not (Test-Path $mainScriptPath)) { throw "FATAL: Main script file '_CLASSY-MAIN.ps1' not found." }
$mainScriptContent = Get-Content -Path $mainScriptPath -Raw
$paramBlock = ""
if ($mainScriptContent -match '(?msi)^\s*param\s*\((.*?)\)') {
    $paramBlock = $matches[0]
    Write-Host "  -> Extracted top-level param() block." -ForegroundColor Green
}
if ($mainScriptContent -match '(?msi)(try\s*\{.*\}\s*finally\s*\{.*\})') {
    $mainScriptBody = $matches[1]
    Write-Host "  -> Extracted main try/catch/finally execution block." -ForegroundColor Green
} else {
    throw "FATAL: Could not find the main 'try { ... }' block in _CLASSY-MAIN.ps1."
}

# --- Stage 3: Process, PATCH, and clean all other files ---
$allOtherContent = [System.Text.StringBuilder]::new()

foreach ($filePath in $FileLoadOrder) {
    $fullPath = Join-Path $PSScriptRoot $filePath
    if (-not (Test-Path $fullPath)) {
        Write-Warning "File not found, skipping: $filePath"
        continue
    }

    Write-Host "Processing: $filePath" -ForegroundColor Cyan
    $content = Get-Content -Path $fullPath -Raw

    # ==============================================================================
    # PROGRAMMATIC PATCHING TO FIX LOGIC BUGS
    # ==============================================================================
    switch -Wildcard ($filePath) {
        '*dashboard-screen.psm1' {
            $content = $content -replace 'class DashboardScreen : UIElement', 'class DashboardScreen : Screen'
            $content = $content -replace 'base\(0, 0, 120, 30\)', 'base("DashboardScreen", $services)'
            Write-Host "  -> PATCHED: DashboardScreen to inherit from Screen and fixed constructor." -ForegroundColor Magenta
        }
        '*task-list-screen.psm1' {
            $content = $content -replace 'class TaskListScreen : UIElement', 'class TaskListScreen : Screen'
            $content = $content -replace 'base\(0, 0, 120, 30\)', 'base("TaskListScreen", $services)'
            Write-Host "  -> PATCHED: TaskListScreen to inherit from Screen and fixed constructor." -ForegroundColor Magenta
        }
        '*navigation-service-class.psm1' {
            $content = $content -replace 'if \(-not \$screenType.IsSubclassOf\(\[Screen\]\)\)', 'if (-not ($screenType -eq [Screen] -or $screenType.IsSubclassOf([Screen])))'
            Write-Host "  -> PATCHED: ScreenFactory type check to be correct." -ForegroundColor Magenta
        }
    }

    $cleanedFile = Clean-FileContent -RawContent $content
    
    [void]$allOtherContent.AppendLine()
    [void]$allOtherContent.AppendLine("# --- START OF ORIGINAL FILE: $filePath ---")
    [void]$allOtherContent.AppendLine($cleanedFile)
    [void]$allOtherContent.AppendLine("# --- END OF ORIGINAL FILE: $filePath ---")
    [void]$allOtherContent.AppendLine()
}

# --- Stage 4: Assemble the final script ---
$finalScript = [System.Text.StringBuilder]::new()
[void]$finalScript.AppendLine("# ==================================================================================")
[void]$finalScript.AppendLine("# PMC Terminal v5 - MONOLITHIC SCRIPT (Generated by Create-Monolith.ps1)")
[void]$finalScript.AppendLine("# DO NOT EDIT THIS FILE DIRECTLY.")
[void]$finalScript.AppendLine("# ==================================================================================")
[void]$finalScript.AppendLine(@"
#Requires -Version 7.0
using namespace System.Text
using namespace System.Management.Automation
using namespace System
"@)
if (-not [string]::IsNullOrWhiteSpace($paramBlock)) {
    [void]$finalScript.AppendLine($paramBlock)
}
[void]$finalScript.AppendLine(@"
# Global script settings
Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"
"@)
[void]$finalScript.Append($allOtherContent.ToString())
[void]$finalScript.AppendLine()
[void]$finalScript.AppendLine("# --- START OF MAIN EXECUTION LOGIC (from _CLASSY-MAIN.ps1) ---")
[void]$finalScript.AppendLine($mainScriptBody)
[void]$finalScript.AppendLine("# --- END OF MAIN EXECUTION LOGIC ---")

Add-Content -Path $OutputScript -Value $finalScript.ToString() -Encoding UTF8

Write-Host "`nSuccessfully created monolithic script: $OutputScript" -ForegroundColor Green
Write-Host "You can now run the application with: pwsh -File `"$OutputScript`"" -ForegroundColor White
