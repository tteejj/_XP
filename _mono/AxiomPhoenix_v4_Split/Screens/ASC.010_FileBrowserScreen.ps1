# ==============================================================================
# Axiom-Phoenix v4.0 - File Browser Screen (Ranger-style)
# Two-panel file browser with ranger-like navigation
# ==============================================================================

using namespace System.IO
using namespace System.Collections.Generic

class FileBrowserScreen : Screen {
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [Panel] $_leftPanel         # Directory tree / navigation
    hidden [Panel] $_rightPanel        # File list / preview
    hidden [Panel] $_statusBar         # Bottom status and hotkeys
    hidden [ListBox] $_directoryList   # Left panel directory navigation
    hidden [ListBox] $_fileList        # Right panel file listing
    hidden [LabelComponent] $_pathLabel # Current path display
    hidden [LabelComponent] $_helpLabel # Help text with hotkeys
    hidden [LabelComponent] $_statusLabel # Status information
    #endregion

    #region State
    hidden [string] $_currentPath = ""
    hidden [string] $_selectedFile = ""
    hidden [System.Collections.Generic.List[DirectoryInfo]] $_directories
    hidden [System.Collections.Generic.List[FileInfo]] $_files
    hidden [System.Collections.Generic.List[string]] $_parentDirectories
    hidden [bool] $_leftPanelFocused = $true
    hidden [int] $_directoryIndex = 0
    hidden [int] $_fileIndex = 0
    #endregion

    FileBrowserScreen([object]$serviceContainer) : base("FileBrowser", $serviceContainer) {
        Write-Log -Level Debug -Message "FileBrowserScreen: Constructor called"
        $this._currentPath = Get-Location | Select-Object -ExpandProperty Path
        $this._directories = [System.Collections.Generic.List[DirectoryInfo]]::new()
        $this._files = [System.Collections.Generic.List[FileInfo]]::new()
        $this._parentDirectories = [System.Collections.Generic.List[string]]::new()
    }

    [void] Initialize() {
        if ($this._isInitialized) { return }
        
        Write-Log -Level Debug -Message "FileBrowserScreen.Initialize: Starting"
        
        # Ensure minimum size for ranger-style layout
        if ($this.Width -lt 100) { $this.Width = 100 }
        if ($this.Height -lt 20) { $this.Height = 20 }
        
        # === MAIN PANEL ===
        $this._mainPanel = [Panel]::new("FileBrowserMain")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " 📁 File Browser (Ranger Style) "
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.BorderColor = Get-ThemeColor "panel.border"
        $this._mainPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this.AddChild($this._mainPanel)

        # Calculate panel dimensions (50/50 split)
        $leftWidth = [Math]::Floor($this.Width * 0.5) - 1
        $rightWidth = $this.Width - $leftWidth - 3
        $contentHeight = $this.Height - 5  # Account for status bar and borders

        # === LEFT PANEL: Directory Navigation ===
        $this._leftPanel = [Panel]::new("DirectoryPanel")
        $this._leftPanel.X = 1
        $this._leftPanel.Y = 3  # Leave space for path display
        $this._leftPanel.Width = $leftWidth
        $this._leftPanel.Height = $contentHeight - 2
        $this._leftPanel.Title = " 📂 Directories "
        $this._leftPanel.HasBorder = $true
        $this._leftPanel.BorderColor = Get-ThemeColor "panel.border"
        $this._leftPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.AddChild($this._leftPanel)

        # === DIRECTORY LISTBOX ===
        $this._directoryList = [ListBox]::new("DirectoryList")
        $this._directoryList.X = 1
        $this._directoryList.Y = 1
        $this._directoryList.Width = $this._leftPanel.Width - 2
        $this._directoryList.Height = $this._leftPanel.Height - 2
        $this._directoryList.TabIndex = 0
        $this._directoryList.IsFocusable = $true
        $this._directoryList.BackgroundColor = Get-ThemeColor "listbox.background"
        $this._directoryList.ForegroundColor = Get-ThemeColor "listbox.foreground"
        $this._directoryList.SelectedBackgroundColor = Get-ThemeColor "listbox.selectedbackground"
        $this._directoryList.SelectedForegroundColor = Get-ThemeColor "listbox.selectedforeground"
        
        # Directory selection handler
        $screenRef = $this
        $this._directoryList.SelectedIndexChanged = {
            param($sender, $index)
            $screenRef._directoryIndex = $index
            $screenRef.UpdateFileList()
        }.GetNewClosure()
        
        $this._leftPanel.AddChild($this._directoryList)

        # === RIGHT PANEL: File List ===
        $this._rightPanel = [Panel]::new("FilePanel")
        $this._rightPanel.X = $leftWidth + 2
        $this._rightPanel.Y = 3
        $this._rightPanel.Width = $rightWidth
        $this._rightPanel.Height = $contentHeight - 2
        $this._rightPanel.Title = " 📄 Files "
        $this._rightPanel.HasBorder = $true
        $this._rightPanel.BorderColor = Get-ThemeColor "panel.border"
        $this._rightPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.AddChild($this._rightPanel)

        # === FILE LISTBOX ===
        $this._fileList = [ListBox]::new("FileList")
        $this._fileList.X = 1
        $this._fileList.Y = 1
        $this._fileList.Width = $this._rightPanel.Width - 2
        $this._fileList.Height = $this._rightPanel.Height - 2
        $this._fileList.TabIndex = 1
        $this._fileList.IsFocusable = $true
        $this._fileList.BackgroundColor = Get-ThemeColor "listbox.background"
        $this._fileList.ForegroundColor = Get-ThemeColor "listbox.foreground"
        $this._fileList.SelectedBackgroundColor = Get-ThemeColor "listbox.selectedbackground"
        $this._fileList.SelectedForegroundColor = Get-ThemeColor "listbox.selectedforeground"
        
        # File selection handler
        $this._fileList.SelectedIndexChanged = {
            param($sender, $index)
            $screenRef._fileIndex = $index
            $screenRef.UpdateStatus()
        }.GetNewClosure()
        
        $this._rightPanel.AddChild($this._fileList)

        # === PATH DISPLAY ===
        $this._pathLabel = [LabelComponent]::new("PathLabel")
        $this._pathLabel.Text = "📍 Path: $($this._currentPath)"
        $this._pathLabel.X = 1
        $this._pathLabel.Y = 1
        $this._pathLabel.Width = $this.Width - 2
        $this._pathLabel.Height = 1
        $this._pathLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._pathLabel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.AddChild($this._pathLabel)

        # === STATUS BAR ===
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 1
        $this._statusBar.Y = $this.Height - 3
        $this._statusBar.Width = $this.Width - 2
        $this._statusBar.Height = 2
        $this._statusBar.HasBorder = $true
        $this._statusBar.BorderColor = Get-ThemeColor "panel.border"
        $this._statusBar.BackgroundColor = Get-ThemeColor "statusbar.background"
        $this._mainPanel.AddChild($this._statusBar)

        # === HELP LABEL ===
        $this._helpLabel = [LabelComponent]::new("HelpLabel")
        $this._helpLabel.Text = "🔑 [Tab] Switch Panel • [↑↓] Navigate • [←] Parent Dir • [→] Open/Enter • [F4] Edit • [F5] Refresh • [Esc] Back"
        $this._helpLabel.X = 1
        $this._helpLabel.Y = 0
        $this._helpLabel.Width = $this._statusBar.Width - 2
        $this._helpLabel.Height = 1
        $this._helpLabel.ForegroundColor = Get-ThemeColor "statusbar.foreground"
        $this._helpLabel.BackgroundColor = Get-ThemeColor "statusbar.background"
        $this._statusBar.AddChild($this._helpLabel)

        # === STATUS LABEL ===
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.Text = "Ready"
        $this._statusLabel.X = 1
        $this._statusLabel.Y = 1
        $this._statusLabel.Width = $this._statusBar.Width - 2
        $this._statusLabel.Height = 1
        $this._statusLabel.ForegroundColor = Get-ThemeColor "statusbar.foreground"
        $this._statusLabel.BackgroundColor = Get-ThemeColor "statusbar.background"
        $this._statusBar.AddChild($this._statusLabel)

        # Set initialization flag
        $this._isInitialized = $true
        
        Write-Log -Level Debug -Message "FileBrowserScreen.Initialize: Completed"
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "FileBrowserScreen.OnEnter: Screen activated"
        
        # Load initial directory content
        $this.LoadDirectory($this._currentPath)
        
        # Start with left panel focused
        $this._leftPanelFocused = $true
        $this.UpdateFocusVisuals()
        
        # Set focus to the directory list
        if ($this._directoryList.ItemCount -gt 0) {
            $this._directoryList.SelectedIndex = 0
        }
        
        # MUST call base to set initial focus
        ([Screen]$this).OnEnter()
        $this.RequestRedraw()
    }

    [void] OnExit() {
        Write-Log -Level Debug -Message "FileBrowserScreen.OnExit: Cleaning up"
        ([Screen]$this).OnExit()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Handle screen-level navigation first
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Tab) {
                # Switch between panels
                $this._leftPanelFocused = -not $this._leftPanelFocused
                $this.UpdateFocusVisuals()
                return $true
            }
            ([ConsoleKey]::LeftArrow) {
                # RANGER-STYLE: Left arrow goes up one directory
                $this.NavigateUp()
                return $true
            }
            ([ConsoleKey]::RightArrow) {
                # RANGER-STYLE: Right arrow opens selected item
                $this.OpenSelected()
                return $true
            }
            ([ConsoleKey]::Escape) {
                $this.GoBack()
                return $true
            }
            ([ConsoleKey]::Backspace) {
                $this.NavigateUp()
                return $true
            }
            ([ConsoleKey]::Enter) {
                $this.OpenSelected()
                return $true
            }
            ([ConsoleKey]::F4) {
                $this.EditSelected()
                return $true
            }
            ([ConsoleKey]::F5) {
                $this.RefreshView()
                return $true
            }
        }
        
        # Removed character shortcuts - consolidating to just arrow keys
        
        # Let base handle other input and route to components
        # This ensures up/down arrows work for navigation within lists
        return ([Screen]$this).HandleInput($keyInfo)
    }

    # === NAVIGATION METHODS ===
    hidden [void] LoadDirectory([string]$path) {
        try {
            $this._currentPath = $path
            $this._pathLabel.Text = "📍 Path: $path"
            
            # Clear previous data
            $this._directories.Clear()
            $this._files.Clear()
            $this._directoryList.ClearItems()
            $this._fileList.ClearItems()
            
            # Load parent directories for navigation
            $this.LoadParentDirectories($path)
            
            # Load subdirectories
            $dirInfo = [DirectoryInfo]::new($path)
            if ($dirInfo.Exists) {
                foreach ($dir in $dirInfo.GetDirectories()) {
                    $this._directories.Add($dir)
                    $this._directoryList.AddItem("📁 $($dir.Name)")
                }
                
                # Load files
                foreach ($file in $dirInfo.GetFiles()) {
                    $this._files.Add($file)
                    $icon = $this.GetFileIcon($file.Extension)
                    $size = $this.FormatFileSize($file.Length)
                    $this._fileList.AddItem("$icon $($file.Name) ($size)")
                }
            }
            
            # Set initial selection to first item
            if ($this._directoryList.ItemCount -gt 0) {
                $this._directoryList.SelectedIndex = 0
                $this._directoryIndex = 0
            }
            if ($this._fileList.ItemCount -gt 0) {
                $this._fileList.SelectedIndex = 0
                $this._fileIndex = 0
            }
            
            $this.UpdateStatus()
            
        } catch {
            Write-Log -Level Error -Message "FileBrowserScreen.LoadDirectory: Error loading $path - $_"
            $this._statusLabel.Text = "Error: Cannot access $path"
        }
    }

    hidden [void] LoadParentDirectories([string]$path) {
        $this._parentDirectories.Clear()
        
        # Add parent directory if not at root
        $parent = [System.IO.Path]::GetDirectoryName($path)
        if ($parent -and $parent -ne $path) {
            $this._directoryList.AddItem("📁 .. (Parent)")
            $this._parentDirectories.Add($parent)
        }
    }

    hidden [string] GetFileIcon([string]$extension) {
        $result = switch ($extension.ToLower()) {
            ".ps1" { "🔷" }
            ".txt" { "📄" }
            ".md" { "📝" }
            ".json" { "📋" }
            ".xml" { "📋" }
            ".jpg" { "🖼️" }
            ".png" { "🖼️" }
            ".gif" { "🖼️" }
            ".mp3" { "🎵" }
            ".mp4" { "🎬" }
            ".zip" { "📦" }
            ".exe" { "⚙️" }
            default { "📄" }
        }
        return $result
    }

    hidden [string] FormatFileSize([long]$bytes) {
        if ($bytes -lt 1024) { return "$bytes B" }
        if ($bytes -lt 1048576) { return "$([Math]::Round($bytes / 1024, 1)) KB" }
        if ($bytes -lt 1073741824) { return "$([Math]::Round($bytes / 1048576, 1)) MB" }
        return "$([Math]::Round($bytes / 1073741824, 1)) GB"
    }

    hidden [void] UpdateFocusVisuals() {
        if ($this._leftPanelFocused) {
            $this._leftPanel.BorderColor = Get-ThemeColor "focus.border"
            $this._rightPanel.BorderColor = Get-ThemeColor "panel.border"
            $this._leftPanel.Title = " 📂 Directories (ACTIVE) "
            $this._rightPanel.Title = " 📄 Files "
        } else {
            $this._leftPanel.BorderColor = Get-ThemeColor "panel.border"
            $this._rightPanel.BorderColor = Get-ThemeColor "focus.border"
            $this._leftPanel.Title = " 📂 Directories "
            $this._rightPanel.Title = " 📄 Files (ACTIVE) "
        }
        $this.RequestRedraw()
    }

    hidden [void] UpdateFileList() {
        if ($this._directoryIndex -ge 0 -and $this._directoryIndex -lt $this._directories.Count) {
            $selectedDir = $this._directories[$this._directoryIndex]
            # Load contents of selected directory into file list
            # This would show preview of subdirectory contents
        }
    }

    hidden [void] UpdateStatus() {
        $dirCount = $this._directories.Count
        $fileCount = $this._files.Count
        $this._statusLabel.Text = "📊 $dirCount directories, $fileCount files"
    }

    # === ACTION METHODS ===
    hidden [void] NavigateUp() {
        $parent = [System.IO.Path]::GetDirectoryName($this._currentPath)
        if ($parent -and $parent -ne $this._currentPath) {
            $this.LoadDirectory($parent)
        }
    }

    hidden [void] NavigateDown() {
        # This would be handled by the listbox navigation
        # Just update visuals here
        $this.UpdateFocusVisuals()
    }

    hidden [void] OpenSelected() {
        if ($this._leftPanelFocused) {
            # Open directory
            if ($this._directoryList.SelectedIndex -eq 0 -and $this._parentDirectories.Count -gt 0) {
                # Parent directory
                $this.NavigateUp()
            } elseif ($this._directoryList.SelectedIndex -gt 0) {
                $dirIndex = $this._directoryList.SelectedIndex - $this._parentDirectories.Count
                if ($dirIndex -ge 0 -and $dirIndex -lt $this._directories.Count) {
                    $selectedDir = $this._directories[$dirIndex]
                    $this.LoadDirectory($selectedDir.FullName)
                }
            }
        } else {
            # Open file
            if ($this._fileList.SelectedIndex -ge 0 -and $this._fileList.SelectedIndex -lt $this._files.Count) {
                $selectedFile = $this._files[$this._fileList.SelectedIndex]
                $this.OpenFile($selectedFile.FullName)
            }
        }
    }

    hidden [void] OpenFile([string]$filePath) {
        try {
            # For now, just edit text files
            $extension = [System.IO.Path]::GetExtension($filePath).ToLower()
            if ($extension -in @(".ps1", ".txt", ".md", ".json", ".xml")) {
                $this.EditFile($filePath)
            } else {
                $this._statusLabel.Text = "📄 File: $filePath (cannot preview)"
            }
        } catch {
            $this._statusLabel.Text = "❌ Error opening file: $_"
        }
    }

    hidden [void] EditFile([string]$filePath) {
        # Navigate to text editor with the file
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if ($actionService) {
            $actionService.ExecuteAction("tools.textEditor", @{ FilePath = $filePath })
        }
    }

    hidden [void] EditSelected() {
        if (-not $this._leftPanelFocused -and $this._fileList.SelectedIndex -ge 0) {
            $selectedFile = $this._files[$this._fileList.SelectedIndex]
            $this.EditFile($selectedFile.FullName)
        }
    }

    hidden [void] RefreshView() {
        $this.LoadDirectory($this._currentPath)
        $this._statusLabel.Text = "🔄 Refreshed"
    }

    hidden [void] ToggleHiddenFiles() {
        # Toggle showing hidden files (files starting with .)
        $this._statusLabel.Text = "👁️ Hidden files toggle (not implemented)"
    }

    hidden [void] GoBack() {
        $navigationService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navigationService) {
            if ($navigationService.CanGoBack()) {
                $navigationService.GoBack()
            } else {
                # Navigate to dashboard
                $actionService = $this.ServiceContainer?.GetService("ActionService")
                if ($actionService) {
                    $actionService.ExecuteAction("navigation.dashboard", @{})
                }
            }
        }
    }
}