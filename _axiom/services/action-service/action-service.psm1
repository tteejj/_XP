# MODULE: action-service/action-service.psm1
# PURPOSE: Provides a central registry for application-wide actions/commands.

# ------------------------------------------------------------------------------
# Public Functions
# ------------------------------------------------------------------------------

function Initialize-ActionService {
    <#
    .SYNOPSIS
    Initializes the central ActionService for the application.
    .DESCRIPTION
    This function creates and returns a new instance of the ActionService class,
    which manages the registration, unregistration, and execution of application-wide commands.
    #>
    [CmdletBinding()]
    param()

    # Wrap the core logic in Invoke-WithErrorHandling for application-wide error consistency.
    # This also ensures centralized logging of the initialization process.
    return Invoke-WithErrorHandling -Component "ActionService.Initialize" -Context "Initializing action service" -ScriptBlock {
        Write-Verbose "ActionService: Initializing a new instance of ActionService."
        $service = [ActionService]::new()
        Write-Log -Level Info -Message "ActionService initialized."
        return $service
    }
}

# ------------------------------------------------------------------------------
# ActionService Class
# ------------------------------------------------------------------------------
# The core component that manages the registry of application actions.
class ActionService {
    # Stores action definitions, mapping action names (string) to action details (hashtable).
    [hashtable] $ActionRegistry = @{}
    
    # Manages internal event subscriptions made by ActionService itself for cleanup purposes.
    # Maps event names (string) to handler IDs (string).
    [hashtable] $EventSubscriptions = @{} 

    # Constructor: Called when a new instance of ActionService is created.
    ActionService() {
        Write-Verbose "ActionService: Constructor called."
        # Register default application-level actions.
        # These actions typically publish events for other services to handle.
        $this.RegisterAction(
            "app.exit", 
            "Exits the PMC Terminal application.", 
            {
                # This script block will be executed when 'app.exit' action is called.
                # It expects the global 'Publish-Event' function to be available.
                Publish-Event -EventName "Application.Exit" -Data @{ Source = "ActionService"; Action = "AppExit" }
            }, 
            "Application", 
            $true # Force overwrite if called multiple times in tests
        )

        $this.RegisterAction(
            "app.help", 
            "Displays application help.", 
            {
                Publish-Event -EventName "App.HelpRequested" -Data @{ Source = "ActionService"; Action = "Help" }
            }, 
            "Application", 
            $true # Force overwrite
        )

        Write-Log -Level Info -Message "ActionService initialized with default actions."
        Write-Verbose "ActionService: Default actions registered."
    }

    # RegisterAction: Registers a new action with the service.
    # Actions are identified by a unique name and associated with a script block to execute.
    [void] RegisterAction(
        [string]$name, 
        [string]$description, 
        [scriptblock]$scriptBlock, 
        [string]$category = "General", 
        [switch]$Force 
    ) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
        if ([string]::IsNullOrWhiteSpace($description)) { throw [System.ArgumentException]::new("Parameter 'description' cannot be null or empty.") }
        if ($null -eq $scriptBlock) { throw [System.ArgumentNullException]::new("scriptBlock") }

        if ($this.ActionRegistry.ContainsKey($name)) {
            if (-not $Force) {
                Write-Log -Level Warning -Message "Action '$name' already registered. Use -Force to overwrite."
                Write-Verbose "ActionService: Skipping registration of '$name' as it already exists (no -Force)."
                return # Do not overwrite if not forced
            } else {
                Write-Log -Level Info -Message "Action '$name' already registered. Overwriting due to -Force."
                Write-Verbose "ActionService: Overwriting action '$name'."
            }
        }

        # Store action details in the registry.
        $this.ActionRegistry[$name] = @{
            Name = $name;
            Description = $description;
            ScriptBlock = $scriptBlock;
            Category = $category;
            RegisteredAt = (Get-Date);
        }
        Write-Log -Level Debug -Message "Action '$name' registered."
        Write-Verbose "ActionService: Action '$name' successfully registered."
    }

    # UnregisterAction: Removes an action from the service.
    [void] UnregisterAction([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }

        if ($this.ActionRegistry.ContainsKey($name)) {
            $this.ActionRegistry.Remove($name)
            Write-Log -Level Debug -Message "Action '$name' unregistered."
            Write-Verbose "ActionService: Action '$name' successfully unregistered."
        } else {
            Write-Log -Level Warning -Message "Action '$name' not found, cannot unregister."
            Write-Verbose "ActionService: Action '$name' not found for unregistration."
        }
    }

    # ExecuteAction: Executes a registered action.
    # The parameters hashtable is passed to the action's script block as $ActionParameters.
    [void] ExecuteAction(
        [string]$name, 
        [hashtable]$parameters = @{}
    ) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }

        if (-not $this.ActionRegistry.ContainsKey($name)) {
            $errorMessage = "Attempted to execute unknown action: $name"
            Write-Log -Level Error -Message $errorMessage -Data @{ ActionName = $name; Parameters = $parameters }
            Write-Verbose "ActionService: Failed to execute action '$name' - not found."
            throw [System.ArgumentException]::new($errorMessage, "name")
        }

        $action = $this.ActionRegistry[$name]
        Write-Log -Level Info -Message "Executing action: $name" -Data @{ ActionName = $name; Parameters = $parameters }
        Write-Verbose "ActionService: Preparing to execute action '$name'."

        try {
            # Pass parameters to the action's script block via a named parameter ($ActionParameters).
            # This ensures a consistent contract for all action script blocks.
            & $action.ScriptBlock -ActionParameters $parameters
            Write-Verbose "ActionService: Action '$name' executed successfully."
        } catch {
            $errorMessage = "Action '$name' failed: $($_.Exception.Message)"
            Write-Log -Level Error -Message $errorMessage -Data @{ ActionName = $name; ActionParameters = $parameters; ErrorDetails = $_.Exception.Message; FullError = $_ }
            Write-Verbose "ActionService: Action '$name' execution failed: $($_.Exception.Message)."
            throw # Re-throw to propagate the error, allowing Invoke-WithErrorHandling to catch it.
        }
    }

    # GetAction: Retrieves the definition of a specific action.
    [hashtable] GetAction([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
        
        Write-Verbose "ActionService: Retrieving action '$name'."
        return $this.ActionRegistry[$name]
    }

    # GetAllActions: Retrieves a list of all registered action definitions.
    # Returns a list of hashtables, each representing an action.
    [System.Collections.Generic.List[hashtable]] GetAllActions() {
        Write-Verbose "ActionService: Retrieving all registered actions."
        # Filter out any null values (shouldn't happen with proper registration) and sort by name.
        return @($this.ActionRegistry.Values | Where-Object { $_ -ne $null } | Sort-Object Name)
    }

    # AddEventSubscription: Internal method to track event subscriptions made by ActionService.
    # This allows for proper cleanup in the Cleanup method.
    hidden [void] AddEventSubscription([string]$eventName, [string]$handlerId) {
        if ([string]::IsNullOrWhiteSpace($eventName)) { throw [System.ArgumentException]::new("Parameter 'eventName' cannot be null or empty.") }
        if ([string]::IsNullOrWhiteSpace($handlerId)) { throw [System.ArgumentException]::new("Parameter 'handlerId' cannot be null or empty.") }

        $this.EventSubscriptions[$eventName] = $handlerId
        Write-Log -Level Debug -Message "ActionService: Tracking event subscription for '$eventName' (HandlerId: $handlerId)."
        Write-Verbose "ActionService: Added event subscription tracking for '$eventName'."
    }

    # Cleanup: Performs necessary cleanup operations when the ActionService is no longer needed.
    # This includes unsubscribing from any events it subscribed to and clearing its action registry.
    [void] Cleanup() {
        # Unsubscribe from any events ActionService itself subscribed to.
        # Assumes 'Unsubscribe-Event' from EventSystem module is globally available.
        Write-Verbose "ActionService: Starting cleanup process."
        foreach ($kvp in $this.EventSubscriptions.GetEnumerator()) {
            try {
                Unsubscribe-Event -EventName $kvp.Key -HandlerId $kvp.Value
                Write-Log -Level Debug -Message "ActionService: Unsubscribed from event '$($kvp.Key)' (HandlerId: $($kvp.Value))."
                Write-Verbose "ActionService: Unsubscribed from event '$($kvp.Key)'."
            } catch {
                Write-Log -Level Warning -Message "ActionService: Failed to unsubscribe from event '$($kvp.Key)' (HandlerId: $($kvp.Value)): $($_.Exception.Message)"
                Write-Verbose "ActionService: Failed to unsubscribe from event '$($kvp.Key)'. Error: $($_.Exception.Message)."
            }
        }
        $this.EventSubscriptions.Clear() # Clear tracking after attempting unsubscriptions.
        
        # Clear the action registry.
        $this.ActionRegistry.Clear()
        Write-Log -Level Info -Message "ActionService cleaned up."
        Write-Verbose "ActionService: ActionRegistry cleared. Cleanup complete."
    }
}

# ------------------------------------------------------------------------------
# Module Export
# ------------------------------------------------------------------------------
Export-ModuleMember -Function Initialize-ActionService # FIX: Removed the invalid -Class parameter. The ActionService class is exported automatically.