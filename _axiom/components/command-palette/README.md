# Command Palette Module

## Overview

The Command Palette module provides a powerful, searchable command interface for the PMC Terminal TUI application. Inspired by modern IDE command palettes, this component allows users to quickly find and execute any registered action through a fuzzy search interface.

## Features

- **Fuzzy Search**: Intelligent search across action names and descriptions
- **Modal Interface**: Overlay-based modal design that doesn't interrupt workflow
- **Keyboard Navigation**: Full keyboard navigation with arrow keys and shortcuts
- **Theme Integration**: Fully integrated with the ThemeManager for consistent appearance
- **Action Integration**: Seamless integration with the ActionService for action execution
- **Performance Optimized**: Efficient rendering and filtering for large action sets
- **Responsive Design**: Automatically sizes and positions based on screen dimensions
- **Visual Feedback**: Clear selection highlighting and status indicators

## Architecture

The Command Palette follows a sophisticated component architecture:

### Core Components

- **CommandPalette**: Main component class extending UIElement
- **TextBoxComponent**: Integrated search input with placeholder text
- **ActionService**: Backend service providing all available actions
- **Event System**: Event-driven activation and communication

### Design Pattern

The Command Palette uses a modal overlay pattern:

1. **Activation**: Global hotkey (Ctrl+P) publishes activation event
2. **Display**: Component shows as modal overlay centered on screen
3. **Interaction**: User types to filter actions and navigates with keyboard
4. **Execution**: Selected action is executed and palette closes
5. **Cleanup**: Component properly cleans up resources and returns focus

## Usage

### Basic Setup

```powershell
# Register the command palette during application startup
$actionService = Get-Service "ActionService"
$keybindingService = Get-Service "KeybindingService"

$palette = Register-CommandPalette -ActionService $actionService -KeybindingService $keybindingService
```

### Activation

```powershell
# The palette is activated by the global hotkey Ctrl+P
# Users can also programmatically show it:
Publish-Event -EventName "CommandPalette.Open"
```

### Custom Actions

```powershell
# Register actions that will appear in the palette
$actionService.RegisterAction(
    "task.create",
    "Create a new task",
    { New-Task },
    "Tasks"
)

$actionService.RegisterAction(
    "project.open",
    "Open a project",
    { Open-Project },
    "Projects"
)
```

## User Experience

### Search Behavior

The Command Palette provides intuitive search:

- **Fuzzy Matching**: Partial matches across action names and descriptions
- **Real-time Filtering**: Results update as user types
- **Case Insensitive**: Search is case-insensitive for ease of use
- **Wildcard Support**: Uses PowerShell's `-like` operator for flexible matching

### Navigation

- **Arrow Keys**: ↑/↓ to navigate through results
- **Page Navigation**: PageUp/PageDown for quick scrolling
- **Home/End**: Jump to first/last result
- **Enter**: Execute selected action
- **Escape**: Close palette without executing

### Visual Design

- **Centered Modal**: Appears in center of screen for focus
- **Title Bar**: Shows "Command Palette" with result count
- **Search Box**: Prominent search input with placeholder text
- **Results List**: Scrollable list of filtered actions
- **Help Text**: Bottom border shows available shortcuts
- **Selection Highlight**: Clear visual indication of selected item

## Integration Points

### ActionService Integration

The Command Palette integrates seamlessly with the ActionService:

```powershell
# Retrieves all registered actions
$actions = $actionService.GetAllActions()

# Executes selected action by name
$actionService.ExecuteAction($actionName)
```

### Event System Integration

Uses the event system for loose coupling:

```powershell
# Listens for activation events
Subscribe-Event -EventName "CommandPalette.Open" -Handler { $this.Show() }

# Publishes activation events
Publish-Event -EventName "CommandPalette.Open"
```

### Theme Integration

All visual elements respect the current theme:

- `Accent`: Border color and focus indicators
- `Selection`: Selected item background
- `Background`: Default background color
- `Foreground`: Default text color
- `Subtle`: Help text and secondary information

## Performance Considerations

### Efficient Filtering

- **Lazy Loading**: Actions loaded once on first show
- **Optimized Search**: Simple but effective fuzzy matching
- **Viewport Rendering**: Only visible items are rendered
- **Debounced Updates**: Efficient handling of rapid typing

### Memory Management

- **Resource Cleanup**: Proper disposal of resources on hide
- **Buffer Management**: Efficient buffer allocation and reuse
- **Event Cleanup**: Automatic unsubscription from events

## Configuration

### Appearance Settings

```powershell
# Palette dimensions are calculated dynamically:
$width = [Math]::Min(80, $screenWidth - 10)
$height = [Math]::Min(20, $screenHeight - 6)
```

### Search Configuration

```powershell
# Search behavior can be customized:
$searchBox.Placeholder = "Type to search actions..."
$searchBox.MaxLength = 100
```

### Keybinding Configuration

```powershell
# Default keybinding can be changed:
$keybindingService.SetBinding("app.showCommandPalette", 'P', @('Ctrl'))
```

## Error Handling

The Command Palette includes comprehensive error handling:

- **Action Execution Errors**: Caught and displayed to user
- **Service Unavailability**: Graceful degradation when services unavailable
- **Rendering Errors**: Non-fatal errors logged and recovered
- **Input Validation**: Safe handling of all user input

## Accessibility

- **Keyboard Only**: Fully accessible via keyboard
- **Clear Focus**: Obvious focus indicators
- **Screen Reader**: Semantic structure for screen readers
- **High Contrast**: Respects theme high contrast settings

## Extension Points

### Custom Filtering

```powershell
# Override filtering logic for custom behavior
class CustomCommandPalette : CommandPalette {
    hidden [void] _UpdateFilter([string]$query) {
        # Custom filtering implementation
    }
}
```

### Custom Rendering

```powershell
# Override rendering for custom appearance
[void] OnRender() {
    # Custom rendering logic
}
```

## Version History

- **v1.0**: Basic command palette with simple search
- **v2.0**: Added fuzzy search and keyboard navigation
- **v3.0**: Theme integration and performance optimizations
- **v4.0**: ActionService integration and event-driven architecture
- **v5.0**: Full Axiom-Phoenix integration with lifecycle management

## Dependencies

- `ui-classes`: For base UIElement class
- `tui-components`: For TextBoxComponent
- `tui-primitives`: For core TUI rendering functions
- `theme-manager`: For theme-aware color management
- `action-service`: For action registration and execution
- `keybinding-service`: For hotkey registration
- `event-system`: For event-driven communication
- `logger`: For comprehensive logging
