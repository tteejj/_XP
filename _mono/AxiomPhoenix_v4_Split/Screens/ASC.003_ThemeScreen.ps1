# ==============================================================================
# Axiom-Phoenix v4.0 - Theme Selection Screen  
# FIXED: Removed FocusManager dependency, uses direct input handling
# ==============================================================================

class ThemeScreen : Screen {
    # UI Components
    hidden [Panel]$_mainPanel
    hidden [ListBox]$_themeList
    hidden [Panel]$_previewPanel
    hidden [LabelComponent]$_titleLabel
    hidden [LabelComponent]$_descriptionLabel
    hidden [LabelComponent]$_statusLabel
    hidden [LabelComponent]$_previewTextLabel
    hidden [LabelComponent]$_previewButtonLabel
    hidden [LabelComponent]$_previewListLabel
    
    # State
    hidden [int]$_selectedIndex = 0
    hidden [string]$_originalTheme
    
    # Available themes with hex colors
    hidden [hashtable[]]$_themes = @(
        @{
            Name = "Default"
            Description = "Classic terminal colors with blue accents"
            Colors = @{
                "Background" = "#000000"
                "Foreground" = "#C0C0C0"
                "Primary" = "#0000FF"
                "Secondary" = "#000080"
                "Accent" = "#00FFFF"
                "Success" = "#00FF00"
                "Warning" = "#FFFF00"
                "Error" = "#FF0000"
                "Info" = "#00FFFF"
                "component.background" = "#000000"
                "component.border" = "#808080"
                "component.title" = "#00FFFF"
                "button.focused.fg" = "#FFFFFF"
                "button.focused.bg" = "#0000FF"
                "list.item.selected" = "#FFFFFF"
                "list.item.selected.background" = "#000080"
            }
        }
        @{
            Name = "Green Console"
            Description = "Classic green phosphor terminal look"
            Colors = @{
                "Background" = "#000000"
                "Foreground" = "#00FF00"
                "Primary" = "#00FF00"
                "Secondary" = "#008000"
                "Accent" = "#00FF00"
                "Success" = "#00FF00"
                "Warning" = "#FFFF00"
                "Error" = "#FF0000"
                "Info" = "#00FF00"
                "component.background" = "#000000"
                "component.border" = "#008000"
                "component.title" = "#00FF00"
                "button.focused.fg" = "#000000"
                "button.focused.bg" = "#00FF00"
                "list.item.selected" = "#000000"
                "list.item.selected.background" = "#00FF00"
            }
        }
        @{
            Name = "Amber Console"
            Description = "Warm amber monochrome terminal"
            Colors = @{
                "Background" = "#000000"
                "Foreground" = "#FFFF00"
                "Primary" = "#FFFF00"
                "Secondary" = "#808000"
                "Accent" = "#FFFF00"
                "Success" = "#00FF00"
                "Warning" = "#FFFF00"
                "Error" = "#FF0000"
                "Info" = "#FFFF00"
                "component.background" = "#000000"
                "component.border" = "#808000"
                "component.title" = "#FFFF00"
                "button.focused.fg" = "#000000"
                "button.focused.bg" = "#FFFF00"
                "list.item.selected" = "#000000"
                "list.item.selected.background" = "#FFFF00"
            }
        }
        @{
            Name = "Notepad Style"
            Description = "Clean white background with black text"
            Colors = @{
                "Background" = "#FFFFFF"
                "Foreground" = "#000000"
                "Primary" = "#000080"
                "Secondary" = "#C0C0C0"
                "Accent" = "#0000FF"
                "Success" = "#008000"
                "Warning" = "#808000"
                "Error" = "#800000"
                "Info" = "#008080"
                "component.background" = "#FFFFFF"
                "component.border" = "#808080"
                "component.title" = "#000080"
                "button.focused.fg" = "#000000"
                "button.focused.bg" = "#000080"
                "list.item.selected" = "#000080"
                "list.item.selected.background" = "#FFFFFF"
            }
        }
        @{
            Name = "Synthwave"
            Description = "Retro 80s neon colors"
            Colors = @{
                "Background" = "#0A0A0A"
                "Foreground" = "#FF00FF"
                "Primary" = "#FF00FF"
                "Secondary" = "#00FFFF"
                "Accent" = "#FF00FF"
                "Success" = "#00FF88"
                "Warning" = "#FFD700"
                "Error" = "#FF0066"
                "Info" = "#00D4FF"
                "component.background" = "#1A0A1A"
                "component.border" = "#FF00FF"
                "component.title" = "#00FFFF"
                "button.focused.fg" = "#000000"
                "button.focused.bg" = "#FF00FF"
                "list.item.selected" = "#000000"
                "list.item.selected.background" = "#FF00FF"
            }
        }
        @{
            Name = "HackerVision"
            Description = "Dark theme with bright green accents"
            Colors = @{
                "Background" = "#0A0A0A"
                "Foreground" = "#00FF00"
                "Primary" = "#00FF00"
                "Secondary" = "#00CC00"
                "Accent" = "#00FF00"
                "Success" = "#00FF00"
                "Warning" = "#FFD700"
                "Error" = "#FF0000"
                "Info" = "#00D4FF"
                "component.background" = "#0A0A0A"
                "component.border" = "#00FF00"
                "component.title" = "#00FF00"
                "button.focused.fg" = "#000000"
                "button.focused.bg" = "#00FF00"
                "list.item.selected" = "#000000"
                "list.item.selected.background" = "#00FF00"
            }
        }
    )
    
    ThemeScreen([object]$serviceContainer) : base("ThemeScreen", $serviceContainer) {
        Write-Log -Level Debug -Message "ThemeScreen: Constructor called"
    }
    
    [void] Initialize() {
        Write-Log -Level Debug -Message "ThemeScreen.Initialize: Starting"
        
        # Store current theme to restore on cancel
        $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
        if ($themeManager) {
            $this._originalTheme = $themeManager.ThemeName
        }
        
        # Main panel
        $this._mainPanel = [Panel]::new("ThemeMain")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Theme Selection "
        $this._mainPanel.BorderStyle = "Double"
        $this.AddChild($this._mainPanel)
        
        # Title
        $this._titleLabel = [LabelComponent]::new("Title")
        $this._titleLabel.X = 2
        $this._titleLabel.Y = 1
        $this._titleLabel.Text = "Select a theme for your terminal experience"
        $this._titleLabel.ForegroundColor = Get-ThemeColor "Primary"
        $this._mainPanel.AddChild($this._titleLabel)
        
        # List panel (left side)
        $listWidth = [Math]::Floor($this.Width * 0.3)
        $listPanel = [Panel]::new("ListPanel")
        $listPanel.X = 2
        $listPanel.Y = 3
        $listPanel.Width = $listWidth
        $listPanel.Height = $this.Height - 8
        $listPanel.Title = " Themes "
        $listPanel.BorderStyle = "Single"
        $this._mainPanel.AddChild($listPanel)
        
        # Theme list
        $this._themeList = [ListBox]::new("ThemeList")
        $this._themeList.X = 1
        $this._themeList.Y = 1
        $this._themeList.Width = $listPanel.Width - 2
        $this._themeList.Height = $listPanel.Height - 2
        $this._themeList.HasBorder = $false
        $this._themeList.IsFocusable = $false  # We handle input directly
        $listPanel.AddChild($this._themeList)
        
        # Preview panel (right side)
        $this._previewPanel = [Panel]::new("PreviewPanel")
        $this._previewPanel.X = $listWidth + 4
        $this._previewPanel.Y = 3
        $this._previewPanel.Width = $this.Width - $listWidth - 8
        $this._previewPanel.Height = $this.Height - 8
        $this._previewPanel.Title = " Preview "
        $this._previewPanel.BorderStyle = "Single"
        $this._mainPanel.AddChild($this._previewPanel)
        
        # Description label
        $this._descriptionLabel = [LabelComponent]::new("Description")
        $this._descriptionLabel.X = 2
        $this._descriptionLabel.Y = 1
        $this._descriptionLabel.Text = ""
        $this._previewPanel.AddChild($this._descriptionLabel)
        
        # Preview elements
        $previewY = 3
        
        $this._previewTextLabel = [LabelComponent]::new("PreviewText")
        $this._previewTextLabel.X = 2
        $this._previewTextLabel.Y = $previewY
        $this._previewTextLabel.Text = "This is sample text in the selected theme"
        $this._previewPanel.AddChild($this._previewTextLabel)
        
        $previewY += 2
        
        $this._previewButtonLabel = [LabelComponent]::new("PreviewButton")
        $this._previewButtonLabel.X = 2
        $this._previewButtonLabel.Y = $previewY
        $this._previewButtonLabel.Text = " [Sample Button] "
        $this._previewPanel.AddChild($this._previewButtonLabel)
        
        $previewY += 2
        
        $this._previewListLabel = [LabelComponent]::new("PreviewList")
        $this._previewListLabel.X = 2
        $this._previewListLabel.Y = $previewY
        $this._previewListLabel.Text = "> Selected List Item"
        $this._previewPanel.AddChild($this._previewListLabel)
        
        # Status bar
        $this._statusLabel = [LabelComponent]::new("Status")
        $this._statusLabel.X = 2
        $this._statusLabel.Y = $this.Height - 3
        $this._statusLabel.Text = "↑↓ Navigate | Enter: Apply | P: Preview | Esc: Cancel"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "Muted"
        $this._mainPanel.AddChild($this._statusLabel)
        
        # Populate theme list
        $this.PopulateThemeList()
    }
    
    hidden [void] PopulateThemeList() {
        $this._themeList.ClearItems()
        foreach ($theme in $this._themes) {
            $this._themeList.AddItem($theme.Name)
        }
        
        # Find current theme
        $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
        if ($themeManager) {
            for ($i = 0; $i -lt $this._themes.Count; $i++) {
                if ($this._themes[$i].Name -eq $themeManager.ThemeName) {
                    $this._selectedIndex = $i
                    break
                }
            }
        }
        
        $this._themeList.SelectedIndex = $this._selectedIndex
        $this.UpdatePreview()
    }
    
    hidden [void] UpdatePreview() {
        if ($this._selectedIndex -ge 0 -and $this._selectedIndex -lt $this._themes.Count) {
            $selectedTheme = $this._themes[$this._selectedIndex]
            
            # Update description
            $this._descriptionLabel.Text = $selectedTheme.Description
            $this._descriptionLabel.ForegroundColor = $selectedTheme.Colors["Foreground"]
            
            # Update preview elements with theme colors
            $this._previewTextLabel.ForegroundColor = $selectedTheme.Colors["Foreground"]
            
            $this._previewButtonLabel.BackgroundColor = $selectedTheme.Colors["Primary"]
            $this._previewButtonLabel.ForegroundColor = $selectedTheme.Colors["button.focused.fg"]
            
            $this._previewListLabel.BackgroundColor = $selectedTheme.Colors["list.item.selected.background"]
            $this._previewListLabel.ForegroundColor = $selectedTheme.Colors["list.item.selected"]
            
            # Update panel colors
            $this._previewPanel.BackgroundColor = $selectedTheme.Colors["component.background"]
            $this._previewPanel.BorderColor = $selectedTheme.Colors["component.border"]
            
            $this.RequestRedraw()
        }
    }
    
    hidden [void] ApplyTheme() {
        if ($this._selectedIndex -ge 0 -and $this._selectedIndex -lt $this._themes.Count) {
            $selectedTheme = $this._themes[$this._selectedIndex]
            $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
            
            if ($themeManager) {
                # Apply the theme colors
                foreach ($kvp in $selectedTheme.Colors.GetEnumerator()) {
                    $themeManager.SetColor($kvp.Key, $kvp.Value)
                }
                
                $themeManager.ThemeName = $selectedTheme.Name
                
                # Notify about theme change
                $eventManager = $this.ServiceContainer?.GetService("EventManager")
                if ($eventManager) {
                    $eventManager.Publish("Theme.Changed", @{ Theme = $selectedTheme.Name })
                }
                
                Write-Log -Level Info -Message "Applied theme: $($selectedTheme.Name)"
            }
        }
    }
    
    hidden [void] PreviewTheme() {
        # Temporarily apply theme without saving
        if ($this._selectedIndex -ge 0 -and $this._selectedIndex -lt $this._themes.Count) {
            $selectedTheme = $this._themes[$this._selectedIndex]
            $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
            
            if ($themeManager) {
                foreach ($kvp in $selectedTheme.Colors.GetEnumerator()) {
                    $themeManager.SetColor($kvp.Key, $kvp.Value)
                }
                
                # Request full screen redraw
                $eventManager = $this.ServiceContainer?.GetService("EventManager")
                if ($eventManager) {
                    $eventManager.Publish("Theme.Preview", @{ Theme = $selectedTheme.Name })
                }
            }
        }
    }
    
    [void] OnEnter() {
        Write-Log -Level Debug -Message "ThemeScreen.OnEnter: Starting"
        
        # Don't use FocusManager - we handle input directly
        $this.RequestRedraw()
    }
    
    # === INPUT HANDLING (DIRECT, NO FOCUS MANAGER) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "ThemeScreen.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "ThemeScreen.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)'"
        
        $handled = $false
        
        # Navigation keys
        switch ($keyInfo.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this._selectedIndex -gt 0) {
                    $this._selectedIndex--
                    $this._themeList.SelectedIndex = $this._selectedIndex
                    $this.UpdatePreview()
                }
                $handled = $true
            }
            ([ConsoleKey]::DownArrow) {
                if ($this._selectedIndex -lt $this._themes.Count - 1) {
                    $this._selectedIndex++
                    $this._themeList.SelectedIndex = $this._selectedIndex
                    $this.UpdatePreview()
                }
                $handled = $true
            }
            ([ConsoleKey]::Enter) {
                $this.ApplyTheme()
                # Go back after applying
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
                $handled = $true
            }
            ([ConsoleKey]::Escape) {
                # Restore original theme and go back
                $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
                if ($themeManager -and $this._originalTheme) {
                    # Find and apply original theme
                    foreach ($theme in $this._themes) {
                        if ($theme.Name -eq $this._originalTheme) {
                            foreach ($kvp in $theme.Colors.GetEnumerator()) {
                                $themeManager.SetColor($kvp.Key, $kvp.Value)
                            }
                            break
                        }
                    }
                }
                
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
                $handled = $true
            }
            ([ConsoleKey]::Home) {
                $this._selectedIndex = 0
                $this._themeList.SelectedIndex = $this._selectedIndex
                $this.UpdatePreview()
                $handled = $true
            }
            ([ConsoleKey]::End) {
                $this._selectedIndex = $this._themes.Count - 1
                $this._themeList.SelectedIndex = $this._selectedIndex
                $this.UpdatePreview()
                $handled = $true
            }
        }
        
        # Character shortcuts
        if (-not $handled) {
            switch ($keyInfo.KeyChar) {
                'p' {
                    if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                        $this.PreviewTheme()
                        $handled = $true
                    }
                }
                'P' {
                    $this.PreviewTheme()
                    $handled = $true
                }
            }
        }
        
        Write-Log -Level Debug -Message "ThemeScreen.HandleInput: Returning handled=$handled"
        return $handled
    }
}

# ==============================================================================
# END OF THEME SCREEN
# ==============================================================================
