# Event System Module
# Provides pub/sub event functionality for decoupled communication

# Module-scoped state variables for the event system
# $script:EventHandlers stores eventName -> [System.Collections.Generic.List[object]] of handlers
$script:EventHandlers = @{} 
$script:EventHistory = [System.Collections.Generic.List[object]]::new()
$script:MaxEventHistory = 100

function Initialize-EventSystem {
    <#
    .SYNOPSIS
    Initializes or resets the event system for the application.
    This clears all registered handlers and the event history.
    #>
    [CmdletBinding()]
    param()

    $script:EventHandlers.Clear() # Use Clear() method for Hashtable
    $script:EventHistory.Clear()  # Use Clear() method for List
    Write-Verbose "Event system initialized."
}

function Publish-Event {
    <#
    .SYNOPSIS
    Publishes an event to all registered handlers for the specified event name.
    .PARAMETER EventName
    The name of the event to publish. Must be a non-empty string.
    .PARAMETER Data
    Optional data to pass to event handlers. This should be a hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EventName,
        
        [Parameter()]
        [hashtable]$Data = @{}
    )
    
    try {
        $eventRecord = @{
            EventName = $EventName
            Data = $Data
            Timestamp = (Get-Date)
        }
        
        # Add to history, managing the maximum size
        $script:EventHistory.Add($eventRecord)
        if ($script:EventHistory.Count -gt $script:MaxEventHistory) {
            $script:EventHistory.RemoveAt(0) # Efficient for List
        }
        
        # Call handlers
        if ($script:EventHandlers.ContainsKey($EventName)) {
            # Create a copy of the list of handlers to iterate over.
            # This prevents issues if a handler unsubscribes itself or others during iteration.
            $handlersToCall = $script:EventHandlers[$EventName].ToArray()
            
            foreach ($handler in $handlersToCall) {
                try {
                    # Prepare the event data for the handler
                    $eventData = @{
                        EventName = $EventName
                        Data = $Data
                        Timestamp = $eventRecord.Timestamp
                    }
                    # Invoke the handler script block, passing $eventData as a named parameter
                    & $handler.ScriptBlock -EventData $eventData
                }
                catch {
                    # Log errors from individual handlers without stopping the publishing process
                    Write-Warning "Error in event handler for '$EventName' (ID: $($handler.HandlerId)): $($_.Exception.Message)"
                    Write-Debug "Full error details for handler ID '$($handler.HandlerId)' on event '$EventName': $_"
                }
            }
        }
        
        Write-Verbose "Published event: $EventName."
    }
    catch {
        Write-Error "Failed to publish event '$EventName': $($_.Exception.Message)"
        throw # Re-throw to allow calling script to handle critical publishing errors
    }
}

function Subscribe-Event {
    <#
    .SYNOPSIS
    Subscribes to an event with a handler.
    .PARAMETER EventName
    The name of the event to subscribe to. Must be a non-empty string.
    .PARAMETER Handler
    The script block to execute when the event is published.
    This script block will receive a hashtable via the '-EventData' parameter,
    containing 'EventName', 'Data', and 'Timestamp'.
    .PARAMETER HandlerId
    Optional unique identifier for the handler. If not provided, a GUID will be generated.
    This ID can be used to unsubscribe the handler later.
    .PARAMETER Source
    Optional source component ID. This allows for bulk removal of handlers associated
    with a specific component, e.g., when a component is disposed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EventName,
        
        [Parameter(Mandatory)]
        [scriptblock]$Handler,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$HandlerId = [Guid]::NewGuid().ToString(),
        
        [Parameter()]
        [string]$Source
    )
    
    try {
        # Ensure the list of handlers for this event exists, creating it if necessary
        if (-not $script:EventHandlers.ContainsKey($EventName)) {
            $script:EventHandlers[$EventName] = [System.Collections.Generic.List[object]]::new()
        }
        
        # Check for duplicate HandlerId for the same event to prevent unintentional double subscriptions
        if ($script:EventHandlers[$EventName].Where({$_.HandlerId -eq $HandlerId}).Count -gt 0) {
            Write-Warning "Handler with ID '$HandlerId' is already subscribed to event '$EventName'. Skipping subscription."
            return $HandlerId # Return existing ID
        }

        $handlerInfo = @{
            HandlerId = $HandlerId
            ScriptBlock = $Handler
            SubscribedAt = (Get-Date)
            Source = $Source
        }
        
        # Add the handler information to the List (efficient)
        $script:EventHandlers[$EventName].Add($handlerInfo)
        
        Write-Verbose "Subscribed to event: $EventName (Handler: $HandlerId, Source: $($Source -replace '^$', '<None>')). Returned HandlerId: $HandlerId"
        return $HandlerId
    }
    catch {
        Write-Error "Failed to subscribe to event '$EventName' for handler '$HandlerId': $($_.Exception.Message)"
        throw
    }
}

function Unsubscribe-Event {
    <#
    .SYNOPSIS
    Unsubscribes a specific handler from an event or searches all events.
    .PARAMETER EventName
    The name of the event from which to unsubscribe. Optional, but providing it
    improves performance by targeting the search.
    .PARAMETER HandlerId
    The unique identifier of the handler to remove. This parameter is mandatory.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$EventName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$HandlerId
    )
    
    try {
        if ($PSCmdlet.ShouldProcess("handler '$HandlerId'", "Unsubscribe event handler")) {
            $removedCount = 0
            if ($EventName) {
                # Unsubscribe from a specific event (more efficient)
                if ($script:EventHandlers.ContainsKey($EventName)) {
                    $handlersList = $script:EventHandlers[$EventName]
                    # Remove all matching handlers using RemoveAll (efficient)
                    $removedCount = $handlersList.RemoveAll({param($h) $h.HandlerId -eq $HandlerId})
                    
                    # Clean up: If no handlers remain for this event, remove the event entry
                    if ($handlersList.Count -eq 0) {
                        $script:EventHandlers.Remove($EventName)
                    }
                    
                    if ($removedCount -gt 0) {
                        Write-Verbose "Unsubscribed $removedCount handler(s) from event: $EventName (Handler: $HandlerId)."
                    } else {
                        Write-Warning "Handler ID '$HandlerId' not found for event '$EventName'."
                    }
                } else {
                    Write-Warning "Event '$EventName' has no registered handlers. Nothing to unsubscribe."
                }
            }
            else {
                # Search all events for the handler (less efficient, use EventName if known)
                $found = $false
                # Iterate over a copy of the keys as the dictionary might be modified
                foreach ($eventKey in @($script:EventHandlers.Keys)) {
                    $handlersList = $script:EventHandlers[$eventKey]
                    $currentRemoved = $handlersList.RemoveAll({param($h) $h.HandlerId -eq $HandlerId})
                    
                    if ($currentRemoved -gt 0) {
                        $removedCount += $currentRemoved
                        $found = $true
                        # Clean up: If no handlers remain for this event, remove the event entry
                        if ($handlersList.Count -eq 0) {
                            $script:EventHandlers.Remove($eventKey)
                        }
                        Write-Verbose "Unsubscribed $currentRemoved handler(s) from event: $eventKey (Handler: $HandlerId)."
                        break # Handler IDs are unique, so we can stop after the first removal
                    }
                }
                
                if (-not $found) {
                    Write-Warning "Handler ID not found across all events: $HandlerId."
                }
            }
        }
    }
    catch {
        Write-Error "Failed to unsubscribe handler '$HandlerId': $($_.Exception.Message)"
        throw
    }
}

function Get-EventHandlers {
    <#
    .SYNOPSIS
    Gets information about registered event handlers.
    .PARAMETER EventName
    Optional event name to filter handlers. If omitted, returns all handlers grouped by event.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$EventName
    )
    
    if ($EventName) {
        # Return specific handlers as PSCustomObjects, excluding the ScriptBlock itself
        $handlers = $script:EventHandlers[$EventName]
        if ($handlers) {
            $handlers | ForEach-Object { 
                [pscustomobject]@{
                    HandlerId = $_.HandlerId
                    EventName = $EventName # Add EventName to each handler object for context
                    SubscribedAt = $_.SubscribedAt
                    Source = $_.Source
                    # Uncomment below line if you need to see the raw script block content for debugging
                    # ScriptBlock = $_.ScriptBlock 
                }
            }
        } else {
            return @() # Return empty array if no handlers for the specified event
        }
    }
    else {
        # Return a custom hashtable where keys are event names and values are arrays of handler info
        $output = [System.Collections.Generic.Hashtable]::new()
        foreach ($eventKey in $script:EventHandlers.Keys) {
            $handlers = $script:EventHandlers[$eventKey]
            # Convert internal List<object> to an array of PSCustomObjects
            $handlerList = @($handlers | ForEach-Object { 
                [pscustomobject]@{
                    HandlerId = $_.HandlerId
                    EventName = $eventKey # Add EventName to each handler object for context
                    SubscribedAt = $_.SubscribedAt
                    Source = $_.Source
                    # Uncomment below line if you need to see the raw script block content for debugging
                    # ScriptBlock = $_.ScriptBlock 
                }
            })
            $output[$eventKey] = $handlerList
        }
        return $output
    }
}

function Clear-EventHandlers {
    <#
    .SYNOPSIS
    Clears all event handlers for a specific event or all events.
    .PARAMETER EventName
    Optional event name to clear handlers for. If omitted, all event handlers are cleared.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$EventName
    )
    
    if ($PSCmdlet.ShouldProcess($EventName, "Clear event handlers")) {
        if ($EventName) {
            if ($script:EventHandlers.ContainsKey($EventName)) {
                $script:EventHandlers.Remove($EventName)
                Write-Verbose "Cleared all handlers for event: $EventName."
            } else {
                Write-Warning "No handlers found for event: $EventName. Nothing to clear."
            }
        }
        else {
            $script:EventHandlers.Clear() # Clear all entries in the hashtable
            Write-Verbose "Cleared all event handlers across all events."
        }
    }
}

function Get-EventHistory {
    <#
    .SYNOPSIS
    Gets the event history.
    .PARAMETER EventName
    Optional event name to filter history entries.
    .PARAMETER Last
    Number of recent events to return. If 0 (default), returns all available history.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$EventName,
        
        [Parameter()]
        [int]$Last = 0
    )
    
    # Get a snapshot of the current history to avoid collection modification issues
    $history = $script:EventHistory.ToArray()
    
    if ($EventName) {
        $history = $history | Where-Object { $_.EventName -eq $EventName }
    }
    
    if ($Last -gt 0) {
        $history = $history | Select-Object -Last $Last
    }
    
    return $history
}

function Remove-ComponentEventHandlers {
    <#
    .SYNOPSIS
    Removes all event handlers associated with a specific component ID.
    This is useful for cleaning up resources when a component is no longer needed.
    .PARAMETER ComponentId
    The component ID whose handlers should be removed. Must be a non-empty string.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ComponentId
    )
    
    try {
        if ($PSCmdlet.ShouldProcess("component '$ComponentId'", "Remove all associated event handlers")) {
            $removedCount = 0
            
            # Iterate over a copy of the keys because the dictionary might be modified during iteration
            foreach ($eventName in @($script:EventHandlers.Keys)) {
                $handlersList = $script:EventHandlers[$eventName]
                
                # Remove all handlers whose 'Source' matches the ComponentId (efficient)
                $currentRemoved = $handlersList.RemoveAll({param($h) $h.Source -ne $null -and $h.Source -eq $ComponentId})
                $removedCount += $currentRemoved
                
                if ($currentRemoved -gt 0) {
                    Write-Verbose "Removed $currentRemoved handlers for component '$ComponentId' from event '$eventName'."
                }

                # If no handlers remain for this event, remove the event entry from the main hashtable
                if ($handlersList.Count -eq 0) {
                    $script:EventHandlers.Remove($eventName)
                    Write-Verbose "Event '$eventName' now has no handlers and was removed from the system."
                }
            }
            
            Write-Verbose "Total removed $removedCount event handlers for component: $ComponentId."
        }
    }
    catch {
        Write-Error "Failed to remove handlers for component '$ComponentId': $($_.Exception.Message)"
        throw
    }
}

# Export all public functions to make them available when the module is imported
Export-ModuleMember -Function Initialize-EventSystem, Publish-Event, Subscribe-Event, Unsubscribe-Event, Get-EventHandlers, Clear-EventHandlers, Get-EventHistory, Remove-ComponentEventHandlers