# ==============================================================================
# Axiom-Phoenix v4.0 - ThemeManager with Palette-Based Architecture
# Core application services: action, navigation, data, theming, logging, events
# ==============================================================================

#region ThemeManager Class

# ===== CLASS: ThemeManager =====
# Module: theme-manager (from axiom)
# Dependencies: None
# Purpose: Visual theming system with palette-based architecture
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
            Palette = @{
                # Base colors
                Black = "#0a0e27"
                White = "#ffffff"
                Primary = "#f92aad"
                Secondary = "#5a189a"
                Accent = "#ffcc00"
                Success = "#3bf4fb"
                Warning = "#ffbe0b"
                Error = "#ff006e"
                Info = "#8338ec"
                Subtle = "#72f1b8"
                
                # Grays
                Background = "#0a0e27"
                Surface = "#1a1e3a"
                Border = "#2a2e4a"
                TextPrimary = "#f92aad"
                TextSecondary = "#72f1b8"
                TextDisabled = "#555555"
            }
            
            Components = @{
                # Screen/Window
                Screen = @{
                    Background = '$Palette.Background'
                    Foreground = '$Palette.TextPrimary'
                }
                
                # Panel
                Panel = @{
                    Background = '$Palette.Background'
                    Border = '$Palette.Border'
                    Title = '$Palette.Accent'
                    Header = '$Palette.Surface'
                }
                
                # Labels and Text
                Label = @{
                    Foreground = '$Palette.TextPrimary'
                    Disabled = '$Palette.TextDisabled'
                }
                
                # Buttons
                Button = @{
                    Normal = @{
                        Foreground = '$Palette.Black'
                        Background = '$Palette.Primary'
                    }
                    Focused = @{
                        Foreground = '$Palette.Black'
                        Background = '$Palette.Accent'
                    }
                    Pressed = @{
                        Foreground = '$Palette.Black'
                        Background = '$Palette.Secondary'
                    }
                    Disabled = @{
                        Foreground = '$Palette.TextDisabled'
                        Background = '$Palette.Border'
                    }
                }
                
                # Input fields
                Input = @{
                    Background = '$Palette.Surface'
                    Foreground = '$Palette.TextPrimary'
                    Placeholder = '$Palette.TextSecondary'
                    Border = '$Palette.Border'
                    FocusedBorder = '$Palette.Accent'
                }
                
                # Lists and Tables
                List = @{
                    Background = '$Palette.Background'
                    ItemNormal = '$Palette.TextPrimary'
                    ItemSelected = '$Palette.Black'
                    ItemSelectedBackground = '$Palette.Primary'
                    ItemFocused = '$Palette.Black'
                    ItemFocusedBackground = '$Palette.Accent'
                    HeaderForeground = '$Palette.Accent'
                    HeaderBackground = '$Palette.Surface'
                    Scrollbar = '$Palette.Subtle'
                }
                
                # Status
                Status = @{
                    Success = '$Palette.Success'
                    Warning = '$Palette.Warning'
                    Error = '$Palette.Error'
                    Info = '$Palette.Info'
                }
                
                # Overlay/Dialog
                Overlay = @{
                    Background = '$Palette.Black'
                    DialogBackground = '$Palette.Surface'
                }
            }
        }
        
        # Green Theme - Classic terminal green
        $this.Themes["Green"] = @{
            Palette = @{
                # Base colors
                Black = "#000000"
                White = "#ffffff"
                Primary = "#00ff00"
                Secondary = "#008000"
                Accent = "#ffff00"
                Success = "#00ff00"
                Warning = "#ffff00"
                Error = "#ff0000"
                Info = "#00ffff"
                Subtle = "#008000"
                
                # Grays
                Background = "#000000"
                Surface = "#001100"
                Border = "#00ff00"
                TextPrimary = "#00ff00"
                TextSecondary = "#008000"
                TextDisabled = "#004400"
            }
            
            Components = @{
                # Copy structure from Synthwave, all values reference $Palette
                Screen = @{
                    Background = '$Palette.Background'
                    Foreground = '$Palette.TextPrimary'
                }
                
                Panel = @{
                    Background = '$Palette.Background'
                    Border = '$Palette.Border'
                    Title = '$Palette.Primary'
                    Header = '$Palette.Surface'
                }
                
                Label = @{
                    Foreground = '$Palette.TextPrimary'
                    Disabled = '$Palette.TextDisabled'
                }
                
                Button = @{
                    Normal = @{
                        Foreground = '$Palette.Black'
                        Background = '$Palette.Primary'
                    }
                    Focused = @{
                        Foreground = '$Palette.Black'
                        Background = '$Palette.Accent'
                    }
                    Pressed = @{
                        Foreground = '$Palette.Black'
                        Background = '$Palette.Secondary'
                    }
                    Disabled = @{
                        Foreground = '$Palette.TextDisabled'
                        Background = '$Palette.Surface'
                    }
                }
                
                Input = @{
                    Background = '$Palette.Surface'
                    Foreground = '$Palette.TextPrimary'
                    Placeholder = '$Palette.TextSecondary'
                    Border = '$Palette.Border'
                    FocusedBorder = '$Palette.Primary'
                }
                
                List = @{
                    Background = '$Palette.Background'
                    ItemNormal = '$Palette.TextPrimary'
                    ItemSelected = '$Palette.Black'
                    ItemSelectedBackground = '$Palette.Primary'
                    ItemFocused = '$Palette.Black'
                    ItemFocusedBackground = '$Palette.Accent'
                    HeaderForeground = '$Palette.Primary'
                    HeaderBackground = '$Palette.Surface'
                    Scrollbar = '$Palette.Secondary'
                }
                
                Status = @{
                    Success = '$Palette.Success'
                    Warning = '$Palette.Warning'
                    Error = '$Palette.Error'
                    Info = '$Palette.Info'
                }
                
                Overlay = @{
                    Background = '$Palette.Black'
                    DialogBackground = '$Palette.Surface'
                }
            }
        }
    }
    
    [void] LoadTheme([string]$themeName) {
        if ($this.Themes.ContainsKey($themeName)) {
            $this.CurrentTheme = $this.Themes[$themeName].Clone()
            $this.ThemeName = $themeName
            # Force redraw
            if ($global:TuiState) {
                $global:TuiState.IsDirty = $true
            }
        }
    }
    
    [void] LoadDefaultTheme() {
        $this.LoadTheme("Synthwave")
    }
    
    # Get any theme value (not just colors)
    [string] GetThemeValue([string]$path) {
        return $this.GetThemeValue($path, "#FFFFFF")
    }
    
    [string] GetThemeValue([string]$path, [string]$defaultValue) {
        # Split the path (e.g., "List.ItemSelected" -> ["List", "ItemSelected"])
        $parts = $path -split '\.'
        
        # Navigate through the theme structure
        $current = $this.CurrentTheme.Components
        foreach ($part in $parts) {
            if ($current -is [hashtable] -and $current.ContainsKey($part)) {
                $current = $current[$part]
            } else {
                return $defaultValue
            }
        }
        
        # If we found a value, check if it's a palette reference
        if ($current -is [string] -and $current.StartsWith('$Palette.')) {
            # Extract the palette key
            $paletteKey = $current.Substring(9) # Remove '$Palette.'
            if ($this.CurrentTheme.Palette.ContainsKey($paletteKey)) {
                return $this.CurrentTheme.Palette[$paletteKey]
            }
        }
        
        # Return the value as-is if it's not a palette reference
        return $current
    }
    
    # Backward compatibility
    [string] GetColor([string]$colorName) {
        # Map old color names to new paths
        $mappings = @{
            "Background" = "Screen.Background"
            "Foreground" = "Screen.Foreground"
            "Primary" = "Screen.Foreground"
            "border.active" = "Panel.Border"
            "border.inactive" = "Panel.Border"
            "component.background" = "Panel.Background"
            "component.border" = "Panel.Border"
            "component.title" = "Panel.Title"
            "component.text" = "Label.Foreground"
            "list.selected.bg" = "List.ItemSelectedBackground"
            "list.selected.fg" = "List.ItemSelected"
            "list.item.selected" = "List.ItemSelected"
            "list.item.selected.background" = "List.ItemSelectedBackground"
            "list.item.normal" = "List.ItemNormal"
            "list.scrollbar" = "List.Scrollbar"
            "label" = "Label.Foreground"
            "primary.accent" = "Panel.Title"
            "primary.text" = "Label.Foreground"
            "overlay.background" = "Overlay.Background"
            "Info" = "Status.Info"
            "Success" = "Status.Success"
            "Warning" = "Status.Warning"
            "Error" = "Status.Error"
            "Subtle" = "Label.Foreground"
        }
        
        if ($mappings.ContainsKey($colorName)) {
            return $this.GetThemeValue($mappings[$colorName], "#FFFFFF")
        }
        
        # Check if it's already a path
        if ($colorName -match '\.') {
            return $this.GetThemeValue($colorName, "#FFFFFF")
        }
        
        # Check palette directly
        if ($this.CurrentTheme.Palette.ContainsKey($colorName)) {
            return $this.CurrentTheme.Palette[$colorName]
        }
        
        return "#FFFFFF"
    }
    
    [string] GetColor([string]$colorName, [string]$defaultColor) {
        $color = $this.GetColor($colorName)
        if ($color -eq "#FFFFFF" -and $defaultColor -ne "#FFFFFF") {
            return $defaultColor
        }
        return $color
    }
    
    [void] SetColor([string]$colorName, $colorValue) {
        # This is deprecated in the new system
        Write-Warning "SetColor is deprecated. Themes should be modified through the palette."
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
#<!-- END_PAGE: ASE.003 -->
