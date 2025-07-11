# ==============================================================================
# Axiom-Phoenix v4.0 - All Services (Load After Components)
# Core application services: action, navigation, data, theming, logging, events
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASE.###" to find specific sections.
# Each section ends with "END_PAGE: ASE.###"
# ==============================================================================

#region ThemeManager Class

# ===== CLASS: ThemeManager =====
# Module: theme-manager (from axiom)
# Dependencies: None
# Purpose: Visual theming system with consistent hex color output
class ThemeManager {
    [hashtable]$CurrentTheme = @{}
    [string]$ThemeName = "Synthwave"
    [hashtable]$Themes = @{}
    
    ThemeManager() {
        $this.InitializeThemes()
        $this.LoadTheme($this.ThemeName)
    }
    
    [void] InitializeThemes() {
        # Synthwave Theme - Neon cyberpunk aesthetic
        $this.Themes["Synthwave"] = @{
            # Base colors
            "Background" = "#0a0e27"
            "Foreground" = "#f92aad"
            "Subtle" = "#72f1b8"
            "Primary" = "#ff6ac1"
            "Accent" = "#ffcc00"
            "Secondary" = "#5a189a"
            "Error" = "#ff006e"
            "Warning" = "#ffbe0b"
            "Success" = "#3bf4fb"
            "Info" = "#8338ec"
            
            # Component specific
            "component.background" = "#0a0e27"
            "component.border" = "#f92aad"
            "component.title" = "#ffcc00"
            "component.text" = "#f92aad"  # ADDED
            
            # Input
            "input.background" = "#1a1e3a"
            "input.foreground" = "#f92aad"
            "input.placeholder" = "#72f1b8"
            
            # Button states
            "button.normal.fg" = "#0a0e27"
            "button.normal.bg" = "#f92aad"
            "button.focused.fg" = "#0a0e27"
            "button.focused.bg" = "#ff6ac1"
            "button.pressed.fg" = "#0a0e27"
            "button.pressed.bg" = "#ffcc00"
            "button.disabled.fg" = "#555555"
            "button.disabled.bg" = "#2a2e4a"
            
            # List/Table
            "list.header.fg" = "#ffcc00"
            "list.header.bg" = "#1a1e3a"
            "list.item.normal" = "#f92aad"
            "list.item.selected" = "#0a0e27"
            "list.item.selected.background" = "#ff6ac1"
            "list.scrollbar" = "#72f1b8"
            
            # Overlay
            "overlay.background" = "#0a0e27"  # ADDED
        }
        
        # Aurora Theme - Northern lights inspired
        $this.Themes["Aurora"] = @{
            # Base colors
            "Background" = "#011627"
            "Foreground" = "#d6deeb"
            "Subtle" = "#7fdbca"
            "Primary" = "#82aaff"
            "Accent" = "#21c7a8"
            "Secondary" = "#c792ea"
            "Error" = "#ef5350"
            "Warning" = "#ffeb95"
            "Success" = "#22da6e"
            "Info" = "#82aaff"
            
            # Component specific
            "component.background" = "#011627"
            "component.border" = "#5f7e97"
            "component.title" = "#21c7a8"
            
            # Input
            "input.background" = "#0e293f"
            "input.foreground" = "#d6deeb"
            "input.placeholder" = "#637777"
            
            # Button states
            "button.normal.fg" = "#011627"
            "button.normal.bg" = "#82aaff"
            "button.focused.fg" = "#011627"
            "button.focused.bg" = "#21c7a8"
            "button.pressed.fg" = "#011627"
            "button.pressed.bg" = "#c792ea"
            "button.disabled.fg" = "#444444"
            "button.disabled.bg" = "#1d3b53"
            
            # List/Table
            "list.header.fg" = "#21c7a8"
            "list.header.bg" = "#0e293f"
            "list.item.normal" = "#d6deeb"
            "list.item.selected" = "#011627"
            "list.item.selected.background" = "#82aaff"
            "list.scrollbar" = "#5f7e97"
        }
        
        # Ocean Theme - Deep sea aesthetics
        $this.Themes["Ocean"] = @{
            # Base colors
            "Background" = "#0f111a"
            "Foreground" = "#8f93a2"
            "Subtle" = "#4b526d"
            "Primary" = "#00bcd4"
            "Accent" = "#00e676"
            "Secondary" = "#536dfe"
            "Error" = "#ff5252"
            "Warning" = "#ffb74d"
            "Success" = "#00e676"
            "Info" = "#448aff"
            
            # Component specific
            "component.background" = "#0f111a"
            "component.border" = "#1f2937"
            "component.title" = "#00bcd4"
            
            # Input
            "input.background" = "#1a1f2e"
            "input.foreground" = "#8f93a2"
            "input.placeholder" = "#4b526d"
            
            # Button states
            "button.normal.fg" = "#0f111a"
            "button.normal.bg" = "#00bcd4"
            "button.focused.fg" = "#0f111a"
            "button.focused.bg" = "#00e676"
            "button.pressed.fg" = "#0f111a"
            "button.pressed.bg" = "#536dfe"
            "button.disabled.fg" = "#333333"
            "button.disabled.bg" = "#1a1f2e"
            
            # List/Table
            "list.header.fg" = "#00e676"
            "list.header.bg" = "#1a1f2e"
            "list.item.normal" = "#8f93a2"
            "list.item.selected" = "#0f111a"
            "list.item.selected.background" = "#00bcd4"
            "list.scrollbar" = "#4b526d"
        }
        
        # Forest Theme - Nature inspired
        $this.Themes["Forest"] = @{
            # Base colors
            "Background" = "#0d1117"
            "Foreground" = "#c9d1d9"
            "Subtle" = "#8b949e"
            "Primary" = "#58a6ff"
            "Accent" = "#56d364"
            "Secondary" = "#d29922"
            "Error" = "#f85149"
            "Warning" = "#f0883e"
            "Success" = "#56d364"
            "Info" = "#58a6ff"
            
            # Component specific
            "component.background" = "#0d1117"
            "component.border" = "#30363d"
            "component.title" = "#56d364"
            
            # Input
            "input.background" = "#161b22"
            "input.foreground" = "#c9d1d9"
            "input.placeholder" = "#484f58"
            
            # Button states
            "button.normal.fg" = "#0d1117"
            "button.normal.bg" = "#58a6ff"
            "button.focused.fg" = "#0d1117"
            "button.focused.bg" = "#56d364"
            "button.pressed.fg" = "#0d1117"
            "button.pressed.bg" = "#d29922"
            "button.disabled.fg" = "#484f58"
            "button.disabled.bg" = "#21262d"
            
            # List/Table
            "list.header.fg" = "#56d364"
            "list.header.bg" = "#161b22"
            "list.item.normal" = "#c9d1d9"
            "list.item.selected" = "#0d1117"
            "list.item.selected.background" = "#58a6ff"
            "list.scrollbar" = "#8b949e"
        }
        
        # Green Theme - Classic terminal green
        $this.Themes["Green"] = @{
            # Base colors
            "Background" = "#000000"
            "Foreground" = "#00FF00"
            "Subtle" = "#008000"
            "Primary" = "#00FF00"
            "Accent" = "#FFFF00"
            "Secondary" = "#008000"
            "Error" = "#FF0000"
            "Warning" = "#FFFF00"
            "Success" = "#00FF00"
            "Info" = "#00FFFF"
            
            # Component specific
            "component.background" = "#000000"
            "component.border" = "#00FF00"
            "component.title" = "#00FF00"
            "component.text" = "#00FF00"
            
            # Input
            "input.background" = "#001100"
            "input.foreground" = "#00FF00"
            "input.placeholder" = "#008000"
            
            # Button states
            "button.normal.fg" = "#000000"
            "button.normal.bg" = "#00FF00"
            "button.focused.fg" = "#000000"
            "button.focused.bg" = "#00FF00"
            "button.pressed.fg" = "#000000"
            "button.pressed.bg" = "#FFFF00"
            "button.disabled.fg" = "#004400"
            "button.disabled.bg" = "#002200"
            
            # List/Table
            "list.header.fg" = "#00FF00"
            "list.header.bg" = "#001100"
            "list.item.normal" = "#00FF00"
            "list.item.selected" = "#000000"
            "list.item.selected.background" = "#00FF00"
            "list.scrollbar" = "#008000"
            
            # Overlay
            "overlay.background" = "#000000"
        }
    }
    
    [void] LoadTheme([string]$themeName) {
        if ($this.Themes.ContainsKey($themeName)) {
            $this.CurrentTheme = $this.Themes[$themeName].Clone()
            $this.ThemeName = $themeName
        }
    }
    
    [void] LoadDefaultTheme() {
        $this.LoadTheme("Synthwave")
    }
    
    [string] GetColor([string]$colorName) {
        return $this.GetColor($colorName, "#FFFFFF")
    }
    
    [string] GetColor([string]$colorName, [string]$defaultColor) {
        if ($this.CurrentTheme.ContainsKey($colorName)) {
            return $this.CurrentTheme[$colorName]
        }
        return $defaultColor
    }
    
    [void] SetColor([string]$colorName, $colorValue) {
        # Convert ConsoleColor to hex if needed
        if ($colorValue -is [ConsoleColor]) {
            $consoleColorMap = @{
                [ConsoleColor]::Black = "#000000"
                [ConsoleColor]::DarkBlue = "#000080"
                [ConsoleColor]::DarkGreen = "#008000"
                [ConsoleColor]::DarkCyan = "#008080"
                [ConsoleColor]::DarkRed = "#800000"
                [ConsoleColor]::DarkMagenta = "#800080"
                [ConsoleColor]::DarkYellow = "#808000"
                [ConsoleColor]::Gray = "#C0C0C0"
                [ConsoleColor]::DarkGray = "#808080"
                [ConsoleColor]::Blue = "#0000FF"
                [ConsoleColor]::Green = "#00FF00"
                [ConsoleColor]::Cyan = "#00FFFF"
                [ConsoleColor]::Red = "#FF0000"
                [ConsoleColor]::Magenta = "#FF00FF"
                [ConsoleColor]::Yellow = "#FFFF00"
                [ConsoleColor]::White = "#FFFFFF"
            }
            $colorValue = $consoleColorMap[$colorValue]
        }
        
        $this.CurrentTheme[$colorName] = $colorValue
        # Force redraw when colors change
        if ($global:TuiState) {
            $global:TuiState.IsDirty = $true
        }
    }
    
    [string[]] GetAvailableThemes() {
        return $this.Themes.Keys | Sort-Object
    }
    
    [void] CycleTheme() {
        $availableThemes = $this.GetAvailableThemes()
        $currentIndex = [array]::IndexOf($availableThemes, $this.ThemeName)
        $nextIndex = ($currentIndex + 1) % $availableThemes.Count
        $this.LoadTheme($availableThemes[$nextIndex])
    }
}

#endregion
#<!-- END_PAGE: ASE.005 -->
