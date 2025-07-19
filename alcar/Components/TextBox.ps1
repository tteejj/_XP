# TextBox Component - Single-line text input field

class TextBox : Component {
    [string]$Text = ""
    [string]$Placeholder = ""
    [int]$MaxLength = 100
    [int]$CursorPosition = 0
    [scriptblock]$OnChange = $null
    [scriptblock]$OnSubmit = $null
    
    # Visual properties
    [bool]$ShowBorder = $true
    [string]$PlaceholderColor = ""
    [bool]$ShowCursor = $true
    [bool]$PasswordMode = $false
    [char]$PasswordChar = '•'
    
    # Internal state
    hidden [int]$_scrollOffset = 0
    hidden [string]$_lastText = ""
    
    TextBox([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Height = if ($this.ShowBorder) { 3 } else { 1 }
        $this.Width = 20
    }
    
    [void] SetText([string]$text) {
        $this.Text = $text
        $this.CursorPosition = $text.Length
        $this._scrollOffset = 0
        $this.Invalidate()
    }
    
    [void] Clear() {
        $this.Text = ""
        $this.CursorPosition = 0
        $this._scrollOffset = 0
        $this.Invalidate()
    }
    
    [void] OnRender([object]$buffer) {
        if (-not $this.Visible) { return }
        
        # Determine colors
        $bgColor = if ($this.BackgroundColor) { $this.BackgroundColor } else { [VT]::RGBBG(30, 30, 35) }
        $fgColor = if ($this.ForegroundColor) { $this.ForegroundColor } else { [VT]::RGB(220, 220, 220) }
        $borderColor = if ($this.BorderColor) { $this.BorderColor } else {
            if ($this.IsFocused) { [VT]::RGB(100, 200, 255) } else { [VT]::RGB(80, 80, 100) }
        }
        $placeholderColor = if ($this.PlaceholderColor) { $this.PlaceholderColor } else { [VT]::RGB(100, 100, 120) }
        
        # Calculate content area
        $contentY = if ($this.ShowBorder) { 1 } else { 0 }
        $contentX = if ($this.ShowBorder) { 1 } else { 0 }
        $contentWidth = $this.Width - (if ($this.ShowBorder) { 2 } else { 0 })
        
        # Clear background
        for ($y = 0; $y -lt $this.Height; $y++) {
            $this.DrawText($buffer, 0, $y, $bgColor + (" " * $this.Width) + [VT]::Reset())
        }
        
        # Draw border if enabled
        if ($this.ShowBorder) {
            $this.DrawBorder($buffer, $borderColor)
        }
        
        # Calculate visible text with scroll offset
        $this.UpdateScrollOffset($contentWidth)
        
        # Draw content
        if ($this.Text.Length -eq 0 -and $this.Placeholder) {
            # Show placeholder
            $placeholderText = if ($this.Placeholder.Length -gt $contentWidth) {
                $this.Placeholder.Substring(0, $contentWidth - 3) + "..."
            } else {
                $this.Placeholder
            }
            $this.DrawText($buffer, $contentX, $contentY, 
                          $placeholderColor + $placeholderText + [VT]::Reset())
        } else {
            # Show text (with password masking if enabled)
            $displayText = if ($this.PasswordMode) {
                $this.PasswordChar * $this.Text.Length
            } else {
                $this.Text
            }
            
            # Get visible portion
            $visibleText = ""
            if ($displayText.Length -gt $this._scrollOffset) {
                $endIndex = [Math]::Min($displayText.Length, $this._scrollOffset + $contentWidth)
                $visibleText = $displayText.Substring($this._scrollOffset, $endIndex - $this._scrollOffset)
            }
            
            if ($visibleText) {
                $this.DrawText($buffer, $contentX, $contentY, 
                              $fgColor + $visibleText + [VT]::Reset())
            }
        }
        
        # Draw cursor if focused
        if ($this.IsFocused -and $this.ShowCursor) {
            $cursorScreenPos = $this.CursorPosition - $this._scrollOffset
            if ($cursorScreenPos -ge 0 -and $cursorScreenPos -lt $contentWidth) {
                $cursorX = $contentX + $cursorScreenPos
                
                # Get character under cursor
                $charUnderCursor = ' '
                if ($this.CursorPosition -lt $this.Text.Length) {
                    $charUnderCursor = if ($this.PasswordMode) { 
                        $this.PasswordChar 
                    } else { 
                        $this.Text[$this.CursorPosition] 
                    }
                }
                
                # Draw inverted cursor
                $this.DrawText($buffer, $cursorX, $contentY,
                              [VT]::RGBBG(220, 220, 220) + [VT]::RGB(30, 30, 35) + 
                              $charUnderCursor + [VT]::Reset())
            }
        }
    }
    
    [void] DrawBorder([object]$buffer, [string]$color) {
        # Top border
        $this.DrawText($buffer, 0, 0, $color + "┌" + ("─" * ($this.Width - 2)) + "┐" + [VT]::Reset())
        
        # Middle with sides
        $this.DrawText($buffer, 0, 1, $color + "│" + [VT]::Reset())
        $this.DrawText($buffer, $this.Width - 1, 1, $color + "│" + [VT]::Reset())
        
        # Bottom border
        $this.DrawText($buffer, 0, 2, $color + "└" + ("─" * ($this.Width - 2)) + "┘" + [VT]::Reset())
    }
    
    [void] UpdateScrollOffset([int]$visibleWidth) {
        # Ensure cursor stays visible
        if ($this.CursorPosition -lt $this._scrollOffset) {
            $this._scrollOffset = $this.CursorPosition
        } elseif ($this.CursorPosition -ge ($this._scrollOffset + $visibleWidth)) {
            $this._scrollOffset = $this.CursorPosition - $visibleWidth + 1
        }
        
        # Ensure scroll offset is valid
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
    }
    
    [void] DrawText([object]$buffer, [int]$x, [int]$y, [string]$text) {
        # Placeholder for alcar buffer integration
        # In production, this would integrate with the buffer system
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.IsFocused) { return $false }
        
        $handled = $true
        $oldText = $this.Text
        
        switch ($key.Key) {
            ([ConsoleKey]::LeftArrow) {
                if ($this.CursorPosition -gt 0) {
                    $this.CursorPosition--
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($this.CursorPosition -lt $this.Text.Length) {
                    $this.CursorPosition++
                }
            }
            ([ConsoleKey]::Home) {
                $this.CursorPosition = 0
            }
            ([ConsoleKey]::End) {
                $this.CursorPosition = $this.Text.Length
            }
            ([ConsoleKey]::Backspace) {
                if ($this.CursorPosition -gt 0) {
                    $this.Text = $this.Text.Remove($this.CursorPosition - 1, 1)
                    $this.CursorPosition--
                }
            }
            ([ConsoleKey]::Delete) {
                if ($this.CursorPosition -lt $this.Text.Length) {
                    $this.Text = $this.Text.Remove($this.CursorPosition, 1)
                }
            }
            ([ConsoleKey]::Enter) {
                if ($this.OnSubmit) {
                    & $this.OnSubmit $this $this.Text
                }
            }
            ([ConsoleKey]::Escape) {
                # Could implement cancel behavior
                $handled = $false
            }
            default {
                # Handle character input
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    if ($this.Text.Length -lt $this.MaxLength) {
                        $this.Text = $this.Text.Insert($this.CursorPosition, $key.KeyChar)
                        $this.CursorPosition++
                    }
                } else {
                    $handled = $false
                }
            }
        }
        
        if ($handled) {
            # Fire OnChange event if text changed
            if ($oldText -ne $this.Text -and $this.OnChange) {
                & $this.OnChange $this $this.Text
            }
            
            $this.Invalidate()
        }
        
        return $handled
    }
    
    [void] OnFocus() {
        $this.ShowCursor = $true
        $this.Invalidate()
    }
    
    [void] OnBlur() {
        $this.ShowCursor = $false
        $this.Invalidate()
    }
    
    # Static factory method for common configurations
    static [TextBox] CreatePassword([string]$name) {
        $textBox = [TextBox]::new($name)
        $textBox.PasswordMode = $true
        $textBox.Placeholder = "Enter password..."
        return $textBox
    }
    
    static [TextBox] CreateSearch([string]$name) {
        $textBox = [TextBox]::new($name)
        $textBox.Placeholder = "Search..."
        $textBox.ShowBorder = $false
        $textBox.Width = 30
        return $textBox
    }
}