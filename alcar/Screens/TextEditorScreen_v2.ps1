# TextEditorScreen v2 - Enhanced with gap buffer algorithm and AxiomPhoenix improvements

class GapBuffer {
    hidden [char[]]$Buffer
    hidden [int]$GapStart
    hidden [int]$GapEnd
    hidden [int]$Capacity
    
    GapBuffer([int]$initialCapacity = 1024) {
        $this.Capacity = $initialCapacity
        $this.Buffer = New-Object char[] $this.Capacity
        $this.GapStart = 0
        $this.GapEnd = $this.Capacity
    }
    
    [int] get_Length() {
        return $this.Capacity - ($this.GapEnd - $this.GapStart)
    }
    
    [void] MoveGap([int]$position) {
        if ($position -eq $this.GapStart) { return }
        
        if ($position -lt $this.GapStart) {
            # Move gap left
            $count = $this.GapStart - $position
            [Array]::Copy($this.Buffer, $position, $this.Buffer, $this.GapEnd - $count, $count)
            $this.GapStart = $position
            $this.GapEnd -= $count
        } else {
            # Move gap right
            $count = $position - $this.GapStart
            [Array]::Copy($this.Buffer, $this.GapEnd, $this.Buffer, $this.GapStart, $count)
            $this.GapStart += $count
            $this.GapEnd += $count
        }
    }
    
    [void] Insert([int]$position, [char]$ch) {
        $this.MoveGap($position)
        
        # Expand buffer if needed
        if ($this.GapStart -eq $this.GapEnd) {
            $this.Expand()
        }
        
        $this.Buffer[$this.GapStart] = $ch
        $this.GapStart++
    }
    
    [void] Delete([int]$position) {
        $this.MoveGap($position)
        if ($this.GapEnd -lt $this.Capacity) {
            $this.GapEnd++
        }
    }
    
    [void] Expand() {
        $newCapacity = $this.Capacity * 2
        $newBuffer = New-Object char[] $newCapacity
        
        # Copy before gap
        [Array]::Copy($this.Buffer, 0, $newBuffer, 0, $this.GapStart)
        
        # Copy after gap
        $afterGapCount = $this.Capacity - $this.GapEnd
        [Array]::Copy($this.Buffer, $this.GapEnd, $newBuffer, $newCapacity - $afterGapCount, $afterGapCount)
        
        $this.GapEnd = $newCapacity - $afterGapCount
        $this.Buffer = $newBuffer
        $this.Capacity = $newCapacity
    }
    
    [char] GetChar([int]$position) {
        if ($position -lt $this.GapStart) {
            return $this.Buffer[$position]
        } else {
            return $this.Buffer[$position + ($this.GapEnd - $this.GapStart)]
        }
    }
    
    [string] ToString() {
        $result = New-Object System.Text.StringBuilder
        
        # Before gap
        for ($i = 0; $i -lt $this.GapStart; $i++) {
            [void]$result.Append($this.Buffer[$i])
        }
        
        # After gap
        for ($i = $this.GapEnd; $i -lt $this.Capacity; $i++) {
            [void]$result.Append($this.Buffer[$i])
        }
        
        return $result.ToString()
    }
}

class TextEditorScreenV2 : Screen {
    [string]$FilePath
    hidden [GapBuffer]$Buffer
    [int]$CursorPosition = 0
    [int]$ScrollOffsetY = 0
    [int]$ScrollOffsetX = 0
    [bool]$Modified = $false
    [bool]$InsertMode = $true
    [string]$StatusMessage = ""
    
    # Editor settings
    [int]$TabWidth = 4
    [bool]$ShowLineNumbers = $true
    [int]$LineNumberWidth = 5
    
    # Undo/Redo stacks
    hidden [System.Collections.Generic.Stack[object]]$UndoStack
    hidden [System.Collections.Generic.Stack[object]]$RedoStack
    
    # Performance: pre-resolved colors
    hidden [hashtable]$Colors = @{}
    
    # Cached line information
    hidden [int[]]$LineStarts = @(0)
    hidden [bool]$LinesCacheDirty = $true
    
    TextEditorScreenV2([string]$filePath) {
        $this.FilePath = $filePath
        $this.Title = "Text Editor v2"
        $this.Buffer = [GapBuffer]::new(1024)
        $this.UndoStack = [System.Collections.Generic.Stack[object]]::new()
        $this.RedoStack = [System.Collections.Generic.Stack[object]]::new()
        $this.Initialize()
    }
    
    TextEditorScreenV2() {
        $this.FilePath = ""
        $this.Title = "Text Editor v2 - New File"
        $this.Buffer = [GapBuffer]::new(1024)
        $this.UndoStack = [System.Collections.Generic.Stack[object]]::new()
        $this.RedoStack = [System.Collections.Generic.Stack[object]]::new()
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Pre-resolve theme colors for performance
        $this.Colors = @{
            Background = [VT]::RGB(30, 30, 30)
            Foreground = [VT]::RGB(212, 212, 212)
            LineNumber = [VT]::RGB(100, 100, 150)
            Keyword = [VT]::RGB(150, 150, 255)
            String = [VT]::RGB(200, 150, 100)
            Comment = [VT]::RGB(100, 150, 100)
            Modified = [VT]::RGB(255, 200, 100)
        }
        
        # Load file if specified
        if ($this.FilePath -and (Test-Path $this.FilePath)) {
            $this.LoadFile()
        }
        
        # Key bindings
        $this.InitializeKeyBindings()
        
        # Update status bar
        $this.UpdateStatusBar()
    }
    
    [void] LoadFile() {
        try {
            $content = Get-Content -Path $this.FilePath -Raw
            if ($content) {
                foreach ($char in $content.ToCharArray()) {
                    $this.Buffer.Insert($this.Buffer.Length, $char)
                }
            }
            $this.Title = "Text Editor v2 - $([System.IO.Path]::GetFileName($this.FilePath))"
            $this.Modified = $false
            $this.LinesCacheDirty = $true
            $this.UpdateLineStarts()
        }
        catch {
            $this.StatusMessage = "Error loading file: $_"
        }
    }
    
    [void] SaveFile() {
        if (-not $this.FilePath) {
            $this.StatusMessage = "No file name - use Ctrl+S to save as"
            return
        }
        
        try {
            $content = $this.Buffer.ToString()
            Set-Content -Path $this.FilePath -Value $content -NoNewline
            $this.Modified = $false
            $this.StatusMessage = "File saved"
            $this.UpdateStatusBar()
        }
        catch {
            $this.StatusMessage = "Error saving file: $_"
        }
    }
    
    [void] UpdateLineStarts() {
        if (-not $this.LinesCacheDirty) { return }
        
        $this.LineStarts = @(0)
        $length = $this.Buffer.Length
        
        for ($i = 0; $i -lt $length; $i++) {
            if ($this.Buffer.GetChar($i) -eq "`n") {
                $this.LineStarts += ($i + 1)
            }
        }
        
        $this.LinesCacheDirty = $false
    }
    
    [int] GetCurrentLine() {
        $this.UpdateLineStarts()
        
        for ($i = $this.LineStarts.Count - 1; $i -ge 0; $i--) {
            if ($this.CursorPosition -ge $this.LineStarts[$i]) {
                return $i
            }
        }
        return 0
    }
    
    [int] GetCurrentColumn() {
        $line = $this.GetCurrentLine()
        return $this.CursorPosition - $this.LineStarts[$line]
    }
    
    [void] InitializeKeyBindings() {
        # Navigation
        $this.BindKey([ConsoleKey]::UpArrow, { $this.MoveCursor(0, -1) })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.MoveCursor(0, 1) })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.MoveCursorLeft() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.MoveCursorRight() })
        $this.BindKey([ConsoleKey]::Home, { $this.MoveCursorHome() })
        $this.BindKey([ConsoleKey]::End, { $this.MoveCursorEnd() })
        $this.BindKey([ConsoleKey]::PageUp, { $this.PageUp() })
        $this.BindKey([ConsoleKey]::PageDown, { $this.PageDown() })
        
        # Editing
        $this.BindKey([ConsoleKey]::Enter, { $this.InsertNewline() })
        $this.BindKey([ConsoleKey]::Backspace, { $this.Backspace() })
        $this.BindKey([ConsoleKey]::Delete, { $this.Delete() })
        $this.BindKey([ConsoleKey]::Tab, { $this.InsertTab() })
        
        # File operations
        $this.KeyBindings[[ConsoleKey]::S] = { 
            param($key)
            if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                $this.SaveFile()
            } else {
                $this.InsertChar('s')
            }
        }
        
        # Undo/Redo
        $this.KeyBindings[[ConsoleKey]::Z] = {
            param($key)
            if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                $this.Undo()
            } else {
                $this.InsertChar('z')
            }
        }
        
        $this.KeyBindings[[ConsoleKey]::Y] = {
            param($key)
            if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                $this.Redo()
            } else {
                $this.InsertChar('y')
            }
        }
        
        # Exit
        $this.BindKey([ConsoleKey]::Escape, { 
            if ($this.Modified) {
                $this.StatusMessage = "Unsaved changes! Press ESC again to quit"
            } else {
                $this.Active = $false
            }
        })
    }
    
    [void] HandleInput([ConsoleKeyInfo]$key) {
        # Clear status message on any input
        if ($this.StatusMessage -and -not $this.StatusMessage.StartsWith("Unsaved")) {
            $this.StatusMessage = ""
        }
        
        # Check for bound keys first
        if ($this.KeyBindings.ContainsKey($key.Key)) {
            & $this.KeyBindings[$key.Key] $key
            return
        }
        
        # Insert characters
        if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
            $this.InsertChar($key.KeyChar)
        }
    }
    
    [void] InsertChar([char]$char) {
        # Record for undo
        $this.RecordUndo(@{
            Type = "Insert"
            Position = $this.CursorPosition
            Char = $char
        })
        
        $this.Buffer.Insert($this.CursorPosition, $char)
        $this.CursorPosition++
        $this.Modified = $true
        $this.LinesCacheDirty = $true
        $this.UpdateStatusBar()
        $this.RequestRender()
    }
    
    [void] Backspace() {
        if ($this.CursorPosition -gt 0) {
            $deletedChar = $this.Buffer.GetChar($this.CursorPosition - 1)
            
            $this.RecordUndo(@{
                Type = "Delete"
                Position = $this.CursorPosition - 1
                Char = $deletedChar
            })
            
            $this.CursorPosition--
            $this.Buffer.Delete($this.CursorPosition)
            $this.Modified = $true
            $this.LinesCacheDirty = $true
            $this.UpdateStatusBar()
            $this.RequestRender()
        }
    }
    
    [void] Delete() {
        if ($this.CursorPosition -lt $this.Buffer.Length) {
            $deletedChar = $this.Buffer.GetChar($this.CursorPosition)
            
            $this.RecordUndo(@{
                Type = "Delete"
                Position = $this.CursorPosition
                Char = $deletedChar
            })
            
            $this.Buffer.Delete($this.CursorPosition)
            $this.Modified = $true
            $this.LinesCacheDirty = $true
            $this.UpdateStatusBar()
            $this.RequestRender()
        }
    }
    
    [void] InsertNewline() {
        $this.InsertChar("`n")
    }
    
    [void] InsertTab() {
        for ($i = 0; $i -lt $this.TabWidth; $i++) {
            $this.InsertChar(' ')
        }
    }
    
    # Smart cursor movement from AxiomPhoenix
    [void] MoveCursorLeft() {
        if ($this.CursorPosition -gt 0) {
            $this.CursorPosition--
            
            # If we moved to a newline, go to end of previous line
            if ($this.CursorPosition -gt 0 -and $this.Buffer.GetChar($this.CursorPosition) -eq "`n") {
                $this.CursorPosition--
            }
        }
        $this.RequestRender()
    }
    
    [void] MoveCursorRight() {
        if ($this.CursorPosition -lt $this.Buffer.Length) {
            $this.CursorPosition++
            
            # If we moved past a newline, go to start of next line
            if ($this.CursorPosition -lt $this.Buffer.Length -and 
                $this.Buffer.GetChar($this.CursorPosition - 1) -eq "`n") {
                # Already at correct position
            }
        }
        $this.RequestRender()
    }
    
    [void] MoveCursorHome() {
        $line = $this.GetCurrentLine()
        $this.CursorPosition = $this.LineStarts[$line]
        $this.RequestRender()
    }
    
    [void] MoveCursorEnd() {
        $line = $this.GetCurrentLine()
        $nextLine = $line + 1
        
        if ($nextLine -lt $this.LineStarts.Count) {
            $this.CursorPosition = $this.LineStarts[$nextLine] - 1
        } else {
            $this.CursorPosition = $this.Buffer.Length
        }
        $this.RequestRender()
    }
    
    [void] MoveCursor([int]$dx, [int]$dy) {
        if ($dy -ne 0) {
            $currentLine = $this.GetCurrentLine()
            $currentColumn = $this.GetCurrentColumn()
            $targetLine = [Math]::Max(0, [Math]::Min($this.LineStarts.Count - 1, $currentLine + $dy))
            
            if ($targetLine -ne $currentLine) {
                # Move to target line, maintaining column if possible
                $targetLineStart = $this.LineStarts[$targetLine]
                $targetLineEnd = if ($targetLine + 1 -lt $this.LineStarts.Count) {
                    $this.LineStarts[$targetLine + 1] - 1
                } else {
                    $this.Buffer.Length
                }
                
                $targetLineLength = $targetLineEnd - $targetLineStart
                $this.CursorPosition = $targetLineStart + [Math]::Min($currentColumn, $targetLineLength)
            }
        }
        $this.RequestRender()
    }
    
    # Undo/Redo system
    [void] RecordUndo([hashtable]$action) {
        $this.UndoStack.Push($action)
        $this.RedoStack.Clear()
    }
    
    [void] Undo() {
        if ($this.UndoStack.Count -eq 0) {
            $this.StatusMessage = "Nothing to undo"
            return
        }
        
        $action = $this.UndoStack.Pop()
        
        switch ($action.Type) {
            "Insert" {
                $this.Buffer.Delete($action.Position)
                $this.CursorPosition = $action.Position
            }
            "Delete" {
                $this.Buffer.Insert($action.Position, $action.Char)
                $this.CursorPosition = $action.Position + 1
            }
        }
        
        $this.RedoStack.Push($action)
        $this.Modified = $true
        $this.LinesCacheDirty = $true
        $this.StatusMessage = "Undone"
        $this.UpdateStatusBar()
        $this.RequestRender()
    }
    
    [void] Redo() {
        if ($this.RedoStack.Count -eq 0) {
            $this.StatusMessage = "Nothing to redo"
            return
        }
        
        $action = $this.RedoStack.Pop()
        
        switch ($action.Type) {
            "Insert" {
                $this.Buffer.Insert($action.Position, $action.Char)
                $this.CursorPosition = $action.Position + 1
            }
            "Delete" {
                $this.Buffer.Delete($action.Position)
                $this.CursorPosition = $action.Position
            }
        }
        
        $this.UndoStack.Push($action)
        $this.Modified = $true
        $this.LinesCacheDirty = $true
        $this.StatusMessage = "Redone"
        $this.UpdateStatusBar()
        $this.RequestRender()
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        
        # File info
        $fileName = if ($this.FilePath) { [System.IO.Path]::GetFileName($this.FilePath) } else { "New File" }
        $modifiedIndicator = if ($this.Modified) { "*" } else { "" }
        $this.StatusBarItems.Add(@{
            Label = "$fileName$modifiedIndicator"
        }) | Out-Null
        
        # Position info
        $line = $this.GetCurrentLine() + 1
        $col = $this.GetCurrentColumn() + 1
        $this.StatusBarItems.Add(@{
            Label = "Ln $line, Col $col"
        }) | Out-Null
        
        # Buffer info
        $this.StatusBarItems.Add(@{
            Label = "$($this.Buffer.Length) chars"
        }) | Out-Null
        
        # Mode
        $mode = if ($this.InsertMode) { "INSERT" } else { "OVERWRITE" }
        $this.StatusBarItems.Add(@{
            Label = $mode
        }) | Out-Null
        
        # Commands
        $this.AddStatusItem('Ctrl+S', 'save')
        $this.AddStatusItem('Ctrl+Z', 'undo')
        $this.AddStatusItem('Ctrl+Y', 'redo')
        $this.AddStatusItem('ESC', 'exit')
        
        # Status message
        if ($this.StatusMessage) {
            $this.StatusBarItems.Add(@{
                Label = $this.StatusMessage
                Align = "Right"
            }) | Out-Null
        }
    }
    
    [void] EnsureCursorVisible([int]$viewHeight, [int]$viewWidth) {
        $currentLine = $this.GetCurrentLine()
        $currentColumn = $this.GetCurrentColumn()
        
        # Smart scroll from AxiomPhoenix - minimal scrolling to keep cursor visible
        # Vertical scrolling
        if ($currentLine -lt $this.ScrollOffsetY) {
            $this.ScrollOffsetY = $currentLine
        }
        elseif ($currentLine -ge $this.ScrollOffsetY + $viewHeight) {
            $this.ScrollOffsetY = $currentLine - $viewHeight + 1
        }
        
        # Horizontal scrolling
        $effectiveWidth = $viewWidth - $this.LineNumberWidth
        if ($currentColumn -lt $this.ScrollOffsetX) {
            $this.ScrollOffsetX = $currentColumn
        }
        elseif ($currentColumn -ge $this.ScrollOffsetX + $effectiveWidth) {
            $this.ScrollOffsetX = $currentColumn - $effectiveWidth + 1
        }
    }
    
    # Buffer-based render - zero string allocation for maximum text editing performance
    [void] RenderToBuffer([Buffer]$buffer) {
        # Clear background
        $normalBG = "#1E1E23"
        $normalFG = "#D4D4D4"
        for ($y = 0; $y -lt $buffer.Height; $y++) {
            for ($x = 0; $x -lt $buffer.Width; $x++) {
                $buffer.SetCell($x, $y, ' ', $normalFG, $normalBG)
            }
        }
        
        # Title bar
        $titleText = " $($this.Title) "
        $titleX = [int](($buffer.Width - $titleText.Length) / 2)
        for ($i = 0; $i -lt $titleText.Length; $i++) {
            $buffer.SetCell($titleX + $i, 0, $titleText[$i], "#64C8FF", $normalBG)
        }
        
        # Calculate visible area
        $editorY = 1
        $editorHeight = $buffer.Height - 3
        $editorWidth = $buffer.Width
        
        # Update line cache if needed
        $this.UpdateLineStarts()
        
        # Ensure cursor is visible
        $this.EnsureCursorVisible($editorHeight, $editorWidth)
        
        # Render visible lines
        $startLine = $this.ScrollOffsetY
        $endLine = [Math]::Min($startLine + $editorHeight, $this.LineStarts.Count)
        
        for ($lineNum = $startLine; $lineNum -lt $endLine; $lineNum++) {
            $screenY = $editorY + ($lineNum - $startLine)
            
            # Line number
            $contentX = 0
            if ($this.ShowLineNumbers) {
                $lineNumStr = ($lineNum + 1).ToString().PadLeft($this.LineNumberWidth - 1)
                $lineNumText = $lineNumStr + " "
                for ($i = 0; $i -lt $lineNumText.Length; $i++) {
                    $buffer.SetCell($i, $screenY, $lineNumText[$i], "#6496C8", $normalBG)
                }
                $contentX = $this.LineNumberWidth
            }
            
            # Line content - direct character rendering for speed
            $lineStart = $this.LineStarts[$lineNum]
            $lineEnd = if ($lineNum + 1 -lt $this.LineStarts.Count) {
                $this.LineStarts[$lineNum + 1] - 1
            } else {
                $this.Buffer.Length
            }
            
            # Extract visible portion of line
            $screenX = $contentX
            for ($charIndex = $lineStart + $this.ScrollOffsetX; $charIndex -lt $lineEnd -and $screenX -lt $buffer.Width; $charIndex++) {
                $char = $this.Buffer.GetChar($charIndex)
                if ($char -ne "`n") {
                    # Syntax highlighting colors
                    $color = $this.Colors.Foreground
                    if ($char -eq '"' -or $char -eq "'") {
                        $color = $this.Colors.String
                    } elseif ($char -eq '#') {
                        $color = $this.Colors.Comment
                    }
                    
                    $buffer.SetCell($screenX, $screenY, $char, $color, $normalBG)
                    $screenX++
                }
            }
        }
        
        # Cursor - use special cursor cell if visible
        $cursorLine = $this.GetCurrentLine()
        $cursorColumn = $this.GetCurrentColumn()
        $cursorScreenX = if ($this.ShowLineNumbers) { $this.LineNumberWidth } else { 0 }
        $cursorScreenX += $cursorColumn - $this.ScrollOffsetX
        $cursorScreenY = $editorY + $cursorLine - $this.ScrollOffsetY
        
        if ($cursorScreenX -ge 0 -and $cursorScreenX -lt $buffer.Width -and 
            $cursorScreenY -ge $editorY -and $cursorScreenY -lt $editorY + $editorHeight) {
            # Highlight cursor position
            $cursorChar = if ($this.CursorPosition -lt $this.Buffer.Length) {
                $this.Buffer.GetChar($this.CursorPosition)
            } else {
                ' '
            }
            $buffer.SetCell($cursorScreenX, $cursorScreenY, $cursorChar, "#000000", "#FFFFFF")
        }
    }
    
    [void] PageUp() {
        $pageSize = [Console]::WindowHeight - 6
        $currentLine = $this.GetCurrentLine()
        $targetLine = [Math]::Max(0, $currentLine - $pageSize)
        $this.CursorPosition = $this.LineStarts[$targetLine]
        $this.ScrollOffsetY = [Math]::Max(0, $this.ScrollOffsetY - $pageSize)
        $this.RequestRender()
    }
    
    [void] PageDown() {
        $pageSize = [Console]::WindowHeight - 6
        $currentLine = $this.GetCurrentLine()
        $targetLine = [Math]::Min($this.LineStarts.Count - 1, $currentLine + $pageSize)
        $this.CursorPosition = $this.LineStarts[$targetLine]
        $this.RequestRender()
    }
}