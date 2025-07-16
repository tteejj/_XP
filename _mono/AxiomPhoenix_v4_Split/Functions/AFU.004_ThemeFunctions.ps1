# ==============================================================================
# Axiom-Phoenix v4.0 - Theme Functions (Enhanced for Palette-Based System)
# ==============================================================================

# PERFORMANCE: Cache ThemeManager reference and frequently requested colors
$script:CachedThemeManager = $null
$script:ColorCache = @{}
$script:CacheVersion = 0

# Get theme color with standardized key validation
function Get-ThemeColor {
    param(
        [string]$Key,
        [string]$Fallback = $null,
        [switch]$NoValidation
    )
    
    # PERFORMANCE: Use cached ThemeManager reference
    if (-not $script:CachedThemeManager) {
        # Path 1: Direct Services hashtable (Start.ps1 setup)
        if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.ThemeManager) {
            $script:CachedThemeManager = $global:TuiState.Services.ThemeManager
        }
        
        # Path 2: ServiceContainer access (modern pattern)
        if (-not $script:CachedThemeManager -and $global:TuiState -and $global:TuiState.ServiceContainer) {
            try {
                $script:CachedThemeManager = $global:TuiState.ServiceContainer.GetService("ThemeManager")
            } catch {
                # ServiceContainer might not be ready
            }
        }
        
        # Path 3: Legacy Services.ServiceContainer pattern (fallback)
        if (-not $script:CachedThemeManager -and $global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.ServiceContainer) {
            try {
                $script:CachedThemeManager = $global:TuiState.Services.ServiceContainer.GetService("ThemeManager")
            } catch {
                # ServiceContainer might not be ready
            }
        }
    }
    
    if (-not $script:CachedThemeManager) {
        return $Fallback -or "#FFFFFF"
    }
    
    # PERFORMANCE: Check color cache first
    $cacheKey = "$Key|$Fallback|$NoValidation"
    if ($script:ColorCache.ContainsKey($cacheKey)) {
        return $script:ColorCache[$cacheKey]
    }
    
    $themeManager = $script:CachedThemeManager
    
    # Check if key is in registry using public method
    if (-not $NoValidation -and $themeManager.IsValidThemeKey($Key)) {
        $keyInfo = $themeManager.GetThemeKeyInfo($Key)
        if ($keyInfo) {
            $actualPath = $keyInfo.Path
            $registryFallback = $keyInfo.Fallback
            
            $color = $themeManager.GetColor($actualPath)
            if ($color) { 
                # PERFORMANCE: Cache the result
                $script:ColorCache[$cacheKey] = $color
                return $color 
            }
            
            # Use parameter fallback first, then registry fallback
            $result = $Fallback -or $registryFallback
            $script:ColorCache[$cacheKey] = $result
            return $result
        }
    }
    
    # Legacy mode - direct path lookup with warning
    if (-not $NoValidation) {
        Write-Warning "Theme key '$Key' not in registry. Add to _validThemeKeys or use -NoValidation. Using direct lookup."
    }
    
    $color = $themeManager.GetColor($Key)
    $result = $color -or $Fallback -or "#FFFFFF"
    # PERFORMANCE: Cache the result
    $script:ColorCache[$cacheKey] = $result
    return $result
}

# PERFORMANCE: Clear theme cache when theme changes
function Clear-ThemeCache {
    $script:ColorCache.Clear()
    $script:CachedThemeManager = $null
}

# Get any theme value (colors, borders, etc.) with fallback
function Get-ThemeValue {
    param(
        [string]$Path,
        [object]$DefaultValue = $null
    )
    
    # Try multiple paths to find ThemeManager - CRITICAL FIX for service access
    $themeManager = $null
    
    # Path 1: Direct Services hashtable (Start.ps1 setup)
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.ThemeManager) {
        $themeManager = $global:TuiState.Services.ThemeManager
    }
    
    # Path 2: ServiceContainer access (modern pattern)
    if (-not $themeManager -and $global:TuiState -and $global:TuiState.ServiceContainer) {
        try {
            $themeManager = $global:TuiState.ServiceContainer.GetService("ThemeManager")
        } catch {
            # ServiceContainer might not be ready
        }
    }
    
    # Path 3: Legacy Services.ServiceContainer pattern (fallback)
    if (-not $themeManager -and $global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.ServiceContainer) {
        try {
            $themeManager = $global:TuiState.Services.ServiceContainer.GetService("ThemeManager")
        } catch {
            # ServiceContainer might not be ready
        }
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