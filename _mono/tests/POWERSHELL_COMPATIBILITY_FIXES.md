# PowerShell 5.1 Compatibility Fixes

## Issue
The null-conditional operator (`?.`) and null-coalescing operator (`??`) are only available in PowerShell 7.0+. Using these operators in older versions causes parse errors.

## Files Fixed

### 1. Services/ASE.006_FocusManager.ps1
- Line 131: `$($this.FocusedComponent?.Name ?? 'null')` → Replaced with conditional check
- Line 140: `$($previousFocus?.Name ?? 'null')` → Replaced with conditional check

### 2. Services/ASE.004_ActionService.ps1
- Line 192: `$global:TuiState.Services.EventManager?.Publish()` → Replaced with if check

### 3. Components/ACO.014a_Dialog.ps1
- Line 77: `$this.ServiceContainer?.GetService()` → Replaced with null check
- Line 118: `$this.ServiceContainer?.GetService()` → Replaced with null check  
- Line 158: `$this.ServiceContainer?.GetService()` → Replaced with null check

### 4. Test-WindowModel.ps1 (Test script)
- Multiple lines: Replaced all `?.` and `??` operators with conditional checks

## Pattern Used
Instead of:
```powershell
$object?.Property ?? 'default'
```

Use:
```powershell
if ($null -ne $object) { $object.Property } else { 'default' }
```

Or for simple cases:
```powershell
$value = if ($null -ne $object) { $object.Property } else { 'default' }
```

## Verification
The framework should now load successfully in PowerShell 5.1 and newer versions.
