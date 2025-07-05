# keybinding-service-class.psm1
# FIX: Consolidated SetBinding and improved type safety.

using module logger
using module exceptions

class KeybindingService {
    [hashtable] $KeyMap = @{}
    [hashtable] $GlobalHandlers = @{}
    [System.Collections.Generic.List[string]] $ContextStack
    [bool] $EnableChords = $false

    KeybindingService() {
        $this.ContextStack = [System.Collections.Generic.List[string]]::new()
        $this.InitializeDefaultBindings()
        Write-Log -Level Info -Message "KeybindingService initialized"
    }

    KeybindingService([bool]$enableChords) {
        $this.ContextStack = [System.Collections.Generic.List[string]]::new()
        $this.EnableChords = $enableChords
        $this.InitializeDefaultBindings()
        Write-Log -Level Info -Message "KeybindingService initialized with chords: $enableChords"
    }

    hidden [void] InitializeDefaultBindings() {
        $this.KeyMap = @{
            "app.exit" = @{ Key = [System.ConsoleKey]::Q; Modifiers = @("Ctrl") }
            "app.help" = @{ Key = [System.ConsoleKey]::F1; Modifiers = @() }
            "nav.back" = @{ Key = [System.ConsoleKey]::Escape; Modifiers = @() }
            "nav.up" = @{ Key = [System.ConsoleKey]::UpArrow; Modifiers = @() }
            "nav.down" = @{ Key = [System.ConsoleKey]::DownArrow; Modifiers = @() }
            "nav.left" = @{ Key = [System.ConsoleKey]::LeftArrow; Modifiers = @() }
            "nav.right" = @{ Key = [System.ConsoleKey]::RightArrow; Modifiers = @() }
            "nav.select" = @{ Key = [System.ConsoleKey]::Enter; Modifiers = @() }
            "nav.pageup" = @{ Key = [System.ConsoleKey]::PageUp; Modifiers = @() }
            "nav.pagedown" = @{ Key = [System.ConsoleKey]::PageDown; Modifiers = @() }
            "nav.home" = @{ Key = [System.ConsoleKey]::Home; Modifiers = @() }
            "nav.end" = @{ Key = [System.ConsoleKey]::End; Modifiers = @() }
            "nav.tab" = @{ Key = [System.ConsoleKey]::Tab; Modifiers = @() }
            "nav.shifttab" = @{ Key = [System.ConsoleKey]::Tab; Modifiers = @("Shift") }
            "edit.delete" = @{ Key = [System.ConsoleKey]::Delete; Modifiers = @() }
            "edit.backspace" = @{ Key = [System.ConsoleKey]::Backspace; Modifiers = @() }
            "edit.new" = @{ Key = [System.ConsoleKey]::N; Modifiers = @() }
            "edit.save" = @{ Key = [System.ConsoleKey]::S; Modifiers = @("Ctrl") }
            "app.refresh" = @{ Key = [System.ConsoleKey]::F5; Modifiers = @() }
        }
    }

    # FIX: Consolidated SetBinding into a single method to remove ambiguity.
    [void] SetBinding([string]$actionName, [object]$key, [string[]]$modifiers) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "SetBinding:$actionName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                throw [System.ArgumentException]::new("Action name cannot be null or empty", "actionName")
            }
            if ($null -eq $key) {
                throw [System.ArgumentNullException]::new("key", "Key cannot be null")
            }

            $binding = @{
                Modifiers = if ($modifiers) { @($modifiers) } else { @() }
            }

            # Intelligently handle the key type.
            if ($key -is [System.ConsoleKey]) {
                $binding.Key = $key
            } elseif ($key -is [char]) {
                $binding.KeyChar = $key
            } else {
                # Attempt to parse as ConsoleKey if it's a string.
                try {
                    $binding.Key = [System.ConsoleKey]::$key
                } catch {
                    throw [System.ArgumentException]::new("The provided key '$key' is not a valid [System.ConsoleKey] or [char].")
                }
            }

            $this.KeyMap[$actionName.ToLower()] = $binding
            Write-Log -Level Debug -Message "Set keybinding: $actionName -> $($this.GetBindingDescription($actionName))"
        }
    }
    
    [void] SetBinding([string]$actionName, [System.ConsoleKeyInfo]$keyInfo) {
        if ([string]::IsNullOrWhiteSpace($actionName)) {
            throw [System.ArgumentException]::new("Action name cannot be null or empty", "actionName")
        }

        $modifiers = @()
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) { $modifiers += "Ctrl" }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) { $modifiers += "Alt" }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) { $modifiers += "Shift" }

        $this.KeyMap[$actionName.ToLower()] = @{
            Key = $keyInfo.Key
            KeyChar = $keyInfo.KeyChar
            Modifiers = $modifiers
        }
        Write-Log -Level Debug -Message "Set keybinding for '$actionName': $($this.GetBindingDescription($actionName))"
    }

    [void] RemoveBinding([string]$actionName) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "RemoveBinding:$actionName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                return
            }

            $normalizedName = $actionName.ToLower()
            if ($this.KeyMap.ContainsKey($normalizedName)) {
                $this.KeyMap.Remove($normalizedName)
                Write-Log -Level Debug -Message "Removed keybinding: $actionName"
            }
        }
    }

    [bool] IsAction([string]$actionName, [System.ConsoleKeyInfo]$keyInfo) {
        return $this.IsAction($actionName, $keyInfo, $null)
    }

    [bool] IsAction([string]$actionName, [System.ConsoleKeyInfo]$keyInfo, [string]$context) {
        return Invoke-WithErrorHandling -Component "KeybindingService" -Context "IsAction:$actionName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                return $false
            }

            $normalizedName = $actionName.ToLower()
            if (-not $this.KeyMap.ContainsKey($normalizedName)) {
                return $false
            }

            $binding = $this.KeyMap[$normalizedName]

            # FIX: Unified key matching logic
            $keyMatches = $false
            if ($binding.ContainsKey('KeyChar')) {
                # KeyChar binding is more specific.
                # KeyChar matching should be case-sensitive.
                if ($keyInfo.KeyChar -eq $binding.KeyChar) {
                    $keyMatches = $true
                }
            }
            if (-not $keyMatches -and $binding.ContainsKey('Key')) {
                 # Fallback to ConsoleKey if KeyChar doesn't match or isn't present
                if ($keyInfo.Key -eq $binding.Key) {
                    $keyMatches = $true
                }
            }
            
            if (-not $keyMatches) {
                return $false
            }

            # Check modifiers
            $hasCtrl = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) -ne 0
            $hasAlt = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) -ne 0
            $hasShift = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) -ne 0

            $expectedCtrl = $binding.Modifiers -contains "Ctrl"
            $expectedAlt = $binding.Modifiers -contains "Alt"
            $expectedShift = $binding.Modifiers -contains "Shift"

            return ($hasCtrl -eq $expectedCtrl) -and ($hasAlt -eq $expectedAlt) -and ($hasShift -eq $expectedShift)
        }
    }

    [string] GetAction([System.ConsoleKeyInfo]$keyInfo) {
        return Invoke-WithErrorHandling -Component "KeybindingService" -Context "GetAction" -ScriptBlock {
            foreach ($actionName in $this.KeyMap.Keys) {
                if ($this.IsAction($actionName, $keyInfo)) {
                    return $actionName
                }
            }
            return $null
        }
    }

    [void] RegisterGlobalHandler([string]$actionName, [scriptblock]$handler) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "RegisterGlobalHandler:$actionName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                throw [System.ArgumentException]::new("Action name cannot be null or empty", "actionName")
            }
            if ($null -eq $handler) {
                throw [System.ArgumentNullException]::new("handler", "Handler cannot be null")
            }

            $this.GlobalHandlers[$actionName.ToLower()] = $handler
            Write-Log -Level Debug -Message "Registered global handler: $actionName"
        }
    }

    [object] HandleKey([System.ConsoleKeyInfo]$keyInfo) {
        return $this.HandleKey($keyInfo, $null)
    }

    [object] HandleKey([System.ConsoleKeyInfo]$keyInfo, [string]$context) {
        return Invoke-WithErrorHandling -Component "KeybindingService" -Context "HandleKey" -ScriptBlock {
            foreach ($action in $this.KeyMap.Keys) {
                if ($this.IsAction($action, $keyInfo, $context)) {
                    if ($this.GlobalHandlers.ContainsKey($action)) {
                        Write-Log -Level Debug -Message "Executing global handler: $action"
                        try {
                            return & $this.GlobalHandlers[$action] -KeyInfo $keyInfo -Context $context
                        }
                        catch {
                            Write-Log -Level Error -Message "Global handler failed for '$action': $_"
                            return $null
                        }
                    }
                    return $action
                }
            }
            return $null
        }
    }

    [void] PushContext([string]$context) {
        if (-not [string]::IsNullOrWhiteSpace($context)) {
            $this.ContextStack.Add($context)
            Write-Log -Level Debug -Message "Pushed keybinding context: $context (Stack depth: $($this.ContextStack.Count))"
        }
    }

    [string] PopContext() {
        if ($this.ContextStack.Count -gt 0) {
            $context = $this.ContextStack[-1]
            $this.ContextStack.RemoveAt($this.ContextStack.Count - 1)
            Write-Log -Level Debug -Message "Popped keybinding context: $context (Stack depth: $($this.ContextStack.Count))"
            return $context
        }
        return $null
    }

    [string] GetCurrentContext() {
        if ($this.ContextStack.Count -gt 0) {
            return $this.ContextStack[-1]
        }
        return "global"
    }

    [string] GetBindingDescription([string]$actionName) {
        if ([string]::IsNullOrWhiteSpace($actionName)) {
            return $null
        }

        $normalizedName = $actionName.ToLower()
        if (-not $this.KeyMap.ContainsKey($normalizedName)) {
            return "Unbound"
        }

        $binding = $this.KeyMap[$normalizedName]
        $keyStr = ""
        if ($binding.ContainsKey('KeyChar')) {
            $keyStr = $binding.KeyChar.ToString().ToUpper()
        } elseif ($binding.ContainsKey('Key')) {
            $keyStr = $binding.Key.ToString()
        }

        if ($binding.Modifiers.Count -gt 0) {
            return "$($binding.Modifiers -join '+') + $keyStr"
        }

        return $keyStr
    }

    [hashtable] GetAllBindings() {
        return $this.GetAllBindings($false)
    }

    [hashtable] GetAllBindings([bool]$groupByCategory) {
        if (-not $groupByCategory) {
            return $this.KeyMap.Clone()
        }
        
        $grouped = @{}
        foreach ($action in $this.KeyMap.Keys) {
            $parts = $action.Split('.')
            $category = if ($parts.Count -gt 1) { $parts[0] } else { "General" }
            if (-not $grouped.ContainsKey($category)) {
                $grouped[$category] = @{}
            }
            $grouped[$category][$action] = $this.KeyMap[$action]
        }
        return $grouped
    }

    [void] ExportBindings([string]$path) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "ExportBindings" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($path)) {
                throw [System.ArgumentException]::new("Path cannot be null or empty", "path")
            }
            $this.KeyMap | ConvertTo-Json -Depth 3 | Out-File -FilePath $path -Encoding UTF8
            Write-Log -Level Info -Message "Exported keybindings to: $path"
        }
    }

    [void] ImportBindings([string]$path) {
        Invoke-WithErrorHandling -Component "KeybindingService" -Context "ImportBindings" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($path)) {
                throw [System.ArgumentException]::new("Path cannot be null or empty", "path")
            }
            if (-not (Test-Path $path)) {
                Write-Log -Level Warning -Message "Keybindings file not found: $path"
                return
            }
            try {
                $imported = Get-Content $path -Raw | ConvertFrom-Json
                foreach ($prop in $imported.PSObject.Properties) {
                    $bindingData = @{
                        Modifiers = $prop.Value.Modifiers
                    }
                    if ($prop.Value.PSObject.Properties.Name -contains 'KeyChar') {
                        $bindingData['KeyChar'] = $prop.Value.KeyChar
                    }
                    if ($prop.Value.PSObject.Properties.Name -contains 'Key') {
                        $bindingData['Key'] = $prop.Value.Key
                    }
                    $this.KeyMap[$prop.Name] = $bindingData
                }
                Write-Log -Level Info -Message "Imported keybindings from: $path"
            }
            catch {
                Write-Log -Level Error -Message "Failed to import keybindings from '$path': $_"
                throw
            }
        }
    }
}