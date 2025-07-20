# Simple Text Editor - Notepad-like functionality
# Fast, responsive, multiline text editing

class SimpleTextEditor : Screen {
    # Text storage
    [System.Collections.ArrayList]$Lines
    
    # Cursor position
    [int]$CursorX = 0
    [int]$CursorY = 0
    
    # Viewport
    [int]$ScrollY = 0
    [int]$ScrollX = 0
    
    # File info
    [string]$FileName = ""
    [bool]$Modified = $false
    
    # Display area
    [int]$ViewportWidth
    [int]$ViewportHeight
    [int]$StatusBarY
    
    SimpleTextEditor() {
        $this.Initialize()
    }
    
    SimpleTextEditor([string]$filePath) {
        $this.FileName = $filePath
        $this.Initialize()
        $this.LoadFile($filePath)
    }
    
    [void] Initialize() {
        $this.Title = "TEXT EDITOR"
        $this.Lines = [System.Collections.ArrayList]::new()
        
        # Calculate viewport
        $this.ViewportWidth = [Console]::WindowWidth - 2
        $this.ViewportHeight = [Console]::WindowHeight - 4  # Leave space for title and status
        $this.StatusBarY = [Console]::WindowHeight - 1
        
        # Start with one empty line if no file
        if ($this.Lines.Count -eq 0) {
            $this.Lines.Add("") | Out-Null
        }
        
        $this.InitializeKeyBindings()
        $this.UpdateStatusBar()
    }
    
    [void] InitializeKeyBindings() {
        # Arrow key navigation
        $this.BindKey([ConsoleKey]::UpArrow, { $this.MoveCursor([ConsoleKey]::UpArrow); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.MoveCursor([ConsoleKey]::DownArrow); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.MoveCursor([ConsoleKey]::LeftArrow); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.MoveCursor([ConsoleKey]::RightArrow); $this.RequestRender() })
        
        # Text editing
        $this.BindKey([ConsoleKey]::Backspace, { $this.HandleBackspace(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::Delete, { $this.HandleDelete(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::Enter, { $this.HandleEnter(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::Tab, { $this.InsertText("    "); $this.RequestRender() })
        
        # Navigation shortcuts
        $this.BindKey([ConsoleKey]::Home, { $this.MoveCursor([ConsoleKey]::Home); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::End, { $this.MoveCursor([ConsoleKey]::End); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::PageUp, { $this.MoveCursor([ConsoleKey]::PageUp); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::PageDown, { $this.MoveCursor([ConsoleKey]::PageDown); $this.RequestRender() })
        
        # File operations
        $this.BindKey([ConsoleKey]::S, { 
            if ($this.FileName) { 
                $this.SaveFile(); $this.RequestRender() 
            } 
        })
        
        # Exit
        $this.BindKey([ConsoleKey]::Escape, { $this.Active = $false })
        $this.BindKey('q', { $this.Active = $false })
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        
        # File status
        $fileStatus = if ($this.FileName) { 
            [System.IO.Path]::GetFileName($this.FileName) 
        } else { 
            "Untitled" 
        }
        if ($this.Modified) { 
            $fileStatus += "*" 
        }
        
        # Position info
        $pos = "Ln $($this.CursorY + 1), Col $($this.CursorX + 1)"
        
        $this.StatusBarItems.Add(@{Label = $fileStatus}) | Out-Null
        $this.StatusBarItems.Add(@{Label = $pos; Align = "Right"}) | Out-Null
        $this.AddStatusItem('Ctrl+S', 'save')
        $this.AddStatusItem('Esc', 'exit')
    }
    
    # Fast string rendering for maximum performance
    [string] RenderContent() {
        $output = ""
        
        # Clear screen efficiently
        $output += [VT]::Clear()
        
        # Title bar
        $title = " TEXT EDITOR "
        if ($this.FileName) {
            $title += "- " + [System.IO.Path]::GetFileName($this.FileName)
        }
        if ($this.Modified) {
            $title += " [Modified]"
        }
        
        $titleX = [int](([Console]::WindowWidth - $title.Length) / 2)
        $output += [VT]::MoveTo($titleX, 1)
        $output += [VT]::RGB(100, 200, 255) + $title + [VT]::Reset()
        
        # Text content area
        $output += $this.RenderTextArea()
        
        # Cursor
        $output += $this.RenderCursor()
        
        return $output
    }
    
    [string] RenderTextArea() {
        $output = ""
        $startY = 3
        
        # Calculate visible line range
        $visibleLines = $this.ViewportHeight
        $endLine = [Math]::Min($this.ScrollY + $visibleLines, $this.Lines.Count)
        
        for ($i = $this.ScrollY; $i -lt $endLine; $i++) {
            $line = $this.Lines[$i]
            $displayY = $startY + ($i - $this.ScrollY)
            
            # Handle horizontal scrolling
            $visibleText = ""
            if ($line.Length -gt $this.ScrollX) {
                $endX = [Math]::Min($this.ScrollX + $this.ViewportWidth, $line.Length)
                $visibleText = $line.Substring($this.ScrollX, $endX - $this.ScrollX)
            }
            
            $output += [VT]::MoveTo(2, $displayY)
            $output += [VT]::Text() + $visibleText + [VT]::Reset()
        }
        
        return $output
    }
    
    [string] RenderCursor() {
        # Calculate cursor screen position
        $screenX = 2 + ($this.CursorX - $this.ScrollX)
        $screenY = 3 + ($this.CursorY - $this.ScrollY)
        
        # Only show cursor if it's in viewport
        if ($screenX -ge 2 -and $screenX -le $this.ViewportWidth + 1 -and
            $screenY -ge 3 -and $screenY -le 3 + $this.ViewportHeight - 1) {
            
            # Get character at cursor position or space
            $cursorChar = " "
            if ($this.CursorY -lt $this.Lines.Count) {
                $line = $this.Lines[$this.CursorY]
                if ($this.CursorX -lt $line.Length) {
                    $cursorChar = $line[$this.CursorX]
                }
            }
            
            $output = [VT]::MoveTo($screenX, $screenY)
            $output += [VT]::RGBBG(255, 255, 255) + [VT]::RGB(0, 0, 0) + $cursorChar + [VT]::Reset()
            return $output
        }
        
        return ""
    }
    
    # Text editing methods
    [void] InsertText([string]$text) {
        if ($this.CursorY -ge $this.Lines.Count) {
            # Add empty lines if needed
            while ($this.Lines.Count -le $this.CursorY) {
                $this.Lines.Add("") | Out-Null
            }
        }
        
        $line = $this.Lines[$this.CursorY]
        
        # Extend line if cursor is beyond end
        if ($this.CursorX -gt $line.Length) {
            $line = $line.PadRight($this.CursorX)
        }
        
        # Insert text at cursor position
        $newLine = $line.Substring(0, $this.CursorX) + $text + $line.Substring($this.CursorX)
        $this.Lines[$this.CursorY] = $newLine
        
        # Move cursor
        $this.CursorX += $text.Length
        $this.Modified = $true
        $this.UpdateStatusBar()
        $this.EnsureCursorVisible()
    }
    
    [void] HandleBackspace() {
        if ($this.CursorX -gt 0) {
            # Delete character before cursor on same line
            $line = $this.Lines[$this.CursorY]
            if ($this.CursorX -le $line.Length) {
                $newLine = $line.Substring(0, $this.CursorX - 1) + $line.Substring($this.CursorX)
                $this.Lines[$this.CursorY] = $newLine
                $this.CursorX--
                $this.Modified = $true
            }
        } elseif ($this.CursorY -gt 0) {
            # Join with previous line
            $currentLine = $this.Lines[$this.CursorY]
            $previousLine = $this.Lines[$this.CursorY - 1]
            $this.CursorX = $previousLine.Length
            $this.Lines[$this.CursorY - 1] = $previousLine + $currentLine
            $this.Lines.RemoveAt($this.CursorY)
            $this.CursorY--
            $this.Modified = $true
        }
        
        $this.UpdateStatusBar()
        $this.EnsureCursorVisible()
    }
    
    [void] HandleDelete() {
        if ($this.CursorY -lt $this.Lines.Count) {
            $line = $this.Lines[$this.CursorY]
            
            if ($this.CursorX -lt $line.Length) {
                # Delete character at cursor
                $newLine = $line.Substring(0, $this.CursorX) + $line.Substring($this.CursorX + 1)
                $this.Lines[$this.CursorY] = $newLine
                $this.Modified = $true
            } elseif ($this.CursorY -lt $this.Lines.Count - 1) {
                # Join with next line
                $nextLine = $this.Lines[$this.CursorY + 1]
                $this.Lines[$this.CursorY] = $line + $nextLine
                $this.Lines.RemoveAt($this.CursorY + 1)
                $this.Modified = $true
            }
        }
        
        $this.UpdateStatusBar()
    }
    
    [void] HandleEnter() {
        if ($this.CursorY -ge $this.Lines.Count) {
            # Add empty lines if needed
            while ($this.Lines.Count -le $this.CursorY) {
                $this.Lines.Add("") | Out-Null
            }
        }
        
        $line = $this.Lines[$this.CursorY]
        
        # Split line at cursor
        $beforeCursor = ""
        $afterCursor = ""
        
        if ($this.CursorX -le $line.Length) {
            $beforeCursor = $line.Substring(0, $this.CursorX)
            $afterCursor = $line.Substring($this.CursorX)
        } else {
            $beforeCursor = $line
        }
        
        # Update current line and insert new line
        $this.Lines[$this.CursorY] = $beforeCursor
        $this.Lines.Insert($this.CursorY + 1, $afterCursor)
        
        # Move cursor to start of next line
        $this.CursorY++
        $this.CursorX = 0
        $this.Modified = $true
        $this.UpdateStatusBar()
        $this.EnsureCursorVisible()
    }
    
    # Cursor movement methods
    [void] MoveCursor([ConsoleKey]$key) {
        switch ($key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.CursorY -gt 0) {
                    $this.CursorY--
                    $this.ClampCursorX()
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.CursorY -lt $this.Lines.Count - 1) {
                    $this.CursorY++
                    $this.ClampCursorX()
                }
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this.CursorX -gt 0) {
                    $this.CursorX--
                } elseif ($this.CursorY -gt 0) {
                    $this.CursorY--
                    $this.CursorX = $this.Lines[$this.CursorY].Length
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($this.CursorY -lt $this.Lines.Count) {
                    $line = $this.Lines[$this.CursorY]
                    if ($this.CursorX -lt $line.Length) {
                        $this.CursorX++
                    } elseif ($this.CursorY -lt $this.Lines.Count - 1) {
                        $this.CursorY++
                        $this.CursorX = 0
                    }
                }
            }
            ([ConsoleKey]::Home) {
                $this.CursorX = 0
            }
            ([ConsoleKey]::End) {
                if ($this.CursorY -lt $this.Lines.Count) {
                    $this.CursorX = $this.Lines[$this.CursorY].Length
                }
            }
            ([ConsoleKey]::PageUp) {
                $this.CursorY = [Math]::Max(0, $this.CursorY - $this.ViewportHeight)
                $this.ClampCursorX()
            }
            ([ConsoleKey]::PageDown) {
                $this.CursorY = [Math]::Min($this.Lines.Count - 1, $this.CursorY + $this.ViewportHeight)
                $this.ClampCursorX()
            }
        }
        
        $this.UpdateStatusBar()
        $this.EnsureCursorVisible()
    }
    
    [void] ClampCursorX() {
        if ($this.CursorY -lt $this.Lines.Count) {
            $lineLength = $this.Lines[$this.CursorY].Length
            $this.CursorX = [Math]::Min($this.CursorX, $lineLength)
        }
    }
    
    [void] EnsureCursorVisible() {
        # Vertical scrolling
        if ($this.CursorY -lt $this.ScrollY) {
            $this.ScrollY = $this.CursorY
        } elseif ($this.CursorY -ge $this.ScrollY + $this.ViewportHeight) {
            $this.ScrollY = $this.CursorY - $this.ViewportHeight + 1
        }
        
        # Horizontal scrolling
        if ($this.CursorX -lt $this.ScrollX) {
            $this.ScrollX = $this.CursorX
        } elseif ($this.CursorX -ge $this.ScrollX + $this.ViewportWidth) {
            $this.ScrollX = $this.CursorX - $this.ViewportWidth + 1
        }
    }
    
    # File operations
    [void] LoadFile([string]$filePath) {
        try {
            if (Test-Path $filePath) {
                $content = Get-Content -Path $filePath -Raw
                if ($content) {
                    $this.Lines = [System.Collections.ArrayList]($content -split "`r?`n")
                } else {
                    $this.Lines = [System.Collections.ArrayList]@("")
                }
            } else {
                $this.Lines = [System.Collections.ArrayList]@("")
            }
            
            $this.CursorX = 0
            $this.CursorY = 0
            $this.ScrollX = 0
            $this.ScrollY = 0
            $this.Modified = $false
            $this.UpdateStatusBar()
        }
        catch {
            Write-Error "Failed to load file: $_"
            $this.Lines = [System.Collections.ArrayList]@("")
        }
    }
    
    [void] SaveFile() {
        if (-not $this.FileName) {
            # TODO: Implement save dialog
            Write-Host "Save dialog not implemented yet"
            return
        }
        
        try {
            $content = $this.Lines -join "`n"
            Set-Content -Path $this.FileName -Value $content -NoNewline
            $this.Modified = $false
            $this.UpdateStatusBar()
            Write-Host "File saved: $($this.FileName)" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to save file: $_"
        }
    }
    
    # Handle regular character input
    [void] HandleInput([ConsoleKeyInfo]$key) {
        # Handle printable characters
        if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
            $this.InsertText([string]$key.KeyChar)
            $this.RequestRender()
            return
        }
        
        # Handle control keys with Ctrl modifier
        if ($key.Modifiers -eq [ConsoleModifiers]::Control) {
            switch ($key.Key) {
                ([ConsoleKey]::S) { 
                    if ($this.FileName) { 
                        $this.SaveFile(); $this.RequestRender() 
                    } 
                }
            }
            return
        }
        
        # Pass to base class for other keys
        ([Screen]$this).HandleInput($key)
    }
}