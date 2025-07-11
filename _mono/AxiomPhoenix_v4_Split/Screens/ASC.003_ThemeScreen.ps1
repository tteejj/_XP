# ==============================================================================
# Axiom-Phoenix v4.0 - Theme Selection Screen
# Simple theme picker with predefined themes
# ==============================================================================

class ThemeScreen : Screen {
    # UI Components
    hidden [Panel]$_mainPanel
    hidden [ListBox]$_themeList
    hidden [Panel]$_previewPanel
    hidden [LabelComponent]$_titleLabel
    hidden [LabelComponent]$_descriptionLabel
    hidden [LabelComponent]$_statusLabel
    
    # Available themes
    hidden [hashtable[]]$_themes = @(
        @{
            Name = "Default"
            Description = "Classic terminal colors with blue accents"
            Colors = @{
                "primary.background" = [ConsoleColor]::Black
                "primary.text" = [ConsoleColor]::Gray
                "secondary.background" = [ConsoleColor]::DarkBlue
                "secondary.text" = [ConsoleColor]::White
                "accent.primary" = [ConsoleColor]::Blue
                "accent.secondary" = [ConsoleColor]::Cyan
                "border.normal" = [ConsoleColor]::DarkGray
                "border.focused" = [ConsoleColor]::Blue
                "button.normal.background" = [ConsoleColor]::DarkGray
                "button.normal.text" = [ConsoleColor]::White
                "button.focused.background" = [ConsoleColor]::Blue
                "button.focused.text" = [ConsoleColor]::White
                "list.selected.background" = [ConsoleColor]::DarkBlue
                "list.selected.text" = [ConsoleColor]::White
                "success" = [ConsoleColor]::Green
                "warning" = [ConsoleColor]::Yellow
                "error" = [ConsoleColor]::Red
                "info" = [ConsoleColor]::Cyan
            }
        }
        @{
            Name = "Green Console"
            Description = "Classic green phosphor terminal look"
            Colors = @{
                "primary.background" = [ConsoleColor]::Black
                "primary.text" = [ConsoleColor]::Green
                "secondary.background" = [ConsoleColor]::DarkGreen
                "secondary.text" = [ConsoleColor]::Green
                "accent.primary" = [ConsoleColor]::Green
                "accent.secondary" = [ConsoleColor]::DarkGreen
                "border.normal" = [ConsoleColor]::DarkGreen
                "border.focused" = [ConsoleColor]::Green
                "button.normal.background" = [ConsoleColor]::DarkGreen
                "button.normal.text" = [ConsoleColor]::Green
                "button.focused.background" = [ConsoleColor]::Green
                "button.focused.text" = [ConsoleColor]::Black
                "list.selected.background" = [ConsoleColor]::DarkGreen
                "list.selected.text" = [ConsoleColor]::Green
                "success" = [ConsoleColor]::Green
                "warning" = [ConsoleColor]::Yellow
                "error" = [ConsoleColor]::Red
                "info" = [ConsoleColor]::Cyan
            }
        }
        @{
            Name = "Amber Console"
            Description = "Warm amber monochrome terminal"
            Colors = @{
                "primary.background" = [ConsoleColor]::Black
                "primary.text" = [ConsoleColor]::Yellow
                "secondary.background" = [ConsoleColor]::DarkYellow
                "secondary.text" = [ConsoleColor]::Yellow
                "accent.primary" = [ConsoleColor]::Yellow
                "accent.secondary" = [ConsoleColor]::DarkYellow
                "border.normal" = [ConsoleColor]::DarkYellow
                "border.focused" = [ConsoleColor]::Yellow
                "button.normal.background" = [ConsoleColor]::DarkYellow
                "button.normal.text" = [ConsoleColor]::Yellow
                "button.focused.background" = [ConsoleColor]::Yellow
                "button.focused.text" = [ConsoleColor]::Black
                "list.selected.background" = [ConsoleColor]::DarkYellow
                "list.selected.text" = [ConsoleColor]::Yellow
                "success" = [ConsoleColor]::Green
                "warning" = [ConsoleColor]::Yellow
                "error" = [ConsoleColor]::Red
                "info" = [ConsoleColor]::Cyan
            }
        }
        @{
            Name = "Notepad Style"
            Description = "Clean white background with black text"
            Colors = @{
                "primary.background" = [ConsoleColor]::White
                "primary.text" = [ConsoleColor]::Black
                "secondary.background" = [ConsoleColor]::Gray
                "secondary.text" = [ConsoleColor]::Black
                "accent.primary" = [ConsoleColor]::DarkBlue
                "accent.secondary" = [ConsoleColor]::Blue
                "border.normal" = [ConsoleColor]::DarkGray
                "border.focused" = [ConsoleColor]::DarkBlue
                "button.normal.background" = [ConsoleColor]::Gray
                "button.normal.text" = [ConsoleColor]::Black
                "button.focused.background" = [ConsoleColor]::DarkBlue
                "button.focused.text" = [ConsoleColor]::White
                "list.selected.background" = [ConsoleColor]::Blue
                "list.selected.text" = [ConsoleColor]::White
                "success" = [ConsoleColor]::DarkGreen
                "warning" = [ConsoleColor]::DarkYellow
                "error" = [ConsoleColor]::DarkRed
                "info" = [ConsoleColor]::DarkCyan
            }
        }
    )
    
    ThemeScreen([ServiceContainer]$container) : base("ThemeScreen", $container) {
        # Screen is automatically full window size
    }
    
    [void] Initialize() {
        # Create main panel
        $this._mainPanel = [Panel]::new("ThemeScreen_MainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.HasBorder = $true
        $this._mainPanel.BorderStyle = "Single"
        $this._mainPanel.Title = " Theme Selection "
        $this.AddChild($this._mainPanel)
        
        # Title label
        $this._titleLabel = [LabelComponent]::new("ThemeScreen_Title")
        $this._titleLabel.Text = "Select a Theme"
        $this._titleLabel.X = 2
        $this._titleLabel.Y = 1
        $this._titleLabel.ForegroundColor = Get-ThemeColor "accent.primary"
        $this._mainPanel.AddChild($this._titleLabel)
        
        # Theme list
        $this._themeList = [ListBox]::new("ThemeScreen_List")
        $this._themeList.X = 2
        $this._themeList.Y = 3
        $this._themeList.Width = [Math]::Min(40, $this._mainPanel.Width / 2 - 3)
        $this._themeList.Height = $this._mainPanel.Height - 8
        $this._themeList.HasBorder = $true
        $this._themeList.BorderStyle = "Single"
        $this._themeList.Title = " Available Themes "
        $this._mainPanel.AddChild($this._themeList)
        
        # Preview panel
        $previewX = $this._themeList.X + $this._themeList.Width + 2
        $this._previewPanel = [Panel]::new("ThemeScreen_Preview")
        $this._previewPanel.X = $previewX
        $this._previewPanel.Y = 3
        $this._previewPanel.Width = $this._mainPanel.Width - $previewX - 2
        $this._previewPanel.Height = $this._mainPanel.Height - 8
        $this._previewPanel.HasBorder = $true
        $this._previewPanel.BorderStyle = "Single"
        $this._previewPanel.Title = " Preview "
        $this._mainPanel.AddChild($this._previewPanel)
        
        # Description label in preview
        $this._descriptionLabel = [LabelComponent]::new("ThemeScreen_Description")
        $this._descriptionLabel.X = 2
        $this._descriptionLabel.Y = 1
        $this._descriptionLabel.Width = $this._previewPanel.Width - 4
        $this._previewPanel.AddChild($this._descriptionLabel)
        
        # Status label
        $this._statusLabel = [LabelComponent]::new("ThemeScreen_Status")
        $this._statusLabel.Text = "Use ↑↓ to navigate, Enter to apply theme, Escape to go back"
        $this._statusLabel.X = 2
        $this._statusLabel.Y = $this._mainPanel.Height - 3
        $this._statusLabel.ForegroundColor = Get-ThemeColor "info"
        $this._mainPanel.AddChild($this._statusLabel)
        
        # Populate theme list
        $this.PopulateThemeList()
        
        # Subscribe to selection changes
        $thisScreen = $this
        $this._themeList.SelectedIndexChanged = {
            param($sender, $index)
            $thisScreen.UpdatePreview()
        }
        
        # Set focus to list
        $focusManager = $this.ServiceContainer.GetService("FocusManager")
        if ($focusManager) {
            $focusManager.SetFocus($this._themeList)
        }
    }
    
    hidden [void] PopulateThemeList() {
        $this._themeList.ClearItems()
        foreach ($theme in $this._themes) {
            $this._themeList.AddItem($theme.Name)
        }
        
        # Select current theme if found
        $themeManager = $this.ServiceContainer.GetService("ThemeManager")
        if ($themeManager -and $themeManager.ThemeName) {
            for ($i = 0; $i -lt $this._themes.Count; $i++) {
                if ($this._themes[$i].Name -eq $themeManager.ThemeName) {
                    $this._themeList.SelectedIndex = $i
                    break
                }
            }
        }
        
        $this.UpdatePreview()
    }
    
    hidden [void] UpdatePreview() {
        if ($this._themeList.SelectedIndex -ge 0 -and $this._themeList.SelectedIndex -lt $this._themes.Count) {
            $selectedTheme = $this._themes[$this._themeList.SelectedIndex]
            $this._descriptionLabel.Text = $selectedTheme.Description
            
            # Clear preview panel
            $children = @($this._previewPanel.Children | Where-Object { $_.Name -ne "ThemeScreen_Description" })
            foreach ($child in $children) {
                $this._previewPanel.RemoveChild($child)
            }
            
            # Add preview elements
            $y = 3
            
            # Sample text
            $sampleLabel = [LabelComponent]::new("Preview_Text")
            $sampleLabel.Text = "Sample Text"
            $sampleLabel.X = 2
            $sampleLabel.Y = $y
            $sampleLabel.ForegroundColor = $selectedTheme.Colors["primary.text"]
            $this._previewPanel.AddChild($sampleLabel)
            $y += 2
            
            # Sample button
            $sampleButton = [ButtonComponent]::new("Preview_Button")
            $sampleButton.Text = " Sample Button "
            $sampleButton.X = 2
            $sampleButton.Y = $y
            $this._previewPanel.AddChild($sampleButton)
            $y += 3
            
            # Sample list
            $sampleList = [ListBox]::new("Preview_List")
            $sampleList.X = 2
            $sampleList.Y = $y
            $sampleList.Width = [Math]::Min(30, $this._previewPanel.Width - 4)
            $sampleList.Height = 5
            $sampleList.AddItem("List Item 1")
            $sampleList.AddItem("List Item 2 (Selected)")
            $sampleList.AddItem("List Item 3")
            $sampleList.SelectedIndex = 1
            $this._previewPanel.AddChild($sampleList)
            
            $this.RequestRedraw()
        }
    }
    
    hidden [void] ApplySelectedTheme() {
        if ($this._themeList.SelectedIndex -ge 0 -and $this._themeList.SelectedIndex -lt $this._themes.Count) {
            $selectedTheme = $this._themes[$this._themeList.SelectedIndex]
            $themeManager = $this.ServiceContainer.GetService("ThemeManager")
            
            if ($themeManager) {
                # Apply all theme colors
                foreach ($colorKey in $selectedTheme.Colors.Keys) {
                    $themeManager.SetColor($colorKey, $selectedTheme.Colors[$colorKey])
                }
                
                # Update theme name
                $themeManager.ThemeName = $selectedTheme.Name
                
                # Publish theme change event
                $eventManager = $this.ServiceContainer.GetService("EventManager")
                if ($eventManager) {
                    $eventManager.Publish("Theme.Changed", @{
                        ThemeName = $selectedTheme.Name
                    })
                }
                
                Write-Log -Level Info -Message "Applied theme: $($selectedTheme.Name)"
                
                # Show confirmation
                $this._statusLabel.Text = "Theme '$($selectedTheme.Name)' applied!"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "success"
                $this.RequestRedraw()
                
                # Go back after short delay
                Start-Sleep -Milliseconds 500
                $navService = $this.ServiceContainer.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
            }
        }
    }
    
    [void] OnEnter() {
        ([Screen]$this).OnEnter()
        $this.UpdatePreview()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        switch ($key.Key) {
            ([ConsoleKey]::Escape) {
                # Go back
                $navService = $this.ServiceContainer.GetService("NavigationService")
                if ($navService.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
            ([ConsoleKey]::Enter) {
                # Apply selected theme
                $this.ApplySelectedTheme()
                return $true
            }
        }
        
        # Let base class handle input routing to focused component
        return ([Screen]$this).HandleInput($key)
    }
}
