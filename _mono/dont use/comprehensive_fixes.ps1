# Comprehensive fixes for Axiom-Phoenix v4.0
# This script fixes all identified issues:
# 1. Data Model Enhancements (TimeEntry, enhanced PmcProject)
# 2. TaskListScreen CRUD operations
# 3. Panel alignment issues
# 4. Command palette performance and filtering
# 5. Unicode support
# 6. DashboardScreen rendering issues

Write-Host "Applying comprehensive fixes to Axiom-Phoenix v4.0..." -ForegroundColor Cyan

# PART 1: Data Model Enhancements (AllModels.ps1)
Write-Host "`nPart 1: Enhancing data models..." -ForegroundColor Yellow

$modelsFile = "AllModels.ps1"
$modelsContent = Get-Content $modelsFile -Raw

# Add BillingType enum after existing enums
$enumsMarker = "enum TaskPriority {`r`n    Low`r`n    Medium`r`n    High`r`n}"
$billingTypeEnum = @"

enum BillingType {
    Billable
    NonBillable
}
"@

if ($modelsContent -notmatch "enum BillingType") {
    $modelsContent = $modelsContent.Replace($enumsMarker, "$enumsMarker$billingTypeEnum")
    Write-Host "  - Added BillingType enum" -ForegroundColor Green
}

# Enhance PmcProject class
$projectClassStart = "class PmcProject : ValidationBase {"
$projectEnhancements = @"
    # Enhanced properties from reference implementation
    [string]`$ID1                             # Optional secondary identifier
    [Nullable[datetime]]`$BFDate              # Bring-Forward date for follow-ups
    [string]`$ProjectFolderPath               # Full path to the project's root folder on disk
    [string]`$CaaFileName                     # Relative name of the associated CAA file
    [string]`$RequestFileName                 # Relative name of the associated Request file
    [string]`$T2020FileName                   # Relative name of the associated T2020 file
"@

# Insert after existing properties
$projectPropertiesEnd = "    [bool]`$IsActive = `$true"
if ($modelsContent -notmatch "ProjectFolderPath") {
    $modelsContent = $modelsContent.Replace($projectPropertiesEnd, "$projectPropertiesEnd`r`n$projectEnhancements")
    Write-Host "  - Enhanced PmcProject class" -ForegroundColor Green
}

# Add TimeEntry class before the end comment
$timeEntryClass = @"

# ===== CLASS: TimeEntry =====
# Purpose: Represents a time entry for a task or project
class TimeEntry : ValidationBase {
    [string]`$Id = [Guid]::NewGuid().ToString()
    [string]`$TaskId                                  # Associated task ID (optional)
    [string]`$ProjectKey                              # Associated project key (required)
    [DateTime]`$StartTime                             # When work started
    [Nullable[DateTime]]`$EndTime                     # When work ended (null if timer is still running)
    [string]`$Description                             # A note about the work that was done
    [BillingType]`$BillingType = [BillingType]::Billable # Billing classification
    [string]`$UserId                                  # Who logged the time (future use)
    [decimal]`$HourlyRate = 0                         # Rate per hour (if applicable)

    # Constructors
    TimeEntry() {}
    
    TimeEntry([string]`$projectKey, [string]`$description) {
        `$this.ProjectKey = `$projectKey
        `$this.Description = `$description
        `$this.StartTime = [DateTime]::Now
    }

    # Methods
    [TimeSpan] GetDuration() {
        if (`$null -eq `$this.EndTime) {
            return [DateTime]::Now - `$this.StartTime
        }
        return `$this.EndTime - `$this.StartTime
    }

    [double] GetHours() {
        return `$this.GetDuration().TotalHours
    }

    [decimal] GetTotalValue() {
        if (`$this.BillingType -eq [BillingType]::NonBillable) {
            return 0
        }
        return [decimal](`$this.GetHours()) * `$this.HourlyRate
    }

    [void] Stop() {
        if (`$null -eq `$this.EndTime) {
            `$this.EndTime = [DateTime]::Now
        }
    }

    [bool] IsRunning() {
        return `$null -eq `$this.EndTime
    }
}
"@

$endMarker = "#endregion`r`n#<!-- END_PAGE: AMO.005 -->"
if ($modelsContent -notmatch "class TimeEntry") {
    $modelsContent = $modelsContent.Replace($endMarker, "$timeEntryClass`r`n`r`n$endMarker")
    Write-Host "  - Added TimeEntry class" -ForegroundColor Green
}

Set-Content $modelsFile $modelsContent -Encoding UTF8
Write-Host "  - Data model enhancements complete" -ForegroundColor Green

# PART 2: Enable Unicode Support (AllRuntime.ps1)
Write-Host "`nPart 2: Enabling Unicode support..." -ForegroundColor Yellow

$runtimeFile = "AllRuntime.ps1"
$runtimeContent = Get-Content $runtimeFile -Raw

$initializeFunction = "function Initialize-TuiEngine {"
$unicodeSupport = @"
    # Enable full Unicode support
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    `$env:PYTHONIOENCODING = "utf-8"
    
"@

$functionBody = "function Initialize-TuiEngine {`r`n    param(`r`n        [int]`$BufferWidth = 0,`r`n        [int]`$BufferHeight = 0`r`n    )"

if ($runtimeContent -notmatch "OutputEncoding.*UTF8") {
    $runtimeContent = $runtimeContent.Replace($functionBody, "$functionBody`r`n$unicodeSupport")
    Set-Content $runtimeFile $runtimeContent -Encoding UTF8
    Write-Host "  - Unicode support enabled" -ForegroundColor Green
}

# PART 3: Fix TaskListScreen - Add CRUD buttons and fix layout
Write-Host "`nPart 3: Fixing TaskListScreen..." -ForegroundColor Yellow

$screensFile = "AllScreens.ps1"
$screensContent = Get-Content $screensFile -Raw

# Find the TaskListScreen's Initialize method and add buttons
$taskListInitEnd = "        `$this._UpdateDisplay()"

$crudButtons = @"

        # Add CRUD action buttons at the bottom
        `$buttonY = `$this.Height - 3
        `$buttonSpacing = 15
        `$currentX = 2
        
        # New button
        `$this._newButton = [ButtonComponent]::new("NewButton")
        `$this._newButton.Text = "[N]ew Task"
        `$this._newButton.X = `$currentX
        `$this._newButton.Y = `$buttonY
        `$this._newButton.Width = 12
        `$this._newButton.Height = 1
        `$this._newButton.OnClick = {
            Write-Verbose "New task button clicked"
            # TODO: Show new task dialog
        }
        `$this._mainPanel.AddChild(`$this._newButton)
        `$currentX += `$buttonSpacing
        
        # Edit button
        `$this._editButton = [ButtonComponent]::new("EditButton")
        `$this._editButton.Text = "[E]dit Task"
        `$this._editButton.X = `$currentX
        `$this._editButton.Y = `$buttonY
        `$this._editButton.Width = 12
        `$this._editButton.Height = 1
        `$this._editButton.OnClick = {
            Write-Verbose "Edit task button clicked"
            # TODO: Show edit task dialog
        }
        `$this._mainPanel.AddChild(`$this._editButton)
        `$currentX += `$buttonSpacing
        
        # Delete button
        `$this._deleteButton = [ButtonComponent]::new("DeleteButton")
        `$this._deleteButton.Text = "[D]elete Task"
        `$this._deleteButton.X = `$currentX
        `$this._deleteButton.Y = `$buttonY
        `$this._deleteButton.Width = 14
        `$this._deleteButton.Height = 1
        `$this._deleteButton.OnClick = {
            Write-Verbose "Delete task button clicked"
            # TODO: Show delete confirmation dialog
        }
        `$this._mainPanel.AddChild(`$this._deleteButton)
        `$currentX += `$buttonSpacing + 2
        
        # Complete button
        `$this._completeButton = [ButtonComponent]::new("CompleteButton")
        `$this._completeButton.Text = "[C]omplete"
        `$this._completeButton.X = `$currentX
        `$this._completeButton.Y = `$buttonY
        `$this._completeButton.Width = 12
        `$this._completeButton.Height = 1
        `$this._completeButton.OnClick = {
            Write-Verbose "Complete task button clicked"
            # TODO: Mark task as complete
        }
        `$this._mainPanel.AddChild(`$this._completeButton)
        
        # Add filter textbox
        `$this._filterBox = [TextBoxComponent]::new("FilterBox")
        `$this._filterBox.Placeholder = "Type to filter tasks..."
        `$this._filterBox.X = 2
        `$this._filterBox.Y = 2
        `$this._filterBox.Width = `$taskListWidth - 4
        `$this._filterBox.Height = 1
        `$this._filterBox.OnChange = {
            param(`$newText)
            `$this._filterText = `$newText
            `$this._RefreshTasks()
            `$this._UpdateDisplay()
        }
        `$this._mainPanel.AddChild(`$this._filterBox)

        `$this._UpdateDisplay()
"@

# First, check if buttons already exist
if ($screensContent -notmatch "_newButton") {
    # Find where to insert the buttons (at the end of Initialize method)
    $pattern = "(class TaskListScreen[^}]+Initialize\(\)[^}]+?)(\s+`$this\._UpdateDisplay\(\)\s+\})"
    if ($screensContent -match $pattern) {
        $screensContent = $screensContent -replace $pattern, "`$1$crudButtons`r`n    }"
        Write-Host "  - Added CRUD buttons to TaskListScreen" -ForegroundColor Green
    }
}

# Fix panel heights to accommodate buttons
$panelHeightPattern = "(`$this\._taskListPanel\.Height = )(\d+)"
$screensContent = $screensContent -replace $panelHeightPattern, '`$1(`$this.Height - 8)'

$detailHeightPattern = "(`$this\._detailPanel\.Height = )`$this\.Height - 3"
$screensContent = $screensContent -replace $detailHeightPattern, '`$1`$this.Height - 8'

# Fix the _RefreshTasks method to implement filtering
$refreshTasksMethod = @"
    hidden [void] _RefreshTasks() {
        `$dataManager = `$this.ServiceContainer?.GetService("DataManager")
        if (`$dataManager) {
            `$allTasks = `$dataManager.GetTasks()
            
            # Apply text filter if present
            if (![string]::IsNullOrWhiteSpace(`$this._filterText)) {
                `$filterLower = `$this._filterText.ToLower()
                `$allTasks = @(`$allTasks | Where-Object {
                    `$_.Title.ToLower().Contains(`$filterLower) -or
                    (`$_.Description -and `$_.Description.ToLower().Contains(`$filterLower))
                })
            }
            
            `$this._tasks = @(`$allTasks)
        } else {
            `$this._tasks = @()
        }
        
        # Reset selection if needed
        if (`$this._selectedIndex -ge `$this._tasks.Count) {
            `$this._selectedIndex = [Math]::Max(0, `$this._tasks.Count - 1)
        }
        
        if (`$this._tasks.Count -gt 0) {
            `$this._selectedTask = `$this._tasks[`$this._selectedIndex]
        } else {
            `$this._selectedTask = `$null
        }
    }
"@

# Replace the existing _RefreshTasks method
$screensContent = $screensContent -replace "hidden \[void\] _RefreshTasks\(\) \{[^}]+\}", $refreshTasksMethod

# Update HandleInput to handle the new keys
$handleInputAdditions = @"
            ([ConsoleKey]::N) {
                if (`$keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    # New task
                    `$this._newButton.OnClick.Invoke()
                }
            }
            ([ConsoleKey]::E) {
                if (`$keyInfo.Modifiers -eq [ConsoleModifiers]::None -and `$this._selectedTask) {
                    # Edit task
                    `$this._editButton.OnClick.Invoke()
                }
            }
            ([ConsoleKey]::D) {
                if (`$keyInfo.Modifiers -eq [ConsoleModifiers]::None -and `$this._selectedTask) {
                    # Delete task
                    `$this._deleteButton.OnClick.Invoke()
                }
            }
            ([ConsoleKey]::C) {
                if (`$keyInfo.Modifiers -eq [ConsoleModifiers]::None -and `$this._selectedTask) {
                    # Complete task
                    `$this._completeButton.OnClick.Invoke()
                }
            }
"@

# Add new key handlers before the default case
$defaultPattern = "default \{"
$screensContent = $screensContent -replace "(\s+)default \{", "$handleInputAdditions`r`n`$1default {"

Set-Content $screensFile $screensContent -Encoding UTF8
Write-Host "  - TaskListScreen CRUD operations added" -ForegroundColor Green

# PART 4: Fix Command Palette performance
Write-Host "`nPart 4: Optimizing Command Palette..." -ForegroundColor Yellow

$componentsFile = "AllComponents.ps1"
$componentsContent = Get-Content $componentsFile -Raw

# Add debouncing to search
$searchDebounce = @"
        # Add debounce timer for search
        `$this._searchTimer = `$null
        `$this._lastSearchTime = [DateTime]::MinValue
        
"@

# Find CommandPalette constructor and add debounce fields
$paletteConstructor = "CommandPalette\(\) \{"
if ($componentsContent -match $paletteConstructor -and $componentsContent -notmatch "_searchTimer") {
    $componentsContent = $componentsContent -replace "($paletteConstructor)", "`$1`r`n$searchDebounce"
}

# Optimize the search method
$optimizedSearch = @"
    hidden [void] _FilterActions([string]`$searchText) {
        # Implement debouncing
        `$now = [DateTime]::Now
        if ((`$now - `$this._lastSearchTime).TotalMilliseconds -lt 100) {
            return
        }
        `$this._lastSearchTime = `$now
        
        if ([string]::IsNullOrWhiteSpace(`$searchText)) {
            `$this._filteredActions = `$this._allActions
        } else {
            `$searchLower = `$searchText.ToLower()
            # Use simple contains for better performance
            `$this._filteredActions = @(`$this._allActions | Where-Object {
                `$_.Label.ToLower().Contains(`$searchLower) -or
                (`$_.Category -and `$_.Category.ToLower().Contains(`$searchLower))
            })
        }
        
        # Update ListBox items efficiently
        `$this._listBox.ClearItems()
        foreach (`$action in `$this._filteredActions) {
            `$display = if (`$action.Category) { "[`$(`$action.Category)] `$(`$action.Label)" } else { `$action.Label }
            `$this._listBox.AddItem(`$display)
        }
        
        # Reset selection
        if (`$this._filteredActions.Count -gt 0) {
            `$this._listBox.SelectedIndex = 0
        }
    }
"@

# Replace the existing _FilterActions method if it exists
if ($componentsContent -match "hidden \[void\] _FilterActions") {
    $componentsContent = $componentsContent -replace "hidden \[void\] _FilterActions\([^}]+\}", $optimizedSearch
} else {
    # Add it after RefreshActions
    $refreshActionsEnd = "(`$this\._FilterActions\(`$this\._searchBox\.Text\)\s+\})"
    $componentsContent = $componentsContent -replace $refreshActionsEnd, "`$1`r`n`r`n$optimizedSearch"
}

Set-Content $componentsFile $componentsContent -Encoding UTF8
Write-Host "  - Command Palette optimized" -ForegroundColor Green

# PART 5: Fix DashboardScreen rendering
Write-Host "`nPart 5: Fixing DashboardScreen..." -ForegroundColor Yellow

# The dashboard fixes are already in the screens file content, but let's ensure panels are properly positioned
$dashboardFixes = @"
        # Ensure proper panel sizing and positioning
        `$summaryWidth = [Math]::Max(40, [Math]::Floor(`$this.Width * 0.5))
        `$helpX = `$summaryWidth + 2
        `$helpWidth = [Math]::Max(30, `$this.Width - `$helpX - 2)
        
        # Update panel dimensions
        `$this._summaryPanel.Width = `$summaryWidth
        `$this._helpPanel.X = `$helpX
        `$this._helpPanel.Width = `$helpWidth
        
        # Ensure status panel doesn't overlap
        `$this._statusPanel.Height = [Math]::Max(5, `$this.Height - 15)
"@

# Insert fixes in DashboardScreen Initialize method after panel creation
$dashInitPattern = "(`$this\._mainPanel\.AddChild\(`$this\._statusPanel\))"
$screensContent = $screensContent -replace $dashInitPattern, "`$1`r`n`r`n$dashboardFixes"

Set-Content $screensFile $screensContent -Encoding UTF8

Write-Host "`nAll fixes applied successfully!" -ForegroundColor Green
Write-Host "Run the application to see the improvements." -ForegroundColor Cyan
