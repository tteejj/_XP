# Key Handling Analysis for TaskScreen

## Issues Identified

### 1. Uppercase 'E' Not Working Properly

**Problem**: When pressing Shift+E (uppercase 'E'), it's falling through to the 'edit' action instead of 'EditDetails'.

**Root Cause**: In the HandleInput method (lines 668-677), the code iterates through MenuItems and uses case-sensitive comparison:
```powershell
foreach ($item in $this.MenuItems) {
    # Case-sensitive comparison for menu items
    if ($key.KeyChar -eq $item.Key) {
        $this.ExecuteMenuAction($item.Action)
        return
    }
}
```

However, the menu items are defined as:
- `@{Key='e'; Label='edit'; Action='Edit'}`
- `@{Key='E'; Label='details'; Action='EditDetails'}`

When iterating through the array, 'e' comes before 'E', so when uppercase 'E' is pressed, it matches lowercase 'e' first because PowerShell's `-eq` operator is case-insensitive by default!

**Solution**: Use the `-ceq` operator for case-sensitive comparison:
```powershell
if ($key.KeyChar -ceq $item.Key) {
    $this.ExecuteMenuAction($item.Action)
    return
}
```

### 2. 'a' Key Does Inline Add Instead of Going to New Screen

**Current Behavior**: The 'a' key triggers the AddTask method (line 724), which creates a new task and enters inline edit mode (lines 760-781).

**Expected Behavior**: Should potentially open a new screen for adding tasks (like EditScreen).

**Solution**: Modify the AddTask method to use EditScreen:
```powershell
[void] AddTask() {
    # Create new task and open edit screen
    $newTask = [Task]::new("New Task")
    $this.Tasks.Add($newTask) | Out-Null
    $this.EditScreen = [EditScreen]::new($newTask, $true)
}
```

### 3. 'd' Key Not Showing Delete Confirmation Dialog

**Current Implementation**: The Delete action (lines 732-736) sets flags but the dialog might not be rendering properly:
```powershell
'Delete' {
    if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
        $this.ConfirmDelete = $true
        $this.TaskToDelete = $this.FilteredTasks[$this.TaskIndex]
    }
}
```

The RenderDeleteConfirmation method exists (lines 817-869) and should be called from the main Render method (lines 425-429).

**Possible Issue**: The delete confirmation is properly implemented. The issue might be that:
1. The user needs to be on the task pane (FocusedPane -eq 1)
2. There need to be tasks in the filtered list

## Verification Steps

1. For uppercase 'E': The comparison needs to be case-sensitive
2. For 'a': The behavior is as designed (inline edit), but could be changed to use EditScreen
3. For 'd': The logic appears correct, but needs testing with proper focus

## Recommended Fixes

### Fix 1: Case-Sensitive Key Comparison
Change line 672 from:
```powershell
if ($key.KeyChar -eq $item.Key) {
```
To:
```powershell
if ($key.KeyChar -ceq $item.Key) {
```

### Fix 2: Use EditScreen for Add (Optional)
Replace AddTask method to use EditScreen instead of inline editing.

### Fix 3: Verify Delete Dialog
The delete confirmation appears to be properly implemented. Need to ensure:
- User is focused on task pane (use Tab to switch)
- There are tasks in the current filter
- The 'd' key is pressed when these conditions are met