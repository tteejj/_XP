# ==============================================================================
# Axiom-Phoenix v4.0 - All Services (Load After Components)
# Core application services: action, navigation, data, theming, logging, events
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASE.###" to find specific sections.
# Each section ends with "END_PAGE: ASE.###"
# ==============================================================================

#region KeybindingService Class

# ===== CLASS: KeybindingService =====
# Module: keybinding-service (from axiom)
# Dependencies: ActionService (optional)
# Purpose: Global keyboard shortcut management
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
        # Default global bindings
        $this.SetBinding("Ctrl+Q", "app.exit", "Global")
        $this.SetBinding("F1", "app.help", "Global")
        $this.SetBinding("Ctrl+P", "app.commandPalette", "Global")
        
        # Navigation bindings
        $this.SetBinding("Tab", "navigation.nextComponent", "Global")
        $this.SetBinding("Shift+Tab", "navigation.previousComponent", "Global")
        
        # Arrow keys removed - handled by focused components instead
        
        # Write-Verbose "KeybindingService: Initialized default keybindings"
    }
    
    [void] SetBinding([string]$keyPattern, [string]$actionName, [string]$context = "Global") {
        if (-not $this.KeyMap.ContainsKey($context)) {
            $this.KeyMap[$context] = @{}
        }
        
        $this.KeyMap[$context][$keyPattern] = $actionName
        # Write-Verbose "KeybindingService: Bound '$keyPattern' to '$actionName' in context '$context'"
    }
    
    [void] RemoveBinding([string]$keyPattern, [string]$context = "Global") {
        if ($this.KeyMap.ContainsKey($context)) {
            $this.KeyMap[$context].Remove($keyPattern)
            # Write-Verbose "KeybindingService: Removed binding for '$keyPattern' in context '$context'"
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
    
    [string] GetAction([System.ConsoleKeyInfo]$keyInfo) {
        $keyPattern = $this._GetKeyPattern($keyInfo)
        
        # Log key pattern for debugging
        if ($keyPattern -match "Ctrl") {
            Write-Log -Level Debug -Message "KeybindingService: Key pattern detected: $keyPattern"
        }
        
        # Check current context stack (most recent first)
        foreach ($context in $this.ContextStack) {
            if ($context.ContainsKey($keyPattern)) {
                Write-Log -Level Debug -Message "KeybindingService: Found action in context: $($context[$keyPattern])"
                return $context[$keyPattern]
            }
        }
        
        # Check global context
        if ($this.KeyMap.ContainsKey("Global") -and $this.KeyMap["Global"].ContainsKey($keyPattern)) {
            Write-Log -Level Debug -Message "KeybindingService: Found action in global context: $($this.KeyMap["Global"][$keyPattern])"
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
        return $null
    }
    
    hidden [string] _GetKeyPattern([System.ConsoleKeyInfo]$keyInfo) {
        $parts = @()
        
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) {
            $parts += "Ctrl"
        }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) {
            $parts += "Alt"
        }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) {
            $parts += "Shift"
        }
        
        $parts += $keyInfo.Key.ToString()
        
        return $parts -join "+"
    }
    
    [void] PushContext([hashtable]$contextBindings) {
        $this.ContextStack.Push($contextBindings)
        # Write-Verbose "KeybindingService: Pushed new context with $($contextBindings.Count) bindings"
    }
    
    [void] PopContext() {
        if ($this.ContextStack.Count -gt 0) {
            $removed = $this.ContextStack.Pop()
            # Write-Verbose "KeybindingService: Popped context with $($removed.Count) bindings"
        }
    }
    
    [void] RegisterGlobalHandler([string]$handlerId, [scriptblock]$handler) {
        $this.GlobalHandlers[$handlerId] = $handler
        # Write-Verbose "KeybindingService: Registered global handler '$handlerId'"
    }
    
    [void] UnregisterGlobalHandler([string]$handlerId) {
        $this.GlobalHandlers.Remove($handlerId)
        # Write-Verbose "KeybindingService: Unregistered global handler '$handlerId'"
    }
    
    [void] SetDefaultBindings() {
        # Application control
        $this.SetBinding("Ctrl+Q", "app.exit", "Global")
        $this.SetBinding("Escape", "app.cancel", "Global")
        $this.SetBinding("F1", "app.help", "Global")
        $this.SetBinding("Ctrl+P", "app.commandPalette", "Global")
        
        # Navigation
        $this.SetBinding("Tab", "nav.nextField", "Global")
        $this.SetBinding("Shift+Tab", "nav.previousField", "Global")
        $this.SetBinding("Enter", "nav.select", "Global")
        $this.SetBinding("Space", "nav.toggle", "Global")
        
        # Movement
        $this.SetBinding("UpArrow", "nav.up", "Global")
        $this.SetBinding("DownArrow", "nav.down", "Global")
        $this.SetBinding("LeftArrow", "nav.left", "Global")
        $this.SetBinding("RightArrow", "nav.right", "Global")
        $this.SetBinding("PageUp", "nav.pageUp", "Global")
        $this.SetBinding("PageDown", "nav.pageDown", "Global")
        $this.SetBinding("Home", "nav.home", "Global")
        $this.SetBinding("End", "nav.end", "Global")
        
        # Screen navigation
        $this.SetBinding("Ctrl+N", "screen.new", "Global")
        $this.SetBinding("Ctrl+D", "screen.dashboard", "Global")
        $this.SetBinding("Ctrl+T", "screen.tasks", "Global")
        $this.SetBinding("Ctrl+B", "nav.back", "Global")
    }
    
    [void] Cleanup() {
        $this.KeyMap.Clear()
        $this.GlobalHandlers.Clear()
        $this.ContextStack.Clear()
    }
}

#endregion
#<!-- END_PAGE: ASE.002 -->
