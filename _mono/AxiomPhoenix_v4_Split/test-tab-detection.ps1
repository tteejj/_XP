#!/usr/bin/env pwsh

# Test script to verify Tab key detection in the focus system

# Mock the basic classes and services we need
class MockServiceContainer {
    [hashtable]$services = @{}
    
    [object] GetService([string]$name) {
        return $this.services[$name]
    }
    
    [void] RegisterService([string]$name, [object]$service) {
        $this.services[$name] = $service
    }
}

class MockKeybindingService {
    [hashtable]$KeyMap = @{ 
        "Global" = @{
            "Tab" = "navigation.nextComponent"
            "Shift+Tab" = "navigation.previousComponent"
        }
    }
    
    [string] GetAction([System.ConsoleKeyInfo]$keyInfo) {
        $keyPattern = $this._GetKeyPattern($keyInfo)
        Write-Host "DEBUG: KeyPattern for input: '$keyPattern'"
        
        if ($this.KeyMap["Global"].ContainsKey($keyPattern)) {
            $action = $this.KeyMap["Global"][$keyPattern]
            Write-Host "DEBUG: Found action: '$action'"
            return $action
        }
        
        Write-Host "DEBUG: No action found for pattern: '$keyPattern'"
        return $null
    }
    
    hidden [string] _GetKeyPattern([System.ConsoleKeyInfo]$keyInfo) {
        $parts = @()
        
        Write-Host "DEBUG: KeyInfo - Key: $($keyInfo.Key), KeyChar: '$($keyInfo.KeyChar)', Modifiers: $($keyInfo.Modifiers)"
        
        if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
            $parts += "Ctrl"
        }
        if ($keyInfo.Modifiers -band [ConsoleModifiers]::Alt) {
            $parts += "Alt"
        }
        if ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) {
            $parts += "Shift"
        }
        
        # Use Key enum for special keys, KeyChar for regular characters
        if ($keyInfo.Key -ne [ConsoleKey]::None -and 
            ($keyInfo.Key -lt [ConsoleKey]::D0 -or $keyInfo.Key -gt [ConsoleKey]::Z)) {
            $parts += $keyInfo.Key.ToString()
            Write-Host "DEBUG: Using Key enum: $($keyInfo.Key)"
        }
        elseif ($keyInfo.KeyChar -ne [char]0) {
            $parts += [char]::ToUpper($keyInfo.KeyChar).ToString()
            Write-Host "DEBUG: Using KeyChar: '$($keyInfo.KeyChar)'"
        }
        
        $pattern = $parts -join "+"
        Write-Host "DEBUG: Final pattern: '$pattern'"
        return $pattern
    }
}

class MockActionService {
    [void] ExecuteAction([string]$actionName, [hashtable]$parameters) {
        Write-Host "ACTION EXECUTED: $actionName"
    }
}

# Test function that simulates Process-TuiInput logic
function Test-TabProcessing {
    param([System.ConsoleKeyInfo]$KeyInfo)
    
    Write-Host "`n=== TESTING TAB KEY PROCESSING ===" -ForegroundColor Yellow
    
    # Create mock services
    $container = [MockServiceContainer]::new()
    $keybindingService = [MockKeybindingService]::new()
    $actionService = [MockActionService]::new()
    
    $container.RegisterService("KeybindingService", $keybindingService)
    $container.RegisterService("ActionService", $actionService)
    
    # Simulate the Process-TuiInput global hotkey check
    Write-Host "`n1. Checking global hotkeys..." -ForegroundColor Cyan
    $actionName = $keybindingService.GetAction($KeyInfo)
    if ($actionName) {
        Write-Host "2. Global hotkey detected: $actionName" -ForegroundColor Green
        $actionService.ExecuteAction($actionName, @{KeyInfo = $KeyInfo})
        Write-Host "3. Tab should be handled at global level - SUCCESS!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "2. NO global hotkey detected - Tab will fall through to screen!" -ForegroundColor Red
        Write-Host "3. This will cause the circular call issue!" -ForegroundColor Red
        return $false
    }
}

# Test Tab key
Write-Host "Testing regular Tab key:" -ForegroundColor White
$tabKey = [System.ConsoleKeyInfo]::new([char]9, [ConsoleKey]::Tab, $false, $false, $false)
Test-TabProcessing -KeyInfo $tabKey

# Test Shift+Tab key  
Write-Host "`n`nTesting Shift+Tab key:" -ForegroundColor White
$shiftTabKey = [System.ConsoleKeyInfo]::new([char]9, [ConsoleKey]::Tab, $true, $false, $false)
Test-TabProcessing -KeyInfo $shiftTabKey

Write-Host "`n=== TEST COMPLETE ===" -ForegroundColor Yellow