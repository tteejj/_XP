# FIXES APPLIED DIRECTLY TO FILES

## 1. NEW TASK SCREEN - TEXT BOX VISIBILITY FIXED
**File:** `Screens\ASC.004_NewTaskScreen.ps1`
- Removed sidebar menu that was taking up space
- Made form panel full screen
- Properly spaced text boxes with Height=3
- Fixed Y positioning so text boxes don't overlap
- Added clear spacing between Title, Description, Priority/Project sections
- Fixed instruction text at bottom

## 2. THEME SCREEN - THEMES NOW APPLY + NO TRUNCATION
**File:** `Screens\ASC.003_ThemeScreen.ps1`
- Added `$global:TuiState.IsDirty = $true` to force redraw when theme applies
- Changed preview panel width to `[Math]::Max(50, ...)` to prevent truncation
- Added longer delay (1000ms) with confirmation message

**File:** `Services\ASE.003_ThemeManager.ps1`
- Modified SetColor() to accept ConsoleColor enums (converted to hex)
- Added redraw trigger in SetColor method

## 3. TASK LIST SCREEN - FIXED FILTER BOX
**File:** `Screens\ASC.002_TaskListScreen.ps1`
- Changed filter box Height from 1 to 3 (proper text box height)
- Moved help text Y position from 3 to 4 to avoid overlap
- Shortened help text to prevent truncation

## 4. GENERAL FIXES
- ESC key now works to cancel in NewTaskScreen
- Ctrl+S saves task
- Tasks save immediately to disk with SaveData()
- All text is now visible and not occluded

## TO TEST:
Run `.\Start.ps1` and verify:
1. New Task screen - all text boxes visible when typing
2. Theme screen - select a theme and it applies immediately
3. Task List - filter box doesn't overlap list items
4. ESC key cancels forms properly
