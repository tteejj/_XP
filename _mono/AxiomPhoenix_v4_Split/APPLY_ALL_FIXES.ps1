# COMPLETE FIXES FOR AXIOM-PHOENIX v4.0
# Applying all fixes from REAL_FIX.ps1 plus additional syntax fixes

Write-Host "Applying ALL fixes to Axiom-Phoenix v4.0..." -ForegroundColor Yellow

# FIX 1: Fix syntax errors in TaskListScreen first
Write-Host "`nFixing TaskListScreen syntax errors..." -ForegroundColor Cyan
$taskListPath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AxiomPhoenix_v4_Split\Screens\ASC.002_TaskListScreen.ps1"
$content = Get-Content $taskListPath -Raw

# Fix all HandleInput method signatures missing closing parenthesis
$content = $content -replace '\[bool\]\s+HandleInput\(\[System\.ConsoleKeyInfo\]\$keyInfo\s*$', '[bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {'

# Save fixed content
Set-Content -Path $taskListPath -Value $content -Force
Write-Host "  - Fixed HandleInput method signatures" -ForegroundColor Green

# FIX 2: Apply the Theme Screen from REAL_FIX.ps1
Write-Host "`nApplying Theme Screen fix..." -ForegroundColor Cyan
$themeScreenPath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AxiomPhoenix_v4_Split\Screens\ASC.003_ThemeScreen.ps1"
$themeScreenContent = @'
# ==============================================================================
# Axiom-Phoenix v4.0 - Theme Selection Screen - FIXED VERSION
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
                "button.focused.fg" = "#FFFFFF"
                "button.focused.bg" = "#000080"
                "list.item.selected" = "#FFFFFF"
                "list.item.selected.background" = "#0000FF"
            }
        }
    )
    
    ThemeScreen([ServiceContainer]$container) : base("ThemeScreen", $container) {
    }
    
    [void] Initialize() {
        # Main panel
        $this._mainPanel = [Panel]::new("ThemeScreen_MainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.HasBorder = $true
        $this._mainPanel.BorderStyle = "Single"
        $this._mainPanel.Title = " Theme Selection "
        $this.AddChild($this._mainPanel)
        
        # Title
        $this._titleLabel = [LabelComponent]::new("ThemeScreen_Title")
        $this._titleLabel.Text = "Select a Theme"
        $this._titleLabel.X = 2
        $this._titleLabel.Y = 1
        $this._titleLabel.ForegroundColor = Get-ThemeColor "Primary"
        $this._mainPanel.AddChild($this._titleLabel)
        
        # Theme list - fixed width
        $this._themeList = [ListBox]::new("ThemeScreen_List")
        $this._themeList.X = 2
        $this._themeList.Y = 3
        $this._themeList.Width = 30  # Fixed width
        $this._themeList.Height = $this._mainPanel.Height - 8
        $this._themeList.HasBorder = $true
        $this._themeList.BorderStyle = "Single"
        $this._themeList.Title = " Themes "
        $this._themeList.IsFocusable = $true
        $this._mainPanel.AddChild($this._themeList)
        
        # Preview panel - rest of the width
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
        
        # Description in preview
        $this._descriptionLabel = [LabelComponent]::new("ThemeScreen_Description")
        $this._descriptionLabel.X = 2
        $this._descriptionLabel.Y = 1
        $this._descriptionLabel.Width = $this._previewPanel.Width - 4
        $this._descriptionLabel.Text = ""
        $this._previewPanel.AddChild($this._descriptionLabel)
        
        # Preview elements - static labels showing theme colors
        $y = 3
        
        # Text preview
        $this._previewTextLabel = [LabelComponent]::new("Preview_Text")
        $this._previewTextLabel.Text = "Sample Text (Foreground Color)"
        $this._previewTextLabel.X = 2
        $this._previewTextLabel.Y = $y
        $this._previewPanel.AddChild($this._previewTextLabel)
        $y += 2
        
        # Button preview
        $this._previewButtonLabel = [LabelComponent]::new("Preview_Button")
        $this._previewButtonLabel.Text = "[ Sample Button (Focused) ]"
        $this._previewButtonLabel.X = 2
        $this._previewButtonLabel.Y = $y
        $this._previewPanel.AddChild($this._previewButtonLabel)
        $y += 2
        
        # List preview
        $this._previewListLabel = [LabelComponent]::new("Preview_List")
        $this._previewListLabel.Text = "> Selected List Item <"
        $this._previewListLabel.X = 2
        $this._previewListLabel.Y = $y
        $this._previewPanel.AddChild($this._previewListLabel)
        
        # Status label - positioned correctly
        $statusY = $this._mainPanel.Height - 3
        $this._statusLabel = [LabelComponent]::new("ThemeScreen_Status")
        $this._statusLabel.Text = "Use ↑↓ to navigate, Enter to apply theme, Escape to go back"
        $this._statusLabel.X = 2
        $this._statusLabel.Y = $statusY
        $this._statusLabel.ForegroundColor = Get-ThemeColor "Info"
        $this._mainPanel.AddChild($this._statusLabel)
        
        # Populate themes
        $this.PopulateThemeList()
        
        # Selection change handler
        $thisScreen = $this
        $this._themeList.SelectedIndexChanged = {
            param($sender, $index)
            $thisScreen.UpdatePreview()
        }
        
        # Set focus
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
        $this._themeList.SelectedIndex = 0
        $this.UpdatePreview()
    }
    
    hidden [void] UpdatePreview() {
        if ($this._themeList.SelectedIndex -ge 0 -and $this._themeList.SelectedIndex -lt $this._themes.Count) {
            $selectedTheme = $this._themes[$this._themeList.SelectedIndex]
            
            # Update description
            $this._descriptionLabel.Text = $selectedTheme.Description
            
            # Update preview colors
            $this._previewTextLabel.ForegroundColor = $selectedTheme.Colors["Foreground"]
            $this._previewButtonLabel.ForegroundColor = $selectedTheme.Colors["button.focused.fg"]
            $this._previewButtonLabel.BackgroundColor = $selectedTheme.Colors["button.focused.bg"]
            $this._previewListLabel.ForegroundColor = $selectedTheme.Colors["list.item.selected"]
            $this._previewListLabel.BackgroundColor = $selectedTheme.Colors["list.item.selected.background"]
            
            $this.RequestRedraw()
        }
    }
    
    hidden [void] ApplySelectedTheme() {
        if ($this._themeList.SelectedIndex -ge 0 -and $this._themeList.SelectedIndex -lt $this._themes.Count) {
            $selectedTheme = $this._themes[$this._themeList.SelectedIndex]
            $themeManager = $this.ServiceContainer.GetService("ThemeManager")
            
            if ($themeManager) {
                # Apply all colors
                foreach ($colorKey in $selectedTheme.Colors.Keys) {
                    $themeManager.SetColor($colorKey, $selectedTheme.Colors[$colorKey])
                }
                
                $themeManager.ThemeName = $selectedTheme.Name
                $global:TuiState.IsDirty = $true
                
                # Show confirmation
                $this._statusLabel.Text = "Theme '$($selectedTheme.Name)' applied!"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "Success"
                $this.RequestRedraw()
                
                # Force immediate redraw
                if ($global:TuiState.RenderEngine) {
                    $global:TuiState.RenderEngine.Render()
                }
                
                # Return after delay
                Start-Sleep -Milliseconds 1500
                $navService = $this.ServiceContainer.GetService("NavigationService")
                if ($navService) {
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
                $navService = $this.ServiceContainer.GetService("NavigationService")
                if ($navService) { $navService.GoBack() }
                return $true
            }
            ([ConsoleKey]::Enter) {
                $this.ApplySelectedTheme()
                return $true
            }
        }
        
        return ([Screen]$this).HandleInput($key)
    }
}
'@

Set-Content -Path $themeScreenPath -Value $themeScreenContent -Force
Write-Host "  - Theme Screen completely replaced with FIXED VERSION" -ForegroundColor Green

# FIX 3: Add Tab navigation to TaskListScreen if missing
Write-Host "`nAdding Tab navigation to TaskListScreen..." -ForegroundColor Cyan
$content = Get-Content $taskListPath -Raw

# Find the main TaskListScreen HandleInput method
$pattern = '(class TaskListScreen : Screen[\s\S]+?)\[bool\]\s+HandleInput\(\[System\.ConsoleKeyInfo\]\$keyInfo\)\s*\{([^}]+switch\s*\(\$keyInfo\.Key\)\s*\{[^}]+)(\}\s*return\s+\(\[Screen\]\$this\)\.HandleInput)'

if ($content -match $pattern) {
    $beforeMethod = $matches[1]
    $methodContent = $matches[2]
    $afterMethod = $matches[3]
    
    # Check if Tab handling already exists
    if ($methodContent -notmatch 'ConsoleKey.*Tab') {
        # Add Tab handling before the closing brace
        $tabHandling = @'
            ([ConsoleKey]::Tab) {
                # Cycle focus between components
                $focusManager = $this.ServiceContainer.GetService("FocusManager")
                if ($focusManager) {
                    if ($this._taskListBox.IsFocused) {
                        $focusManager.SetFocus($this._filterBox)
                    } else {
                        $focusManager.SetFocus($this._taskListBox)
                    }
                }
                return $true
            }
'@
        $newMethodContent = $methodContent + "`n" + $tabHandling + "`n        }"
        $newContent = $beforeMethod + "[bool] HandleInput([System.ConsoleKeyInfo]`$keyInfo) {" + $newMethodContent + "`n" + $afterMethod
        Set-Content -Path $taskListPath -Value $newContent -Force
        Write-Host "  - Tab navigation added to TaskListScreen" -ForegroundColor Green
    } else {
        Write-Host "  - Tab navigation already exists in TaskListScreen" -ForegroundColor Yellow
    }
}

# FIX 4: Apply New Task Screen spacing fix from REAL_FIX.ps1
Write-Host "`nApplying New Task Screen spacing fix..." -ForegroundColor Cyan
$newTaskPath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AxiomPhoenix_v4_Split\Screens\ASC.004_NewTaskScreen.ps1"
$newTaskContent = Get-Content $newTaskPath -Raw

# Replace the Initialize method
$initPattern = '(\[void\]\s+Initialize\(\)\s*\{)([^}]+\})'
$newInitializeBody = @'
        # Main form panel - full screen
        $this._formPanel = [Panel]::new("NewTaskForm")
        $this._formPanel.X = 0
        $this._formPanel.Y = 0
        $this._formPanel.Width = $this.Width
        $this._formPanel.Height = $this.Height
        $this._formPanel.Title = " New Task "
        $this._formPanel.BorderStyle = "Double"
        $this._formPanel.BorderColor = Get-ThemeColor "Primary"
        $this._formPanel.BackgroundColor = Get-ThemeColor "Background"
        $this.AddChild($this._formPanel)
        
        # Layout with generous spacing
        $leftMargin = 5
        $topMargin = 3
        $labelHeight = 1
        $inputHeight = 3
        $sectionGap = 3  # Gap between sections
        $contentWidth = [Math]::Min(100, $this._formPanel.Width - ($leftMargin * 2))
        
        $currentY = $topMargin
        
        # Title Section
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Task Title:"
        $titleLabel.X = $leftMargin
        $titleLabel.Y = $currentY
        $titleLabel.ForegroundColor = Get-ThemeColor "Foreground"
        $this._formPanel.AddChild($titleLabel)
        
        $currentY += $labelHeight + 1
        
        $this._titleBox = [TextBoxComponent]::new("TitleInput")
        $this._titleBox.X = $leftMargin
        $this._titleBox.Y = $currentY
        $this._titleBox.Width = $contentWidth
        $this._titleBox.Height = $inputHeight
        $this._titleBox.Placeholder = "Enter task title..."
        $this._titleBox.IsFocusable = $true
        $this._formPanel.AddChild($this._titleBox)
        
        $currentY += $inputHeight + $sectionGap
        
        # Description Section
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = $leftMargin
        $descLabel.Y = $currentY
        $descLabel.ForegroundColor = Get-ThemeColor "Foreground"
        $this._formPanel.AddChild($descLabel)
        
        $currentY += $labelHeight + 1
        
        $this._descriptionBox = [TextBoxComponent]::new("DescInput")
        $this._descriptionBox.X = $leftMargin
        $this._descriptionBox.Y = $currentY
        $this._descriptionBox.Width = $contentWidth
        $this._descriptionBox.Height = $inputHeight
        $this._descriptionBox.Placeholder = "Enter description..."
        $this._descriptionBox.IsFocusable = $true
        $this._formPanel.AddChild($this._descriptionBox)
        
        $currentY += $inputHeight + $sectionGap
        
        # Priority and Project side by side
        $halfWidth = [Math]::Floor(($contentWidth - 10) / 2)
        
        # Priority
        $priorityLabel = [LabelComponent]::new("PriorityLabel")
        $priorityLabel.Text = "Priority:"
        $priorityLabel.X = $leftMargin
        $priorityLabel.Y = $currentY
        $priorityLabel.ForegroundColor = Get-ThemeColor "Foreground"
        $this._formPanel.AddChild($priorityLabel)
        
        $this._priorityList = [ListBox]::new("PriorityList")
        $this._priorityList.X = $leftMargin
        $this._priorityList.Y = $currentY + $labelHeight + 1
        $this._priorityList.Width = $halfWidth
        $this._priorityList.Height = 5
        $this._priorityList.HasBorder = $true
        $this._priorityList.BorderStyle = "Single"
        $this._priorityList.AddItem("Low")
        $this._priorityList.AddItem("Medium")
        $this._priorityList.AddItem("High")
        $this._priorityList.SelectedIndex = 1
        $this._priorityList.IsFocusable = $true
        $this._formPanel.AddChild($this._priorityList)
        
        # Project
        $projectX = $leftMargin + $halfWidth + 10
        $projectLabel = [LabelComponent]::new("ProjectLabel")
        $projectLabel.Text = "Project:"
        $projectLabel.X = $projectX
        $projectLabel.Y = $currentY
        $projectLabel.ForegroundColor = Get-ThemeColor "Foreground"
        $this._formPanel.AddChild($projectLabel)
        
        $this._projectList = [ListBox]::new("ProjectList")
        $this._projectList.X = $projectX
        $this._projectList.Y = $currentY + $labelHeight + 1
        $this._projectList.Width = $halfWidth
        $this._projectList.Height = 5
        $this._projectList.HasBorder = $true
        $this._projectList.BorderStyle = "Single"
        $this._projectList.AddItem("General")
        $this._projectList.SelectedIndex = 0
        $this._projectList.IsFocusable = $true
        $this._formPanel.AddChild($this._projectList)
        
        # Status at bottom
        $bottomY = $this._formPanel.Height - 5
        
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.X = $leftMargin
        $this._statusLabel.Y = $bottomY
        $this._statusLabel.Text = "Ready to create task"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "Info"
        $this._formPanel.AddChild($this._statusLabel)
        
        $instructLabel = [LabelComponent]::new("InstructLabel")
        $instructLabel.X = $leftMargin
        $instructLabel.Y = $bottomY + 2
        $instructLabel.Text = "Tab: Next field | Ctrl+S: Save | ESC: Cancel"
        $instructLabel.ForegroundColor = Get-ThemeColor "Subtle"
        $this._formPanel.AddChild($instructLabel)
    }
'@

$newTaskContent = $newTaskContent -replace $initPattern, "`$1`n$newInitializeBody"
Set-Content -Path $newTaskPath -Value $newTaskContent -Force
Write-Host "  - New Task Screen spacing completely fixed" -ForegroundColor Green

Write-Host "`nAll fixes have been applied!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run .\Start.ps1 to test the application" -ForegroundColor White
Write-Host "2. Test Theme Selection (should apply immediately)" -ForegroundColor White
Write-Host "3. Test New Task screen (all fields should be visible)" -ForegroundColor White
Write-Host "4. Test Tab navigation in Task List screen" -ForegroundColor White
