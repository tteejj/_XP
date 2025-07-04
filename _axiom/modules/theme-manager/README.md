# theme-manager Module

## Overview
The `theme-manager` module provides comprehensive theming and color management for the PMC Terminal TUI system. It supports both traditional ConsoleColor themes and modern 24-bit truecolor themes with hot-swapping capabilities and persistent theme storage.

## Features
- **Multiple Theme Support** - Light, Dark, Modern, Retro, and custom themes
- **Truecolor Support** - 24-bit RGB color support alongside traditional ConsoleColors
- **Hot Theme Swapping** - Change themes instantly without application restart
- **Theme Persistence** - Import/export themes as JSON files
- **Event Integration** - Publishes theme change events for UI updates
- **Semantic Colors** - Named color roles (Primary, Accent, Error, etc.)
- **Validation** - Input validation and error handling for robust operation

## Color System

### Semantic Color Names
The theme system uses semantic color names that describe the purpose of the color:

- **`Background`** - Main background color
- **`Foreground`** - Main text color
- **`Primary`** - Primary UI elements
- **`Secondary`** - Secondary UI elements
- **`Accent`** - Highlight and focus colors
- **`Success`** - Success states and messages
- **`Warning`** - Warning states and messages
- **`Error`** - Error states and messages
- **`Info`** - Informational messages
- **`Header`** - Headers and titles
- **`Border`** - Borders and separators
- **`Selection`** - Selected items
- **`Highlight`** - Highlighted content
- **`Subtle`** - Subtle/muted content
- **`Keyword`** - Syntax highlighting keywords
- **`String`** - Syntax highlighting strings
- **`Number`** - Syntax highlighting numbers
- **`Comment`** - Syntax highlighting comments

### Color Formats
The theme system supports multiple color formats:

#### ConsoleColor (Legacy)
```powershell
@{
    Background = [ConsoleColor]::Black
    Foreground = [ConsoleColor]::White
    Accent = [ConsoleColor]::Cyan
}
```

#### Hex Colors (Truecolor)
```powershell
@{
    Background = "#000000"
    Foreground = "#FFFFFF"
    Accent = "#00FFFF"
}
```

## Functions

### Initialize-ThemeManager
Initializes the theme manager and sets the default theme.

```powershell
Initialize-ThemeManager
```

**Process:**
1. Loads predefined themes
2. Sets "Modern" as the default active theme
3. Applies theme to console colors
4. Publishes initialization event

### Set-TuiTheme
Sets the active theme for the TUI system.

```powershell
# Set predefined theme
Set-TuiTheme -ThemeName "Dark"

# With confirmation prompts
Set-TuiTheme -ThemeName "Light" -WhatIf
Set-TuiTheme -ThemeName "Retro" -Confirm
```

**Parameters:**
- `ThemeName` (Required) - Name of the theme to activate

**Process:**
1. Validates theme exists
2. Updates current theme
3. Applies console colors immediately
4. Publishes `Theme.Changed` event

### Get-ThemeColor
Retrieves a specific color from the current theme.

```powershell
# Get specific colors
$accentColor = Get-ThemeColor -ColorName "Accent"
$backgroundColor = Get-ThemeColor -ColorName "Background"

# With fallback
$borderColor = Get-ThemeColor -ColorName "Border" -Default ([ConsoleColor]::Gray)
```

**Parameters:**
- `ColorName` (Required) - Name of the color to retrieve
- `Default` (Optional) - Fallback color if not found (default: Gray)

**Returns:** ConsoleColor enum or hex string depending on theme type

### Get-TuiTheme
Gets the currently active theme configuration.

```powershell
$currentTheme = Get-TuiTheme
Write-Host "Current theme: $($currentTheme.Name)"
```

**Returns:** Hashtable with theme name and colors

### Get-AvailableThemes
Gets a list of all available theme names.

```powershell
$themes = Get-AvailableThemes
$themes | ForEach-Object { Write-Host "Available: $_" }
```

**Returns:** Array of theme names sorted alphabetically

### New-TuiTheme
Creates a new custom theme, optionally based on an existing theme.

```powershell
# Create new theme from scratch
New-TuiTheme -Name "MyTheme" -Colors @{
    Background = "#1E1E1E"
    Foreground = "#D4D4D4"
    Accent = "#007ACC"
}

# Base on existing theme
New-TuiTheme -Name "DarkBlue" -BaseTheme "Dark" -Colors @{
    Accent = "#0078D4"
    Primary = "#106EBE"
} -Force
```

**Parameters:**
- `Name` (Required) - Unique name for the new theme
- `BaseTheme` (Optional) - Existing theme to use as base (default: "Modern")
- `Colors` (Optional) - Custom colors to override
- `Force` (Switch) - Overwrite existing theme with same name

### Export-TuiTheme
Exports a theme definition to a JSON file.

```powershell
# Export specific theme
Export-TuiTheme -ThemeName "MyTheme" -Path "C:\Themes\MyTheme.json"

# With confirmation
Export-TuiTheme -ThemeName "Dark" -Path ".\dark-theme.json" -WhatIf
```

**Parameters:**
- `ThemeName` (Required) - Name of theme to export
- `Path` (Required) - File path for JSON export

### Import-TuiTheme
Imports a theme definition from a JSON file.

```powershell
# Import new theme
Import-TuiTheme -Path "C:\Themes\CustomTheme.json"

# Overwrite existing
Import-TuiTheme -Path ".\updated-theme.json" -Force
```

**Parameters:**
- `Path` (Required) - Path to JSON theme file
- `Force` (Switch) - Overwrite existing theme with same name

## Predefined Themes

### Modern Theme (Default)
A clean, modern theme with high contrast:
```powershell
@{
    Background = [ConsoleColor]::Black
    Foreground = [ConsoleColor]::White
    Primary = [ConsoleColor]::White
    Secondary = [ConsoleColor]::Gray
    Accent = [ConsoleColor]::Cyan
    Success = [ConsoleColor]::Green
    Warning = [ConsoleColor]::Yellow
    Error = [ConsoleColor]::Red
    Info = [ConsoleColor]::Blue
}
```

### Dark Theme
A softer dark theme:
```powershell
@{
    Background = [ConsoleColor]::Black
    Foreground = [ConsoleColor]::Gray
    Accent = [ConsoleColor]::DarkCyan
    # ... more colors
}
```

### Light Theme
Light background theme:
```powershell
@{
    Background = [ConsoleColor]::White
    Foreground = [ConsoleColor]::Black
    Accent = [ConsoleColor]::Blue
    # ... more colors
}
```

### Retro Theme
Classic green-on-black terminal:
```powershell
@{
    Background = [ConsoleColor]::Black
    Foreground = [ConsoleColor]::Green
    Accent = [ConsoleColor]::Yellow
    # ... more colors
}
```

## Usage Examples

### Basic Theme Management
```powershell
# Initialize theme system
Initialize-ThemeManager

# Check current theme
$current = Get-TuiTheme
Write-Host "Current: $($current.Name)"

# List available themes
Get-AvailableThemes | ForEach-Object { Write-Host "- $_" }

# Switch theme
Set-TuiTheme -ThemeName "Dark"
```

### Custom Theme Creation
```powershell
# Create VS Code inspired theme
New-TuiTheme -Name "VSCode" -BaseTheme "Dark" -Colors @{
    Background = "#1E1E1E"
    Foreground = "#D4D4D4"
    Accent = "#007ACC"
    Success = "#4EC9B0"
    Warning = "#FFCC02"
    Error = "#F14C4C"
    Keyword = "#569CD6"
    String = "#CE9178"
    Comment = "#6A9955"
}

# Apply the new theme
Set-TuiTheme -ThemeName "VSCode"
```

### Theme Persistence
```powershell
# Export current theme
Export-TuiTheme -ThemeName "VSCode" -Path ".\vscode-theme.json"

# Share theme file and import elsewhere
Import-TuiTheme -Path ".\received-theme.json"
```

### Component Integration
```powershell
# In a UI component
class MyComponent : UIElement {
    [void] OnRender() {
        $bgColor = Get-ThemeColor -ColorName "Background"
        $accentColor = Get-ThemeColor -ColorName "Accent"
        
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
            -Width $this.Width -Height $this.Height `
            -BorderColor $accentColor -BackgroundColor $bgColor
    }
}

# Subscribe to theme changes
Subscribe-Event -EventName "Theme.Changed" -Handler {
    param($EventData)
    Write-Host "Theme changed to: $($EventData.Data.ThemeName)"
    # Refresh UI components
    Request-TuiRefresh
}
```

## Event System Integration

### Theme.Changed Event
Published when the active theme changes:

```powershell
{
    "EventName": "Theme.Changed",
    "Data": {
        "ThemeName": "Dark",
        "Theme": {
            "Name": "Dark",
            "Colors": { ... }
        }
    },
    "Timestamp": "2025-01-01T12:00:00.000Z"
}
```

### Event Subscription
```powershell
# Subscribe to theme changes
Subscribe-Event -EventName "Theme.Changed" -Handler {
    param($EventData)
    $themeName = $EventData.Data.ThemeName
    Write-Verbose "Theme changed to: $themeName"
    
    # Update UI components
    Request-TuiRefresh
}
```

## JSON Theme Format

### Standard Format
```json
{
  "Name": "MyTheme",
  "Colors": {
    "Background": "Black",
    "Foreground": "White",
    "Primary": "White",
    "Secondary": "Gray",
    "Accent": "Cyan",
    "Success": "Green",
    "Warning": "Yellow",
    "Error": "Red",
    "Info": "Blue",
    "Header": "Cyan",
    "Border": "DarkGray",
    "Selection": "Yellow",
    "Highlight": "Cyan",
    "Subtle": "DarkGray"
  }
}
```

### Truecolor Format
```json
{
  "Name": "ModernDark",
  "Colors": {
    "Background": "#1E1E1E",
    "Foreground": "#D4D4D4",
    "Accent": "#007ACC",
    "Success": "#4EC9B0",
    "Warning": "#FFCC02",
    "Error": "#F14C4C"
  }
}
```

## Error Handling

The theme manager includes comprehensive error handling:

### Invalid Theme Names
```powershell
try {
    Set-TuiTheme -ThemeName "NonExistentTheme"
} catch {
    Write-Host "Theme not found: $($_.Exception.Message)"
}
```

### File Operations
```powershell
try {
    Export-TuiTheme -ThemeName "MyTheme" -Path "C:\ReadOnlyFolder\theme.json"
} catch {
    Write-Host "Export failed: $($_.Exception.Message)"
}
```

### Color Validation
```powershell
try {
    New-TuiTheme -Name "InvalidTheme" -Colors @{
        Background = "InvalidColor"  # Will be validated and warned
    }
} catch {
    Write-Host "Theme creation failed: $($_.Exception.Message)"
}
```

## Best Practices

1. **Use Semantic Names** - Always use semantic color names rather than hardcoding colors
2. **Subscribe to Events** - Listen for theme changes to update UI components
3. **Provide Defaults** - Always specify default colors when calling Get-ThemeColor
4. **Test Themes** - Test custom themes with different UI components
5. **Version Themes** - Include version information in custom theme names
6. **Document Custom Colors** - Document any custom color roles in themes

## Performance Considerations

- **Color Caching** - Colors are cached until theme changes
- **Event Publishing** - Theme changes publish events for component updates
- **File I/O** - Import/export operations are optimized for small theme files
- **Memory Usage** - Themes are stored as lightweight hashtables

## Dependencies
- **exceptions** - For robust error handling with `Invoke-WithErrorHandling`
- **event-system** - For publishing theme change events
- **logger** (optional) - For structured logging integration

## Compatibility

The theme manager maintains backward compatibility:
- **Legacy Code** - Existing hardcoded colors continue to work
- **ConsoleColor** - Traditional ConsoleColor enums are fully supported
- **Gradual Migration** - Components can be migrated to themed colors incrementally

The theme manager provides a robust foundation for creating visually appealing and customizable terminal user interfaces with support for both traditional and modern color systems.
