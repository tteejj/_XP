# ==============================================================================
# Axiom-Phoenix v4.0 - Core Components
# Contains fundamental UI components like labels, buttons, text boxes,
# checkboxes, radio buttons, and list boxes.
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

##<!-- PAGE: ACO.001 - LabelComponent Class -->
#region Core UI Components

# ===== CLASS: LabelComponent =====
# Module: tui-components
# Dependencies: UIElement
# Purpose: Static text display
class LabelComponent : UIElement {
    [string]$Text = ""
    [object]$ForegroundColor

    LabelComponent([string]$name) : base($name) {
        $this.IsFocusable = $false
        $this.Width = 30  # Increased default width
        $this.Height = 1
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer with theme background
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Get foreground color
        if ($this.ForegroundColor) {
            if ($this.ForegroundColor -is [ConsoleColor]) {
                # Convert ConsoleColor to hex if needed
                $fg = Get-ThemeColor("Foreground") # Use theme default instead
            } else {
                $fg = $this.ForegroundColor # Assume it's already hex
            }
        } else {
            $fg = Get-ThemeColor("Foreground")
        }
        
        # Draw text
        Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $this.Text -Style @{ FG = $fg; BG = $bgColor }
        
        $this._needs_redraw = $false
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $false
    }
}
#<!-- END_PAGE: ACO.001 -->

#<!-- PAGE: ACO.002 - ButtonComponent Class -->
# ===== CLASS: ButtonComponent =====
# Module: tui-components
# Dependencies: UIElement, TuiCell
# Purpose: Interactive button with click events
class ButtonComponent : UIElement {
    [string]$Text = "Button"
    [bool]$IsPressed = $false
    [scriptblock]$OnClick

    ButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 10
        $this.Height = 3
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer with theme background
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Determine colors based on state
        $fgColor = "#FFFFFF"
        $bgColor = "#333333"
        
        if ($this.IsPressed) {
            $fgColor = Get-ThemeColor("button.pressed.fg")
            $bgColor = Get-ThemeColor("button.pressed.bg")
        }
        elseif ($this.IsFocused) {
            $fgColor = Get-ThemeColor("button.focused.fg") 
            $bgColor = Get-ThemeColor("button.focused.bg")
        }
        elseif (-not $this.Enabled) {
            $fgColor = Get-ThemeColor("button.disabled.fg")
            $bgColor = Get-ThemeColor("button.disabled.bg")
        }
        else {
            $fgColor = Get-ThemeColor("button.normal.fg")
            $bgColor = Get-ThemeColor("button.normal.bg")
        }
        
        # Draw button background
        $style = @{ FG = $fgColor; BG = $bgColor }
        $this._private_buffer.FillRect(0, 0, $this.Width, $this.Height, ' ', $style)
        
        # Draw button text centered
        if (-not [string]::IsNullOrEmpty($this.Text)) {
            $textX = [Math]::Max(0, [Math]::Floor(($this.Width - $this.Text.Length) / 2))
            $textY = [Math]::Floor($this.Height / 2)
            
            Write-TuiText -Buffer $this._private_buffer -X $textX -Y $textY -Text $this.Text -Style $style
        }
        
        $this._needs_redraw = $false
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            try {
                $this.IsPressed = $true
                $this.RequestRedraw()
                
                if ($this.OnClick) {
                    & $this.OnClick
                }
                
                Start-Sleep -Milliseconds 50
                $this.IsPressed = $false
                $this.RequestRedraw()
                
                return $true
            }
            catch {
                $this.IsPressed = $false
                $this.RequestRedraw()
            }
        }
        return $false
    }
}

#<!-- END_PAGE: ACO.002 -->

#<!-- PAGE: ACO.003 - TextBoxComponent Class -->
# ===== CLASS: TextBoxComponent =====
# Module: tui-components
# Dependencies: UIElement, TuiCell
# Purpose: Text input with viewport scrolling, non-destructive cursor
class TextBoxComponent : UIElement {
    [string]$Text = ""
    [string]$Placeholder = ""
    [ValidateRange(1, [int]::MaxValue)][int]$MaxLength = 100
    [int]$CursorPosition = 0
    [scriptblock]$OnChange
    hidden [int]$_scrollOffset = 0
    [string]$BackgroundColor = "#000000" # Changed from ConsoleColor to hex string
    [string]$ForegroundColor = "#FFFFFF" # Changed from ConsoleColor to hex string
    [string]$BorderColor = "#808080" # Changed from ConsoleColor to hex string
    [string]$PlaceholderColor = "#808080" # Changed from ConsoleColor to hex string

    TextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer with theme background
        $bgColor = Get-ThemeColor("input.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Determine colors
        $fgColor = if ($this.IsFocused) { Get-ThemeColor("input.foreground") } else { Get-ThemeColor("Subtle") }
        $bgColor = Get-ThemeColor("input.background")
        $borderColorValue = if ($this.IsFocused) { Get-ThemeColor("Primary") } else { Get-ThemeColor("component.border") }
        
        # Draw border
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
            -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = "Single" }
            
            # Draw text or placeholder
            $contentY = 1
            $contentStartX = 1
            $contentWidth = $this.Width - 2
            
            if ($this.Text.Length -eq 0 -and $this.Placeholder) {
                # Draw placeholder
                $placeholderText = if ($this.Placeholder.Length -gt $contentWidth) {
                    $this.Placeholder.Substring(0, $contentWidth)
                } else { $this.Placeholder }
                
                $textStyle = @{ FG = Get-ThemeColor("input.placeholder"); BG = $bgColor }
                Write-TuiText -Buffer $this._private_buffer -X $contentStartX -Y $contentY -Text $placeholderText -Style $textStyle
            }
            else {
                # Calculate scroll offset
                if ($this.CursorPosition -lt $this._scrollOffset) {
                    $this._scrollOffset = $this.CursorPosition
                }
                elseif ($this.CursorPosition -ge ($this._scrollOffset + $contentWidth)) {
                    $this._scrollOffset = $this.CursorPosition - $contentWidth + 1
                }
                
                # Draw visible portion of text
                $visibleText = ""
                if ($this.Text.Length -gt 0) {
                    $endPos = [Math]::Min($this._scrollOffset + $contentWidth, $this.Text.Length)
                    if ($this._scrollOffset -lt $this.Text.Length) {
                        $visibleText = $this.Text.Substring($this._scrollOffset, $endPos - $this._scrollOffset)
                    }
                }
                
                if ($visibleText) {
                    $textStyle = @{ FG = $fgColor; BG = $bgColor }
                    Write-TuiText -Buffer $this._private_buffer -X $contentStartX -Y $contentY -Text $visibleText -Style $textStyle
                }
                
                # Draw cursor if focused (non-destructive - inverts colors)
                if ($this.IsFocused) {
                    $cursorScreenPos = $this.CursorPosition - $this._scrollOffset
                    if ($cursorScreenPos -ge 0 -and $cursorScreenPos -lt $contentWidth) {
                        $cursorX = $contentStartX + $cursorScreenPos
                        
                        # Get the cell that is ALREADY at the cursor's position
                        $cellUnderCursor = $this._private_buffer.GetCell($cursorX, $contentY)
                        
                        # Invert its colors to represent the cursor (non-destructive)
                        $cursorFg = $cellUnderCursor.BackgroundColor
                        $cursorBg = $cellUnderCursor.ForegroundColor
                        $newCell = [TuiCell]::new($cellUnderCursor.Char, $cursorBg, $cursorFg, $true) # Make it bold
                        $this._private_buffer.SetCell($cursorX, $contentY, $newCell)
                    }
                }
            }
            
        $this._needs_redraw = $false
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
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
            default {
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    if ($this.Text.Length -lt $this.MaxLength) {
                        $this.Text = $this.Text.Insert($this.CursorPosition, $key.KeyChar)
                        $this.CursorPosition++
                    }
                }
                else {
                    $handled = $false
                }
            }
        }
        
        if ($handled) {
            if ($oldText -ne $this.Text -and $this.OnChange) {
                try { 
                    & $this.OnChange $this $this.Text 
                } catch {
                    # Ignore errors in onChange handler
                }
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
}

#<!-- END_PAGE: ACO.003 -->

#<!-- PAGE: ACO.004 - CheckBoxComponent Class -->
# ===== CLASS: CheckBoxComponent =====
# Module: tui-components
# Dependencies: UIElement, TuiCell
# Purpose: Boolean checkbox input
class CheckBoxComponent : UIElement {
    [string]$Text = ""
    [bool]$Checked = $false
    [scriptblock]$OnChange

    CheckBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        if ($this.IsFocused) { 
            $fgColor = Get-ThemeColor("Primary") 
        } else { 
            $fgColor = Get-ThemeColor("Foreground") 
        }
        if ($this.Checked) { 
            $checkMark = "[X]" 
        } else { 
            $checkMark = "[ ]" 
        }
        $fullText = "$checkMark $($this.Text)"
        
        Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $fullText -Style @{ FG = $fgColor; BG = $bgColor }
        
        $this._needs_redraw = $false
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        if ($key.Key -eq [ConsoleKey]::Spacebar) {
            $this.Checked = -not $this.Checked
            if ($this.OnChange) {
                try { 
                    & $this.OnChange $this $this.Checked 
                } catch {
                    # Ignore errors in onChange handler
                }
            }
            $this.RequestRedraw()
            return $true
        }
        
        return $false
    }
}

#<!-- END_PAGE: ACO.004 -->

#<!-- PAGE: ACO.005 - RadioButtonComponent Class -->
# ===== CLASS: RadioButtonComponent =====
# Module: tui-components
# Dependencies: UIElement, TuiCell
# Purpose: Exclusive selection with group management
class RadioButtonComponent : UIElement {
    [string]$Text = ""
    [bool]$Selected = $false
    [string]$GroupName = "default"
    [scriptblock]$OnChange
    static [hashtable]$_groups = @{}

    RadioButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        if ($this.IsFocused) { 
            $fgColor = Get-ThemeColor("Primary") 
        } else { 
            $fgColor = Get-ThemeColor("Foreground") 
        }
        if ($this.Selected) { 
            $radioMark = "(o)" 
        } else { 
            $radioMark = "( )" 
        }
        $fullText = "$radioMark $($this.Text)"
        
        Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $fullText -Style @{ FG = $fgColor; BG = $bgColor }
        
        $this._needs_redraw = $false
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        if ($key.Key -eq [ConsoleKey]::Spacebar -and -not $this.Selected) {
            $this.Select()
            return $true
        }
        
        return $false
    }

    [void] Select() {
        # Deselect all others in group
        if ([RadioButtonComponent]::_groups.ContainsKey($this.GroupName)) {
            foreach ($radio in [RadioButtonComponent]::_groups[$this.GroupName]) {
                if ($radio -ne $this -and $radio.Selected) {
                    $radio.Selected = $false
                    $radio.RequestRedraw()
                    if ($radio.OnChange) {
                        try { 
                            & $radio.OnChange $radio $false 
                        } catch {
                            # Ignore errors in onChange handler
                        }
                    }
                }
            }
        }
        
        $this.Selected = $true
        $this.RequestRedraw()
        if ($this.OnChange) {
            try { 
                & $this.OnChange $this $true 
            } catch {
                # Ignore errors in onChange handler
            }
        }
    }

    [void] AddedToParent() {
        if (-not [RadioButtonComponent]::_groups.ContainsKey($this.GroupName)) {
            [RadioButtonComponent]::_groups[$this.GroupName] = [List[RadioButtonComponent]]::new()
        }
        [RadioButtonComponent]::_groups[$this.GroupName].Add($this)
    }

    [void] RemovedFromParent() {
        if ([RadioButtonComponent]::_groups.ContainsKey($this.GroupName)) {
            [RadioButtonComponent]::_groups[$this.GroupName].Remove($this)
        }
    }
}

#endregion Core UI Components
#<!-- END_PAGE: ACO.005 -->

#<!-- PAGE: ACO.014 - ListBox Class -->
# ===== CLASS: ListBox =====
# Module: tui-components (wrapper)
# Dependencies: UIElement, TuiCell
# Purpose: Scrollable item list with selection
class ListBox : UIElement {
    [List[object]]$Items
    [int]$SelectedIndex = -1
    [string]$ForegroundColor = "#FFFFFF" # Changed from ConsoleColor to hex string
    [string]$BackgroundColor = "#000000" # Changed from ConsoleColor to hex string
    [string]$SelectedForegroundColor = "#000000" # Changed from ConsoleColor to hex string
    [string]$SelectedBackgroundColor = "#00FFFF" # Changed from ConsoleColor to hex string
    [string]$BorderColor = "#808080" # Changed from ConsoleColor to hex string
    hidden [int]$ScrollOffset = 0

    ListBox([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Items = [List[object]]::new()
        $this.Width = 30
        $this.Height = 10
    }

    [void] AddItem([object]$item) {
        $this.Items.Add($item)
        if ($this.SelectedIndex -eq -1 -and $this.Items.Count -eq 1) {
            $this.SelectedIndex = 0
        }
        $this.RequestRedraw()
    }

    [void] ClearItems() {
        $this.Items.Clear()
        $this.SelectedIndex = -1
        $this.ScrollOffset = 0
        $this.RequestRedraw()
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Draw border
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
            -Style @{ BorderFG = Get-ThemeColor("component.border"); BG = $bgColor; BorderStyle = "Single" }
            
            # Calculate visible area
            $contentY = 1
            $contentHeight = $this.Height - 2
            $contentX = 1
            $contentWidth = $this.Width - 2
            
            # Ensure selected item is visible
            $this.EnsureVisible($this.SelectedIndex)
            
            # Draw items
            for ($i = 0; $i -lt $contentHeight -and ($i + $this.ScrollOffset) -lt $this.Items.Count; $i++) {
                $itemIndex = $i + $this.ScrollOffset
                $item = $this.Items[$itemIndex]
                if ($item -is [string]) { 
                    $itemText = $item 
                } else { 
                    $itemText = $item.ToString() 
                }
                
                if ($itemText.Length -gt $contentWidth) {
                    $itemText = $itemText.Substring(0, $contentWidth - 3) + "..."
                }
                
                $isSelected = ($itemIndex -eq $this.SelectedIndex)
                if ($isSelected) { 
                    $fgColor = Get-ThemeColor("list.item.selected") 
                } else { 
                    $fgColor = Get-ThemeColor("list.item.normal") 
                }
                if ($isSelected) { 
                    $itemBgColor = Get-ThemeColor("list.item.selected.background") 
                } else { 
                    $itemBgColor = $bgColor 
                }
                
                # Draw item background
                $this._private_buffer.FillRect(1, $contentY + $i, $this.Width - 2, 1, ' ', @{ BG = $itemBgColor })
                
                # Draw item text
                Write-TuiText -Buffer $this._private_buffer -X $contentX -Y ($contentY + $i) -Text $itemText `
                    -Style @{ FG = $fgColor; BG = $itemBgColor }
            }
            
            # Draw scrollbar if needed
            if ($this.Items.Count -gt $contentHeight) {
                $scrollbarX = $this.Width - 2
                $scrollbarHeight = $contentHeight
                $thumbSize = [Math]::Max(1, [int]($scrollbarHeight * $scrollbarHeight / $this.Items.Count))
                $thumbPos = if ($this.Items.Count -gt $scrollbarHeight) {
                    [int](($scrollbarHeight - $thumbSize) * $this.ScrollOffset / ($this.Items.Count - $scrollbarHeight))
                } else { 0 }
                
                $scrollbarColor = Get-ThemeColor "list.scrollbar"
                for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                    $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { '█' } else { '│' }
                    $this._private_buffer.SetCell($scrollbarX, $contentY + $i, 
                        [TuiCell]::new($char, $scrollbarColor, $bgColor))
                }
            }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or $this.Items.Count -eq 0) { return $false }
        
        $handled = $true
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectedIndex++
                }
            }
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
            }
            ([ConsoleKey]::PageUp) {
                $pageSize = $this.Height - 2
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
            }
            ([ConsoleKey]::PageDown) {
                $pageSize = $this.Height - 2
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $pageSize)
            }
            default {
                $handled = $false
            }
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }

    [void] EnsureVisible([int]$index) {
        if ($index -lt 0 -or $index -ge $this.Items.Count) { return }
        
        $visibleHeight = $this.Height - 2
        
        if ($index -lt $this.ScrollOffset) {
            $this.ScrollOffset = $index
        }
        elseif ($index -ge $this.ScrollOffset + $visibleHeight) {
            $this.ScrollOffset = $index - $visibleHeight + 1
        }
    }
}

#<!-- END_PAGE: ACO.014 -->

#<!-- PAGE: ACO.015 - TextBox Class -->
# ===== CLASS: TextBox =====
# Module: tui-components (wrapper)
# Dependencies: TextBoxComponent
# Purpose: Enhanced wrapper around TextBoxComponent

class TextBox : UIElement {
    hidden [TextBoxComponent]$_textBox

    TextBox([string]$name) : base($name) {
        $this._textBox = [TextBoxComponent]::new($name + "_inner")
        # CRITICAL FIX: Immediately size the inner component to match the wrapper's current size.
        $this._textBox.Resize($this.Width, $this.Height)
        $this.AddChild($this._textBox)
        $this.IsFocusable = $true
    }

    [string] GetText() { return $this._textBox.Text }
    [void] SetText([string]$value) { $this._textBox.Text = $value }
    
    [void] Clear() {
        $this._textBox.Text = ""
        $this._textBox.CursorPosition = 0
        $this._textBox.RequestRedraw()
    }

    [void] Focus() {
        $focusManager = $global:TuiState.Services.FocusManager
        if ($focusManager) {
            $focusManager.SetFocus($this)
        }
    }

    [void] OnFocus() {
        ([UIElement]$this).OnFocus()
        if ($this._textBox) {
            $this._textBox.IsFocused = $true
            $this._textBox.OnFocus()
            $this._textBox.RequestRedraw()
        }
    }

    [void] OnBlur() {
        ([UIElement]$this).OnBlur()
        if ($this._textBox) {
            $this._textBox.IsFocused = $false
            $this._textBox.OnBlur()
            $this._textBox.RequestRedraw()
        }
    }

    [void] OnResize() {
        if ($this._textBox) {
            $this._textBox.Width = $this.Width
            $this._textBox.Height = $this.Height
            $this._textBox.X = 0
            $this._textBox.Y = 0
            # Ensure the inner component's buffer is also resized.
            $this._textBox.Resize($this.Width, $this.Height)
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $this._textBox.HandleInput($key)
    }
}

#<!-- END_PAGE: ACO.015 -->