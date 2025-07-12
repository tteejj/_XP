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
    [string]$ThemeName = ""
    [hashtable]$Themes = @{}
    
    ThemeManager() {
        $this.InitializeThemes()
        $this.LoadDefaultTheme()
    }
    
    [void] InitializeThemes() {
        # Load external themes first
        $this.LoadExternalThemes()
        
        # Basic fallback theme - only if no external themes loaded
        if ($this.Themes.Count -eq 0) {
            $this.Themes["Fallback"] = @{
                Palette = @{
                    Black = "#000000"
                    White = "#ffffff"
                    Primary = "#00ff00"
                    Secondary = "#008000"
                    Accent = "#ffff00"
                    Success = "#00ff00"
                    Warning = "#ffff00"
                    Error = "#ff0000"
                    Info = "#00ffff"
                    Background = "#000000"
                    Surface = "#001100"
                    Border = "#00ff00"
                    TextPrimary = "#00ff00"
                    TextSecondary = "#008000"
                    TextDisabled = "#004400"
                }
                
                Components = @{
                    Screen = @{ Background = '$Palette.Background'; Foreground = '$Palette.TextPrimary' }
                    Panel = @{ Background = '$Palette.Background'; Border = '$Palette.Border'; Title = '$Palette.Primary'; Header = '$Palette.Surface' }
                    Label = @{ Foreground = '$Palette.TextPrimary'; Disabled = '$Palette.TextDisabled' }
                    Button = @{
                        Normal = @{ Foreground = '$Palette.Black'; Background = '$Palette.Primary' }
                        Focused = @{ Foreground = '$Palette.Black'; Background = '$Palette.Accent' }
                        Pressed = @{ Foreground = '$Palette.Black'; Background = '$Palette.Secondary' }
                        Disabled = @{ Foreground = '$Palette.TextDisabled'; Background = '$Palette.Surface' }
                    }
                    Input = @{ Background = '$Palette.Surface'; Foreground = '$Palette.TextPrimary'; Placeholder = '$Palette.TextSecondary'; Border = '$Palette.Border'; FocusedBorder = '$Palette.Primary' }
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
                    Status = @{ Success = '$Palette.Success'; Warning = '$Palette.Warning'; Error = '$Palette.Error'; Info = '$Palette.Info' }
                    Overlay = @{ Background = '$Palette.Black'; DialogBackground = '$Palette.Surface' }
                }
            }
        }
    }
    
    # Load themes from external files
    [void] LoadExternalThemes() {
        try {
            # Get the current script directory
            $scriptPath = $PSScriptRoot
            if (-not $scriptPath) {
                $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
            }
            
            # Look for Themes folder relative to Services folder
            $themesPath = Join-Path (Split-Path $scriptPath -Parent) "Themes"
            
            if (Test-Path $themesPath) {
                $themeFiles = Get-ChildItem -Path $themesPath -Filter "*.ps1"
                
                foreach ($themeFile in $themeFiles) {
                    try {
                        # Execute the theme file to get the hashtable
                        $themeData = & $themeFile.FullName
                        
                        if ($themeData -and $themeData.Name) {
                            $this.Themes[$themeData.Name] = $themeData
                            Write-Host "Loaded theme: $($themeData.Name)" -ForegroundColor Green
                        }
                    }
                    catch {
                        Write-Warning "Failed to load theme file: $($themeFile.Name) - $_"
                    }
                }
            }
            else {
                Write-Host "Themes folder not found at: $themesPath" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Warning "Error loading external themes: $_"
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
        $availableThemes = $this.GetAvailableThemes()
        if ($availableThemes.Count -gt 0) {
            # Load first external theme if available, otherwise fallback
            $preferredOrder = @("Cyberpunk", "Modern Dark", "Synthwave", "RetroAmber", "HighContrast", "Fallback")
            $themeToLoad = "Fallback"  # Default fallback
            
            foreach ($preferred in $preferredOrder) {
                if ($preferred -in $availableThemes) {
                    $themeToLoad = $preferred
                    break
                }
            }
            
            $this.LoadTheme($themeToLoad)
        }
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
    
    # Get color using new theme paths only
    [string] GetColor([string]$colorPath) {
        return $this.GetColor($colorPath, "#ffffff")
    }
    
    [string] GetColor([string]$colorPath, [string]$defaultColor) {
        # Check if it's a component path (e.g., "Panel.Border")
        if ($colorPath -match '\.') {
            return $this.GetThemeValue($colorPath, $defaultColor)
        }
        
        # Check palette directly
        if ($this.CurrentTheme.Palette.ContainsKey($colorPath)) {
            return $this.CurrentTheme.Palette[$colorPath]
        }
        
        return $defaultColor
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
