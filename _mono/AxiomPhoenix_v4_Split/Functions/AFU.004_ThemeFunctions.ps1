# ==============================================================================
# Axiom-Phoenix v4.0 - Theme Functions (Enhanced for Palette-Based System)
# ==============================================================================

# Get theme color with fallback (uses new theme paths)
function Get-ThemeColor {
    param(
        [string]$ThemePath,
        [string]$DefaultColor = "#ffffff"
    )
    
    $themeManager = $global:TuiState?.Services?.ThemeManager
    if ($themeManager) {
        return $themeManager.GetColor($ThemePath, $DefaultColor)
    }
    return $DefaultColor
}

# Get any theme value (colors, borders, etc.) with fallback
function Get-ThemeValue {
    param(
        [string]$Path,
        [object]$DefaultValue = $null
    )
    
    $themeManager = $global:TuiState.Services.ThemeManager
    if ($themeManager) {
        return $themeManager.GetValue($Path, $DefaultValue)
    }
    return $DefaultValue
}

# Apply theme to a component (convenience function)
function Apply-ThemeToComponent {
    param(
        [UIElement]$Component,
        [string]$ComponentType
    )
    
    if (-not $Component -or -not $ComponentType) { return }
    
    # Common theme applications
    switch ($ComponentType) {
        "Panel" {
            $Component.SetBorderColor((Get-ThemeValue "Panel.Border" "#333333"))
            $Component.SetBackgroundColor((Get-ThemeValue "Panel.Background" "#000000"))
            if ($Component.Title) {
                # Title color handled internally by Panel
            }
        }
        "Button" {
            $Component.SetBackgroundColor((Get-ThemeValue "Button.Background" "#1A1A1A"))
            $Component.SetForegroundColor((Get-ThemeValue "Button.Foreground" "#E0E0E0"))
            # Focus states handled internally by Button
        }
        "TextBox" {
            $Component.SetBackgroundColor((Get-ThemeValue "TextBox.Background" "#1A1A1A"))
            $Component.SetForegroundColor((Get-ThemeValue "TextBox.Foreground" "#E0E0E0"))
            $Component.SetBorderColor((Get-ThemeValue "TextBox.Border" "#333333"))
            # PlaceholderColor does not have a setter method, direct assignment is fine.
            $Component.PlaceholderColor = Get-ThemeValue "TextBox.Placeholder" "#666666"
        }
        "List" {
            $Component.SetBackgroundColor((Get-ThemeValue "List.Background" "#000000"))
            $Component.SetForegroundColor((Get-ThemeValue "List.Foreground" "#E0E0E0"))
            # SelectedBackgroundColor and SelectedForegroundColor do not have setter methods, direct assignment is fine.
            $Component.SelectedBackgroundColor = Get-ThemeValue "List.SelectedBackground" "#0066CC"
            $Component.SelectedForegroundColor = Get-ThemeValue "List.SelectedForeground" "#FFFFFF"
            if ($Component.HasBorder) {
                $Component.SetBorderColor((Get-ThemeValue "List.Border" "#333333"))
            }
        }
        "Label" {
            # Labels typically inherit from parent, but can be set explicitly
            $bg = Get-ThemeValue "Label.Background"
            if ($bg -and $bg -ne 'transparent') {
                $Component.SetBackgroundColor($bg)
            }
            $Component.SetForegroundColor((Get-ThemeValue "Label.Foreground" "#E0E0E0"))
        }
    }
}

# Get contrasting color for readability
function Get-ContrastingColor {
    param(
        [string]$BackgroundColor
    )
    
    if (-not $BackgroundColor -or $BackgroundColor -eq 'transparent') {
        return "#FFFFFF"
    }
    
    # Simple luminance calculation
    $r = [Convert]::ToInt32($BackgroundColor.Substring(1, 2), 16)
    $g = [Convert]::ToInt32($BackgroundColor.Substring(3, 2), 16)
    $b = [Convert]::ToInt32($BackgroundColor.Substring(5, 2), 16)
    
    $luminance = (0.299 * $r + 0.587 * $g + 0.114 * $b) / 255
    
    if ($luminance -gt 0.5) {
        return "#000000"  # Dark text on light background
    } else {
        return "#FFFFFF"  # Light text on dark background
    }
}