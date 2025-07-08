# CRITICAL STABILITY FIXES - IMPLEMENTATION GUIDE
# For Axiom-Phoenix v4.0 Mono Framework

## Overview
This guide provides complete code blocks to fix two critical stability issues in AllComponents.ps1:
1. ExecuteAction overload crash in CommandPalette
2. ConsoleColor to hex string conversion issues

## ISSUE 1.1: CommandPalette ExecuteAction Crash

### Problem
The ActionService.ExecuteAction method requires two parameters but CommandPalette was calling it with only one.

### Fix Location
File: AllComponents.ps1
Class: CommandPalette
Method: HandleInput

### Implementation
Replace the entire HandleInput method in CommandPalette class with the code from `critical_fixes_part1.ps1`

The key change is on the line that executes the action:
```powershell
# OLD (causes crash):
$this._actionService.ExecuteAction($selectedAction.Name)

# NEW (fixed):
$this._actionService.ExecuteAction($selectedAction.Name, @{})
```

## ISSUE 1.2: ConsoleColor to Hex String Conversions

### Problem
Multiple components were using [ConsoleColor] properties while the rendering system expects hex strings.

### Components Requiring Fixes

#### 1. MultilineTextBoxComponent
- **File**: AllComponents.ps1
- **Fix**: Replace the entire class with the code from `fixed_multiline_textbox.ps1`
- **Key Changes**: 
  - Properties changed from [ConsoleColor] to [string]
  - Default values changed to hex strings
  - OnRender method updated to use Get-ThemeColor

#### 2. Panel
- **File**: AllComponents.ps1
- **Fix**: Replace the entire class with the code from `fixed_panel.ps1`
- **Key Changes**:
  - BorderColor: [ConsoleColor]::Gray → "#808080"
  - BackgroundColor: [ConsoleColor]::Black → "#000000"
  - OnRender method updated to use theme colors

#### 3. GroupPanel
- **File**: AllComponents.ps1
- **Fix**: Replace the entire class with the code from `fixed_grouppanel.ps1`
- **Key Changes**:
  - Constructor updated to use hex strings
  - BorderColor: [ConsoleColor]::DarkCyan → "#008B8B"
  - BackgroundColor: [ConsoleColor]::Black → "#000000"

#### 4. DateInputComponent
- **File**: AllComponents.ps1
- **Fix**: Replace the OnRender method with the code from `fixed_dateinput_onrender.ps1`
- **Key Changes**:
  - OnRender method updated to use Get-ThemeColor with hex strings
  - Removed all [ConsoleColor] references

#### 5. ListBox
- **Status**: Already fixed in current code
- **Note**: ListBox already uses hex strings, no changes needed

#### 6. NavigationMenu
- **Status**: Not found in codebase
- **Note**: Component mentioned in issue list but doesn't exist, no action needed

## Application Instructions

1. **Backup** AllComponents.ps1 before making changes

2. **Apply fixes** in this order:
   - CommandPalette.HandleInput method
   - MultilineTextBoxComponent (entire class)
   - Panel (entire class)
   - GroupPanel (entire class)
   - DateInputComponent.OnRender method

3. **Verify** by searching for remaining [ConsoleColor] usage:
   ```powershell
   Select-String -Path AllComponents.ps1 -Pattern "\[ConsoleColor\]"
   ```

4. **Test** the application to ensure:
   - Command Palette opens without errors (Ctrl+P)
   - All components render correctly with proper colors
   - No type mismatch errors in the console

## Color Reference
Common ConsoleColor to Hex conversions used:
- Black: "#000000"
- White: "#FFFFFF"
- Gray: "#808080"
- DarkCyan: "#008B8B"
- Cyan: "#00FFFF"
- Yellow: "#FFFF00"
- DarkBlue: "#00008B"

## Notes
- All color properties should use [string] type with hex values
- Use Get-ThemeColor function for theme-aware colors
- Provide default hex colors as fallbacks
- The rendering system only accepts hex strings, not ConsoleColor enums
