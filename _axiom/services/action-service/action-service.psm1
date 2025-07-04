# ==============================================================================
# PMC Terminal Axiom-Phoenix v4.0 - Action Service Module
# ==============================================================================
# Purpose: Central registry for all application actions and commands
# Features:
#   - Register actions with metadata (name, group, description, hotkey)
#   - Search and filter actions
#   - Execute actions with context
#   - Support for global hotkeys
#   - Integration with command palette
# ==============================================================================

using namespace System
using namespace System.Collections.Generic

# Action metadata class
class Action {
    [string] $Id
    [string] $Name
    [string] $Group
    [string] $Description
    [scriptblock] $Handler
    [string] $Hotkey
    [bool] $Enabled
    [hashtable] $Metadata
    [string[]] $Tags
    [DateTime] $RegisteredAt
    
    Action() {
        $this.Enabled = $true
        $this.Metadata = @{}
        $this.Tags = @()
        $this.RegisteredAt = [DateTime]::Now
    }
    
    [string] ToString() {
        if ($this.Hotkey) {
            return "$($this.Name) ($($this.Hotkey))"
        }
        return $this.Name
    }
    
    [string] GetSearchText() {
        # Combine all searchable fields for fuzzy matching
        return "$($this.Name) $($this.Group) $($this.Description) $($this.Tags -join ' ')"
    }
}

# Main action service class
class ActionService {
    hidden [Dictionary[string, Action]] $actions
    hidden [Dictionary[string, List[Action]]] $groupedActions
    hidden [Dictionary[string, Action]] $hotkeyMap
    hidden [List[string]] $executionHistory
    hidden [int] $maxHistorySize
    
    ActionService() {
        $this.actions = [Dictionary[string, Action]]::new()
        $this.groupedActions = [Dictionary[string, List[Action]]]::new()
        $this.hotkeyMap = [Dictionary[string, Action]]::new()
        $this.executionHistory = [List[string]]::new()
        $this.maxHistorySize = 50
        
        # Register default action groups
        $this.EnsureGroup("Navigation")
        $this.EnsureGroup("File")
        $this.EnsureGroup("Edit")
        $this.EnsureGroup("View")
        $this.EnsureGroup("Task")
        $this.EnsureGroup("Project")
        $this.EnsureGroup("System")
        $this.EnsureGroup("Help")
    }
    
    # Register a new action
    [void] RegisterAction([string]$id, [string]$name, [string]$group, [scriptblock]$handler) {
        $this.RegisterAction($id, $name, $group, "", $handler, $null)
    }
    
    # Register a new action with full metadata
    [void] RegisterAction([string]$id, [string]$name, [string]$group, [string]$description, [scriptblock]$handler, [string]$hotkey) {
        if ([string]::IsNullOrWhiteSpace($id)) {
            throw "Action ID cannot be empty"
        }
        
        if ($this.actions.ContainsKey($id)) {
            throw "Action with ID '$id' is already registered"
        }
        
        $action = [Action]::new()
        $action.Id = $id
        $action.Name = $name
        $action.Group = $group
        $action.Description = $description
        $action.Handler = $handler
        $action.Hotkey = $hotkey
        
        # Add to main registry
        $this.actions[$id] = $action
        
        # Add to group index
        $this.EnsureGroup($group)
        $this.groupedActions[$group].Add($action)
        
        # Add to hotkey map if applicable
        if (-not [string]::IsNullOrWhiteSpace($hotkey)) {
            if ($this.hotkeyMap.ContainsKey($hotkey)) {
                Write-Log -Level Warning -Message "Hotkey '$hotkey' is already mapped to action '$($this.hotkeyMap[$hotkey].Name)'"
            }
            else {
                $this.hotkeyMap[$hotkey] = $action
            }
        }
        
        Write-Log -Level Debug -Message "Registered action '$name' (ID: $id) in group '$group'"
        
        # Publish event for other components to react
        Publish-Event -EventName "Action.Registered" -Data @{
            ActionId = $id
            ActionName = $name
            Group = $group
        }
    }
    
    # Unregister an action
    [void] UnregisterAction([string]$id) {
        if (-not $this.actions.ContainsKey($id)) {
            return
        }
        
        $action = $this.actions[$id]
        
        # Remove from group
        if ($this.groupedActions.ContainsKey($action.Group)) {
            [void]$this.groupedActions[$action.Group].Remove($action)
        }
        
        # Remove from hotkey map
        if ($action.Hotkey -and $this.hotkeyMap.ContainsKey($action.Hotkey)) {
            [void]$this.hotkeyMap.Remove($action.Hotkey)
        }
        
        # Remove from main registry
        [void]$this.actions.Remove($id)
        
        Write-Log -Level Debug -Message "Unregistered action '$($action.Name)' (ID: $id)"
    }
    
    # Execute an action by ID
    [object] ExecuteAction([string]$id) {
        return $this.ExecuteAction($id, @{})
    }
    
    # Execute an action by ID with context
    [object] ExecuteAction([string]$id, [hashtable]$context) {
        if (-not $this.actions.ContainsKey($id)) {
            throw "Action with ID '$id' not found"
        }
        
        $action = $this.actions[$id]
        
        if (-not $action.Enabled) {
            Write-Log -Level Warning -Message "Attempted to execute disabled action '$($action.Name)'"
            return $null
        }
        
        try {
            Write-Log -Level Debug -Message "Executing action '$($action.Name)' (ID: $id)"
            
            # Add to history
            $this.AddToHistory($id)
            
            # Execute the handler with context
            $result = & $action.Handler $context
            
            # Publish execution event
            Publish-Event -EventName "Action.Executed" -Data @{
                ActionId = $id
                ActionName = $action.Name
                Context = $context
                Success = $true
            }
            
            return $result
        }
        catch {
            Write-Log -Level Error -Message "Failed to execute action '$($action.Name)': $_"
            
            Publish-Event -EventName "Action.Executed" -Data @{
                ActionId = $id
                ActionName = $action.Name
                Context = $context
                Success = $false
                Error = $_.Exception.Message
            }
            
            throw
        }
    }
    
    # Execute an action by hotkey
    [object] ExecuteHotkey([string]$hotkey) {
        return $this.ExecuteHotkey($hotkey, @{})
    }
    
    # Execute an action by hotkey with context
    [object] ExecuteHotkey([string]$hotkey, [hashtable]$context) {
        if (-not $this.hotkeyMap.ContainsKey($hotkey)) {
            return $null
        }
        
        $action = $this.hotkeyMap[$hotkey]
        return $this.ExecuteAction($action.Id, $context)
    }
    
    # Get action by ID
    [Action] GetAction([string]$id) {
        if ($this.actions.ContainsKey($id)) {
            return $this.actions[$id]
        }
        return $null
    }
    
    # Get all actions
    [Action[]] GetAllActions() {
        return $this.actions.Values
    }
    
    # Get actions by group
    [Action[]] GetActionsByGroup([string]$group) {
        if ($this.groupedActions.ContainsKey($group)) {
            return $this.groupedActions[$group].ToArray()
        }
        return @()
    }
    
    # Get all groups
    [string[]] GetGroups() {
        return $this.groupedActions.Keys | Sort-Object
    }
    
    # Search actions
    [Action[]] SearchActions([string]$query) {
        if ([string]::IsNullOrWhiteSpace($query)) {
            return $this.GetAllActions()
        }
        
        $results = [List[Action]]::new()
        $lowerQuery = $query.ToLower()
        
        foreach ($action in $this.actions.Values) {
            $searchText = $action.GetSearchText().ToLower()
            if ($searchText.Contains($lowerQuery)) {
                $results.Add($action)
            }
        }
        
        # Sort by relevance (simple scoring based on where match appears)
        $scored = $results | ForEach-Object {
            $score = 0
            if ($_.Name.ToLower().StartsWith($lowerQuery)) { $score += 10 }
            elseif ($_.Name.ToLower().Contains($lowerQuery)) { $score += 5 }
            if ($_.Group.ToLower().Contains($lowerQuery)) { $score += 3 }
            if ($_.Description.ToLower().Contains($lowerQuery)) { $score += 1 }
            
            [PSCustomObject]@{
                Action = $_
                Score = $score
            }
        }
        
        return $scored | Sort-Object Score -Descending | Select-Object -ExpandProperty Action
    }
    
    # Get recent actions
    [Action[]] GetRecentActions([int]$count = 10) {
        $recentIds = $this.executionHistory | Select-Object -Last $count -Unique
        $recent = [List[Action]]::new()
        
        foreach ($id in $recentIds) {
            if ($this.actions.ContainsKey($id)) {
                $recent.Add($this.actions[$id])
            }
        }
        
        return $recent.ToArray()
    }
    
    # Enable/disable an action
    [void] SetActionEnabled([string]$id, [bool]$enabled) {
        if ($this.actions.ContainsKey($id)) {
            $this.actions[$id].Enabled = $enabled
            Write-Log -Level Debug -Message "Action '$id' enabled: $enabled"
        }
    }
    
    # Update action metadata
    [void] UpdateActionMetadata([string]$id, [string]$key, [object]$value) {
        if ($this.actions.ContainsKey($id)) {
            $this.actions[$id].Metadata[$key] = $value
        }
    }
    
    # Add tags to an action
    [void] AddActionTags([string]$id, [string[]]$tags) {
        if ($this.actions.ContainsKey($id)) {
            $action = $this.actions[$id]
            $action.Tags = $action.Tags + $tags | Select-Object -Unique
        }
    }
    
    # Private helper methods
    hidden [void] EnsureGroup([string]$group) {
        if (-not $this.groupedActions.ContainsKey($group)) {
            $this.groupedActions[$group] = [List[Action]]::new()
        }
    }
    
    hidden [void] AddToHistory([string]$id) {
        $this.executionHistory.Add($id)
        
        # Trim history if needed
        if ($this.executionHistory.Count > $this.maxHistorySize) {
            $excess = $this.executionHistory.Count - $this.maxHistorySize
            $this.executionHistory.RemoveRange(0, $excess)
        }
    }
    
    # Export action registry to JSON (for debugging/persistence)
    [string] ExportToJson() {
        $export = @{
            Actions = @{}
            Groups = $this.GetGroups()
            History = $this.executionHistory.ToArray()
        }
        
        foreach ($kvp in $this.actions.GetEnumerator()) {
            $action = $kvp.Value
            $export.Actions[$kvp.Key] = @{
                Name = $action.Name
                Group = $action.Group
                Description = $action.Description
                Hotkey = $action.Hotkey
                Enabled = $action.Enabled
                Tags = $action.Tags
                Metadata = $action.Metadata
            }
        }
        
        return $export | ConvertTo-Json -Depth 5
    }
}

# Global functions for module export
function New-ActionService {
    <#
    .SYNOPSIS
    Creates a new action service instance
    
    .DESCRIPTION
    Creates a new action registry for managing application commands
    
    .EXAMPLE
    $actionService = New-ActionService
    #>
    return [ActionService]::new()
}

function Initialize-StandardActions {
    <#
    .SYNOPSIS
    Registers standard PMC Terminal actions
    
    .DESCRIPTION
    Populates the action service with common application actions
    
    .PARAMETER ActionService
    The action service to populate
    
    .PARAMETER NavigationService
    Navigation service for navigation actions
    
    .EXAMPLE
    Initialize-StandardActions -ActionService $actionService -NavigationService $navService
    #>
    param(
        [ActionService]$ActionService,
        [object]$NavigationService
    )
    
    # Navigation actions
    $ActionService.RegisterAction("nav.dashboard", "Go to Dashboard", "Navigation", "Navigate to the main dashboard", {
        param($context)
        $NavigationService.GoTo("/dashboard", @{})
    }, "Ctrl+D")
    
    $ActionService.RegisterAction("nav.tasks", "Go to Tasks", "Navigation", "Navigate to task management", {
        param($context)
        $NavigationService.GoTo("/tasks", @{})
    }, "Ctrl+T")
    
    $ActionService.RegisterAction("nav.back", "Go Back", "Navigation", "Navigate to previous screen", {
        param($context)
        $NavigationService.GoBack()
    }, "Alt+Left")
    
    # System actions
    $ActionService.RegisterAction("sys.quit", "Quit Application", "System", "Exit PMC Terminal", {
        param($context)
        Stop-TuiEngine
    }, "Ctrl+Q")
    
    $ActionService.RegisterAction("sys.refresh", "Refresh", "System", "Refresh current screen", {
        param($context)
        Request-TuiRefresh
    }, "F5")
    
    $ActionService.RegisterAction("sys.command-palette", "Open Command Palette", "System", "Show all available commands", {
        param($context)
        # This will be handled by the command palette component
        Publish-Event -EventName "CommandPalette.Open"
    }, "Ctrl+P")
    
    Write-Log -Level Info -Message "Standard actions registered in ActionService"
}

# Export module members
Export-ModuleMember -Function New-ActionService, Initialize-StandardActions