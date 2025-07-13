# ==============================================================================
# High-Performance Text Editor Screen for Axiom-Phoenix
# FIXED: Removed FocusManager dependency, uses NCURSES-style window focus model
# Smooth rendering, advanced cursor movement, and incremental search
# ==============================================================================

# Text Editor Screen with optimized rendering
class TextEditorScreen : Screen {
    # Core components
    hidden [TextBuffer]$_buffer
    hidden [SearchEngine]$_searchEngine
    hidden [TextSelection]$_selection
    
    # Cursor and viewport
    hidden [int]$_cursorPosition = 0
    hidden [int]$_cursorLine = 0
    hidden [int]$_cursorColumn = 0
    hidden [int]$_viewportTop = 0
    hidden [int]$_viewportLeft = 0
    hidden [int]$_preferredColumn = 0  # For vertical movement
    
    # UI components
    hidden [Panel]$_editorPanel
    hidden [Panel]$_statusBar
    hidden [Panel]$_searchPanel
    hidden [TextBoxComponent]$_searchBox
    hidden [TextBoxComponent]$_replaceBox
    hidden [LabelComponent]$_statusLabel
    hidden [LabelComponent]$_positionLabel
    hidden [LabelComponent]$_searchStatusLabel
    
    # Rendering optimization
    hidden [hashtable]$_lineRenderCache = @{}
    hidden [int]$_lastRenderVersion = -1
    hidden [bool]$_fullRedrawNeeded = $true
    
    # Editor state
    hidden [bool]$_isSearchMode = $false
    hidden [bool]$_isReplaceMode = $false
    hidden [bool]$_isReadOnly = $false
    hidden [string]$_clipboard = ""
    
    # Search panel uses proper Screen focus management
    
    # Undo/Redo stacks
    hidden [Stack[IEditCommand]]$_undoStack
    hidden [Stack[IEditCommand]]$_redoStack
    hidden [int]$_lastCommandGroupId = 0
    hidden [datetime]$_lastEditTime = [datetime]::MinValue
    
    # Settings
    hidden [int]$_tabSize = 4
    hidden [bool]$_showLineNumbers = $true
    hidden [int]$_lineNumberWidth = 5
    
    TextEditorScreen([ServiceContainer]$container) : base("TextEditorScreen", $container) {
        $this._buffer = [TextBuffer]::new()
        $this._searchEngine = [SearchEngine]::new($this._buffer)
        $this._selection = [TextSelection]::new()
        $this._undoStack = [Stack[IEditCommand]]::new()
        $this._redoStack = [Stack[IEditCommand]]::new()
    }
    
    [void] Initialize() {
        Write-Log -Level Debug -Message "TextEditorScreen.Initialize: Starting"
        
        # Main editor panel
        $this._editorPanel = [Panel]::new("EditorPanel")
        $this._editorPanel.X = 0
        $this._editorPanel.Y = 0
        $this._editorPanel.Width = $this.Width
        $this._editorPanel.Height = $this.Height - 3  # Leave room for status bar
        $this._editorPanel.HasBorder = $false
        $this._editorPanel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
        $this.AddChild($this._editorPanel)
        
        # Status bar
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 0
        $this._statusBar.Y = $this.Height - 3
        $this._statusBar.Width = $this.Width
        $this._statusBar.Height = 3
        $this._statusBar.HasBorder = $true
        $this._statusBar.BorderStyle = "Single"
        $this._statusBar.BackgroundColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
        $this.AddChild($this._statusBar)
        
        # Status label
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.X = 2
        $this._statusLabel.Y = 1
        $this._statusLabel.Text = "Ready"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00d4ff"
        $this._statusBar.AddChild($this._statusLabel)
        
        # Menu instructions - show available commands
        $menuLabel = [LabelComponent]::new("MenuLabel")
        $menuLabel.X = 25
        $menuLabel.Y = 1
        $menuLabel.Text = "^O:Open ^S:Save ^F:Find ^Q:Quit"
        $menuLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#d4d4d4"
        $this._statusBar.AddChild($menuLabel)
        
        # Position label
        $this._positionLabel = [LabelComponent]::new("PositionLabel")
        $this._positionLabel.X = $this.Width - 20
        $this._positionLabel.Y = 1
        $this._positionLabel.Text = "Ln 1, Col 1"
        $this._positionLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#666666"
        $this._statusBar.AddChild($this._positionLabel)
        
        # Search panel (hidden by default)
        $this._searchPanel = [Panel]::new("SearchPanel")
        $this._searchPanel.X = 5
        $this._searchPanel.Y = 2
        $this._searchPanel.Width = [Math]::Min(60, $this.Width - 10)
        $this._searchPanel.Height = 6
        $this._searchPanel.HasBorder = $true
        $this._searchPanel.BorderStyle = "Double"
        $this._searchPanel.Title = " Find & Replace "
        $this._searchPanel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
        $this._searchPanel.Visible = $false
        $this._searchPanel.IsOverlay = $true
        $this.AddChild($this._searchPanel)
        
        # Search box
        $searchLabel = [LabelComponent]::new("SearchLabel")
        $searchLabel.X = 2
        $searchLabel.Y = 1
        $searchLabel.Text = "Find:"
        $this._searchPanel.AddChild($searchLabel)
        
        $this._searchBox = [TextBoxComponent]::new("SearchBox")
        $this._searchBox.X = 8
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this._searchPanel.Width - 10
        $this._searchBox.IsFocusable = $false  # Will be set to true when panel opens
        $thisEditor = $this
        $this._searchBox.OnChange = {
            param($sender, $text)
            $thisEditor.PerformIncrementalSearch()
        }.GetNewClosure()
        $this._searchPanel.AddChild($this._searchBox)
        
        # Replace box
        $replaceLabel = [LabelComponent]::new("ReplaceLabel")
        $replaceLabel.X = 2
        $replaceLabel.Y = 2
        $replaceLabel.Text = "Replace:"
        $this._searchPanel.AddChild($replaceLabel)
        
        $this._replaceBox = [TextBoxComponent]::new("ReplaceBox")
        $this._replaceBox.X = 11
        $this._replaceBox.Y = 2
        $this._replaceBox.Width = $this._searchPanel.Width - 13
        $this._replaceBox.IsFocusable = $false  # Will be set to true when panel opens
        $this._searchPanel.AddChild($this._replaceBox)
        
        # Search status
        $this._searchStatusLabel = [LabelComponent]::new("SearchStatus")
        $this._searchStatusLabel.X = 2
        $this._searchStatusLabel.Y = 4
        $this._searchStatusLabel.Text = ""
        $this._searchStatusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00d4ff"
        $this._searchPanel.AddChild($this._searchStatusLabel)
        
        # Load some initial text for demo
        $this.LoadDemoText()
        
        Write-Log -Level Debug -Message "TextEditorScreen.Initialize: Completed"
    }
    
    [void] OnEnter() {
        Write-Log -Level Debug -Message "TextEditorScreen.OnEnter: Starting"
        
        # Call base to set up focus system
        ([Screen]$this).OnEnter()
        $this.RequestRedraw()
        $this._fullRedrawNeeded = $true
    }
    
    [void] OnExit() {
        Write-Log -Level Debug -Message "TextEditorScreen.OnExit: Cleaning up"
        # Nothing to clean up
    }
    
    # Optimized rendering
    [void] OnRender([TuiBuffer]$buffer) {
        if (-not $buffer) { return }
        
        # Clear if full redraw needed
        if ($this._fullRedrawNeeded) {
            $buffer.Clear()
            $this._lineRenderCache.Clear()
            $this._fullRedrawNeeded = $false
        }
        
        # Calculate viewport dimensions
        $editorWidth = $this._editorPanel.Width
        $editorHeight = $this._editorPanel.Height
        $contentStartX = if ($this._showLineNumbers) { $this._lineNumberWidth + 1 } else { 0 }
        $contentWidth = $editorWidth - $contentStartX
        
        # Ensure viewport is in bounds
        $this.EnsureCursorVisible()
        
        # Get dirty lines
        $dirtyLines = $this._buffer.GetAndClearDirtyLines()
        
        # Render visible lines
        for ($i = 0; $i -lt $editorHeight; $i++) {
            $lineIndex = $this._viewportTop + $i
            if ($lineIndex -ge $this._buffer.LineCount) { break }
            
            # Check if line needs redraw
            $needsRedraw = $this._fullRedrawNeeded -or ($lineIndex -in $dirtyLines) -or 
                           ($this._buffer._version -ne $this._lastRenderVersion)
            
            if ($needsRedraw) {
                $this.RenderLine($buffer, $lineIndex, $i)
            }
        }
        
        # Update cursor position in buffer
        $cursorScreenX = $this._editorPanel.X + $contentStartX + $this._cursorColumn - $this._viewportLeft
        $cursorScreenY = $this._editorPanel.Y + $this._cursorLine - $this._viewportTop
        
        if ($cursorScreenX -ge $this._editorPanel.X + $contentStartX -and 
            $cursorScreenX -lt $this._editorPanel.X + $editorWidth -and
            $cursorScreenY -ge $this._editorPanel.Y -and 
            $cursorScreenY -lt $this._editorPanel.Y + $editorHeight) {
            $buffer.SetCursorPosition($cursorScreenX, $cursorScreenY)
            $buffer.ShowCursor = $true
        }
        
        # Update position label
        $this._positionLabel.Text = "Ln $($this._cursorLine + 1), Col $($this._cursorColumn + 1)"
        
        $this._lastRenderVersion = $this._buffer._version
    }
    
    hidden [void] RenderLine([TuiBuffer]$buffer, [int]$lineIndex, [int]$screenRow) {
        $y = $this._editorPanel.Y + $screenRow
        $lineText = $this._buffer.GetLineText($lineIndex)
        
        # Render line numbers
        $x = $this._editorPanel.X
        if ($this._showLineNumbers) {
            $lineNum = ($lineIndex + 1).ToString().PadLeft($this._lineNumberWidth - 1)
            $lineNumColor = Get-ThemeColor "Label.Foreground" "#666666"
            
            for ($i = 0; $i -lt $lineNum.Length; $i++) {
                $cell = [TuiCell]::new($lineNum[$i], $lineNumColor, $null)
                $buffer.SetCell($x + $i, $y, $cell)
            }
            
            # Separator
            $cell = [TuiCell]::new('│', $lineNumColor, $null)
            $buffer.SetCell($x + $this._lineNumberWidth - 1, $y, $cell)
            
            $x += $this._lineNumberWidth
        }
        
        # Clear the line first
        $contentWidth = $this._editorPanel.Width - ($x - $this._editorPanel.X)
        for ($i = 0; $i -lt $contentWidth; $i++) {
            $cell = [TuiCell]::new(' ', $null, $null)
            $buffer.SetCell($x + $i, $y, $cell)
        }
        
        # Render visible text
        if ($lineText.Length -gt $this._viewportLeft) {
            $visibleText = $lineText.Substring($this._viewportLeft)
            $maxLength = [Math]::Min($visibleText.Length, $contentWidth)
            
            for ($i = 0; $i -lt $maxLength; $i++) {
                $char = $visibleText[$i]
                $fg = Get-ThemeColor "Label.Foreground" "#d4d4d4"
                
                # Highlight selection if active
                $absolutePos = $this._buffer.GetLineStart($lineIndex) + $this._viewportLeft + $i
                if ($this._selection.IsActive -and $this._selection.ContainsPosition($absolutePos)) {
                    $fg = Get-ThemeColor "List.ItemSelected" "#ffffff"
                    $bg = Get-ThemeColor "List.ItemSelectedBackground" "#007acc"
                    $cell = [TuiCell]::new($char, $fg, $bg)
                } else {
                    $cell = [TuiCell]::new($char, $fg, $null)
                }
                
                $buffer.SetCell($x + $i, $y, $cell)
            }
        }
        
        # Cache the rendered line
        $this._lineRenderCache[$lineIndex] = $this._buffer._version
    }
    
    hidden [void] EnsureCursorVisible() {
        # Vertical scrolling
        if ($this._cursorLine -lt $this._viewportTop) {
            $this._viewportTop = $this._cursorLine
        } elseif ($this._cursorLine -ge $this._viewportTop + $this._editorPanel.Height) {
            $this._viewportTop = $this._cursorLine - $this._editorPanel.Height + 1
        }
        
        # Horizontal scrolling
        $contentStartX = if ($this._showLineNumbers) { $this._lineNumberWidth + 1 } else { 0 }
        $visibleWidth = $this._editorPanel.Width - $contentStartX
        
        if ($this._cursorColumn -lt $this._viewportLeft) {
            $this._viewportLeft = $this._cursorColumn
        } elseif ($this._cursorColumn -ge $this._viewportLeft + $visibleWidth) {
            $this._viewportLeft = $this._cursorColumn - $visibleWidth + 1
        }
    }
    
    hidden [void] UpdateCursorPosition() {
        $pos = $this._buffer.GetCursorPosition()
        $this._cursorPosition = $pos
        $this._cursorLine = $this._buffer.GetLineFromPosition($pos)
        $lineStart = $this._buffer.GetLineStart($this._cursorLine)
        $this._cursorColumn = $pos - $lineStart
    }
    
    hidden [void] MoveCursorTo([int]$line, [int]$column) {
        $line = [Math]::Max(0, [Math]::Min($line, $this._buffer.LineCount - 1))
        $lineStart = $this._buffer.GetLineStart($line)
        $lineEnd = $this._buffer.GetLineEnd($line)
        $lineLength = $lineEnd - $lineStart
        
        $column = [Math]::Max(0, [Math]::Min($column, $lineLength))
        $newPos = $lineStart + $column
        
        $this._buffer.SetCursorPosition($newPos)
        $this.UpdateCursorPosition()
        $this.RequestRedraw()
    }
    
    # Movement commands
    hidden [void] MoveCursorLeft() {
        if ($this._cursorPosition -gt 0) {
            $this._buffer.SetCursorPosition($this._cursorPosition - 1)
            $this.UpdateCursorPosition()
            $this._preferredColumn = $this._cursorColumn
        }
    }
    
    hidden [void] MoveCursorRight() {
        if ($this._cursorPosition -lt $this._buffer.Length) {
            $this._buffer.SetCursorPosition($this._cursorPosition + 1)
            $this.UpdateCursorPosition()
            $this._preferredColumn = $this._cursorColumn
        }
    }
    
    hidden [void] MoveCursorUp() {
        if ($this._cursorLine -gt 0) {
            $this.MoveCursorTo($this._cursorLine - 1, $this._preferredColumn)
        }
    }
    
    hidden [void] MoveCursorDown() {
        if ($this._cursorLine -lt $this._buffer.LineCount - 1) {
            $this.MoveCursorTo($this._cursorLine + 1, $this._preferredColumn)
        }
    }
    
    hidden [void] MoveCursorHome() {
        $this.MoveCursorTo($this._cursorLine, 0)
        $this._preferredColumn = 0
    }
    
    hidden [void] MoveCursorEnd() {
        $lineEnd = $this._buffer.GetLineEnd($this._cursorLine)
        $lineStart = $this._buffer.GetLineStart($this._cursorLine)
        $this.MoveCursorTo($this._cursorLine, $lineEnd - $lineStart)
        $this._preferredColumn = $this._cursorColumn
    }
    
    hidden [void] MoveCursorWordLeft() {
        $newPos = $this._buffer.FindNextWordBoundary($this._cursorPosition, $false)
        $this._buffer.SetCursorPosition($newPos)
        $this.UpdateCursorPosition()
        $this._preferredColumn = $this._cursorColumn
    }
    
    hidden [void] MoveCursorWordRight() {
        $newPos = $this._buffer.FindNextWordBoundary($this._cursorPosition, $true)
        $this._buffer.SetCursorPosition($newPos)
        $this.UpdateCursorPosition()
        $this._preferredColumn = $this._cursorColumn
    }
    
    # Editing commands
    hidden [void] InsertChar([char]$char) {
        if ($this._isReadOnly) { return }
        
        $command = [InsertCommand]::new($this._cursorPosition, $char.ToString(), $this._cursorPosition)
        $this.ExecuteCommand($command)
        $this.MoveCursorRight()
    }
    
    hidden [void] InsertText([string]$text) {
        if ($this._isReadOnly -or [string]::IsNullOrEmpty($text)) { return }
        
        $command = [InsertCommand]::new($this._cursorPosition, $text, $this._cursorPosition)
        $this.ExecuteCommand($command)
        
        # Move cursor to end of inserted text
        $this._buffer.SetCursorPosition($this._cursorPosition + $text.Length)
        $this.UpdateCursorPosition()
    }
    
    hidden [void] DeleteBackward() {
        if ($this._isReadOnly -or $this._cursorPosition -eq 0) { return }
        
        $this.MoveCursorLeft()
        $deletedChar = $this._buffer.GetChar($this._cursorPosition)
        $command = [DeleteCommand]::new($this._cursorPosition, 1, $deletedChar.ToString(), $this._cursorPosition + 1)
        $this.ExecuteCommand($command)
    }
    
    hidden [void] DeleteForward() {
        if ($this._isReadOnly -or $this._cursorPosition -ge $this._buffer.Length) { return }
        
        $deletedChar = $this._buffer.GetChar($this._cursorPosition)
        $command = [DeleteCommand]::new($this._cursorPosition, 1, $deletedChar.ToString(), $this._cursorPosition)
        $this.ExecuteCommand($command)
    }
    
    hidden [void] ExecuteCommand([IEditCommand]$command) {
        $command.Execute($this._buffer)
        $this._undoStack.Push($command)
        $this._redoStack.Clear()
        $this.UpdateCursorPosition()
        $this._fullRedrawNeeded = $true
        $this.RequestRedraw()
    }
    
    hidden [void] Undo() {
        if ($this._undoStack.Count -eq 0) { return }
        
        $command = $this._undoStack.Pop()
        $command.Undo($this._buffer)
        $this._redoStack.Push($command)
        
        # Restore cursor position
        $this._buffer.SetCursorPosition($command.CursorBefore)
        $this.UpdateCursorPosition()
        $this._fullRedrawNeeded = $true
        $this.RequestRedraw()
    }
    
    hidden [void] Redo() {
        if ($this._redoStack.Count -eq 0) { return }
        
        $command = $this._redoStack.Pop()
        $command.Execute($this._buffer)
        $this._undoStack.Push($command)
        
        # Restore cursor position
        $this._buffer.SetCursorPosition($command.CursorAfter)
        $this.UpdateCursorPosition()
        $this._fullRedrawNeeded = $true
        $this.RequestRedraw()
    }
    
    # File operations
    hidden [void] OpenFile() {
        # Would show file dialog
        $this._statusLabel.Text = "Open file: Feature requires file dialog"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00d4ff"
    }
    
    hidden [void] SaveFile() {
        # Would save to file
        $this._statusLabel.Text = "File saved (simulated)"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00ff88"
    }
    
    # Search operations
    hidden [void] ShowSearchPanel([bool]$replace = $false) {
        $this._isSearchMode = $true
        $this._isReplaceMode = $replace
        $this._searchPanel.Visible = $true
        
        # Update search panel height
        $this._searchPanel.Height = if ($replace) { 6 } else { 4 }
        $this._replaceBox.Visible = $replace
        
        # Make search boxes focusable and add focus handlers
        $this._searchBox.IsFocusable = $true
        $this._searchBox.TabIndex = 0
        $this._searchBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.ShowCursor = $true
            # TextBoxComponent inherits BorderColor from UIElement, which does not have a setter. Direct assignment is fine.
            $this.BorderColor = Get-ThemeColor "Input.FocusedBorder" "#00d4ff"
            $this.RequestRedraw()
        } -Force
        $this._searchBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.ShowCursor = $false
            # Direct assignment for BorderColor is fine.
            $this.BorderColor = Get-ThemeColor "Input.Border" "#444444"
            $this.RequestRedraw()
        } -Force
        
        if ($replace) {
            $this._replaceBox.IsFocusable = $true
            $this._replaceBox.TabIndex = 1
            $this._replaceBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
                $this.ShowCursor = $true
                # Direct assignment for BorderColor is fine.
                $this.BorderColor = Get-ThemeColor "Input.FocusedBorder" "#00d4ff"
                $this.RequestRedraw()
            } -Force
            $this._replaceBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
                $this.ShowCursor = $false
                # Direct assignment for BorderColor is fine.
                $this.BorderColor = Get-ThemeColor "Input.Border" "#444444"
                $this.RequestRedraw()
            } -Force
        }
        
        # Invalidate focus cache and focus the search box
        $this.InvalidateFocusCache()
        $this.SetChildFocus($this._searchBox)
        
        $this.RequestRedraw()
    }
    
    hidden [void] HideSearchPanel() {
        # Clear focus before hiding
        $this.ClearFocus()
        
        $this._isSearchMode = $false
        $this._isReplaceMode = $false
        $this._searchPanel.Visible = $false
        $this._searchBox.Text = ""
        $this._replaceBox.Text = ""
        $this._searchStatusLabel.Text = ""
        
        # Make search boxes non-focusable when hidden
        $this._searchBox.IsFocusable = $false
        $this._searchBox.ShowCursor = $false
        $this._replaceBox.IsFocusable = $false
        $this._replaceBox.ShowCursor = $false
        
        # Invalidate focus cache
        $this.InvalidateFocusCache()
        
        $this.RequestRedraw()
    }
    
    hidden [void] PerformIncrementalSearch() {
        if ([string]::IsNullOrEmpty($this._searchBox.Text)) {
            $this._searchStatusLabel.Text = ""
            return
        }
        
        $results = $this._searchEngine.Search($this._searchBox.Text, $false, $false)
        if ($results.Count -gt 0) {
            $this._searchStatusLabel.Text = "Found $($results.Count) matches"
            $this._searchStatusLabel.ForegroundColor = Get-ThemeColor "Label.Foreground" "#00ff88"
            
            # Move to first result
            $firstResult = $this._searchEngine.GetCurrentResult()
            if ($firstResult) {
                $this._buffer.SetCursorPosition($firstResult.Start)
                $this.UpdateCursorPosition()
                $this._selection.StartSelection($firstResult.Start)
                $this._selection.UpdateSelection($firstResult.Start + $firstResult.Length)
            }
        } else {
            $this._searchStatusLabel.Text = "No matches found"
            $this._searchStatusLabel.ForegroundColor = Get-ThemeColor "Warning"
        }
        
        $this._fullRedrawNeeded = $true
        $this.RequestRedraw()
    }
    
    hidden [void] FindNext() {
        $result = $this._searchEngine.NextResult()
        if ($result) {
            $this._buffer.SetCursorPosition($result.Start)
            $this.UpdateCursorPosition()
            $this._selection.StartSelection($result.Start)
            $this._selection.UpdateSelection($result.Start + $result.Length)
            $this._fullRedrawNeeded = $true
            $this.RequestRedraw()
        }
    }
    
    hidden [void] FindPrevious() {
        $result = $this._searchEngine.PreviousResult()
        if ($result) {
            $this._buffer.SetCursorPosition($result.Start)
            $this.UpdateCursorPosition()
            $this._selection.StartSelection($result.Start)
            $this._selection.UpdateSelection($result.Start + $result.Length)
            $this._fullRedrawNeeded = $true
            $this.RequestRedraw()
        }
    }
    
    # Demo content
    hidden [void] LoadDemoText() {
        $demoText = @"
Welcome to the Axiom-Phoenix Text Editor!

Features:
- Smooth cursor movement with arrow keys
- Word navigation with Ctrl+Left/Right
- Home/End: Move to line start/end
- Page Up/Down: Scroll by page
- Ctrl+Home/End: Go to document start/end
- Ctrl+S: Save file
- Ctrl+O: Open file
- Ctrl+F: Find text
- Ctrl+H: Find and replace
- Ctrl+Z: Undo
- Ctrl+Y: Redo
- F3: Find next
- Shift+F3: Find previous
- Ctrl+Q: Quit editor

This editor uses a high-performance gap buffer for efficient text editing.
Try typing, navigating, and searching to see the smooth performance!
"@
        
        $this._buffer.Insert($demoText)
        $this._buffer.SetCursorPosition(0)
        $this.UpdateCursorPosition()
    }
    
    # === INPUT HANDLING (HYBRID MODEL FOR SEARCH, DIRECT FOR EDITING) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "TextEditorScreen.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "TextEditorScreen.HandleInput: Key=$($keyInfo.Key), SearchMode=$($this._isSearchMode)"
        
        # When search panel is open, use hybrid model for Tab navigation
        if ($this._isSearchMode) {
            # Let base Screen handle Tab navigation between search components
            if (([Screen]$this).HandleInput($keyInfo)) {
                return $true
            }
            # Handle search-specific shortcuts
            return $this.HandleSearchInput($keyInfo)
        }
        
        # Main editor input handling
        $handled = $true
        
        # Ctrl combinations
        if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::F) {
                    $this.ShowSearchPanel($false)
                    return $true
                }
                ([ConsoleKey]::H) {
                    $this.ShowSearchPanel($true)
                    return $true
                }
                ([ConsoleKey]::O) {
                    $this.OpenFile()
                    return $true
                }
                ([ConsoleKey]::S) {
                    $this.SaveFile()
                    return $true
                }
                ([ConsoleKey]::Q) {
                    # Quit
                    $navService = $this.ServiceContainer.GetService("NavigationService")
                    if ($navService.CanGoBack()) {
                        $navService.GoBack()
                    }
                    return $true
                }
                ([ConsoleKey]::Z) {
                    $this.Undo()
                    return $true
                }
                ([ConsoleKey]::Y) {
                    $this.Redo()
                    return $true
                }
                ([ConsoleKey]::LeftArrow) {
                    $this.MoveCursorWordLeft()
                    return $true
                }
                ([ConsoleKey]::RightArrow) {
                    $this.MoveCursorWordRight()
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $this.MoveCursorTo(0, 0)
                    return $true
                }
                ([ConsoleKey]::End) {
                    $lastLine = $this._buffer.LineCount - 1
                    $this.MoveCursorTo($lastLine, [int]::MaxValue)
                    return $true
                }
                default { $handled = $false }
            }
        }
        # Regular keys
        else {
            switch ($keyInfo.Key) {
                # Navigation
                ([ConsoleKey]::LeftArrow) {
                    $this.MoveCursorLeft()
                    return $true
                }
                ([ConsoleKey]::RightArrow) {
                    $this.MoveCursorRight()
                    return $true
                }
                ([ConsoleKey]::UpArrow) {
                    $this.MoveCursorUp()
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    $this.MoveCursorDown()
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $this.MoveCursorHome()
                    return $true
                }
                ([ConsoleKey]::End) {
                    $this.MoveCursorEnd()
                    return $true
                }
                ([ConsoleKey]::PageUp) {
                    for ($i = 0; $i -lt $this._editorPanel.Height - 1; $i++) {
                        $this.MoveCursorUp()
                    }
                    return $true
                }
                ([ConsoleKey]::PageDown) {
                    for ($i = 0; $i -lt $this._editorPanel.Height - 1; $i++) {
                        $this.MoveCursorDown()
                    }
                    return $true
                }
                
                # Editing
                ([ConsoleKey]::Backspace) {
                    $this.DeleteBackward()
                    return $true
                }
                ([ConsoleKey]::Delete) {
                    $this.DeleteForward()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    $this.InsertChar("`n")
                    return $true
                }
                ([ConsoleKey]::Tab) {
                    # Insert spaces for tab
                    for ($i = 0; $i -lt $this._tabSize; $i++) {
                        $this.InsertChar(' ')
                    }
                    return $true
                }
                
                # Function keys
                ([ConsoleKey]::F3) {
                    if ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) {
                        $this.FindPrevious()
                    } else {
                        $this.FindNext()
                    }
                    return $true
                }
                
                ([ConsoleKey]::Escape) {
                    if ($this._selection.IsActive) {
                        $this._selection.ClearSelection()
                        $this._fullRedrawNeeded = $true
                        $this.RequestRedraw()
                    } else {
                        # Go back
                        $navService = $this.ServiceContainer.GetService("NavigationService")
                        if ($navService.CanGoBack()) {
                            $navService.GoBack()
                        }
                    }
                    return $true
                }
                
                default {
                    # Regular character input
                    if ($keyInfo.KeyChar -and $keyInfo.KeyChar -ne "`0") {
                        $this.InsertChar($keyInfo.KeyChar)
                        return $true
                    }
                    $handled = $false
                }
            }
        }
        
        # Let base Screen handle any unhandled keys (global shortcuts, etc.)
        return ([Screen]$this).HandleInput($keyInfo)
    }
    
    hidden [bool] HandleSearchInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $this.HideSearchPanel()
                return $true
            }
            ([ConsoleKey]::Enter) {
                $this.FindNext()
                return $true
            }
            ([ConsoleKey]::R) {
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
                    # Replace current
                    if ($this._searchEngine.ReplaceCurrent($this._replaceBox.Text)) {
                        $this._searchStatusLabel.Text = "Replaced 1 occurrence"
                        $this._searchStatusLabel.ForegroundColor = Get-ThemeColor "Success"
                        $this._fullRedrawNeeded = $true
                        $this.RequestRedraw()
                    }
                    return $true
                }
            }
            ([ConsoleKey]::A) {
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
                    # Replace all
                    $count = $this._searchEngine.ReplaceAll($this._replaceBox.Text)
                    $this._searchStatusLabel.Text = "Replaced $count occurrences"
                    $this._searchStatusLabel.ForegroundColor = Get-ThemeColor "Success"
                    $this._fullRedrawNeeded = $true
                    $this.RequestRedraw()
                    return $true
                }
            }
            ([ConsoleKey]::F3) {
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) {
                    $this.FindPrevious()
                } else {
                    $this.FindNext()
                }
                return $true
            }
        }
        
        # Let focused search component handle text input
        # The TextBoxComponent.HandleInput() will handle character input
        return $false
    }
}

# ==============================================================================
# END OF TEXT EDITOR SCREEN
# ==============================================================================