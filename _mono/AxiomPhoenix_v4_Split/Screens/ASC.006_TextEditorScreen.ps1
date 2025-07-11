# ==============================================================================
# High-Performance Text Editor Screen for Axiom-Phoenix
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
        # Main editor panel
        $this._editorPanel = [Panel]::new("EditorPanel")
        $this._editorPanel.X = 0
        $this._editorPanel.Y = 0
        $this._editorPanel.Width = $this.Width
        $this._editorPanel.Height = $this.Height - 3  # Leave room for status bar
        $this._editorPanel.HasBorder = $false
        $this._editorPanel.BackgroundColor = Get-ThemeColor "Background"
        $this.AddChild($this._editorPanel)
        
        # Status bar
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 0
        $this._statusBar.Y = $this.Height - 3
        $this._statusBar.Width = $this.Width
        $this._statusBar.Height = 3
        $this._statusBar.HasBorder = $true
        $this._statusBar.BorderStyle = "Single"
        $this._statusBar.BackgroundColor = Get-ThemeColor "component.background"
        $this.AddChild($this._statusBar)
        
        # Status label
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.X = 2
        $this._statusLabel.Y = 1
        $this._statusLabel.Text = "Ready"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "Info"
        $this._statusBar.AddChild($this._statusLabel)
        
        # Position label
        $this._positionLabel = [LabelComponent]::new("PositionLabel")
        $this._positionLabel.X = $this.Width - 20
        $this._positionLabel.Y = 1
        $this._positionLabel.Text = "Ln 1, Col 1"
        $this._positionLabel.ForegroundColor = Get-ThemeColor "Subtle"
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
        $this._searchPanel.BackgroundColor = Get-ThemeColor "component.background"
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
        $this._searchBox.IsFocusable = $true
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
        $this._replaceBox.IsFocusable = $true
        $this._searchPanel.AddChild($this._replaceBox)
        
        # Search status
        $this._searchStatusLabel = [LabelComponent]::new("SearchStatus")
        $this._searchStatusLabel.X = 2
        $this._searchStatusLabel.Y = 4
        $this._searchStatusLabel.Text = ""
        $this._searchStatusLabel.ForegroundColor = Get-ThemeColor "Info"
        $this._searchPanel.AddChild($this._searchStatusLabel)
        
        # Load some initial text for demo
        $this.LoadDemoText()
    }
    
    [void] OnEnter() {
        ([Screen]$this).OnEnter()
        $this.RequestRedraw()
        $this._fullRedrawNeeded = $true
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
        $versionChanged = $this._buffer._version -ne $this._lastRenderVersion
        
        # Render visible lines
        for ($i = 0; $i -lt $editorHeight; $i++) {
            $lineIndex = $this._viewportTop + $i
            if ($lineIndex -ge $this._buffer.LineCount) { break }
            
            # Check if line needs redraw
            $needsRedraw = $this._fullRedrawNeeded -or 
                          $versionChanged -or 
                          ($lineIndex -in $dirtyLines) -or
                          -not $this._lineRenderCache.ContainsKey($lineIndex)
            
            if ($needsRedraw) {
                $this.RenderLine($buffer, $lineIndex, $i, $contentStartX, $contentWidth)
            }
        }
        
        # Render cursor
        $this.RenderCursor($buffer)
        
        # Update last render version
        $this._lastRenderVersion = $this._buffer._version
        
        # Let base class render children (status bar, search panel)
        ([Screen]$this).OnRender($buffer)
    }
    
    hidden [void] RenderLine([TuiBuffer]$buffer, [int]$lineIndex, [int]$screenY, [int]$startX, [int]$width) {
        # Render line numbers
        if ($this._showLineNumbers) {
            $lineNumStr = ($lineIndex + 1).ToString().PadLeft($this._lineNumberWidth - 1)
            $lineNumColor = Get-ThemeColor "Subtle"
            
            for ($j = 0; $j -lt $lineNumStr.Length; $j++) {
                $buffer.SetCell($j, $screenY, 
                    [TuiCell]::new($lineNumStr[$j], $lineNumColor, Get-ThemeColor "Background"))
            }
            
            # Separator
            $buffer.SetCell($this._lineNumberWidth - 1, $screenY,
                [TuiCell]::new('│', Get-ThemeColor "component.border", Get-ThemeColor "Background"))
        }
        
        # Get line text
        $lineStart = $this._buffer.GetLineStart($lineIndex)
        $lineEnd = $this._buffer.GetLineEnd($lineIndex)
        $lineText = $this._buffer.GetLineText($lineIndex)
        
        # Apply viewport horizontal offset
        if ($this._viewportLeft -gt 0 -and $lineText.Length -gt $this._viewportLeft) {
            $lineText = $lineText.Substring($this._viewportLeft)
        } elseif ($this._viewportLeft -ge $lineText.Length) {
            $lineText = ""
        }
        
        # Render visible part of line
        $visibleLength = [Math]::Min($lineText.Length, $width)
        $normalFg = Get-ThemeColor "Foreground"
        $normalBg = Get-ThemeColor "Background"
        $selectionFg = Get-ThemeColor "list.item.selected"
        $selectionBg = Get-ThemeColor "list.item.selected.background"
        
        for ($j = 0; $j -lt $visibleLength; $j++) {
            $charPos = $lineStart + $this._viewportLeft + $j
            $char = $lineText[$j]
            
            # Handle tabs
            if ($char -eq "`t") {
                $char = ' '
            }
            
            # Check if in selection
            $fg = $normalFg
            $bg = $normalBg
            if ($this._selection.ContainsPosition($charPos)) {
                $fg = $selectionFg
                $bg = $selectionBg
            }
            
            # Check if in search result
            $searchResults = $this._searchEngine._results
            foreach ($result in $searchResults) {
                if ($charPos -ge $result.Start -and $charPos -lt ($result.Start + $result.Length)) {
                    $bg = Get-ThemeColor "Warning"
                    break
                }
            }
            
            $buffer.SetCell($startX + $j, $screenY, [TuiCell]::new($char, $fg, $bg))
        }
        
        # Clear rest of line
        for ($j = $visibleLength; $j -lt $width; $j++) {
            $buffer.SetCell($startX + $j, $screenY, [TuiCell]::new(' ', $normalFg, $normalBg))
        }
        
        # Cache rendered line
        $this._lineRenderCache[$lineIndex] = $true
    }
    
    hidden [void] RenderCursor([TuiBuffer]$buffer) {
        # Calculate cursor screen position
        $cursorScreenX = $this._cursorColumn - $this._viewportLeft
        $cursorScreenY = $this._cursorLine - $this._viewportTop
        
        if ($this._showLineNumbers) {
            $cursorScreenX += $this._lineNumberWidth + 1
        }
        
        # Ensure cursor is visible
        if ($cursorScreenX -ge 0 -and $cursorScreenX -lt $this._editorPanel.Width -and
            $cursorScreenY -ge 0 -and $cursorScreenY -lt $this._editorPanel.Height) {
            
            # Get current cell
            $cell = $buffer.GetCell($cursorScreenX, $cursorScreenY)
            if ($cell) {
                # Invert colors for cursor
                $cursorCell = [TuiCell]::new($cell.Char, 
                    Get-ThemeColor "Background", 
                    Get-ThemeColor "Foreground")
                $buffer.SetCell($cursorScreenX, $cursorScreenY, $cursorCell)
            }
        }
    }
    
    hidden [void] UpdateCursorPosition() {
        $this._cursorPosition = $this._buffer.GetCursorPosition()
        $this._cursorLine = $this._buffer.GetLineFromPosition($this._cursorPosition)
        
        # Calculate column
        $lineStart = $this._buffer.GetLineStart($this._cursorLine)
        $this._cursorColumn = $this._cursorPosition - $lineStart
        
        # Update position label
        $this._positionLabel.Text = "Ln $($this._cursorLine + 1), Col $($this._cursorColumn + 1)"
        
        # Update selection if active
        if ($this._selection.IsActive) {
            $this._selection.UpdateSelection($this._cursorPosition)
        }
    }
    
    hidden [void] EnsureCursorVisible() {
        # Vertical scrolling
        if ($this._cursorLine -lt $this._viewportTop) {
            $this._viewportTop = $this._cursorLine
            $this._fullRedrawNeeded = $true
        } elseif ($this._cursorLine -ge $this._viewportTop + $this._editorPanel.Height) {
            $this._viewportTop = $this._cursorLine - $this._editorPanel.Height + 1
            $this._fullRedrawNeeded = $true
        }
        
        # Horizontal scrolling
        $contentStartX = if ($this._showLineNumbers) { $this._lineNumberWidth + 1 } else { 0 }
        $contentWidth = $this._editorPanel.Width - $contentStartX
        
        if ($this._cursorColumn -lt $this._viewportLeft) {
            $this._viewportLeft = $this._cursorColumn
            $this._fullRedrawNeeded = $true
        } elseif ($this._cursorColumn -ge $this._viewportLeft + $contentWidth) {
            $this._viewportLeft = $this._cursorColumn - $contentWidth + 1
            $this._fullRedrawNeeded = $true
        }
    }
    
    # Input handling
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Search mode input
        if ($this._isSearchMode) {
            return $this.HandleSearchInput($keyInfo)
        }
        
        # Check for modifiers
        $ctrl = ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) -ne 0
        $shift = ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) -ne 0
        $alt = ($keyInfo.Modifiers -band [ConsoleModifiers]::Alt) -ne 0
        
        # Handle shortcuts
        if ($ctrl) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::F) { $this.ShowSearchPanel(); return $true }
                ([ConsoleKey]::H) { $this.ShowSearchPanel($true); return $true }
                ([ConsoleKey]::G) { $this.GoToLine(); return $true }
                ([ConsoleKey]::A) { $this.SelectAll(); return $true }
                ([ConsoleKey]::C) { $this.Copy(); return $true }
                ([ConsoleKey]::X) { $this.Cut(); return $true }
                ([ConsoleKey]::V) { $this.Paste(); return $true }
                ([ConsoleKey]::Z) { $this.Undo(); return $true }
                ([ConsoleKey]::Y) { $this.Redo(); return $true }
                ([ConsoleKey]::S) { $this.Save(); return $true }
                ([ConsoleKey]::Q) { $this.Exit(); return $true }
            }
        }
        
        # Movement and selection
        $startSelection = $shift -and -not $this._selection.IsActive
        if ($startSelection) {
            $this._selection.StartSelection($this._cursorPosition)
        }
        
        $handled = $false
        
        switch ($keyInfo.Key) {
            # Basic movement
            ([ConsoleKey]::LeftArrow) {
                if ($ctrl) {
                    $this.MoveCursorToWordBoundary($false)
                } else {
                    $this.MoveCursorLeft()
                }
                $this._preferredColumn = $this._cursorColumn
                $handled = $true
            }
            ([ConsoleKey]::RightArrow) {
                if ($ctrl) {
                    $this.MoveCursorToWordBoundary($true)
                } else {
                    $this.MoveCursorRight()
                }
                $this._preferredColumn = $this._cursorColumn
                $handled = $true
            }
            ([ConsoleKey]::UpArrow) {
                $this.MoveCursorUp()
                $handled = $true
            }
            ([ConsoleKey]::DownArrow) {
                $this.MoveCursorDown()
                $handled = $true
            }
            ([ConsoleKey]::Home) {
                if ($ctrl) {
                    $this.MoveCursorToStart()
                } else {
                    $this.MoveCursorToLineStart()
                }
                $this._preferredColumn = $this._cursorColumn
                $handled = $true
            }
            ([ConsoleKey]::End) {
                if ($ctrl) {
                    $this.MoveCursorToEnd()
                } else {
                    $this.MoveCursorToLineEnd()
                }
                $this._preferredColumn = $this._cursorColumn
                $handled = $true
            }
            ([ConsoleKey]::PageUp) {
                $this.PageUp()
                $handled = $true
            }
            ([ConsoleKey]::PageDown) {
                $this.PageDown()
                $handled = $true
            }
            
            # Editing
            ([ConsoleKey]::Backspace) {
                if (-not $this._isReadOnly) {
                    $this.HandleBackspace()
                }
                $handled = $true
            }
            ([ConsoleKey]::Delete) {
                if (-not $this._isReadOnly) {
                    $this.HandleDelete()
                }
                $handled = $true
            }
            ([ConsoleKey]::Enter) {
                if (-not $this._isReadOnly) {
                    $this.HandleEnter()
                }
                $handled = $true
            }
            ([ConsoleKey]::Tab) {
                if (-not $this._isReadOnly) {
                    $this.HandleTab()
                }
                $handled = $true
            }
            ([ConsoleKey]::Escape) {
                if ($this._selection.IsActive) {
                    $this._selection.ClearSelection()
                    $this.RequestRedraw()
                } else {
                    $this.Exit()
                }
                $handled = $true
            }
            
            # Regular character input
            default {
                if (-not $ctrl -and -not $alt -and $keyInfo.KeyChar -ne 0 -and -not $this._isReadOnly) {
                    $this.InsertChar($keyInfo.KeyChar)
                    $handled = $true
                }
            }
        }
        
        # Update selection after movement
        if ($shift -and $handled) {
            $this._selection.UpdateSelection($this._cursorPosition)
        } elseif (-not $shift -and $this._selection.IsActive -and $handled) {
            $this._selection.ClearSelection()
        }
        
        # Update cursor and redraw
        if ($handled) {
            $this.UpdateCursorPosition()
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    # Movement methods
    hidden [void] MoveCursorLeft() {
        if ($this._cursorPosition -gt 0) {
            $this._buffer.SetCursorPosition($this._cursorPosition - 1)
        }
    }
    
    hidden [void] MoveCursorRight() {
        if ($this._cursorPosition -lt $this._buffer.Length) {
            $this._buffer.SetCursorPosition($this._cursorPosition + 1)
        }
    }
    
    hidden [void] MoveCursorUp() {
        if ($this._cursorLine -gt 0) {
            $newLine = $this._cursorLine - 1
            $lineStart = $this._buffer.GetLineStart($newLine)
            $lineLength = $this._buffer.GetLineEnd($newLine) - $lineStart
            $newColumn = [Math]::Min($this._preferredColumn, $lineLength)
            $this._buffer.SetCursorPosition($lineStart + $newColumn)
        }
    }
    
    hidden [void] MoveCursorDown() {
        if ($this._cursorLine -lt $this._buffer.LineCount - 1) {
            $newLine = $this._cursorLine + 1
            $lineStart = $this._buffer.GetLineStart($newLine)
            $lineLength = $this._buffer.GetLineEnd($newLine) - $lineStart
            $newColumn = [Math]::Min($this._preferredColumn, $lineLength)
            $this._buffer.SetCursorPosition($lineStart + $newColumn)
        }
    }
    
    hidden [void] MoveCursorToLineStart() {
        $lineStart = $this._buffer.GetLineStart($this._cursorLine)
        $lineText = $this._buffer.GetLineText($this._cursorLine)
        
        # Smart home - toggle between start and first non-whitespace
        $firstNonWhitespace = 0
        for ($i = 0; $i -lt $lineText.Length; $i++) {
            if (-not [char]::IsWhiteSpace($lineText[$i])) {
                $firstNonWhitespace = $i
                break
            }
        }
        
        if ($this._cursorColumn -eq $firstNonWhitespace) {
            $this._buffer.SetCursorPosition($lineStart)
        } else {
            $this._buffer.SetCursorPosition($lineStart + $firstNonWhitespace)
        }
    }
    
    hidden [void] MoveCursorToLineEnd() {
        $lineEnd = $this._buffer.GetLineEnd($this._cursorLine)
        $this._buffer.SetCursorPosition($lineEnd)
    }
    
    hidden [void] MoveCursorToStart() {
        $this._buffer.SetCursorPosition(0)
    }
    
    hidden [void] MoveCursorToEnd() {
        $this._buffer.SetCursorPosition($this._buffer.Length)
    }
    
    hidden [void] MoveCursorToWordBoundary([bool]$forward) {
        $newPos = $this._buffer.FindNextWordBoundary($this._cursorPosition, $forward)
        $this._buffer.SetCursorPosition($newPos)
    }
    
    hidden [void] PageUp() {
        $pageSize = [Math]::Max(1, $this._editorPanel.Height - 2)
        $this._viewportTop = [Math]::Max(0, $this._viewportTop - $pageSize)
        
        if ($this._cursorLine -ge $this._viewportTop + $this._editorPanel.Height) {
            $newLine = $this._viewportTop + $this._editorPanel.Height - 1
            $lineStart = $this._buffer.GetLineStart($newLine)
            $this._buffer.SetCursorPosition($lineStart + [Math]::Min($this._preferredColumn, 
                $this._buffer.GetLineEnd($newLine) - $lineStart))
        }
        
        $this._fullRedrawNeeded = $true
    }
    
    hidden [void] PageDown() {
        $pageSize = [Math]::Max(1, $this._editorPanel.Height - 2)
        $maxViewportTop = [Math]::Max(0, $this._buffer.LineCount - $this._editorPanel.Height)
        $this._viewportTop = [Math]::Min($maxViewportTop, $this._viewportTop + $pageSize)
        
        if ($this._cursorLine -lt $this._viewportTop) {
            $newLine = $this._viewportTop
            $lineStart = $this._buffer.GetLineStart($newLine)
            $this._buffer.SetCursorPosition($lineStart + [Math]::Min($this._preferredColumn, 
                $this._buffer.GetLineEnd($newLine) - $lineStart))
        }
        
        $this._fullRedrawNeeded = $true
    }
    
    # Editing methods
    hidden [void] InsertChar([char]$char) {
        $this.DeleteSelection()
        
        # Group rapid typing into single undo command
        $now = [datetime]::Now
        $timeSinceLastEdit = ($now - $this._lastEditTime).TotalMilliseconds
        
        if ($timeSinceLastEdit -gt 1000) {
            $this._lastCommandGroupId++
        }
        
        $cmd = [InsertCommand]::new($this._cursorPosition, $char.ToString(), $this._cursorPosition)
        $this.ExecuteCommand($cmd)
        
        $this._lastEditTime = $now
    }
    
    hidden [void] HandleBackspace() {
        if ($this._selection.IsActive) {
            $this.DeleteSelection()
        } else {
            if ($this._buffer.DeleteBackward()) {
                $this._redoStack.Clear()
            }
        }
    }
    
    hidden [void] HandleDelete() {
        if ($this._selection.IsActive) {
            $this.DeleteSelection()
        } else {
            if ($this._buffer.DeleteForward()) {
                $this._redoStack.Clear()
            }
        }
    }
    
    hidden [void] HandleEnter() {
        $this.DeleteSelection()
        
        # Get current line indentation
        $lineText = $this._buffer.GetLineText($this._cursorLine)
        $indent = ""
        for ($i = 0; $i -lt $lineText.Length; $i++) {
            if ($lineText[$i] -eq ' ' -or $lineText[$i] -eq "`t") {
                $indent += $lineText[$i]
            } else {
                break
            }
        }
        
        # Insert newline and indent
        $cmd = [InsertCommand]::new($this._cursorPosition, "`n$indent", $this._cursorPosition)
        $this.ExecuteCommand($cmd)
    }
    
    hidden [void] HandleTab() {
        $this.DeleteSelection()
        
        # Insert spaces for tab
        $spaces = " " * $this._tabSize
        $cmd = [InsertCommand]::new($this._cursorPosition, $spaces, $this._cursorPosition)
        $this.ExecuteCommand($cmd)
    }
    
    hidden [bool] DeleteSelection() {
        if (-not $this._selection.IsActive) { return $false }
        
        $start = $this._selection.GetNormalizedStart()
        $length = $this._selection.GetLength()
        
        if ($length -gt 0) {
            $deletedText = $this._buffer.GetText($start, $length)
            $cmd = [DeleteCommand]::new($start, $length, $deletedText, $this._cursorPosition)
            $this.ExecuteCommand($cmd)
            
            $this._buffer.SetCursorPosition($start)
            $this._selection.ClearSelection()
            return $true
        }
        
        return $false
    }
    
    # Command execution
    hidden [void] ExecuteCommand([IEditCommand]$cmd) {
        $cmd.Execute($this._buffer)
        $this._undoStack.Push($cmd)
        $this._redoStack.Clear()
    }
    
    # Clipboard operations
    hidden [void] Copy() {
        if ($this._selection.IsActive) {
            $start = $this._selection.GetNormalizedStart()
            $length = $this._selection.GetLength()
            $this._clipboard = $this._buffer.GetText($start, $length)
            $this._statusLabel.Text = "Copied $length characters"
        }
    }
    
    hidden [void] Cut() {
        if ($this._selection.IsActive -and -not $this._isReadOnly) {
            $this.Copy()
            $this.DeleteSelection()
        }
    }
    
    hidden [void] Paste() {
        if (-not [string]::IsNullOrEmpty($this._clipboard) -and -not $this._isReadOnly) {
            $this.DeleteSelection()
            $cmd = [InsertCommand]::new($this._cursorPosition, $this._clipboard, $this._cursorPosition)
            $this.ExecuteCommand($cmd)
        }
    }
    
    hidden [void] SelectAll() {
        $this._selection.StartSelection(0)
        $this._selection.UpdateSelection($this._buffer.Length)
        $this._buffer.SetCursorPosition($this._buffer.Length)
        $this.UpdateCursorPosition()
        $this.RequestRedraw()
    }
    
    # Undo/Redo
    hidden [void] Undo() {
        if ($this._undoStack.Count -gt 0) {
            $cmd = $this._undoStack.Pop()
            $cmd.Undo($this._buffer)
            $this._redoStack.Push($cmd)
            $this._buffer.SetCursorPosition($cmd.CursorBefore)
            $this.UpdateCursorPosition()
            $this.RequestRedraw()
        }
    }
    
    hidden [void] Redo() {
        if ($this._redoStack.Count -gt 0) {
            $cmd = $this._redoStack.Pop()
            $cmd.Execute($this._buffer)
            $this._undoStack.Push($cmd)
            $this._buffer.SetCursorPosition($cmd.CursorAfter)
            $this.UpdateCursorPosition()
            $this.RequestRedraw()
        }
    }
    
    # Search functionality
    hidden [void] ShowSearchPanel([bool]$replace = $false) {
        $this._isSearchMode = $true
        $this._isReplaceMode = $replace
        $this._searchPanel.Visible = $true
        $this._searchPanel.Title = if ($replace) { " Find & Replace " } else { " Find " }
        
        # Update search panel height
        $this._searchPanel.Height = if ($replace) { 6 } else { 4 }
        $this._replaceBox.Visible = $replace
        
        # Focus search box
        $focusManager = $this.ServiceContainer.GetService("FocusManager")
        if ($focusManager) {
            $focusManager.SetFocus($this._searchBox)
        }
        
        $this.RequestRedraw()
    }
    
    hidden [void] HideSearchPanel() {
        $this._isSearchMode = $false
        $this._isReplaceMode = $false
        $this._searchPanel.Visible = $false
        $this._searchBox.Text = ""
        $this._replaceBox.Text = ""
        $this._searchStatusLabel.Text = ""
        $this.RequestRedraw()
    }
    
    hidden [void] PerformIncrementalSearch() {
        if ([string]::IsNullOrEmpty($this._searchBox.Text)) {
            $this._searchStatusLabel.Text = ""
            return
        }
        
        $results = $this._searchEngine.Search($this._searchBox.Text, $false, $false)
        
        if ($results.Count -gt 0) {
            $this._searchStatusLabel.Text = "$($results.Count) matches found"
            $current = $this._searchEngine.GetCurrentResult()
            if ($current) {
                $this._buffer.SetCursorPosition($current.Start)
                $this.UpdateCursorPosition()
                $this.EnsureCursorVisible()
            }
        } else {
            $this._searchStatusLabel.Text = "No matches found"
        }
        
        $this.RequestRedraw()
    }
    
    hidden [bool] HandleSearchInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $this.HideSearchPanel()
                return $true
            }
            ([ConsoleKey]::Enter) {
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) {
                    # Previous result
                    $result = $this._searchEngine.PreviousResult()
                } else {
                    # Next result
                    $result = $this._searchEngine.NextResult()
                }
                
                if ($result) {
                    $this._buffer.SetCursorPosition($result.Start)
                    $this.UpdateCursorPosition()
                    $this.EnsureCursorVisible()
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::F3) {
                # Find next
                $result = $this._searchEngine.NextResult()
                if ($result) {
                    $this._buffer.SetCursorPosition($result.Start)
                    $this.UpdateCursorPosition()
                    $this.EnsureCursorVisible()
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::Tab) {
                if ($this._isReplaceMode) {
                    # Switch focus between search and replace
                    $focusManager = $this.ServiceContainer.GetService("FocusManager")
                    if ($focusManager) {
                        if ($this._searchBox.IsFocused) {
                            $focusManager.SetFocus($this._replaceBox)
                        } else {
                            $focusManager.SetFocus($this._searchBox)
                        }
                    }
                }
                return $true
            }
            ([ConsoleKey]::R) {
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
                    # Replace current
                    if ($this._searchEngine.ReplaceCurrent($this._replaceBox.Text)) {
                        $this._searchStatusLabel.Text = "Replaced 1 occurrence"
                        $this.UpdateCursorPosition()
                        $this.RequestRedraw()
                    }
                    return $true
                }
            }
            ([ConsoleKey]::A) {
                if (($keyInfo.Modifiers -band [ConsoleModifiers]::Control) -and $this._isReplaceMode) {
                    # Replace all
                    $count = $this._searchEngine.ReplaceAll($this._replaceBox.Text)
                    $this._searchStatusLabel.Text = "Replaced $count occurrences"
                    $this.UpdateCursorPosition()
                    $this.RequestRedraw()
                    return $true
                }
            }
        }
        
        # Let search/replace boxes handle their input
        return ([Screen]$this).HandleInput($keyInfo)
    }
    
    # Demo content
    hidden [void] LoadDemoText() {
        $demoText = @"
# High-Performance Text Editor Demo

Welcome to the Axiom-Phoenix Text Editor!

This editor features:
- Gap buffer for O(1) insertions at cursor position
- Efficient line indexing for fast navigation
- Viewport-only rendering for smooth scrolling
- Incremental search with highlighting
- Smart cursor movement and selection
- Undo/Redo support
- Syntax-aware indentation

## Key Bindings

### Navigation
- Arrow keys: Move cursor
- Ctrl+Arrow: Move by word
- Home/End: Move to line start/end
- Ctrl+Home/End: Move to document start/end
- PageUp/PageDown: Scroll by page

### Editing
- Ctrl+A: Select all
- Ctrl+C: Copy selection
- Ctrl+X: Cut selection
- Ctrl+V: Paste
- Ctrl+Z: Undo
- Ctrl+Y: Redo

### Search
- Ctrl+F: Find
- Ctrl+H: Find and Replace
- F3: Find next
- Shift+F3: Find previous
- Ctrl+R: Replace current (in replace mode)
- Ctrl+A: Replace all (in replace mode)

### File Operations
- Ctrl+S: Save (placeholder)
- Ctrl+Q: Exit

## Performance Features

The editor uses several optimizations:
1. **Gap Buffer**: Maintains a gap at the cursor position for O(1) insertions
2. **Line Caching**: Tracks line starts for O(1) line access
3. **Dirty Tracking**: Only redraws changed lines
4. **Viewport Rendering**: Only processes visible content

Try editing this text to see the smooth performance!
"@
        
        $this._buffer.Insert($demoText)
        $this._buffer.SetCursorPosition(0)
        $this.UpdateCursorPosition()
        $this._fullRedrawNeeded = $true
    }
    
    # Placeholder methods
    hidden [void] GoToLine() {
        $this._statusLabel.Text = "Go to line (not implemented)"
    }
    
    hidden [void] Save() {
        $this._statusLabel.Text = "Save (no filesystem access)"
    }
    
    hidden [void] Exit() {
        # Return to previous screen
        $navService = $this.ServiceContainer.GetService("NavigationService")
        if ($navService -and $navService.CanGoBack()) {
            $navService.GoBack()
        } else {
            $global:TuiState.Running = $false
        }
    }
}
