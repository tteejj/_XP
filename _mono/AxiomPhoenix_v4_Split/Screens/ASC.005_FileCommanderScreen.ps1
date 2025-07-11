# ==============================================================================
# Axiom-Phoenix v4.0 - File Commander - Full-Featured Terminal File Browser
# Built on Axiom-Phoenix v4.0 Framework
# ==============================================================================

class FileCommanderScreen : Screen {
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [Panel] $_leftPanel
    hidden [Panel] $_rightPanel
    hidden [Panel] $_functionBar
    hidden [Panel] $_statusBar
    hidden [Panel] $_quickViewPanel
    hidden [ListBox] $_leftFileList
    hidden [ListBox] $_rightFileList
    hidden [TextBoxComponent] $_commandLine
    hidden [LabelComponent] $_leftPathLabel
    hidden [LabelComponent] $_rightPathLabel
    hidden [LabelComponent] $_statusLabel
    hidden [LabelComponent] $_sizeLabel
    hidden [LabelComponent] $_itemCountLabel
    #endregion

    #region State
    hidden [string] $_leftPath
    hidden [string] $_rightPath
    hidden [bool] $_leftPanelActive = $true
    hidden [object[]] $_leftItems = @()
    hidden [object[]] $_rightItems = @()
    hidden [object] $_selectedItem
    hidden [hashtable] $_fileTypeIcons = @{
        ".ps1" = "🔧"
        ".txt" = "📄"
        ".md" = "📝"
        ".json" = "📊"
        ".xml" = "📋"
        ".exe" = "⚡"
        ".dll" = "📦"
        ".zip" = "🗜️"
        ".7z" = "🗜️"
        ".rar" = "🗜️"
        ".jpg" = "🖼️"
        ".png" = "🖼️"
        ".gif" = "🖼️"
        ".mp3" = "🎵"
        ".mp4" = "🎬"
        ".avi" = "🎬"
        ".mkv" = "🎬"
        ".pdf" = "📕"
        ".doc" = "📘"
        ".docx" = "📘"
        ".xls" = "📗"
        ".xlsx" = "📗"
        "folder" = "📁"
        "folderup" = "📂"
        "default" = "📄"
    }
    hidden [bool] $_showHidden = $false
    hidden [string] $_sortBy = "Name"  # Name, Size, Date, Extension
    hidden [bool] $_sortDescending = $false
    hidden [System.Collections.Generic.List[string]] $_clipboard = [System.Collections.Generic.List[string]]::new()
    hidden [bool] $_cutMode = $false  # false = copy, true = cut
    hidden [string] $_quickFilter = ""
    #endregion

    FileCommanderScreen([ServiceContainer]$container) : base("FileCommanderScreen", $container) {
        # Initialize paths safely
        try {
            $this._leftPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
            $this._rightPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        } catch {
            $this._leftPath = "C:\"
            $this._rightPath = "C:\"
        }
    }

    [void] Initialize() {
        # Main panel
        $this._mainPanel = [Panel]::new("FileCommanderMain")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.HasBorder = $false
        $this._mainPanel.BackgroundColor = Get-ThemeColor "background" "#0A0A0A"
        $this.AddChild($this._mainPanel)

        # Calculate panel dimensions
        $halfWidth = [Math]::Floor($this.Width / 2)
        $panelHeight = $this.Height - 4  # Leave room for function bar and status bar

        # Left file panel
        $this._leftPanel = [Panel]::new("LeftPanel")
        $this._leftPanel.X = 0
        $this._leftPanel.Y = 0
        $this._leftPanel.Width = $halfWidth
        $this._leftPanel.Height = $panelHeight
        $this._leftPanel.HasBorder = $true
        $this._leftPanel.BorderStyle = "Single"
        $this._leftPanel.BorderColor = Get-ThemeColor "border.active" "#00D4FF"
        $this._mainPanel.AddChild($this._leftPanel)

        # Left path label
        $this._leftPathLabel = [LabelComponent]::new("LeftPath")
        $this._leftPathLabel.X = 1
        $this._leftPathLabel.Y = 0
        $this._leftPathLabel.Width = $halfWidth - 2
        $this._leftPathLabel.Height = 1
        $this._leftPathLabel.ForegroundColor = Get-ThemeColor "path" "#FFD700"
        $this._leftPathLabel.BackgroundColor = Get-ThemeColor "panel.header" "#1A1A1A"
        $this._leftPanel.AddChild($this._leftPathLabel)

        # Left file list
        $this._leftFileList = [ListBox]::new("LeftFiles")
        $this._leftFileList.X = 1
        $this._leftFileList.Y = 1
        $this._leftFileList.Width = $halfWidth - 2
        $this._leftFileList.Height = $panelHeight - 2
        $this._leftFileList.HasBorder = $false
        # Use theme colors for selection - remove hardcoded colors
        $this._leftFileList.SelectedBackgroundColor = ""
        $this._leftFileList.SelectedForegroundColor = ""
        $this._leftFileList.ItemForegroundColor = Get-ThemeColor "file.normal" "#E0E0E0"
        $this._leftPanel.AddChild($this._leftFileList)

        # Right file panel
        $this._rightPanel = [Panel]::new("RightPanel")
        $this._rightPanel.X = $halfWidth
        $this._rightPanel.Y = 0
        $this._rightPanel.Width = $this.Width - $halfWidth
        $this._rightPanel.Height = $panelHeight
        $this._rightPanel.HasBorder = $true
        $this._rightPanel.BorderStyle = "Single"
        $this._rightPanel.BorderColor = Get-ThemeColor "border.inactive" "#666666"
        $this._mainPanel.AddChild($this._rightPanel)

        # Right path label
        $this._rightPathLabel = [LabelComponent]::new("RightPath")
        $this._rightPathLabel.X = 1
        $this._rightPathLabel.Y = 0
        $this._rightPathLabel.Width = $this._rightPanel.Width - 2
        $this._rightPathLabel.Height = 1
        $this._rightPathLabel.ForegroundColor = Get-ThemeColor "path" "#FFD700"
        $this._rightPathLabel.BackgroundColor = Get-ThemeColor "panel.header" "#1A1A1A"
        $this._rightPanel.AddChild($this._rightPathLabel)

        # Right file list
        $this._rightFileList = [ListBox]::new("RightFiles")
        $this._rightFileList.X = 1
        $this._rightFileList.Y = 1
        $this._rightFileList.Width = $this._rightPanel.Width - 2
        $this._rightFileList.Height = $panelHeight - 2
        $this._rightFileList.HasBorder = $false
        # Use theme colors for selection - remove hardcoded colors  
        $this._rightFileList.SelectedBackgroundColor = ""
        $this._rightFileList.SelectedForegroundColor = ""
        $this._rightFileList.ItemForegroundColor = Get-ThemeColor "file.normal" "#E0E0E0"
        $this._rightPanel.AddChild($this._rightFileList)

        # Status bar
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 0
        $this._statusBar.Y = $panelHeight
        $this._statusBar.Width = $this.Width
        $this._statusBar.Height = 2
        $this._statusBar.HasBorder = $false
        $this._statusBar.BackgroundColor = Get-ThemeColor "statusbar.bg" "#1A1A1A"
        $this._mainPanel.AddChild($this._statusBar)

        # Status label
        $this._statusLabel = [LabelComponent]::new("Status")
        $this._statusLabel.X = 1
        $this._statusLabel.Y = 0
        $this._statusLabel.Width = 60
        $this._statusLabel.Height = 1
        $this._statusLabel.ForegroundColor = Get-ThemeColor "status.text" "#00FF88"
        $this._statusBar.AddChild($this._statusLabel)

        # Size label
        $this._sizeLabel = [LabelComponent]::new("Size")
        $this._sizeLabel.X = 62
        $this._sizeLabel.Y = 0
        $this._sizeLabel.Width = 20
        $this._sizeLabel.Height = 1
        $this._sizeLabel.ForegroundColor = Get-ThemeColor "size.text" "#FFD700"
        $this._statusBar.AddChild($this._sizeLabel)

        # Item count label
        $this._itemCountLabel = [LabelComponent]::new("ItemCount")
        $this._itemCountLabel.X = $this.Width - 25
        $this._itemCountLabel.Y = 0
        $this._itemCountLabel.Width = 24
        $this._itemCountLabel.Height = 1
        $this._itemCountLabel.ForegroundColor = Get-ThemeColor "count.text" "#00D4FF"
        $this._statusBar.AddChild($this._itemCountLabel)

        # Function key bar
        $this._functionBar = [Panel]::new("FunctionBar")
        $this._functionBar.X = 0
        $this._functionBar.Y = $this.Height - 2
        $this._functionBar.Width = $this.Width
        $this._functionBar.Height = 2
        $this._functionBar.HasBorder = $false
        $this._functionBar.BackgroundColor = Get-ThemeColor "function.bg" "#0D47A1"
        $this._mainPanel.AddChild($this._functionBar)

        # Function key labels
        $functions = @(
            @{Key="F1"; Text="Help"; X=0},
            @{Key="F2"; Text="Menu"; X=10},
            @{Key="F3"; Text="View"; X=20},
            @{Key="F4"; Text="Edit"; X=30},
            @{Key="F5"; Text="Copy"; X=40},
            @{Key="F6"; Text="Move"; X=50},
            @{Key="F7"; Text="MkDir"; X=60},
            @{Key="F8"; Text="Delete"; X=70},
            @{Key="F9"; Text="Menu"; X=80},
            @{Key="F10"; Text="Quit"; X=90}
        )

        foreach ($func in $functions) {
            $keyLabel = [LabelComponent]::new("F$($func.Key)")
            $keyLabel.X = $func.X
            $keyLabel.Y = 0
            $keyLabel.Width = 9
            $keyLabel.Height = 1
            $keyLabel.Text = "$($func.Key):$($func.Text)"
            # Only set foreground color - let the panel's background show through
            $keyLabel.ForegroundColor = Get-ThemeColor "foreground" "#FFFFFF"
            # Don't set background color for labels
            $this._functionBar.AddChild($keyLabel)
        }

        # Set up event handlers
        $this.SetupEventHandlers()
        
        # Initial load
        $this.RefreshPanels()
    }

    hidden [void] SetupEventHandlers() {
        $thisScreen = $this
        
        # Left panel selection change
        $this._leftFileList.SelectedIndexChanged = {
            param($sender, $index)
            if ($thisScreen._leftPanelActive -and $index -ge 0 -and $index -lt $thisScreen._leftItems.Count) {
                $thisScreen._selectedItem = $thisScreen._leftItems[$index]
                $thisScreen.UpdateStatusBar()
            }
        }

        # Right panel selection change
        $this._rightFileList.SelectedIndexChanged = {
            param($sender, $index)
            if (-not $thisScreen._leftPanelActive -and $index -ge 0 -and $index -lt $thisScreen._rightItems.Count) {
                $thisScreen._selectedItem = $thisScreen._rightItems[$index]
                $thisScreen.UpdateStatusBar()
            }
        }
    }

    hidden [void] RefreshPanels() {
        $this.LoadDirectory($this._leftPath, $true)
        $this.LoadDirectory($this._rightPath, $false)
        $this.UpdatePathLabels()
        $this.UpdateStatusBar()
    }

    hidden [void] LoadDirectory([string]$path, [bool]$isLeftPanel) {
        try {
            # Get items
            $items = @()
            
            # Add parent directory if not at root
            $parentDir = Split-Path $path -Parent
            if ($parentDir) {
                $parentItem = [PSCustomObject]@{
                    Name = ".."
                    FullName = $parentDir
                    Length = 0
                    LastWriteTime = $null
                    Attributes = [System.IO.FileAttributes]::Directory
                    PSIsContainer = $true
                }
                $items += $parentItem
            }

            # Get directories and files
            $getChildParams = @{
                Path = $path
                Force = $this._showHidden
            }
            
            $allItems = Get-ChildItem @getChildParams -ErrorAction SilentlyContinue
            
            # Separate directories and files
            $dirs = @($allItems | Where-Object { $_.PSIsContainer })
            $files = @($allItems | Where-Object { -not $_.PSIsContainer })
            
            # Sort items
            switch ($this._sortBy) {
                "Name" {
                    $dirs = $dirs | Sort-Object Name -Descending:$this._sortDescending
                    $files = $files | Sort-Object Name -Descending:$this._sortDescending
                }
                "Size" {
                    $dirs = $dirs | Sort-Object Name -Descending:$this._sortDescending
                    $files = $files | Sort-Object Length -Descending:$this._sortDescending
                }
                "Date" {
                    $dirs = $dirs | Sort-Object LastWriteTime -Descending:$this._sortDescending
                    $files = $files | Sort-Object LastWriteTime -Descending:$this._sortDescending
                }
                "Extension" {
                    $dirs = $dirs | Sort-Object Name -Descending:$this._sortDescending
                    $files = $files | Sort-Object Extension -Descending:$this._sortDescending
                }
            }
            
            # Combine directories first, then files
            $items += $dirs
            $items += $files
            
            # Apply quick filter if set
            if ($this._quickFilter) {
                $items = $items | Where-Object { $_.Name -like "*$($this._quickFilter)*" }
            }
            
            # Update the appropriate panel
            if ($isLeftPanel) {
                $this._leftItems = $items
                $this._leftFileList.ClearItems()
                foreach ($item in $items) {
                    $this._leftFileList.AddItem($this.FormatFileItem($item))
                }
                if ($items.Count -gt 0) {
                    $this._leftFileList.SelectedIndex = 0
                }
            } else {
                $this._rightItems = $items
                $this._rightFileList.ClearItems()
                foreach ($item in $items) {
                    $this._rightFileList.AddItem($this.FormatFileItem($item))
                }
                if ($items.Count -gt 0) {
                    $this._rightFileList.SelectedIndex = 0
                }
            }
            
        } catch {
            Write-Log -Level Error -Message "Failed to load directory '$path': $_"
        }
    }

    hidden [string] FormatFileItem([object]$item) {
        # Special case for parent directory
        if ($item.Name -eq "..") {
            return "📂 .."
        }
        
        # Get icon
        $icon = ""
        if ($item.PSIsContainer -or $item.Attributes -band [System.IO.FileAttributes]::Directory) {
            $icon = $this._fileTypeIcons["folder"]
        } else {
            $ext = [System.IO.Path]::GetExtension($item.Name).ToLower()
            if ($this._fileTypeIcons.ContainsKey($ext)) {
                $icon = $this._fileTypeIcons[$ext]
            } else {
                $icon = $this._fileTypeIcons["default"]
            }
        }
        
        # Format name with padding
        $maxNameLength = 30
        $name = $item.Name
        if ($name.Length -gt $maxNameLength) {
            $name = $name.Substring(0, $maxNameLength - 3) + "..."
        }
        $name = $name.PadRight($maxNameLength)
        
        # Format size
        $size = ""
        if (-not ($item.PSIsContainer -or $item.Attributes -band [System.IO.FileAttributes]::Directory)) {
            $size = $this.FormatFileSize($item.Length)
        } else {
            $size = "<DIR>".PadLeft(10)
        }
        
        # Format date
        $date = ""
        if ($item.LastWriteTime) {
            $date = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        }
        
        return "$icon $name $size $date"
    }

    hidden [string] FormatFileSize([long]$bytes) {
        if ($bytes -lt 1024) { return "$bytes B".PadLeft(10) }
        if ($bytes -lt 1048576) { return "$([Math]::Round($bytes/1KB, 2)) KB".PadLeft(10) }
        if ($bytes -lt 1073741824) { return "$([Math]::Round($bytes/1MB, 2)) MB".PadLeft(10) }
        return "$([Math]::Round($bytes/1GB, 2)) GB".PadLeft(10)
    }

    hidden [void] UpdatePathLabels() {
        # Truncate paths if too long
        $maxPathLength = $this._leftPanel.Width - 4
        
        $leftDisplay = $this._leftPath
        if ($leftDisplay.Length -gt $maxPathLength) {
            $leftDisplay = "..." + $leftDisplay.Substring($leftDisplay.Length - $maxPathLength + 3)
        }
        $this._leftPathLabel.Text = " $leftDisplay "
        
        $rightDisplay = $this._rightPath
        if ($rightDisplay.Length -gt $maxPathLength) {
            $rightDisplay = "..." + $rightDisplay.Substring($rightDisplay.Length - $maxPathLength + 3)
        }
        $this._rightPathLabel.Text = " $rightDisplay "
    }

    hidden [void] UpdateStatusBar() {
        if ($this._selectedItem) {
            $name = $this._selectedItem.Name
            if ($this._selectedItem.PSIsContainer -or $this._selectedItem.Attributes -band [System.IO.FileAttributes]::Directory) {
                $this._statusLabel.Text = "Directory: $name"
                $this._sizeLabel.Text = ""
            } else {
                $this._statusLabel.Text = "File: $name"
                $this._sizeLabel.Text = "Size: $($this.FormatFileSize($this._selectedItem.Length))"
            }
        }
        
        # Update item counts
        $leftCount = $this._leftItems.Count
        $rightCount = $this._rightItems.Count
        $this._itemCountLabel.Text = "L: $leftCount | R: $rightCount items"
    }

    hidden [void] NavigateToDirectory([string]$path) {
        if (Test-Path $path -PathType Container) {
            if ($this._leftPanelActive) {
                $this._leftPath = $path
                $this.LoadDirectory($path, $true)
            } else {
                $this._rightPath = $path
                $this.LoadDirectory($path, $false)
            }
            $this.UpdatePathLabels()
            $this.UpdateStatusBar()
        }
    }

    hidden [void] EnterDirectory() {
        $item = $null
        if ($this._leftPanelActive -and $this._leftFileList.SelectedIndex -ge 0) {
            $item = $this._leftItems[$this._leftFileList.SelectedIndex]
        } elseif (-not $this._leftPanelActive -and $this._rightFileList.SelectedIndex -ge 0) {
            $item = $this._rightItems[$this._rightFileList.SelectedIndex]
        }
        
        if ($item -and ($item.PSIsContainer -or $item.Attributes -band [System.IO.FileAttributes]::Directory -or $item.Name -eq "..")) {
            if ($item.Name -eq "..") {
                $this.NavigateToDirectory($item.FullName)
            } else {
                $this.NavigateToDirectory($item.FullName)
            }
        }
    }

    hidden [void] SwitchPanel() {
        $this._leftPanelActive = -not $this._leftPanelActive
        
        if ($this._leftPanelActive) {
            $this._leftPanel.BorderColor = Get-ThemeColor "border.active" "#00D4FF"
            $this._rightPanel.BorderColor = Get-ThemeColor "border.inactive" "#666666"
            # Let ListBox use theme colors
            $this._leftFileList.SelectedBackgroundColor = ""
            $this._rightFileList.SelectedBackgroundColor = ""
            
            # Update selected item
            if ($this._leftFileList.SelectedIndex -ge 0 -and $this._leftFileList.SelectedIndex -lt $this._leftItems.Count) {
                $this._selectedItem = $this._leftItems[$this._leftFileList.SelectedIndex]
            }
            
            # Set focus
            $focusManager = $this.ServiceContainer.GetService("FocusManager")
            if ($focusManager) {
                $focusManager.SetFocus($this._leftFileList)
            }
        } else {
            $this._leftPanel.BorderColor = Get-ThemeColor "border.inactive" "#666666"
            $this._rightPanel.BorderColor = Get-ThemeColor "border.active" "#00D4FF"
            # Let ListBox use theme colors
            $this._leftFileList.SelectedBackgroundColor = ""
            $this._rightFileList.SelectedBackgroundColor = ""
            
            # Update selected item
            if ($this._rightFileList.SelectedIndex -ge 0 -and $this._rightFileList.SelectedIndex -lt $this._rightItems.Count) {
                $this._selectedItem = $this._rightItems[$this._rightFileList.SelectedIndex]
            }
            
            # Set focus
            $focusManager = $this.ServiceContainer.GetService("FocusManager")
            if ($focusManager) {
                $focusManager.SetFocus($this._rightFileList)
            }
        }
        
        $this.UpdateStatusBar()
        $this.RequestRedraw()
    }

    hidden [void] CopySelectedItems() {
        $this._clipboard.Clear()
        $this._cutMode = $false
        
        if ($this._leftPanelActive -and $this._leftFileList.SelectedIndex -ge 0) {
            $item = $this._leftItems[$this._leftFileList.SelectedIndex]
            if ($item.Name -ne "..") {
                $this._clipboard.Add($item.FullName)
                $this._statusLabel.Text = "Copied: $($item.Name)"
            }
        } elseif (-not $this._leftPanelActive -and $this._rightFileList.SelectedIndex -ge 0) {
            $item = $this._rightItems[$this._rightFileList.SelectedIndex]
            if ($item.Name -ne "..") {
                $this._clipboard.Add($item.FullName)
                $this._statusLabel.Text = "Copied: $($item.Name)"
            }
        }
    }

    hidden [void] ViewFile() {
        $item = $null
        if ($this._leftPanelActive -and $this._leftFileList.SelectedIndex -ge 0) {
            $item = $this._leftItems[$this._leftFileList.SelectedIndex]
        } elseif (-not $this._leftPanelActive -and $this._rightFileList.SelectedIndex -ge 0) {
            $item = $this._rightItems[$this._rightFileList.SelectedIndex]
        }
        
        if ($item -and -not ($item.PSIsContainer -or $item.Attributes -band [System.IO.FileAttributes]::Directory) -and $item.Name -ne "..") {
            # Navigate to text editor with the file
            $navService = $this.ServiceContainer.GetService("NavigationService")
            $actionService = $this.ServiceContainer.GetService("ActionService")
            if ($actionService) {
                # Store the file path for the editor to open (in a real implementation)
                $this._statusLabel.Text = "Opening: $($item.Name)"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "info"
                # Navigate to text editor
                $actionService.ExecuteAction("tools.textEditor", @{FilePath = $item.FullName})
            }
        }
    }

    hidden [void] DeleteSelectedItem() {
        $item = $null
        if ($this._leftPanelActive -and $this._leftFileList.SelectedIndex -ge 0) {
            $item = $this._leftItems[$this._leftFileList.SelectedIndex]
        } elseif (-not $this._leftPanelActive -and $this._rightFileList.SelectedIndex -ge 0) {
            $item = $this._rightItems[$this._rightFileList.SelectedIndex]
        }
        
        if ($item -and $item.Name -ne "..") {
            $dialogManager = $this.ServiceContainer.GetService("DialogManager")
            if ($dialogManager) {
                $itemType = if ($item.PSIsContainer -or $item.Attributes -band [System.IO.FileAttributes]::Directory) { "directory" } else { "file" }
                $message = "Delete $itemType '$($item.Name)'?"
                
                $thisScreen = $this
                $dialogManager.ShowConfirm("Confirm Delete", $message, {
                    # Delete the item
                    try {
                        Remove-Item -Path $item.FullName -Recurse -Force
                        $thisScreen._statusLabel.Text = "Deleted: $($item.Name)"
                        $thisScreen._statusLabel.ForegroundColor = Get-ThemeColor "warning"
                        # Refresh panels
                        $thisScreen.RefreshPanels()
                    } catch {
                        $thisScreen._statusLabel.Text = "Error: $($_.Exception.Message)"
                        $thisScreen._statusLabel.ForegroundColor = Get-ThemeColor "error"
                    }
                }.GetNewClosure(), {
                    # Cancel - do nothing
                })
            } else {
                $this._statusLabel.Text = "Delete: $($item.Name) (dialog not available)"
            }
        }
    }

    hidden [void] CreateDirectory() {
        $dialogManager = $this.ServiceContainer.GetService("DialogManager")
        if ($dialogManager) {
            $dialog = [InputDialog]::new("CreateDirDialog", $this.ServiceContainer)
            $dialog.SetMessage("Enter directory name:")
            $dialog.SetInputValue("")
            
            $currentPath = if ($this._leftPanelActive) { $this._leftPath } else { $this._rightPath }
            $thisScreen = $this
            
            $dialog.OnClose = {
                param($result, $dirName)
                if ($result -eq [DialogResult]::OK -and -not [string]::IsNullOrWhiteSpace($dirName)) {
                    $newPath = Join-Path $currentPath $dirName
                    try {
                        New-Item -Path $newPath -ItemType Directory -Force | Out-Null
                        $thisScreen._statusLabel.Text = "Created: $dirName"
                        $thisScreen._statusLabel.ForegroundColor = Get-ThemeColor "success"
                        # Refresh the panels
                        $thisScreen.RefreshPanels()
                    } catch {
                        $thisScreen._statusLabel.Text = "Error: $($_.Exception.Message)"
                        $thisScreen._statusLabel.ForegroundColor = Get-ThemeColor "error"
                    }
                }
            }.GetNewClosure()
            
            $dialogManager.ShowDialog($dialog)
        } else {
            $this._statusLabel.Text = "Create directory (dialog not available)"
        }
    }

    hidden [void] ShowHelp() {
        # In a real implementation, you'd show a help screen
        $this._statusLabel.Text = "Help: Tab=Switch, Enter=Open, F5=Copy, F8=Delete, F10=Quit"
    }

    [void] OnEnter() {
        ([Screen]$this).OnEnter()
        
        # Load initial directories
        $this.RefreshPanels()
        
        # Set initial focus
        $focusManager = $this.ServiceContainer.GetService("FocusManager")
        if ($focusManager) {
            if ($this._leftPanelActive) {
                $focusManager.SetFocus($this._leftFileList)
            } else {
                $focusManager.SetFocus($this._rightFileList)
            }
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $handled = $true
        
        switch ($key.Key) {
            # Navigation
            ([ConsoleKey]::Tab) { 
                $this.SwitchPanel()
            }
            ([ConsoleKey]::Enter) {
                $this.EnterDirectory()
            }
            ([ConsoleKey]::Backspace) {
                # Go to parent directory
                if ($this._leftPanelActive) {
                    $parent = Split-Path $this._leftPath -Parent
                    if ($parent) {
                        $this.NavigateToDirectory($parent)
                    }
                } else {
                    $parent = Split-Path $this._rightPath -Parent
                    if ($parent) {
                        $this.NavigateToDirectory($parent)
                    }
                }
            }
            
            # Function keys
            ([ConsoleKey]::F1) {
                $this.ShowHelp()
            }
            ([ConsoleKey]::F3) {
                $this.ViewFile()
            }
            ([ConsoleKey]::F5) {
                $this.CopySelectedItems()
            }
            ([ConsoleKey]::F7) {
                $this.CreateDirectory()
            }
            ([ConsoleKey]::F8) {
                $this.DeleteSelectedItem()
            }
            ([ConsoleKey]::F10) {
                # Exit
                $navService = $this.ServiceContainer.GetService("NavigationService")
                if ($navService.CanGoBack()) {
                    $navService.GoBack()
                } else {
                    $actionService = $this.ServiceContainer.GetService("ActionService")
                    if ($actionService) {
                        $actionService.ExecuteAction("app.exit", @{})
                    }
                }
            }
            ([ConsoleKey]::Escape) {
                # Go back
                $navService = $this.ServiceContainer.GetService("NavigationService")
                if ($navService.CanGoBack()) {
                    $navService.GoBack()
                }
            }
            
            # Ctrl combinations
            default {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    switch ($key.Key) {
                        ([ConsoleKey]::H) {
                            # Toggle hidden files
                            $this._showHidden = -not $this._showHidden
                            $this.RefreshPanels()
                            $this._statusLabel.Text = if ($this._showHidden) { "Hidden files: ON" } else { "Hidden files: OFF" }
                        }
                        ([ConsoleKey]::R) {
                            # Refresh
                            $this.RefreshPanels()
                            $this._statusLabel.Text = "Refreshed"
                        }
                        ([ConsoleKey]::L) {
                            # Go to path (would show input dialog)
                            $this._statusLabel.Text = "Go to path (not implemented)"
                        }
                        default {
                            $handled = $false
                        }
                    }
                } else {
                    $handled = $false
                }
            }
        }
        
        # If not handled by specific keys, let focused component handle it
        if (-not $handled) {
            return ([Screen]$this).HandleInput($key)
        }
        
        return $true
    }
}
