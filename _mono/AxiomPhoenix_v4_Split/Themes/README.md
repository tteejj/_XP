# Axiom-Phoenix v4.0 - Theme System

This folder contains external theme files that showcase the new **palette-based theme architecture**.

## What's New

The new theme system uses a **hierarchical palette approach** with two main sections:

### 1. **Palette** - Base Color Definitions
Define your color palette once, give colors semantic names:
```powershell
Palette = @{
    # Base colors
    Black = "#0d0208"           # Deep black with hint of red
    White = "#e8f4f8"           # Cool white with blue tint
    Primary = "#ff006e"         # Hot magenta/pink - main accent
    Secondary = "#3a0ca3"       # Deep electric purple
    Accent = "#00d4ff"          # Electric cyan - secondary accent
    
    # Semantic colors
    Background = "#0d0208"      # Deep dark base
    Surface = "#1a0e1a"         # Dark purple surface
    Border = "#ff006e"          # Hot pink borders
    TextPrimary = "#e8f4f8"     # Cool white text
    TextSecondary = "#b388ff"   # Purple secondary text
}
```

### 2. **Components** - UI Element Mapping
Map UI components to palette colors using references:
```powershell
Components = @{
    Panel = @{
        Background = '$Palette.Background'    # References palette color
        Border = '$Palette.NeonPink'
        Title = '$Palette.NeonBlue'
    }
    
    Button = @{
        Normal = @{
            Foreground = '$Palette.Black'
            Background = '$Palette.NeonBlue'
        }
        Focused = @{
            Foreground = '$Palette.Black'
            Background = '$Palette.NeonPink'
        }
    }
}
```

## Benefits

1. **Consistency** - Change a palette color and it updates everywhere
2. **Semantic Naming** - Colors have meaningful names like "NeonBlue" instead of "#00d4ff"
3. **Easy Customization** - Tweak the palette without touching component mappings
4. **Theme Variants** - Create light/dark variants by just changing the palette

## Available Themes

- **Cyberpunk.ps1** - Neon-soaked cyberpunk aesthetic with electric blues and hot pinks
- **RetroAmber.ps1** - Classic amber terminal aesthetic with warm golden tones  
- **ModernDark.ps1** - Professional dark theme with subtle blues and grays
- **HighContrast.ps1** - Maximum contrast theme for accessibility and visibility

## Creating Your Own Theme

1. Copy an existing theme file as a template
2. Update the `Name` and `Description` at the top
3. Customize the `Palette` section with your colors
4. Optionally adjust `Components` mappings
5. Save as `YourThemeName.ps1` in this folder
6. Restart the application to load your theme

## Theme Structure

```powershell
@{
    Name = "Your Theme Name"
    Description = "Description of your theme"
    Version = "1.0"
    Author = "Your Name"
    
    Palette = @{
        # Define your color palette here
    }
    
    Components = @{
        Screen = @{ Background = '$Palette.Background'; Foreground = '$Palette.TextPrimary' }
        Panel = @{ Background = '$Palette.Background'; Border = '$Palette.Border'; Title = '$Palette.Accent' }
        Label = @{ Foreground = '$Palette.TextPrimary'; Disabled = '$Palette.TextDisabled' }
        Button = @{ /* ... */ }
        Input = @{ /* ... */ }
        List = @{ /* ... */ }
        Status = @{ /* ... */ }
        Overlay = @{ /* ... */ }
    }
}
```

## Backward Compatibility

The ThemeManager maintains full backward compatibility with old theme key names:
- `component.border` → `Panel.Border`
- `primary.accent` → `Panel.Title`  
- `list.item.selected` → `List.ItemSelected`
- And many more...

## Advanced Features

- **Palette References** - Use `$Palette.ColorName` to reference palette colors
- **Extended Palettes** - Add custom color names beyond the standard set
- **Component Inheritance** - Components can reference other component colors
- **Theme Metadata** - Include version, author, and description information

The new system is more powerful, maintainable, and showcases modern theming best practices!
