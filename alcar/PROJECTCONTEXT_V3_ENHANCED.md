# ProjectContextScreenV3 Enhanced - Implementation Guide

## Overview
The Enhanced V3 is a significant upgrade from the basic V3, implementing a full command system with visual feedback, command suggestions, and improved layout capabilities.

## Key Improvements Over V3

### 1. Command System
- **Visual Command Line**: Dedicated command area at bottom with borders
- **Command Suggestions**: Real-time suggestions as you type
- **Command History**: Navigate with ↑↓ arrows
- **Context Awareness**: Commands adapt based on current selection
- **Cursor Support**: Full cursor navigation in command line

### 2. Layout Enhancements
- **Fixed Alignment**: Proper calculation of pane widths
- **Three-Pane Mode**: Toggle between 2 and 3 pane layouts (V key)
- **Dynamic Splits**: Configurable split ratio (default 35/65)
- **Better Borders**: Clean, consistent border drawing

### 3. Command Palette
- **Ctrl+P**: Opens overlay command palette
- **Search**: Filter commands by name, description, or tags
- **Quick Copy**: Select and copy commands to clipboard

## Command System Details

### Command Format
```
/ <verb> [target] [arguments]
```

### Available Commands
- `new project|task|note` - Create new items
- `edit [task|project] [name]` - Edit items
- `delete task [name]` - Delete items
- `open project [name]` - Open specific project
- `goto project|tasks|files|notes` - Navigate to sections
- `filter` - Toggle filters
- `search [query]` - Search (planned)

### Command Features
1. **Tab Completion**: Press Tab to complete suggestions
2. **History**: ↑↓ to navigate command history
3. **Suggestions**: Shows up to 5 relevant suggestions
4. **Visual Feedback**: Highlighted suggestion box
5. **Cursor Movement**: ←→ Home End for navigation

## Implementation Architecture

### State Management
```powershell
# Command state
[string]$CommandLine = ""
[int]$CommandCursorPos = 0
[System.Collections.ArrayList]$CommandHistory
[System.Collections.ArrayList]$CommandSuggestions
[bool]$ShowSuggestions = $false

# View state
[string]$ViewMode = "TwoPane"  # or "ThreePane"
[string]$ViewState = "ProjectSelection"  # or "ProjectWorking"
[double]$SplitRatio = 0.35
```

### Layout Calculation
```powershell
[void] CalculateLayout() {
    $totalWidth = [Console]::WindowWidth
    
    if ($this.ViewMode -eq "TwoPane") {
        $this.LeftWidth = [int]($totalWidth * $this.SplitRatio) - 2
        $this.RightWidth = $totalWidth - $this.LeftWidth - 3
    } else {
        # Three pane - equal split
        $paneWidth = [int]($totalWidth / 3) - 2
        $this.LeftWidth = $paneWidth
        $this.RightWidth = $totalWidth - ($paneWidth * 2) - 4
    }
}
```

### Command Processing
```powershell
[void] ProcessCommand([string]$command) {
    $parts = $command -split ' ', 2
    $verb = $parts[0].ToLower()
    $args = if ($parts.Count -gt 1) { $parts[1] } else { "" }
    
    switch ($verb) {
        "new" { ... }
        "edit" { ... }
        "delete" { ... }
        "open" { ... }
        "goto" { ... }
    }
}
```

## Visual Layout

### Two-Pane Mode (Default)
```
[*Projects*] [Tasks] [Time] [Notes] [Files] [Commands]    Tab/] Next | [ Prev | V View Mode
┌─────────────────────────────────┬────────────────────────────────────────────────────┐
│▶ PROJECTS                       │▶ PROJECT DETAILS                                   │
├─────────────────────────────────┼────────────────────────────────────────────────────┤
│ Filter:                         │ WebPortal Project                                  │
│ ☑ Active                        │ Nickname: WebPortal                                │
│                                 │ ID1: CAA-2024-001                                  │
│ > PMC001                        │ ID2: REQ-5547                                      │
│   ABC123                        │                                                    │
│   XYZ789                        │ Dates:                                             │
│                                 │   Assigned: 2024-01-15                             │
│ [+ New]                         │   BF Date: 2024-01-20                              │
│                                 │   Due Date: 2024-02-28                             │
│                                 │   Days Left: 38 days                               │
│                                 │                                                    │
│                                 │ Progress:                                          │
│                                 │   Hours Used: 127.5 hrs                            │
│                                 │   Progress: ████████░░                             │
└─────────────────────────────────┴────────────────────────────────────────────────────┘
Enter/→ select | N new | E edit | F filter | / command | Ctrl+P palette | V view | Q quit
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ / new task↴                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Three-Pane Mode
```
[*Projects*] [Tasks] [Time] [Notes] [Files] [Commands]    Tab/] Next | [ Prev | V View Mode
┌──────────────────────┬───────────────────────┬─────────────────────────────────────┐
│PROJECTS              │DETAILS                │TOOLS                                │
├──────────────────────┼───────────────────────┼─────────────────────────────────────┤
│ Filter:              │ WebPortal Project     │ Tasks (5):                          │
│ ☑ Active             │ Nickname: WebPortal   │                                     │
│                      │ ID1: CAA-2024-001     │ > ⚡ - Fix login bug                │
│ > PMC001             │ ID2: REQ-5547         │   ○   Add OAuth                    │
│   ABC123             │                       │   ○   Update docs                  │
│   XYZ789             │ Hours: 127.5/200      │   ✓   Setup auth                   │
│                      │ Progress: ████████░░  │   ○   Deploy v2.1                  │
│ [+ New]              │                       │                                     │
│                      │ Days Left: 38         │ 1 completed, 4 remaining            │
└──────────────────────┴───────────────────────┴─────────────────────────────────────┘
```

## Key Navigation Patterns

### Standard Navigation
- **↑↓**: Navigate within focused pane
- **←→**: Switch between panes
- **Tab/]**: Next tab
- **[**: Previous tab
- **Enter**: Select/Activate
- **Esc**: Back/Cancel

### Command Mode
- **/**: Start command mode
- **Enter**: Execute command or select suggestion
- **Tab**: Complete suggestion
- **↑↓**: Navigate history or suggestions
- **←→**: Move cursor
- **Esc**: Cancel command

### Quick Actions
- **N**: New (context-aware)
- **E**: Edit current
- **D**: Delete current
- **F**: Toggle filter or file browser
- **V**: Toggle view mode
- **Q**: Quit

## Future Enhancements

1. **Settings Integration**
   - User-defined split ratios
   - Customizable command shortcuts
   - Color themes

2. **Advanced Commands**
   - Batch operations
   - Command macros
   - External command integration

3. **Search Functionality**
   - Full-text search across projects/tasks
   - Quick filters
   - Search history

4. **Plugin System**
   - Custom command providers
   - External tool integration
   - Custom renderers

## Usage Tips

1. **Command Discovery**: Start typing `/` and see suggestions
2. **Quick Navigation**: Use `goto` commands for fast switching
3. **Context Awareness**: Commands adapt to your current selection
4. **Efficiency**: Learn keyboard shortcuts for common actions
5. **View Modes**: Use three-pane for overview, two-pane for focus

## Technical Notes

- Uses VT100 escape sequences for rendering
- Maintains responsive layout calculations
- Efficient string-based rendering for performance
- Modular design for easy extension
- Command system is extensible via ProcessCommand method