# ui-classes Module

## Overview
The `ui-classes` module provides the foundational class hierarchy for all UI components in the PMC Terminal TUI system. It defines the base `UIElement` class and specialized containers like `Component` and `Screen` with comprehensive lifecycle management and compositor-based rendering.

## Features
- **Component-Based Architecture** - Hierarchical UI component system
- **Lifecycle Management** - Complete component lifecycle with initialization and cleanup
- **Compositor Rendering** - Buffer-based rendering with Z-order compositing
- **Event Integration** - Built-in event subscription and cleanup management
- **Focus Management** - Comprehensive focus handling and navigation
- **Service Integration** - Dependency injection support for screens
- **Parent-Child Relationships** - Automatic hierarchy management
- **Performance Optimized** - Dirty flagging and efficient redraw logic

## Core Classes

### UIElement (Base Class)
The foundational class for all visual components in the TUI system.

#### Key Properties
- **Position & Size** - `X`, `Y`, `Width`, `Height` for layout
- **Visibility** - `Visible`, `Enabled` for state management
- **Focus** - `IsFocusable`, `IsFocused`, `TabIndex` for navigation
- **Hierarchy** - `Parent`, `Children` for component tree
- **Rendering** - `ZIndex` for layering, private buffer for drawing
- **Metadata** - `Name`, `Metadata` for identification and data attachment

#### Lifecycle Methods (Virtual)
```powershell
# Override in derived classes for custom behavior
[void] OnRender()        # Custom drawing logic
[void] OnResize($w, $h)  # Handle size changes
[void] OnMove($x, $y)    # Handle position changes
[void] OnFocus()         # Handle gaining focus
[void] OnBlur()          # Handle losing focus
[bool] HandleInput($key) # Process keyboard input
```

#### Core Methods
```powershell
# Hierarchy management
$element.AddChild($childElement)
$element.RemoveChild($childElement)

# Layout operations
$element.Resize($newWidth, $newHeight)
$element.Move($newX, $newY)

# Rendering
$element.Render()           # Public render entry point
$element.RequestRedraw()    # Mark for redraw

# Positioning
$absolutePos = $element.GetAbsolutePosition()
$child = $element.GetChildAtPoint($x, $y)
$contains = $element.ContainsPoint($x, $y)
```

### Component Class
A generic container that inherits from `UIElement` and can contain other UI elements.

```powershell
# Create a component container
$container = [Component]::new("MyContainer")
$container.AddChild($button)
$container.AddChild($textBox)
```

**Purpose:** Groups related UI elements and provides a simple container with no special rendering behavior beyond what `UIElement` provides.

### Screen Class
Top-level container for application views with service integration and lifecycle management.

#### Construction
```powershell
# With hashtable services (legacy)
$screen = [Screen]::new("MyScreen", $servicesHashtable)

# With service container (recommended)
$screen = [Screen]::new("MyScreen", $serviceContainer)
```

#### Service Integration
```powershell
class MyScreen : Screen {
    [DataManager]$DataManager
    
    MyScreen([string]$name, [object]$serviceContainer) : base($name, $serviceContainer) {
        # Services are automatically available via $this.Services hashtable
        # or resolve from $this.ServiceContainer
    }
    
    [void] Initialize() {
        # Get services
        $this.DataManager = $this.ServiceContainer.GetService("DataManager")
        
        # Set up UI components
        $this.SetupUI()
        
        # Subscribe to events
        $this.SubscribeToEvent("Data.Changed", {
            param($EventData)
            $this.RefreshDisplay()
        })
    }
}
```

#### Lifecycle Methods (Virtual)
```powershell
[void] Initialize()     # One-time setup after creation
[void] OnEnter()        # When screen becomes active
[void] OnExit()         # When screen becomes inactive
[void] OnResume()       # When screen becomes active again
[void] HandleInput($key) # Screen-level input handling
[void] Cleanup()        # Resource cleanup before destruction
```

## Component Lifecycle

### Initialization Phase
1. **Constructor** - Object created with basic properties
2. **Initialize()** - One-time setup, create child components
3. **OnResize()** - Initial sizing if dimensions change
4. **OnRender()** - Initial drawing to private buffer

### Active Phase
1. **Render()** - Called each frame if dirty
2. **HandleInput()** - Process user input
3. **OnFocus()/OnBlur()** - Focus state changes
4. **OnResize()/OnMove()** - Layout changes

### Cleanup Phase
1. **OnExit()** - Deactivation (for screens)
2. **Cleanup()** - Resource cleanup, event unsubscription
3. **Dispose** - Final cleanup (automatic via GC)

## Rendering System

### Buffer-Based Rendering
Each `UIElement` has a private `TuiBuffer` for its content:

```powershell
class MyComponent : UIElement {
    [void] OnRender() {
        # Clear the private buffer
        $this._private_buffer.Clear()
        
        # Draw custom content
        Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 `
            -Text "Hello World" -ForegroundColor (Get-ThemeColor 'Primary')
        
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
            -Width $this.Width -Height $this.Height `
            -BorderColor (Get-ThemeColor 'Border')
    }
}
```

### Compositor Process
1. **Component Rendering** - Each component draws to its private buffer
2. **Child Composition** - Child buffers are blended onto parent buffers
3. **Z-Order Sorting** - Children rendered in ZIndex order (low to high)
4. **Final Composition** - Root screen buffer sent to TUI engine

### Dirty Flagging
- Components marked dirty when content changes
- Only dirty components re-render their content
- Parent components automatically marked dirty when children change
- Efficient redraw system minimizes unnecessary work

## Event System Integration

### Event Subscription (Screens)
```powershell
class MyScreen : Screen {
    [void] Initialize() {
        # Subscribe to events with automatic cleanup
        $this.SubscribeToEvent("Tasks.Changed", {
            param($EventData)
            $this.RefreshTaskList()
        })
        
        $this.SubscribeToEvent("Theme.Changed", {
            param($EventData)
            $this.RequestRedraw()  # Refresh UI colors
        })
    }
    
    # Cleanup() automatically unsubscribes all events
}
```

### Manual Event Management
```powershell
# For non-screen components, manage events manually
$handlerId = Subscribe-Event -EventName "Data.Updated" -Source $this.Name -Handler {
    param($EventData)
    # Handle event
}

# Clean up in component cleanup
Remove-ComponentEventHandlers -ComponentId $this.Name
```

## Focus Management

### Focus Navigation
```powershell
# Set focusable
$component.IsFocusable = $true
$component.TabIndex = 1

# Handle focus events
class MyComponent : UIElement {
    [void] OnFocus() {
        $this.RequestRedraw()  # Redraw with focus styling
    }
    
    [void] OnBlur() {
        $this.RequestRedraw()  # Redraw without focus styling
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter) {
            # Handle activation
            return $true  # Input consumed
        }
        return $false  # Input not handled
    }
}
```

### Focus Tracking
```powershell
# Screen-level focus management
class MyScreen : Screen {
    [UIElement]$LastFocusedComponent
    
    [void] SetFocus([UIElement]$component) {
        if ($this.LastFocusedComponent) {
            $this.LastFocusedComponent.IsFocused = $false
            $this.LastFocusedComponent.OnBlur()
        }
        
        $component.IsFocused = $true
        $component.OnFocus()
        $this.LastFocusedComponent = $component
    }
}
```

## Advanced Usage Patterns

### Custom Container Components
```powershell
class Panel : UIElement {
    [string]$Title
    [bool]$HasBorder = $true
    
    Panel([string]$name, [string]$title) : base($name) {
        $this.Title = $title
        $this.Width = 40
        $this.Height = 20
    }
    
    [void] OnRender() {
        $this._private_buffer.Clear()
        
        if ($this.HasBorder) {
            $borderColor = if ($this.IsFocused) { (Get-ThemeColor 'Accent') } else { (Get-ThemeColor 'Border') }
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                -Width $this.Width -Height $this.Height `
                -BorderColor $borderColor -Title $this.Title
        }
    }
    
    [void] OnResize([int]$newWidth, [int]$newHeight) {
        # Adjust child layout when size changes
        $this.LayoutChildren()
    }
    
    [void] LayoutChildren() {
        # Custom layout logic for child components
        $contentX = if ($this.HasBorder) { 1 } else { 0 }
        $contentY = if ($this.HasBorder) { 1 } else { 0 }
        $contentWidth = $this.Width - (if ($this.HasBorder) { 2 } else { 0 })
        $contentHeight = $this.Height - (if ($this.HasBorder) { 2 } else { 0 })
        
        # Position children within content area
        foreach ($child in $this.Children) {
            $child.Move($contentX, $contentY)
            $child.Resize($contentWidth, $child.Height)
            $contentY += $child.Height
        }
    }
}
```

### State Management
```powershell
class StatefulComponent : UIElement {
    [hashtable]$State = @{}
    
    [void] SetState([hashtable]$newState) {
        $oldState = $this.State.Clone()
        
        # Merge new state
        foreach ($key in $newState.Keys) {
            $this.State[$key] = $newState[$key]
        }
        
        # Trigger update if state changed
        if ($this.StateChanged($oldState, $this.State)) {
            $this.OnStateChanged($oldState, $this.State)
            $this.RequestRedraw()
        }
    }
    
    [bool] StateChanged([hashtable]$oldState, [hashtable]$newState) {
        # Compare state objects
        foreach ($key in $newState.Keys) {
            if ($oldState[$key] -ne $newState[$key]) {
                return $true
            }
        }
        return $false
    }
    
    [void] OnStateChanged([hashtable]$oldState, [hashtable]$newState) {
        # Override in derived classes
    }
}
```

## Best Practices

### Component Design
1. **Single Responsibility** - Each component should have one clear purpose
2. **Composition Over Inheritance** - Use child components rather than complex inheritance
3. **Event-Driven Updates** - React to data changes via events
4. **Theme Integration** - Always use `Get-ThemeColor` for colors
5. **Proper Cleanup** - Always clean up resources in `Cleanup()` method

### Performance Optimization
1. **Minimize Redraws** - Only call `RequestRedraw()` when visual state changes
2. **Efficient Rendering** - Keep `OnRender()` methods fast and simple
3. **Lazy Loading** - Create expensive child components only when needed
4. **Buffer Reuse** - Don't recreate buffers unnecessarily

### Error Handling
```powershell
class RobustComponent : UIElement {
    [void] OnRender() {
        try {
            # Rendering logic
            $this._private_buffer.Clear()
            $this.DrawContent()
        } catch {
            # Log error but don't crash
            Write-Log -Level Error -Message "Render error in $($this.Name): $($_.Exception.Message)"
            
            # Draw error state
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 `
                -Text "Error" -ForegroundColor ([ConsoleColor]::Red)
        }
    }
}
```

### Memory Management
```powershell
class DisposableComponent : UIElement {
    [System.IDisposable]$Resource
    
    [void] Cleanup() {
        # Clean up managed resources
        if ($this.Resource) {
            $this.Resource.Dispose()
            $this.Resource = $null
        }
        
        # Clean up children
        foreach ($child in $this.Children) {
            if ($child.PSObject.Methods['Cleanup']) {
                $child.Cleanup()
            }
        }
        
        $this.Children.Clear()
    }
}
```

## Integration Examples

### Complete Screen Example
```powershell
class TaskListScreen : Screen {
    [DataManager]$DataManager
    [Panel]$TaskPanel
    [System.Collections.Generic.List[UIElement]]$TaskComponents
    
    TaskListScreen([object]$serviceContainer) : base("TaskList", $serviceContainer) {
        $this.TaskComponents = [System.Collections.Generic.List[UIElement]]::new()
    }
    
    [void] Initialize() {
        # Get services
        $this.DataManager = $this.ServiceContainer.GetService("DataManager")
        
        # Create UI
        $this.TaskPanel = [Panel]::new("TaskPanel", "Tasks")
        $this.TaskPanel.Move(5, 5)
        $this.TaskPanel.Resize(70, 15)
        $this.AddPanel($this.TaskPanel)
        
        # Subscribe to data changes
        $this.SubscribeToEvent("Tasks.Changed", {
            param($EventData)
            $this.RefreshTasks()
        })
        
        # Load initial data
        $this.RefreshTasks()
    }
    
    [void] RefreshTasks() {
        # Clear existing task components
        foreach ($taskComp in $this.TaskComponents) {
            $this.TaskPanel.RemoveChild($taskComp)
        }
        $this.TaskComponents.Clear()
        
        # Get current tasks
        $tasks = $this.DataManager.GetTasks()
        
        # Create task components
        $y = 1
        foreach ($task in $tasks) {
            $taskComponent = [TaskItemComponent]::new($task)
            $taskComponent.Move(1, $y)
            $taskComponent.Resize(66, 1)
            $this.TaskPanel.AddChild($taskComponent)
            $this.TaskComponents.Add($taskComponent)
            $y++
        }
        
        $this.RequestRedraw()
    }
    
    [void] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::F5) { $this.RefreshTasks() }
            ([ConsoleKey]::N) { $this.CreateNewTask() }
        }
    }
    
    [void] CreateNewTask() {
        # Show task creation dialog
        $dialog = [NewTaskDialog]::new($this.ServiceContainer)
        Show-Dialog $dialog
    }
}
```

The ui-classes module provides the essential foundation for building sophisticated, maintainable terminal user interfaces with proper lifecycle management, efficient rendering, and clean architecture patterns.
