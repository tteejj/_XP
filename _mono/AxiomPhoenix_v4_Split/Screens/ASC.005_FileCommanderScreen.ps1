# ==============================================================================
# Axiom-Phoenix v4.0 - File Commander - Full-Featured Terminal File Browser
# HYBRID MODEL: Uses automatic focus management with focusable panel components
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
    hidden [object[]] $_leftItems = @()
    hidden [object[]] $_rightItems = @()
    hidden [object] $_selectedItem
    hidden [object] $_pendingDelete = $null
    hidden [string] $_inputMode = ""
    hidden [string] $_inputBuffer = ""
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
    hidden [System.Collections.Generic.List[string]] $_clipboard
    hidden [bool] $_cutMode = $false  # false = copy, true = cut
    hidden [string] $_quickFilter = ""
    #endregion

    FileCommanderScreen([ServiceContainer]$container) : base("FileCommanderScreen", $container) {
        # Initialize collections first
        $this._clipboard = [System.Collections.Generic.List[string]]::new()
        
        # Initialize paths safely
        try {
            $this._leftPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
            $this._rightPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        } catch {
            # Cross-platform fallback paths
            $isWindowsOS = [System.Environment]::OSVersion.Platform -eq 'Win32NT'
            $userHome = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
            if ([string]::IsNullOrEmpty($userHome)) {
                $userHome = if ($isWindowsOS) { $env:USERPROFILE } else { $env:HOME }
            }
            
            $this._leftPath = if ($isWindowsOS) { "C:\" } else { "/" }
            $this._rightPath = if ($isWindowsOS) { "C:\" } else { $userHome }
        }
    }

    [void] Initialize() {
        Write-Log -Level Debug -Message "FileCommanderScreen.Initialize: Starting"
        
        # Main panel
        $this._mainPanel = [Panel]::new("FileCommanderMain")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.HasBorder = $false
        # Use property assignment, not method
        $this._mainPanel.BackgroundColor = Get-ThemeColor "Panel.Background" "#0A0A0A"
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
        $this._leftPanel.HasBorder = $true
        # Use property assignment
        $this._leftPanel.BorderColor = Get-ThemeColor "Panel.Border" "#00D4FF"  # Initially active
        $this._mainPanel.AddChild($this._leftPanel)

        # Left path label
        $this._leftPathLabel = [LabelComponent]::new("LeftPath")
        $this._leftPathLabel.X = 1
        $this._leftPathLabel.Y = 0
        $this._leftPathLabel.Width = $halfWidth - 2
        $this._leftPathLabel.Height = 1
        # Use property assignment
        $this._leftPathLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#FFD700"
        $this._leftPathLabel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1A1A1A"
        $this._leftPanel.AddChild($this._leftPathLabel)

        # Left file list
        $this._leftFileList = [ListBox]::new("LeftFiles")
        $this._leftFileList.X = 1
        $this._leftFileList.Y = 1
        $this._leftFileList.Width = $halfWidth - 2
        $this._leftFileList.Height = $panelHeight - 2
        $this._leftFileList.HasBorder = $false
        $this._leftFileList.IsFocusable = $true  # Enable focus for hybrid model
        $this._leftFileList.TabIndex = 0         # First in tab order
        # Use property assignment
        $this._leftFileList.SelectedBackgroundColor = Get-ThemeColor "list.selected.background" "#1E3A8A"
        $this._leftFileList.SelectedForegroundColor = Get-ThemeColor "list.selected.foreground" "#FFFFFF"
        $this._leftFileList.ItemForegroundColor = Get-ThemeColor "Label.Foreground" "#E0E0E0"
        
        # Store theme colors before creating closure
        $focusBorderColor = Get-ThemeColor "Panel.Border" "#00D4FF"
        $blurBorderColor = Get-ThemeColor "Panel.Border" "#666666"
        $screenRef = $this
        
        # Add focus visual feedback with stored colors
        $this._leftFileList | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.Parent.BorderColor = $focusBorderColor
            $screenRef.UpdateStatusBar()
            $this.RequestRedraw()
        }.GetNewClosure() -Force
        
        $this._leftFileList | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.Parent.BorderColor = $blurBorderColor
            $this.RequestRedraw()
        }.GetNewClosure() -Force
        
        # Handle item selection and directory navigation - NO HandleInput override
        
        $this._leftPanel.AddChild($this._leftFileList)

        # Right file panel
        $this._rightPanel = [Panel]::new("RightPanel")
        $this._rightPanel.X = $halfWidth
        $this._rightPanel.Y = 0
        $this._rightPanel.Width = $this.Width - $halfWidth
        $this._rightPanel.Height = $panelHeight
        $this._rightPanel.HasBorder = $true
        $this._rightPanel.HasBorder = $true
        # Use property assignment
        $this._rightPanel.BorderColor = Get-ThemeColor "Panel.Border" "#666666"  # Initially inactive
        $this._mainPanel.AddChild($this._rightPanel)

        # Right path label
        $this._rightPathLabel = [LabelComponent]::new("RightPath")
        $this._rightPathLabel.X = 1
        $this._rightPathLabel.Y = 0
        $this._rightPathLabel.Width = $this._rightPanel.Width - 2
        $this._rightPathLabel.Height = 1
        # Use property assignment
        $this._rightPathLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#FFD700"
        $this._rightPathLabel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1A1A1A"
        $this._rightPanel.AddChild($this._rightPathLabel)

        # Right file list
        $this._rightFileList = [ListBox]::new("RightFiles")
        $this._rightFileList.X = 1
        $this._rightFileList.Y = 1
        $this._rightFileList.Width = $this._rightPanel.Width - 2
        $this._rightFileList.Height = $panelHeight - 2
        $this._rightFileList.HasBorder = $false
        $this._rightFileList.IsFocusable = $true  # Enable focus for hybrid model
        $this._rightFileList.TabIndex = 1         # Second in tab order
        # Use property assignment
        $this._rightFileList.SelectedBackgroundColor = Get-ThemeColor "list.selected.background" "#1E3A8A"
        $this._rightFileList.SelectedForegroundColor = Get-ThemeColor "list.selected.foreground" "#FFFFFF"
        $this._rightFileList.ItemForegroundColor = Get-ThemeColor "Label.Foreground" "#E0E0E0"
        
        # Add focus visual feedback with stored colors
        $this._rightFileList | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.Parent.BorderColor = $focusBorderColor
            $screenRef.UpdateStatusBar()
            $this.RequestRedraw()
        }.GetNewClosure() -Force
        
        $this._rightFileList | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.Parent.BorderColor = $blurBorderColor
            $this.RequestRedraw()
        }.GetNewClosure() -Force
        
        # Handle item selection and directory navigation - NO HandleInput override
        
        $this._rightPanel.AddChild($this._rightFileList)

        # Status bar
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 0
        $this._statusBar.Y = $panelHeight
        $this._statusBar.Width = $this.Width
        $this._statusBar.Height = 2
        $this._statusBar.HasBorder = $false
        # Use property assignment
        $this._statusBar.BackgroundColor = Get-ThemeColor "Panel.Background" "#1A1A1A"
        $this._mainPanel.AddChild($this._statusBar)

        # Status label
        $this._statusLabel = [LabelComponent]::new("Status")
        $this._statusLabel.X = 1
        $this._statusLabel.Y = 0
        $this._statusLabel.Width = 60
        $this._statusLabel.Height = 1
        # Use property assignment
        $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00FF88"
        $this._statusBar.AddChild($this._statusLabel)

        # Size label
        $this._sizeLabel = [LabelComponent]::new("Size")
        $this._sizeLabel.X = 62
        $this._sizeLabel.Y = 0
        $this._sizeLabel.Width = 20
        $this._sizeLabel.Height = 1
        # Use property assignment
        $this._sizeLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#FFD700"
        $this._statusBar.AddChild($this._sizeLabel)

        # Item count label
        $this._itemCountLabel = [LabelComponent]::new("ItemCount")
        $this._itemCountLabel.X = $this.Width - 25
        $this._itemCountLabel.Y = 0
        $this._itemCountLabel.Width = 24
        $this._itemCountLabel.Height = 1
        # Use property assignment
        $this._itemCountLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00D4FF"
        $this._statusBar.AddChild($this._itemCountLabel)

        # Function key bar
        $this._functionBar = [Panel]::new("FunctionBar")
        $this._functionBar.X = 0
        $this._functionBar.Y = $this.Height - 2
        $this._functionBar.Width = $this.Width
        $this._functionBar.Height = 2
        $this._functionBar.HasBorder = $false
        # Use property assignment
        $this._functionBar.BackgroundColor = Get-ThemeColor "Panel.Background" "#0D47A1"
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
            # Use property assignment
            $keyLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#FFFFFF"
            $this._functionBar.AddChild($keyLabel)
        }

        # Set up event handlers - components now handle their own input
        # Selection changes are handled automatically via focus system
        
        Write-Log -Level Debug -Message "FileCommanderScreen.Initialize: Completed"
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
                Force = $true
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
        # Get currently selected item based on focused component
        $focusedChild = $this.GetFocusedChild()
        
        if ($focusedChild -eq $this._leftFileList) {
            if ($this._leftFileList.SelectedIndex -ge 0 -and $this._leftFileList.SelectedIndex -lt $this._leftItems.Count) {
                $this._selectedItem = $this._leftItems[$this._leftFileList.SelectedIndex]
            }
        } elseif ($focusedChild -eq $this._rightFileList) {
            if ($this._rightFileList.SelectedIndex -ge 0 -and $this._rightFileList.SelectedIndex -lt $this._rightItems.Count) {
                $this._selectedItem = $this._rightItems[$this._rightFileList.SelectedIndex]
            }
        }
        
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
            $focusedChild = $this.GetFocusedChild()
            
            if ($focusedChild -eq $this._leftFileList) {
                $this._leftPath = $path
                $this.LoadDirectory($path, $true)
            } elseif ($focusedChild -eq $this._rightFileList) {
                $this._rightPath = $path
                $this.LoadDirectory($path, $false)
            }
            $this.UpdatePathLabels()
            $this.UpdateStatusBar()
        }
    }

    hidden [void] EnterDirectoryLeft() {
        if ($this._leftFileList.SelectedIndex -ge 0 -and $this._leftFileList.SelectedIndex -lt $this._leftItems.Count) {
            $item = $this._leftItems[$this._leftFileList.SelectedIndex]
            if ($item -and ($item.PSIsContainer -or $item.Attributes -band [System.IO.FileAttributes]::Directory -or $item.Name -eq "..")) {
                if ($item.Name -eq "..") {
                    $this._leftPath = $item.FullName
                    $this.LoadDirectory($item.FullName, $true)
                } else {
                    $this._leftPath = $item.FullName
                    $this.LoadDirectory($item.FullName, $true)
                }
                $this.UpdatePathLabels()
                $this.UpdateStatusBar()
            }
        }
    }

    hidden [void] EnterDirectoryRight() {
        if ($this._rightFileList.SelectedIndex -ge 0 -and $this._rightFileList.SelectedIndex -lt $this._rightItems.Count) {
            $item = $this._rightItems[$this._rightFileList.SelectedIndex]
            if ($item -and ($item.PSIsContainer -or $item.Attributes -band [System.IO.FileAttributes]::Directory -or $item.Name -eq "..")) {
                if ($item.Name -eq "..") {
                    $this._rightPath = $item.FullName
                    $this.LoadDirectory($item.FullName, $false)
                } else {
                    $this._rightPath = $item.FullName
                    $this.LoadDirectory($item.FullName, $false)
                }
                $this.UpdatePathLabels()
                $this.UpdateStatusBar()
            }
        }
    }

    hidden [void] EnterDirectory() {
        $focusedChild = $this.GetFocusedChild()
        
        if ($focusedChild -eq $this._leftFileList) {
            $this.EnterDirectoryLeft()
        } elseif ($focusedChild -eq $this._rightFileList) {
            $this.EnterDirectoryRight()
        }
    }

    hidden [void] CopySelectedItems() {
        $this._clipboard.Clear()
        $this._cutMode = $false
        
        $focusedChild = $this.GetFocusedChild()
        $item = $null
        
        if ($focusedChild -eq $this._leftFileList -and $this._leftFileList.SelectedIndex -ge 0) {
            $item = $this._leftItems[$this._leftFileList.SelectedIndex]
        } elseif ($focusedChild -eq $this._rightFileList -and $this._rightFileList.SelectedIndex -ge 0) {
            $item = $this._rightItems[$this._rightFileList.SelectedIndex]
        }
        
        if ($item -and $item.Name -ne "..") {
            $this._clipboard.Add($item.FullName)
            $this._statusLabel.Text = "Copied: $($item.Name)"
        }
    }

    hidden [void] ViewFile() {
        $focusedChild = $this.GetFocusedChild()
        $item = $null
        
        if ($focusedChild -eq $this._leftFileList -and $this._leftFileList.SelectedIndex -ge 0) {
            $item = $this._leftItems[$this._leftFileList.SelectedIndex]
        } elseif ($focusedChild -eq $this._rightFileList -and $this._rightFileList.SelectedIndex -ge 0) {
            $item = $this._rightItems[$this._rightFileList.SelectedIndex]
        }
        
        if ($item -and -not ($item.PSIsContainer -or $item.Attributes -band [System.IO.FileAttributes]::Directory) -and $item.Name -ne "..") {
            # Navigate to text editor with the file
            $navService = $this.ServiceContainer.GetService("NavigationService")
            $actionService = $this.ServiceContainer.GetService("ActionService")
            if ($actionService) {
                # Store the file path for the editor to open
                $this._statusLabel.Text = "Opening: $($item.Name)"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00d4ff"
                # Navigate to text editor
                $actionService.ExecuteAction("tools.textEditor", @{FilePath = $item.FullName})
            }
        }
    }

    hidden [void] DeleteSelectedItem() {
        $focusedChild = $this.GetFocusedChild()
        $item = $null
        
        if ($focusedChild -eq $this._leftFileList -and $this._leftFileList.SelectedIndex -ge 0) {
            $item = $this._leftItems[$this._leftFileList.SelectedIndex]
        } elseif ($focusedChild -eq $this._rightFileList -and $this._rightFileList.SelectedIndex -ge 0) {
            $item = $this._rightItems[$this._rightFileList.SelectedIndex]
        }
        
        if ($item -and $item.Name -ne "..") {
            $itemType = "file"
            if ($item.PSIsContainer -or $item.Attributes -band [System.IO.FileAttributes]::Directory) {
                $itemType = "directory"
            }
            $message = "Delete $itemType '$($item.Name)'?"
            
            # Simple confirmation - in real app would use dialog
            $this._statusLabel.Text = "Press Y to confirm delete, any other key to cancel"
            $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#ffa500"
            $this.RequestRedraw()
            
            # Store for next keypress handling
            $this._pendingDelete = $item
        }
    }

    hidden [void] CreateDirectory() {
        try {
            # Get current directory from active panel
            $currentDir = if ($this._leftActive) { $this._leftPath } else { $this._rightPath }
            
            # Simple input prompt (basic implementation)
            $this._statusLabel.Text = "Enter directory name (then press Enter): "
            $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00d4ff"
            $this.RequestRedraw()
            
            # Set up input mode
            $this._inputMode = "createDir"
            $this._inputBuffer = ""
            
        } catch {
            Write-Log -Level Error -Message "CreateDirectory failed: $_"
            $this._statusLabel.Text = "Create directory failed: $($_.Exception.Message)"
            $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Error" "#ff0000"
        }
    }

    hidden [void] _CreateDirectoryFromInput() {
        try {
            if ([string]::IsNullOrWhiteSpace($this._inputBuffer)) {
                $this._statusLabel.Text = "Directory name cannot be empty"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Error" "#ff0000"
                $this.RequestRedraw()
                return
            }
            
            # Get current directory from active panel
            $currentDir = if ($this._leftActive) { $this._leftPath } else { $this._rightPath }
            $newDirPath = Join-Path $currentDir $this._inputBuffer
            
            # Create directory
            $fileSystemService = $this.ServiceContainer.GetService("FileSystemService")
            if ($fileSystemService) {
                $success = $fileSystemService.CreateDirectory($newDirPath)
                if ($success) {
                    $this._statusLabel.Text = "Directory created: $($this._inputBuffer)"
                    $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00ff88"
                    $this.RefreshPanels()
                } else {
                    $this._statusLabel.Text = "Failed to create directory: $($this._inputBuffer)"
                    $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Error" "#ff0000"
                }
            } else {
                # Fallback to direct .NET call
                New-Item -ItemType Directory -Path $newDirPath -Force | Out-Null
                $this._statusLabel.Text = "Directory created: $($this._inputBuffer)"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00ff88"
                $this.RefreshPanels()
            }
            
        } catch {
            Write-Log -Level Error -Message "CreateDirectoryFromInput failed: $_"
            $this._statusLabel.Text = "Create directory failed: $($_.Exception.Message)"
            $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Error" "#ff0000"
        } finally {
            # Reset input mode
            $this._inputMode = ""
            $this._inputBuffer = ""
            $this.RequestRedraw()
        }
    }

    hidden [void] ShowHelp() {
        $this._statusLabel.Text = "Help: Tab=Switch, Enter=Open, F5=Copy, F8=Delete, F10=Quit"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00d4ff"
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "FileCommanderScreen.OnEnter: Starting"
        
        # Load initial directories
        $this.RefreshPanels()
        
        # Set initial border states (will be updated by focus system)
        # Use property assignment
        $this._leftPanel.BorderColor = Get-ThemeColor "Panel.Border" "#666666"
        $this._rightPanel.BorderColor = Get-ThemeColor "Panel.Border" "#666666"
        
        # Call base to set initial focus (will focus first focusable child)
        ([Screen]$this).OnEnter()
        
        $this.RequestRedraw()
    }

    [void] OnExit() {
        Write-Log -Level Debug -Message "FileCommanderScreen.OnExit: Cleaning up"
        # Nothing to clean up
    }

    # === HYBRID MODEL INPUT HANDLING ===
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) {
            Write-Log -Level Warning -Message "FileCommanderScreen.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "FileCommanderScreen.HandleInput: Key=$($key.Key)"
        
        # Check if we have a pending delete confirmation (global state)
        if ($this._pendingDelete) {
            if ($key.KeyChar -eq 'y' -or $key.KeyChar -eq 'Y') {
                try {
                    Remove-Item -Path $this._pendingDelete.FullName -Recurse -Force
                    $this._statusLabel.Text = "Deleted: $($this._pendingDelete.Name)"
                    $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00ff88"
                    $this.RefreshPanels()
                } catch {
                    $this._statusLabel.Text = "Error: $($_.Exception.Message)"
                    $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#ff4444"
                }
            } else {
                $this._statusLabel.Text = "Delete cancelled"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00d4ff"
            }
            $this._pendingDelete = $null
            $this.RequestRedraw()
            return $true
        }
        
        # Handle input modes (like creating directory)
        if ($this._inputMode -eq "createDir") {
            if ($key.Key -eq [ConsoleKey]::Enter) {
                # Create directory
                $this._CreateDirectoryFromInput()
                return $true
            }
            elseif ($key.Key -eq [ConsoleKey]::Escape) {
                # Cancel input
                $this._inputMode = ""
                $this._inputBuffer = ""
                $this._statusLabel.Text = "Create directory cancelled"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00d4ff"
                $this.RequestRedraw()
                return $true
            }
            elseif ($key.Key -eq [ConsoleKey]::Backspace) {
                # Handle backspace
                if ($this._inputBuffer.Length -gt 0) {
                    $this._inputBuffer = $this._inputBuffer.Substring(0, $this._inputBuffer.Length - 1)
                    $this._statusLabel.Text = "Enter directory name (then press Enter): $($this._inputBuffer)"
                    $this.RequestRedraw()
                }
                return $true
            }
            elseif ($key.KeyChar -and $key.KeyChar -ne [char]0) {
                # Add character to input buffer
                $this._inputBuffer += $key.KeyChar
                $this._statusLabel.Text = "Enter directory name (then press Enter): $($this._inputBuffer)"
                $this.RequestRedraw()
                return $true
            }
        }
        
        # IMPORTANT: Call base class first - handles Tab navigation and routes to focused component
        if (([Screen]$this).HandleInput($key)) {
            return $true
        }
        
        # Handle global shortcuts that work regardless of focus
        switch ($key.Key) {
            ([ConsoleKey]::Enter) {
                # Handle Enter for directory navigation based on focused list
                $focusedChild = $this.GetFocusedChild()
                if ($focusedChild -eq $this._leftFileList) {
                    $this.EnterDirectoryLeft()
                    return $true
                } elseif ($focusedChild -eq $this._rightFileList) {
                    $this.EnterDirectoryRight()
                    return $true
                }
            }
            # Function keys
            ([ConsoleKey]::F1) {
                $this.ShowHelp()
                return $true
            }
            ([ConsoleKey]::F3) {
                $this.ViewFile()
                return $true
            }
            ([ConsoleKey]::F5) {
                $this.CopySelectedItems()
                return $true
            }
            ([ConsoleKey]::F7) {
                $this.CreateDirectory()
                return $true
            }
            ([ConsoleKey]::F8) {
                $this.DeleteSelectedItem()
                return $true
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
                return $true
            }
            ([ConsoleKey]::Escape) {
                # Go back
                $navService = $this.ServiceContainer.GetService("NavigationService")
                if ($navService.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
            ([ConsoleKey]::Backspace) {
                # Go to parent directory of focused panel
                $focusedChild = $this.GetFocusedChild()
                if ($focusedChild -eq $this._leftFileList) {
                    $parent = Split-Path $this._leftPath -Parent
                    if ($parent) {
                        $this._leftPath = $parent
                        $this.LoadDirectory($parent, $true)
                        $this.UpdatePathLabels()
                        $this.UpdateStatusBar()
                    }
                } elseif ($focusedChild -eq $this._rightFileList) {
                    $parent = Split-Path $this._rightPath -Parent
                    if ($parent) {
                        $this._rightPath = $parent
                        $this.LoadDirectory($parent, $false)
                        $this.UpdatePathLabels()
                        $this.UpdateStatusBar()
                    }
                }
                return $true
            }
        }
        
        # Handle Ctrl combinations
        if ($key.Modifiers -band [ConsoleModifiers]::Control) {
            switch ($key.Key) {
                ([ConsoleKey]::H) {
                    # Toggle hidden files
                    $this._showHidden = -not $this._showHidden
                    $this.RefreshPanels()
                    $this._statusLabel.Text = if ($this._showHidden) { "Hidden files: ON" } else { "Hidden files: OFF" }
                    return $true
                }
                ([ConsoleKey]::R) {
                    # Refresh
                    $this.RefreshPanels()
                    $this._statusLabel.Text = "Refreshed"
                    return $true
                }
                ([ConsoleKey]::L) {
                    # Go to path (would show input dialog)
                    $this._statusLabel.Text = "Go to path: Feature requires dialog system"
                    return $true
                }
            }
        }
        
        Write-Log -Level Debug -Message "FileCommanderScreen.HandleInput: Returning false (unhandled)"
        return $false
    }
}

# ==============================================================================
# END OF FILE COMMANDER SCREEN
# ==============================================================================
