# ui-classes Module

## Overview
The `ui-classes` module provides the foundational class hierarchy for all UI components in PMC Terminal. It defines the base classes that all visual components inherit from, implementing the composite pattern for UI rendering.

## Classes

### UIElement
Base class for all UI components. Implements the composite pattern with parent-child relationships and buffer-based rendering.

**Key Properties:**
- `[string] $Name` - Component identifier
- `[int] $X, $Y` - Position relative to parent
- `[int] $Width, $Height` - Component dimensions
- `[bool] $Visible` - Visibility flag
- `[bool] $Enabled` - Enabled state
- `[bool] $IsFocusable` - Can receive keyboard focus
- `[UIElement] $Parent` - Parent component
- `[List[UIElement]] $Children` - Child components
- `[TuiBuffer] $_private_buffer` - Private rendering buffer

**Key Methods:**
- `AddChild($child)` - Add a child component
- `RemoveChild($child)` - Remove a child component
- `GetAbsolutePosition()` - Get screen coordinates
- `ContainsPoint($x, $y)` - Hit testing
- `RequestRedraw()` - Mark for re-rendering
- `Render()` - Main render method
- `HandleInput($keyInfo)` - Process keyboard input

**Virtual Methods (Override in subclasses):**
- `OnRender()` - Custom rendering logic
- `OnResize($width, $height)` - Handle resize
- `OnMove($x, $y)` - Handle position change
- `OnFocus()` - Handle focus gain
- `OnBlur()` - Handle focus loss

### Component
Simple container class that inherits from UIElement. Used as a base for components that can contain other components but don't need special rendering logic.

### Screen
Top-level container representing a full application view. Manages panels, services, and state.

**Additional Properties:**
- `[hashtable] $Services` - Service references
- `[object] $ServiceContainer` - DI container (optional)
- `[Dictionary] $State` - Screen-specific state
- `[List[UIElement]] $Panels` - Top-level panels
- `[UIElement] $LastFocusedComponent` - Focus tracking

**Screen Lifecycle Methods:**
- `Initialize()` - One-time setup
- `OnEnter()` - Called when screen becomes active
- `OnExit()` - Called when leaving screen
- `OnResume()` - Called when returning to screen
- `Cleanup()` - Resource cleanup

## Dependencies
- `tui-primitives` - For TuiBuffer class

## Usage Example
```powershell
Import-Module ui-classes

# Create a custom component
class MyButton : UIElement {
    [string] $Text
    
    MyButton([string]$text) : base("Button") {
        $this.Text = $text
        $this.IsFocusable = $true
        $this.Width = $text.Length + 4
        $this.Height = 3
    }
    
    [void] OnRender() {
        # Draw button border
        Write-TuiBox -Buffer $this._private_buffer `
            -X 0 -Y 0 `
            -Width $this.Width -Height $this.Height `
            -BorderStyle "Single"
        
        # Draw button text
        Write-TuiText -Buffer $this._private_buffer `
            -X 2 -Y 1 `
            -Text $this.Text `
            -ForegroundColor ($this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::White)
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($keyInfo.Key -eq [ConsoleKey]::Enter) {
            Write-Host "Button pressed: $($this.Text)"
            return $true
        }
        return $false
    }
}

# Create a screen
class MyScreen : Screen {
    MyScreen([hashtable]$services) : base("MyScreen", $services) {
        # Create a button
        $button = [MyButton]::new("Click Me")
        $button.Move(10, 5)
        $this.AddChild($button)
    }
}
```

## Design Patterns
- **Composite Pattern**: Components can contain other components
- **Template Method**: Virtual methods for customization
- **Buffer-based Rendering**: Each component renders to its own buffer
- **Dirty Flag**: Only re-render when needed
