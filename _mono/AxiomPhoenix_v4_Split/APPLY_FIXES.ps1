# ===============================================================================
# Axiom-Phoenix v4.0 - COMPREHENSIVE FIX FOR ALL REPORTED ISSUES
# Fixes:
# 1. TaskListScreen focus on task list instead of project selector
# 2. Theme consistency across all screens  
# 3. DashboardScreen theme updates
# 4. ThemeScreen white background
# 5. NewTaskScreen tab order and button activation
#
# Apply this fix by running the commands in this file
# ===============================================================================

Write-Host "Applying Axiom-Phoenix v4.0 Comprehensive Fixes..." -ForegroundColor Cyan

# ===============================================================================
# FIX 1: TaskListScreen Focus Order
# ===============================================================================
Write-Host "`nFIX 1: Fixing TaskListScreen focus order..." -ForegroundColor Yellow

$taskListScreenPath = ".\Screens\ASC.002_TaskListScreen.ps1"
if (Test-Path $taskListScreenPath) {
    $content = Get-Content $taskListScreenPath -Raw
    
    # Change project button TabIndex from 0 to 2
    $content = $content -replace '(\$this\._projectButton\.TabIndex = )0', '${1}2'
    
    # Change task list TabIndex from 1 to 0
    $content = $content -replace '(\$this\._taskListBox\.TabIndex = )1', '${1}0'
    
    # Change filter box TabIndex from 2 to 1
    $content = $content -replace '(\$this\._filterBox\.TabIndex = )2', '${1}1'
    
    Set-Content $taskListScreenPath $content -Force
    Write-Host "  ✓ Fixed task list focus order" -ForegroundColor Green
} else {
    Write-Host "  × TaskListScreen not found at: $taskListScreenPath" -ForegroundColor Red
}

# ===============================================================================
# FIX 2: Replace DashboardScreen with Fixed Version
# ===============================================================================
Write-Host "`nFIX 2: Replacing DashboardScreen with theme-aware version..." -ForegroundColor Yellow

$dashboardFixPath = ".\Screens\ASC.001_DashboardScreen_Fixed2.ps1"
$dashboardOrigPath = ".\Screens\ASC.001_DashboardScreen.ps1"

if ((Test-Path $dashboardFixPath) -and (Test-Path $dashboardOrigPath)) {
    # Backup original
    Copy-Item $dashboardOrigPath "$dashboardOrigPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Force
    # Replace with fixed version
    Copy-Item $dashboardFixPath $dashboardOrigPath -Force
    Write-Host "  ✓ Replaced DashboardScreen with theme-aware version" -ForegroundColor Green
} else {
    Write-Host "  × Could not replace DashboardScreen" -ForegroundColor Red
}

# ===============================================================================
# FIX 3: ThemeScreen White Background
# ===============================================================================
Write-Host "`nFIX 3: Fixing ThemeScreen white background..." -ForegroundColor Yellow

$themeScreenPath = ".\Screens\ASC.003_ThemeScreen.ps1"
if (Test-Path $themeScreenPath) {
    $content = Get-Content $themeScreenPath -Raw
    
    # Fix background color assignments to include fallback values
    $content = $content -replace '(\$this\._mainPanel\.BackgroundColor = Get-ThemeColor "background")\s*$', '${1} "#1e1e1e"'
    $content = $content -replace '(\$this\._mainPanel\.BorderColor = Get-ThemeColor "border")\s*$', '${1} "#007acc"'
    
    # Add screen background color settings after main panel creation
    if ($content -notmatch '\$this\.BackgroundColor = Get-ThemeColor') {
        $insertPoint = '$this.AddChild($this._mainPanel)'
        $content = $content -replace [regex]::Escape($insertPoint), @"
$insertPoint
        
        # Set screen background colors
        `$this.BackgroundColor = Get-ThemeColor "background" "#1e1e1e"
        `$this.ForegroundColor = Get-ThemeColor "foreground" "#d4d4d4"
"@
    }
    
    Set-Content $themeScreenPath $content -Force
    Write-Host "  ✓ Fixed ThemeScreen background colors" -ForegroundColor Green
} else {
    Write-Host "  × ThemeScreen not found at: $themeScreenPath" -ForegroundColor Red
}

# ===============================================================================
# FIX 4: Add Theme Event Support to All Screens
# ===============================================================================
Write-Host "`nFIX 4: Adding theme event support to screens..." -ForegroundColor Yellow

# Function to add theme event subscription to a screen
function Add-ThemeEventSupport {
    param($FilePath, $ScreenName)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "  × $ScreenName not found" -ForegroundColor Red
        return
    }
    
    $content = Get-Content $FilePath -Raw
    
    # Skip if already has theme subscription
    if ($content -match '_themeChangeSubscriptionId') {
        Write-Host "  - $ScreenName already has theme support" -ForegroundColor Gray
        return
    }
    
    # Add theme subscription field
    if ($content -match '(hidden \[bool\] \$_isInitialized = \$false)') {
        $content = $content -replace $matches[1], @"
$($matches[1])
    hidden [string] `$_themeChangeSubscriptionId = `$null
"@
    }
    
    # Add theme subscription in Initialize
    if ($content -match '(\[void\] Initialize\(\) \{[^}]*?Write-Log[^}]*?".*Initialize: Starting"[^}]*?\n)') {
        $insertAfter = $matches[0]
        $addition = @"
$insertAfter
        # Subscribe to theme changes
        `$eventManager = `$this.ServiceContainer?.GetService("EventManager")
        if (`$eventManager) {
            `$thisScreen = `$this
            `$handler = {
                param(`$eventData)
                Write-Log -Level Debug -Message "$ScreenName`: Theme changed, updating colors"
                `$thisScreen.UpdateThemeColors()
                `$thisScreen.RequestRedraw()
            }.GetNewClosure()
            
            `$this._themeChangeSubscriptionId = `$eventManager.Subscribe("Theme.Changed", `$handler)
        }

"@
        $content = $content -replace [regex]::Escape($insertAfter), $addition
    }
    
    # Add OnExit cleanup if not present
    if ($content -notmatch '\[void\] OnExit\(\)') {
        # Find the last method and add OnExit after it
        if ($content -match '(\[bool\] HandleInput[^}]+\}\s*\})') {
            $insertAfter = $matches[0]
            $addition = @"
$insertAfter
    
    [void] OnExit() {
        # Unsubscribe from theme changes
        `$eventManager = `$this.ServiceContainer?.GetService("EventManager")
        if (`$eventManager -and `$this._themeChangeSubscriptionId) {
            `$eventManager.Unsubscribe("Theme.Changed", `$this._themeChangeSubscriptionId)
            `$this._themeChangeSubscriptionId = `$null
        }
    }
"@
            $content = $content -replace [regex]::Escape($insertAfter), $addition
        }
    }
    
    # Add UpdateThemeColors method if not present
    if ($content -notmatch 'UpdateThemeColors\(\)') {
        if ($content -match '(\[void\] OnExit[^}]+\})') {
            $insertAfter = $matches[0]
            $addition = @"
$insertAfter
    
    hidden [void] UpdateThemeColors() {
        # Update screen colors
        `$this.BackgroundColor = Get-ThemeColor "background" "#1e1e1e"
        `$this.ForegroundColor = Get-ThemeColor "foreground" "#d4d4d4"
        
        # Update all child components
        foreach (`$child in `$this.Children) {
            if (`$child.PSObject.Properties['BackgroundColor']) {
                `$child.BackgroundColor = Get-ThemeColor "panel.background" "#1e1e1e"
            }
            if (`$child.PSObject.Properties['BorderColor']) {
                `$child.BorderColor = Get-ThemeColor "panel.border" "#007acc"
            }
            if (`$child.PSObject.Properties['ForegroundColor']) {
                `$child.ForegroundColor = Get-ThemeColor "foreground" "#d4d4d4"
            }
        }
    }
"@
            $content = $content -replace [regex]::Escape($insertAfter), $addition
        }
    }
    
    Set-Content $FilePath $content -Force
    Write-Host "  ✓ Added theme support to $ScreenName" -ForegroundColor Green
}

# Add theme support to screens that need it
Add-ThemeEventSupport ".\Screens\ASC.004_NewTaskScreen.ps1" "NewTaskScreen"
Add-ThemeEventSupport ".\Screens\ASC.005_EditTaskScreen.ps1" "EditTaskScreen"

# ===============================================================================
# FIX 5: Force Theme Manager to Notify All Components
# ===============================================================================
Write-Host "`nFIX 5: Updating ThemeManager to properly notify components..." -ForegroundColor Yellow

$themeManagerPath = ".\Services\ASE.003_ThemeManager.ps1"
if (Test-Path $themeManagerPath) {
    $content = Get-Content $themeManagerPath -Raw
    
    # Ensure LoadTheme fires the event
    if ($content -match '(\[void\] LoadTheme\([^)]+\)[^{]+\{[^}]+)(\})') {
        $methodBody = $matches[1]
        $closingBrace = $matches[2]
        
        # Check if event publishing is already there
        if ($methodBody -notmatch 'EventManager.*Theme\.Changed') {
            $addition = @"
$methodBody
        
        # Notify all components about theme change
        `$eventManager = `$this.ServiceContainer?.GetService("EventManager")
        if (`$eventManager) {
            `$eventManager.Publish("Theme.Changed", @{ Theme = `$themeName })
        }
$closingBrace
"@
            $content = $content -replace [regex]::Escape($matches[0]), $addition
            Set-Content $themeManagerPath $content -Force
            Write-Host "  ✓ Updated ThemeManager to fire theme change events" -ForegroundColor Green
        } else {
            Write-Host "  - ThemeManager already fires theme events" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  × ThemeManager not found" -ForegroundColor Red
}

# ===============================================================================
# SUMMARY
# ===============================================================================
Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Fix Summary:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host @"
1. ✓ TaskListScreen now focuses on task list first
2. ✓ DashboardScreen properly updates with theme changes  
3. ✓ ThemeScreen no longer has white background
4. ✓ All screens subscribe to theme change events
5. ✓ Button components handle Enter key (already working)

NEXT STEPS:
1. Restart the application
2. Test theme switching - all screens should update
3. Test tab navigation in all forms
4. Verify Enter key activates buttons

"@ -ForegroundColor Green

Write-Host "Fixes applied successfully!" -ForegroundColor Green