# Axiom-Phoenix v4.0 - Hybrid Model Migration Plan
# Refactoring screens from direct input to hybrid window manager model

## Overview

Many screens were incorrectly "fixed" to handle all input directly with components set to IsFocusable = false. These need to be updated to use the hybrid model where:
- Components have IsFocusable = true
- Components handle their own input
- Screen manages focus using base class methods
- Tab navigation is automatic

## Screens Requiring Updates

### 1. DashboardScreen ✅ (Simple - Display Only)
**Current:** Direct input handling, no focusable components
**Required Changes:** 
- This screen only shows menu items, no interactive components
- Can keep as-is since it's just a menu selector
- No changes needed

### 2. TaskListScreen ❌ (Needs Update)
**Current:** Manual tracking of $_activeComponent, direct text input
**Required Changes:**
- Set `$_taskListBox.IsFocusable = $true`
- Set `$_filterBox.IsFocusable = $true`
- Remove `$_activeComponent` tracking
- Move text input handling to TextBoxComponent
- Let base Screen handle Tab navigation
- Add TabIndex properties

### 3. EditTaskScreen ❌ (Complex - Needs Major Update)
**Current:** Complex manual field tracking with $_activeField and $_fieldOrder
**Required Changes:**
- Set IsFocusable = true on all form components
- Remove $_activeField, $_fieldOrder, $_currentFieldIndex
- Set TabIndex on each component for proper order
- Move text input to TextBoxComponent.HandleInput
- Move list navigation to ListBox.HandleInput
- Simplify HandleInput to just global shortcuts

### 4. NewTaskScreen ❌ (Needs Update)  
**Current:** Manual focus tracking with $_focusIndex and $_focusOrder
**Required Changes:**
- Set IsFocusable = true on text boxes and buttons
- Remove manual focus tracking
- Set TabIndex for proper order
- Move text input to components

### 5. FileCommanderScreen ❌ (Special Case)
**Current:** Dual-pane with $_leftPanelActive tracking
**Required Changes:**
- This is a special case - dual pane interface
- May need custom focus logic to switch between panes
- Each pane's ListBox should be focusable
- Tab switches panes (custom logic needed)

### 6. ProjectsListScreen ❌ (Needs Update)
**Current:** Manual $_activeComponent tracking
**Required Changes:**
- Set search box and list as focusable
- Remove manual component tracking
- Use TabIndex

### 7. ProjectInfoScreen ✅ (Display Only)
**Current:** No interactive components, just scrolling
**Required Changes:**
- This is mostly display-only
- ScrollablePanel handles its own scrolling
- No changes needed

### 8. ProjectEditDialog ❌ (Needs Update)
**Current:** Complex form with manual tracking
**Required Changes:**
- Set all form fields as focusable
- Remove manual tracking
- Use TabIndex for field order

### 9. ThemeScreen ✅ (Simple List)
**Current:** Direct list navigation
**Required Changes:**
- Minor: Set ListBox.IsFocusable = true
- Move arrow key handling to ListBox

## Component Updates Needed

### TextBoxComponent
Needs proper HandleInput implementation:
```powershell
[bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
    if (-not $this.IsFocused) { return $false }
    
    switch ($keyInfo.Key) {
        ([ConsoleKey]::Backspace) {
            if ($this.Text.Length -gt 0) {
                $this.Text = $this.Text.Substring(0, $this.Text.Length - 1)
                $this.CursorPosition = [Math]::Max(0, $this.CursorPosition - 1)
                $this.RequestRedraw()
            }
            return $true
        }
        ([ConsoleKey]::Delete) {
            # Implement delete at cursor
            return $true
        }
        ([ConsoleKey]::LeftArrow) {
            $this.CursorPosition = [Math]::Max(0, $this.CursorPosition - 1)
            $this.RequestRedraw()
            return $true
        }
        ([ConsoleKey]::RightArrow) {
            $this.CursorPosition = [Math]::Min($this.Text.Length, $this.CursorPosition + 1)
            $this.RequestRedraw()
            return $true
        }
        ([ConsoleKey]::Home) {
            $this.CursorPosition = 0
            $this.RequestRedraw()
            return $true
        }
        ([ConsoleKey]::End) {
            $this.CursorPosition = $this.Text.Length
            $this.RequestRedraw()
            return $true
        }
        ([ConsoleKey]::Enter) {
            if ($this.OnEnter) {
                & $this.OnEnter $this
            }
            return $true
        }
        default {
            if ($keyInfo.KeyChar -and $keyInfo.KeyChar -ne "`0") {
                # Insert character at cursor position
                $this.Text = $this.Text.Insert($this.CursorPosition, $keyInfo.KeyChar)
                $this.CursorPosition++
                $this.RequestRedraw()
                return $true
            }
        }
    }
    return $false
}
```

### ListBox
Needs proper HandleInput for arrow navigation:
```powershell
[bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
    if (-not $this.IsFocused) { return $false }
    
    switch ($keyInfo.Key) {
        ([ConsoleKey]::UpArrow) {
            if ($this.SelectedIndex -gt 0) {
                $this.SelectedIndex--
                $this.EnsureVisible($this.SelectedIndex)
                if ($this.SelectedIndexChanged) {
                    & $this.SelectedIndexChanged $this $this.SelectedIndex
                }
                $this.RequestRedraw()
            }
            return $true
        }
        ([ConsoleKey]::DownArrow) {
            if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                $this.SelectedIndex++
                $this.EnsureVisible($this.SelectedIndex)
                if ($this.SelectedIndexChanged) {
                    & $this.SelectedIndexChanged $this $this.SelectedIndex
                }
                $this.RequestRedraw()
            }
            return $true
        }
        ([ConsoleKey]::PageUp) {
            $pageSize = $this.Height - 2
            $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
            $this.EnsureVisible($this.SelectedIndex)
            $this.RequestRedraw()
            return $true
        }
        ([ConsoleKey]::PageDown) {
            $pageSize = $this.Height - 2
            $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $pageSize)
            $this.EnsureVisible($this.SelectedIndex)
            $this.RequestRedraw()
            return $true
        }
        ([ConsoleKey]::Home) {
            $this.SelectedIndex = 0
            $this.EnsureVisible($this.SelectedIndex)
            $this.RequestRedraw()
            return $true
        }
        ([ConsoleKey]::End) {
            $this.SelectedIndex = $this.Items.Count - 1
            $this.EnsureVisible($this.SelectedIndex)
            $this.RequestRedraw()
            return $true
        }
        ([ConsoleKey]::Enter) {
            if ($this.OnItemSelected) {
                & $this.OnItemSelected $this $this.SelectedIndex
            }
            return $true
        }
    }
    return $false
}
```

### ButtonComponent
```powershell
[bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
    if (-not $this.IsFocused) { return $false }
    
    switch ($keyInfo.Key) {
        ([ConsoleKey]::Enter) {
            if ($this.OnClick) {
                & $this.OnClick $this
            }
            return $true
        }
        ([ConsoleKey]::Spacebar) {
            if ($this.OnClick) {
                & $this.OnClick $this
            }
            return $true
        }
    }
    return $false
}
```

## Implementation Order

1. **First: Update Base Components** (TextBoxComponent, ListBox, ButtonComponent)
   - Add proper HandleInput methods
   - Ensure OnFocus/OnBlur update visuals

2. **Second: Simple Screens**
   - ThemeScreen (just set ListBox focusable)
   - ProjectsListScreen (search + list)

3. **Third: Form Screens**
   - NewTaskScreen
   - EditTaskScreen  
   - ProjectEditDialog

4. **Fourth: Complex Screens**
   - TaskListScreen (has filter mode)
   - FileCommanderScreen (dual pane)

5. **Fifth: Cleanup**
   - Remove FocusManager stub service
   - Update old INPUT_HANDLING_GUIDE.md
   - Delete FOCUSMANAGER_REMOVAL_PROGRESS.md

## Testing Each Screen

After updating each screen:
1. Tab navigation works automatically
2. Shift+Tab goes backwards
3. Text input works in text boxes
4. Arrow keys work in lists
5. Enter/Space activate buttons
6. Escape goes back
7. Visual focus indicators update
8. Global shortcuts still work

## Special Considerations

### FileCommanderScreen
This screen has a dual-pane interface. Options:
1. Make each pane a separate focusable container
2. Use Tab to switch panes, then focus navigates within pane
3. Or keep manual pane switching with custom logic

### Dialog Overlays
Dialogs should:
- Call `InvalidateFocusCache()` when shown
- Focus first field automatically
- Return focus to previous screen when closed

### Performance
The hybrid model is more efficient:
- No manual tracking of active components
- Framework handles focus automatically
- Components are self-contained

## Success Criteria

✅ All screens use base Screen focus management
✅ Components have IsFocusable = true where appropriate  
✅ Tab navigation works without manual code
✅ Each component handles its own input
✅ Visual focus feedback works
✅ No FocusManager service usage
✅ Consistent behavior across all screens
