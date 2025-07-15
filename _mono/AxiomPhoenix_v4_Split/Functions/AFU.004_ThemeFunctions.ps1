# ==============================================================================
# Axiom-Phoenix v4.0 - Theme Functions (Enhanced for Palette-Based System)
# ==============================================================================

# Get theme color with standardized key validation
function Get-ThemeColor {
    param(
        [string]$Key,
        [string]$Fallback = $null,
        [switch]$NoValidation
    )
    
    $themeManager = $global:TuiState?.Services?.ThemeManager
    if (-not $themeManager) {
        # Try alternate location during initialization
        $themeManager = $global:TuiState?.ServiceContainer?.GetService("ThemeManager")
    }
    
    if (-not $themeManager) {
        Write-Warning "ThemeManager not available, using fallback for '$Key'"
        return $Fallback -or "#FFFFFF"
    }
    
    # Check if key is in registry (case-insensitive)
    $keyLower = $Key.ToLower()
    if (-not $NoValidation -and $themeManager._validThemeKeys.ContainsKey($keyLower)) {
        $keyInfo = $themeManager._validThemeKeys[$keyLower]
        $actualPath = $keyInfo.Path
        $registryFallback = $keyInfo.Fallback
        
        $color = $themeManager.GetColor($actualPath)
        if ($color) { return $color }
        
        # Use parameter fallback first, then registry fallback
        return $Fallback -or $registryFallback
    }
    
    # Legacy mode - direct path lookup with warning
    if (-not $NoValidation) {
        Write-Warning "Theme key '$Key' not in registry. Add to _validThemeKeys or use -NoValidation. Using direct lookup."
    }
    
    $color = $themeManager.GetColor($Key)
    return $color -or $Fallback -or "#FFFFFF"
}

# Get any theme value (colors, borders, etc.) with fallback
function Get-ThemeValue {
    param(
        [string]$Path,
        [object]$DefaultValue = $null
    )
    
    $themeManager = $global:TuiState?.Services?.ThemeManager
    if (-not $themeManager) {
        # Try alternate location during initialization
        $themeManager = $global:TuiState?.ServiceContainer?.GetService("ThemeManager")
    }
    
    if ($themeManager) {
        return $themeManager.GetThemeValue($Path, $DefaultValue)
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
            $Component.BorderColor = Get-ThemeValue "Panel.Border" "#333333"
            $Component.BackgroundColor = Get-ThemeValue "Panel.Background" "#000000"
            if ($Component.Title) {
                # Title color handled internally by Panel
            }
        }
        "Button" {
            $Component.BackgroundColor = Get-ThemeValue "Button.Background" "#1A1A1A"
            $Component.ForegroundColor = Get-ThemeValue "Button.Foreground" "#E0E0E0"
            # Focus states handled internally by Button
        }
        "TextBox" {
            $Component.BackgroundColor = Get-ThemeValue "TextBox.Background" "#1A1A1A"
            $Component.ForegroundColor = Get-ThemeValue "TextBox.Foreground" "#E0E0E0"
            $Component.BorderColor = Get-ThemeValue "TextBox.Border" "#333333"
            # PlaceholderColor does not have a setter method, direct assignment is fine.
            $Component.PlaceholderColor = Get-ThemeValue "TextBox.Placeholder" "#666666"
        }
        "List" {
            $Component.BackgroundColor = Get-ThemeValue "List.Background" "#000000"
            $Component.ForegroundColor = Get-ThemeValue "List.Foreground" "#E0E0E0"
            # SelectedBackgroundColor and SelectedForegroundColor do not have setter methods, direct assignment is fine.
            $Component.SelectedBackgroundColor = Get-ThemeValue "List.SelectedBackground" "#0066CC"
            $Component.SelectedForegroundColor = Get-ThemeValue "List.SelectedForeground" "#FFFFFF"
            if ($Component.HasBorder) {
                $Component.BorderColor = Get-ThemeValue "List.Border" "#333333"
            }
        }
        "Label" {
            # Labels typically inherit from parent, but can be set explicitly
            $bg = Get-ThemeValue "Label.Background"
            if ($bg -and $bg -ne 'transparent') {
                $Component.BackgroundColor = $bg
            }
            $Component.ForegroundColor = Get-ThemeValue "Label.Foreground" "#E0E0E0"
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