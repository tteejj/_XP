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
    
    [string] RenderContent() {
        $output = ""
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Clear background
        for ($y = 1; $y -le $height; $y++) {
            $output += [VT]::MoveTo(1, $y)
            $output += " " * $width
        }
        
        # Title bar
        $titleText = " $($this.Title) "
        $x = [int](($width - $titleText.Length) / 2)
        $output += [VT]::MoveTo($x, 1)
        $output += [VT]::RGB(100, 200, 255) + $titleText + [VT]::Reset()
        
        # Calculate visible area
        $editorY = 2
        $editorHeight = $height - 4  # Leave room for title and status bar
        $editorWidth = $width
        
        # Ensure cursor is visible
        $this.EnsureCursorVisible($editorHeight, $editorWidth)
        
        # Render lines
        $startLine = $this.ScrollOffsetY
        $endLine = [Math]::Min($startLine + $editorHeight, $this.Lines.Count)
        
        for ($i = $startLine; $i -lt $endLine; $i++) {
            $y = $editorY + ($i - $startLine)
            $output += [VT]::MoveTo(1, $y)
            
            # Line number
            if ($this.ShowLineNumbers) {
                $lineNum = ($i + 1).ToString().PadLeft($this.LineNumberWidth - 1)
                $output += [VT]::RGB(100, 100, 150) + $lineNum + " " + [VT]::Reset()
            }
            
            # Line content
            $line = $this.Lines[$i]
            $visibleLine = $this.GetVisibleLine($line, $this.ScrollOffsetX, $editorWidth - $this.LineNumberWidth)
            
            # Syntax highlighting (simple)
            if ($this.FilePath -like "*.ps1") {
                $visibleLine = $this.HighlightPowerShell($visibleLine)
            }
            
            $output += $visibleLine
        }
        
        # Show cursor
        $cursorScreenX = 1 + $this.LineNumberWidth + $this.CursorX - $this.ScrollOffsetX
        $cursorScreenY = $editorY + $this.CursorY - $this.ScrollOffsetY
        
        if ($cursorScreenX -ge 1 -and $cursorScreenX -le $width -and 
            $cursorScreenY -ge $editorY -and $cursorScreenY -lt $editorY + $editorHeight) {
            $output += [VT]::MoveTo($cursorScreenX, $cursorScreenY)
            $output += [VT]::ShowCursor()
        }
        
        return $output
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