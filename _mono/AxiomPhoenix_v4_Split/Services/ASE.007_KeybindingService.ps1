# ==============================================================================
# Axiom-Phoenix v4.0 - KeybindingService
# Global keyboard shortcut management
# ==============================================================================

class KeybindingService {
    [hashtable]$KeyMap = @{}
    [hashtable]$GlobalHandlers = @{}
    [System.Collections.Generic.Stack[hashtable]]$ContextStack
    [ActionService]$ActionService
    [bool]$EnableChords = $false
    
    KeybindingService() {
        $this.ContextStack = [System.Collections.Generic.Stack[hashtable]]::new()
        $this._InitializeDefaultBindings()
    }
    
    KeybindingService([ActionService]$actionService) {
        $this.ActionService = $actionService
        $this.ContextStack = [System.Collections.Generic.Stack[hashtable]]::new()
        $this._InitializeDefaultBindings()
    }
    
    hidden [void] _InitializeDefaultBindings() {
        # Global navigation
        $this.SetBinding("Ctrl+Q", "app.exit", "Global")
        $this.SetBinding("Ctrl+C", "app.exit.ctrlc", "Global")
        $this.SetBinding("F1", "app.help", "Global")
        $this.SetBinding("Ctrl+P", "app.commandPalette", "Global")
        
        # Tab navigation - but DON'T bind number keys globally
        $this.SetBinding("Tab", "navigation.nextComponent", "Global")
        $this.SetBinding("Shift+Tab", "navigation.previousComponent", "Global")
        
        # Arrow keys removed - handled by focused components instead
        
        Write-Log -Level Debug -Message "KeybindingService: Initialized default bindings"
    }
    
    [void] SetBinding([string]$keyPattern, [string]$actionName, [string]$context = "Global") {
        if (-not $this.KeyMap.ContainsKey($context)) {
            $this.KeyMap[$context] = @{}
        }
        
        $this.KeyMap[$context][$keyPattern] = $actionName
        Write-Log -Level Debug -Message "KeybindingService: Bound $keyPattern to $actionName in context $context"
    }
    
    [void] RemoveBinding([string]$keyPattern, [string]$context = "Global") {
        if ($this.KeyMap.ContainsKey($context)) {
            $this.KeyMap[$context].Remove($keyPattern)
            Write-Log -Level Debug -Message "KeybindingService: Removed binding for $keyPattern from context $context"
        }
    }
    
    [bool] IsAction([System.ConsoleKeyInfo]$keyInfo, [string]$actionName) {
        $keyPattern = $this._GetKeyPattern($keyInfo)
        
        # Check current context stack
        foreach ($context in $this.ContextStack) {
            if ($context.ContainsKey($keyPattern) -and $context[$keyPattern] -eq $actionName) {
                return $true
            }
        }
        
        # Check global context
        if ($this.KeyMap.ContainsKey("Global") -and 
            $this.KeyMap["Global"].ContainsKey($keyPattern) -and 
            $this.KeyMap["Global"][$keyPattern] -eq $actionName) {
            return $true
        }
        
        return $false
    }
    
    # Defensive overload to catch incorrect calls with stack trace
    [bool] IsAction([System.ConsoleKeyInfo]$keyInfo) {
        $stack = Get-PSCallStack
        $caller = "Unknown"
        if ($stack.Count -gt 1) { $caller = $stack[1].Command }
        Write-Log -Level Warning -Message "IsAction called with only 1 parameter from: $caller. This is incorrect usage - IsAction requires (keyInfo, actionName)"
        
        # Log the full stack for debugging
        Write-Log -Level Debug -Message "Full stack trace:"
        foreach ($frame in $stack) {
            Write-Log -Level Debug -Message "  - $($frame.Command) at $($frame.Location)"
        }
        
        return $false
    }
    
    [string] GetAction([System.ConsoleKeyInfo]$keyInfo) {
        $keyPattern = $this._GetKeyPattern($keyInfo)
        
        # Log key pattern for debugging
        if ($keyPattern -match "Ctrl") {
            Write-Log -Level Debug -Message "KeybindingService: Looking up action for $keyPattern"
        }
        
        # Check current context stack (most recent first)
        foreach ($context in $this.ContextStack) {
            if ($context.ContainsKey($keyPattern)) {
                Write-Log -Level Debug -Message "KeybindingService: Found action in context stack: $($context[$keyPattern])"
                return $context[$keyPattern]
            }
        }
        
        # Check global context
        if ($this.KeyMap.ContainsKey("Global") -and $this.KeyMap["Global"].ContainsKey($keyPattern)) {
            Write-Log -Level Debug -Message "KeybindingService: Found global action: $($this.KeyMap["Global"][$keyPattern])"
            return $this.KeyMap["Global"][$keyPattern]
        }
        
        return $null
    }
    
    [string] GetBindingDescription([System.ConsoleKeyInfo]$keyInfo) {
        $action = $this.GetAction($keyInfo)
        if ($action -and $this.ActionService) {
            $actionData = $this.ActionService.GetAction($action)
            if ($actionData) {
                return $actionData.Description
            }
        }
        return ""
    }
    
    hidden [string] _GetKeyPattern([System.ConsoleKeyInfo]$keyInfo) {
        $parts = @()
        
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
        }
        elseif ($keyInfo.KeyChar -ne [char]0) {
            $parts += [char]::ToUpper($keyInfo.KeyChar).ToString()
        }
        
        return $parts -join "+"
    }
    
    [void] PushContext([hashtable]$contextBindings) {
        $this.ContextStack.Push($contextBindings)
        Write-Log -Level Debug -Message "KeybindingService: Pushed new context with $($contextBindings.Count) bindings"
    }
    
    [void] PopContext() {
        if ($this.ContextStack.Count -gt 0) {
            $removed = $this.ContextStack.Pop()
            Write-Log -Level Debug -Message "KeybindingService: Popped context with $($removed.Count) bindings"
        }
    }
    
    [void] RegisterGlobalHandler([string]$handlerId, [scriptblock]$handler) {
        $this.GlobalHandlers[$handlerId] = $handler
        Write-Log -Level Debug -Message "KeybindingService: Registered global handler $handlerId"
    }
    
    [void] UnregisterGlobalHandler([string]$handlerId) {
        $this.GlobalHandlers.Remove($handlerId)
        Write-Log -Level Debug -Message "KeybindingService: Unregistered global handler $handlerId"
    }
    
    [void] SetDefaultBindings() {
        # Application control
        $this.SetBinding("Ctrl+Q", "app.exit", "Global")
        $this.SetBinding("F1", "app.help", "Global")
        $this.SetBinding("Ctrl+P", "app.commandPalette", "Global")
        
        # Tools
        $this.SetBinding("F9", "tools.fileCommander", "Global")
        $this.SetBinding("Ctrl+E", "tools.textEditor", "Global")
        
        # Screen navigation
        $this.SetBinding("Escape", "navigation.back", "Global")
        
        Write-Log -Level Debug -Message "KeybindingService: Set default bindings"
    }
}

#endregion
