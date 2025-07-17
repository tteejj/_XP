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
    
    # Theme Schema Registry - standardized key mappings
    hidden [hashtable]$_validThemeKeys = @{
        # Core Palette (lowercase with dots)
        "palette.primary" = @{ Path = "Palette.Primary"; Fallback = "#00D4FF" }
        "palette.secondary" = @{ Path = "Palette.Secondary"; Fallback = "#FF6B35" }
        "palette.accent" = @{ Path = "Palette.Accent"; Fallback = "#7C3AED" }
        "palette.background" = @{ Path = "Palette.Background"; Fallback = "#0A0A0A" }
        "palette.surface" = @{ Path = "Palette.Surface"; Fallback = "#1A1A1A" }
        "palette.text" = @{ Path = "Palette.TextPrimary"; Fallback = "#FFFFFF" }
        "palette.text.secondary" = @{ Path = "Palette.TextSecondary"; Fallback = "#B3B3B3" }
        "palette.text.disabled" = @{ Path = "Palette.TextDisabled"; Fallback = "#666666" }
        "palette.muted" = @{ Path = "Palette.TextSecondary"; Fallback = "#6B7280" }
        "palette.success" = @{ Path = "Palette.Success"; Fallback = "#10B981" }
        "palette.warning" = @{ Path = "Palette.Warning"; Fallback = "#F59E0B" }
        "palette.error" = @{ Path = "Palette.Error"; Fallback = "#EF4444" }
        "palette.info" = @{ Path = "Palette.Info"; Fallback = "#3B82F6" }
        "palette.border" = @{ Path = "Palette.Border"; Fallback = "#374151" }
        
        # Screen Components
        "screen.background" = @{ Path = "Components.Screen.Background"; Fallback = "#0A0A0A" }
        "screen.foreground" = @{ Path = "Components.Screen.Foreground"; Fallback = "#FFFFFF" }
        
        # Panel Components  
        "panel.background" = @{ Path = "Components.Panel.Background"; Fallback = "#1A1A1A" }
        "panel.border" = @{ Path = "Components.Panel.Border"; Fallback = "#007ACC" }
        "panel.border.focused" = @{ Path = "Components.Panel.FocusedBorder"; Fallback = "#00D4FF" }
        "panel.title" = @{ Path = "Components.Panel.Title"; Fallback = "#00D4FF" }
        "panel.header" = @{ Path = "Components.Panel.Header"; Fallback = "#1A1A1A" }
        "panel.foreground" = @{ Path = "Components.Panel.Foreground"; Fallback = "#FFFFFF" }
        
        # Button Components
        "button.normal.background" = @{ Path = "Components.Button.Normal.Background"; Fallback = "#374151" }
        "button.normal.foreground" = @{ Path = "Components.Button.Normal.Foreground"; Fallback = "#FFFFFF" }
        "button.focused.background" = @{ Path = "Components.Button.Focused.Background"; Fallback = "#00D4FF" }
        "button.focused.foreground" = @{ Path = "Components.Button.Focused.Foreground"; Fallback = "#000000" }
        "button.focused.border" = @{ Path = "Components.Button.Focused.Border"; Fallback = "#00FF88" }
        "button.border" = @{ Path = "Components.Button.Border"; Fallback = "#666666" }
        "button.pressed.background" = @{ Path = "Components.Button.Pressed.Background"; Fallback = "#FF6B35" }
        "button.pressed.foreground" = @{ Path = "Components.Button.Pressed.Foreground"; Fallback = "#000000" }
        "button.disabled.background" = @{ Path = "Components.Button.Disabled.Background"; Fallback = "#1A1A1A" }
        "button.disabled.foreground" = @{ Path = "Components.Button.Disabled.Foreground"; Fallback = "#666666" }
        
        # Input Components
        "input.background" = @{ Path = "Components.Input.Background"; Fallback = "#1F2937" }
        "input.foreground" = @{ Path = "Components.Input.Foreground"; Fallback = "#FFFFFF" }
        "input.border" = @{ Path = "Components.Input.Border"; Fallback = "#374151" }
        "input.focused.border" = @{ Path = "Components.Input.FocusedBorder"; Fallback = "#00D4FF" }
        "input.placeholder" = @{ Path = "Components.Input.Placeholder"; Fallback = "#6B7280" }
        
        # List Components
        "list.background" = @{ Path = "Components.List.Background"; Fallback = "#1F2937" }
        "list.foreground" = @{ Path = "Components.List.ItemNormal"; Fallback = "#FFFFFF" }
        "list.selected.background" = @{ Path = "Components.List.ItemSelectedBackground"; Fallback = "#00D4FF" }
        "list.selected.foreground" = @{ Path = "Components.List.ItemSelected"; Fallback = "#000000" }
        "list.focused.background" = @{ Path = "Components.List.ItemFocusedBackground"; Fallback = "#7C3AED" }
        "list.focused.foreground" = @{ Path = "Components.List.ItemFocused"; Fallback = "#000000" }
        "list.header.background" = @{ Path = "Components.List.HeaderBackground"; Fallback = "#1A1A1A" }
        "list.header.foreground" = @{ Path = "Components.List.HeaderForeground"; Fallback = "#00D4FF" }
        "list.scrollbar" = @{ Path = "Components.List.Scrollbar"; Fallback = "#FF6B35" }
        
        # Label Components
        "label.foreground" = @{ Path = "Components.Label.Foreground"; Fallback = "#FFFFFF" }
        "label.disabled" = @{ Path = "Components.Label.Disabled"; Fallback = "#666666" }
        "label.muted" = @{ Path = "Components.Label.Disabled"; Fallback = "#6B7280" }
        
        # Dialog Components
        "dialog.background" = @{ Path = "Components.Overlay.DialogBackground"; Fallback = "#1A1A1A" }
        "dialog.border" = @{ Path = "Components.Panel.Border"; Fallback = "#7C3AED" }
        "overlay.background" = @{ Path = "Components.Overlay.Background"; Fallback = "#000000" }
        
        # Status Components
        "status.success" = @{ Path = "Components.Status.Success"; Fallback = "#10B981" }
        "status.warning" = @{ Path = "Components.Status.Warning"; Fallback = "#F59E0B" }
        "status.error" = @{ Path = "Components.Status.Error"; Fallback = "#EF4444" }
        "status.info" = @{ Path = "Components.Status.Info"; Fallback = "#3B82F6" }
        
        # Legacy/Common Mappings for backwards compatibility
        "foreground" = @{ Path = "Palette.TextPrimary"; Fallback = "#FFFFFF" }
        "background" = @{ Path = "Palette.Background"; Fallback = "#0A0A0A" }
        "border" = @{ Path = "Palette.Border"; Fallback = "#374151" }
        "component.border" = @{ Path = "Components.Panel.Border"; Fallback = "#374151" }
        "component.text" = @{ Path = "Components.Label.Foreground"; Fallback = "#FFFFFF" }
        "text.muted" = @{ Path = "Components.Label.Disabled"; Fallback = "#6B7280" }
        "primary.accent" = @{ Path = "Palette.Primary"; Fallback = "#00D4FF" }
        "accent.secondary" = @{ Path = "Palette.Secondary"; Fallback = "#FF6B35" }
        
        # ListBox aliases (for backwards compatibility)
        "listbox.selectedbackground" = @{ Path = "Components.List.ItemSelectedBackground"; Fallback = "#00D4FF" }
        "listbox.selectedforeground" = @{ Path = "Components.List.ItemSelected"; Fallback = "#000000" }
        "listbox.focusedselectedbackground" = @{ Path = "Components.List.ItemFocusedBackground"; Fallback = "#7C3AED" }
        
        # ===== SEMANTIC STYLE KEYS (Dynamic Styling) =====
        # Task-related semantic styles
        "task.status.pending.foreground" = @{ Path = "Semantic.Task.Status.Pending.Foreground"; Fallback = "#F59E0B" }
        "task.status.pending.background" = @{ Path = "Semantic.Task.Status.Pending.Background"; Fallback = "#1A1A1A" }
        "task.status.inprogress.foreground" = @{ Path = "Semantic.Task.Status.InProgress.Foreground"; Fallback = "#3B82F6" }
        "task.status.inprogress.background" = @{ Path = "Semantic.Task.Status.InProgress.Background"; Fallback = "#1A1A1A" }
        "task.status.completed.foreground" = @{ Path = "Semantic.Task.Status.Completed.Foreground"; Fallback = "#10B981" }
        "task.status.completed.background" = @{ Path = "Semantic.Task.Status.Completed.Background"; Fallback = "#1A1A1A" }
        "task.status.cancelled.foreground" = @{ Path = "Semantic.Task.Status.Cancelled.Foreground"; Fallback = "#EF4444" }
        "task.status.cancelled.background" = @{ Path = "Semantic.Task.Status.Cancelled.Background"; Fallback = "#1A1A1A" }
        
        # Task priority semantic styles
        "task.priority.high.foreground" = @{ Path = "Semantic.Task.Priority.High.Foreground"; Fallback = "#EF4444" }
        "task.priority.high.background" = @{ Path = "Semantic.Task.Priority.High.Background"; Fallback = "#1A1A1A" }
        "task.priority.medium.foreground" = @{ Path = "Semantic.Task.Priority.Medium.Foreground"; Fallback = "#F59E0B" }
        "task.priority.medium.background" = @{ Path = "Semantic.Task.Priority.Medium.Background"; Fallback = "#1A1A1A" }
        "task.priority.low.foreground" = @{ Path = "Semantic.Task.Priority.Low.Foreground"; Fallback = "#6B7280" }
        "task.priority.low.background" = @{ Path = "Semantic.Task.Priority.Low.Background"; Fallback = "#1A1A1A" }
        
        # Task title semantic styles
        "task.title.normal.foreground" = @{ Path = "Semantic.Task.Title.Normal.Foreground"; Fallback = "#FFFFFF" }
        "task.title.normal.background" = @{ Path = "Semantic.Task.Title.Normal.Background"; Fallback = "#1A1A1A" }
        "task.title.overdue.foreground" = @{ Path = "Semantic.Task.Title.Overdue.Foreground"; Fallback = "#EF4444" }
        "task.title.overdue.background" = @{ Path = "Semantic.Task.Title.Overdue.Background"; Fallback = "#1A1A1A" }
        
        # Task progress semantic styles
        "task.progress.complete.foreground" = @{ Path = "Semantic.Task.Progress.Complete.Foreground"; Fallback = "#10B981" }
        "task.progress.complete.background" = @{ Path = "Semantic.Task.Progress.Complete.Background"; Fallback = "#1A1A1A" }
        "task.progress.high.foreground" = @{ Path = "Semantic.Task.Progress.High.Foreground"; Fallback = "#3B82F6" }
        "task.progress.high.background" = @{ Path = "Semantic.Task.Progress.High.Background"; Fallback = "#1A1A1A" }
        "task.progress.medium.foreground" = @{ Path = "Semantic.Task.Progress.Medium.Foreground"; Fallback = "#F59E0B" }
        "task.progress.medium.background" = @{ Path = "Semantic.Task.Progress.Medium.Background"; Fallback = "#1A1A1A" }
        "task.progress.low.foreground" = @{ Path = "Semantic.Task.Progress.Low.Foreground"; Fallback = "#EF4444" }
        "task.progress.low.background" = @{ Path = "Semantic.Task.Progress.Low.Background"; Fallback = "#1A1A1A" }
        
        # Project-related semantic styles
        "project.key.normal.foreground" = @{ Path = "Semantic.Project.Key.Normal.Foreground"; Fallback = "#00D4FF" }
        "project.key.normal.background" = @{ Path = "Semantic.Project.Key.Normal.Background"; Fallback = "#1A1A1A" }
        "project.name.normal.foreground" = @{ Path = "Semantic.Project.Name.Normal.Foreground"; Fallback = "#FFFFFF" }
        "project.name.normal.background" = @{ Path = "Semantic.Project.Name.Normal.Background"; Fallback = "#1A1A1A" }
        "project.name.overdue.foreground" = @{ Path = "Semantic.Project.Name.Overdue.Foreground"; Fallback = "#EF4444" }
        "project.name.overdue.background" = @{ Path = "Semantic.Project.Name.Overdue.Background"; Fallback = "#1A1A1A" }
        "project.name.inactive.foreground" = @{ Path = "Semantic.Project.Name.Inactive.Foreground"; Fallback = "#6B7280" }
        "project.name.inactive.background" = @{ Path = "Semantic.Project.Name.Inactive.Background"; Fallback = "#1A1A1A" }
        "project.status.active.foreground" = @{ Path = "Semantic.Project.Status.Active.Foreground"; Fallback = "#10B981" }
        "project.status.active.background" = @{ Path = "Semantic.Project.Status.Active.Background"; Fallback = "#1A1A1A" }
        "project.status.inactive.foreground" = @{ Path = "Semantic.Project.Status.Inactive.Foreground"; Fallback = "#6B7280" }
        "project.status.inactive.background" = @{ Path = "Semantic.Project.Status.Inactive.Background"; Fallback = "#1A1A1A" }
        "project.owner.assigned.foreground" = @{ Path = "Semantic.Project.Owner.Assigned.Foreground"; Fallback = "#FFFFFF" }
        "project.owner.assigned.background" = @{ Path = "Semantic.Project.Owner.Assigned.Background"; Fallback = "#1A1A1A" }
        "project.owner.unassigned.foreground" = @{ Path = "Semantic.Project.Owner.Unassigned.Foreground"; Fallback = "#6B7280" }
        "project.owner.unassigned.background" = @{ Path = "Semantic.Project.Owner.Unassigned.Background"; Fallback = "#1A1A1A" }
        
        # DataGrid semantic styles
        "datagrid.cell.normal.foreground" = @{ Path = "Semantic.DataGrid.Cell.Normal.Foreground"; Fallback = "#FFFFFF" }
        "datagrid.cell.normal.background" = @{ Path = "Semantic.DataGrid.Cell.Normal.Background"; Fallback = "#1A1A1A" }
    }
    
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
                    Panel = @{ Background = '$Palette.Background'; Border = '$Palette.Border'; Title = '$Palette.Primary'; Header = '$Palette.Surface'; Foreground = '$Palette.TextPrimary' }
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
    
    # CRITICAL FIX: LoadTheme now properly updates all existing UI components
    [void] LoadTheme([string]$themeName) {
        if ($this.Themes.ContainsKey($themeName)) {
            Write-Host "ThemeManager: Loading theme '$themeName'" -ForegroundColor Yellow
            
            $this.CurrentTheme = $this.Themes[$themeName].Clone()
            $this.ThemeName = $themeName
            
            # PERFORMANCE FIX: Clear theme cache on theme changes
            if (Get-Command 'Clear-ThemeCache' -ErrorAction SilentlyContinue) {
                Clear-ThemeCache
            }
            
            # CRITICAL: Update all existing UI components with new theme colors
            $this.RefreshAllComponents()
            
            # PERFORMANCE: Pre-warm cache for Performance theme
            if ($themeName -eq "Performance" -and (Get-Command 'Initialize-PerformanceThemeCache' -ErrorAction SilentlyContinue)) {
                Initialize-PerformanceThemeCache
            }
            
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
        
        # PERFORMANCE FIX: Update cached colors AND trigger redraws
        $this.UpdateComponentThemeRecursive($global:TuiState.CurrentScreen)
        
        # Also update any overlays or dialogs
        if ($global:TuiState.PSObject.Properties['OverlayStack']) {
            foreach ($overlay in $global:TuiState.OverlayStack) {
                $this.UpdateComponentThemeRecursive($overlay)
            }
        }
        
        # Finally trigger a global redraw
        $this.RequestRedrawRecursive($global:TuiState.CurrentScreen)
    }
    
    # PERFORMANCE FIX: Recursively update component colors (updates cached values)
    hidden [void] UpdateComponentThemeRecursive([object]$component) {
        if (-not $component) { return }
        
        try {
            $componentType = $component.GetType().Name
            
            # PERFORMANCE: If component has ResolveThemeColors method, use it
            if ($component.PSObject.Methods['ResolveThemeColors']) {
                $component.ResolveThemeColors()
            }
            
            # Update component based on its type - this updates CACHED colors
            switch -Regex ($componentType) {
                "Screen" {
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $component.BackgroundColor = $this.GetColor("screen.background")
                    }
                    if ($component.PSObject.Properties['ForegroundColor']) {
                        $component.ForegroundColor = $this.GetColor("screen.foreground")
                    }
                }
                "Panel" {
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $component.BackgroundColor = $this.GetColor("panel.background")
                    }
                    if ($component.PSObject.Properties['BorderColor']) {
                        $component.BorderColor = $this.GetColor("panel.border")
                    }
                    if ($component.PSObject.Properties['TitleColor']) {
                        $component.TitleColor = $this.GetColor("panel.title")
                    }
                }
                ".*Label.*|LabelComponent" {
                    if ($component.PSObject.Properties['ForegroundColor']) {
                        $component.ForegroundColor = $this.GetColor("label.foreground")
                    }
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $bgColor = $this.GetColor("panel.background")
                        if ($bgColor) {
                            $component.BackgroundColor = $bgColor
                        }
                    }
                }
                ".*Button.*|ButtonComponent" {
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $component.BackgroundColor = $this.GetColor("button.normal.background")
                    }
                    if ($component.PSObject.Properties['ForegroundColor']) {
                        $component.ForegroundColor = $this.GetColor("button.normal.foreground")
                    }
                    if ($component.PSObject.Properties['BorderColor']) {
                        $component.BorderColor = $this.GetColor("button.border")
                    }
                }
                ".*List.*|ListBox" {
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $component.BackgroundColor = $this.GetColor("list.background")
                    }
                    if ($component.PSObject.Properties['ForegroundColor']) {
                        $component.ForegroundColor = $this.GetColor("list.foreground")
                    }
                    if ($component.PSObject.Properties['BorderColor']) {
                        $component.BorderColor = $this.GetColor("input.border")
                    }
                }
                ".*TextBox.*|.*Input.*" {
                    if ($component.PSObject.Properties['BackgroundColor']) {
                        $component.BackgroundColor = $this.GetColor("input.background")
                    }
                    if ($component.PSObject.Properties['ForegroundColor']) {
                        $component.ForegroundColor = $this.GetColor("input.foreground")
                    }
                    if ($component.PSObject.Properties['BorderColor']) {
                        $component.BorderColor = $this.GetColor("input.border")
                    }
                }
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

    # NEW: Recursively request redraw on all components (for theme updates)
    hidden [void] RequestRedrawRecursive([object]$component) {
        if (-not $component) { return }
        
        try {
            # Force the component to redraw with updated theme colors
            if ($component.PSObject.Methods['RequestRedraw']) {
                $component.RequestRedraw()
            }
            
            # Recursively redraw all children
            if ($component.PSObject.Properties['Children']) {
                foreach ($child in $component.Children) {
                    $this.RequestRedrawRecursive($child)
                }
            }
        }
        catch {
            # Silently ignore errors for components that don't support redraw
        }
    }
    
    [void] LoadDefaultTheme() {
        $availableThemes = $this.GetAvailableThemes()
        if ($availableThemes.Count -gt 0) {
            # PERFORMANCE: Load Performance theme as default for optimal speed
            $preferredOrder = @("Performance", "Default", "Retro Amber", "Synthwave", "Green Console", "Fallback")
            $themeToLoad = "Fallback"  # Default fallback
            
            foreach ($preferred in $preferredOrder) {
                if ($preferred -in $availableThemes) {
                    $themeToLoad = $preferred
                    break
                }
            }
            
            Write-Host "ThemeManager: Loading default theme '$themeToLoad'" -ForegroundColor Green
            $this.LoadTheme($themeToLoad)
        }
    }
    
    # Get any theme value (not just colors)
    [string] GetThemeValue([string]$path) {
        return $this.GetThemeValue($path, "#FFFFFF")
    }
    
    [string] GetThemeValue([string]$path, [string]$defaultValue) {
        # Handle direct palette access (e.g., "Palette.TextPrimary")
        if ($path.StartsWith("Palette.")) {
            $paletteKey = $path.Substring(8) # Remove "Palette." prefix
            if ($this.CurrentTheme.Palette.ContainsKey($paletteKey)) {
                return $this.CurrentTheme.Palette[$paletteKey]
            }
            return $defaultValue
        }
        
        # Handle Components.X.Y paths by removing the Components prefix
        if ($path.StartsWith("Components.")) {
            $path = $path.Substring(11) # Remove "Components." prefix
        }
        
        # Split the path (e.g., "Panel.Background" -> ["Panel", "Background"])
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
        # First check if it's a registered theme key (like "foreground" -> "Palette.TextPrimary")
        $keyInfo = $this.GetThemeKeyInfo($colorPath)
        if ($keyInfo) {
            $actualPath = $keyInfo.Path
            $color = $this.GetThemeValue($actualPath, $defaultColor)
            return $color
        }
        
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
    
    # PUBLIC: Check if theme key is valid and get its mapping info
    [hashtable] GetThemeKeyInfo([string]$key) {
        $keyLower = $key.ToLower()
        if ($this._validThemeKeys.ContainsKey($keyLower)) {
            return $this._validThemeKeys[$keyLower]
        }
        return $null
    }
    
    # PUBLIC: Check if theme key exists in registry
    [bool] IsValidThemeKey([string]$key) {
        $keyLower = $key.ToLower()
        return $this._validThemeKeys.ContainsKey($keyLower)
    }
}

#endregion
#<!-- END_PAGE: ASE.003 -->
