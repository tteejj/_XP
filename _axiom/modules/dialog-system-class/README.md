# Dialog System Module

## Overview

The Dialog System module provides a comprehensive framework for creating modal dialogs in the PMC Terminal TUI application. This module supports various dialog types including alerts, confirmations, input prompts, and custom dialogs with modern promise-based asynchronous handling.

## Features

- **Modern Promise-Based API**: Async/await support for clean, linear code
- **Theme Integration**: Fully integrated with the ThemeManager for consistent appearance
- **Component Lifecycle**: Proper initialization and cleanup with resource management
- **Multiple Dialog Types**: Alert, Confirm, Input, and custom dialog support
- **Event-Driven Architecture**: Comprehensive callback system for dialog interactions
- **Keyboard Navigation**: Full keyboard support with intuitive navigation
- **Responsive Design**: Automatic sizing and positioning based on content
- **Error Handling**: Robust error handling with graceful fallbacks

## Dialog Types

### AlertDialog

A simple message dialog with an OK button:

- **Single Action**: OK button for acknowledgment
- **Message Display**: Supports multi-line message text
- **Auto-Sizing**: Automatically sizes based on message content
- **Theme-Aware**: Respects current theme colors

### ConfirmDialog

A confirmation dialog with Yes/No options:

- **Two Actions**: Yes and No buttons
- **Keyboard Navigation**: Tab between buttons, Enter to select
- **Boolean Result**: Returns true for Yes, false for No
- **Focus Management**: Clear visual focus indicators

### InputDialog

A dialog for text input with validation:

- **Advanced Text Input**: Uses enhanced TextBoxComponent
- **Validation Support**: OnChange events for input validation
- **Default Values**: Support for pre-filled text
- **Cancellation**: Escape key to cancel input

### Custom Dialogs

Extensible base dialog class for custom implementations:

- **Base Dialog Class**: Foundation for custom dialog types
- **Component Composition**: Add child components as needed
- **Lifecycle Management**: Proper initialization and cleanup
- **Event Handling**: Comprehensive input and event management

## Usage Examples

### Simple Alert

```powershell
# Show a simple alert message
$result = await Show-AlertDialog -Title "Success" -Message "Operation completed successfully!"
```

### Confirmation Dialog

```powershell
# Get user confirmation
$confirmed = await Show-ConfirmDialog -Title "Delete" -Message "Are you sure you want to delete this item?"
if ($confirmed) {
    # User confirmed, proceed with deletion
    Write-Host "Item deleted"
} else {
    # User cancelled
    Write-Host "Operation cancelled"
}
```

### Input Dialog

```powershell
# Get user input
$userInput = await Show-InputDialog -Title "Name" -Message "Enter your name:" -DefaultValue "John Doe"
if ($userInput) {
    Write-Host "Hello, $userInput!"
}
```

### Custom Dialog

```powershell
# Create a custom dialog
class MyCustomDialog : Dialog {
    MyCustomDialog() : base("CustomDialog") {
        $this.Title = "Custom Dialog"
        $this.Message = "This is a custom dialog"
        $this.Width = 60
        $this.Height = 12
    }
    
    [void] OnInitialize() {
        # Add custom components here
        $button = New-TuiButton -Props @{
            Name = "CustomButton"
            Text = "Click Me"
            OnClick = { $this.Close("Custom result") }
        }
        $this.AddChild($button)
    }
}
```

## Dependencies

- `ui-classes`: For base UIElement class
- `tui-components`: For enhanced TextBoxComponent
- `tui-primitives`: For core TUI rendering functions
- `theme-manager`: For theme-aware color management
- `logger`: For error logging and debugging

## Architecture

The module follows the Axiom-Phoenix architecture principles:

- **Component Lifecycle**: Proper initialization, rendering, and cleanup
- **Promise-Based API**: Modern async/await pattern for clean code
- **Theme Awareness**: All colors sourced from ThemeManager
- **Error Handling**: Comprehensive error handling with logging
- **Resource Management**: Automatic cleanup of dialog resources
- **Extensibility**: Easy to extend with custom dialog types

## Promise-Based API

The dialog system uses a modern promise-based API that eliminates callback hell:

### Traditional Callback Approach (Avoided)

```powershell
Show-ConfirmDialog -Title "Delete" -Message "Really?" -OnConfirm {
    Show-AlertDialog -Title "Success" -Message "Deleted." -OnConfirm {
        # More nested callbacks...
    }
} -OnCancel {
    # Cancel logic...
}
```

### Modern Promise-Based Approach

```powershell
$confirmed = await Show-ConfirmDialog -Title "Delete" -Message "Really?"
if ($confirmed) {
    await Show-AlertDialog -Title "Success" -Message "Deleted."
    # Linear, readable code...
} else {
    # Cancel logic...
}
```

## Theme Integration

All dialog visual elements respect the current theme:

- `dialog.background`: Dialog background color
- `dialog.border`: Dialog border color
- `dialog.title`: Dialog title text color
- `dialog.message`: Dialog message text color
- `dialog.button.normal.foreground`: Normal button text color
- `dialog.button.normal.background`: Normal button background color
- `dialog.button.focus.foreground`: Focused button text color
- `dialog.button.focus.background`: Focused button background color

## Keyboard Navigation

All dialogs support comprehensive keyboard navigation:

- **Tab**: Navigate between buttons and inputs
- **Enter**: Activate selected button or confirm input
- **Escape**: Cancel dialog and return null/false
- **Arrow Keys**: Navigate between options in choice dialogs
- **Spacebar**: Alternative activation for buttons

## Error Handling

The dialog system includes robust error handling:

- **Graceful Degradation**: Dialogs continue to function even with theme errors
- **Resource Cleanup**: Automatic cleanup on errors
- **Logging**: Comprehensive error logging for debugging
- **User Feedback**: Clear error messages for user-facing issues

## Performance Considerations

- **Lazy Initialization**: Components created only when needed
- **Efficient Rendering**: Minimal redraws with change detection
- **Memory Management**: Proper disposal of resources
- **Event Optimization**: Efficient event handling and cleanup

## Version History

- **v1.0**: Basic dialog implementations with callback-based API
- **v2.0**: Added theme integration and enhanced keyboard navigation
- **v3.0**: Promise-based API and improved error handling
- **v4.0**: Component lifecycle integration and resource management
- **v5.0**: Full Axiom-Phoenix integration with advanced features
