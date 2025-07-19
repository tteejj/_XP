# Alcar Upgrades: Features from AxiomPhoenix

## Report: AxiomPhoenix Features Suitable for Alcar

### ✅ **Highly Suitable for Direct Adaptation**

1. **FileBrowserScreen → Ranger-Style File Manager**
   - Already has 2-panel layout with ranger-style navigation
   - Just needs a third preview panel
   - Has file operations, icons, and keyboard navigation
   - Clean implementation that would fit alcar's style

2. **TimesheetScreen → Calendar View**
   - Weekly calendar layout already exists
   - Could be adapted to show task due dates
   - Navigation between weeks implemented
   - Export functionality included

3. **DateInputComponent → Date Picker**
   - Full calendar popup already implemented
   - Keyboard navigation works well
   - Could be used for task due dates
   - Clean, focused component

4. **CommandPaletteScreen → Quick Actions**
   - Search/filter functionality
   - Could store alcar shortcuts/macros
   - Already has execute/manage features

### 🔄 **Needs Significant Modification**

1. **Pomodoro Timer** (Not implemented, but could use):
   - TimeSheetService's time tracking as base
   - Would need countdown display
   - Work/break interval management
   - Notification system

2. **DataGridComponent → Enhanced Task List**
   - More feature-rich than current task list
   - Supports custom view definitions
   - Better for large datasets

### 🏗️ **New Features to Build**

1. **Pomodoro Timer Component**
   ```
   ┌─────────────────┐
   │ 🍅 Pomodoro     │
   │ ─────────────── │
   │   25:00         │
   │ [▶️ Start] [⏸️]  │
   │ Work: ████░░░░  │
   └─────────────────┘
   ```

2. **Dashboard Widgets**
   - Calendar widget showing upcoming tasks
   - Time tracking summary
   - Project progress bars

3. **Ranger-Style File Browser**
   - Three-panel Miller columns
   - File preview
   - Bookmarks/shortcuts

### 💡 **Architecture Patterns to Adopt**

1. **ViewDefinitionService Pattern**
   - Flexible data display configuration
   - Reusable across different screens

2. **Component Focus Management**
   - TabIndex system
   - Automatic Tab navigation

3. **Event-Driven Updates**
   - Components subscribe to changes
   - Real-time UI updates

4. **Service Layer Architecture**
   - Separate business logic from UI
   - Easier testing and maintenance

### 📋 **Implementation Priority**

1. **High Priority**:
   - Ranger-style file browser (high user value, relatively straightforward)
   - Calendar view for tasks (integrates with existing task system)
   - Date picker for task creation

2. **Medium Priority**:
   - Pomodoro timer (new feature, moderate complexity)
   - Command palette (power user feature)
   - Enhanced data grid for task list

3. **Low Priority**:
   - Time tracking (complex, may not fit alcar's scope)
   - Project dashboard (depends on project management features)

## Available Screens in AxiomPhoenix

### Core Screens
1. **DashboardScreen** (ASC.001) - Main menu/home screen
2. **TaskListScreen** (ASC.002) - Task management with DataGrid
3. **ThemeScreen** (ASC.003) - Theme selection with preview
4. **NewTaskScreen** (ASC.004) - Task creation form
5. **EditTaskScreen** (ASC.005) - Task editing form
6. **ProjectsListScreen** (ASC.008) - Project management
7. **FileBrowserScreen** (ASC.010) - File system navigation
8. **TextEditScreen** (ASC.011) - Text editor
9. **TimesheetScreen** (ASC.012) - Time tracking calendar
10. **CommandPaletteScreen** (ASC.014) - Command storage/execution
11. **ProjectDashboardScreen** (ASC.015) - Project-specific view

### Key Components to Consider

1. **DataGridComponent** (ACO.022)
   - Generic data grid with scrolling
   - ViewDefinition support
   - Built-in caching
   - Theme-aware styling

2. **ListBox** (ACO.014)
   - Scrollable list with keyboard navigation
   - Selection highlighting
   - Focus management

3. **DateInputComponent** (ACO.008)
   - Calendar popup interface
   - Keyboard navigation
   - Min/Max date constraints

4. **Dialog Components**
   - AlertDialog (ACO.018)
   - InputDialog (ACO.020)
   - ConfirmDialog (ACO.026)

### Key Services to Consider

1. **ViewDefinitionService** (ASE.011)
   - Centralized data presentation
   - Column configuration
   - Dynamic styling

2. **EventManager** (ASE.002)
   - Pub/sub event system
   - Data update notifications

3. **NavigationService** (ASE.008)
   - Screen navigation with history
   - Back navigation support

4. **ActionService** (ASE.004)
   - Command pattern implementation
   - Centralized action handling

## Technical Notes

The AxiomPhoenix codebase demonstrates:
- Well-structured component model
- Service layer with dependency injection
- Event-driven architecture
- Comprehensive keyboard navigation
- Theme system integration
- Focus management patterns

Many components could be adapted with minimal modification to fit alcar's cleaner, more focused design philosophy.