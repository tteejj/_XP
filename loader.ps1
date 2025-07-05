# class-loader.ps1
#
# PURPOSE:
# This script's only job is to define all class types for the Axiom-Phoenix
# application. It is dot-sourced by the main 'run.ps1' script at startup.
# This pre-loads all classes into the session *before* any modules are
# imported, which solves PowerShell's parse-time dependency resolution issue
# for this project's specific architecture.

Write-Host "[Loader] Defining all application classes..." -ForegroundColor DarkGray

# --- CORE PRIMITIVES & BASE CLASSES ---
. "$PSScriptRoot\modules\exceptions\exceptions.psm1"
. "$PSScriptRoot\components\tui-primitives\tui-primitives.psm1"
. "$PSScriptRoot\components\ui-classes\ui-classes.psm1"
. "$PSScriptRoot\layout\panels-class\panels-class.psm1"
. "$PSScriptRoot\modules\models\models.psm1"

# --- CORE SERVICES (without UI dependencies) ---
. "$PSScriptRoot\services\service-container\service-container.psm1"
. "$PSScriptRoot\services\action-service\action-service.psm1"
. "$PSScriptRoot\services\keybinding-service-class\keybinding-service-class.psm1"
. "$PSScriptRoot\services\navigation-service-class\navigation-service-class.psm1"
. "$PSScriptRoot\modules\data-manager\data-manager.psm1"

# --- UI-DEPENDENT COMPONENTS & SERVICES ---
. "$PSScriptRoot\components\tui-components\tui-components.psm1"
. "$PSScriptRoot\components\advanced-data-components\advanced-data-components.psm1"
. "$PSScriptRoot\components\advanced-input-components\advanced-input-components.psm1"
. "$PSScriptRoot\modules\dialog-system-class\dialog-system-class.psm1"
. "$PSScriptRoot\components\command-palette\command-palette.psm1"
. "$PSScriptRoot\modules\tui-framework\tui-framework.psm1" # Contains TuiFrameworkService class

# --- SCREENS (Top-level UI compositions) ---
. "$PSScriptRoot\screens\dashboard-screen\dashboard-screen.psm1"
. "$PSScriptRoot\screens\task-list-screen\task-list-screen.psm1"

# --- ENGINE & HANDLERS (Depend on many other components) ---
. "$PSScriptRoot\modules\panic-handler\panic-handler.psm1"
. "$PSScriptRoot\modules\tui-engine\tui-engine.psm1"

Write-Host "[Loader] All classes defined." -ForegroundColor DarkGray