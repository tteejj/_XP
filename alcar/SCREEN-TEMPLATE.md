# Screen Creation Template

## Quick Start

```powershell
# Screens/MyNewScreen.ps1

class MyNewScreen : Screen {
    # Data properties
    [System.Collections.ArrayList]$Items
    [int]$SelectedIndex = 0
    
    # Layout
    [ThreePaneLayout]$Layout  # or create your own
    
    MyNewScreen() {
        $this.Title = "MY NEW SCREEN"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # 1. Setup layout
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        $this.Layout = [ThreePaneLayout]::new($width, $height, 20, 30)
        
        # 2. Load data
        $this.Items = [System.Collections.ArrayList]::new()
        $this.LoadData()
        
        # 3. Setup key bindings
        $this.InitializeKeyBindings()
        
        # 4. Setup status bar
        $this.AddStatusItem('a', 'add')
        $this.AddStatusItem('d', 'delete')
        $this.AddStatusItem('q', 'quit')
    }
    
    [void] InitializeKeyBindings() {
        # Navigation
        $this.BindKey([ConsoleKey]::UpArrow, { $this.MoveUp() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.MoveDown() })
        
        # Actions
        $this.BindKey('a', 'Add')
        $this.BindKey('d', 'Delete')
        $this.BindKey('q', { $this.Active = $false })
    }
    
    [void] ExecuteAction([string]$action) {
        switch ($action) {
            'Add' { $this.AddItem() }
            'Delete' { $this.DeleteItem() }
        }
    }
    
    [string] RenderContent() {
        # Update panes
        $this.UpdateLeftPane()
        $this.UpdateMiddlePane()
        $this.UpdateRightPane()
        
        # Return rendered layout
        return $this.Layout.Render()
    }
    
    # Navigation methods
    [void] MoveUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
        }
    }
    
    [void] MoveDown() {
        if ($this.SelectedIndex -lt $this.Items.Count - 1) {
            $this.SelectedIndex++
        }
    }
    
    # Action methods
    [void] AddItem() {
        # Your add logic
    }
    
    [void] DeleteItem() {
        # Your delete logic
    }
}
```

## Common Patterns

### 1. List Selection
```powershell
for ($i = 0; $i -lt $this.Items.Count; $i++) {
    $item = $this.Items[$i]
    $line = ""
    
    if ($i -eq $this.SelectedIndex) {
        $line += [VT]::Selected()
    }
    
    $line += " $($item.Name)"
    $line += [VT]::Reset()
    
    $this.Layout.MiddlePane.Content.Add($line) | Out-Null
}
```

### 2. Input Dialog
```powershell
class InputDialog : Dialog {
    [string]$Prompt
    [string]$Value = ""
    [bool]$Confirmed = $false
    
    InputDialog([Screen]$parent, [string]$prompt) : base($parent) {
        $this.Title = "INPUT"
        $this.Prompt = $prompt
        $this.Height = 7
        
        $this.BindKey([ConsoleKey]::Enter, { 
            $this.Confirmed = $true
            $this.Active = $false 
        })
        $this.BindKey([ConsoleKey]::Escape, { 
            $this.Active = $false 
        })
    }
}
```

### 3. Menu Navigation
```powershell
[bool]$MenuMode = $false
[int]$MenuIndex = 0

# Toggle menu with Ctrl
if ($key.Modifiers -eq [ConsoleModifiers]::Control) {
    $this.MenuMode = -not $this.MenuMode
}
```

### 4. Tree View
```powershell
# Display with indentation
$indent = "  " * $item.Level
if ($item.HasChildren) {
    $indent += if ($item.IsExpanded) { "▼ " } else { "▶ " }
} else {
    $indent += "• "
}
```

## Best Practices

1. **Separation of Concerns**
   - Data loading in separate methods
   - Rendering logic separate from business logic
   - Input handling through bindings

2. **Consistent Navigation**
   - Arrow keys for movement
   - Tab for pane switching
   - Enter for selection
   - Escape for cancel/back

3. **Visual Feedback**
   - Selected items highlighted
   - Edit mode with yellow background
   - Confirmations with red dialogs

4. **Status Bar**
   - Show available actions
   - Context-sensitive help
   - Mode indicators

## Testing Your Screen

```powershell
# test-myscreen.ps1
. ./bolt.ps1 -Debug

# Create and run your screen
$screen = [MyNewScreen]::new()

while ($screen.Active) {
    $screen.Render()
    
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        $screen.HandleInput($key)
    }
}
```