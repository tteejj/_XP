# BETTER LAYOUT APPROACH FOR AXIOM-PHOENIX

Instead of manual positioning, use Panel's built-in layout system:

## EXAMPLE: NewTaskScreen with Automatic Layout

```powershell
class NewTaskScreen : Screen {
    [void] Initialize() {
        # Main form panel with VERTICAL layout
        $this._formPanel = [Panel]::new("NewTaskForm")
        $this._formPanel.X = 0
        $this._formPanel.Y = 0
        $this._formPanel.Width = $this.Width
        $this._formPanel.Height = $this.Height
        $this._formPanel.Title = " New Task "
        $this._formPanel.BorderStyle = "Double"
        
        # USE AUTOMATIC VERTICAL LAYOUT!
        $this._formPanel.LayoutType = "Vertical"
        $this._formPanel.Padding = 5      # Space from borders
        $this._formPanel.Spacing = 3      # Space between children
        
        $this.AddChild($this._formPanel)
        
        # Now just add components - they auto-position!
        
        # Title Section Container
        $titleSection = [Panel]::new("TitleSection")
        $titleSection.Height = 5
        $titleSection.Width = 100
        $titleSection.HasBorder = $false
        $titleSection.LayoutType = "Vertical"
        $titleSection.Spacing = 1
        $this._formPanel.AddChild($titleSection)
        
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Task Title:"
        $titleSection.AddChild($titleLabel)  # Auto-positioned!
        
        $this._titleBox = [TextBoxComponent]::new("TitleInput")
        $this._titleBox.Width = 80
        $this._titleBox.Height = 3
        $titleSection.AddChild($this._titleBox)  # Auto-positioned below label!
        
        # Description Section Container
        $descSection = [Panel]::new("DescSection")
        $descSection.Height = 5
        $descSection.Width = 100
        $descSection.HasBorder = $false
        $descSection.LayoutType = "Vertical"
        $descSection.Spacing = 1
        $this._formPanel.AddChild($descSection)  # Auto-positioned below title section!
        
        # And so on...
    }
}
```

## BENEFITS:
1. **No manual Y calculations** - Components auto-stack
2. **Consistent spacing** - Set once with `Spacing` property
3. **Responsive** - Adjusts if parent size changes
4. **Cleaner code** - Focus on structure, not coordinates
5. **No overlap bugs** - Layout manager handles it

## LAYOUT OPTIONS:

### Vertical Layout
```powershell
$panel.LayoutType = "Vertical"
$panel.Spacing = 2  # Gap between children
```

### Horizontal Layout
```powershell
$panel.LayoutType = "Horizontal"  
$panel.Spacing = 4  # Gap between children
```

### Grid Layout
```powershell
$panel.LayoutType = "Grid"
$panel.GridColumns = 2
$panel.Spacing = 3
```

This approach would eliminate most of the positioning bugs!
