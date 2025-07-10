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

#region EventManager Class

# ===== CLASS: EventManager =====
# Module: event-system (from axiom)
# Dependencies: None
# Purpose: Pub/sub event system for decoupled communication
class EventManager {
    [hashtable]$EventHandlers = @{}
    [int]$NextHandlerId = 1
    [System.Collections.Generic.List[hashtable]]$EventHistory
    [int]$MaxHistorySize = 100
    [bool]$EnableHistory = $true
    
    EventManager() {
        $this.EventHistory = [System.Collections.Generic.List[hashtable]]::new()
        # Write-Verbose "EventManager: Initialized"
    }
    
    [string] Subscribe([string]$eventName, [scriptblock]$handler) {
        if ([string]::IsNullOrWhiteSpace($eventName)) {
            throw [ArgumentException]::new("Event name cannot be null or empty")
        }
        if (-not $handler) {
            throw [ArgumentNullException]::new("handler")
        }
        
        if (-not $this.EventHandlers.ContainsKey($eventName)) {
            $this.EventHandlers[$eventName] = @{}
        }
        
        $handlerId = "handler_$($this.NextHandlerId)"
        $this.NextHandlerId++
        
        $this.EventHandlers[$eventName][$handlerId] = @{
            Handler = $handler
            SubscribedAt = [DateTime]::Now
            ExecutionCount = 0
        }
        
        # Write-Verbose "EventManager: Subscribed handler '$handlerId' to event '$eventName'"
        return $handlerId
    }
    
    [void] Unsubscribe([string]$eventName, [string]$handlerId) {
        if ($this.EventHandlers.ContainsKey($eventName)) {
            if ($this.EventHandlers[$eventName].ContainsKey($handlerId)) {
                $this.EventHandlers[$eventName].Remove($handlerId)
                # Write-Verbose "EventManager: Unsubscribed handler '$handlerId' from event '$eventName'"
                
                # Clean up empty event entries
                if ($this.EventHandlers[$eventName].Count -eq 0) {
                    $this.EventHandlers.Remove($eventName)
                }
            }
        }
    }
    
    [void] UnsubscribeAll([string]$eventName) {
        if ($this.EventHandlers.ContainsKey($eventName)) {
            $handlerCount = $this.EventHandlers[$eventName].Count
            $this.EventHandlers.Remove($eventName)
            # Write-Verbose "EventManager: Unsubscribed all $handlerCount handlers from event '$eventName'"
        }
    }
    
    [void] Publish([string]$eventName, [hashtable]$eventData = @{}) {
        # Sanitize event data to prevent circular reference issues
        $sanitizedData = @{}
        foreach ($key in $eventData.Keys) {
            $value = $eventData[$key]
            if ($value -is [string] -or $value -is [int] -or $value -is [double] -or 
                $value -is [bool] -or $value -is [datetime] -or $value -eq $null) {
                # Simple types are safe
                $sanitizedData[$key] = $value
            }
            elseif ($value -is [UIElement]) {
                # Never store UIElement objects - just store identifying info
                $sanitizedData[$key] = "[UIElement: $($value.Name)]"
            }
            elseif ($value.GetType().Name -match 'Task|Project') {
                # For task/project objects, only store essential data
                try {
                    if ($value.PSObject.Properties['Id']) {
                        $sanitizedData[$key] = @{
                            Type = $value.GetType().Name
                            Id = $value.Id
                            Title = if ($value.PSObject.Properties['Title']) { $value.Title } else { $null }
                        }
                    } else {
                        $sanitizedData[$key] = "[Object: $($value.GetType().Name)]"
                    }
                } catch {
                    $sanitizedData[$key] = "[Object: $($value.GetType().Name)]"
                }
            }
            else {
                # For other complex types, just store the type name
                $sanitizedData[$key] = "[Object: $($value.GetType().Name)]"
            }
        }
        
        # Add to history if enabled (using sanitized data)
        if ($this.EnableHistory) {
            $historyEntry = @{
                EventName = $eventName
                EventData = $sanitizedData
                Timestamp = [DateTime]::Now
                HandlerCount = 0
            }
            
            $this.EventHistory.Add($historyEntry)
            
            if ($this.EventHistory.Count -gt $this.MaxHistorySize) {
                $this.EventHistory.RemoveAt(0)
            }
        }
        
        # Execute handlers with original data
        if ($this.EventHandlers.ContainsKey($eventName)) {
            $handlers = @($this.EventHandlers[$eventName].GetEnumerator())
            
            if ($this.EnableHistory -and $this.EventHistory.Count -gt 0) {
                $this.EventHistory[-1].HandlerCount = $handlers.Count
            }
            
            foreach ($entry in $handlers) {
                try {
                    $handlerData = $entry.Value
                    $handlerData.ExecutionCount++
                    & $handlerData.Handler $eventData
                }
                catch {
                    # Log errors without complex data
                    if ($global:TuiState.Services.Logger) {
                        $global:TuiState.Services.Logger.Log(
                            "EventManager: Error in handler '$($entry.Key)' for event '$eventName': $($_.Exception.Message)", 
                            "Error"
                        )
                    }
                }
            }
        }
    }
    
    [hashtable[]] GetEventHistory([string]$eventName = $null) {
        if ($eventName) {
            return $this.EventHistory | Where-Object { $_.EventName -eq $eventName }
        }
        return $this.EventHistory | ForEach-Object { $_ }
    }
    
    [void] ClearHistory() {
        $this.EventHistory.Clear()
        # Write-Verbose "EventManager: Cleared event history"
    }
    
    [hashtable] GetEventInfo() {
        $info = @{
            RegisteredEvents = @{}
            TotalHandlers = 0
        }
        
        foreach ($eventName in $this.EventHandlers.Keys) {
            $handlers = $this.EventHandlers[$eventName]
            $info.RegisteredEvents[$eventName] = @{
                HandlerCount = $handlers.Count
                Handlers = $handlers.Keys | ForEach-Object { $_ }
            }
            $info.TotalHandlers += $handlers.Count
        }
        
        return $info
    }
}

#endregion
#<!-- END_PAGE: ASE.007 -->
