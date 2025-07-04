# Event System Module
# Provides pub/sub event functionality for decoupled communication

$script:EventHandlers = @{}
$script:EventHistory = [System.Collections.Generic.List[object]]::new()
$script:MaxEventHistory = 100

function Initialize-EventSystem {
    <#
    .SYNOPSIS
    Initializes the event system for the application
    #>
    $script:EventHandlers = @{}
    $script:EventHistory = [System.Collections.Generic.List[object]]::new()
    Write-Verbose "Event system initialized"
}

function Publish-Event {
    <#
    .SYNOPSIS
    Publishes an event to all registered handlers
    .PARAMETER EventName
    The name of the event to publish
    .PARAMETER Data
    Optional data to pass to event handlers
    #>
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        
        [Parameter()]
        [hashtable]$Data = @{}
    )
    
    try {
        $eventRecord = @{
            EventName = $EventName
            Data = $Data
            Timestamp = Get-Date
        }
        
        # Add to history
        $script:EventHistory.Add($eventRecord)
        if ($script:EventHistory.Count -gt $script:MaxEventHistory) {
            $script:EventHistory.RemoveAt(0)
        }
        
        # Call handlers
        if ($script:EventHandlers.ContainsKey($EventName)) {
            foreach ($handler in $script:EventHandlers[$EventName]) {
                try {
                    $eventData = @{
                        EventName = $EventName
                        Data = $Data
                        Timestamp = $eventRecord.Timestamp
                    }
                    & $handler.ScriptBlock -EventData $eventData
                }
                catch {
                    Write-Warning "Error in event handler for '$EventName' (ID: $($handler.HandlerId)): $_"
                }
            }
        }
        
        Write-Verbose "Published event: $EventName"
    }
    catch {
        Write-Error "Failed to publish event '$EventName': $_"
        throw
    }
}

function Subscribe-Event {
    <#
    .SYNOPSIS
    Subscribes to an event with a handler
    .PARAMETER EventName
    The name of the event to subscribe to
    .PARAMETER Handler
    The script block to execute when the event is published
    .PARAMETER HandlerId
    Optional unique identifier for the handler
    .PARAMETER Source
    Optional source component ID for cleanup tracking
    #>
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        
        [Parameter(Mandatory)]
        [scriptblock]$Handler,
        
        [Parameter()]
        [string]$HandlerId = [Guid]::NewGuid().ToString(),
        
        [Parameter()]
        [string]$Source
    )
    
    try {
        if (-not $script:EventHandlers.ContainsKey($EventName)) {
            $script:EventHandlers[$EventName] = @()
        }
        
        $handlerInfo = @{
            HandlerId = $HandlerId
            ScriptBlock = $Handler
            SubscribedAt = Get-Date
            Source = $Source
        }
        
        $script:EventHandlers[$EventName] += $handlerInfo
        
        Write-Verbose "Subscribed to event: $EventName (Handler: $HandlerId)"
        return $HandlerId
    }
    catch {
        Write-Error "Failed to subscribe to event '$EventName': $_"
        throw
    }
}

function Unsubscribe-Event {
    <#
    .SYNOPSIS
    Unsubscribes from an event
    .PARAMETER EventName
    The name of the event (optional if HandlerId is provided)
    .PARAMETER HandlerId
    The unique identifier of the handler to remove
    #>
    param(
        [Parameter()]
        [string]$EventName,
        
        [Parameter(Mandatory)]
        [string]$HandlerId
    )
    
    try {
        if ($EventName) {
            # Unsubscribe from specific event
            if ($script:EventHandlers.ContainsKey($EventName)) {
                $script:EventHandlers[$EventName] = @($script:EventHandlers[$EventName] | Where-Object { $_.HandlerId -ne $HandlerId })
                if ($script:EventHandlers[$EventName].Count -eq 0) {
                    $script:EventHandlers.Remove($EventName)
                }
                Write-Verbose "Unsubscribed from event: $EventName (Handler: $HandlerId)"
            }
        }
        else {
            # Search all events for the handler
            $found = $false
            foreach ($eventKey in @($script:EventHandlers.Keys)) {
                $handlers = $script:EventHandlers[$eventKey]
                $newHandlers = @($handlers | Where-Object { $_.HandlerId -ne $HandlerId })
                
                if ($newHandlers.Count -lt $handlers.Count) {
                    $found = $true
                    if ($newHandlers.Count -eq 0) {
                        $script:EventHandlers.Remove($eventKey)
                    }
                    else {
                        $script:EventHandlers[$eventKey] = $newHandlers
                    }
                    Write-Verbose "Unsubscribed from event: $eventKey (Handler: $HandlerId)"
                    break
                }
            }
            
            if (-not $found) {
                Write-Warning "Handler ID not found: $HandlerId"
            }
        }
    }
    catch {
        Write-Error "Failed to unsubscribe handler '$HandlerId': $_"
        throw
    }
}

function Get-EventHandlers {
    <#
    .SYNOPSIS
    Gets all registered event handlers
    .PARAMETER EventName
    Optional event name to filter handlers
    #>
    param(
        [Parameter()]
        [string]$EventName
    )
    
    if ($EventName) {
        return $script:EventHandlers[$EventName] ?? @()
    }
    else {
        return $script:EventHandlers
    }
}

function Clear-EventHandlers {
    <#
    .SYNOPSIS
    Clears all event handlers for a specific event or all events
    .PARAMETER EventName
    Optional event name to clear handlers for
    #>
    param(
        [Parameter()]
        [string]$EventName
    )
    
    if ($EventName) {
        if ($script:EventHandlers.ContainsKey($EventName)) {
            $script:EventHandlers.Remove($EventName)
            Write-Verbose "Cleared handlers for event: $EventName"
        }
    }
    else {
        $script:EventHandlers = @{}
        Write-Verbose "Cleared all event handlers"
    }
}

function Get-EventHistory {
    <#
    .SYNOPSIS
    Gets the event history
    .PARAMETER EventName
    Optional event name to filter history
    .PARAMETER Last
    Number of recent events to return (0 for all)
    #>
    param(
        [Parameter()]
        [string]$EventName,
        
        [Parameter()]
        [int]$Last = 0
    )
    
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
    Removes all event handlers associated with a specific component
    .PARAMETER ComponentId
    The component ID whose handlers should be removed
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ComponentId
    )
    
    try {
        $removedCount = 0
        
        foreach ($eventName in @($script:EventHandlers.Keys)) {
            $initialCount = $script:EventHandlers[$eventName].Count
            $script:EventHandlers[$eventName] = @($script:EventHandlers[$eventName] | Where-Object { $_.Source -ne $ComponentId })
            $removedCount += $initialCount - $script:EventHandlers[$eventName].Count
            
            if ($script:EventHandlers[$eventName].Count -eq 0) {
                $script:EventHandlers.Remove($eventName)
            }
        }
        
        Write-Verbose "Removed $removedCount event handlers for component: $ComponentId"
    }
    catch {
        Write-Error "Failed to remove handlers for component '$ComponentId': $_"
        throw
    }
}

# Export all public functions
Export-ModuleMember -Function Initialize-EventSystem, Publish-Event, Subscribe-Event, Unsubscribe-Event, Get-EventHandlers, Clear-EventHandlers, Get-EventHistory, Remove-ComponentEventHandlers
