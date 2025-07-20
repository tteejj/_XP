# ALCAR Screen Building Guide

## Overview

This guide provides comprehensive instructions for building consistent, performant screens in the ALCAR TUI framework. Follow these patterns to ensure your screens integrate seamlessly with the existing codebase.

## Core Principles

### 1. **Performance First**
- Use string concatenation for rendering, not Write-Host
- Minimize ANSI escape sequences
- Implement efficient scrolling and viewport management
- Cache rendered content when possible

### 2. **Consistent Navigation**
- Use NavigationStandard class for standardized key bindings
- Follow established navigation patterns
- Implement proper focus management

### 3. **Clean Architecture**
- Separate UI from business logic
- Use services for data management
- Follow established patterns

## Screen Types & Templates

### Single-Pane Screen (Lists, Menus)

```powershell
class MyScreen : Screen {
    [System.Collections.ArrayList]$Items
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    
    MyScreen() {
        $this.Title = "MY SCREEN"
        $this.InitializeNavigation()
        $this.LoadData()
        $this.BindKeys()
    }
    
    [void] InitializeNavigation() {
        # Use standard single-pane navigation
        [NavigationStandard]::ApplyTo($this, [NavigationMode]::SinglePane)
    }
    
    [void] BindKeys() {
        # Override standard bindings as needed
        $this.BindKey([ConsoleKey]::N, { $this.NewItem() })
        $this.BindKey([ConsoleKey]::E, { $this.EditItem() })
        $this.BindKey([ConsoleKey]::D, { $this.DeleteItem() })
    }
    
    # Required navigation methods
    [void] MoveUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.EnsureVisible()
            $this.RequestRender()
        }
    }
    
    [void] MoveDown() {
        if ($this.SelectedIndex -lt $this.Items.Count - 1) {
            $this.SelectedIndex++
            $this.EnsureVisible()
            $this.RequestRender()
        }
    }
    
    [void] SelectItem() {
        if ($this.Items.Count -gt 0) {
            $item = $this.Items[$this.SelectedIndex]
            # Handle selection
        }
    }
    
    [void] EnsureVisible() {
        $viewHeight = 20  # Adjust based on your layout
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $viewHeight) {
            $this.ScrollOffset = $this.SelectedIndex - $viewHeight + 1
        }
    }
    
    [string] Render() {
        $output = ""
        
        # Header
        $output += [VT]::MoveTo(2, 1) + [VT]::TextBright() + $this.Title + [VT]::Reset()
        
        # Render list
        $startY = 3
        for ($i = 0; $i -lt 20; $i++) {
            $itemIndex = $i + $this.ScrollOffset
            $y = $startY + $i
            
            $output += [VT]::MoveTo(2, $y)
            
            if ($itemIndex -lt $this.Items.Count) {
                $item = $this.Items[$itemIndex]
                $text = $item.ToString()  # Customize as needed
                
                if ($itemIndex -eq $this.SelectedIndex) {
                    $output += [VT]::Selected() + $text + [VT]::Reset()
                } else {
                    $output += [VT]::Text() + $text + [VT]::Reset()
                }
            }
            
            $output += [VT]::ClearLine()
        }
        
        return $output
    }
}
```

### Multi-Pane Screen (Dashboard, Projects)

```powershell
class MyMultiPaneScreen : Screen {
    [ThreePaneLayout]$Layout
    [int]$SelectedIndex = 0
    
    MyMultiPaneScreen() {
        $this.Title = "MULTI-PANE SCREEN"
        $this.InitializeLayout()
        $this.InitializeNavigation()
        $this.LoadData()
        $this.BindKeys()
    }
    
    [void] InitializeLayout() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        $this.Layout = [ThreePaneLayout]::new($width, $height, 25, 30)
        $this.Layout.LeftPane.Title = "LEFT"
        $this.Layout.MiddlePane.Title = "MIDDLE"
        $this.Layout.RightPane.Title = "RIGHT"
        $this.Layout.SetFocus(0)
    }
    
    [void] InitializeNavigation() {
        # Use standard multi-pane navigation
        [NavigationStandard]::ApplyTo($this, [NavigationMode]::MultiPane)
    }
    
    # Required navigation methods
    [void] NextPane() {
        $this.Layout.SetFocus(($this.Layout.FocusedPane + 1) % 3)
        $this.RequestRender()
    }
    
    [void] PreviousPane() {
        $newPane = $this.Layout.FocusedPane - 1
        if ($newPane -lt 0) { $newPane = 2 }
        $this.Layout.SetFocus($newPane)
        $this.RequestRender()
    }
    
    [bool] CanMoveToNextPane() { return $this.Layout.FocusedPane -lt 2 }
    [bool] CanMoveToPreviousPane() { return $this.Layout.FocusedPane -gt 0 }
}
```

### Dialog/Form Screen

```powershell
class MyDialog : Dialog {
    [System.Collections.ArrayList]$Fields
    [int]$CurrentField = 0
    
    MyDialog([string]$title) : base($title) {
        $this.DialogWidth = 50
        $this.DialogHeight = 15
        $this.InitializeFields()
        $this.InitializeNavigation()
    }
    
    [void] InitializeNavigation() {
        [NavigationStandard]::ApplyTo($this, [NavigationMode]::FormEditing)
    }
    
    # Required form methods
    [void] NextField() {
        if ($this.CurrentField -lt $this.Fields.Count - 1) {
            $this.CurrentField++
            $this.RequestRender()
        }
    }
    
    [void] PreviousField() {
        if ($this.CurrentField -gt 0) {
            $this.CurrentField--
            $this.RequestRender()
        }
    }
    
    [void] EditField() {
        $field = $this.Fields[$this.CurrentField]
        # Implement field editing logic
    }
}
```

## Navigation Standards

### Standard Key Bindings

| Context | Key | Action |
|---------|-----|--------|
| **Single Pane** | ↑/↓ | Navigate items |
| | ←/Escape/Backspace | Exit/Back |
| | →/Enter | Select/Open |
| **Multi Pane** | ↑/↓ | Navigate within pane |
| | Tab | Switch panes |
| | ←/→ | Pane navigation + fallback |
| | Escape | Exit |
| **Form** | ↑/↓/Tab | Navigate fields |
| | ←/→ | Adjust values |
| | Enter | Edit field |
| | Escape | Cancel |

### Navigation Implementation

Always use the NavigationStandard class:

```powershell
# In constructor
[NavigationStandard]::ApplyTo($this, [NavigationMode]::SinglePane)

# Required methods to implement
[void] MoveUp() { }
[void] MoveDown() { }
[void] SelectItem() { }
[void] GoBack() { $this.Active = $false }
```

## Visual Styling

### Color Palette (VT Class)

```powershell
# Use consistent colors
[VT]::TextBright()     # Headers, titles
[VT]::Text()           # Normal text
[VT]::TextDim()        # Hints, help text
[VT]::Selected()       # Selected items
[VT]::Border()         # Borders, frames
[VT]::Accent()         # Highlights, success
[VT]::Warning()        # Warnings
[VT]::Error()          # Errors
```

### Layout Guidelines

1. **Consistent Margins**: Start content at column 2, row 3
2. **Clear Hierarchy**: Use headers, spacing, and colors effectively
3. **Responsive**: Adapt to console width/height
4. **Clean Lines**: Use `[VT]::ClearLine()` to prevent artifacts

## Performance Best Practices

### 1. String-Based Rendering
```powershell
# GOOD: Build output string
[string] Render() {
    $output = ""
    $output += [VT]::MoveTo(1, 1) + "Header"
    $output += [VT]::MoveTo(1, 2) + "Content"
    return $output
}

# BAD: Direct console writes
[void] Render() {
    Write-Host "Header" -NoNewline
    Write-Host "Content"
}
```

### 2. Efficient Scrolling
```powershell
[void] EnsureVisible() {
    $viewHeight = 20
    if ($this.SelectedIndex -lt $this.ScrollOffset) {
        $this.ScrollOffset = $this.SelectedIndex
    } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $viewHeight) {
        $this.ScrollOffset = $this.SelectedIndex - $viewHeight + 1
    }
}
```

### 3. Minimal ANSI Usage
```powershell
# GOOD: Group color changes
$output += [VT]::Selected() + "Item 1" + [VT]::Reset()

# BAD: Excessive color switching
$output += [VT]::Selected() + "I" + [VT]::Reset() + [VT]::Text() + "tem 1"
```

## Common Pitfalls to Avoid

### ❌ What NOT to Do

1. **Mixed Console/String Output**
   ```powershell
   # BAD
   Write-Host "Some content"
   return $output  # This won't work properly
   ```

2. **Inconsistent Navigation**
   ```powershell
   # BAD - Custom key bindings without standards
   $this.BindKey([ConsoleKey]::LeftArrow, { $this.SomeCustomAction() })
   ```

3. **Direct Service Access**
   ```powershell
   # BAD - Direct service instantiation
   $taskService = [TaskService]::new()
   
   # GOOD - Use dependency injection
   $taskService = $global:ServiceContainer.GetService("TaskService")
   ```

4. **Hardcoded Dimensions**
   ```powershell
   # BAD
   for ($i = 0; $i -lt 25; $i++) { }
   
   # GOOD
   $viewHeight = [Console]::WindowHeight - 10
   for ($i = 0; $i -lt $viewHeight; $i++) { }
   ```

5. **Missing Error Handling**
   ```powershell
   # BAD
   $data = $service.GetData()
   
   # GOOD
   try {
       $data = $service.GetData()
   } catch {
       Write-Warning "Failed to load data: $($_.Exception.Message)"
       $data = @()
   }
   ```

### ✅ What TO Do

1. **Use Existing Services**
   ```powershell
   $this.TaskService = $global:ServiceContainer.GetService("TaskService")
   ```

2. **Follow Navigation Standards**
   ```powershell
   [NavigationStandard]::ApplyTo($this, [NavigationMode]::SinglePane)
   ```

3. **Implement Proper Cleanup**
   ```powershell
   [void] Dispose() {
       # Clean up resources
       if ($this.Timer) {
           $this.Timer.Stop()
           $this.Timer.Dispose()
       }
   }
   ```

4. **Handle Edge Cases**
   ```powershell
   [void] MoveDown() {
       if ($this.Items.Count -eq 0) { return }
       if ($this.SelectedIndex -lt $this.Items.Count - 1) {
           $this.SelectedIndex++
           $this.EnsureVisible()
           $this.RequestRender()
       }
   }
   ```

## Service Integration

### Using Existing Services
```powershell
# In constructor
$this.TaskService = $global:ServiceContainer.GetService("TaskService")
$this.ProjectService = $global:ServiceContainer.GetService("ProjectService")

# Loading data
[void] LoadData() {
    try {
        $this.Items = $this.TaskService.GetAllTasks()
        $this.RequestRender()
    } catch {
        Write-Warning "Failed to load tasks: $_"
        $this.Items = @()
    }
}
```

### Creating New Services
```powershell
# Register in ServiceContainer initialization
$global:ServiceContainer.RegisterService("MyService", [MyService]::new())
```

## Error Handling

### Screen-Level Error Handling
```powershell
[void] HandleError([string]$operation, [Exception]$exception) {
    Write-Warning "$operation failed: $($exception.Message)"
    $this.StatusText = "Error: $operation failed"
    $this.RequestRender()
}
```

### Try-Catch Patterns
```powershell
try {
    $result = $this.Service.DoSomething()
    $this.ProcessResult($result)
} catch {
    $this.HandleError("Operation", $_.Exception)
}
```

## Testing Your Screen

### Quick Test Template
```powershell
# Create test script: test-my-screen.ps1
. ".\Core\*.ps1"
. ".\Base\*.ps1" 
. ".\Models\*.ps1"
. ".\Services\*.ps1"
. ".\Screens\MyScreen.ps1"

try {
    $screen = [MyScreen]::new()
    $global:ScreenManager = [ScreenManager]::new()
    $global:ScreenManager.Push($screen)
    $global:ScreenManager.Run()
} catch {
    Write-Error "Test failed: $_"
}
```

### Integration with Main App
1. Add to bolt.ps1 file list
2. Add to MainMenuScreen menu items
3. Test navigation flow

## Summary Checklist

Before submitting your screen:

- [ ] Extends correct base class (Screen, Dialog, etc.)
- [ ] Uses NavigationStandard for key bindings
- [ ] Implements required navigation methods
- [ ] Follows VT color palette
- [ ] Uses string-based rendering
- [ ] Handles empty/error states
- [ ] Respects console dimensions
- [ ] Integrates with existing services
- [ ] Includes proper error handling
- [ ] Tested independently and integrated

This guide ensures consistency, performance, and maintainability across all ALCAR screens.