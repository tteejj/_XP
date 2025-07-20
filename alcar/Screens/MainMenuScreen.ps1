# Main Menu Screen - Enhanced with left panel navigation

class MainMenuScreen : Screen {
    [System.Collections.ArrayList]$MenuItems
    [System.Collections.ArrayList]$MenuCategories
    [int]$SelectedIndex = 0
    [int]$SelectedCategory = 0
    [bool]$ShowCategories = $true
    [int]$ScrollOffset = 0
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
                Title = "Tasks (LazyGit Style)"
                Category = 0
                Icon = "◆"
                Key = "L"
                Action = { 
                    try {
                        Write-Host "Creating TaskScreenLazyGit..." -ForegroundColor Magenta
                        $screen = [TaskScreenLazyGit]::new()
                        Write-Host "TaskScreenLazyGit created, pushing to ScreenManager..." -ForegroundColor Magenta
                        $global:ScreenManager.Push($screen)
                        Write-Host "TaskScreenLazyGit pushed successfully" -ForegroundColor Magenta
                    } catch {
                        Write-Host "Error creating TaskScreenLazyGit: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
                    }
                }.GetNewClosure()
            },
            @{
                Title = "Projects"
                Category = 0
                Icon = "◈"
                Key = "P"
                Action = {
                    $screen = [ProjectsScreenNew]::new()
                    $global:ScreenManager.Push($screen)
                }.GetNewClosure()
            },
            @{
                Title = "Kanban Board"
                Category = 0
                Icon = "⚡"
                Key = "K"
                Action = {
                    $screen = [KanbanScreen]::new()
                    $global:ScreenManager.Push($screen)
                }.GetNewClosure()
            },
            @{
                Title = "Time Tracking"
                Category = 0
                Icon = "⏱"
                Key = "M"
                Action = {
                    $screen = [TimeTrackingScreen]::new()
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
            @{
                Title = "New Project"
                Category = 0
                Icon = "◈"
                Key = "N"
                Action = {
                    $projectService = $global:ServiceContainer.GetService("ProjectService")
                    $screen = New-Object ProjectCreationDialog -ArgumentList $projectService
                    $global:ScreenManager.PushModal($screen)
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
                }.GetNewClosure()
            },
            @{
                Title = "Simple Text Editor"
                Category = 1
                Icon = "◆"
                Key = "E"
                Action = {
                    $screen = [SimpleTextEditor]::new()
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
        # STANDARDIZED NAVIGATION:
        # Up/Down: Navigate within current list
        $this.BindKey([ConsoleKey]::UpArrow, { $this.MoveUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.MoveDown(); $this.RequestRender() })
        
        # Left/Right: Left for categories, Right to select/activate
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.MoveCategoryUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.SelectItem() })
        
        # Standard actions
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
        # Remove bottom help text as requested
        $this.StatusBarItems.Clear()
    }
    
    # Fast string rendering - maximum performance like TaskScreen
    [string] RenderContent() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Clear screen efficiently  
        $output += [VT]::Clear()
        
        # Draw border
        $output += $this.DrawBorder()
        
        # Draw title
        $output += $this.DrawCompactTitle()
        
        # Draw left panel
        $leftPanelWidth = 30
        $output += $this.DrawLeftPanel($leftPanelWidth, $height)
        
        # Draw right content
        $output += $this.DrawRightContent($leftPanelWidth + 2, $width - $leftPanelWidth - 3, $height)
        
        return $output
    }
    
    # Buffer-based drawing methods
    [void] DrawBorderToBuffer([Buffer]$buffer) {
        $borderColor = "#646464"
        
        # Top border
        $buffer.SetCell(0, 0, '╔', $borderColor, "#1E1E23")
        for ($x = 1; $x -lt $buffer.Width - 1; $x++) {
            $buffer.SetCell($x, 0, '═', $borderColor, "#1E1E23")
        }
        $buffer.SetCell($buffer.Width - 1, 0, '╗', $borderColor, "#1E1E23")
        
        # Sides
        for ($y = 1; $y -lt $buffer.Height - 1; $y++) {
            $buffer.SetCell(0, $y, '║', $borderColor, "#1E1E23")
            $buffer.SetCell($buffer.Width - 1, $y, '║', $borderColor, "#1E1E23")
        }
        
        # Bottom border
        $buffer.SetCell(0, $buffer.Height - 1, '╚', $borderColor, "#1E1E23")
        for ($x = 1; $x -lt $buffer.Width - 1; $x++) {
            $buffer.SetCell($x, $buffer.Height - 1, '═', $borderColor, "#1E1E23")
        }
        $buffer.SetCell($buffer.Width - 1, $buffer.Height - 1, '╝', $borderColor, "#1E1E23")
    }
    
    [void] DrawCompactTitleToBuffer([Buffer]$buffer) {
        $title = "═══╡ A L C A R ╞═══"
        $x = [Math]::Max(1, [int](($buffer.Width - $title.Length) / 2))
        for ($i = 0; $i -lt $title.Length; $i++) {
            $buffer.SetCell($x + $i, 1, $title[$i], "#64C8FF", "#1E1E23")
        }
    }
    
    [void] DrawLeftPanelToBuffer([Buffer]$buffer, [int]$panelWidth) {
        # Panel border
        for ($y = 3; $y -lt $buffer.Height - 1; $y++) {
            $buffer.SetCell($panelWidth, $y, '│', "#505078", "#1E1E23")
        }
        
        # Menu items
        $menuY = 4
        $itemIndex = 0
        
        for ($categoryIndex = 0; $categoryIndex -lt $this.MenuCategories.Count; $categoryIndex++) {
            $category = $this.MenuCategories[$categoryIndex]
            # Category header
            $categoryText = if ($this.SelectedCategory -eq $categoryIndex) {
                "▼ $($category.Name)"
            } else {
                "▶ $($category.Name)"
            }
            $categoryColor = if ($this.SelectedCategory -eq $categoryIndex) {
                "#96C8FF"
            } else {
                "#646496"
            }
            
            $buffer.WriteString(2, $menuY, $categoryText, $categoryColor, "#1E1E23")
            $menuY += 2
            
            # Show items if category is selected or all categories are shown
            if ($this.ShowCategories -or $this.SelectedCategory -eq $categoryIndex) {
                foreach ($item in $category.Items) {
                    $isSelected = ($itemIndex -eq $this.SelectedIndex)
                    
                    if ($isSelected) {
                        # Highlight bar
                        for ($x = 1; $x -lt $panelWidth; $x++) {
                            $buffer.SetCell($x, $menuY, ' ', "#FFFFFF", "#282850")
                        }
                        
                        $itemText = "$($item.Icon) $($item.Title)"
                        $buffer.WriteString(4, $menuY, $itemText, "#FFFFFF", "#282850")
                        
                        # Key hint
                        if ($item.Key) {
                            $keyText = "[$($item.Key)]"
                            $buffer.WriteString($panelWidth - 4, $menuY, $keyText, "#C8C864", "#282850")
                        }
                    } else {
                        $itemText = "$($item.Icon) $($item.Title)"
                        $buffer.WriteString(4, $menuY, $itemText, "#969696", "#1E1E23")
                        
                        # Key hint (dimmed)
                        if ($item.Key) {
                            $keyText = "[$($item.Key)]"
                            $buffer.WriteString($panelWidth - 4, $menuY, $keyText, "#505050", "#1E1E23")
                        }
                    }
                    
                    $menuY++
                    $itemIndex++
                }
                $menuY++ # Extra space after category
            }
        }
    }
    
    [void] DrawRightContentToBuffer([Buffer]$buffer, [int]$startX, [int]$contentWidth) {
        # Get selected item details
        $selectedItem = $this.GetSelectedItem()
        if (-not $selectedItem) { return }
        
        # Draw selection preview/info
        $centerY = [int]($buffer.Height / 2) - 5
        $centerX = $startX + [int]($contentWidth / 2)
        
        # Item icon (large)
        $largeIcon = if ($selectedItem.Icon) { $selectedItem.Icon } else { "◆" }
        
        # Draw large version
        for ($i = 0; $i -lt 3; $i++) {
            $iconText = "  $largeIcon $largeIcon $largeIcon  "
            $buffer.WriteString($centerX - 6, $centerY + $i, $iconText, "#64C8FF", "#1E1E23")
        }
        
        # Item title
        $titleText = $selectedItem.Title.ToUpper()
        $titleX = $centerX - [int]($titleText.Length / 2)
        $buffer.WriteString($titleX, $centerY + 5, $titleText, "#FFFFFF", "#1E1E23")
        
        # Hint text
        $hint = if ($selectedItem.Key) {
            "Press Enter or '$($selectedItem.Key)' to launch"
        } else {
            "Press Enter to launch"
        }
        $hintX = $centerX - [int]($hint.Length / 2)
        $buffer.WriteString($hintX, $centerY + 7, $hint, "#969696", "#1E1E23")
    }
    
    [string] DrawCompactTitle() {
        $width = [Console]::WindowWidth
        $output = ""
        
        # ASCII Art ALCAR title with cool effects
        $asciiTitle = @(
            "  ██████╗ ██╗      ██████╗ ██████╗ ██████╗ ",
            " ██╔══██╗██║     ██╔════╝██╔══██╗██╔══██╗",
            " ███████║██║     ██║     ███████║██████╔╝",
            " ██╔══██║██║     ██║     ██╔══██║██╔══██╗",
            " ██║  ██║███████╗╚██████╗██║  ██║██║  ██║",
            " ╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝"
        )
        
        $startY = 2
        for ($i = 0; $i -lt $asciiTitle.Count; $i++) {
            $line = $asciiTitle[$i]
            $x = [Math]::Max(1, [int](($width - $line.Length) / 2))
            $output += [VT]::MoveTo($x, $startY + $i)
            # Gradient effect - blue to cyan
            $color = switch ($i) {
                0 { [VT]::RGB(64, 128, 255) }
                1 { [VT]::RGB(80, 160, 255) }
                2 { [VT]::RGB(96, 192, 255) }
                3 { [VT]::RGB(112, 224, 255) }
                4 { [VT]::RGB(128, 255, 255) }
                5 { [VT]::RGB(144, 255, 240) }
            }
            $output += $color + $line + [VT]::Reset()
        }
        
        return $output
    }
    
    [string] DrawLeftPanel([int]$panelWidth, [int]$panelHeight) {
        $output = ""
        
        # Panel border
        for ($y = 4; $y -lt $panelHeight - 1; $y++) {
            $output += [VT]::MoveTo($panelWidth, $y)
            $output += [VT]::RGB(80, 80, 120) + "│" + [VT]::Reset()
        }
        
        # Menu items - start after ASCII title
        $menuY = 10
        $itemIndex = 0
        $displayedItems = 0
        $maxDisplayItems = $panelHeight - 15  # Leave room for title and borders
        
        for ($categoryIndex = 0; $categoryIndex -lt $this.MenuCategories.Count; $categoryIndex++) {
            $category = $this.MenuCategories[$categoryIndex]
            
            # Skip items before scroll offset
            $categoryItemCount = $category.Items.Count
            if ($itemIndex + $categoryItemCount -le $this.ScrollOffset) {
                $itemIndex += $categoryItemCount
                continue
            }
            
            # Category header (if visible)
            if ($itemIndex -ge $this.ScrollOffset -and $displayedItems -lt $maxDisplayItems) {
                $output += [VT]::MoveTo(3, $menuY)
                if ($this.SelectedCategory -eq $categoryIndex) {
                    $output += [VT]::RGB(150, 200, 255) + "▼ " + $category.Name + [VT]::Reset()
                } else {
                    $output += [VT]::RGB(100, 100, 150) + "▶ " + $category.Name + [VT]::Reset()
                }
                $menuY += 2
                $displayedItems++
            }
            
            # Show items if category is selected or all categories are shown
            if ($this.ShowCategories -or $this.SelectedCategory -eq $categoryIndex) {
                foreach ($item in $category.Items) {
                    # Check if this item should be displayed
                    if ($itemIndex -ge $this.ScrollOffset -and $displayedItems -lt $maxDisplayItems) {
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
                        $displayedItems++
                    }
                    $itemIndex++
                }
                if ($displayedItems -lt $maxDisplayItems) {
                    $menuY++ # Extra space after category
                    $displayedItems++
                }
            } else {
                # Skip items in collapsed categories
                $itemIndex += $categoryItemCount
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
        $this.EnsureVisible()
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
        $this.EnsureVisible()
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
                    $this.EnsureVisible()
                    $this.SelectItem()
                    return
                }
                $index++
            }
        }
    }
    
    [void] EnsureVisible() {
        $maxVisibleItems = [Console]::WindowHeight - 15  # Account for title and borders
        if ($maxVisibleItems -lt 5) { $maxVisibleItems = 5 }
        
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $maxVisibleItems) {
            $this.ScrollOffset = $this.SelectedIndex - $maxVisibleItems + 1
        }
    }
}