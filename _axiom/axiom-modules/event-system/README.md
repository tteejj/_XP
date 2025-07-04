# event-system Module

## Overview
The `event-system` module provides a publish/subscribe (pub/sub) event system for PMC Terminal, enabling decoupled communication between components. This allows different parts of the application to communicate without direct references to each other.

## Features
- Event publishing and subscription
- Multiple handlers per event
- Handler tracking by source component
- Event history with configurable retention
- Wildcard event cleanup by component
- Error isolation (one handler's error doesn't affect others)

## Functions

### Initialize-EventSystem
Initialize or reset the event system.

```powershell
Initialize-EventSystem
```

### Publish-Event
Publish an event with optional data to all subscribers.

```powershell
# Simple event
Publish-Event -EventName "App.Started"

# Event with data
Publish-Event -EventName "Task.Created" -Data @{
    TaskId = 123
    TaskName = "New Task"
    CreatedBy = "User"
}
```

### Subscribe-Event
Subscribe to an event with a handler script block.

```powershell
# Basic subscription
$handlerId = Subscribe-Event -EventName "Task.Created" -Handler {
    param($EventData)
    Write-Host "Task created: $($EventData.Data.TaskName)"
}

# Subscription with source tracking
Subscribe-Event -EventName "App.Shutdown" -Source "MyComponent" -Handler {
    param($EventData)
    # Cleanup code
}
```

### Unsubscribe-Event
Remove a specific event handler.

```powershell
# Unsubscribe by handler ID
Unsubscribe-Event -HandlerId $handlerId

# Unsubscribe from specific event
Unsubscribe-Event -EventName "Task.Created" -HandlerId $handlerId
```

### Get-EventHandlers
Retrieve registered event handlers.

```powershell
# Get all handlers
$allHandlers = Get-EventHandlers

# Get handlers for specific event
$taskHandlers = Get-EventHandlers -EventName "Task.Created"
```

### Clear-EventHandlers
Remove event handlers.

```powershell
# Clear handlers for specific event
Clear-EventHandlers -EventName "Task.Created"

# Clear all handlers
Clear-EventHandlers
```

### Get-EventHistory
Retrieve event history.

```powershell
# Get all history
$history = Get-EventHistory

# Get last 10 events
$recent = Get-EventHistory -Last 10

# Get history for specific event
$taskHistory = Get-EventHistory -EventName "Task.Created" -Last 5
```

### Remove-ComponentEventHandlers
Remove all handlers registered by a specific component.

```powershell
# Clean up all handlers for a component
Remove-ComponentEventHandlers -ComponentId "MyComponent"
```

## Event Naming Conventions

Recommended event naming patterns:
- `Component.Action` - e.g., "Task.Created", "Screen.Loaded"
- `Module:Event` - e.g., "DataManager:SaveComplete"
- `Category.Subcategory.Event` - e.g., "UI.Button.Clicked"

## Handler Script Block

Event handlers receive an `$EventData` parameter with:
- `EventName` - The name of the event
- `Data` - The data hashtable passed to Publish-Event
- `Timestamp` - When the event was published

```powershell
Subscribe-Event -EventName "Task.Updated" -Handler {
    param($EventData)
    
    # Access event information
    $eventName = $EventData.EventName
    $taskId = $EventData.Data.TaskId
    $timestamp = $EventData.Timestamp
    
    Write-Host "Task $taskId updated at $timestamp"
}
```

## Common Event Patterns

### Application Lifecycle
```powershell
Publish-Event -EventName "App.Initializing"
Publish-Event -EventName "App.Started"
Publish-Event -EventName "App.Stopping"
```

### Data Changes
```powershell
Publish-Event -EventName "Data.Created" -Data @{Type="Task"; Id=123}
Publish-Event -EventName "Data.Updated" -Data @{Type="Task"; Id=123; Changes=@{}}
Publish-Event -EventName "Data.Deleted" -Data @{Type="Task"; Id=123}
```

### UI Events
```powershell
Publish-Event -EventName "Screen.Entered" -Data @{ScreenName="Dashboard"}
Publish-Event -EventName "Dialog.Closed" -Data @{DialogId="Confirm"; Result="OK"}
```

## Dependencies
None - This module is self-contained.

## Best Practices

1. **Use descriptive event names** - Make it clear what the event represents
2. **Include relevant data** - But keep it serializable (no complex objects)
3. **Handle errors gracefully** - Don't let handler errors crash the app
4. **Clean up handlers** - Use Remove-ComponentEventHandlers when components are destroyed
5. **Avoid circular events** - Don't publish events from within event handlers that could cause loops

## Example: Component Integration
```powershell
# In a screen component
class MyScreen {
    [string]$Id = "MyScreen"
    
    [void] Initialize() {
        # Subscribe to relevant events
        Subscribe-Event -EventName "Task.Updated" -Source $this.Id -Handler {
            param($EventData)
            $this.RefreshTaskDisplay($EventData.Data.TaskId)
        }.GetNewClosure()
    }
    
    [void] Cleanup() {
        # Remove all handlers for this component
        Remove-ComponentEventHandlers -ComponentId $this.Id
    }
    
    [void] SaveTask($task) {
        # ... save logic ...
        
        # Notify other components
        Publish-Event -EventName "Task.Updated" -Data @{
            TaskId = $task.Id
            UpdatedFields = @("Name", "Status")
        }
    }
}
```
