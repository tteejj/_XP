# MultilineTextBox Component - Multi-line text editor

class MultilineTextBox : Component {
    [System.Collections.ArrayList]$Lines
    [int]$CursorLine = 0
    [int]$CursorColumn = 0
    [int]$ScrollOffsetY = 0
    [int]$ScrollOffsetX = 0
    [bool]$ReadOnly = $false
    [bool]$WordWrap = $false
    [int]$TabSize = 4
    [scriptblock]$OnChange = $null
    [scriptblock]$OnLineChange = $null
    
    # Visual properties
    [bool]$ShowBorder = $true
    [bool]$ShowLineNumbers = $false
    [bool]$ShowScrollbars = $true
    [int]$LineNumberWidth = 4
    
    # Text management
    hidden [int]$_maxLineLength = 0
    hidden [bool]$_modified = $false
    
    MultilineTextBox([string]$name) : base($name) {
        $this.Lines = [System.Collections.ArrayList]::new()
        $this.Lines.Add("") | Out-Null
        $this.IsFocusable = $true
        $this.Width = 40
        $this.Height = 10
    }
    
    [void] SetText([string]$text) {
        $this.Lines.Clear()
        
        if ([string]::IsNullOrEmpty($text)) {
            $this.Lines.Add("") | Out-Null
        } else {
            $textLines = $text -split "`r?`n"
            foreach ($line in $textLines) {
                $this.Lines.Add($line) | Out-Null
            }
        }
        
        $this.CursorLine = 0
        $this.CursorColumn = 0
        $this.ScrollOffsetY = 0
        $this.ScrollOffsetX = 0
        $this._modified = $false
        $this.UpdateMaxLineLength()
        $this.Invalidate()
    }
    
    [string] GetText() {
        return $this.Lines -join "`n"
    }
    
    [void] UpdateMaxLineLength() {
        $this._maxLineLength = 0
        foreach ($line in $this.Lines) {
            if ($line.Length -gt $this._maxLineLength) {
                $this._maxLineLength = $line.Length
            }
        }
    }
    
    [void] InsertText([string]$text) {
        if ($this.ReadOnly) { return }
        
        $currentLine = $this.Lines[$this.CursorLine]
        
        # Handle newlines
        if ($text -eq "`n") {
            # Split current line at cursor
            $before = $currentLine.Substring(0, $this.CursorColumn)
            $after = if ($this.CursorColumn -lt $currentLine.Length) {
                $currentLine.Substring($this.CursorColumn)
            } else { "" }
            
            $this.Lines[$this.CursorLine] = $before
            $this.Lines.Insert($this.CursorLine + 1, $after)
            
            $this.CursorLine++
            $this.CursorColumn = 0
        } else {
            # Insert text at cursor position
            $this.Lines[$this.CursorLine] = $currentLine.Insert($this.CursorColumn, $text)
            $this.CursorColumn += $text.Length
        }
        
        $this._modified = $true
        $this.UpdateMaxLineLength()
        
        if ($this.OnChange) {
            & $this.OnChange $this $this.GetText()
        }
        if ($this.OnLineChange) {
            & $this.OnLineChange $this $this.CursorLine $this.Lines[$this.CursorLine]
        }
        
        $this.Invalidate()
    }
    
    [void] DeleteChar([bool]$backspace) {
        if ($this.ReadOnly) { return }
        
        if ($backspace) {
            # Backspace
            if ($this.CursorColumn -gt 0) {
                $currentLine = $this.Lines[$this.CursorLine]
                $this.Lines[$this.CursorLine] = $currentLine.Remove($this.CursorColumn - 1, 1)
                $this.CursorColumn--
            } elseif ($this.CursorLine -gt 0) {
                # Merge with previous line
                $previousLine = $this.Lines[$this.CursorLine - 1]
                $currentLine = $this.Lines[$this.CursorLine]
                $this.CursorColumn = $previousLine.Length
                $this.Lines[$this.CursorLine - 1] = $previousLine + $currentLine
                $this.Lines.RemoveAt($this.CursorLine)
                $this.CursorLine--
            }
        } else {
            # Delete
            $currentLine = $this.Lines[$this.CursorLine]
            if ($this.CursorColumn -lt $currentLine.Length) {
                $this.Lines[$this.CursorLine] = $currentLine.Remove($this.CursorColumn, 1)
            } elseif ($this.CursorLine -lt $this.Lines.Count - 1) {
                # Merge with next line
                $nextLine = $this.Lines[$this.CursorLine + 1]
                $this.Lines[$this.CursorLine] = $currentLine + $nextLine
                $this.Lines.RemoveAt($this.CursorLine + 1)
            }
        }
        
        $this._modified = $true
        $this.UpdateMaxLineLength()
        
        if ($this.OnChange) {
            & $this.OnChange $this $this.GetText()
        }
        
        $this.Invalidate()
    }
    
    [void] EnsureCursorVisible() {
        # Calculate content area
        if ($this.ShowBorder) {
            $contentHeight = $this.Height - 2
            $contentWidth = $this.Width - 2
        } else {
            $contentHeight = $this.Height
            $contentWidth = $this.Width
        }
        
        if ($this.ShowLineNumbers) {
            $contentWidth -= $this.LineNumberWidth + 1
        }
        
        # Vertical scrolling
        if ($this.CursorLine -lt $this.ScrollOffsetY) {
            $this.ScrollOffsetY = $this.CursorLine
        } elseif ($this.CursorLine -ge $this.ScrollOffsetY + $contentHeight) {
            $this.ScrollOffsetY = $this.CursorLine - $contentHeight + 1
        }
        
        # Horizontal scrolling
        if ($this.CursorColumn -lt $this.ScrollOffsetX) {
            $this.ScrollOffsetX = $this.CursorColumn
        } elseif ($this.CursorColumn -ge $this.ScrollOffsetX + $contentWidth) {
            $this.ScrollOffsetX = $this.CursorColumn - $contentWidth + 1
        }
    }
    
    [void] OnRender([object]$buffer) {
        if (-not $this.Visible) { return }
        
        # Colors
        $bgColor = if ($this.BackgroundColor) { $this.BackgroundColor } else { [VT]::RGBBG(30, 30, 35) }
        $fgColor = if ($this.ForegroundColor) { $this.ForegroundColor } else { [VT]::RGB(220, 220, 220) }
        $borderColor = if ($this.BorderColor) { $this.BorderColor } else {
            if ($this.IsFocused) { [VT]::RGB(100, 200, 255) } else { [VT]::RGB(80, 80, 100) }
        }
        $lineNumColor = [VT]::RGB(100, 100, 120)
        
        # Clear background
        for ($y = 0; $y -lt $this.Height; $y++) {
            $this.DrawText($buffer, 0, $y, $bgColor + (" " * $this.Width) + [VT]::Reset())
        }
        
        # Draw border if enabled
        if ($this.ShowBorder) {
            $this.DrawBorder($buffer, $borderColor)
        }
        
        # Calculate content area
        $contentY = if ($this.ShowBorder) { 1 } else { 0 }
        $contentX = if ($this.ShowBorder) { 1 } else { 0 }
        if ($this.ShowBorder) {
            $contentHeight = $this.Height - 2
            $contentWidth = $this.Width - 2
        } else {
            $contentHeight = $this.Height
            $contentWidth = $this.Width
        }
        
        # Adjust for line numbers
        $textStartX = $contentX
        if ($this.ShowLineNumbers) {
            $textStartX += $this.LineNumberWidth + 1
            $contentWidth -= $this.LineNumberWidth + 1
        }
        
        # Ensure cursor is visible
        $this.EnsureCursorVisible()
        
        # Draw visible lines
        for ($y = 0; $y -lt $contentHeight; $y++) {
            $lineIndex = $y + $this.ScrollOffsetY
            if ($lineIndex -ge $this.Lines.Count) { break }
            
            # Draw line number if enabled
            if ($this.ShowLineNumbers) {
                $lineNum = ($lineIndex + 1).ToString().PadLeft($this.LineNumberWidth)
                $this.DrawText($buffer, $contentX, $contentY + $y, 
                              $lineNumColor + $lineNum + " " + [VT]::Reset())
            }
            
            # Draw line content
            $line = $this.Lines[$lineIndex]
            $visibleText = ""
            
            if ($line.Length -gt $this.ScrollOffsetX) {
                $endPos = [Math]::Min($this.ScrollOffsetX + $contentWidth, $line.Length)
                $visibleText = $line.Substring($this.ScrollOffsetX, $endPos - $this.ScrollOffsetX)
            }
            
            if ($visibleText) {
                $this.DrawText($buffer, $textStartX, $contentY + $y, 
                              $fgColor + $visibleText + [VT]::Reset())
            }
        }
        
        # Draw cursor if focused
        if ($this.IsFocused -and -not $this.ReadOnly) {
            $cursorScreenY = $contentY + ($this.CursorLine - $this.ScrollOffsetY)
            $cursorScreenX = $textStartX + ($this.CursorColumn - $this.ScrollOffsetX)
            
            if ($cursorScreenY -ge $contentY -and $cursorScreenY -lt $contentY + $contentHeight -and
                $cursorScreenX -ge $textStartX -and $cursorScreenX -lt $textStartX + $contentWidth) {
                
                $charUnderCursor = ' '
                if ($this.CursorLine -lt $this.Lines.Count) {
                    $line = $this.Lines[$this.CursorLine]
                    if ($this.CursorColumn -lt $line.Length) {
                        $charUnderCursor = $line[$this.CursorColumn]
                    }
                }
                
                $this.DrawText($buffer, $cursorScreenX, $cursorScreenY,
                              [VT]::RGBBG(220, 220, 220) + [VT]::RGB(30, 30, 35) + 
                              $charUnderCursor + [VT]::Reset())
            }
        }
        
        # Draw scrollbars if needed
        if ($this.ShowScrollbars) {
            # Vertical scrollbar
            if ($this.Lines.Count -gt $contentHeight) {
                $this.DrawVerticalScrollbar($buffer, $this.Width - 1, $contentY, 
                                           $contentHeight, $this.ScrollOffsetY, $this.Lines.Count)
            }
            
            # Horizontal scrollbar
            if ($this._maxLineLength -gt $contentWidth) {
                $this.DrawHorizontalScrollbar($buffer, $textStartX, $this.Height - 1,
                                            $contentWidth, $this.ScrollOffsetX, $this._maxLineLength)
            }
        }
    }
    
    [void] DrawBorder([object]$buffer, [string]$color) {
        # Top
        $this.DrawText($buffer, 0, 0, $color + "┌" + ("─" * ($this.Width - 2)) + "┐" + [VT]::Reset())
        
        # Sides
        for ($y = 1; $y -lt $this.Height - 1; $y++) {
            $this.DrawText($buffer, 0, $y, $color + "│" + [VT]::Reset())
            $this.DrawText($buffer, $this.Width - 1, $y, $color + "│" + [VT]::Reset())
        }
        
        # Bottom
        $this.DrawText($buffer, 0, $this.Height - 1, 
                      $color + "└" + ("─" * ($this.Width - 2)) + "┘" + [VT]::Reset())
    }
    
    [void] DrawVerticalScrollbar([object]$buffer, [int]$x, [int]$y, [int]$height, [int]$offset, [int]$total) {
        $thumbSize = [Math]::Max(1, [int]($height * $height / $total))
        $maxOffset = $total - $height
        $thumbPos = if ($maxOffset -gt 0) {
            [int](($height - $thumbSize) * $offset / $maxOffset)
        } else { 0 }
        
        for ($i = 0; $i -lt $height; $i++) {
            $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { "█" } else { "░" }
            $this.DrawText($buffer, $x, $y + $i, [VT]::RGB(60, 60, 80) + $char + [VT]::Reset())
        }
    }
    
    [void] DrawHorizontalScrollbar([object]$buffer, [int]$x, [int]$y, [int]$width, [int]$offset, [int]$total) {
        $thumbSize = [Math]::Max(1, [int]($width * $width / $total))
        $maxOffset = $total - $width
        $thumbPos = if ($maxOffset -gt 0) {
            [int](($width - $thumbSize) * $offset / $maxOffset)
        } else { 0 }
        
        for ($i = 0; $i -lt $width; $i++) {
            $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { "█" } else { "░" }
            $this.DrawText($buffer, $x + $i, $y, [VT]::RGB(60, 60, 80) + $char + [VT]::Reset())
        }
    }
    
    [void] DrawText([object]$buffer, [int]$x, [int]$y, [string]$text) {
        # Placeholder for alcar buffer integration
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.Enabled -or -not $this.IsFocused) { return $false }
        
        $handled = $true
        
        switch ($key.Key) {
            # Navigation
            ([ConsoleKey]::LeftArrow) {
                if ($this.CursorColumn -gt 0) {
                    $this.CursorColumn--
                } elseif ($this.CursorLine -gt 0) {
                    $this.CursorLine--
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
            }
            ([ConsoleKey]::RightArrow) {
                $currentLine = $this.Lines[$this.CursorLine]
                if ($this.CursorColumn -lt $currentLine.Length) {
                    $this.CursorColumn++
                } elseif ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $this.CursorLine++
                    $this.CursorColumn = 0
                }
            }
            ([ConsoleKey]::UpArrow) {
                if ($this.CursorLine -gt 0) {
                    $this.CursorLine--
                    $currentLine = $this.Lines[$this.CursorLine]
                    $this.CursorColumn = [Math]::Min($this.CursorColumn, $currentLine.Length)
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $this.CursorLine++
                    $currentLine = $this.Lines[$this.CursorLine]
                    $this.CursorColumn = [Math]::Min($this.CursorColumn, $currentLine.Length)
                }
            }
            ([ConsoleKey]::Home) {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    # Go to beginning of document
                    $this.CursorLine = 0
                    $this.CursorColumn = 0
                } else {
                    # Go to beginning of line
                    $this.CursorColumn = 0
                }
            }
            ([ConsoleKey]::End) {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    # Go to end of document
                    $this.CursorLine = $this.Lines.Count - 1
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                } else {
                    # Go to end of line
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
            }
            ([ConsoleKey]::PageUp) {
                $pageSize = $this.Height - (if ($this.ShowBorder) { 2 } else { 0 })
                $this.CursorLine = [Math]::Max(0, $this.CursorLine - $pageSize)
                $currentLine = $this.Lines[$this.CursorLine]
                $this.CursorColumn = [Math]::Min($this.CursorColumn, $currentLine.Length)
            }
            ([ConsoleKey]::PageDown) {
                $pageSize = $this.Height - (if ($this.ShowBorder) { 2 } else { 0 })
                $this.CursorLine = [Math]::Min($this.Lines.Count - 1, $this.CursorLine + $pageSize)
                $currentLine = $this.Lines[$this.CursorLine]
                $this.CursorColumn = [Math]::Min($this.CursorColumn, $currentLine.Length)
            }
            
            # Editing
            ([ConsoleKey]::Enter) {
                if (-not $this.ReadOnly) {
                    $this.InsertText("`n")
                }
            }
            ([ConsoleKey]::Backspace) {
                if (-not $this.ReadOnly) {
                    $this.DeleteChar($true)
                }
            }
            ([ConsoleKey]::Delete) {
                if (-not $this.ReadOnly) {
                    $this.DeleteChar($false)
                }
            }
            ([ConsoleKey]::Tab) {
                if (-not $this.ReadOnly) {
                    $this.InsertText(" " * $this.TabSize)
                }
            }
            
            default {
                # Character input
                if (-not $this.ReadOnly -and $key.KeyChar -and 
                    [char]::IsControl($key.KeyChar) -eq $false) {
                    $this.InsertText($key.KeyChar.ToString())
                } else {
                    $handled = $false
                }
            }
        }
        
        if ($handled) {
            $this.EnsureCursorVisible()
            $this.Invalidate()
        }
        
        return $handled
    }
    
    [void] OnFocus() {
        $this.Invalidate()
    }
    
    [void] OnBlur() {
        $this.Invalidate()
    }
    
    # Static factory methods
    static [MultilineTextBox] CreateReadOnly([string]$name, [string]$text) {
        $textBox = [MultilineTextBox]::new($name)
        $textBox.SetText($text)
        $textBox.ReadOnly = $true
        return $textBox
    }
    
    static [MultilineTextBox] CreateWithLineNumbers([string]$name) {
        $textBox = [MultilineTextBox]::new($name)
        $textBox.ShowLineNumbers = $true
        return $textBox
    }
}