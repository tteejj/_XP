# Advanced Input Components Module

## Overview

The Advanced Input Components module provides sophisticated input controls for the PMC Terminal TUI application. These components go beyond basic text input to provide specialized controls for multiline text, numeric input, date selection, and dropdown selection with advanced features like scrolling, validation, and overlay rendering.

## Features

- **Multiline Text Input**: Full-featured text editor with vertical and horizontal scrolling
- **Numeric Input**: Specialized numeric input with spinners, validation, and formatting
- **Date Input**: Date picker with calendar navigation and format validation
- **Combo Box**: Dropdown selection with search, filtering, and overlay rendering
- **Theme Integration**: All components fully integrated with the ThemeManager
- **Advanced Cursors**: Non-destructive block cursors with proper positioning
- **Viewport Scrolling**: Efficient handling of content larger than display area
- **Input Validation**: Real-time validation with visual feedback
- **Overlay Rendering**: True overlay dropdowns that appear above all content

## Components

### MultilineTextBoxComponent

A sophisticated multiline text editor:

- **Line Management**: Dynamic line creation and management
- **Bidirectional Scrolling**: Both vertical and horizontal scrolling
- **Advanced Cursor**: Non-destructive block cursor with proper positioning
- **Text Selection**: Support for text selection and manipulation
- **Line Wrapping**: Configurable line wrapping behavior
- **Placeholder Support**: Placeholder text when empty
- **Change Events**: Real-time change notification

### NumericInputComponent

A specialized numeric input control:

- **Spinner Controls**: Up/down arrows for value adjustment
- **Range Validation**: Minimum and maximum value constraints
- **Decimal Support**: Configurable decimal places
- **Format Validation**: Real-time format validation
- **Step Values**: Configurable increment/decrement steps
- **Suffix Support**: Unit suffixes (%, $, etc.)
- **Keyboard Support**: Full keyboard navigation and input

### DateInputComponent

A date selection control with calendar:

- **Calendar Popup**: Full calendar interface for date selection
- **Format Validation**: Multiple date format support
- **Range Constraints**: Date range validation
- **Keyboard Navigation**: Arrow key navigation in calendar
- **Today Highlighting**: Special highlighting for current date
- **Month/Year Navigation**: Quick navigation to different months/years

### ComboBoxComponent

A dropdown selection control:

- **Overlay Rendering**: True overlay dropdown that appears above content
- **Search Filtering**: Type-ahead search within options
- **Scrolling Support**: Scrollable dropdown for large option lists
- **Custom Rendering**: Configurable item rendering
- **Keyboard Navigation**: Full keyboard support
- **Multiple Selection**: Optional multiple selection mode
- **Grouping Support**: Option grouping and categorization

## Usage Examples

### Multiline Text Input

```powershell
$multilineText = New-TuiMultilineTextBox -Props @{
    Name = "Description"
    Width = 60
    Height = 10
    MaxLines = 50
    MaxLineLength = 200
    Placeholder = "Enter detailed description..."
    OnChange = {
        param($NewValue)
        Write-Host "Text changed: $($NewValue.Length) characters"
    }
}
```

### Numeric Input

```powershell
$numericInput = New-TuiNumericInput -Props @{
    Name = "Amount"
    Width = 20
    Height = 3
    MinValue = 0
    MaxValue = 1000
    DecimalPlaces = 2
    Step = 0.5
    Suffix = " USD"
    OnChange = {
        param($NewValue)
        Write-Host "Amount: $NewValue"
    }
}
```

### Date Input

```powershell
$dateInput = New-TuiDateInput -Props @{
    Name = "DueDate"
    Width = 25
    Height = 3
    DateFormat = "yyyy-MM-dd"
    MinDate = (Get-Date)
    MaxDate = (Get-Date).AddYears(1)
    OnChange = {
        param($NewValue)
        Write-Host "Due date: $NewValue"
    }
}
```

### Combo Box

```powershell
$comboBox = New-TuiComboBox -Props @{
    Name = "Priority"
    Width = 30
    Height = 3
    Items = @("Low", "Medium", "High", "Critical")
    MaxDropDownHeight = 6
    AllowSearch = $true
    OnSelectionChanged = {
        param($SelectedItem)
        Write-Host "Priority: $SelectedItem"
    }
}
```

## Advanced Features

### Viewport Scrolling

All components support viewport scrolling for content larger than the display area:

- **Automatic Scrolling**: Content scrolls automatically to keep cursor visible
- **Smooth Navigation**: Smooth scrolling with keyboard navigation
- **Scrollbar Indicators**: Visual scrollbars showing position and available content
- **Performance Optimized**: Only visible content is rendered

### Theme Integration

All components fully integrate with the theme system:

- `input.border.normal`: Normal border color
- `input.border.focus`: Focused border color
- `input.foreground`: Input text color
- `input.background`: Input background color
- `input.placeholder`: Placeholder text color
- `input.cursor`: Cursor color
- `input.selection`: Selection background color
- `input.suffix`: Suffix text color

### Overlay Rendering

The ComboBox demonstrates advanced overlay rendering:

- **True Overlays**: Dropdown appears above all other content
- **Proper Z-Order**: Overlays respect proper layering
- **Clipping Prevention**: Content never clipped by parent boundaries
- **Focus Management**: Proper focus handling for overlay content

### Input Validation

Real-time input validation with visual feedback:

- **Character Filtering**: Invalid characters prevented from input
- **Format Validation**: Real-time format checking
- **Range Validation**: Value range enforcement
- **Visual Feedback**: Clear indication of validation errors
- **Error Messages**: Descriptive error messages

## Performance Considerations

### Efficient Rendering

- **Viewport-Based**: Only visible content is rendered
- **Change Detection**: Only changed content is redrawn
- **Buffer Optimization**: Efficient buffer management
- **Minimal Redraws**: Smart redraw scheduling

### Memory Management

- **Resource Cleanup**: Proper cleanup of all resources
- **Buffer Pooling**: Efficient buffer reuse
- **Event Cleanup**: Automatic event handler cleanup
- **Memory Monitoring**: Memory usage optimization

## Architecture

### Component Hierarchy

```
UIElement
├── MultilineTextBoxComponent
├── NumericInputComponent
├── DateInputComponent
└── ComboBoxComponent
```

### Event Flow

1. **Input Event**: User input captured by component
2. **Validation**: Input validated against constraints
3. **State Update**: Component state updated
4. **Change Event**: OnChange event fired
5. **Render Request**: Component requests redraw
6. **Render**: Component rendered with new state

### Theme Integration

All components follow the theme integration pattern:

1. **Color Resolution**: Colors resolved from theme manager
2. **State-Based Colors**: Different colors for different states
3. **Fallback Colors**: Graceful fallback for missing theme colors
4. **Dynamic Updates**: Automatic updates when theme changes

## Dependencies

- `ui-classes`: For base UIElement class
- `tui-components`: For basic components like TextBoxComponent
- `tui-primitives`: For core TUI rendering functions
- `theme-manager`: For theme-aware color management
- `logger`: For error logging and debugging

## Version History

- **v1.0**: Basic advanced input components
- **v2.0**: Added theme integration and improved validation
- **v3.0**: Enhanced scrolling and cursor handling
- **v4.0**: Overlay rendering and performance optimizations
- **v5.0**: Full Axiom-Phoenix integration with lifecycle management
