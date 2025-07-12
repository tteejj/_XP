# Axiom-Phoenix v4.0 - Hybrid Window Manager Model
# THIS IS THE CORRECT INPUT HANDLING MODEL

## Overview

The framework uses a hybrid window manager model similar to desktop GUI frameworks:
- Each Screen acts as a window manager for its child components
- The Screen manages focus (which component is active)
- Components handle their own input when focused
- The Screen handles navigation between components and global shortcuts

## Key Architecture

```
TUI Engine
    ↓ (sends input)
Current Screen 
    ↓ (if Tab/Shift+Tab → changes focus)
    ↓ (else → routes to focused child)
Focused Component
    ↓ (handles input, returns true/false)
    ↓ (if false → Screen gets second chance)
Screen (fallback handling)
```

## Correct Screen Implementation

```powershell
class YourScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [TextBox] $_searchBox
    hidden [ListBox] $_itemList
    hidden [ButtonComponent] $_saveButton
    
    [void] Initialize() {
        # Create components with IsFocusable = $true for interactive elements
        
        $this._searchBox = [TextBox]::new("SearchBox")
        $this._searchBox.IsFocusable = $true  # CAN receive focus
        $this._searchBox.TabIndex = 0         # Order in tab sequence
        
        $this._itemList = [ListBox]::new("ItemList")
        $this._itemList.IsFocusable = $true   # CAN receive focus
        $this._itemList.TabIndex = 1
        
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.IsFocusable = $true  # CAN receive focus
        $this._saveButton.TabIndex = 2
        
        # Labels and decorative elements should NOT be focusable
        $titleLabel = [LabelComponent]::new("Title")
        $titleLabel.IsFocusable = $false      # Cannot receive focus
    }
    
    [void] OnEnter() {
        # The base Screen class will automatically focus the first focusable child
        # You can also manually set initial focus:
        # $this.SetChildFocus($this._searchBox)
        
        ([Screen]$this).OnEnter()  # IMPORTANT: Call base implementation
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # The base Screen class handles Tab navigation automatically!
        # Just call the base implementation first
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # Handle screen-level shortcuts that work regardless of focus
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                # Global: Go back
                $navService = $this.ServiceContainer.GetService("NavigationService")
                if ($navService.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
            ([ConsoleKey]::F5) {
                # Global: Refresh
                $this.RefreshData()
                return $true
            }
        }
        
        # Handle character shortcuts
        if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Control) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::S) {
                    $this.SaveData()
                    return $true
                }
            }
        }
        
        return $false
    }
    
    # Optional: Override to customize tab order
    hidden [System.Collections.Generic.List[UIElement]] _GetFocusableChildren() {
        # The base implementation finds all focusable children automatically
        # Override only if you need custom ordering beyond TabIndex
        $focusable = ([Screen]$this)._GetFocusableChildren()
        
        # Sort by TabIndex if you set it
        return $focusable | Sort-Object { $_.TabIndex }
    }
}
```

## Component Implementation

Components should handle their own specific input:

```powershell
class TextBox : Component {
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if (-not $this.IsFocused) { return $false }
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Backspace) {
                if ($this.Text.Length -gt 0) {
                    $this.Text = $this.Text.Substring(0, $this.Text.Length - 1)
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::Delete) {
                # Handle delete
                return $true
            }
            ([ConsoleKey]::Enter) {
                # Trigger any OnEnter event
                if ($this.OnEnter) {
                    & $this.OnEnter $this
                }
                return $true
            }
            default {
                # Add character
                if ($keyInfo.KeyChar -and [char]::IsLetterOrDigit($keyInfo.KeyChar)) {
                    $this.Text += $keyInfo.KeyChar
                    $this.RequestRedraw()
                    return $true
                }
            }
        }
        
        # Don't handle navigation keys - let Screen handle them
        return $false
    }
}
```

## Focus Visual Feedback

Components should update their appearance based on focus:

```powershell
class Component : UIElement {
    [void] OnFocus() {
        # Called when component receives focus
        $this.BorderColor = Get-ThemeColor "primary.accent"
        $this.ShowCursor = $true  # For text inputs
        $this.RequestRedraw()
    }
    
    [void] OnBlur() {
        # Called when component loses focus
        $this.BorderColor = Get-ThemeColor "border"
        $this.ShowCursor = $false
        $this.RequestRedraw()
    }
}
```

## Key Principles

1. **Screen is Window Manager** - Screen decides which child has focus
2. **Components Handle Own Input** - When focused, components process their specific keys
3. **Tab Navigation is Automatic** - Base Screen class handles Tab/Shift+Tab
4. **IsFocusable = true** - Set on all interactive components
5. **TabIndex for Order** - Optional property to control tab sequence
6. **Global Shortcuts in Screen** - Screen handles Esc, F-keys, Ctrl combinations
7. **Visual Feedback** - Components show focus state visually

## Input Flow

1. Engine sends key to `Screen.HandleInput()`
2. Screen base class checks for Tab/Shift+Tab → changes focus if needed
3. If not Tab, Screen routes to `_focusedChild.HandleInput()`
4. If child handles it → returns true, done
5. If child returns false → Screen gets second chance for global shortcuts
6. Screen returns final true/false to engine

## Common Patterns

### Screen with Form Fields
```powershell
[void] Initialize() {
    $y = 2
    
    # Create form fields with tab order
    $this._nameBox = [TextBox]::new("Name")
    $this._nameBox.IsFocusable = $true
    $this._nameBox.TabIndex = 0
    $this._nameBox.Y = $y
    $y += 3
    
    $this._emailBox = [TextBox]::new("Email")
    $this._emailBox.IsFocusable = $true
    $this._emailBox.TabIndex = 1
    $this._emailBox.Y = $y
    $y += 3
    
    $this._saveButton = [ButtonComponent]::new("Save")
    $this._saveButton.IsFocusable = $true
    $this._saveButton.TabIndex = 2
    $this._saveButton.OnClick = { $this.SaveForm() }
}
```

### Mixed Interactive and Display Elements
```powershell
[void] Initialize() {
    # Display-only elements
    $header = [LabelComponent]::new("Header")
    $header.IsFocusable = $false  # Cannot be focused
    
    # Interactive list
    $this._list = [ListBox]::new("MainList")
    $this._list.IsFocusable = $true
    $this._list.TabIndex = 0
    
    # Status bar - not focusable
    $status = [Panel]::new("StatusBar")
    $status.IsFocusable = $false
}
```

### Custom Focus Order
```powershell
hidden [void] SetupTabOrder() {
    # After creating all components, set explicit tab order
    $this._field1.TabIndex = 0
    $this._field3.TabIndex = 1  # Skip field2
    $this._field2.TabIndex = 2  # Come back to field2
    $this._submitBtn.TabIndex = 3
    
    # Or override _GetFocusableChildren for complex logic
}
```

## What NOT to Do

1. **DON'T** use the FocusManager service (it's deprecated)
2. **DON'T** handle Tab in components (Screen handles it)
3. **DON'T** set IsFocusable = false on interactive components
4. **DON'T** forget to call base Screen.HandleInput()
5. **DON'T** handle all input in Screen (let components handle their own)

## Migration Checklist

When updating a screen to the hybrid model:
- [ ] Remove all FocusManager service usage
- [ ] Remove manual Tab handling code
- [ ] Set IsFocusable = true on all interactive components
- [ ] Set IsFocusable = false on labels and decorative elements
- [ ] Optional: Set TabIndex for custom tab order
- [ ] Ensure components have HandleInput methods
- [ ] Update components to show focus visually (OnFocus/OnBlur)
- [ ] Call base Screen.HandleInput() at start of screen's HandleInput
- [ ] Move component-specific input to component HandleInput methods
- [ ] Keep global shortcuts in screen HandleInput

## Benefits of Hybrid Model

1. **Reusable Components** - TextBox works the same in any screen
2. **Separation of Concerns** - Components handle their input, screens handle navigation
3. **Automatic Tab Navigation** - No manual tracking needed
4. **Consistent Focus Behavior** - All screens work the same way
5. **Easy to Test** - Components can be tested independently
6. **Extensible** - Easy to add new focusable components

Remember: Let the framework do the work! The Screen base class already handles focus management beautifully.
