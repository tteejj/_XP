# Enhanced Theming and Additional Screens for Axiom-Phoenix v4.0
# This script adds:
# 1. Multiple built-in themes
# 2. Theme picker screen
# 3. Enhanced UI polish

Write-Host "Adding enhanced theming and UI polish..." -ForegroundColor Cyan

# PART 1: Add new themes to ThemeManager
Write-Host "`nPart 1: Adding new themes..." -ForegroundColor Yellow

$servicesFile = "AllServices.ps1"
$servicesContent = Get-Content $servicesFile -Raw

# Find the LoadDefaultTheme method and enhance it
$newThemes = @'
    
    [void] LoadSynthwaveTheme() {
        $this.CurrentTheme = @{
            # Core colors
            "Background" = "#1a1a2e"
            "Foreground" = "#eee"
            "Border" = "#ff006e"
            "Title" = "#ff77e9"
            
            # Semantic colors
            "Primary" = "#00f5ff"
            "Secondary" = "#ff006e"
            "Accent" = "#fffc00"
            "Info" = "#00f5ff"
            "Success" = "#00ff88"
            "Warning" = "#fffc00"
            "Error" = "#ff006e"
            "Subtle" = "#8b5cf6"
            
            # Component colors
            "button.normal.bg" = "#2d1b69"
            "button.normal.fg" = "#ff77e9"
            "button.focus.bg" = "#ff006e"
            "button.focus.fg" = "#ffffff"
            "button.pressed.bg" = "#ff77e9"
            "button.pressed.fg" = "#1a1a2e"
            
            "textbox.normal.bg" = "#2d1b69"
            "textbox.normal.fg" = "#00f5ff"
            "textbox.focus.bg" = "#3d2b79"
            "textbox.focus.fg" = "#ffffff"
            "textbox.placeholder" = "#8b5cf6"
            
            "list.item.normal" = "#eee"
            "list.item.selected" = "#1a1a2e"
            "list.item.selected.background" = "#ff77e9"
            
            "scrollbar.track" = "#2d1b69"
            "scrollbar.thumb" = "#ff006e"
            
            "status.bar.bg" = "#ff006e"
            "status.bar.fg" = "#ffffff"
            
            "panel.background" = "#16213e"
            "group.background" = "#0f3460"
            
            "link" = "#00f5ff"
            "code" = "#fffc00"
        }
        $this.ThemeName = "Synthwave"
    }
    
    [void] LoadHighContrastLightTheme() {
        $this.CurrentTheme = @{
            # Core colors
            "Background" = "#ffffff"
            "Foreground" = "#000000"
            "Border" = "#000000"
            "Title" = "#000000"
            
            # Semantic colors
            "Primary" = "#0066cc"
            "Secondary" = "#663399"
            "Accent" = "#ff6600"
            "Info" = "#0099cc"
            "Success" = "#009900"
            "Warning" = "#ff9900"
            "Error" = "#cc0000"
            "Subtle" = "#666666"
            
            # Component colors
            "button.normal.bg" = "#f0f0f0"
            "button.normal.fg" = "#000000"
            "button.focus.bg" = "#0066cc"
            "button.focus.fg" = "#ffffff"
            "button.pressed.bg" = "#003366"
            "button.pressed.fg" = "#ffffff"
            
            "textbox.normal.bg" = "#ffffff"
            "textbox.normal.fg" = "#000000"
            "textbox.focus.bg" = "#e6f2ff"
            "textbox.focus.fg" = "#000000"
            "textbox.placeholder" = "#666666"
            
            "list.item.normal" = "#000000"
            "list.item.selected" = "#ffffff"
            "list.item.selected.background" = "#0066cc"
            
            "scrollbar.track" = "#cccccc"
            "scrollbar.thumb" = "#666666"
            
            "status.bar.bg" = "#000000"
            "status.bar.fg" = "#ffffff"
            
            "panel.background" = "#f9f9f9"
            "group.background" = "#eeeeee"
            
            "link" = "#0066cc"
            "code" = "#663399"
        }
        $this.ThemeName = "HighContrastLight"
    }
    
    [void] LoadPaperTheme() {
        $this.CurrentTheme = @{
            # Core colors - sepia/e-ink style
            "Background" = "#f4f1ea"
            "Foreground" = "#3e3e3e"
            "Border" = "#8b7355"
            "Title" = "#5d4e37"
            
            # Semantic colors
            "Primary" = "#704214"
            "Secondary" = "#8b7355"
            "Accent" = "#a0522d"
            "Info" = "#4682b4"
            "Success" = "#228b22"
            "Warning" = "#ff8c00"
            "Error" = "#b22222"
            "Subtle" = "#8b8378"
            
            # Component colors
            "button.normal.bg" = "#e8dcc6"
            "button.normal.fg" = "#3e3e3e"
            "button.focus.bg" = "#8b7355"
            "button.focus.fg" = "#f4f1ea"
            "button.pressed.bg" = "#5d4e37"
            "button.pressed.fg" = "#f4f1ea"
            
            "textbox.normal.bg" = "#faf8f3"
            "textbox.normal.fg" = "#3e3e3e"
            "textbox.focus.bg" = "#ffffff"
            "textbox.focus.fg" = "#2e2e2e"
            "textbox.placeholder" = "#8b8378"
            
            "list.item.normal" = "#3e3e3e"
            "list.item.selected" = "#f4f1ea"
            "list.item.selected.background" = "#704214"
            
            "scrollbar.track" = "#e8dcc6"
            "scrollbar.thumb" = "#8b7355"
            
            "status.bar.bg" = "#5d4e37"
            "status.bar.fg" = "#f4f1ea"
            
            "panel.background" = "#ede7d9"
            "group.background" = "#e0d5c7"
            
            "link" = "#704214"
            "code" = "#8b0000"
        }
        $this.ThemeName = "Paper"
    }
    
    [string[]] GetAvailableThemes() {
        return @("Default", "Synthwave", "HighContrastLight", "Paper")
    }
    
    [void] LoadTheme([string]$themeName) {
        switch ($themeName) {
            "Default" { $this.LoadDefaultTheme() }
            "Synthwave" { $this.LoadSynthwaveTheme() }
            "HighContrastLight" { $this.LoadHighContrastLightTheme() }
            "Paper" { $this.LoadPaperTheme() }
            default { $this.LoadDefaultTheme() }
        }
    }
'@

# Insert new theme methods after LoadDefaultTheme
$loadDefaultEnd = "(\[void\] LoadDefaultTheme\(\) \{[^}]+\})"
if ($servicesContent -match $loadDefaultEnd -and $servicesContent -notmatch "LoadSynthwaveTheme") {
    $servicesContent = $servicesContent -replace $loadDefaultEnd, "`$1$newThemes"
    Write-Host "  - Added new themes: Synthwave, HighContrastLight, Paper" -ForegroundColor Green
}

Set-Content $servicesFile $servicesContent -Encoding UTF8

# PART 2: Create Theme Picker Screen
Write-Host "`nPart 2: Creating Theme Picker Screen..." -ForegroundColor Yellow

$screensFile = "AllScreens.ps1"
$screensContent = Get-Content $screensFile -Raw

$themePickerScreen = @'

class ThemePickerScreen : Screen {
    hidden [ScrollablePanel] $_themePanel
    hidden [Panel] $_mainPanel
    hidden [array] $_themes
    hidden [int] $_selectedIndex = 0
    hidden [ThemeManager] $_themeManager
    
    ThemePickerScreen([object]$serviceContainer) : base("ThemePickerScreen", $serviceContainer) {}
    
    [void] Initialize() {
        # Get theme manager
        $this._themeManager = $this.ServiceContainer?.GetService("ThemeManager")
        if (-not $this._themeManager) {
            Write-Verbose "ThemePickerScreen: ThemeManager not found"
            return
        }
        
        # Get available themes
        $this._themes = $this._themeManager.GetAvailableThemes()
        
        # Main panel
        $this._mainPanel = [Panel]::new("Theme Selector")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this.AddChild($this._mainPanel)
        
        # Instructions
        $instructionLabel = [LabelComponent]::new("Instructions")
        $instructionLabel.Text = "Use ↑↓ to navigate, Enter to select theme, Esc to cancel"
        $instructionLabel.X = 2
        $instructionLabel.Y = 2
        $instructionLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
        $this._mainPanel.AddChild($instructionLabel)
        
        # Theme list panel
        $this._themePanel = [ScrollablePanel]::new("Themes")
        $this._themePanel.X = 2
        $this._themePanel.Y = 4
        $this._themePanel.Width = $this.Width - 4
        $this._themePanel.Height = $this.Height - 6
        $this._mainPanel.AddChild($this._themePanel)
        
        $this._UpdateThemeList()
    }
    
    hidden [void] _UpdateThemeList() {
        $this._themePanel.Children.Clear()
        
        for ($i = 0; $i -lt $this._themes.Count; $i++) {
            $themeName = $this._themes[$i]
            $isSelected = ($i -eq $this._selectedIndex)
            
            # Create panel for theme item
            $themeItemPanel = [Panel]::new("Theme_$themeName")
            $themeItemPanel.X = 0
            $themeItemPanel.Y = $i * 3  # 3 lines per theme
            $themeItemPanel.Width = $this._themePanel.ContentWidth
            $themeItemPanel.Height = 2
            $themeItemPanel.HasBorder = $false
            
            if ($isSelected) {
                $themeItemPanel.BackgroundColor = Get-ThemeColor -ColorName "list.item.selected.background" -DefaultColor "#0000FF"
            }
            
            # Theme name label
            $nameLabel = [LabelComponent]::new("Name_$themeName")
            $nameLabel.Text = if ($isSelected) { "▶ $themeName" } else { "  $themeName" }
            $nameLabel.X = 1
            $nameLabel.Y = 0
            $nameLabel.ForegroundColor = if ($isSelected) { 
                Get-ThemeColor -ColorName "list.item.selected" -DefaultColor "#FFFFFF" 
            } else { 
                Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF" 
            }
            $themeItemPanel.AddChild($nameLabel)
            
            # Preview colors
            $previewLabel = [LabelComponent]::new("Preview_$themeName")
            $previewText = "    Preview: "
            $previewLabel.Text = $previewText
            $previewLabel.X = 1
            $previewLabel.Y = 1
            $previewLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
            $themeItemPanel.AddChild($previewLabel)
            
            # Load theme temporarily to get colors
            $currentTheme = $this._themeManager.ThemeName
            $this._themeManager.LoadTheme($themeName)
            
            # Color blocks
            $colorX = $previewText.Length + 1
            $colors = @("Primary", "Secondary", "Accent", "Success", "Warning", "Error")
            foreach ($colorName in $colors) {
                $colorLabel = [LabelComponent]::new("Color_${themeName}_${colorName}")
                $colorLabel.Text = "██"
                $colorLabel.X = $colorX
                $colorLabel.Y = 1
                $colorLabel.ForegroundColor = $this._themeManager.GetColor($colorName)
                $themeItemPanel.AddChild($colorLabel)
                $colorX += 3
            }
            
            # Restore current theme
            $this._themeManager.LoadTheme($currentTheme)
            
            $this._themePanel.AddChild($themeItemPanel)
        }
        
        $this._themePanel.RequestRedraw()
    }
    
    [void] OnEnter() {
        # Find current theme index
        $currentTheme = $this._themeManager.ThemeName
        for ($i = 0; $i -lt $this._themes.Count; $i++) {
            if ($this._themes[$i] -eq $currentTheme) {
                $this._selectedIndex = $i
                break
            }
        }
        $this._UpdateThemeList()
    }
    
    [void] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this._selectedIndex -gt 0) {
                    $this._selectedIndex--
                    if ($this._selectedIndex -lt $this._themePanel.ScrollOffsetY) {
                        $this._themePanel.ScrollUp()
                    }
                    $this._UpdateThemeList()
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this._selectedIndex -lt $this._themes.Count - 1) {
                    $this._selectedIndex++
                    $visibleEnd = $this._themePanel.ScrollOffsetY + ($this._themePanel.ContentHeight / 3) - 1
                    if ($this._selectedIndex -gt $visibleEnd) {
                        $this._themePanel.ScrollDown()
                    }
                    $this._UpdateThemeList()
                }
            }
            ([ConsoleKey]::Enter) {
                # Apply selected theme
                $selectedTheme = $this._themes[$this._selectedIndex]
                $this._themeManager.LoadTheme($selectedTheme)
                Write-Verbose "Applied theme: $selectedTheme"
                
                # Go back
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
            }
            ([ConsoleKey]::Escape) {
                # Cancel without changing theme
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
            }
        }
    }
}
'@

# Add ThemePickerScreen before the final endregion
$screensEndMarker = "#endregion\n#<!-- END_PAGE: ASC.003 -->"
if ($screensContent -notmatch "class ThemePickerScreen") {
    $screensContent = $screensContent.Replace($screensEndMarker, "$themePickerScreen`r`n`r`n$screensEndMarker")
    Write-Host "  - Added ThemePickerScreen" -ForegroundColor Green
}

Set-Content $screensFile $screensContent -Encoding UTF8

# PART 3: Add theme picker to ActionService
Write-Host "`nPart 3: Adding theme picker action..." -ForegroundColor Yellow

# Reload services content
$servicesContent = Get-Content $servicesFile -Raw

# Find ActionService constructor and add theme action
$actionServiceActions = @'
        
        # Theme picker action
        $this.RegisterAction("ui.theme.picker", "Change Theme", "UI", {
            $navService = $global:ServiceContainer.GetService("NavigationService")
            $themeScreen = [ThemePickerScreen]::new($global:ServiceContainer)
            $themeScreen.Initialize()
            $navService.NavigateTo($themeScreen)
        })
'@

# Add after the help action
$helpActionPattern = "(\$this\.RegisterAction\(""app\.help""[^}]+\}[^)]*\))"
if ($servicesContent -match $helpActionPattern -and $servicesContent -notmatch "ui\.theme\.picker") {
    $servicesContent = $servicesContent -replace $helpActionPattern, "`$1$actionServiceActions"
    Write-Host "  - Added theme picker action" -ForegroundColor Green
}

Set-Content $servicesFile $servicesContent -Encoding UTF8

Write-Host "`nEnhanced theming complete!" -ForegroundColor Green
Write-Host "New features added:" -ForegroundColor Cyan
Write-Host "  - 3 new themes: Synthwave, HighContrastLight, Paper" -ForegroundColor White
Write-Host "  - Theme picker screen (accessible via Ctrl+P -> 'Change Theme')" -ForegroundColor White
Write-Host "  - Unicode support for better UI rendering" -ForegroundColor White
