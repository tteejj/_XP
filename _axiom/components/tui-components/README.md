# TUI Components Module

## Overview

The TUI Components module provides essential UI building blocks for the PMC Terminal TUI application. This module contains the core interactive components that form the foundation of the user interface, including buttons, text inputs, checkboxes, and other input controls.

## Features

- **Theme Integration**: All components fully integrated with the ThemeManager for consistent appearance
- **Advanced Text Input**: Professional text input with viewport scrolling and non-destructive cursors
- **State Management**: Comprehensive state management with focus, enabled/disabled states
- **Event-Driven Architecture**: Scriptblock callbacks for component interactions
- **Parameter Validation**: Extensive validation for type safety and error prevention
- **Lifecycle Management**: Proper component initialization and cleanup
- **Accessibility**: Keyboard navigation and focus management support

## Components

### LabelComponent

A simple text display component:

- **Static Text Display**: Shows read-only text content
- **Theme-Aware Colors**: Respects current theme colors
- **Flexible Sizing**: Automatic sizing based on content
- **Non-Focusable**: Optimized for display purposes

### ButtonComponent

An interactive button component:

- **Click Events**: OnClick scriptblock callback support
- **Visual Feedback**: Press animation and focus indicators
- **Theme Integration**: State-aware color schemes (normal, focus, pressed)
- **Keyboard Support**: Enter and Spacebar activation
- **Flexible Sizing**: Automatic text centering

### TextBoxComponent

A sophisticated text input component:

- **Viewport Scrolling**: Supports text longer than component width
- **Non-Destructive Cursor**: Block cursor that doesn't hide text
- **Change Events**: OnChange callback for value monitoring
- **Input Validation**: MaxLength and character filtering
- **Placeholder Support**: Placeholder text when empty
- **Advanced Navigation**: Home, End, arrow key support

### CheckBoxComponent

A checkbox input component:

- **Boolean State**: Checked/unchecked state management
- **Change Events**: OnChange callback for state changes
- **Theme Integration**: Focus-aware appearance
- **Keyboard Support**: Enter and Spacebar toggling
- **Text Label**: Configurable label text

### RadioButtonComponent

A radio button component for exclusive selection:

- **Group Management**: Automatic exclusive selection within groups
- **Change Events**: OnChange callback for selection changes
- **Theme Integration**: Focus and selection indicators
- **Keyboard Support**: Enter and Spacebar selection
- **Group Names**: Named groups for logical organization

## Usage Examples

### Basic Button

```powershell
$button = New-TuiButton -Props @{
    Name = "SubmitButton"
    Text = "Submit"
    Width = 12
    Height = 3
    OnClick = {
        Write-Host "Button clicked!"
    }
}
```

### Text Input with Validation

```powershell
$textBox = New-TuiTextBox -Props @{
    Name = "EmailInput"
    Placeholder = "Enter email address"
    MaxLength = 100
    Width = 30
    Height = 3
    OnChange = {
        param($NewValue)
        if ($NewValue -match '^[^@]+@[^@]+\.[^@]+$') {
            Write-Host "Valid email: $NewValue"
        }
    }
}
```

### Radio Button Group

```powershell
$radio1 = New-TuiRadioButton -Props @{
    Name = "Option1"
    Text = "Option 1"
    GroupName = "MyGroup"
    Selected = $true
}

$radio2 = New-TuiRadioButton -Props @{
    Name = "Option2"
    Text = "Option 2"
    GroupName = "MyGroup"
}
```

## Dependencies

- `ui-classes`: For base UIElement class
- `tui-primitives`: For core TUI rendering functions
- `theme-manager`: For theme-aware color management
- `logger`: For error logging and debugging

## Architecture

The module follows the Axiom-Phoenix architecture principles:

- **Component Lifecycle**: Proper initialization and cleanup
- **Theme Awareness**: All colors sourced from ThemeManager
- **Event-Driven**: Scriptblock callbacks for user interactions
- **Error Handling**: Comprehensive error handling with logging
- **Performance**: Efficient rendering with change detection
- **Extensibility**: Factory functions for easy component creation

## Theme Integration

All components respect the current theme with semantic color keys:

- `Foreground`: Default text color
- `Background`: Default background color
- `Border`: Component borders
- `Accent`: Focus indicators and highlights
- `Selection`: Selected state background
- `Subtle`: Placeholder and secondary text

## Advanced Features

### TextBox Viewport Scrolling

The TextBox component supports text longer than its display width through intelligent viewport scrolling:

- **Automatic Scrolling**: Viewport adjusts to keep cursor visible
- **Smooth Navigation**: Arrow keys provide natural text navigation
- **Overflow Handling**: Graceful handling of long text content

### Non-Destructive Cursors

Text input components use non-destructive block cursors:

- **Character Preservation**: Cursor doesn't hide underlying text
- **Color Inversion**: Uses background/foreground color inversion
- **Clear Indication**: Obvious cursor position indication

### State Management

All components maintain comprehensive state:

- **Focus State**: Visual focus indicators
- **Enabled State**: Disabled components ignore input
- **Visibility State**: Hidden components don't render
- **Custom State**: Component-specific state (pressed, selected, etc.)

## Performance Considerations

- **Change Detection**: Only redraw when component state changes
- **Efficient Rendering**: Minimal buffer operations
- **Event Optimization**: Efficient event handling and propagation
- **Memory Management**: Proper cleanup of resources

## Version History

- **v1.0**: Basic component implementations
- **v2.0**: Added theme integration and advanced text input
- **v3.0**: Enhanced error handling and validation
- **v4.0**: Lifecycle management and performance optimizations
- **v5.0**: Full Axiom-Phoenix integration with true color support
