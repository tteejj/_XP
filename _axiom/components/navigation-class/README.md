# Navigation Class Module

## Overview

The Navigation Class module provides contextual navigation menu components for the PMC Terminal TUI application. While global navigation is now handled by the ActionService and CommandPalette, this module provides specialized components for local and contextual menu scenarios such as menu bars, context menus, and embedded navigation panels.

## Important Note

**This module is intended for LOCAL/CONTEXTUAL menus only.** Global application commands should be registered with the ActionService and accessed via the CommandPalette (Ctrl+P). This module provides components for:

- Menu bars (File, Edit, View, etc.)
- Context menus (right-click style menus)
- Embedded navigation panels within specific screens
- Local option selection within components

## Features

- **Theme Integration**: Fully integrated with the ThemeManager for consistent appearance
- **Flexible Orientation**: Support for both horizontal and vertical menu layouts
- **Keyboard Navigation**: Full keyboard support with arrow key navigation
- **Visual Feedback**: Clear selection highlighting and focus indicators
- **Separator Support**: Visual separators for menu organization
- **Action Integration**: Scriptblock-based action execution
- **State Management**: Enabled/disabled and visible/hidden item states
- **Error Handling**: Robust error handling with comprehensive logging

## Components

### NavigationItem

A data class representing a single menu item:

- **Key**: Single character hotkey for the item
- **Label**: Display text for the item
- **Action**: Scriptblock to execute when selected
- **Enabled**: Whether the item can be selected
- **Visible**: Whether the item is displayed
- **Description**: Optional description for tooltips

### NavigationMenu

A UI component for displaying selectable navigation items:

- **Orientation**: Vertical or horizontal layout
- **Selection Highlighting**: Clear visual indication of selected item
- **Keyboard Navigation**: Arrow key navigation between items
- **Hotkey Support**: Direct selection by pressing item keys
- **Separator Support**: Visual dividers between menu sections
- **Theme Awareness**: All colors sourced from ThemeManager

## Usage Examples

### Vertical Context Menu

```powershell
$contextMenu = [NavigationMenu]::new("ContextMenu")
$contextMenu.Orientation = "Vertical"
$contextMenu.Width = 20
$contextMenu.Height = 10

# Add menu items
$contextMenu.AddItem([NavigationItem]::new("N", "New Item", { New-Item }))
$contextMenu.AddItem([NavigationItem]::new("E", "Edit Item", { Edit-Item }))
$contextMenu.AddItem([NavigationItem]::new("D", "Delete Item", { Delete-Item }))
$contextMenu.AddSeparator()
$contextMenu.AddItem([NavigationItem]::new("X", "Exit", { Exit-Context }))
```

### Horizontal Menu Bar

```powershell
$menuBar = [NavigationMenu]::new("MenuBar")
$menuBar.Orientation = "Horizontal"
$menuBar.Width = 80
$menuBar.Height = 1
$menuBar.Separator = " | "

# Add menu bar items
$menuBar.AddItem([NavigationItem]::new("F", "File", { Show-FileMenu }))
$menuBar.AddItem([NavigationItem]::new("E", "Edit", { Show-EditMenu }))
$menuBar.AddItem([NavigationItem]::new("V", "View", { Show-ViewMenu }))
$menuBar.AddItem([NavigationItem]::new("H", "Help", { Show-HelpMenu }))
```

### Embedded Navigation Panel

```powershell
$navPanel = [NavigationMenu]::new("NavigationPanel")
$navPanel.Orientation = "Vertical"

# Add navigation options
$navPanel.AddItem([NavigationItem]::new("1", "Dashboard", { Navigate-Dashboard }))
$navPanel.AddItem([NavigationItem]::new("2", "Tasks", { Navigate-Tasks }))
$navPanel.AddItem([NavigationItem]::new("3", "Projects", { Navigate-Projects }))
$navPanel.AddItem([NavigationItem]::new("4", "Reports", { Navigate-Reports }))
```

## Theme Integration

The NavigationMenu component uses semantic theme colors:

- `menu.item.foreground.normal`: Normal item text color
- `menu.item.foreground.focus`: Focused item text color
- `menu.item.background.focus`: Focused item background color
- `menu.item.hotkey.normal`: Normal hotkey color
- `menu.item.hotkey.focus`: Focused hotkey color
- `menu.item.prefix.normal`: Normal prefix color (selection indicator)
- `menu.item.prefix.focus`: Focused prefix color
- `menu.item.separator`: Separator line color

## Keyboard Navigation

### Vertical Menus

- **↑/↓**: Navigate between items
- **Enter**: Execute selected item
- **Hotkey**: Direct selection by pressing item key
- **Escape**: Close menu (if implemented by parent)

### Horizontal Menus

- **←/→**: Navigate between items
- **Enter**: Execute selected item
- **Hotkey**: Direct selection by pressing item key
- **Escape**: Close menu (if implemented by parent)

## Architecture

### Component Hierarchy

```
UIElement
└── NavigationMenu
    └── NavigationItem[] (data only)
```

### Event Flow

1. **User Input**: Keyboard input captured by NavigationMenu
2. **Navigation**: Arrow keys change selected item
3. **Execution**: Enter key or hotkey executes item action
4. **Action**: Item's scriptblock is executed with error handling
5. **Feedback**: Visual feedback provided through rendering

### Design Patterns

- **Data/View Separation**: NavigationItem holds data, NavigationMenu handles rendering
- **Theme Awareness**: All visual elements use theme colors
- **Error Handling**: Comprehensive error handling with logging
- **Scriptblock Actions**: Flexible action system using scriptblocks

## Use Cases

### Menu Bars

Perfect for application-style menu bars:

```powershell
# Traditional menu bar
$menuBar = [NavigationMenu]::new("MainMenuBar")
$menuBar.Orientation = "Horizontal"
$menuBar.AddItem([NavigationItem]::new("F", "File", { Show-FileMenu }))
$menuBar.AddItem([NavigationItem]::new("E", "Edit", { Show-EditMenu }))
```

### Context Menus

Ideal for right-click style context menus:

```powershell
# Context menu for items
$contextMenu = [NavigationMenu]::new("ItemContextMenu")
$contextMenu.AddItem([NavigationItem]::new("O", "Open", { Open-Selected }))
$contextMenu.AddItem([NavigationItem]::new("R", "Rename", { Rename-Selected }))
$contextMenu.AddSeparator()
$contextMenu.AddItem([NavigationItem]::new("D", "Delete", { Delete-Selected }))
```

### Navigation Panels

Great for embedded navigation within screens:

```powershell
# Side navigation panel
$sideNav = [NavigationMenu]::new("SideNavigation")
$sideNav.Orientation = "Vertical"
$sideNav.AddItem([NavigationItem]::new("1", "Overview", { Show-Overview }))
$sideNav.AddItem([NavigationItem]::new("2", "Details", { Show-Details }))
$sideNav.AddItem([NavigationItem]::new("3", "Settings", { Show-Settings }))
```

## Performance Considerations

- **Efficient Rendering**: Only visible items are rendered
- **Minimal Redraws**: Only redraws when state changes
- **Memory Efficient**: Lightweight data structures
- **Fast Navigation**: Optimized keyboard handling

## Error Handling

- **Action Execution**: Errors in item actions are caught and logged
- **Invalid States**: Graceful handling of invalid selections
- **Null Safety**: Comprehensive null checking
- **Logging**: Detailed error logging for debugging

## Migration from Legacy

If you have existing NavigationMenu usage for global navigation:

### Before (Legacy)
```powershell
$globalMenu = [NavigationMenu]::new("GlobalMenu")
$globalMenu.AddItem([NavigationItem]::new("T", "Tasks", { Navigate-Tasks }))
$globalMenu.AddItem([NavigationItem]::new("P", "Projects", { Navigate-Projects }))
```

### After (Recommended)
```powershell
# Register actions with ActionService
$actionService.RegisterAction("nav.tasks", "Navigate to Tasks", { Navigate-Tasks }, "Navigation")
$actionService.RegisterAction("nav.projects", "Navigate to Projects", { Navigate-Projects }, "Navigation")

# Users access via CommandPalette (Ctrl+P)
```

## Dependencies

- `ui-classes`: For base UIElement class
- `theme-manager`: For theme-aware color management
- `logger`: For error logging and debugging

## Version History

- **v1.0**: Basic navigation menu functionality
- **v2.0**: Added theme integration and keyboard navigation
- **v3.0**: Enhanced rendering and visual feedback
- **v4.0**: Clarified role as contextual menu component
- **v5.0**: Full Axiom-Phoenix integration with improved architecture
