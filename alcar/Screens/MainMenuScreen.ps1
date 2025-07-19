# Main Menu Screen - Enhanced with left panel navigation

class MainMenuScreen : Screen {
    [System.Collections.ArrayList]$MenuItems
    [System.Collections.ArrayList]$MenuCategories
    [int]$SelectedIndex = 0
    [int]$SelectedCategory = 0
    [bool]$ShowCategories = $true
    hidden [int]$AnimationFrame = 0
    
    MainMenuScreen() {
        $this.Title = "ALCAR"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Menu categories for better organization
        $this.MenuCategories = [System.Collections.ArrayList]@(
            @{Name = "CORE"; Items = @()},
            @{Name = "TOOLS"; Items = @()},
            @{Name = "SYSTEM"; Items = @()}
        )
        
        # All menu items organized by category
        $this.MenuItems = [System.Collections.ArrayList]@(
            # CORE category
            @{
                Title = "Tasks"
                Category = 0
                Icon = "◈"
                Key = "T"
                Action = { 
                    $screen = [TaskScreen]::new()
                    $global:ScreenManager.Push($screen)
                }.GetNewClosure()
            },
            @{
                Title = "Projects"
                Category = 0
                Icon = "◈"
                Key = "P"
                Action = {
                    $screen = [ProjectsScreen]::new()
                    $global:ScreenManager.Push($screen)
                }.GetNewClosure()
            },
            @{
                Title = "Dashboard"
                Category = 0
                Icon = "◈"
                Key = "D"
                Action = {
                    $screen = [DashboardScreen]::new()
                    $global:ScreenManager.Push($screen)
                }.GetNewClosure()
            },
            # TOOLS category (ready for expansion)
            @{
                Title = "Calendar"
                Category = 1
                Icon = "◆"
                Key = "C"
                Action = {
                    # Placeholder for future calendar screen
                    Write-Host "Calendar not yet implemented"
                    Start-Sleep -Seconds 1
                }.GetNewClosure()
            },
            @{
                Title = "File Browser"
                Category = 1
                Icon = "◆"
                Key = "F"
                Action = {
                    $screen = [FileBrowserScreen]::new()
                    $global:ScreenManager.Push($screen)
                }.GetNewClosure()
            },
            @{
                Title = "Pomodoro"
                Category = 1
                Icon = "◆"
                Key = "O"
                Action = {
                    # Placeholder for future pomodoro timer
                    Write-Host "Pomodoro Timer not yet implemented"
                    Start-Sleep -Seconds 1
                }.GetNewClosure()
            },
            @{
                Title = "Text Editor"
                Category = 1
                Icon = "◆"
                Key = "E"
                Action = {
                    $screen = [TextEditorScreen]::new()
                    $global:ScreenManager.Push($screen)
                }.GetNewClosure()
            },
            @{
                Title = "Text Editor v2"
                Category = 1
                Icon = "◆"
                Key = "V"
                Action = {
                    $screen = [TextEditorScreenV2]::new()
                    $global:ScreenManager.Push($screen)
                }.GetNewClosure()
            },
            # SYSTEM category
            @{
                Title = "Settings"
                Category = 2
                Icon = "○"
                Key = "S"
                Action = {
                    $screen = [SettingsScreenV2]::new()
                    $global:ScreenManager.Push($screen)
                }.GetNewClosure()
            },
            @{
                Title = "About"
                Category = 2
                Icon = "○"
                Key = "A"
                Action = {
                    # Placeholder for about screen
                    Write-Host "ALCAR v1.0 - Advanced Linux Console Application Resource"
                    Start-Sleep -Seconds 2
                }.GetNewClosure()
            },
            @{
                Title = "Exit"
                Category = 2
                Icon = "●"
                Key = "Q"
                Action = {
                    $this.Active = $false
                }
            }
        )
        
        # Organize items into categories
        foreach ($item in $this.MenuItems) {
            $this.MenuCategories[$item.Category].Items += $item
        }
        
        # Key bindings
        $this.InitializeKeyBindings()
        
        # Status bar
        $this.UpdateStatusBar()
    }
    
    [void] InitializeKeyBindings() {
        $this.BindKey([ConsoleKey]::UpArrow, { $this.MoveUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.MoveDown(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.MoveCategoryUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.MoveCategoryDown(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::Enter, { $this.SelectItem() })
        $this.BindKey([ConsoleKey]::Tab, { $this.ToggleCategoryView(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::Escape, { $this.Active = $false })
        
        # Quick access keys for all items
        foreach ($item in $this.MenuItems) {
            if ($item.Key) {
                $this.BindKey($item.Key.ToLower()[0], { 
                    param($key)
                    $this.QuickSelectByKey($key)
                }.GetNewClosure())
            }
        }
        
        $this.BindKey('q', { $this.Active = $false })
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        $this.AddStatusItem('↑↓', 'navigate')
        $this.AddStatusItem('←→', 'category')
        $this.AddStatusItem('Enter', 'select')
        $this.AddStatusItem('Tab', 'toggle view')
        $this.AddStatusItem('Letter keys', 'quick access')
        $this.AddStatusItem('ESC/Q', 'quit')
    }
    
    [string] RenderContent() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Clear background
        for ($y = 1; $y -le $height; $y++) {
            $output += [VT]::MoveTo(1, $y)
            $output += " " * $width
        }
        
        # Draw main border
        $output += $this.DrawBorder()
        
        # ALCAR title at top
        $output += $this.DrawCompactTitle()
        
        # Left panel for menu
        $leftPanelWidth = 30
        $output += $this.DrawLeftPanel($leftPanelWidth, $height)
        
        # Right content area
        $output += $this.DrawRightContent($leftPanelWidth + 2, $width - $leftPanelWidth - 3, $height)
        
        $output += [VT]::Reset()
        return $output
    }
    
    [string] DrawCompactTitle() {
        $width = [Console]::WindowWidth
        $output = ""
        
        # Compact ALCAR title
        $title = "═══╡ A L C A R ╞═══"
        $x = [Math]::Max(1, [int](($width - $title.Length) / 2))
        $output += [VT]::MoveTo($x, 2)
        $output += [VT]::RGB(100, 200, 255) + $title + [VT]::Reset()
        
        return $output
    }
    
    [string] DrawLeftPanel([int]$panelWidth, [int]$panelHeight) {
        $output = ""
        
        # Panel border
        for ($y = 4; $y -lt $panelHeight - 1; $y++) {
            $output += [VT]::MoveTo($panelWidth, $y)
            $output += [VT]::RGB(80, 80, 120) + "│" + [VT]::Reset()
        }
        
        # Menu items
        $menuY = 5
        $itemIndex = 0
        
        foreach ($category in $this.MenuCategories) {
            # Category header
            $output += [VT]::MoveTo(3, $menuY)
            if ($this.SelectedCategory -eq $this.MenuCategories.IndexOf($category)) {
                $output += [VT]::RGB(150, 200, 255) + "▼ " + $category.Name + [VT]::Reset()
            } else {
                $output += [VT]::RGB(100, 100, 150) + "▶ " + $category.Name + [VT]::Reset()
            }
            $menuY += 2
            
            # Show items if category is selected or all categories are shown
            if ($this.ShowCategories -or $this.SelectedCategory -eq $this.MenuCategories.IndexOf($category)) {
                foreach ($item in $category.Items) {
                    $isSelected = ($itemIndex -eq $this.SelectedIndex)
                    
                    $output += [VT]::MoveTo(5, $menuY)
                    
                    if ($isSelected) {
                        # Highlight bar
                        $output += [VT]::MoveTo(2, $menuY)
                        $output += [VT]::RGBBG(40, 40, 80) + " " * ($panelWidth - 3) + [VT]::Reset()
                        
                        $output += [VT]::MoveTo(5, $menuY)
                        $output += [VT]::RGB(255, 255, 255)
                        $output += $item.Icon + " " + $item.Title
                        $output += [VT]::Reset()
                        
                        # Key hint
                        if ($item.Key) {
                            $output += [VT]::MoveTo($panelWidth - 4, $menuY)
                            $output += [VT]::RGB(200, 200, 100) + "[" + $item.Key + "]" + [VT]::Reset()
                        }
                    } else {
                        $output += [VT]::RGB(150, 150, 150)
                        $output += $item.Icon + " " + $item.Title
                        
                        # Key hint (dimmed)
                        if ($item.Key) {
                            $output += [VT]::MoveTo($panelWidth - 4, $menuY)
                            $output += [VT]::RGB(80, 80, 80) + "[" + $item.Key + "]"
                        }
                        $output += [VT]::Reset()
                    }
                    
                    $menuY++
                    $itemIndex++
                }
                $menuY++ # Extra space after category
            }
        }
        
        return $output
    }
    
    [string] DrawRightContent([int]$startX, [int]$contentWidth, [int]$contentHeight) {
        $output = ""
        
        # Get selected item details
        $selectedItem = $this.GetSelectedItem()
        if (-not $selectedItem) { return $output }
        
        # Draw selection preview/info
        $centerY = [int]($contentHeight / 2) - 5
        $centerX = $startX + [int]($contentWidth / 2)
        
        # Item icon (large)
        $largeIcon = "◆"
        if ($selectedItem.Icon) { $largeIcon = $selectedItem.Icon }
        
        $output += [VT]::MoveTo($centerX - 1, $centerY)
        $output += [VT]::RGB(100, 200, 255)
        # Draw large version
        for ($i = 0; $i -lt 3; $i++) {
            $output += [VT]::MoveTo($centerX - 3, $centerY + $i)
            $output += "  $largeIcon $largeIcon $largeIcon  "
        }
        $output += [VT]::Reset()
        
        # Item title
        $output += [VT]::MoveTo($centerX - ([int]($selectedItem.Title.Length / 2)), $centerY + 5)
        $output += [VT]::RGB(255, 255, 255) + $selectedItem.Title.ToUpper() + [VT]::Reset()
        
        # Hint text
        $hint = "Press Enter to launch"
        if ($selectedItem.Key) {
            $hint = "Press Enter or '" + $selectedItem.Key + "' to launch"
        }
        $output += [VT]::MoveTo($centerX - ([int]($hint.Length / 2)), $centerY + 7)
        $output += [VT]::RGB(150, 150, 150) + $hint + [VT]::Reset()
        
        return $output
    }
    
    [string] DrawBorder() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        $borderColor = [VT]::RGB(100, 100, 150)
        
        # Top border
        $output += [VT]::MoveTo(1, 1)
        $output += $borderColor
        $output += "╔" + ("═" * ($width - 2)) + "╗"
        
        # Sides
        for ($y = 2; $y -lt $height - 1; $y++) {
            $output += [VT]::MoveTo(1, $y) + "║"
            $output += [VT]::MoveTo($width, $y) + "║"
        }
        
        # Bottom border
        $output += [VT]::MoveTo(1, $height - 1)
        $output += "╚" + ("═" * ($width - 2)) + "╝"
        
        $output += [VT]::Reset()
        return $output
    }
    
    [object] GetSelectedItem() {
        $index = 0
        foreach ($category in $this.MenuCategories) {
            foreach ($item in $category.Items) {
                if ($index -eq $this.SelectedIndex) {
                    return $item
                }
                $index++
            }
        }
        return $null
    }
    
    [void] MoveUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
        } else {
            # Wrap to bottom
            $this.SelectedIndex = $this.GetTotalItemCount() - 1
        }
        $this.UpdateSelectedCategory()
    }
    
    [void] MoveDown() {
        $total = $this.GetTotalItemCount()
        if ($this.SelectedIndex -lt $total - 1) {
            $this.SelectedIndex++
        } else {
            # Wrap to top
            $this.SelectedIndex = 0
        }
        $this.UpdateSelectedCategory()
    }
    
    [void] MoveCategoryUp() {
        if ($this.SelectedCategory -gt 0) {
            $this.SelectedCategory--
            # Move to first item in category
            $this.SelectFirstInCategory()
        }
    }
    
    [void] MoveCategoryDown() {
        if ($this.SelectedCategory -lt $this.MenuCategories.Count - 1) {
            $this.SelectedCategory++
            # Move to first item in category
            $this.SelectFirstInCategory()
        }
    }
    
    [void] SelectFirstInCategory() {
        $index = 0
        for ($i = 0; $i -lt $this.SelectedCategory; $i++) {
            $index += $this.MenuCategories[$i].Items.Count
        }
        $this.SelectedIndex = $index
    }
    
    [void] UpdateSelectedCategory() {
        # Determine which category the selected index falls into
        $index = 0
        for ($i = 0; $i -lt $this.MenuCategories.Count; $i++) {
            $categorySize = $this.MenuCategories[$i].Items.Count
            if ($this.SelectedIndex -ge $index -and $this.SelectedIndex -lt ($index + $categorySize)) {
                $this.SelectedCategory = $i
                break
            }
            $index += $categorySize
        }
    }
    
    [int] GetTotalItemCount() {
        $total = 0
        foreach ($category in $this.MenuCategories) {
            $total += $category.Items.Count
        }
        return $total
    }
    
    [void] ToggleCategoryView() {
        $this.ShowCategories = -not $this.ShowCategories
    }
    
    [void] SelectItem() {
        $item = $this.GetSelectedItem()
        if ($item -and $item.Action) {
            & $item.Action
        }
    }
    
    [void] QuickSelectByKey([char]$key) {
        $upperKey = [char]::ToUpper($key)
        $index = 0
        foreach ($category in $this.MenuCategories) {
            foreach ($item in $category.Items) {
                if ($item.Key -and $item.Key[0] -eq $upperKey) {
                    $this.SelectedIndex = $index
                    $this.UpdateSelectedCategory()
                    $this.SelectItem()
                    return
                }
                $index++
            }
        }
    }
}