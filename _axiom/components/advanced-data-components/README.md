# Advanced Data Components Module

## Overview

The Advanced Data Components module provides sophisticated data display controls for the PMC Terminal TUI application. This module contains the `Table` component, which offers high-performance scrollable data display with theme integration and event-driven selection capabilities.

## Features

- **High-Performance Scrolling**: Efficiently handles large datasets with viewport-based rendering
- **Theme Integration**: Fully integrated with the ThemeManager for consistent appearance
- **Dynamic Column Sizing**: Supports both fixed and auto-sized columns
- **Event-Driven Selection**: Provides callback mechanisms for user selections
- **Flexible Data Handling**: Robust data binding with type safety
- **Professional Formatting**: Advanced cell formatting with alignment and overflow handling

## Components

### Table

A fully-featured data grid component that provides:

- Scrollable viewport for large datasets
- Keyboard navigation (Arrow keys, Page Up/Down, Home/End)
- Selection highlighting with theme-aware colors
- Configurable columns with flexible width sizing
- Event callbacks for selection changes
- Professional text formatting and alignment

#### Usage Example

```powershell
# Create table with columns
$table = New-TuiTable -Props @{
    Name = "MyTable"
    Width = 60
    Height = 15
    ShowBorder = $true
    ShowHeader = $true
    OnSelectionChanged = {
        param($SelectedItem)
        Write-Host "Selected: $($SelectedItem.Name)"
    }
}

# Define columns
$columns = @(
    [TableColumn]::new("Name", "Name", 20)
    [TableColumn]::new("Description", "Description", "Auto")
    [TableColumn]::new("Status", "Status", 10)
)
$table.SetColumns($columns)

# Set data
$data = @(
    [pscustomobject]@{ Name = "Task 1"; Description = "First task"; Status = "Active" }
    [pscustomobject]@{ Name = "Task 2"; Description = "Second task"; Status = "Completed" }
)
$table.SetData($data)
```

## Dependencies

- `tui-primitives`: For core TUI rendering functions
- `ui-classes`: For base UIElement class
- `theme-manager`: For theme-aware color management
- `logger`: For error logging and debugging

## Architecture

The module follows the Axiom-Phoenix architecture principles:

- **Component Lifecycle**: Proper initialization and cleanup
- **Theme Awareness**: All colors sourced from ThemeManager
- **Error Handling**: Comprehensive error handling with logging
- **Performance**: Optimized rendering with viewport scrolling
- **Extensibility**: Designed for easy extension and customization

## Performance Considerations

The Table component uses viewport-based rendering, meaning only visible rows are rendered. This allows efficient handling of datasets with thousands of rows while maintaining smooth scrolling performance.

## Theme Integration

All visual elements respect the current theme:

- `Border`: Component borders
- `Header`: Table headers
- `Selection`: Selected row highlighting
- `Background`: Default background
- `Foreground`: Default text
- `Subtle`: Placeholder text

## Version History

- **v1.0**: Initial implementation with basic table functionality
- **v2.0**: Added scrolling, theme integration, and enhanced selection
- **v3.0**: Dynamic column sizing and event-driven architecture
