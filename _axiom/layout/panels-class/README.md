# Panel Classes Module

## Overview

The Panel Classes module provides foundational layout and container components for the PMC Terminal TUI application. This module contains specialized `UIElement` subclasses that handle layout management, scrolling, and collapsible content organization.

## Features

- **Flexible Layout Management**: Automatic layout with vertical, horizontal, and grid arrangements
- **Scrollable Content**: Advanced scrolling capabilities with virtual content areas
- **Collapsible Panels**: Expandable/collapsible sections for space-efficient UI organization
- **Theme Integration**: Fully integrated with the ThemeManager for consistent appearance
- **Border and Title Support**: Configurable borders and titles with multiple styles
- **Focus Management**: Hierarchical focus management for keyboard navigation
- **Content Area Management**: Intelligent content area calculation and management

## Components

### Panel

The base Panel class provides:

- **Layout Management**: Automatic child positioning with multiple layout types
- **Border Support**: Configurable borders with multiple styles (Single, Double, Rounded, Thick)
- **Title Display**: Optional title display on the top border
- **Content Area**: Intelligent content area calculation excluding borders
- **Focus Management**: Hierarchical focus management for keyboard navigation
- **Theme Integration**: All colors sourced from ThemeManager

#### Layout Types

- **Manual**: No automatic layout, manual positioning
- **Vertical**: Children stacked vertically
- **Horizontal**: Children arranged side-by-side
- **Grid**: Children arranged in a grid pattern

### ScrollablePanel

An enhanced Panel with scrolling capabilities:

- **Virtual Content Area**: Support for content larger than visible area
- **Scroll Controls**: Keyboard navigation with arrows, page up/down, home/end
- **Scrollbar Indicators**: Visual scrollbars showing position and available content
- **Viewport Management**: Efficient rendering of only visible content
- **Scroll Events**: Automatic scroll adjustment to keep content in view

### GroupPanel

A specialized Panel for collapsible content:

- **Expand/Collapse**: Toggle between expanded and collapsed states
- **State Indicators**: Visual indicators showing current state
- **Child Visibility**: Automatic child visibility management
- **Keyboard Control**: Space/Enter to toggle state
- **Height Management**: Automatic height adjustment on state change

## Usage Examples

### Basic Panel

```powershell
$panel = [Panel]::new(10, 5, 40, 20, "My Panel")
$panel.LayoutType = "Vertical"
$panel.HasBorder = $true
$panel.BorderStyle = "Double"
```

### Scrollable Panel

```powershell
$scrollPanel = [ScrollablePanel]::new(10, 5, 40, 20)
$scrollPanel.SetVirtualSize(40, 50)  # Content larger than visible area
$scrollPanel.ShowScrollbars = $true
```

### Collapsible Panel

```powershell
$groupPanel = [GroupPanel]::new(10, 5, 40, 20, "Collapsible Section")
$groupPanel.IsCollapsed = $false
```

## Dependencies

- `ui-classes`: For base UIElement class
- `tui-primitives`: For core TUI rendering functions
- `theme-manager`: For theme-aware color management
- `logger`: For error logging and debugging

## Architecture

The module follows the Axiom-Phoenix architecture principles:

- **Component Lifecycle**: Proper initialization, resize, and cleanup
- **Theme Awareness**: All colors sourced from ThemeManager
- **Error Handling**: Comprehensive error handling with logging
- **Parameter Validation**: Extensive validation for type safety
- **Focus Management**: Hierarchical focus management
- **Layout Flexibility**: Multiple layout strategies for different needs

## Layout Management

The Panel class provides automatic layout management:

### Vertical Layout
Children are stacked vertically with equal height distribution.

### Horizontal Layout
Children are arranged side-by-side with equal width distribution.

### Grid Layout
Children are arranged in a grid pattern, automatically calculating optimal rows and columns.

### Manual Layout
No automatic positioning, allowing precise control over child placement.

## Focus Management

Panels provide hierarchical focus management:

- **Tab Navigation**: Tab key moves focus to first focusable child
- **Focus Tracking**: Maintains focus state and visual indicators
- **Child Enumeration**: Automatic discovery of focusable children
- **Focus Events**: OnFocus/OnBlur events for visual feedback

## Theme Integration

All visual elements respect the current theme:

- `Border`: Panel borders
- `Background`: Panel background
- `Foreground`: Default text color
- `Accent`: Focus indicators
- `Subtle`: Secondary text and indicators

## Performance Considerations

- **Efficient Rendering**: Only visible content is rendered
- **Layout Caching**: Layout calculations are cached when possible
- **Scroll Optimization**: Scrollable panels use viewport-based rendering
- **Memory Management**: Proper cleanup of resources and child components

## Version History

- **v1.0**: Basic Panel implementation with manual layout
- **v2.0**: Added automatic layout types and ScrollablePanel
- **v3.0**: Added GroupPanel, theme integration, and enhanced focus management
- **v4.0**: Performance optimizations and lifecycle improvements
- **v5.0**: Full Axiom-Phoenix integration with enhanced error handling
