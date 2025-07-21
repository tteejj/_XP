# BOLT-AXIOM Features

## Current Implementation

### Edit Mode
- **Quick Edit (e)**: Inline editing of task titles with visual feedback
  - Yellow background highlights the editing task
  - Cursor shows current position
  - Enter to save, Esc to cancel
  
### Detailed Edit (E)
- **Edit Details Screen**: Full-featured task editor
  - Edit all fields: Title, Description, Status, Priority, Progress, Due Date
  - Navigate fields with arrow keys
  - Enter to edit a field
  - F2 to save all changes
  - Esc to cancel

### Tree View
- **Hierarchical Display**: Shows parent-child relationships
  - ▼/▶ indicators for expandable tasks
  - • for leaf tasks (no children)
  - Indentation shows nesting level
  - Enter on parent task to expand/collapse
  - 'x' key to expand/collapse all

### Task Operations
- **Add (a)**: Create new root task
- **Add Subtask (s)**: Create subtask under selected task
- **Delete (d)**: Remove selected task
- **Toggle Status (space)**: Cycle through Pending → InProgress → Completed
- **Priority (p)**: Cycle through Low → Medium → High

### Navigation
- **Tab**: Switch between Filter and Task panes
- **Arrow keys**: Navigate within panes
- **Ctrl + any key**: Toggle menu mode
- **Menu mode arrows**: Navigate menu items

## How to Use

### Creating Tasks
1. Press 'a' to add a new root task
2. Type the task title and press Enter
3. Select a task and press 's' to add a subtask

### Editing Tasks
- **Quick edit**: Press 'e' to edit just the title inline
- **Full edit**: Press 'E' (shift+e) to open the detailed edit screen

### Managing Subtasks
1. Tasks with children show ▼ (expanded) or ▶ (collapsed)
2. Press Enter on a parent to toggle expansion
3. Press 'x' to expand/collapse all tasks at once
4. Press 's' on any task to add a subtask under it

### Setting Task Details
1. Select a task and press 'E' for the edit details screen
2. Use arrow keys to navigate between fields
3. Press Enter on a field to edit it
4. For Status/Priority, use left/right arrows to change values
5. Press F2 to save all changes

## Visual Indicators
- **Yellow background**: Task being edited
- **Selected task**: Highlighted in current pane
- **Overdue tasks**: Shown in red
- **Task status symbols**: ○ Pending, ◐ InProgress, ● Completed
- **Priority symbols**: ↓ Low, → Medium, ↑ High

## Tips
- The right pane always shows details of the selected task
- Filter counts update automatically as you modify tasks
- Tree view maintains your expansion state as you work
- All changes are immediate (no separate save needed)