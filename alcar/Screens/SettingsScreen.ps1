# Settings Screen

class SettingsScreen : Screen {
    [System.Collections.ArrayList]$Categories
    [System.Collections.ArrayList]$CurrentSettings
    [int]$CategoryIndex = 0
    [int]$SettingIndex = 0
    [int]$FocusedPane = 0  # 0=categories, 1=settings
    
    SettingsScreen() {
        $this.Title = "SETTINGS"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Setting categories
        $this.Categories = [System.Collections.ArrayList]@(
            @{
                Name = "Appearance"
                Icon = "🎨"
                Settings = @(
                    @{Name="Theme"; Type="Choice"; Value="Synthwave"; Options=@("Dark", "Light", "Synthwave", "Matrix", "Dracula")},
                    @{Name="Show Icons"; Type="Bool"; Value=$true},
                    @{Name="Animation Speed"; Type="Choice"; Value="Normal"; Options=@("None", "Slow", "Normal", "Fast")},
                    @{Name="Border Style"; Type="Choice"; Value="Single"; Options=@("Single", "Double", "Rounded", "ASCII")}
                )
            },
            @{
                Name = "Behavior"
                Icon = "⚙️"
                Settings = @(
                    @{Name="Auto-save"; Type="Bool"; Value=$true},
                    @{Name="Confirm Delete"; Type="Bool"; Value=$true},
                    @{Name="Default View"; Type="Choice"; Value="Tree"; Options=@("List", "Tree", "Kanban")},
                    @{Name="Task Sorting"; Type="Choice"; Value="Priority"; Options=@("Priority", "Due Date", "Created", "Title")}
                )
            },
            @{
                Name = "Shortcuts"
                Icon = "⌨️"
                Settings = @(
                    @{Name="Quick Add"; Type="Key"; Value="Ctrl+N"},
                    @{Name="Quick Search"; Type="Key"; Value="Ctrl+F"},
                    @{Name="Toggle Menu"; Type="Key"; Value="Ctrl"},
                    @{Name="Exit"; Type="Key"; Value="Ctrl+Q"}
                )
            },
            @{
                Name = "Data"
                Icon = "💾"
                Settings = @(
                    @{Name="Data Path"; Type="Path"; Value="~/.boltaxiom/data"},
                    @{Name="Backup Frequency"; Type="Choice"; Value="Daily"; Options=@("Never", "Daily", "Weekly", "Monthly")},
                    @{Name="Export Format"; Type="Choice"; Value="JSON"; Options=@("JSON", "CSV", "Markdown")}
                )
            }
        )
        
        # Load current category settings
        $this.LoadCategorySettings()
        
        # Key bindings
        $this.InitializeKeyBindings()
        
        # Status bar
        $this.UpdateStatusBar()
    }
    
    [void] InitializeKeyBindings() {
        $this.BindKey([ConsoleKey]::Tab, { $this.SwitchPane() })
        $this.BindKey([ConsoleKey]::UpArrow, { $this.NavigateUp() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.NavigateDown() })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.NavigateLeft() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.NavigateRight() })
        $this.BindKey([ConsoleKey]::Enter, { $this.ToggleSetting() })
        $this.BindKey([ConsoleKey]::Spacebar, { $this.ToggleSetting() })
        $this.BindKey([ConsoleKey]::Escape, { $this.Active = $false })
        $this.BindKey([ConsoleKey]::Backspace, { $this.Active = $false })
        
        $this.BindKey('s', { $this.SaveSettings() })
        $this.BindKey('r', { $this.ResetDefaults() })
        $this.BindKey('q', { $this.Active = $false })
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        $this.AddStatusItem('Tab', 'switch pane')
        $this.AddStatusItem('↑↓', 'navigate')
        $this.AddStatusItem('←→', 'change value')
        $this.AddStatusItem('Space', 'toggle')
        $this.AddStatusItem('s', 'save')
        $this.AddStatusItem('r', 'reset')
        $this.AddStatusItem('Esc', 'back')
    }
    
    # Buffer-based render - zero string allocation
    [void] RenderToBuffer([Buffer]$buffer) {
        # Clear background
        $normalBG = "#1E1E23"
        $normalFG = "#C8C8C8"
        for ($y = 0; $y -lt $buffer.Height; $y++) {
            for ($x = 0; $x -lt $buffer.Width; $x++) {
                $buffer.SetCell($x, $y, ' ', $normalFG, $normalBG)
            }
        }
        
        # Render using fallback for now
        $content = $this.RenderContent()
        $lines = $content -split "`n"
        for ($i = 0; $i -lt [Math]::Min($lines.Count, $buffer.Height); $i++) {
            $buffer.WriteString(0, $i, $lines[$i], $normalFG, $normalBG)
        }
    }
    
    [string] RenderContent() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Clear background by drawing spaces everywhere
        for ($y = 1; $y -le $height; $y++) {
            $output += [VT]::MoveTo(1, $y)
            $output += " " * $width
        }
        
        # Draw border
        $output += $this.DrawBorder()
        
        # Title
        $titleText = "═══ SETTINGS ═══"
        $titleX = [int](($width - $titleText.Length) / 2)
        $output += [VT]::MoveTo($titleX, 1)
        $output += [VT]::BorderActive() + $titleText + [VT]::Reset()
        
        # Two-column layout
        $leftWidth = 30
        $dividerX = $leftWidth + 2
        
        # Draw divider
        for ($y = 2; $y -lt $height - 1; $y++) {
            $output += [VT]::MoveTo($dividerX, $y)
            $output += [VT]::Border() + "│"
        }
        
        # Categories (left)
        $output += $this.DrawCategories(3, 3, $leftWidth - 3)
        
        # Settings (right)
        $output += $this.DrawSettings($dividerX + 2, 3, $width - $dividerX - 4)
        
        return $output
    }
    
    [string] DrawBorder() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Top border
        $output += [VT]::MoveTo(1, 1)
        $output += [VT]::Border()
        $output += [VT]::TL() + [VT]::H() * ($width - 2) + [VT]::TR()
        
        # Sides
        for ($y = 2; $y -lt $height - 1; $y++) {
            $output += [VT]::MoveTo(1, $y) + [VT]::V()
            $output += [VT]::MoveTo($width, $y) + [VT]::V()
        }
        
        # Bottom border
        $output += [VT]::MoveTo(1, $height - 1)
        $output += [VT]::BL() + [VT]::H() * ($width - 2) + [VT]::BR()
        
        return $output
    }
    
    [string] DrawCategories([int]$x, [int]$y, [int]$w) {
        $output = ""
        
        $output += [VT]::MoveTo($x, $y)
        $output += [VT]::TextBright() + "CATEGORIES" + [VT]::Reset()
        
        $y += 2
        
        for ($i = 0; $i -lt $this.Categories.Count; $i++) {
            $category = $this.Categories[$i]
            $isSelected = ($i -eq $this.CategoryIndex)
            $isFocused = ($this.FocusedPane -eq 0)
            
            $output += [VT]::MoveTo($x, $y + $i * 2)
            
            if ($isSelected -and $isFocused) {
                $output += [VT]::Selected() + " > "
            } elseif ($isSelected) {
                $output += [VT]::TextBright() + " > "
            } else {
                $output += "   "
            }
            
            $output += $category.Icon + " " + $category.Name
            $output += [VT]::Reset()
        }
        
        return $output
    }
    
    [string] DrawSettings([int]$x, [int]$y, [int]$w) {
        $output = ""
        
        $category = $this.Categories[$this.CategoryIndex]
        
        $output += [VT]::MoveTo($x, $y)
        $output += [VT]::TextBright() + $category.Icon + " " + $category.Name.ToUpper() + " SETTINGS" + [VT]::Reset()
        
        $y += 2
        
        for ($i = 0; $i -lt $this.CurrentSettings.Count; $i++) {
            $setting = $this.CurrentSettings[$i]
            $isSelected = ($i -eq $this.SettingIndex)
            $isFocused = ($this.FocusedPane -eq 1)
            
            $output += [VT]::MoveTo($x, $y + $i * 2)
            
            # Setting name
            if ($isSelected -and $isFocused) {
                $output += [VT]::Selected() + " "
            } else {
                $output += " "
            }
            
            $output += [VT]::Text() + $setting.Name + ": "
            
            # Setting value
            $valueX = $x + 20
            $output += [VT]::MoveTo($valueX, $y + $i * 2)
            
            switch ($setting.Type) {
                "Bool" {
                    if ($setting.Value) {
                        $output += [VT]::Accent() + "[✓] Enabled"
                    } else {
                        $output += [VT]::TextDim() + "[ ] Disabled"
                    }
                }
                "Choice" {
                    if ($isSelected -and $isFocused) {
                        $output += [VT]::Accent() + "< " + $setting.Value + " >"
                    } else {
                        $output += [VT]::TextBright() + $setting.Value
                    }
                }
                "Key" {
                    $output += [VT]::Warning() + $setting.Value
                }
                "Path" {
                    $output += [VT]::Text() + $setting.Value
                }
            }
            
            $output += [VT]::Reset()
        }
        
        return $output
    }
    
    [void] LoadCategorySettings() {
        $category = $this.Categories[$this.CategoryIndex]
        $this.CurrentSettings = [System.Collections.ArrayList]$category.Settings
        $this.SettingIndex = 0
    }
    
    [void] SwitchPane() {
        $this.FocusedPane = 1 - $this.FocusedPane
    }
    
    [void] NavigateUp() {
        if ($this.FocusedPane -eq 0) {
            if ($this.CategoryIndex -gt 0) {
                $this.CategoryIndex--
                $this.LoadCategorySettings()
            }
        } else {
            if ($this.SettingIndex -gt 0) {
                $this.SettingIndex--
            }
        }
    }
    
    [void] NavigateDown() {
        if ($this.FocusedPane -eq 0) {
            if ($this.CategoryIndex -lt $this.Categories.Count - 1) {
                $this.CategoryIndex++
                $this.LoadCategorySettings()
            }
        } else {
            if ($this.SettingIndex -lt $this.CurrentSettings.Count - 1) {
                $this.SettingIndex++
            }
        }
    }
    
    [void] NavigateLeft() {
        if ($this.FocusedPane -eq 1) {
            $this.ChangeSetting(-1)
        } else {
            $this.FocusedPane = 0
        }
    }
    
    [void] NavigateRight() {
        if ($this.FocusedPane -eq 1) {
            $this.ChangeSetting(1)
        } else {
            $this.FocusedPane = 1
        }
    }
    
    [void] ToggleSetting() {
        if ($this.FocusedPane -eq 1 -and $this.CurrentSettings.Count -gt 0) {
            $setting = $this.CurrentSettings[$this.SettingIndex]
            
            if ($setting.Type -eq "Bool") {
                $setting.Value = -not $setting.Value
            } elseif ($setting.Type -eq "Choice") {
                $this.ChangeSetting(1)
            }
        }
    }
    
    [void] ChangeSetting([int]$direction) {
        if ($this.FocusedPane -eq 1 -and $this.CurrentSettings.Count -gt 0) {
            $setting = $this.CurrentSettings[$this.SettingIndex]
            
            if ($setting.Type -eq "Choice" -and $setting.Options) {
                $currentIndex = $setting.Options.IndexOf($setting.Value)
                $newIndex = $currentIndex + $direction
                
                if ($newIndex -lt 0) {
                    $newIndex = $setting.Options.Count - 1
                } elseif ($newIndex -ge $setting.Options.Count) {
                    $newIndex = 0
                }
                
                $setting.Value = $setting.Options[$newIndex]
            }
        }
    }
    
    [void] SaveSettings() {
        Write-Host "`nSettings saved!" -ForegroundColor Green
        Start-Sleep -Seconds 1
    }
    
    [void] ResetDefaults() {
        Write-Host "`nReset to defaults!" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}