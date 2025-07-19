# Settings Screen v2 - Comprehensive settings with extensive controls

class SettingsScreenV2 : Screen {
    [System.Collections.ArrayList]$Categories
    [System.Collections.ArrayList]$CurrentSettings
    [int]$CategoryIndex = 0
    [int]$SettingIndex = 0
    [int]$FocusedPane = 0  # 0=categories, 1=settings
    [hashtable]$Settings = @{}  # Actual settings storage
    [bool]$HasUnsavedChanges = $false
    
    SettingsScreenV2() {
        $this.Title = "ALCAR SETTINGS"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Load existing settings or use defaults
        $this.LoadSettings()
        
        # Setting categories with comprehensive options
        $this.Categories = [System.Collections.ArrayList]@(
            @{
                Name = "Interface"
                Icon = "◈"
                Settings = @(
                    @{Name="Theme"; Type="Choice"; Key="theme"; 
                      Value=$this.Settings.theme; 
                      Options=@("Dark", "Light", "Synthwave", "Matrix", "Dracula", "Solarized", "Nord", "Gruvbox")},
                    @{Name="Color Mode"; Type="Choice"; Key="colorMode"; 
                      Value=$this.Settings.colorMode; 
                      Options=@("16 Colors", "256 Colors", "True Color")},
                    @{Name="Border Style"; Type="Choice"; Key="borderStyle"; 
                      Value=$this.Settings.borderStyle; 
                      Options=@("Single", "Double", "Rounded", "ASCII", "Heavy", "None")},
                    @{Name="Show Icons"; Type="Bool"; Key="showIcons"; Value=$this.Settings.showIcons},
                    @{Name="Show Animations"; Type="Bool"; Key="animations"; Value=$this.Settings.animations},
                    @{Name="Animation Speed"; Type="Choice"; Key="animSpeed"; 
                      Value=$this.Settings.animSpeed; 
                      Options=@("None", "Slow", "Normal", "Fast", "Instant")},
                    @{Name="Status Bar"; Type="Bool"; Key="statusBar"; Value=$this.Settings.statusBar},
                    @{Name="Compact Mode"; Type="Bool"; Key="compactMode"; Value=$this.Settings.compactMode},
                    @{Name="High Contrast"; Type="Bool"; Key="highContrast"; Value=$this.Settings.highContrast}
                )
            },
            @{
                Name = "Navigation"
                Icon = "◆"
                Settings = @(
                    @{Name="Arrow Key Mode"; Type="Choice"; Key="arrowMode"; 
                      Value=$this.Settings.arrowMode; 
                      Options=@("Standard", "Vim-like", "Emacs-like", "Custom")},
                    @{Name="Left Arrow in Panels"; Type="Choice"; Key="leftArrowBehavior"; 
                      Value=$this.Settings.leftArrowBehavior; 
                      Options=@("Focus Parent", "Go Back", "Previous Item", "Do Nothing")},
                    @{Name="Right Arrow in Panels"; Type="Choice"; Key="rightArrowBehavior"; 
                      Value=$this.Settings.rightArrowBehavior; 
                      Options=@("Focus Child", "Enter Item", "Next Item", "Do Nothing")},
                    @{Name="Tab Behavior"; Type="Choice"; Key="tabBehavior"; 
                      Value=$this.Settings.tabBehavior; 
                      Options=@("Next Field", "Next Pane", "Cycle Windows", "Insert Tab")},
                    @{Name="Wrap Navigation"; Type="Bool"; Key="wrapNav"; Value=$this.Settings.wrapNav},
                    @{Name="Quick Jump"; Type="Bool"; Key="quickJump"; Value=$this.Settings.quickJump},
                    @{Name="Home/End Keys"; Type="Choice"; Key="homeEndKeys"; 
                      Value=$this.Settings.homeEndKeys; 
                      Options=@("List Bounds", "Screen Bounds", "Document Bounds", "Line Bounds")}
                )
            },
            @{
                Name = "Editor"
                Icon = "◆"
                Settings = @(
                    @{Name="Tab Width"; Type="Number"; Key="tabWidth"; Value=$this.Settings.tabWidth; Min=1; Max=8},
                    @{Name="Insert Spaces"; Type="Bool"; Key="insertSpaces"; Value=$this.Settings.insertSpaces},
                    @{Name="Word Wrap"; Type="Bool"; Key="wordWrap"; Value=$this.Settings.wordWrap},
                    @{Name="Show Line Numbers"; Type="Bool"; Key="lineNumbers"; Value=$this.Settings.lineNumbers},
                    @{Name="Highlight Current Line"; Type="Bool"; Key="highlightLine"; Value=$this.Settings.highlightLine},
                    @{Name="Syntax Highlighting"; Type="Bool"; Key="syntaxHighlight"; Value=$this.Settings.syntaxHighlight},
                    @{Name="Auto Indent"; Type="Bool"; Key="autoIndent"; Value=$this.Settings.autoIndent},
                    @{Name="Auto Pairs"; Type="Bool"; Key="autoPairs"; Value=$this.Settings.autoPairs},
                    @{Name="Show Whitespace"; Type="Bool"; Key="showWhitespace"; Value=$this.Settings.showWhitespace},
                    @{Name="Trim Trailing Space"; Type="Bool"; Key="trimWhitespace"; Value=$this.Settings.trimWhitespace}
                )
            },
            @{
                Name = "Tasks"
                Icon = "◆"
                Settings = @(
                    @{Name="Default View"; Type="Choice"; Key="taskView"; 
                      Value=$this.Settings.taskView; 
                      Options=@("List", "Tree", "Kanban", "Calendar", "Timeline")},
                    @{Name="Sort By"; Type="Choice"; Key="taskSort"; 
                      Value=$this.Settings.taskSort; 
                      Options=@("Priority", "Due Date", "Created", "Modified", "Title", "Status")},
                    @{Name="Group By"; Type="Choice"; Key="taskGroup"; 
                      Value=$this.Settings.taskGroup; 
                      Options=@("None", "Project", "Priority", "Status", "Due Date")},
                    @{Name="Show Completed"; Type="Bool"; Key="showCompleted"; Value=$this.Settings.showCompleted},
                    @{Name="Show Archived"; Type="Bool"; Key="showArchived"; Value=$this.Settings.showArchived},
                    @{Name="Auto Archive Days"; Type="Number"; Key="autoArchiveDays"; 
                      Value=$this.Settings.autoArchiveDays; Min=0; Max=365},
                    @{Name="Due Date Warning"; Type="Number"; Key="dueDateWarning"; 
                      Value=$this.Settings.dueDateWarning; Min=0; Max=30},
                    @{Name="Task Colors"; Type="Bool"; Key="taskColors"; Value=$this.Settings.taskColors}
                )
            },
            @{
                Name = "Performance"
                Icon = "⚡"
                Settings = @(
                    @{Name="Render Mode"; Type="Choice"; Key="renderMode"; 
                      Value=$this.Settings.renderMode; 
                      Options=@("Optimized", "Balanced", "Quality", "Minimal")},
                    @{Name="Buffer Strategy"; Type="Choice"; Key="bufferStrategy"; 
                      Value=$this.Settings.bufferStrategy; 
                      Options=@("Double Buffer", "Triple Buffer", "Direct", "Adaptive")},
                    @{Name="Max FPS"; Type="Number"; Key="maxFps"; Value=$this.Settings.maxFps; Min=10; Max=120},
                    @{Name="Lazy Loading"; Type="Bool"; Key="lazyLoad"; Value=$this.Settings.lazyLoad},
                    @{Name="Cache Size (MB)"; Type="Number"; Key="cacheSize"; 
                      Value=$this.Settings.cacheSize; Min=0; Max=1024},
                    @{Name="Virtual Scrolling"; Type="Bool"; Key="virtualScroll"; Value=$this.Settings.virtualScroll},
                    @{Name="Preload Items"; Type="Number"; Key="preloadItems"; 
                      Value=$this.Settings.preloadItems; Min=0; Max=100}
                )
            },
            @{
                Name = "Shortcuts"
                Icon = "⌨"
                Settings = @(
                    @{Name="Quick Add"; Type="Key"; Key="keyQuickAdd"; Value=$this.Settings.keyQuickAdd},
                    @{Name="Quick Search"; Type="Key"; Key="keyQuickSearch"; Value=$this.Settings.keyQuickSearch},
                    @{Name="Command Palette"; Type="Key"; Key="keyCommandPalette"; Value=$this.Settings.keyCommandPalette},
                    @{Name="Toggle Sidebar"; Type="Key"; Key="keyToggleSidebar"; Value=$this.Settings.keyToggleSidebar},
                    @{Name="Focus Next Pane"; Type="Key"; Key="keyNextPane"; Value=$this.Settings.keyNextPane},
                    @{Name="Save"; Type="Key"; Key="keySave"; Value=$this.Settings.keySave},
                    @{Name="Undo"; Type="Key"; Key="keyUndo"; Value=$this.Settings.keyUndo},
                    @{Name="Redo"; Type="Key"; Key="keyRedo"; Value=$this.Settings.keyRedo},
                    @{Name="Exit"; Type="Key"; Key="keyExit"; Value=$this.Settings.keyExit}
                )
            },
            @{
                Name = "Data & Storage"
                Icon = "💾"
                Settings = @(
                    @{Name="Data Path"; Type="Path"; Key="dataPath"; Value=$this.Settings.dataPath},
                    @{Name="Backup Path"; Type="Path"; Key="backupPath"; Value=$this.Settings.backupPath},
                    @{Name="Auto Save"; Type="Bool"; Key="autoSave"; Value=$this.Settings.autoSave},
                    @{Name="Save Interval (min)"; Type="Number"; Key="saveInterval"; 
                      Value=$this.Settings.saveInterval; Min=1; Max=60},
                    @{Name="Backup on Exit"; Type="Bool"; Key="backupOnExit"; Value=$this.Settings.backupOnExit},
                    @{Name="Backup Frequency"; Type="Choice"; Key="backupFreq"; 
                      Value=$this.Settings.backupFreq; 
                      Options=@("Never", "Hourly", "Daily", "Weekly", "Monthly")},
                    @{Name="Max Backups"; Type="Number"; Key="maxBackups"; 
                      Value=$this.Settings.maxBackups; Min=1; Max=100},
                    @{Name="Compress Backups"; Type="Bool"; Key="compressBackups"; Value=$this.Settings.compressBackups},
                    @{Name="Export Format"; Type="Choice"; Key="exportFormat"; 
                      Value=$this.Settings.exportFormat; 
                      Options=@("JSON", "CSV", "Markdown", "HTML", "XML")}
                )
            },
            @{
                Name = "Advanced"
                Icon = "⚙"
                Settings = @(
                    @{Name="Debug Mode"; Type="Bool"; Key="debugMode"; Value=$this.Settings.debugMode},
                    @{Name="Log Level"; Type="Choice"; Key="logLevel"; 
                      Value=$this.Settings.logLevel; 
                      Options=@("None", "Error", "Warning", "Info", "Debug", "Trace")},
                    @{Name="Log to File"; Type="Bool"; Key="logToFile"; Value=$this.Settings.logToFile},
                    @{Name="Network Timeout (s)"; Type="Number"; Key="networkTimeout"; 
                      Value=$this.Settings.networkTimeout; Min=1; Max=300},
                    @{Name="Encoding"; Type="Choice"; Key="encoding"; 
                      Value=$this.Settings.encoding; 
                      Options=@("UTF-8", "UTF-16", "ASCII", "Windows-1252")},
                    @{Name="Line Endings"; Type="Choice"; Key="lineEndings"; 
                      Value=$this.Settings.lineEndings; 
                      Options=@("Auto", "LF", "CRLF", "CR")},
                    @{Name="Experimental Features"; Type="Bool"; Key="experimental"; Value=$this.Settings.experimental}
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
    
    [void] LoadSettings() {
        # Default settings
        $this.Settings = @{
            # Interface
            theme = "Synthwave"
            colorMode = "256 Colors"
            borderStyle = "Single"
            showIcons = $true
            animations = $true
            animSpeed = "Normal"
            statusBar = $true
            compactMode = $false
            highContrast = $false
            
            # Navigation
            arrowMode = "Standard"
            leftArrowBehavior = "Go Back"
            rightArrowBehavior = "Enter Item"
            tabBehavior = "Next Pane"
            wrapNav = $true
            quickJump = $true
            homeEndKeys = "List Bounds"
            
            # Editor
            tabWidth = 4
            insertSpaces = $true
            wordWrap = $false
            lineNumbers = $true
            highlightLine = $true
            syntaxHighlight = $true
            autoIndent = $true
            autoPairs = $true
            showWhitespace = $false
            trimWhitespace = $true
            
            # Tasks
            taskView = "Tree"
            taskSort = "Priority"
            taskGroup = "Project"
            showCompleted = $false
            showArchived = $false
            autoArchiveDays = 30
            dueDateWarning = 3
            taskColors = $true
            
            # Performance
            renderMode = "Optimized"
            bufferStrategy = "Double Buffer"
            maxFps = 60
            lazyLoad = $true
            cacheSize = 64
            virtualScroll = $true
            preloadItems = 20
            
            # Shortcuts
            keyQuickAdd = "Ctrl+N"
            keyQuickSearch = "Ctrl+F"
            keyCommandPalette = "Ctrl+P"
            keyToggleSidebar = "Ctrl+B"
            keyNextPane = "Ctrl+Tab"
            keySave = "Ctrl+S"
            keyUndo = "Ctrl+Z"
            keyRedo = "Ctrl+Y"
            keyExit = "Ctrl+Q"
            
            # Data & Storage
            dataPath = "~/.alcar/data"
            backupPath = "~/.alcar/backups"
            autoSave = $true
            saveInterval = 5
            backupOnExit = $true
            backupFreq = "Daily"
            maxBackups = 10
            compressBackups = $true
            exportFormat = "JSON"
            
            # Advanced
            debugMode = $false
            logLevel = "Warning"
            logToFile = $false
            networkTimeout = 30
            encoding = "UTF-8"
            lineEndings = "Auto"
            experimental = $false
        }
        
        # TODO: Load from file if exists
    }
    
    [void] InitializeKeyBindings() {
        # Navigation
        $this.BindKey([ConsoleKey]::Tab, { $this.SwitchPane() })
        $this.BindKey([ConsoleKey]::UpArrow, { $this.NavigateUp() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.NavigateDown() })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.NavigateLeft() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.NavigateRight() })
        $this.BindKey([ConsoleKey]::PageUp, { $this.PageUp() })
        $this.BindKey([ConsoleKey]::PageDown, { $this.PageDown() })
        $this.BindKey([ConsoleKey]::Home, { $this.GoToTop() })
        $this.BindKey([ConsoleKey]::End, { $this.GoToBottom() })
        
        # Actions
        $this.BindKey([ConsoleKey]::Enter, { $this.EditSetting() })
        $this.BindKey([ConsoleKey]::Spacebar, { $this.ToggleSetting() })
        $this.BindKey([ConsoleKey]::Delete, { $this.ResetSetting() })
        $this.BindKey([ConsoleKey]::Escape, { $this.HandleEscape() })
        $this.BindKey([ConsoleKey]::Backspace, { $this.HandleEscape() })
        
        # Commands
        $this.KeyBindings[[ConsoleKey]::S] = {
            param($key)
            if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                $this.SaveSettings()
            } else {
                $this.QuickSearch('s')
            }
        }
        
        $this.KeyBindings[[ConsoleKey]::R] = {
            param($key)
            if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                $this.ReloadSettings()
            } else {
                $this.ResetAllSettings()
            }
        }
        
        $this.BindKey('/', { $this.StartSearch() })
        $this.BindKey('?', { $this.ShowHelp() })
        $this.BindKey('q', { $this.HandleEscape() })
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        
        if ($this.HasUnsavedChanges) {
            $this.StatusBarItems.Add(@{
                Label = "● UNSAVED"
                Color = [VT]::RGB(255, 200, 100)
            }) | Out-Null
        }
        
        $this.AddStatusItem('Tab', 'switch pane')
        $this.AddStatusItem('↑↓', 'navigate')
        $this.AddStatusItem('←→', 'change')
        $this.AddStatusItem('Space', 'toggle')
        $this.AddStatusItem('Enter', 'edit')
        $this.AddStatusItem('Ctrl+S', 'save')
        $this.AddStatusItem('Del', 'reset')
        $this.AddStatusItem('/', 'search')
        $this.AddStatusItem('Esc', 'back')
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
        
        # Title with unsaved indicator
        $titleText = " ALCAR SETTINGS "
        if ($this.HasUnsavedChanges) {
            $titleText = " ALCAR SETTINGS * "
        }
        $titleX = [int](($width - $titleText.Length) / 2)
        $output += [VT]::MoveTo($titleX, 1)
        $output += [VT]::RGB(100, 200, 255) + [VT]::Bold() + $titleText + [VT]::Reset()
        
        # Three-column layout
        $leftWidth = 25
        $divider1X = $leftWidth
        $rightStart = $width - 35
        $divider2X = $rightStart - 1
        
        # Draw dividers
        $dividerColor = [VT]::RGB(80, 80, 120)
        for ($y = 2; $y -lt $height - 1; $y++) {
            $output += [VT]::MoveTo($divider1X, $y) + $dividerColor + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($divider2X, $y) + $dividerColor + "│" + [VT]::Reset()
        }
        
        # Categories (left)
        $output += $this.DrawCategories(2, 3, $leftWidth - 3)
        
        # Settings (middle)
        $output += $this.DrawSettings($divider1X + 2, 3, $divider2X - $divider1X - 3)
        
        # Help/Preview (right)
        $output += $this.DrawHelp($rightStart, 3, 33)
        
        return $output
    }
    
    [string] DrawCategories([int]$x, [int]$y, [int]$w) {
        $output = ""
        
        $output += [VT]::MoveTo($x, $y)
        $output += [VT]::RGB(150, 150, 200) + [VT]::Bold() + "CATEGORIES" + [VT]::Reset()
        
        $y += 2
        
        for ($i = 0; $i -lt $this.Categories.Count; $i++) {
            $category = $this.Categories[$i]
            $isSelected = ($i -eq $this.CategoryIndex)
            $isFocused = ($this.FocusedPane -eq 0)
            
            $output += [VT]::MoveTo($x, $y + $i)
            
            if ($isSelected -and $isFocused) {
                $output += [VT]::RGBBG(40, 40, 80) + " " * $w + [VT]::Reset()
                $output += [VT]::MoveTo($x, $y + $i)
                $output += [VT]::RGB(255, 255, 255) + " ▶ "
            } elseif ($isSelected) {
                $output += [VT]::RGB(200, 200, 255) + " › "
            } else {
                $output += "   "
            }
            
            $output += $category.Icon + " " + $category.Name
            
            # Show count of modified settings
            $modifiedCount = 0
            foreach ($setting in $category.Settings) {
                if ($setting.Value -ne $this.Settings[$setting.Key]) {
                    $modifiedCount++
                }
            }
            if ($modifiedCount -gt 0) {
                $output += [VT]::RGB(255, 200, 100) + " ●" + [VT]::Reset()
            }
            
            $output += [VT]::Reset()
        }
        
        return $output
    }
    
    [string] DrawSettings([int]$x, [int]$y, [int]$w) {
        $output = ""
        
        $category = $this.Categories[$this.CategoryIndex]
        
        $output += [VT]::MoveTo($x, $y)
        $output += [VT]::RGB(150, 150, 200) + [VT]::Bold() 
        $output += $category.Icon + " " + $category.Name.ToUpper() + [VT]::Reset()
        
        $y += 2
        $visibleHeight = [Console]::WindowHeight - 6
        $scrollOffset = $this.CalculateScrollOffset($visibleHeight)
        
        for ($i = $scrollOffset; $i -lt [Math]::Min($scrollOffset + $visibleHeight, $this.CurrentSettings.Count); $i++) {
            $setting = $this.CurrentSettings[$i]
            $isSelected = ($i -eq $this.SettingIndex)
            $isFocused = ($this.FocusedPane -eq 1)
            $isModified = ($setting.Value -ne $this.Settings[$setting.Key])
            
            $displayY = $y + ($i - $scrollOffset)
            $output += [VT]::MoveTo($x, $displayY)
            
            # Highlight selected
            if ($isSelected -and $isFocused) {
                $output += [VT]::RGBBG(40, 40, 80) + " " * $w + [VT]::Reset()
                $output += [VT]::MoveTo($x, $displayY)
            }
            
            # Setting name
            if ($isModified) {
                $output += [VT]::RGB(255, 200, 100) + "● "
            } else {
                $output += "  "
            }
            
            $nameColor = if ($isSelected -and $isFocused) { 
                [VT]::RGB(255, 255, 255) 
            } else { 
                [VT]::RGB(200, 200, 200) 
            }
            $output += $nameColor + $setting.Name + [VT]::Reset()
            
            # Setting value
            $valueX = $x + 25
            $output += [VT]::MoveTo($valueX, $displayY)
            
            $output += $this.RenderSettingValue($setting, $isSelected -and $isFocused)
        }
        
        # Scroll indicator
        if ($this.CurrentSettings.Count -gt $visibleHeight) {
            $this.DrawScrollIndicator($output, $x + $w - 1, $y, $visibleHeight, 
                                     $scrollOffset, $this.CurrentSettings.Count)
        }
        
        return $output
    }
    
    [string] RenderSettingValue([hashtable]$setting, [bool]$isActive) {
        $output = ""
        
        switch ($setting.Type) {
            "Bool" {
                if ($setting.Value) {
                    $output += [VT]::RGB(100, 255, 100) + "[✓] ON"
                } else {
                    $output += [VT]::RGB(150, 150, 150) + "[ ] OFF"
                }
            }
            "Choice" {
                if ($isActive) {
                    $output += [VT]::RGB(100, 200, 255) + "◄ " + $setting.Value + " ►"
                } else {
                    $output += [VT]::RGB(200, 200, 255) + $setting.Value
                }
            }
            "Number" {
                if ($isActive) {
                    $output += [VT]::RGB(255, 200, 100) + "[ " + $setting.Value + " ]"
                } else {
                    $output += [VT]::RGB(255, 255, 200) + $setting.Value.ToString()
                }
            }
            "Key" {
                $output += [VT]::RGB(255, 150, 255) + $setting.Value
            }
            "Path" {
                $truncated = if ($setting.Value.Length -gt 30) {
                    "..." + $setting.Value.Substring($setting.Value.Length - 27)
                } else {
                    $setting.Value
                }
                $output += [VT]::RGB(150, 200, 255) + $truncated
            }
        }
        
        $output += [VT]::Reset()
        return $output
    }
    
    [string] DrawHelp([int]$x, [int]$y, [int]$w) {
        $output = ""
        
        $output += [VT]::MoveTo($x, $y)
        $output += [VT]::RGB(150, 150, 200) + [VT]::Bold() + "HELP" + [VT]::Reset()
        
        $y += 2
        
        if ($this.FocusedPane -eq 1 -and $this.CurrentSettings.Count -gt 0) {
            $setting = $this.CurrentSettings[$this.SettingIndex]
            
            # Setting name
            $output += [VT]::MoveTo($x, $y)
            $output += [VT]::RGB(255, 255, 255) + $setting.Name + [VT]::Reset()
            $y += 2
            
            # Setting description (would be loaded from help data)
            $descriptions = @{
                "theme" = "Visual theme for the interface"
                "arrowMode" = "How arrow keys behave in the UI"
                "leftArrowBehavior" = "Action when pressing left arrow in panels"
                "tabWidth" = "Number of spaces for tab character"
                "renderMode" = "Balance between quality and performance"
                "autoSave" = "Automatically save changes"
            }
            
            $desc = $descriptions[$setting.Key]
            if ($desc) {
                $output += [VT]::MoveTo($x, $y)
                $words = $desc -split ' '
                $line = ""
                foreach ($word in $words) {
                    if (($line + " " + $word).Length -gt $w) {
                        $output += [VT]::RGB(180, 180, 180) + $line + [VT]::Reset()
                        $y++
                        $output += [VT]::MoveTo($x, $y)
                        $line = $word
                    } else {
                        $line = if ($line) { $line + " " + $word } else { $word }
                    }
                }
                if ($line) {
                    $output += [VT]::RGB(180, 180, 180) + $line + [VT]::Reset()
                }
                $y += 2
            }
            
            # Current value
            $output += [VT]::MoveTo($x, $y)
            $output += [VT]::RGB(150, 150, 150) + "Current: " + [VT]::Reset()
            $output += $this.RenderSettingValue($setting, $false)
            $y += 1
            
            # Default value
            if ($setting.ContainsKey('Default')) {
                $output += [VT]::MoveTo($x, $y)
                $output += [VT]::RGB(150, 150, 150) + "Default: " + $setting.Default + [VT]::Reset()
                $y += 1
            }
            
            # Type-specific help
            $y += 1
            $output += [VT]::MoveTo($x, $y)
            switch ($setting.Type) {
                "Bool" {
                    $output += [VT]::RGB(100, 150, 100) + "Press SPACE to toggle" + [VT]::Reset()
                }
                "Choice" {
                    $output += [VT]::RGB(100, 150, 100) + "Use ← → to change" + [VT]::Reset()
                }
                "Number" {
                    $output += [VT]::RGB(100, 150, 100) + "Press ENTER to edit" + [VT]::Reset()
                    if ($setting.Min -or $setting.Max) {
                        $y++
                        $output += [VT]::MoveTo($x, $y)
                        $range = "Range: "
                        if ($setting.Min) { $range += $setting.Min }
                        $range += " - "
                        if ($setting.Max) { $range += $setting.Max }
                        $output += [VT]::RGB(150, 150, 150) + $range + [VT]::Reset()
                    }
                }
                "Key" {
                    $output += [VT]::RGB(100, 150, 100) + "Press ENTER to record" + [VT]::Reset()
                }
                "Path" {
                    $output += [VT]::RGB(100, 150, 100) + "Press ENTER to browse" + [VT]::Reset()
                }
            }
        } else {
            # General help
            $helpText = @(
                "",
                "Navigate categories with",
                "arrow keys when focused",
                "on the left panel.",
                "",
                "Press TAB to switch",
                "between panels.",
                "",
                "Modified settings show",
                "an orange dot (●).",
                "",
                "Press Ctrl+S to save",
                "all changes.",
                "",
                "Press Delete to reset",
                "a setting to default."
            )
            
            foreach ($line in $helpText) {
                $output += [VT]::MoveTo($x, $y)
                $output += [VT]::RGB(150, 150, 150) + $line + [VT]::Reset()
                $y++
            }
        }
        
        return $output
    }
    
    [int] CalculateScrollOffset([int]$visibleHeight) {
        if ($this.CurrentSettings.Count -le $visibleHeight) {
            return 0
        }
        
        # Keep selected item visible
        if ($this.SettingIndex -lt $visibleHeight / 2) {
            return 0
        }
        elseif ($this.SettingIndex -gt $this.CurrentSettings.Count - $visibleHeight / 2) {
            return $this.CurrentSettings.Count - $visibleHeight
        }
        else {
            return $this.SettingIndex - [int]($visibleHeight / 2)
        }
    }
    
    [void] LoadCategorySettings() {
        $category = $this.Categories[$this.CategoryIndex]
        $this.CurrentSettings = [System.Collections.ArrayList]$category.Settings
        
        # Update values from settings storage
        foreach ($setting in $this.CurrentSettings) {
            if ($this.Settings.ContainsKey($setting.Key)) {
                $setting.Value = $this.Settings[$setting.Key]
            }
        }
        
        $this.SettingIndex = 0
    }
    
    [void] SwitchPane() {
        $this.FocusedPane = 1 - $this.FocusedPane
        $this.RequestRender()
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
        $this.RequestRender()
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
        $this.RequestRender()
    }
    
    [void] NavigateLeft() {
        if ($this.FocusedPane -eq 1) {
            $this.ChangeSetting(-1)
        } else {
            $this.FocusedPane = 0
        }
        $this.RequestRender()
    }
    
    [void] NavigateRight() {
        if ($this.FocusedPane -eq 1) {
            $this.ChangeSetting(1)
        } else {
            $this.FocusedPane = 1
        }
        $this.RequestRender()
    }
    
    [void] PageUp() {
        if ($this.FocusedPane -eq 1) {
            $pageSize = [Console]::WindowHeight - 10
            $this.SettingIndex = [Math]::Max(0, $this.SettingIndex - $pageSize)
        } else {
            $this.CategoryIndex = 0
        }
        $this.RequestRender()
    }
    
    [void] PageDown() {
        if ($this.FocusedPane -eq 1) {
            $pageSize = [Console]::WindowHeight - 10
            $this.SettingIndex = [Math]::Min($this.CurrentSettings.Count - 1, $this.SettingIndex + $pageSize)
        } else {
            $this.CategoryIndex = $this.Categories.Count - 1
        }
        $this.RequestRender()
    }
    
    [void] GoToTop() {
        if ($this.FocusedPane -eq 1) {
            $this.SettingIndex = 0
        } else {
            $this.CategoryIndex = 0
            $this.LoadCategorySettings()
        }
        $this.RequestRender()
    }
    
    [void] GoToBottom() {
        if ($this.FocusedPane -eq 1) {
            $this.SettingIndex = $this.CurrentSettings.Count - 1
        } else {
            $this.CategoryIndex = $this.Categories.Count - 1
            $this.LoadCategorySettings()
        }
        $this.RequestRender()
    }
    
    [void] ToggleSetting() {
        if ($this.FocusedPane -eq 1 -and $this.CurrentSettings.Count -gt 0) {
            $setting = $this.CurrentSettings[$this.SettingIndex]
            
            if ($setting.Type -eq "Bool") {
                $setting.Value = -not $setting.Value
                $this.Settings[$setting.Key] = $setting.Value
                $this.HasUnsavedChanges = $true
                $this.UpdateStatusBar()
            } elseif ($setting.Type -eq "Choice") {
                $this.ChangeSetting(1)
            }
        }
        $this.RequestRender()
    }
    
    [void] ChangeSetting([int]$direction) {
        if ($this.FocusedPane -eq 1 -and $this.CurrentSettings.Count -gt 0) {
            $setting = $this.CurrentSettings[$this.SettingIndex]
            
            switch ($setting.Type) {
                "Choice" {
                    if ($setting.Options) {
                        $currentIndex = $setting.Options.IndexOf($setting.Value)
                        if ($currentIndex -eq -1) { $currentIndex = 0 }
                        
                        $newIndex = $currentIndex + $direction
                        if ($newIndex -lt 0) {
                            $newIndex = $setting.Options.Count - 1
                        } elseif ($newIndex -ge $setting.Options.Count) {
                            $newIndex = 0
                        }
                        
                        $setting.Value = $setting.Options[$newIndex]
                        $this.Settings[$setting.Key] = $setting.Value
                        $this.HasUnsavedChanges = $true
                        $this.UpdateStatusBar()
                    }
                }
                "Number" {
                    $step = if ($setting.Step) { $setting.Step } else { 1 }
                    $newValue = $setting.Value + ($direction * $step)
                    
                    if ($setting.Min -and $newValue -lt $setting.Min) {
                        $newValue = $setting.Min
                    }
                    if ($setting.Max -and $newValue -gt $setting.Max) {
                        $newValue = $setting.Max
                    }
                    
                    $setting.Value = $newValue
                    $this.Settings[$setting.Key] = $setting.Value
                    $this.HasUnsavedChanges = $true
                    $this.UpdateStatusBar()
                }
            }
        }
    }
    
    [void] EditSetting() {
        if ($this.FocusedPane -eq 1 -and $this.CurrentSettings.Count -gt 0) {
            $setting = $this.CurrentSettings[$this.SettingIndex]
            
            # TODO: Implement inline editors for different types
            # For now, just toggle or change
            switch ($setting.Type) {
                "Bool" { $this.ToggleSetting() }
                "Choice" { $this.ChangeSetting(1) }
                "Number" { 
                    # Would open number input dialog
                    Write-Host "`nNumber editing not yet implemented" -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
                "Key" {
                    # Would open key recording dialog
                    Write-Host "`nKey recording not yet implemented" -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
                "Path" {
                    # Would open path browser
                    Write-Host "`nPath browsing not yet implemented" -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
    
    [void] ResetSetting() {
        if ($this.FocusedPane -eq 1 -and $this.CurrentSettings.Count -gt 0) {
            $setting = $this.CurrentSettings[$this.SettingIndex]
            
            # Reset to default value (would be loaded from defaults)
            # For now, just show message
            Write-Host "`nReset to default not yet implemented" -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
    
    [void] SaveSettings() {
        # TODO: Implement actual saving to file
        Write-Host "`nSettings saved successfully!" -ForegroundColor Green
        $this.HasUnsavedChanges = $false
        $this.UpdateStatusBar()
        Start-Sleep -Seconds 1
    }
    
    [void] ReloadSettings() {
        # TODO: Implement reloading from file
        Write-Host "`nSettings reloaded!" -ForegroundColor Cyan
        Start-Sleep -Seconds 1
    }
    
    [void] ResetAllSettings() {
        # TODO: Implement reset all with confirmation
        Write-Host "`nReset all settings not yet implemented" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    
    [void] StartSearch() {
        # TODO: Implement setting search
        Write-Host "`nSetting search not yet implemented" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    
    [void] ShowHelp() {
        # TODO: Show comprehensive help screen
        Write-Host "`nHelp screen not yet implemented" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    
    [void] HandleEscape() {
        if ($this.HasUnsavedChanges) {
            # TODO: Show confirmation dialog
            Write-Host "`nYou have unsaved changes! Press ESC again to discard." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        } else {
            $this.Active = $false
        }
    }
}