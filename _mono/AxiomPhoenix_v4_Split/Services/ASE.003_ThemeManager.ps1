# ==============================================================================
# Axiom-Phoenix v4.0 - ThemeManager with Palette-Based Architecture
# FIXED: LoadTheme now properly updates all existing UI components
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
                $themeFiles = Get-ChildItem -Path $themesPath -Filter "*.ps1" -CaseSensitive
                
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
    
    # CRITICAL FIX: LoadTheme now properly updates all existing UI components
    [void] LoadTheme([string]$themeName) {
        if ($this.Themes.ContainsKey($themeName)) {
            Write-Host "ThemeManager: Loading theme '$themeName'" -ForegroundColor Yellow
            
            $this.CurrentTheme = $this.Themes[$themeName].Clone()
            $this.ThemeName = $themeName
            
            # CRITICAL: Update all existing UI components with new theme colors
            $this.RefreshAllComponents()
            
            # Force complete redraw
            if ($global:TuiState) {
                $global:TuiState.IsDirty = $true
                
                # Clear buffer to force complete re-render
                if ($global:TuiState.PSObject.Properties['MainBuffer'] -and $global:TuiState.MainBuffer) {
                    $global:TuiState.MainBuffer.Clear()
                }
            }
            
            Write-Host "ThemeManager: Theme '$themeName' applied successfully" -ForegroundColor Green
        } else {
            Write-Warning "ThemeManager: Theme '$themeName' not found"
        }
    }
    
    # NEW: Refresh all existing UI components with current theme colors
    [void] RefreshAllComponents() {
        if (-not $global:TuiState -or -not $global:TuiState.CurrentScreen) {
            return
        }
        
        Write-Host "ThemeManager: Refreshing all UI components..." -ForegroundColor Cyan
        
        # Recursively update all components starting from current screen
        $this.UpdateComponentThemeRecursive($global:TuiState.CurrentScreen)
        
        # Also update any overlays or dialogs
        if ($global:TuiState.PSObject.Properties['OverlayStack']) {
            foreach ($overlay in $global:TuiState.OverlayStack) {
                $this.UpdateComponentThemeRecursive($overlay)
            }
        }
    }
    
    # NEW: Recursively update component colors
    hidden [void] UpdateComponentThemeRecursive([object]$component) {
        if (-not $component) { return }
        
        try {
            $componentType = $component.GetType().Name
            
            # Update component based on its type
            switch -Regex ($componentType) {
                "Screen" {
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $component.BackgroundColor = $this.GetColor("Screen.Background")
                    }
                    if ($component.PSObject.Properties['ForegroundColor']) {
                        $component.ForegroundColor = $this.GetColor("Screen.Foreground")
                    }
                }
                "Panel" {
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $component.BackgroundColor = $this.GetColor("Panel.Background")
                    }
                    if ($component.PSObject.Properties['BorderColor']) {
                        $component.BorderColor = $this.GetColor("Panel.Border")
                    }
                    if ($component.PSObject.Properties['TitleColor']) {
                        $component.TitleColor = $this.GetColor("Panel.Title")
                    }
                }
                ".*Label.*|LabelComponent" {
                    if ($component.PSObject.Properties['ForegroundColor']) {
                        $component.ForegroundColor = $this.GetColor("Label.Foreground")
                    }
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $bgColor = $this.GetColor("Panel.Background")
                        if ($bgColor) {
                            $component.BackgroundColor = $bgColor
                        }
                    }
                }
                ".*Button.*|ButtonComponent" {
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $component.BackgroundColor = $this.GetColor("Button.Normal.Background")
                    }
                    if ($component.PSObject.Properties['ForegroundColor']) {
                        $component.ForegroundColor = $this.GetColor("Button.Normal.Foreground")
                    }
                }
                ".*List.*|ListBox" {
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $component.BackgroundColor = $this.GetColor("List.Background")
                    }
                    if ($component.PSObject.Properties['ForegroundColor']) {
                        $component.ForegroundColor = $this.GetColor("List.ItemNormal")
                    }
                    if ($component.PSObject.Properties['BorderColor']) {
                        $component.BorderColor = $this.GetColor("Input.Border")
                    }
                }
                ".*TextBox.*|.*Input.*" {
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $component.BackgroundColor = $this.GetColor("Input.Background")
                    }
                    if ($component.PSObject.Properties['ForegroundColor']) {
                        $component.ForegroundColor = $this.GetColor("Input.Foreground")
                    }
                    if ($component.PSObject.Properties['BorderColor']) {
                        $component.BorderColor = $this.GetColor("Input.Border")
                    }
                }
            }
            
            # Force the component to redraw
            if ($component.PSObject.Methods['RequestRedraw']) {
                $component.RequestRedraw()
            }
            
            # Recursively update all children
            if ($component.PSObject.Properties['Children']) {
                foreach ($child in $component.Children) {
                    $this.UpdateComponentThemeRecursive($child)
                }
            }
        }
        catch {
            # Silently ignore errors for components that don't support theme updates
        }
    }
    
    [void] LoadDefaultTheme() {
        $availableThemes = $this.GetAvailableThemes()
        if ($availableThemes.Count -gt 0) {
            # Load first external theme if available, otherwise fallback
            $preferredOrder = @("Default", "Retro Amber", "Synthwave", "Green Console", "Fallback")
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
    
    # NEW: Force save theme (for compatibility)
    [void] SaveTheme() {
        # In this system, themes are loaded from files, not saved
        # This method exists for compatibility but doesn't need to do anything
        Write-Host "ThemeManager: Theme settings applied (file-based system)" -ForegroundColor Green
    }
    
    # NEW: Refresh all colors (for compatibility)
    [void] RefreshAllColors() {
        $this.RefreshAllComponents()
    }
}

#endregion
#<!-- END_PAGE: ASE.003 -->
