# Fixed EventManager.Publish method - sanitize event data before storing
[void] Publish([string]$eventName, [hashtable]$eventData = @{}) {
    Write-Verbose "EventManager: Publishing event '$eventName'"
    
    # Sanitize event data to prevent circular reference issues
    $sanitizedData = @{}
    foreach ($key in $eventData.Keys) {
        $value = $eventData[$key]
        if ($value -is [string] -or $value -is [int] -or $value -is [double] -or $value -is [bool] -or $value -is [datetime]) {
            # Simple types are safe
            $sanitizedData[$key] = $value
        }
        elseif ($value -is [UIElement]) {
            # Never store UIElement objects - just store their name and type
            $sanitizedData[$key] = @{
                Name = $value.Name
                Type = $value.GetType().Name
            }
        }
        elseif ($value -eq $null) {
            $sanitizedData[$key] = $null
        }
        else {
            # For other complex types, just store the type name
            $sanitizedData[$key] = "[Object: $($value.GetType().Name)]"
        }
    }
    
    # Add to history if enabled
    if ($this.EnableHistory) {
        $historyEntry = @{
            EventName = $eventName
            EventData = $sanitizedData  # Use sanitized data
            Timestamp = [DateTime]::Now
            HandlerCount = 0
        }
        
        $this.EventHistory.Add($historyEntry)
        
        # Trim history if needed
        if ($this.EventHistory.Count -gt $this.MaxHistorySize) {
            $this.EventHistory.RemoveAt(0)
        }
    }
    
    # Execute handlers with original data (not sanitized)
    if ($this.EventHandlers.ContainsKey($eventName)) {
        $handlers = @($this.EventHandlers[$eventName].GetEnumerator())
        $handlerCount = $handlers.Count
        
        if ($this.EnableHistory) {
            $this.EventHistory[-1].HandlerCount = $handlerCount
        }
        
        foreach ($entry in $handlers) {
            try {
                $handlerData = $entry.Value
                $handlerData.ExecutionCount++
                
                Write-Verbose "EventManager: Executing handler '$($entry.Key)' for event '$eventName'"
                & $handlerData.Handler $eventData  # Pass original data to handlers
            }
            catch {
                Write-Error "EventManager: Error in handler '$($entry.Key)' for event '$eventName': $_"
            }
        }
        
        Write-Verbose "EventManager: Published event '$eventName' to $handlerCount handlers"
    }
    else {
        Write-Verbose "EventManager: No handlers registered for event '$eventName'"
    }
}
