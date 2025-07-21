# Arrow Key Navigation Analysis - ALCAR

## Current Arrow Key Behaviors by Screen

### 1. DashboardScreen
- **Up Arrow**: No binding
- **Down Arrow**: No binding  
- **Left Arrow**: No binding
- **Right Arrow**: No binding
- **Navigation Type**: None (static dashboard)
- **Notes**: Dashboard is view-only with no navigation

### 2. TaskScreen (Three-pane layout)
- **Up Arrow**: Navigate up within current pane
- **Down Arrow**: Navigate down within current pane
- **Left Arrow**: 
  - If in middle pane (tasks) → Focus left pane (filters)
  - If in left pane (filters) → Go back to main menu
- **Right Arrow**: 
  - If in left pane (filters) → Focus middle pane (tasks)
- **Navigation Type**: Pane-based with item navigation within panes
- **Tab**: Switch between panes (cycles through)
- **Enter**: Apply filter or expand/collapse task

### 3. ProjectsScreen (Three-pane layout)
- **Up Arrow**: Navigate up project list
- **Down Arrow**: Navigate down project list
- **Left Arrow**: 
  - If in left pane → Go back to main menu
- **Right Arrow**: 
  - If in left pane → Open selected project
- **Navigation Type**: Item navigation with special right arrow action
- **Enter**: Open project

### 4. SettingsScreen (Two-pane layout)
- **Up Arrow**: Navigate up in current pane
- **Down Arrow**: Navigate down in current pane
- **Left Arrow**: 
  - If in settings pane → Change choice value (for choice fields)
  - Also switches to categories pane
- **Right Arrow**: 
  - If in settings pane → Change choice value (for choice fields)
  - If in categories pane → Switch to settings pane
- **Navigation Type**: Mixed - pane switching AND value modification
- **Tab**: Switch between panes

### 5. FileBrowserScreen (Three-column ranger-style)
- **Up Arrow**: Navigate up in focused panel
- **Down Arrow**: Navigate down in focused panel
- **Left Arrow**: 
  - If panel > 0 → Focus previous panel
  - If panel = 0 → Navigate up one directory
- **Right Arrow**: 
  - If panel < 2 → Focus next panel
  - If panel = 2 → Enter selected directory
- **Navigation Type**: Panel-based with directory navigation
- **Enter**: Open selected item

### 6. TextEditorScreen
- **Up Arrow**: Move cursor up
- **Down Arrow**: Move cursor down
- **Left Arrow**: Move cursor left
- **Right Arrow**: Move cursor right
- **Navigation Type**: Text cursor movement
- **Notes**: Standard text editor cursor behavior

### 7. MainMenuScreen (Category + items)
- **Up Arrow**: Move selection up
- **Down Arrow**: Move selection down
- **Left Arrow**: Move to previous category
- **Right Arrow**: Move to next category
- **Navigation Type**: Category and item navigation
- **Enter**: Select item

### 8. EditDialog
- **Up Arrow**: Navigate fields (when not editing)
- **Down Arrow**: Navigate fields (when not editing)
- **Left Arrow**: 
  - For choice fields → Change value left
  - For other fields → Cancel dialog
- **Right Arrow**: Change choice value right
- **Navigation Type**: Field navigation with value modification

## Key Inconsistencies Found

### 1. Left Arrow Behavior Variance
- **Back/Exit**: TaskScreen (from left pane), ProjectsScreen, EditDialog (non-choice fields)
- **Panel Switch**: SettingsScreen, FileBrowserScreen
- **Value Change**: SettingsScreen (choice fields), EditDialog (choice fields)
- **Category Navigation**: MainMenuScreen
- **Cursor Movement**: TextEditorScreen

### 2. Right Arrow Behavior Variance
- **Enter/Open**: ProjectsScreen, FileBrowserScreen (when at rightmost panel)
- **Panel Switch**: TaskScreen, SettingsScreen, FileBrowserScreen
- **Value Change**: SettingsScreen (choice fields), EditDialog (choice fields)
- **Category Navigation**: MainMenuScreen
- **Cursor Movement**: TextEditorScreen

### 3. Navigation Paradigm Conflicts
- Some screens use Tab for pane switching (TaskScreen, SettingsScreen)
- Others use Left/Right arrows for panel focus (FileBrowserScreen)
- MainMenuScreen uses Left/Right for categories, not panes

## Recommendations for Standardization

### 1. Establish Clear Navigation Modes

#### A. Multi-Pane Navigation Mode (for screens with panels/panes)
- **Up/Down**: Always navigate items within current pane
- **Tab**: Primary method for switching between panes (forward)
- **Shift+Tab**: Switch panes backward
- **Left Arrow**: Secondary option - go back/exit when in leftmost pane
- **Right Arrow**: Secondary option - activate/enter when appropriate
- **Enter**: Primary action on selected item

#### B. Single List Navigation Mode
- **Up/Down**: Navigate items
- **Left**: Go back/cancel
- **Right**: Enter/activate (if applicable)
- **Enter**: Primary action

#### C. Value Editing Mode (for forms/settings)
- **Up/Down**: Navigate between fields
- **Left/Right**: Modify values (for appropriate field types)
- **Enter**: Edit field or confirm
- **Tab**: Next field
- **Shift+Tab**: Previous field

#### D. Text Editing Mode
- **All arrows**: Cursor movement (current behavior is correct)

### 2. Specific Screen Recommendations

#### TaskScreen
- Keep current behavior (already follows multi-pane pattern well)
- Consider making Left arrow from left pane consistent with Escape

#### ProjectsScreen
- Change Right arrow to focus middle pane instead of opening project
- Use Enter consistently for opening/activating

#### SettingsScreen
- Separate value changing from navigation
- Use dedicated keys (Space, +/-) for value changes
- Keep Left/Right for pane navigation only

#### FileBrowserScreen
- Consider using Tab for panel switching to match other screens
- Keep Left arrow for directory navigation up
- Make Right arrow consistently enter directories

#### MainMenuScreen
- Consider treating categories as a left pane
- Use Tab to toggle between category list and items
- Or keep current unique behavior but document it clearly

### 3. Universal Key Bindings

Establish these across all screens:
- **Escape**: Always go back/cancel
- **Tab**: Primary pane/field navigation (forward)
- **Shift+Tab**: Primary pane/field navigation (backward)
- **Enter**: Primary action/confirm
- **Space**: Toggle/change value (where applicable)
- **F1**: Help (show navigation hints)

### 4. Implementation Priority

1. **High Priority**: Fix conflicting Left/Right behaviors in SettingsScreen
2. **Medium Priority**: Standardize pane switching to use Tab consistently
3. **Low Priority**: Add visual indicators for navigation mode (e.g., "PANE MODE" in status bar)

### 5. User Documentation

Create a help screen that explains:
- Navigation modes and when they apply
- Key bindings for each mode
- Visual cues that indicate current mode

This standardization will improve user experience by making navigation predictable across all screens while still allowing for screen-specific functionality where needed.