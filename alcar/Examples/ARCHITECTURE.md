# BOLT-AXIOM Architecture

## Current State Assessment

### What We Have
1. **Core Layer**
   - `vt100.ps1`: Direct VT100/ANSI rendering (no buffering)
   - `layout2.ps1`: Three-pane layout engine
   - `dateparser.ps1`: Smart date parsing

2. **Models**
   - `task.ps1`: Task data model with tree support

3. **Screens**
   - `taskscreen2.ps1`: Main task management screen
   - `editscreen.ps1`: Detail edit screen

### Strengths
- Fast direct rendering without buffering
- Clean separation of concerns (Core/Models/Screens)
- Consistent use of PowerShell classes
- Tree view implementation works well

### Weaknesses
- No base screen class - code duplication
- Inconsistent input handling patterns
- Mixed responsibilities in taskscreen2.ps1
- No clear navigation/routing system

## Proposed Architecture

### 1. Base Classes
```powershell
# Base/Screen.ps1
class Screen {
    [bool]$Active = $true
    [string]$Title
    
    # Template methods
    [void] Render() { }
    [void] HandleInput([ConsoleKeyInfo]$key) { }
    [void] OnActivate() { }
    [void] OnDeactivate() { }
}

# Base/Dialog.ps1  
class Dialog : Screen {
    [Screen]$ParentScreen
    [bool]$Modal = $true
}
```

### 2. Screen Manager
```powershell
# Core/ScreenManager.ps1
class ScreenManager {
    [Stack[Screen]]$ScreenStack
    [Screen]$CurrentScreen
    
    [void] Push([Screen]$screen) { }
    [void] Pop() { }
    [void] Replace([Screen]$screen) { }
}
```

### 3. Consistent Patterns
- All screens inherit from base Screen class
- Dialogs (delete confirm, edit) are proper Dialog subclasses
- Input handling follows consistent pattern
- Navigation through ScreenManager

## Screen Creation Guide

### 1. Create Your Screen Class
```powershell
class MyScreen : Screen {
    # Properties
    [Layout]$Layout
    [System.Collections.ArrayList]$Items
    [int]$SelectedIndex = 0
    
    # Constructor
    MyScreen() {
        $this.Title = "MY SCREEN"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Setup layout, load data, etc.
    }
}
```

### 2. Implement Render
```powershell
[void] Render() {
    # Clear screen
    $output = [VT]::Clear()
    
    # Draw your UI
    $output += $this.Layout.Render()
    
    # Status bar
    $output += $this.DrawStatusBar()
    
    [Console]::Write($output)
}
```

### 3. Handle Input
```powershell
[void] HandleInput([ConsoleKeyInfo]$key) {
    switch ($key.Key) {
        ([ConsoleKey]::UpArrow) {
            # Navigation
        }
        ([ConsoleKey]::Enter) {
            # Selection
        }
        ([ConsoleKey]::Escape) {
            # Back/Cancel
        }
    }
    
    # Character keys
    switch ($key.KeyChar) {
        'q' { $this.Active = $false }
    }
}
```

### 4. Add to Screen Flow
```powershell
# In your screen manager or main loop
$nextScreen = [MyScreen]::new()
$screenManager.Push($nextScreen)
```

## Next Steps

1. **Refactor to Base Classes**
   - Extract common screen functionality
   - Create proper Dialog base class
   - Implement ScreenManager

2. **Build Next Screens**
   - Projects Screen (list/manage projects)
   - Settings Screen (themes, preferences)
   - Dashboard (overview, stats)

3. **Improve Consistency**
   - Standardize key bindings
   - Consistent status bar format
   - Unified color scheme through themes

## Is This Cohesive?

Currently: **Partially cohesive** - good separation but lacks consistent patterns
Goal: **Fully cohesive** - base classes, clear patterns, easy extension

The foundation is solid (VT100 renderer, layout engine) but needs architectural improvements for maintainability and extension.