# ==============================================================================
# Axiom-Phoenix v4.0 - Text Editor Screen (Brand New Implementation)
# Advanced text editor with TextEngine integration
# ==============================================================================

using namespace System.IO
using namespace System.Collections.Generic

class TextEditScreen : Screen {
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [Panel] $_editorPanel       # Main text editing area
    hidden [Panel] $_statusBar         # Bottom status bar
    hidden [Panel] $_menuBar           # Top menu/toolbar
    hidden [MultilineTextBoxComponent] $_textEditor  # Main text editor component
    hidden [LabelComponent] $_statusLabel           # Status information
    hidden [LabelComponent] $_positionLabel         # Cursor position
    hidden [LabelComponent] $_menuLabel             # Menu/shortcuts
    hidden [LabelComponent] $_fileLabel             # Current file info
    #endregion

    #region State Management
    hidden [string] $_filePath = ""
    hidden [string] $_fileName = "Untitled"
    hidden [bool] $_isModified = $false
    hidden [bool] $_isReadOnly = $false
    hidden [int] $_cursorLine = 1
    hidden [int] $_cursorColumn = 1
    hidden [int] $_totalLines = 1
    hidden [string] $_encoding = "UTF-8"
    hidden [DateTime] $_lastSaved
    
    # Editor features
    hidden [bool] $_showLineNumbers = $true
    hidden [bool] $_wordWrap = $false
    hidden [int] $_tabSize = 4
    hidden [bool] $_insertMode = $true
    
    # Search functionality
    hidden [string] $_searchText = ""
    hidden [bool] $_searchActive = $false
    hidden [bool] $_caseSensitive = $false
    
    # Undo/Redo stacks
    hidden [System.Collections.Generic.Stack[object]] $_undoStack
    hidden [System.Collections.Generic.Stack[object]] $_redoStack
    #endregion

    TextEditScreen([object]$serviceContainer) : base("TextEditor", $serviceContainer) {
        Write-Log -Level Debug -Message "TextEditScreen: Constructor called"
        $this._undoStack = [System.Collections.Generic.Stack[object]]::new()
        $this._redoStack = [System.Collections.Generic.Stack[object]]::new()
        $this._lastSaved = [DateTime]::Now
    }

    # Constructor overload for opening specific file
    TextEditScreen([object]$serviceContainer, [string]$filePath) : base("TextEditor", $serviceContainer) {
        Write-Log -Level Debug -Message "TextEditScreen: Constructor called with file: $filePath"
        $this._filePath = $filePath
        $this._fileName = [System.IO.Path]::GetFileName($filePath)
        $this._undoStack = [System.Collections.Generic.Stack[object]]::new()
        $this._redoStack = [System.Collections.Generic.Stack[object]]::new()
        $this._lastSaved = [DateTime]::Now
    }

    [void] Initialize() {
        if ($this._isInitialized) { return }
        
        Write-Log -Level Debug -Message "TextEditScreen.Initialize: Starting"
        
        # Ensure adequate size for text editing
        if ($this.Width -lt 80) { $this.Width = 80 }
        if ($this.Height -lt 25) { $this.Height = 25 }
        
        # === MAIN PANEL ===
        $this._mainPanel = [Panel]::new("TextEditorMain")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " ✏️ Text Editor - $($this._fileName) "
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.BorderColor = Get-ThemeColor "panel.border"
        $this._mainPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this.AddChild($this._mainPanel)

        # === MENU BAR ===
        $this._menuBar = [Panel]::new("MenuBar")
        $this._menuBar.X = 1
        $this._menuBar.Y = 1
        $this._menuBar.Width = $this.Width - 2
        $this._menuBar.Height = 2
        $this._menuBar.HasBorder = $true
        $this._menuBar.BorderColor = Get-ThemeColor "panel.border"
        $this._menuBar.BackgroundColor = Get-ThemeColor "menu.background"
        $this._mainPanel.AddChild($this._menuBar)

        # === MENU LABEL ===
        $this._menuLabel = [LabelComponent]::new("MenuLabel")
        $this._menuLabel.Text = "📋 [Ctrl+S] Save • [Ctrl+O] Open • [Ctrl+N] New • [Ctrl+F] Find • [Ctrl+Z] Undo • [Ctrl+Y] Redo • [Esc] Exit"
        $this._menuLabel.X = 1
        $this._menuLabel.Y = 0
        $this._menuLabel.Width = $this._menuBar.Width - 2
        $this._menuLabel.Height = 1
        $this._menuLabel.ForegroundColor = Get-ThemeColor "menu.foreground"
        $this._menuLabel.BackgroundColor = Get-ThemeColor "menu.background"
        $this._menuBar.AddChild($this._menuLabel)

        # === FILE INFO LABEL ===
        $this._fileLabel = [LabelComponent]::new("FileLabel")
        $this._fileLabel.Text = $this.GetFileInfo()
        $this._fileLabel.X = 1
        $this._fileLabel.Y = 1
        $this._fileLabel.Width = $this._menuBar.Width - 2
        $this._fileLabel.Height = 1
        $this._fileLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._fileLabel.BackgroundColor = Get-ThemeColor "menu.background"
        $this._menuBar.AddChild($this._fileLabel)

        # === EDITOR PANEL ===
        $this._editorPanel = [Panel]::new("EditorPanel")
        $this._editorPanel.X = 1
        $this._editorPanel.Y = 4  # After menu bar
        $this._editorPanel.Width = $this.Width - 2
        $this._editorPanel.Height = $this.Height - 7  # Account for menu and status bars
        $this._editorPanel.HasBorder = $true
        $this._editorPanel.BorderColor = Get-ThemeColor "editor.border"
        $this._editorPanel.BackgroundColor = Get-ThemeColor "editor.background"
        $this._mainPanel.AddChild($this._editorPanel)

        # === TEXT EDITOR COMPONENT ===
        $this._textEditor = [MultilineTextBoxComponent]::new("TextEditor")
        $this._textEditor.X = 1
        $this._textEditor.Y = 1
        $this._textEditor.Width = $this._editorPanel.Width - 2
        $this._textEditor.Height = $this._editorPanel.Height - 2
        $this._textEditor.TabIndex = 0
        $this._textEditor.IsFocusable = $true
        $this._textEditor.BackgroundColor = Get-ThemeColor "editor.background"
        $this._textEditor.ForegroundColor = Get-ThemeColor "editor.foreground"
        $this._textEditor.BorderColor = Get-ThemeColor "editor.border"
        
        # Note: MultilineTextBoxComponent has basic functionality
        # Enhanced features like ShowLineNumbers, WordWrap, TabSize, InsertMode 
        # are not supported by this component
        
        # Add focus handlers for visual feedback
        $screenRef = $this
        $this._textEditor | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "editor.focus.border"
            $screenRef.UpdateCursorPosition()
            $this.RequestRedraw()
        } -Force
        
        $this._textEditor | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "editor.border"
            $this.RequestRedraw()
        } -Force
        
        # Text change handler for modification tracking
        $this._textEditor | Add-Member -MemberType ScriptMethod -Name OnTextChanged -Value {
            $screenRef._isModified = $true
            $screenRef.UpdateTitle()
            $screenRef.UpdateStatus()
        } -Force
        
        $this._editorPanel.AddChild($this._textEditor)

        # === STATUS BAR ===
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 1
        $this._statusBar.Y = $this.Height - 3
        $this._statusBar.Width = $this.Width - 2
        $this._statusBar.Height = 2
        $this._statusBar.HasBorder = $true
        $this._statusBar.BorderColor = Get-ThemeColor "statusbar.border"
        $this._statusBar.BackgroundColor = Get-ThemeColor "statusbar.background"
        $this._mainPanel.AddChild($this._statusBar)

        # === STATUS LABEL ===
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.Text = "Ready"
        $this._statusLabel.X = 1
        $this._statusLabel.Y = 0
        $this._statusLabel.Width = [Math]::Floor($this._statusBar.Width * 0.7)
        $this._statusLabel.Height = 1
        $this._statusLabel.ForegroundColor = Get-ThemeColor "statusbar.foreground"
        $this._statusLabel.BackgroundColor = Get-ThemeColor "statusbar.background"
        $this._statusBar.AddChild($this._statusLabel)

        # === POSITION LABEL ===
        $this._positionLabel = [LabelComponent]::new("PositionLabel")
        $this._positionLabel.Text = "Ln 1, Col 1"
        $this._positionLabel.X = [Math]::Floor($this._statusBar.Width * 0.7)
        $this._positionLabel.Y = 0
        $this._positionLabel.Width = [Math]::Floor($this._statusBar.Width * 0.3) - 1
        $this._positionLabel.Height = 1
        $this._positionLabel.ForegroundColor = Get-ThemeColor "statusbar.foreground"
        $this._positionLabel.BackgroundColor = Get-ThemeColor "statusbar.background"
        $this._statusBar.AddChild($this._positionLabel)

        # Set initialization flag
        $this._isInitialized = $true
        
        Write-Log -Level Debug -Message "TextEditScreen.Initialize: Completed"
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "TextEditScreen.OnEnter: Screen activated"
        
        # Load file if specified
        if ($this._filePath -and [System.IO.File]::Exists($this._filePath)) {
            $this.LoadFile($this._filePath)
        } else {
            # Start with empty document
            $this._textEditor.Lines = [List[string]]::new()
            $this._textEditor.Lines.Add("")
            $this._isModified = $false
        }
        
        $this.UpdateTitle()
        $this.UpdateStatus()
        $this.UpdateCursorPosition()
        
        # MUST call base to set initial focus
        ([Screen]$this).OnEnter()
        $this.RequestRedraw()
    }

    [void] OnExit() {
        Write-Log -Level Debug -Message "TextEditScreen.OnExit: Cleaning up"
        
        # Check for unsaved changes
        if ($this._isModified) {
            # In a real implementation, show save dialog here
            Write-Log -Level Warning -Message "TextEditScreen: Exiting with unsaved changes"
        }
        
        ([Screen]$this).OnExit()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Handle Ctrl key combinations first
        if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::S) { $this.SaveFile(); return $true }
                ([ConsoleKey]::O) { $this.OpenFile(); return $true }
                ([ConsoleKey]::N) { $this.NewFile(); return $true }
                ([ConsoleKey]::F) { $this.ShowFindDialog(); return $true }
                ([ConsoleKey]::Z) { $this.Undo(); return $true }
                ([ConsoleKey]::Y) { $this.Redo(); return $true }
                ([ConsoleKey]::A) { $this.SelectAll(); return $true }
                ([ConsoleKey]::C) { $this.Copy(); return $true }
                ([ConsoleKey]::V) { $this.Paste(); return $true }
                ([ConsoleKey]::X) { $this.Cut(); return $true }
            }
        }
        
        # Handle other special keys
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                if ($this._searchActive) {
                    $this.CancelSearch()
                    return $true
                } else {
                    $this.ExitEditor()
                    return $true
                }
            }
            ([ConsoleKey]::F3) { $this.FindNext(); return $true }
            ([ConsoleKey]::F5) { $this.RefreshFile(); return $true }
        }
        
        # CRITICAL: Let base handle Tab and route ALL other input to components
        # This ensures text input reaches the MultilineTextBox
        if (([Screen]$this).HandleInput($keyInfo)) {
            $this.UpdateCursorPosition()
            $this.UpdateStatus()
            return $true
        }
        
        return $false
    }

    # === FILE OPERATIONS ===
    hidden [void] LoadFile([string]$filePath) {
        try {
            if ([System.IO.File]::Exists($filePath)) {
                $content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
                $this._textEditor.Lines = [List[string]]::new($content -split "`n")
                $this._filePath = $filePath
                $this._fileName = [System.IO.Path]::GetFileName($filePath)
                $this._isModified = $false
                $this._lastSaved = [System.IO.File]::GetLastWriteTime($filePath)
                
                $this.UpdateTitle()
                $this.UpdateFileInfo()
                $this._statusLabel.Text = "📁 Loaded: $($this._fileName)"
                
                Write-Log -Level Info -Message "TextEditScreen: Loaded file $filePath"
            }
        } catch {
            Write-Log -Level Error -Message "TextEditScreen.LoadFile: Error loading $filePath - $_"
            $this._statusLabel.Text = "❌ Error loading file: $_"
        }
    }

    hidden [void] SaveFile() {
        try {
            if (-not $this._filePath) {
                # TODO: Show save-as dialog
                $this._statusLabel.Text = "💾 Save As dialog not implemented"
                return
            }
            
            $content = $this._textEditor.Lines -join "`n"
            [System.IO.File]::WriteAllText($this._filePath, $content, [System.Text.Encoding]::UTF8)
            $this._isModified = $false
            $this._lastSaved = [DateTime]::Now
            
            $this.UpdateTitle()
            $this._statusLabel.Text = "💾 Saved: $($this._fileName)"
            
            Write-Log -Level Info -Message "TextEditScreen: Saved file $($this._filePath)"
        } catch {
            Write-Log -Level Error -Message "TextEditScreen.SaveFile: Error saving $($this._filePath) - $_"
            $this._statusLabel.Text = "❌ Error saving file: $_"
        }
    }

    hidden [void] NewFile() {
        if ($this._isModified) {
            # TODO: Show save confirmation dialog
            Write-Log -Level Warning -Message "TextEditScreen: Creating new file with unsaved changes"
        }
        
        $this._textEditor.Lines = [List[string]]::new()
        $this._textEditor.Lines.Add("")
        $this._filePath = ""
        $this._fileName = "Untitled"
        $this._isModified = $false
        
        $this.UpdateTitle()
        $this.UpdateFileInfo()
        $this._statusLabel.Text = "📄 New file created"
    }

    hidden [void] OpenFile() {
        # TODO: Show file open dialog
        $this._statusLabel.Text = "📁 Open file dialog not implemented"
    }

    hidden [void] RefreshFile() {
        if ($this._filePath -and [System.IO.File]::Exists($this._filePath)) {
            $this.LoadFile($this._filePath)
        } else {
            $this._statusLabel.Text = "🔄 No file to refresh"
        }
    }

    # === SEARCH FUNCTIONALITY ===
    hidden [void] ShowFindDialog() {
        # TODO: Implement find dialog
        $this._statusLabel.Text = "🔍 Find dialog not implemented"
        $this._searchActive = $true
    }

    hidden [void] FindNext() {
        if ($this._searchText) {
            # TODO: Implement find next
            $this._statusLabel.Text = "🔍 Find next: $($this._searchText)"
        }
    }

    hidden [void] CancelSearch() {
        $this._searchActive = $false
        $this._statusLabel.Text = "🔍 Search cancelled"
    }

    # === EDIT OPERATIONS ===
    hidden [void] Undo() {
        if ($this._undoStack.Count -gt 0) {
            # TODO: Implement proper undo functionality
            $this._statusLabel.Text = "↶ Undo (not fully implemented)"
        } else {
            $this._statusLabel.Text = "↶ Nothing to undo"
        }
    }

    hidden [void] Redo() {
        if ($this._redoStack.Count -gt 0) {
            # TODO: Implement proper redo functionality
            $this._statusLabel.Text = "↷ Redo (not fully implemented)"
        } else {
            $this._statusLabel.Text = "↷ Nothing to redo"
        }
    }

    hidden [void] SelectAll() {
        # TODO: Implement select all
        $this._statusLabel.Text = "📝 Select All (not implemented)"
    }

    hidden [void] Copy() {
        # TODO: Implement copy to clipboard
        $this._statusLabel.Text = "📋 Copy (not implemented)"
    }

    hidden [void] Paste() {
        # TODO: Implement paste from clipboard
        $this._statusLabel.Text = "📋 Paste (not implemented)"
    }

    hidden [void] Cut() {
        # TODO: Implement cut to clipboard
        $this._statusLabel.Text = "✂️ Cut (not implemented)"
    }

    # === UI UPDATE METHODS ===
    hidden [void] UpdateTitle() {
        $modifiedIndicator = if ($this._isModified) { " *" } else { "" }
        $readOnlyIndicator = if ($this._isReadOnly) { " [READ-ONLY]" } else { "" }
        $this._mainPanel.Title = " ✏️ Text Editor - $($this._fileName)$modifiedIndicator$readOnlyIndicator "
    }

    hidden [void] UpdateStatus() {
        $lines = if ($this._textEditor.Lines) { 
            $this._textEditor.Lines.Count 
        } else { 1 }
        
        $chars = if ($this._textEditor.Lines) { 
            ($this._textEditor.Lines -join "`n").Length 
        } else { 0 }
        
        $mode = if ($this._insertMode) { "INS" } else { "OVR" }
        $encoding = $this._encoding
        
        $this._statusLabel.Text = "📊 $lines lines, $chars chars • $mode • $encoding"
    }

    hidden [void] UpdateCursorPosition() {
        # TODO: Get actual cursor position from text editor
        $this._positionLabel.Text = "Ln $($this._cursorLine), Col $($this._cursorColumn)"
    }

    hidden [void] UpdateFileInfo() {
        $this._fileLabel.Text = $this.GetFileInfo()
    }

    hidden [string] GetFileInfo() {
        if ($this._filePath) {
            $fileInfo = [System.IO.FileInfo]::new($this._filePath)
            $size = $this.FormatFileSize($fileInfo.Length)
            $modified = $fileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            return "📁 $($this._filePath) • $size • Modified: $modified"
        } else {
            return "📄 New Document (unsaved)"
        }
    }

    hidden [string] FormatFileSize([long]$bytes) {
        if ($bytes -lt 1024) { return "$bytes B" }
        if ($bytes -lt 1048576) { return "$([Math]::Round($bytes / 1024, 1)) KB" }
        return "$([Math]::Round($bytes / 1048576, 1)) MB"
    }

    hidden [void] ExitEditor() {
        if ($this._isModified) {
            # TODO: Show save confirmation dialog
            Write-Log -Level Warning -Message "TextEditScreen: Exiting with unsaved changes"
            $this._statusLabel.Text = "⚠️ Unsaved changes will be lost!"
            # For now, just exit
        }
        
        $this.GoBack()
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