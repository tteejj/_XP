# TextEditorScreen - Simple but functional text editor

class TextEditorScreen : Screen {
    [string]$FilePath
    [System.Collections.ArrayList]$Lines
    [int]$CursorX = 0
    [int]$CursorY = 0
    [int]$ScrollOffsetY = 0
    [int]$ScrollOffsetX = 0
    [bool]$Modified = $false
    [bool]$InsertMode = $true
    [string]$StatusMessage = ""
    
    # Editor settings
    [int]$TabWidth = 4
    [bool]$ShowLineNumbers = $true
    [int]$LineNumberWidth = 5
    
    TextEditorScreen([string]$filePath) {
        $this.FilePath = $filePath
        $this.Title = "Text Editor"
        $this.Lines = [System.Collections.ArrayList]::new()
        $this.Initialize()
    }
    
    TextEditorScreen() {
        $this.FilePath = ""
        $this.Title = "Text Editor - New File"
        $this.Lines = [System.Collections.ArrayList]::new()
        $this.Lines.Add("") | Out-Null
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Load file if specified
        if ($this.FilePath -and (Test-Path $this.FilePath)) {
            $this.LoadFile()
        } elseif (-not $this.Lines.Count) {
            $this.Lines.Add("") | Out-Null
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
                $this.Lines.Clear()
                $lineArray = $content -split "`r?`n"
                foreach ($line in $lineArray) {
                    $this.Lines.Add($line) | Out-Null
                }
            } else {
                $this.Lines.Add("") | Out-Null
            }
            $this.Title = "Text Editor - $([System.IO.Path]::GetFileName($this.FilePath))"
            $this.Modified = $false
        }
        catch {
            $this.StatusMessage = "Error loading file: $_"
            $this.Lines.Add("") | Out-Null
        }
    }
    
    [void] SaveFile() {
        if (-not $this.FilePath) {
            $this.StatusMessage = "No file name - use Ctrl+S to save as"
            return
        }
        
        try {
            $content = $this.Lines -join "`n"
            Set-Content -Path $this.FilePath -Value $content -NoNewline
            $this.Modified = $false
            $this.StatusMessage = "File saved"
            $this.UpdateStatusBar()
        }
        catch {
            $this.StatusMessage = "Error saving file: $_"
        }
    }
    
    [void] InitializeKeyBindings() {
        # Navigation
        $this.BindKey([ConsoleKey]::UpArrow, { $this.MoveCursor(0, -1) })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.MoveCursor(0, 1) })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.MoveCursor(-1, 0) })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.MoveCursor(1, 0) })
        $this.BindKey([ConsoleKey]::Home, { $this.CursorX = 0; $this.RequestRender() })
        $this.BindKey([ConsoleKey]::End, { $this.CursorX = $this.Lines[$this.CursorY].Length; $this.RequestRender() })
        $this.BindKey([ConsoleKey]::PageUp, { $this.PageUp() })
        $this.BindKey([ConsoleKey]::PageDown, { $this.PageDown() })
        
        # Editing
        $this.BindKey([ConsoleKey]::Enter, { $this.InsertNewline() })
        $this.BindKey([ConsoleKey]::Backspace, { $this.Backspace() })
        $this.BindKey([ConsoleKey]::Delete, { $this.Delete() })
        $this.BindKey([ConsoleKey]::Tab, { $this.InsertTab() })
        
        # File operations - using Ctrl key combinations
        $this.KeyBindings[[ConsoleKey]::S] = { 
            param($key)
            if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                $this.SaveFile()
            } else {
                $this.InsertChar('s')
            }
        }
        
        $this.KeyBindings[[ConsoleKey]::Q] = {
            param($key)
            if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                if ($this.Modified) {
                    $this.StatusMessage = "Unsaved changes! Press Ctrl+Q again to quit"
                    if ($this.StatusMessage -eq "Unsaved changes! Press Ctrl+Q again to quit") {
                        $this.Active = $false
                    }
                } else {
                    $this.Active = $false
                }
            } else {
                $this.InsertChar('q')
            }
        }
        
        # Exit without Ctrl
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
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        
        # File info
        $fileName = if ($this.FilePath) { [System.IO.Path]::GetFileName($this.FilePath) } else { "New File" }
        $modifiedIndicator = if ($this.Modified) { "*" } else { "" }
        $this.StatusBarItems.Add(@{
            Label = "$fileName$modifiedIndicator"
        }) | Out-Null
        
        # Position info
        $this.StatusBarItems.Add(@{
            Label = "Line $($this.CursorY + 1)/$($this.Lines.Count), Col $($this.CursorX + 1)"
        }) | Out-Null
        
        # Mode
        $mode = if ($this.InsertMode) { "INSERT" } else { "OVERWRITE" }
        $this.StatusBarItems.Add(@{
            Label = $mode
        }) | Out-Null
        
        # Commands
        $this.AddStatusItem('Ctrl+S', 'save')
        $this.AddStatusItem('Ctrl+Q', 'quit')
        $this.AddStatusItem('ESC', 'exit')
        
        # Status message
        if ($this.StatusMessage) {
            $this.StatusBarItems.Add(@{
                Label = $this.StatusMessage
                Align = "Right"
            }) | Out-Null
        }
    }
    
    # Buffer-based render - zero string allocation for fast text editing
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
        
        # Ensure cursor is visible
        $this.EnsureCursorVisible($editorHeight, $editorWidth)
        
        # Render lines
        $startLine = $this.ScrollOffsetY
        $endLine = [Math]::Min($startLine + $editorHeight, $this.Lines.Count)
        
        for ($i = $startLine; $i -lt $endLine; $i++) {
            $screenY = $editorY + ($i - $startLine)
            
            # Line number
            $contentX = 0
            if ($this.ShowLineNumbers) {
                $lineNum = ($i + 1).ToString().PadLeft($this.LineNumberWidth - 1)
                $lineNumText = $lineNum + " "
                for ($j = 0; $j -lt $lineNumText.Length; $j++) {
                    $buffer.SetCell($j, $screenY, $lineNumText[$j], "#6496C8", $normalBG)
                }
                $contentX = $this.LineNumberWidth
            }
            
            # Line content - direct character rendering
            $line = $this.Lines[$i]
            $startX = [Math]::Max(0, $this.ScrollOffsetX)
            $maxChars = $buffer.Width - $contentX
            
            for ($charIdx = 0; $charIdx -lt $maxChars -and ($startX + $charIdx) -lt $line.Length; $charIdx++) {
                $char = $line[$startX + $charIdx]
                $screenX = $contentX + $charIdx
                
                # Simple syntax highlighting for PowerShell
                $color = $normalFG
                if ($this.FilePath -like "*.ps1") {
                    if ($char -eq '$') {
                        $color = "#569CD6"  # Variable
                    } elseif ($char -eq '"' -or $char -eq "'") {
                        $color = "#CE9178"  # String
                    } elseif ($char -eq '#') {
                        $color = "#6A9955"  # Comment
                    }
                }
                
                $buffer.SetCell($screenX, $screenY, $char, $color, $normalBG)
            }
        }
        
        # Cursor
        $cursorScreenX = if ($this.ShowLineNumbers) { $this.LineNumberWidth } else { 0 }
        $cursorScreenX += $this.CursorX - $this.ScrollOffsetX
        $cursorScreenY = $editorY + $this.CursorY - $this.ScrollOffsetY
        
        if ($cursorScreenX -ge 0 -and $cursorScreenX -lt $buffer.Width -and 
            $cursorScreenY -ge $editorY -and $cursorScreenY -lt $editorY + $editorHeight) {
            # Get current character or space
            $cursorChar = ' '
            if ($this.CursorY -lt $this.Lines.Count -and $this.CursorX -lt $this.Lines[$this.CursorY].Length) {
                $cursorChar = $this.Lines[$this.CursorY][$this.CursorX]
            }
            $buffer.SetCell($cursorScreenX, $cursorScreenY, $cursorChar, "#000000", "#FFFFFF")
        }
    }
    
    [string] GetVisibleLine([string]$line, [int]$scrollX, [int]$maxWidth) {
        if ($scrollX -ge $line.Length) {
            return ""
        }
        
        $visibleLine = $line.Substring($scrollX)
        if ($visibleLine.Length -gt $maxWidth) {
            $visibleLine = $visibleLine.Substring(0, $maxWidth)
        }
        
        return $visibleLine
    }
    
    [string] HighlightPowerShell([string]$line) {
        # Simple PowerShell syntax highlighting
        $highlighted = $line
        
        # Comments
        if ($highlighted -match '^(\s*)(#.*)$') {
            return $Matches[1] + [VT]::RGB(100, 150, 100) + $Matches[2] + [VT]::Reset()
        }
        
        # Keywords (simple approach)
        $keywords = @('if', 'else', 'elseif', 'foreach', 'for', 'while', 'do', 'switch', 
                      'function', 'class', 'return', 'break', 'continue', 'try', 'catch', 'finally')
        
        foreach ($keyword in $keywords) {
            $pattern = "\b$keyword\b"
            if ($highlighted -match $pattern) {
                $highlighted = $highlighted -replace $pattern, ([VT]::RGB(150, 150, 255) + $keyword + [VT]::Reset())
            }
        }
        
        # Variables (simple)
        $highlighted = $highlighted -replace '(\$\w+)', ([VT]::RGB(255, 200, 100) + '$1' + [VT]::Reset())
        
        # Strings (very simple)
        $highlighted = $highlighted -replace '(".*?")', ([VT]::RGB(200, 150, 100) + '$1' + [VT]::Reset())
        $highlighted = $highlighted -replace "(\'.*?\')", ([VT]::RGB(200, 150, 100) + '$1' + [VT]::Reset())
        
        return $highlighted
    }
    
    [void] EnsureCursorVisible([int]$viewHeight, [int]$viewWidth) {
        # Vertical scrolling
        if ($this.CursorY -lt $this.ScrollOffsetY) {
            $this.ScrollOffsetY = $this.CursorY
        } elseif ($this.CursorY -ge $this.ScrollOffsetY + $viewHeight) {
            $this.ScrollOffsetY = $this.CursorY - $viewHeight + 1
        }
        
        # Horizontal scrolling
        $effectiveWidth = $viewWidth - $this.LineNumberWidth
        if ($this.CursorX -lt $this.ScrollOffsetX) {
            $this.ScrollOffsetX = $this.CursorX
        } elseif ($this.CursorX -ge $this.ScrollOffsetX + $effectiveWidth) {
            $this.ScrollOffsetX = $this.CursorX - $effectiveWidth + 1
        }
    }
    
    # Cursor movement
    [void] MoveCursor([int]$dx, [int]$dy) {
        $this.CursorY = [Math]::Max(0, [Math]::Min($this.Lines.Count - 1, $this.CursorY + $dy))
        
        if ($dx -ne 0) {
            $this.CursorX = [Math]::Max(0, $this.CursorX + $dx)
            $lineLength = $this.Lines[$this.CursorY].Length
            $this.CursorX = [Math]::Min($lineLength, $this.CursorX)
        } else {
            # Vertical movement - try to maintain column
            $lineLength = $this.Lines[$this.CursorY].Length
            $this.CursorX = [Math]::Min($lineLength, $this.CursorX)
        }
        
        $this.RequestRender()
    }
    
    [void] PageUp() {
        $pageSize = [Console]::WindowHeight - 6
        $this.CursorY = [Math]::Max(0, $this.CursorY - $pageSize)
        $this.ScrollOffsetY = [Math]::Max(0, $this.ScrollOffsetY - $pageSize)
        $this.RequestRender()
    }
    
    [void] PageDown() {
        $pageSize = [Console]::WindowHeight - 6
        $this.CursorY = [Math]::Min($this.Lines.Count - 1, $this.CursorY + $pageSize)
        $this.RequestRender()
    }
    
    # Editing operations
    [void] InsertChar([char]$char) {
        $line = $this.Lines[$this.CursorY]
        
        if ($this.InsertMode -or $this.CursorX -ge $line.Length) {
            # Insert mode
            $this.Lines[$this.CursorY] = $line.Insert($this.CursorX, $char)
        } else {
            # Overwrite mode
            $before = if ($this.CursorX -gt 0) { $line.Substring(0, $this.CursorX) } else { "" }
            $after = if ($this.CursorX + 1 -lt $line.Length) { $line.Substring($this.CursorX + 1) } else { "" }
            $this.Lines[$this.CursorY] = $before + $char + $after
        }
        
        $this.CursorX++
        $this.Modified = $true
        $this.UpdateStatusBar()
        $this.RequestRender()
    }
    
    [void] InsertNewline() {
        $line = $this.Lines[$this.CursorY]
        $before = if ($this.CursorX -gt 0) { $line.Substring(0, $this.CursorX) } else { "" }
        $after = if ($this.CursorX -lt $line.Length) { $line.Substring($this.CursorX) } else { "" }
        
        $this.Lines[$this.CursorY] = $before
        $this.Lines.Insert($this.CursorY + 1, $after)
        
        $this.CursorY++
        $this.CursorX = 0
        $this.Modified = $true
        $this.UpdateStatusBar()
        $this.RequestRender()
    }
    
    [void] Backspace() {
        if ($this.CursorX -gt 0) {
            # Delete character before cursor
            $line = $this.Lines[$this.CursorY]
            $this.Lines[$this.CursorY] = $line.Remove($this.CursorX - 1, 1)
            $this.CursorX--
        } elseif ($this.CursorY -gt 0) {
            # Join with previous line
            $prevLine = $this.Lines[$this.CursorY - 1]
            $currentLine = $this.Lines[$this.CursorY]
            $this.CursorX = $prevLine.Length
            $this.Lines[$this.CursorY - 1] = $prevLine + $currentLine
            $this.Lines.RemoveAt($this.CursorY)
            $this.CursorY--
        }
        
        $this.Modified = $true
        $this.UpdateStatusBar()
        $this.RequestRender()
    }
    
    [void] Delete() {
        $line = $this.Lines[$this.CursorY]
        
        if ($this.CursorX -lt $line.Length) {
            # Delete character at cursor
            $this.Lines[$this.CursorY] = $line.Remove($this.CursorX, 1)
        } elseif ($this.CursorY -lt $this.Lines.Count - 1) {
            # Join with next line
            $nextLine = $this.Lines[$this.CursorY + 1]
            $this.Lines[$this.CursorY] = $line + $nextLine
            $this.Lines.RemoveAt($this.CursorY + 1)
        }
        
        $this.Modified = $true
        $this.UpdateStatusBar()
        $this.RequestRender()
    }
    
    [void] InsertTab() {
        # Insert spaces instead of tab
        for ($i = 0; $i -lt $this.TabWidth; $i++) {
            $this.InsertChar(' ')
        }
    }
}