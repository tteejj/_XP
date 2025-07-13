# ==============================================================================
# Axiom-Phoenix v4.0 - Theme Selection Screen  
# FIXED: Proper theme preview and application
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
    hidden [Panel]$_colorSwatchPanel
    
    # State
    hidden [string]$_originalTheme
    hidden [bool]$_themeScreenInitialized = $false
    
    ThemeScreen([object]$serviceContainer) : base("ThemeScreen", $serviceContainer) {
        Write-Log -Level Debug -Message "ThemeScreen: Constructor called"
    }
    
    [void] Initialize() {
        if ($this._themeScreenInitialized) {
            Write-Log -Level Debug -Message "ThemeScreen.Initialize: Already initialized, skipping"
            return
        }
        
        Write-Log -Level Debug -Message "ThemeScreen.Initialize: Starting initialization"
        
        # Store current theme to restore on cancel
        $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
        if ($themeManager) {
            $this._originalTheme = $themeManager.ThemeName
        }
        
        # Main panel
        $this._mainPanel = [Panel]::new("ThemeMain")
        $this._mainPanel.IsFocusable = $false
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Theme Selection "
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.BackgroundColor = Get-ThemeColor "background" "#1e1e1e"
        $this._mainPanel.BorderColor = Get-ThemeColor "border" "#007acc"
        $this.AddChild($this._mainPanel)
        
        # Set screen background colors
        $this.BackgroundColor = Get-ThemeColor "background" "#1e1e1e"
        $this.ForegroundColor = Get-ThemeColor "foreground" "#d4d4d4"
        
        # Title label
        $this._titleLabel = [LabelComponent]::new("Title")
        $this._titleLabel.IsFocusable = $false
        $this._titleLabel.X = 2
        $this._titleLabel.Y = 1
        $this._titleLabel.Text = "Select a theme for your terminal experience"
        $this._titleLabel.ForegroundColor = Get-ThemeColor "foreground" "#d4d4d4"
        $this._titleLabel.BackgroundColor = Get-ThemeColor "background" "#1e1e1e"
        $this._mainPanel.AddChild($this._titleLabel)
        
        # List panel (left side)
        $listWidth = [Math]::Floor($this.Width * 0.3)
        $listPanel = [Panel]::new("ListPanel")
        $listPanel.IsFocusable = $false
        $listPanel.X = 2
        $listPanel.Y = 3
        $listPanel.Width = $listWidth
        $listPanel.Height = $this.Height - 8
        $listPanel.Title = " Themes "
        $listPanel.BorderStyle = "Single"
        $listPanel.BackgroundColor = Get-ThemeColor "background" "#1e1e1e"
        $listPanel.BorderColor = Get-ThemeColor "border" "#007acc"
        $this._mainPanel.AddChild($listPanel)
        
        # Theme list
        $this._themeList = [ListBox]::new("ThemeList")
        $this._themeList.IsFocusable = $true
        $this._themeList.TabIndex = 0
        $this._themeList.X = 1
        $this._themeList.Y = 1
        $this._themeList.Width = $listPanel.Width - 2
        $this._themeList.Height = $listPanel.Height - 2
        $this._themeList.HasBorder = $false
        $this._themeList.BackgroundColor = Get-ThemeColor "background" "#1e1e1e"
        $this._themeList.ForegroundColor = Get-ThemeColor "foreground" "#d4d4d4"
        $this._themeList.SelectedBackgroundColor = Get-ThemeColor "listbox.selectedbackground" "#007acc"
        $this._themeList.SelectedForegroundColor = Get-ThemeColor "listbox.selectedforeground" "#ffffff"
        
        # Add focus visual feedback
        $this._themeList | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent" "#0078d4"
            $this.RequestRedraw()
        } -Force
        
        $this._themeList | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "border" "#007acc"
            $this.RequestRedraw()
        } -Force
        
        # Handle selection changes - fix closure reference
        $screenRef = $this
        $this._themeList.SelectedIndexChanged = {
            param($sender, $newIndex)
            Write-Log -Level Debug -Message "Theme selection changed to index: $newIndex"
            $screenRef.UpdatePreview()
        }.GetNewClosure()
        
        $listPanel.AddChild($this._themeList)
        
        # Preview panel (right side)
        $this._previewPanel = [Panel]::new("PreviewPanel")
        $this._previewPanel.IsFocusable = $false
        $this._previewPanel.X = $listWidth + 4
        $this._previewPanel.Y = 3
        $this._previewPanel.Width = $this.Width - $listWidth - 8
        $this._previewPanel.Height = $this.Height - 8
        $this._previewPanel.Title = " Preview "
        $this._previewPanel.BorderStyle = "Single"
        $this._previewPanel.BackgroundColor = Get-ThemeColor "background" "#1e1e1e"
        $this._previewPanel.BorderColor = Get-ThemeColor "border" "#007acc"
        $this._mainPanel.AddChild($this._previewPanel)
        
        # Description label
        $this._descriptionLabel = [LabelComponent]::new("Description")
        $this._descriptionLabel.IsFocusable = $false
        $this._descriptionLabel.X = 2
        $this._descriptionLabel.Y = 1
        $this._descriptionLabel.Text = ""
        $this._descriptionLabel.ForegroundColor = Get-ThemeColor "foreground" "#d4d4d4"
        $this._descriptionLabel.BackgroundColor = Get-ThemeColor "background" "#1e1e1e"
        $this._previewPanel.AddChild($this._descriptionLabel)
        
        # Preview elements
        $previewY = 3
        
        $this._previewTextLabel = [LabelComponent]::new("PreviewText")
        $this._previewTextLabel.IsFocusable = $false
        $this._previewTextLabel.X = 2
        $this._previewTextLabel.Y = $previewY
        $this._previewTextLabel.Text = "This is sample text in the selected theme"
        $this._previewTextLabel.ForegroundColor = Get-ThemeColor "foreground" "#d4d4d4"
        $this._previewTextLabel.BackgroundColor = Get-ThemeColor "background" "#1e1e1e"
        $this._previewPanel.AddChild($this._previewTextLabel)
        
        $previewY += 2
        
        $this._previewButtonLabel = [LabelComponent]::new("PreviewButton")
        $this._previewButtonLabel.IsFocusable = $false
        $this._previewButtonLabel.X = 2
        $this._previewButtonLabel.Y = $previewY
        $this._previewButtonLabel.Text = " [Sample Button] "
        $this._previewButtonLabel.ForegroundColor = Get-ThemeColor "button.focused.foreground"
        $this._previewButtonLabel.BackgroundColor = Get-ThemeColor "button.focused.background"
        $this._previewPanel.AddChild($this._previewButtonLabel)
        
        $previewY += 2
        
        $this._previewListLabel = [LabelComponent]::new("PreviewList")
        $this._previewListLabel.IsFocusable = $false
        $this._previewListLabel.X = 2
        $this._previewListLabel.Y = $previewY
        $this._previewListLabel.Text = "> Selected List Item"
        $this._previewListLabel.ForegroundColor = Get-ThemeColor "listbox.selectedforeground"
        $this._previewListLabel.BackgroundColor = Get-ThemeColor "listbox.selectedbackground"
        $this._previewPanel.AddChild($this._previewListLabel)
        
        $previewY += 2
        
        # Color swatch panel
        $this._colorSwatchPanel = [Panel]::new("ColorSwatch")
        $this._colorSwatchPanel.IsFocusable = $false
        $this._colorSwatchPanel.X = 2
        $this._colorSwatchPanel.Y = $previewY
        $this._colorSwatchPanel.Width = $this._previewPanel.Width - 4
        $this._colorSwatchPanel.Height = 6
        $this._colorSwatchPanel.Title = " Colors "
        $this._colorSwatchPanel.BorderStyle = "Single"
        $this._colorSwatchPanel.BackgroundColor = Get-ThemeColor "background"
        $this._colorSwatchPanel.BorderColor = Get-ThemeColor "border"
        $this._previewPanel.AddChild($this._colorSwatchPanel)
        
        # Status bar
        $this._statusLabel = [LabelComponent]::new("Status")
        $this._statusLabel.IsFocusable = $false
        $this._statusLabel.X = 2
        $this._statusLabel.Y = $this.Height - 3
        $this._statusLabel.Text = "↑↓ Navigate | Enter: Apply | P: Preview Live | Esc: Cancel"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "foreground"
        $this._statusLabel.BackgroundColor = Get-ThemeColor "background"
        $this._mainPanel.AddChild($this._statusLabel)
        
        # Set own colors
        $this.BackgroundColor = Get-ThemeColor "background"
        $this.ForegroundColor = Get-ThemeColor "foreground"
        
        # Populate theme list
        $this.PopulateThemeList()
        
        $this._themeScreenInitialized = $true
        $this._isInitialized = $true
        Write-Log -Level Debug -Message "ThemeScreen.Initialize: Completed successfully"
    }
    
    hidden [void] PopulateThemeList() {
        $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
        if (-not $themeManager) {
            Write-Log -Level Warning -Message "ThemeScreen: No ThemeManager available"
            return
        }
        
        # Get available themes from ThemeManager
        $availableThemes = $themeManager.GetAvailableThemes()
        Write-Log -Level Debug -Message "ThemeScreen: Found $($availableThemes.Count) available themes: $($availableThemes -join ', ')"
        
        $this._themeList.ClearItems()
        foreach ($themeName in $availableThemes) {
            $this._themeList.AddItem($themeName)
        }
        
        # Select current theme
        $currentTheme = $themeManager.ThemeName
        for ($i = 0; $i -lt $availableThemes.Count; $i++) {
            if ($availableThemes[$i] -eq $currentTheme) {
                $this._themeList.SelectedIndex = $i
                Write-Log -Level Debug -Message "ThemeScreen: Selected current theme '$currentTheme' at index $i"
                break
            }
        }
        
        $this.UpdatePreview()
    }
    
    hidden [void] UpdatePreview() {
        $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
        if (-not $themeManager) { return }
        
        $selectedIndex = $this._themeList.SelectedIndex
        $availableThemes = $themeManager.GetAvailableThemes()
        
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $availableThemes.Count) {
            $selectedThemeName = $availableThemes[$selectedIndex]
            Write-Log -Level Debug -Message "ThemeScreen: Updating preview for theme '$selectedThemeName'"
            
            # Temporarily load the theme to get its colors (don't apply globally yet)
            $themeObject = $null
            if ($themeManager.Themes.ContainsKey($selectedThemeName)) {
                $themeObject = $themeManager.Themes[$selectedThemeName]
            }
            
            if ($themeObject) {
                # Update description
                $description = if ($themeObject.Description) { 
                    $themeObject.Description 
                } else { 
                    "Theme: $selectedThemeName" 
                }
                $this._descriptionLabel.Text = $description
                
                # Get the theme's palette directly
                $palette = $themeObject.Palette
                
                # Update all preview elements with theme colors
                $this._descriptionLabel.ForegroundColor = $palette.Foreground
                $this._descriptionLabel.BackgroundColor = $palette.Background
                
                $this._previewTextLabel.ForegroundColor = $palette.Foreground
                $this._previewTextLabel.BackgroundColor = $palette.Background
                
                $this._previewButtonLabel.ForegroundColor = $palette.ButtonFocusedFg
                $this._previewButtonLabel.BackgroundColor = $palette.ButtonFocusedBg
                
                $this._previewListLabel.ForegroundColor = $palette.ListSelectedFg
                $this._previewListLabel.BackgroundColor = $palette.ListSelectedBg
                
                # Update panel backgrounds to match theme
                $this._previewPanel.BackgroundColor = $palette.Background
                $this._previewPanel.BorderColor = $palette.Border
                
                # Update color swatches
                $this.UpdateColorSwatches($palette)
            }
            
            $this.RequestRedraw()
        }
    }
    
    hidden [void] UpdateColorSwatches([hashtable]$palette) {
        if (-not $this._colorSwatchPanel) { return }
        
        # Clear existing swatches
        $this._colorSwatchPanel.Children.Clear()
        
        # Create color swatches
        $swatchColors = @(
            @{ Name = "BG"; Color = $palette.Background },
            @{ Name = "FG"; Color = $palette.Foreground },
            @{ Name = "Accent"; Color = $palette.PrimaryAccent },
            @{ Name = "Border"; Color = $palette.Border },
            @{ Name = "Button"; Color = $palette.ButtonFocusedBg },
            @{ Name = "Select"; Color = $palette.ListSelectedBg }
        )
        
        $x = 2
        $y = 1
        foreach ($swatch in $swatchColors) {
            $label = [LabelComponent]::new("Swatch_$($swatch.Name)")
            $label.IsFocusable = $false
            $label.X = $x
            $label.Y = $y
            $label.Text = " $($swatch.Name) "
            $label.ForegroundColor = "#FFFFFF"
            $label.BackgroundColor = $swatch.Color
            $this._colorSwatchPanel.AddChild($label)
            
            $x += $swatch.Name.Length + 4
            if ($x + 10 > $this._colorSwatchPanel.Width) {
                $x = 2
                $y += 2
            }
        }
    }
    
    hidden [void] PreviewThemeLive() {
        $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
        if (-not $themeManager) { return }
        
        $selectedIndex = $this._themeList.SelectedIndex
        $availableThemes = $themeManager.GetAvailableThemes()
        
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $availableThemes.Count) {
            $selectedThemeName = $availableThemes[$selectedIndex]
            Write-Log -Level Info -Message "Live preview of theme: $selectedThemeName"
            
            # Apply theme temporarily (without saving)
            $themeManager.LoadTheme($selectedThemeName)
            
            # Force complete redraw
            $global:TuiState.IsDirty = $true
            $this.RequestFullScreenRedraw()
        }
    }
    
    hidden [void] ApplyTheme() {
        $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
        if (-not $themeManager) {
            Write-Log -Level Warning -Message "ThemeScreen: No ThemeManager available for applying theme"
            return
        }
        
        $selectedIndex = $this._themeList.SelectedIndex
        $availableThemes = $themeManager.GetAvailableThemes()
        
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $availableThemes.Count) {
            $selectedThemeName = $availableThemes[$selectedIndex]
            
            Write-Log -Level Info -Message "Applying theme: $selectedThemeName"
            
            # Apply theme and save to config
            $themeManager.LoadTheme($selectedThemeName)
            
            # Save to user config
            $dataManager = $this.ServiceContainer?.GetService("DataManager")
            if ($dataManager) {
                $userConfig = $dataManager.UserConfig
                if (-not $userConfig.Preferences) {
                    $userConfig.Preferences = @{}
                }
                $userConfig.Preferences.Theme = $selectedThemeName
                $dataManager.SaveUserConfig()
            }
            
            # Notify about theme change
            $eventManager = $this.ServiceContainer?.GetService("EventManager")
            if ($eventManager) {
                $eventManager.Publish("Theme.Changed", @{ Theme = $selectedThemeName })
            }
            
            Write-Log -Level Info -Message "Successfully applied theme: $selectedThemeName"
            
            # Force complete UI refresh
            $this.RequestFullScreenRedraw()
        }
    }
    
    hidden [void] RequestFullScreenRedraw() {
        # Force complete redraw of entire screen hierarchy
        $global:TuiState.IsDirty = $true
        
        # Clear all buffers
        if ($global:TuiState.PSObject.Properties['MainBuffer'] -and $global:TuiState.MainBuffer) {
            $global:TuiState.MainBuffer.Clear()
        }
        if ($global:TuiState.PSObject.Properties['CompositorBuffer'] -and $global:TuiState.CompositorBuffer) {
            $global:TuiState.CompositorBuffer.Clear()
        }
        
        # Force redraw of all screens in the navigation stack
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navService -and $navService.PSObject.Properties.Name -contains '_navigationStack') {
            foreach ($screen in $navService._navigationStack) {
                if ($screen -and $screen.PSObject.Methods.Name -contains 'RequestRedraw') {
                    $screen.RequestRedraw()
                }
            }
        }
    }
    
    [void] OnEnter() {
        Write-Log -Level Debug -Message "ThemeScreen.OnEnter: Starting"
        
        # MUST call base to set initial focus
        ([Screen]$this).OnEnter()
        
        $this.RequestRedraw()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # ALWAYS FIRST - Let base handle Tab and component routing
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # ONLY screen-level shortcuts here
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                $this.ApplyTheme()
                # Go back after applying
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
            ([ConsoleKey]::Escape) {
                # Restore original theme and go back
                $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
                if ($themeManager -and $this._originalTheme) {
                    Write-Log -Level Debug -Message "Restoring original theme: $($this._originalTheme)"
                    $themeManager.LoadTheme($this._originalTheme)
                    $this.RequestFullScreenRedraw()
                }
                
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
        }
        
        # Handle P key for live preview
        if ($keyInfo.KeyChar -eq 'p' -or $keyInfo.KeyChar -eq 'P') {
            $this.PreviewThemeLive()
            return $true
        }
        
        return $false
    }
}

# ==============================================================================
# END OF THEME SCREEN
# ==============================================================================
