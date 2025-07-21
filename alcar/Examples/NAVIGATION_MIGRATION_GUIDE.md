# Navigation Migration Guide

This guide helps migrate existing screens to use the standardized navigation system.

## Navigation Modes

### 1. SinglePane Mode
For screens with a single list or content area (MainMenuScreen, simple lists)

**Standard Behavior:**
- **↑↓**: Navigate items
- **←/Backspace/Esc**: Go back/exit
- **→/Enter**: Select/activate item
- **Home/End**: Jump to first/last item
- **PageUp/PageDown**: Scroll by page

### 2. MultiPane Mode  
For screens with multiple panels (TaskScreen, FileBrowserScreen, SettingsScreen)

**Standard Behavior:**
- **Tab**: Switch between panes (forward)
- **Shift+Tab**: Switch between panes (backward)
- **↑↓**: Navigate within current pane
- **←**: Previous pane OR go back (if in leftmost pane)
- **→**: Next pane OR select item (if in rightmost pane)
- **Enter**: Activate/select current item

### 3. FormEditing Mode
For settings and dialog screens with editable fields

**Standard Behavior:**
- **↑↓/Tab**: Navigate between fields
- **←→**: Change values (for choice fields)
- **Space**: Toggle boolean fields
- **Enter**: Edit current field
- **Esc**: Cancel and go back

### 4. TextEditing Mode
For text editors

**Standard Behavior:**
- **All arrows**: Move cursor
- **Home/End**: Beginning/end of line
- **Ctrl+Home/End**: Beginning/end of document
- **Esc**: Exit edit mode

## Migration Steps

### Step 1: Update Screen Base Class

Change from:
```powershell
class MyScreen : Screen {
    MyScreen() {
        # Manual key bindings
        $this.BindKey([ConsoleKey]::UpArrow, { ... })
    }
}
```

To:
```powershell
class MyScreen : NavigationScreen {
    MyScreen() {
        $this.NavigationMode = [NavigationMode]::SinglePane
        # Standard navigation applied automatically
    }
    
    # Override standard methods
    [void] MoveUp() {
        # Your up navigation logic
    }
}
```

### Step 2: Implement Required Methods

Based on your navigation mode, implement these methods:

**For SinglePane:**
- `MoveUp()` - Move selection up
- `MoveDown()` - Move selection down  
- `SelectItem()` - Activate selected item
- `GoBack()` - Exit screen (default: sets Active = $false)

**For MultiPane:**
- All SinglePane methods plus:
- `NextPane()` - Switch to next pane
- `PreviousPane()` - Switch to previous pane
- Set `$this.PaneCount` to number of panes

**For FormEditing:**
- `NextField()` - Move to next field
- `PreviousField()` - Move to previous field
- `EditField()` - Start editing current field
- `ToggleField()` - Toggle boolean fields
- `IncrementValue()` / `DecrementValue()` - Change values

### Step 3: Remove Conflicting Bindings

Remove any manual key bindings that conflict with the standard:
- Remove custom arrow key bindings
- Remove Tab bindings (unless absolutely necessary)
- Keep screen-specific shortcuts (letter keys, function keys)

## Example Migrations

### Example 1: Simple List Screen

```powershell
class ProjectsScreen : NavigationScreen {
    [int]$SelectedIndex = 0
    [array]$Projects = @()
    
    ProjectsScreen() {
        $this.NavigationMode = [NavigationMode]::SinglePane
        $this.Title = "Projects"
    }
    
    [void] MoveUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.RequestRender()
        }
    }
    
    [void] MoveDown() {
        if ($this.SelectedIndex -lt $this.Projects.Count - 1) {
            $this.SelectedIndex++
            $this.RequestRender()
        }
    }
    
    [void] SelectItem() {
        # Open selected project
        $project = $this.Projects[$this.SelectedIndex]
        # ... navigation logic
    }
}
```

### Example 2: Multi-Pane Screen

```powershell
class TaskScreen : NavigationScreen {
    [int]$CategoryIndex = 0
    [int]$TaskIndex = 0
    
    TaskScreen() {
        $this.NavigationMode = [NavigationMode]::MultiPane
        $this.PaneCount = 2  # Categories and Tasks
        $this.Title = "Tasks"
    }
    
    [void] MoveUp() {
        if ($this.CurrentPane -eq 0) {
            # In category pane
            if ($this.CategoryIndex -gt 0) {
                $this.CategoryIndex--
            }
        } else {
            # In task pane
            if ($this.TaskIndex -gt 0) {
                $this.TaskIndex--
            }
        }
        $this.RequestRender()
    }
    
    [void] SelectItem() {
        if ($this.CurrentPane -eq 0) {
            # Select category - move to task pane
            $this.NextPane()
        } else {
            # Open task for editing
            $this.EditTask()
        }
    }
}
```

### Example 3: Settings Screen  

```powershell
class SettingsScreen : FormScreen {
    [array]$Settings = @()
    
    SettingsScreen() {
        # FormScreen sets FormEditing mode automatically
        $this.Title = "Settings"
        $this.FieldCount = $this.Settings.Count
    }
    
    [void] ToggleField() {
        $setting = $this.Settings[$this.CurrentField]
        if ($setting.Type -eq "Bool") {
            $setting.Value = -not $setting.Value
            $this.RequestRender()
        }
    }
    
    [void] IncrementValue() {
        $setting = $this.Settings[$this.CurrentField]
        if ($setting.Type -eq "Choice") {
            # Cycle to next option
            $this.NextOption($setting)
            $this.RequestRender()
        }
    }
}
```

## Testing Checklist

After migration, test these scenarios:

- [ ] Up/Down arrows navigate correctly
- [ ] Left arrow goes back from appropriate positions
- [ ] Right arrow enters/selects items appropriately  
- [ ] Tab switches panes (multi-pane only)
- [ ] Enter activates items
- [ ] Escape/Backspace exits properly
- [ ] Page navigation works (PageUp/Down, Home/End)
- [ ] No conflicting key behaviors
- [ ] Visual feedback updates correctly

## Benefits

1. **Consistency**: Users learn one navigation pattern
2. **Predictability**: Same keys do same things everywhere
3. **Accessibility**: Standard patterns work with screen readers
4. **Maintainability**: Changes to navigation apply globally
5. **Muscle Memory**: Users develop efficient navigation habits