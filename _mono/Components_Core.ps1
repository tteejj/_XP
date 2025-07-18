# ==============================================================================
# Axiom-Phoenix v4.0 - Core UI Components
# Basic UI components that extend UIElement - full implementations from axiom
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ACO.###" to find specific sections.
# Each section ends with "END_PAGE: ACO.###"
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

#region Advanced Components

#<!-- END_PAGE: ACO.005 -->

#<!-- PAGE: ACO.006 - MultilineTextBoxComponent Class -->
# ===== CLASS: MultilineTextBoxComponent =====
# Module: advanced-input-components
# Dependencies: UIElement, TuiCell
# Purpose: Full text editor with scrolling
class MultilineTextBoxComponent : UIElement {
    [List[string]]$Lines
    [int]$CursorLine = 0
    [int]$CursorColumn = 0
    [int]$ScrollOffsetY = 0
    [int]$ScrollOffsetX = 0
    [bool]$ReadOnly = $false
    [scriptblock]$OnChange
    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$BorderColor = "#808080"
    
    MultilineTextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Lines = [List[string]]::new()
        $this.Lines.Add("")
        $this.Width = 40
        $this.Height = 10
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor -ColorName "input.background" -DefaultColor $this.BackgroundColor
            $fgColor = Get-ThemeColor -ColorName "input.foreground" -DefaultColor $this.ForegroundColor
            $borderColorValue = if ($this.IsFocused) { Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF" } else { Get-ThemeColor -ColorName "component.border" -DefaultColor $this.BorderColor }
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            
            # Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                -Width $this.Width -Height $this.Height `
                -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = "Single" }
            
            # Calculate visible area
            $contentWidth = $this.Width - 2
            $contentHeight = $this.Height - 2
            
            # Adjust scroll to keep cursor visible
            if ($this.CursorLine -lt $this.ScrollOffsetY) {
                $this.ScrollOffsetY = $this.CursorLine
            }
            elseif ($this.CursorLine -ge $this.ScrollOffsetY + $contentHeight) {
                $this.ScrollOffsetY = $this.CursorLine - $contentHeight + 1
            }
            
            if ($this.CursorColumn -lt $this.ScrollOffsetX) {
                $this.ScrollOffsetX = $this.CursorColumn
            }
            elseif ($this.CursorColumn -ge $this.ScrollOffsetX + $contentWidth) {
                $this.ScrollOffsetX = $this.CursorColumn - $contentWidth + 1
            }
            
            # Draw visible lines
            for ($y = 0; $y -lt $contentHeight; $y++) {
                $lineIndex = $y + $this.ScrollOffsetY
                if ($lineIndex -lt $this.Lines.Count) {
                    $line = $this.Lines[$lineIndex]
                    $visiblePart = ""
                    
                    if ($line.Length -gt $this.ScrollOffsetX) {
                        $endPos = [Math]::Min($this.ScrollOffsetX + $contentWidth, $line.Length)
                        $visiblePart = $line.Substring($this.ScrollOffsetX, $endPos - $this.ScrollOffsetX)
                    }
                    
                    if ($visiblePart) {
                        Write-TuiText -Buffer $this._private_buffer -X 1 -Y ($y + 1) -Text $visiblePart -Style @{ FG = $fgColor; BG = $bgColor }
                    }
                }
            }
            
            # Draw cursor if focused
            if ($this.IsFocused -and -not $this.ReadOnly) {
                $cursorScreenY = $this.CursorLine - $this.ScrollOffsetY + 1
                $cursorScreenX = $this.CursorColumn - $this.ScrollOffsetX + 1
                
                if ($cursorScreenY -ge 1 -and $cursorScreenY -lt $this.Height - 1 -and
                    $cursorScreenX -ge 1 -and $cursorScreenX -lt $this.Width - 1) {
                    
                    $currentLine = $this.Lines[$this.CursorLine]
                    $cursorChar = ' '
                    if ($this.CursorColumn -lt $currentLine.Length) {
                        $cursorChar = $currentLine[$this.CursorColumn]
                    }
                    
                    $this._private_buffer.SetCell($cursorScreenX, $cursorScreenY,
                        [TuiCell]::new($cursorChar, $bgColor, $fgColor))
                }
            }
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or $this.ReadOnly) { return $false }
        
        $handled = $true
        $changed = $false
        
        switch ($key.Key) {
            ([ConsoleKey]::LeftArrow) {
                if ($this.CursorColumn -gt 0) {
                    $this.CursorColumn--
                }
                elseif ($this.CursorLine -gt 0) {
                    $this.CursorLine--
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
            }
            ([ConsoleKey]::RightArrow) {
                $currentLine = $this.Lines[$this.CursorLine]
                if ($this.CursorColumn -lt $currentLine.Length) {
                    $this.CursorColumn++
                }
                elseif ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $this.CursorLine++
                    $this.CursorColumn = 0
                }
            }
            ([ConsoleKey]::UpArrow) {
                if ($this.CursorLine -gt 0) {
                    $this.CursorLine--
                    $newLineLength = $this.Lines[$this.CursorLine].Length
                    if ($this.CursorColumn -gt $newLineLength) {
                        $this.CursorColumn = $newLineLength
                    }
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $this.CursorLine++
                    $newLineLength = $this.Lines[$this.CursorLine].Length
                    if ($this.CursorColumn -gt $newLineLength) {
                        $this.CursorColumn = $newLineLength
                    }
                }
            }
            ([ConsoleKey]::Home) {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    $this.CursorLine = 0
                    $this.CursorColumn = 0
                }
                else {
                    $this.CursorColumn = 0
                }
            }
            ([ConsoleKey]::End) {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    $this.CursorLine = $this.Lines.Count - 1
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
                else {
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
            }
            ([ConsoleKey]::Enter) {
                $currentLine = $this.Lines[$this.CursorLine]
                $beforeCursor = $currentLine.Substring(0, $this.CursorColumn)
                $afterCursor = $currentLine.Substring($this.CursorColumn)
                
                $this.Lines[$this.CursorLine] = $beforeCursor
                $this.Lines.Insert($this.CursorLine + 1, $afterCursor)
                
                $this.CursorLine++
                $this.CursorColumn = 0
                $changed = $true
            }
            ([ConsoleKey]::Backspace) {
                if ($this.CursorColumn -gt 0) {
                    $currentLine = $this.Lines[$this.CursorLine]
                    $this.Lines[$this.CursorLine] = $currentLine.Remove($this.CursorColumn - 1, 1)
                    $this.CursorColumn--
                    $changed = $true
                }
                elseif ($this.CursorLine -gt 0) {
                    $currentLine = $this.Lines[$this.CursorLine]
                    $previousLine = $this.Lines[$this.CursorLine - 1]
                    $this.CursorColumn = $previousLine.Length
                    $this.Lines[$this.CursorLine - 1] = $previousLine + $currentLine
                    $this.Lines.RemoveAt($this.CursorLine)
                    $this.CursorLine--
                    $changed = $true
                }
            }
            ([ConsoleKey]::Delete) {
                $currentLine = $this.Lines[$this.CursorLine]
                if ($this.CursorColumn -lt $currentLine.Length) {
                    $this.Lines[$this.CursorLine] = $currentLine.Remove($this.CursorColumn, 1)
                    $changed = $true
                }
                elseif ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $nextLine = $this.Lines[$this.CursorLine + 1]
                    $this.Lines[$this.CursorLine] = $currentLine + $nextLine
                    $this.Lines.RemoveAt($this.CursorLine + 1)
                    $changed = $true
                }
            }
            default {
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    $currentLine = $this.Lines[$this.CursorLine]
                    $this.Lines[$this.CursorLine] = $currentLine.Insert($this.CursorColumn, $key.KeyChar)
                    $this.CursorColumn++
                    $changed = $true
                }
                else {
                    $handled = $false
                }
            }
        }
        
        if ($handled) {
            if ($changed -and $this.OnChange) {
                try { & $this.OnChange $this $this.GetText() } catch {}
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    [string] GetText() {
        return ($this.Lines -join "`n")
    }
    
    [void] SetText([string]$text) {
        $this.Lines.Clear()
        $splitLines = $text -split "`n"
        foreach ($line in $splitLines) {
            $this.Lines.Add($line)
        }
        if ($this.Lines.Count -eq 0) {
            $this.Lines.Add("")
        }
        $this.CursorLine = 0
        $this.CursorColumn = 0
        $this.ScrollOffsetY = 0
        $this.ScrollOffsetX = 0
        $this.RequestRedraw()
    }
}

#<!-- END_PAGE: ACO.006 -->

#<!-- PAGE: ACO.007 - NumericInputComponent Class -->
# ===== CLASS: NumericInputComponent =====
# Module: advanced-input-components
# Dependencies: UIElement, TuiCell
# Purpose: Numeric input with spinners and validation
class NumericInputComponent : UIElement {
    [double]$Value = 0
    [double]$Minimum = [double]::MinValue
    [double]$Maximum = [double]::MaxValue
    [double]$Step = 1
    [int]$DecimalPlaces = 0
    [scriptblock]$OnChange
    hidden [string]$_textValue = "0"
    hidden [int]$_cursorPosition = 1
    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$BorderColor = "#808080"
    
    NumericInputComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 15
        $this.Height = 3
        $this._textValue = $this.FormatValue($this.Value)
        $this._cursorPosition = $this._textValue.Length
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor -ColorName "input.background" -DefaultColor $this.BackgroundColor
            $fgColor = Get-ThemeColor -ColorName "input.foreground" -DefaultColor $this.ForegroundColor
            $borderColorValue = if ($this.IsFocused) { Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF" } else { Get-ThemeColor -ColorName "component.border" -DefaultColor $this.BorderColor }
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            
            # Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                -Width $this.Width -Height $this.Height `
                -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = "Single" }
            
            # Draw spinners
            $spinnerColor = if ($this.IsFocused) { "#FFFF00" } else { "#808080" }
            $this._private_buffer.SetCell($this.Width - 2, 1, [TuiCell]::new('▲', $spinnerColor, $bgColor))
            $this._private_buffer.SetCell($this.Width - 2, $this.Height - 2, [TuiCell]::new('▼', $spinnerColor, $bgColor))
            
            # Draw value
            $displayValue = $this._textValue
            $maxTextWidth = $this.Width - 4  # Border + spinner
            if ($displayValue.Length -gt $maxTextWidth) {
                $displayValue = $displayValue.Substring(0, $maxTextWidth)
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $displayValue -Style @{ FG = $fgColor; BG = $bgColor }
            
            # Draw cursor if focused
            if ($this.IsFocused -and $this._cursorPosition -le $displayValue.Length) {
                $cursorX = 1 + $this._cursorPosition
                if ($cursorX -lt $this.Width - 2) {
                    if ($this._cursorPosition -lt $this._textValue.Length) {
                        $cursorChar = $this._textValue[$this._cursorPosition]
                    } else { 
                        $cursorChar = ' ' 
                    }
                    
                    $this._private_buffer.SetCell($cursorX, 1, 
                        [TuiCell]::new($cursorChar, $bgColor, $fgColor))
                }
            }
        }
        catch {}
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $handled = $true
        $oldValue = $this.Value
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                $this.IncrementValue()
            }
            ([ConsoleKey]::DownArrow) {
                $this.DecrementValue()
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this._cursorPosition -gt 0) {
                    $this._cursorPosition--
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($this._cursorPosition -lt $this._textValue.Length) {
                    $this._cursorPosition++
                }
            }
            ([ConsoleKey]::Home) {
                $this._cursorPosition = 0
            }
            ([ConsoleKey]::End) {
                $this._cursorPosition = $this._textValue.Length
            }
            ([ConsoleKey]::Backspace) {
                if ($this._cursorPosition -gt 0) {
                    $this._textValue = $this._textValue.Remove($this._cursorPosition - 1, 1)
                    $this._cursorPosition--
                    $this.ParseAndValidate()
                }
            }
            ([ConsoleKey]::Delete) {
                if ($this._cursorPosition -lt $this._textValue.Length) {
                    $this._textValue = $this._textValue.Remove($this._cursorPosition, 1)
                    $this.ParseAndValidate()
                }
            }
            ([ConsoleKey]::Enter) {
                $this.ParseAndValidate()
            }
            default {
                if ($key.KeyChar -and ($key.KeyChar -match '[0-9.\-]')) {
                    # Allow only valid numeric characters
                    if ($key.KeyChar -eq '.' -and $this._textValue.Contains('.')) {
                        # Only one decimal point allowed
                        $handled = $false
                    }
                    elseif ($key.KeyChar -eq '-' -and ($this._cursorPosition -ne 0 -or $this._textValue.Contains('-'))) {
                        # Minus only at beginning
                        $handled = $false
                    }
                    else {
                        $this._textValue = $this._textValue.Insert($this._cursorPosition, $key.KeyChar)
                        $this._cursorPosition++
                        $this.ParseAndValidate()
                    }
                }
                else {
                    $handled = $false
                }
            }
        }
        
        if ($handled) {
            if ($oldValue -ne $this.Value -and $this.OnChange) {
                try { & $this.OnChange $this $this.Value } catch {}
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    hidden [void] IncrementValue() {
        $newValue = $this.Value + $this.Step
        if ($newValue -le $this.Maximum) {
            $this.Value = $newValue
            $this._textValue = $this.FormatValue($this.Value)
            $this._cursorPosition = $this._textValue.Length
        }
    }
    
    hidden [void] DecrementValue() {
        $newValue = $this.Value - $this.Step
        if ($newValue -ge $this.Minimum) {
            $this.Value = $newValue
            $this._textValue = $this.FormatValue($this.Value)
            $this._cursorPosition = $this._textValue.Length
        }
    }
    
    hidden [void] ParseAndValidate() {
        try {
            $parsedValue = [double]::Parse($this._textValue)
            $parsedValue = [Math]::Max($this.Minimum, [Math]::Min($this.Maximum, $parsedValue))
            $this.Value = $parsedValue
        }
        catch {
            # Keep current value if parse fails
        }
    }
    
    hidden [string] FormatValue([double]$value) {
        if ($this.DecimalPlaces -eq 0) {
            return [Math]::Truncate($value).ToString()
        }
        else {
            return $value.ToString("F$($this.DecimalPlaces)")
        }
    }
}

#<!-- END_PAGE: ACO.007 -->

#<!-- PAGE: ACO.008 - DateInputComponent Class -->
# ===== CLASS: DateInputComponent =====
# Module: advanced-input-components
# Dependencies: UIElement, TuiCell
# Purpose: Date picker with calendar interface
class DateInputComponent : UIElement {
    [DateTime]$Value = [DateTime]::Today
    [DateTime]$MinDate = [DateTime]::MinValue
    [DateTime]$MaxDate = [DateTime]::MaxValue
    [scriptblock]$OnChange
    hidden [bool]$_showCalendar = $false
    hidden [DateTime]$_viewMonth
    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$BorderColor = "#808080"
    
    DateInputComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 25
        $this.Height = 1  # Expands to 10 when calendar shown
        $this._viewMonth = $this.Value
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor -ColorName "input.background" -DefaultColor $this.BackgroundColor
            $fgColor = Get-ThemeColor -ColorName "input.foreground" -DefaultColor $this.ForegroundColor
            if ($this.IsFocused) { 
                $borderColorValue = Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF" 
            } else { 
                $borderColorValue = Get-ThemeColor -ColorName "component.border" -DefaultColor $this.BorderColor 
            }
            
            # Adjust height based on calendar visibility
            if ($this._showCalendar) { 
                $renderHeight = 10 
            } else { 
                $renderHeight = 3 
            }
            if ($this.Height -ne $renderHeight) {
                $this.Height = $renderHeight
                $this.RequestRedraw()
                return
            }
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            
            # Draw text box
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                -Width $this.Width -Height 3 `
                -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = "Single" }
            
            # Draw date value
            $dateStr = $this.Value.ToString("yyyy-MM-dd")
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $dateStr -Style @{ FG = $fgColor; BG = $bgColor }
            
            # Draw calendar icon
            $this._private_buffer.SetCell($this.Width - 2, 1, [TuiCell]::new('📅', $borderColorValue, $bgColor))
            
            # Draw calendar if shown
            if ($this._showCalendar) {
                $this.DrawCalendar(0, 3)
            }
        }
        catch {}
    }
    
    hidden [void] DrawCalendar([int]$startX, [int]$startY) {
        $bgColor = "#000000"
        $fgColor = "#FFFFFF"
        $headerColor = "#FFFF00"
        $selectedColor = "#00FFFF"
        $todayColor = "#00FF00"
        
        # Calendar border
        Write-TuiBox -Buffer $this._private_buffer -X $startX -Y $startY `
            -Width $this.Width -Height 7 `
            -Style @{ BorderFG = "#808080"; BG = $bgColor; BorderStyle = "Single" }
        
        # Month/Year header
        $monthYearStr = $this._viewMonth.ToString("MMMM yyyy")
        $headerX = $startX + [Math]::Floor(($this.Width - $monthYearStr.Length) / 2)
        Write-TuiText -Buffer $this._private_buffer -X $headerX -Y ($startY + 1) -Text $monthYearStr -Style @{ FG = $headerColor; BG = $bgColor }
        
        # Navigation arrows
        $this._private_buffer.SetCell($startX + 1, $startY + 1, [TuiCell]::new('<', $headerColor, $bgColor))
        $this._private_buffer.SetCell($startX + $this.Width - 2, $startY + 1, [TuiCell]::new('>', $headerColor, $bgColor))
        
        # Day headers
        $dayHeaders = @("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
        $dayX = $startX + 2
        foreach ($day in $dayHeaders) {
            Write-TuiText -Buffer $this._private_buffer -X $dayX -Y ($startY + 2) -Text $day -Style @{ FG = "#808080"; BG = $bgColor }
            $dayX += 3
        }
        
        # Calendar days
        $firstDay = [DateTime]::new($this._viewMonth.Year, $this._viewMonth.Month, 1)
        $startDayOfWeek = [int]$firstDay.DayOfWeek
        $daysInMonth = [DateTime]::DaysInMonth($this._viewMonth.Year, $this._viewMonth.Month)
        
        $currentDay = 1
        $today = [DateTime]::Today
        
        for ($week = 0; $week -lt 6; $week++) {
            if ($currentDay -gt $daysInMonth) { break }
            
            for ($dayOfWeek = 0; $dayOfWeek -lt 7; $dayOfWeek++) {
                if ($week -eq 0 -and $dayOfWeek -lt $startDayOfWeek) { continue }
                if ($currentDay -gt $daysInMonth) { break }
                
                $dayX = $startX + 2 + ($dayOfWeek * 3)
                $dayY = $startY + 3 + $week
                
                $currentDate = [DateTime]::new($this._viewMonth.Year, $this._viewMonth.Month, $currentDay)
                $dayStr = $currentDay.ToString().PadLeft(2)
                
                # Determine color
                $dayColor = $fgColor
                if ($currentDate -eq $this.Value) {
                    $dayColor = $selectedColor
                }
                elseif ($currentDate -eq $today) {
                    $dayColor = $todayColor
                }
                
                Write-TuiText -Buffer $this._private_buffer -X $dayX -Y $dayY -Text $dayStr -Style @{ FG = $dayColor; BG = $bgColor }
                $currentDay++
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $handled = $true
        $oldValue = $this.Value
        
        if (-not $this._showCalendar) {
            switch ($key.Key) {
                ([ConsoleKey]::Enter) { $this._showCalendar = $true }
                ([ConsoleKey]::Spacebar) { $this._showCalendar = $true }
                ([ConsoleKey]::DownArrow) { $this._showCalendar = $true }
                default { $handled = $false }
            }
        }
        else {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) { 
                    $this._showCalendar = $false 
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                        # Previous month
                        $this._viewMonth = $this._viewMonth.AddMonths(-1)
                    }
                    else {
                        # Previous day
                        $newDate = $this.Value.AddDays(-1)
                        if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                            $this.Value = $newDate
                            $this._viewMonth = $newDate
                        }
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                        # Next month
                        $this._viewMonth = $this._viewMonth.AddMonths(1)
                    }
                    else {
                        # Next day
                        $newDate = $this.Value.AddDays(1)
                        if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                            $this.Value = $newDate
                            $this._viewMonth = $newDate
                        }
                    }
                }
                ([ConsoleKey]::UpArrow) {
                    # Previous week
                    $newDate = $this.Value.AddDays(-7)
                    if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                        $this.Value = $newDate
                        $this._viewMonth = $newDate
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    # Next week
                    $newDate = $this.Value.AddDays(7)
                    if ($newDate -ge $this.MinDate -and $newDate -le $this.MaxDate) {
                        $this.Value = $newDate
                        $this._viewMonth = $newDate
                    }
                }
                ([ConsoleKey]::Enter) {
                    $this._showCalendar = $false
                }
                ([ConsoleKey]::T) {
                    # Today
                    $today = [DateTime]::Today
                    if ($today -ge $this.MinDate -and $today -le $this.MaxDate) {
                        $this.Value = $today
                        $this._viewMonth = $today
                    }
                }
                default { $handled = $false }
            }
        }
        
        if ($handled) {
            if ($oldValue -ne $this.Value -and $this.OnChange) {
                try { & $this.OnChange $this $this.Value } catch {}
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
}

#<!-- END_PAGE: ACO.008 -->

#<!-- PAGE: ACO.009 - ComboBoxComponent Class -->
# ===== CLASS: ComboBoxComponent =====
# Module: advanced-input-components
# Dependencies: UIElement, TuiCell
# Purpose: Dropdown with search and overlay rendering
class ComboBoxComponent : UIElement {
    [List[object]]$Items
    [int]$SelectedIndex = -1
    [string]$DisplayMember = ""
    [string]$ValueMember = ""
    [bool]$IsEditable = $false
    [string]$Text = ""
    [scriptblock]$OnSelectionChanged
    hidden [bool]$_isDropdownOpen = $false
    hidden [int]$_highlightedIndex = -1
    hidden [string]$_searchText = ""
    hidden [List[int]]$_filteredIndices
    
    ComboBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 25
        $this.Height = 3
        $this.Items = [List[object]]::new()
        $this._filteredIndices = [List[int]]::new()
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor("input.background")
            $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            
            # Draw main box
            if ($this.IsFocused) { 
                $borderColor = Get-ThemeColor("Primary") 
            } else { 
                $borderColor = Get-ThemeColor("component.border") 
            }
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -Style @{ BorderFG = $borderColor; BG = $bgColor; BorderStyle = "Single" }
            
            # Draw selected text or placeholder
            $displayText = ""
            if ($this.IsEditable) {
                $displayText = $this._searchText
            }
            elseif ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
                $item = $this.Items[$this.SelectedIndex]
                $displayText = $this.GetDisplayText($item)
            }
            
            if ($displayText) { 
                $textColor = Get-ThemeColor("input.foreground") 
            } else { 
                $textColor = Get-ThemeColor("input.placeholder") 
            }
            
            $maxTextWidth = $this.Width - 4  # Border + dropdown arrow
            if ($displayText.Length -gt $maxTextWidth) {
                $displayText = $displayText.Substring(0, $maxTextWidth)
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $displayText `
                -Style @{ FG = $textColor; BG = $bgColor }
            
            # Draw dropdown arrow
            if ($this._isDropdownOpen) { 
                $arrowChar = '▲' 
            } else { 
                $arrowChar = '▼' 
            }
            if ($this.IsFocused) { 
                $arrowColor = Get-ThemeColor("Accent") 
            } else { 
                $arrowColor = Get-ThemeColor("Subtle") 
            }
            $this._private_buffer.SetCell($this.Width - 2, 1, [TuiCell]::new($arrowChar, $arrowColor, $bgColor))
            
            # Draw dropdown if open (as overlay)
            if ($this._isDropdownOpen) {
                $this.IsOverlay = $true
                $this.DrawDropdown()
            }
            else {
                $this.IsOverlay = $false
            }
        }
        catch {}
    }
    
    hidden [void] DrawDropdown() {
        $dropdownY = $this.Height
        $maxDropdownHeight = 10
        $dropdownHeight = [Math]::Min($this._filteredIndices.Count + 2, $maxDropdownHeight)
        
        if ($dropdownHeight -lt 3) { $dropdownHeight = 3 }  # Minimum height
        
        # Create dropdown buffer
        $dropdownBuffer = [TuiBuffer]::new($this.Width, $dropdownHeight)
        $dropdownBuffer.Name = "ComboDropdown"
        
        # Draw dropdown border
        Write-TuiBox -Buffer $dropdownBuffer -X 0 -Y 0 `
            -Width $this.Width -Height $dropdownHeight `
            -Style @{ BorderFG = Get-ThemeColor("component.border"); BG = Get-ThemeColor("input.background"); BorderStyle = "Single" }
        
        # Draw items
        $itemY = 1
        $maxItems = $dropdownHeight - 2
        $scrollOffset = 0
        
        if ($this._highlightedIndex -ge $maxItems) {
            $scrollOffset = $this._highlightedIndex - $maxItems + 1
        }
        
        for ($i = $scrollOffset; $i -lt $this._filteredIndices.Count -and $itemY -lt $dropdownHeight - 1; $i++) {
            $itemIndex = $this._filteredIndices[$i]
            $item = $this.Items[$itemIndex]
            $itemText = $this.GetDisplayText($item)
            
            $itemFg = Get-ThemeColor("list.item.normal")
            $itemBg = Get-ThemeColor("input.background")
            
            if ($i -eq $this._highlightedIndex) {
                $itemFg = Get-ThemeColor("list.item.selected")
                $itemBg = Get-ThemeColor("list.item.selected.background")
            }
            elseif ($itemIndex -eq $this.SelectedIndex) {
                $itemFg = Get-ThemeColor("Accent")
            }
            
            # Clear line and draw item
            for ($x = 1; $x -lt $this.Width - 1; $x++) {
                $dropdownBuffer.SetCell($x, $itemY, [TuiCell]::new(' ', $itemFg, $itemBg))
            }
            
            $maxTextWidth = $this.Width - 2
            if ($itemText.Length -gt $maxTextWidth) {
                $itemText = $itemText.Substring(0, $maxTextWidth - 3) + "..."
            }
            
            Write-TuiText -Buffer $dropdownBuffer -X 1 -Y $itemY -Text $itemText -Style @{ FG = $itemFg; BG = $itemBg }
            $itemY++
        }
        
        # Blend dropdown buffer with main buffer at dropdown position
        $absPos = $this.GetAbsolutePosition()
        $dropX = 0
        $dropY = $dropdownY
        
        for ($y = 0; $y -lt $dropdownBuffer.Height; $y++) {
            for ($x = 0; $x -lt $dropdownBuffer.Width; $x++) {
                $cell = $dropdownBuffer.GetCell($x, $y)
                if ($cell) {
                    $this._private_buffer.SetCell($dropX + $x, $dropY + $y, $cell)
                }
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $handled = $true
        
        if (-not $this._isDropdownOpen) {
            switch ($key.Key) {
                ([ConsoleKey]::Enter) { 
                    $this.OpenDropdown()
                }
                ([ConsoleKey]::Spacebar) {
                    if (-not $this.IsEditable) {
                        $this.OpenDropdown()
                    }
                    else {
                        $handled = $false
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    $this.OpenDropdown()
                }
                default {
                    if ($this.IsEditable -and $key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                        $this._searchText += $key.KeyChar
                        $this.OpenDropdown()
                        $this.FilterItems()
                    }
                    else {
                        $handled = $false
                    }
                }
            }
        }
        else {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this.CloseDropdown()
                }
                ([ConsoleKey]::Enter) {
                    if ($this._highlightedIndex -ge 0 -and $this._highlightedIndex -lt $this._filteredIndices.Count) {
                        $this.SelectItem($this._filteredIndices[$this._highlightedIndex])
                        $this.CloseDropdown()
                    }
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this._highlightedIndex -gt 0) {
                        $this._highlightedIndex--
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this._highlightedIndex -lt $this._filteredIndices.Count - 1) {
                        $this._highlightedIndex++
                    }
                }
                ([ConsoleKey]::Home) {
                    $this._highlightedIndex = 0
                }
                ([ConsoleKey]::End) {
                    $this._highlightedIndex = $this._filteredIndices.Count - 1
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.IsEditable -and $this._searchText.Length -gt 0) {
                        $this._searchText = $this._searchText.Substring(0, $this._searchText.Length - 1)
                        $this.FilterItems()
                    }
                }
                default {
                    if ($this.IsEditable -and $key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                        $this._searchText += $key.KeyChar
                        $this.FilterItems()
                    }
                    else {
                        $handled = $false
                    }
                }
            }
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    hidden [void] OpenDropdown() {
        $this._isDropdownOpen = $true
        $this.FilterItems()
        
        # Set highlighted index to selected item
        if ($this.SelectedIndex -ge 0) {
            for ($i = 0; $i -lt $this._filteredIndices.Count; $i++) {
                if ($this._filteredIndices[$i] -eq $this.SelectedIndex) {
                    $this._highlightedIndex = $i
                    break
                }
            }
        }
        
        if ($this._highlightedIndex -eq -1 -and $this._filteredIndices.Count -gt 0) {
            $this._highlightedIndex = 0
        }
    }
    
    hidden [void] CloseDropdown() {
        $this._isDropdownOpen = $false
        $this.IsOverlay = $false
        if (-not $this.IsEditable) {
            $this._searchText = ""
        }
    }
    
    hidden [void] FilterItems() {
        $this._filteredIndices.Clear()
        
        if ($this._searchText -eq "") {
            # Show all items
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                $this._filteredIndices.Add($i)
            }
        }
        else {
            # Filter items based on search text
            $searchLower = $this._searchText.ToLower()
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                $itemText = $this.GetDisplayText($this.Items[$i]).ToLower()
                if ($itemText.Contains($searchLower)) {
                    $this._filteredIndices.Add($i)
                }
            }
        }
        
        # Reset highlighted index
        if ($this._highlightedIndex -ge $this._filteredIndices.Count) {
            $this._highlightedIndex = $this._filteredIndices.Count - 1
        }
        if ($this._highlightedIndex -lt 0 -and $this._filteredIndices.Count -gt 0) {
            $this._highlightedIndex = 0
        }
    }
    
    hidden [void] SelectItem([int]$index) {
        $oldIndex = $this.SelectedIndex
        $this.SelectedIndex = $index
        
        if (-not $this.IsEditable) {
            $this.Text = $this.GetDisplayText($this.Items[$index])
        }
        
        if ($oldIndex -ne $index -and $this.OnSelectionChanged) {
            try { & $this.OnSelectionChanged $this $index } catch {}
        }
    }
    
    hidden [string] GetDisplayText([object]$item) {
        if ($null -eq $item) { return "" }
        
        if ($this.DisplayMember -and $item.PSObject.Properties[$this.DisplayMember]) {
            return $item.$($this.DisplayMember).ToString()
        }
        
        return $item.ToString()
    }
}

#<!-- END_PAGE: ACO.009 -->

#<!-- PAGE: ACO.010 - Table Class -->
# ===== CLASS: Table =====
# Module: advanced-data-components
# Dependencies: UIElement, TuiCell
# Purpose: High-performance data grid with virtual scrolling
class Table : UIElement {
    [List[PSObject]]$Items
    [List[string]]$Columns
    [hashtable]$ColumnWidths
    [int]$SelectedIndex = -1
    [bool]$ShowHeader = $true
    [bool]$ShowBorder = $true
    [bool]$AllowSelection = $true
    [scriptblock]$OnSelectionChanged
    hidden [int]$_scrollOffset = 0
    hidden [int]$_horizontalScroll = 0
    
    Table([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Items = [List[PSObject]]::new()
        $this.Columns = [List[string]]::new()
        $this.ColumnWidths = @{}
        $this.Width = 80
        $this.Height = 20
    }
    
    [void] SetColumns([string[]]$columns) {
        $this.Columns.Clear()
        foreach ($col in $columns) {
            $this.Columns.Add($col)
            if (-not $this.ColumnWidths.ContainsKey($col)) {
                $this.ColumnWidths[$col] = 15  # Default width
            }
        }
    }
    
    [void] AutoSizeColumns() {
        foreach ($col in $this.Columns) {
            $maxWidth = $col.Length
            
            foreach ($item in $this.Items) {
                if ($item.PSObject.Properties[$col]) {
                    $val = $item.$col
                    if ($null -ne $val) {
                        $len = $val.ToString().Length
                        if ($len -gt $maxWidth) {
                            $maxWidth = $len
                        }
                    }
                }
            }
            
            $this.ColumnWidths[$col] = [Math]::Min($maxWidth + 2, 30)  # Cap at 30
        }
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor("component.background")
            $fgColor = Get-ThemeColor("Foreground")
            if ($this.IsFocused) { 
                $borderColor = Get-ThemeColor("Primary") 
            } else { 
                $borderColor = Get-ThemeColor("component.border") 
            }
            $headerBg = Get-ThemeColor("list.header.bg")
            $selectedBg = Get-ThemeColor("list.item.selected.background")
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            
            $contentX = 0
            $contentY = 0
            $contentWidth = $this.Width
            $contentHeight = $this.Height
            
            # Draw border if enabled
            if ($this.ShowBorder) {
                Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                    -Width $this.Width -Height $this.Height `
                    -Style @{ BorderFG = $borderColor; BG = $bgColor; BorderStyle = "Single" }
                
                $contentX = 1
                $contentY = 1
                $contentWidth = $this.Width - 2
                $contentHeight = $this.Height - 2
            }
            
            $currentY = $contentY
            $dataStartY = $contentY
            
            # Draw header if enabled
            if ($this.ShowHeader -and $this.Columns.Count -gt 0) {
                $this.DrawHeader($contentX, $currentY, $contentWidth, $headerBg)
                $currentY++
                $dataStartY++
                
                # Draw separator line
                for ($x = $contentX; $x -lt $contentX + $contentWidth; $x++) {
                    $this._private_buffer.SetCell($x, $currentY, [TuiCell]::new('-', $borderColor, $bgColor))
                }
                $currentY++
                $dataStartY++
            }
            
            # Calculate visible rows
            $visibleRows = $contentHeight - ($dataStartY - $contentY)
            if ($visibleRows -le 0) { return }
            
            # Adjust scroll offset to keep selection visible
            if ($this.AllowSelection -and $this.SelectedIndex -ge 0) {
                if ($this.SelectedIndex -lt $this._scrollOffset) {
                    $this._scrollOffset = $this.SelectedIndex
                }
                elseif ($this.SelectedIndex -ge $this._scrollOffset + $visibleRows) {
                    $this._scrollOffset = $this.SelectedIndex - $visibleRows + 1
                }
            }
            
            # Draw data rows
            for ($i = 0; $i -lt $visibleRows; $i++) {
                $itemIndex = $i + $this._scrollOffset
                if ($itemIndex -ge $this.Items.Count) { break }
                
                $item = $this.Items[$itemIndex]
                $rowBg = $bgColor
                $rowFg = $fgColor
                
                if ($this.AllowSelection -and $itemIndex -eq $this.SelectedIndex) {
                    $rowBg = $selectedBg
                    $rowFg = Get-ThemeColor("list.item.selected")
                }
                
                $this.DrawRow($item, $contentX, $currentY, $contentWidth, $rowFg, $rowBg)
                $currentY++
            }
            
            # Draw scrollbar if needed
            if ($this.Items.Count -gt $visibleRows) {
                $this.DrawScrollbar($contentX + $contentWidth - 1, $dataStartY, $visibleRows)
            }
        }
        catch {}
    }
    
    hidden [void] DrawHeader([int]$x, [int]$y, [int]$maxWidth, [string]$headerBg) {
        $currentX = $x - $this._horizontalScroll
        
        foreach ($col in $this.Columns) {
            $colWidth = $this.ColumnWidths[$col]
            
            if ($currentX + $colWidth -gt $x) {
                $visibleStart = [Math]::Max(0, $x - $currentX)
                $visibleWidth = [Math]::Min($colWidth - $visibleStart, $maxWidth - ($currentX - $x))
                
                if ($visibleWidth -gt 0) {
                    $headerText = $col
                    if ($headerText.Length -gt $visibleWidth) {
                        $headerText = $headerText.Substring(0, $visibleWidth - 1) + ">"
                    }
                    else {
                        $headerText = $headerText.PadRight($visibleWidth)
                    }
                    
                    $drawX = [Math]::Max($x, $currentX)
                    Write-TuiText -Buffer $this._private_buffer -X $drawX -Y $y -Text $headerText -Style @{ FG = Get-ThemeColor("list.header.fg"); BG = $headerBg }
                }
            }
            
            $currentX += $colWidth
            if ($currentX -ge $x + $maxWidth) { break }
        }
    }
    
    hidden [void] DrawRow([PSObject]$item, [int]$x, [int]$y, [int]$maxWidth, [string]$fg, [string]$bg) {
        # Clear row first
        for ($i = 0; $i -lt $maxWidth; $i++) {
            $this._private_buffer.SetCell($x + $i, $y, [TuiCell]::new(' ', $fg, $bg))
        }
        
        $currentX = $x - $this._horizontalScroll
        
        foreach ($col in $this.Columns) {
            $colWidth = $this.ColumnWidths[$col]
            
            if ($currentX + $colWidth -gt $x) {
                $value = ""
                if ($item.PSObject.Properties[$col]) {
                    $val = $item.$col
                    if ($null -ne $val) {
                        $value = $val.ToString()
                    }
                }
                
                $visibleStart = [Math]::Max(0, $x - $currentX)
                $visibleWidth = [Math]::Min($colWidth - $visibleStart, $maxWidth - ($currentX - $x))
                
                if ($visibleWidth -gt 0) {
                    if ($value.Length -gt $visibleWidth - 1) {
                        $value = $value.Substring(0, $visibleWidth - 2) + ".."
                    }
                    
                    $drawX = [Math]::Max($x, $currentX)
                    Write-TuiText -Buffer $this._private_buffer -X $drawX -Y $y -Text $value -Style @{ FG = $fg; BG = $bg }
                }
            }
            
            $currentX += $colWidth
            if ($currentX -ge $x + $maxWidth) { break }
        }
    }
    
    hidden [void] DrawScrollbar([int]$x, [int]$y, [int]$height) {
        $scrollbarHeight = [Math]::Max(1, [int]($height * $height / $this.Items.Count))
        $scrollbarPos = [int](($height - $scrollbarHeight) * $this._scrollOffset / ($this.Items.Count - $height))
        
        $scrollbarColor = Get-ThemeColor("list.scrollbar")
        $bgColor = Get-ThemeColor("component.background")
        
        for ($i = 0; $i -lt $height; $i++) {
            $char = if ($i -ge $scrollbarPos -and $i -lt $scrollbarPos + $scrollbarHeight) { '█' } else { '│' }
            $this._private_buffer.SetCell($x, $y + $i, [TuiCell]::new($char, $scrollbarColor, $bgColor))
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or -not $this.AllowSelection) { return $false }
        
        $handled = $true
        $oldSelection = $this.SelectedIndex
        
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
                $pageSize = $this.Height - 4  # Account for border and header
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
            }
            ([ConsoleKey]::PageDown) {
                $pageSize = $this.Height - 4
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $pageSize)
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this._horizontalScroll -gt 0) {
                    $this._horizontalScroll = [Math]::Max(0, $this._horizontalScroll - 5)
                }
            }
            ([ConsoleKey]::RightArrow) {
                $totalWidth = 0
                foreach ($col in $this.Columns) {
                    $totalWidth += $this.ColumnWidths[$col]
                }
                $maxScroll = [Math]::Max(0, $totalWidth - $this.Width + 2)
                $this._horizontalScroll = [Math]::Min($maxScroll, $this._horizontalScroll + 5)
            }
            default {
                $handled = $false
            }
        }
        
        if ($handled) {
            if ($oldSelection -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
                try { & $this.OnSelectionChanged $this $this.SelectedIndex } catch {}
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
}

#endregion Advanced Components

#region Panel Components

#<!-- END_PAGE: ACO.010 -->

#<!-- PAGE: ACO.011 - Panel Class -->
# ===== CLASS: Panel =====
# Module: panels-class
# Dependencies: UIElement, TuiCell
# Purpose: Container with layout management
class Panel : UIElement {
    [string]$Title = ""
    [string]$BorderStyle = "Single"
    [string]$BorderColor = "#808080"     # FIXED: Changed from ConsoleColor to hex string
    [string]$BackgroundColor = "#000000" # FIXED: Changed from ConsoleColor to hex string
    [bool]$HasBorder = $true
    [string]$LayoutType = "Manual"  # Manual, Vertical, Horizontal, Grid
    [int]$Padding = 0
    [int]$Spacing = 1
    
    # Content area properties
    [int]$ContentX = 1
    [int]$ContentY = 1
    [int]$ContentWidth = 0
    [int]$ContentHeight = 0

    Panel([string]$name) : base($name) {
        $this.IsFocusable = $false
        # Set reasonable defaults
        if ($this.Width -eq 0) { $this.Width = 30 }
        if ($this.Height -eq 0) { $this.Height = 10 }
        # Calculate initial content dimensions
        $this.UpdateContentDimensions()
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor("component.background")
            $bgCell = [TuiCell]::new(' ', $bgColor, $bgColor)
            $this._private_buffer.Clear($bgCell)

            # Update content area dimensions
            $this.UpdateContentDimensions()

            if ($this.HasBorder) {
                if ($this.IsFocused) { 
                    $borderColorValue = Get-ThemeColor("Primary") 
                } else { 
                    $borderColorValue = Get-ThemeColor("component.border") 
                }
                
                Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                    -Width $this.Width -Height $this.Height `
                    -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = $this.BorderStyle; TitleFG = Get-ThemeColor("component.title") } `
                    -Title $this.Title
            }

            # Apply layout to children
            $this.ApplyLayout()
        }
        catch {}
    }

    [void] ApplyLayout() {
        if ($this.LayoutType -eq "Manual") { return }

        if ($this.HasBorder) { 
            $layoutX = 1 + $this.Padding 
        } else { 
            $layoutX = $this.Padding 
        }
        if ($this.HasBorder) { 
            $layoutY = 1 + $this.Padding 
        } else { 
            $layoutY = $this.Padding 
        }
        $layoutWidth = [Math]::Max(0, $this.Width - (2 * $layoutX))
        $layoutHeight = [Math]::Max(0, $this.Height - (2 * $layoutY))

        $visibleChildren = @($this.Children | Where-Object { $_.Visible })
        if ($visibleChildren.Count -eq 0) { return }

        switch ($this.LayoutType) {
            "Vertical" {
                $currentY = $layoutY
                foreach ($child in $visibleChildren) {
                    $child.X = $layoutX
                    $child.Y = $currentY
                    $child.Width = [Math]::Min($child.Width, $layoutWidth)
                    $currentY += $child.Height + $this.Spacing
                }
            }
            "Horizontal" {
                $currentX = $layoutX
                foreach ($child in $visibleChildren) {
                    $child.X = $currentX
                    $child.Y = $layoutY
                    $child.Height = [Math]::Min($child.Height, $layoutHeight)
                    $currentX += $child.Width + $this.Spacing
                }
            }
            "Grid" {
                # Simple grid layout - arrange in rows
                $cols = [Math]::Max(1, [Math]::Floor($layoutWidth / 20))  # Assume 20 char min width
                $col = 0
                $row = 0
                $cellWidth = [Math]::Max(1, [Math]::Floor($layoutWidth / $cols))
                $cellHeight = 3  # Default height
                
                foreach ($child in $visibleChildren) {
                    $child.X = $layoutX + ($col * $cellWidth)
                    $child.Y = $layoutY + ($row * ($cellHeight + $this.Spacing))
                    $child.Width = [Math]::Max(1, $cellWidth - $this.Spacing)
                    $child.Height = $cellHeight
                    
                    $col++
                    if ($col -ge $cols) {
                        $col = 0
                        $row++
                    }
                }
            }
        }
    }

    [hashtable] GetContentArea() {
        $area = @{
            X = if ($this.HasBorder) { 1 + $this.Padding } else { $this.Padding }
            Y = if ($this.HasBorder) { 1 + $this.Padding } else { $this.Padding }
        }
        $area.Width = [Math]::Max(0, $this.Width - (2 * $area.X))
        $area.Height = [Math]::Max(0, $this.Height - (2 * $area.Y))
        return $area
    }
    
    # New method to update content dimensions
    [void] UpdateContentDimensions() {
        $this.ContentX = if ($this.HasBorder) { 1 } else { 0 }
        $this.ContentY = if ($this.HasBorder) { 1 } else { 0 }
        $borderOffset = if ($this.HasBorder) { 2 } else { 0 }
        $this.ContentWidth = [Math]::Max(0, $this.Width - $borderOffset)
        $this.ContentHeight = [Math]::Max(0, $this.Height - $borderOffset)
    }
    
    # Override Resize to update content dimensions
    [void] OnResize() {
        $this.UpdateContentDimensions()
        ([UIElement]$this).OnResize()
    }
}

#<!-- END_PAGE: ACO.011 -->

#<!-- PAGE: ACO.012 - ScrollablePanel Class -->
# ===== CLASS: ScrollablePanel =====
# Module: panels-class
# Dependencies: Panel, TuiCell
# Purpose: Panel with scrolling capabilities
class ScrollablePanel : Panel {
    [int]$ScrollOffsetY = 0
    [int]$MaxScrollY = 0
    [bool]$ShowScrollbar = $true
    hidden [int]$_contentHeight = 0 # This will be the virtual content height
    hidden [TuiBuffer]$_virtual_buffer = $null # NEW: To hold the entire scrollable content

    ScrollablePanel([string]$name) : base($name) {
        $this.IsFocusable = $true
        # Initialize _virtual_buffer with initial dimensions. Will be resized later based on content.
        # Start with max possible height or a reasonable large value, will grow as children are added
        $this._virtual_buffer = [TuiBuffer]::new($this.Width, 1000, "$($this.Name).Virtual") 
    }

    # Override OnResize to ensure virtual buffer matches actual content area needs
    [void] OnResize([int]$newWidth, [int]$newHeight) {
        # Call base Panel resize, which updates Width, Height, and _private_buffer
        ([Panel]$this).Resize($newWidth, $newHeight) 

        # Ensure the virtual buffer is wide enough for the content area
        $targetVirtualWidth = $this.ContentWidth 
        if ($this._virtual_buffer.Width -ne $targetVirtualWidth) {
            $this._virtual_buffer.Resize($targetVirtualWidth, $this._virtual_buffer.Height) # Only resize width for now
        }
        $this.UpdateMaxScroll() # Recalculate max scroll on resize
        $this.RequestRedraw()
    }

    # Override _RenderContent to implement virtual scrolling logic
    hidden [void] _RenderContent() {
        # 1. First, render the base Panel. This clears its own _private_buffer and draws borders/title.
        # This implicitly calls ([Panel]$this).OnRender()
        ([Panel]$this)._RenderContent()

        # 2. Render all children onto the _virtual_buffer
        $this._virtual_buffer.Clear([TuiCell]::new(' ', $this.BackgroundColor, $this.BackgroundColor)) # Clear virtual buffer
        
        $actualContentBottom = 0
        foreach ($child in $this.Children | Sort-Object ZIndex) {
            if ($child.Visible) {
                # Render each child to its own private buffer
                $child.Render() 
                if ($null -ne $child._private_buffer) {
                    # Blend child's buffer onto our _virtual_buffer at its original coordinates
                    # (relative to the panel's content area)
                    $this._virtual_buffer.BlendBuffer($child._private_buffer, $child.X - $this.ContentX, $child.Y - $this.ContentY)
                }
                # Track the maximum vertical extent of children to determine virtual height
                $childExtent = ($child.Y - $this.ContentY) + $child.Height
                if ($childExtent -gt $actualContentBottom) {
                    $actualContentBottom = $childExtent
                }
            }
        }
        $this._contentHeight = $actualContentBottom # Update actual content height

        # 3. Update MaxScrollY and clamp ScrollOffsetY
        $this.UpdateMaxScroll()

        # 4. Extract the visible portion from _virtual_buffer and blend it onto _private_buffer
        #    This accounts for the scroll offset when drawing to screen.
        $viewportWidth = $this.ContentWidth
        $viewportHeight = $this.ContentHeight
        
        # Ensure target size for sub-buffer is positive
        $viewportWidth = [Math]::Max(1, $viewportWidth)
        $viewportHeight = [Math]::Max(1, $viewportHeight)

        $sourceX = 0 # No horizontal scrolling for now, but easily extendable
        $sourceY = $this.ScrollOffsetY
        
        # Get sub-buffer, ensure it's not trying to read beyond virtual buffer bounds
        $effectiveSourceHeight = [Math]::Min($viewportHeight, $this._virtual_buffer.Height - $sourceY)
        if ($effectiveSourceHeight -le 0) {
            # No content to display in viewport
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': No effective content for viewport."
            return
        }

        $visiblePortion = $this._virtual_buffer.GetSubBuffer($sourceX, $sourceY, $viewportWidth, $effectiveSourceHeight)
        
        # Blend the visible portion onto our own _private_buffer, at the content area
        $this._private_buffer.BlendBuffer($visiblePortion, $this.ContentX, $this.ContentY)

        # 5. Draw scrollbar if needed (uses _private_buffer and current ScrollOffsetY)
        if ($this.ShowScrollbar -and $this.MaxScrollY -gt 0) {
            $this.DrawScrollbar()
        }

        $this._needs_redraw = $false
    }

    # Helper method to calculate MaxScrollY and clamp ScrollOffsetY
    [void] UpdateMaxScroll() {
        $viewportHeight = $this.ContentHeight # Use ContentHeight as the available rendering area
        
        # Ensure virtual buffer height is at least content height
        $currentVirtualHeight = $this._virtual_buffer.Height
        $newVirtualHeight = [Math]::Max($currentVirtualHeight, $this._contentHeight)
        if ($newVirtualHeight -ne $currentVirtualHeight) {
            $this._virtual_buffer.Resize($this._virtual_buffer.Width, $newVirtualHeight)
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': Resized virtual buffer height to $newVirtualHeight."
        }

        $this.MaxScrollY = [Math]::Max(0, $this._contentHeight - $viewportHeight)
        $this.ScrollOffsetY = [Math]::Max(0, [Math]::Min($this.ScrollOffsetY, $this.MaxScrollY))
        # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': ContentHeight=$($this._contentHeight), ViewportHeight=$($viewportHeight), MaxScrollY=$($this.MaxScrollY), ScrollOffsetY=$($this.ScrollOffsetY)."
    }

    # Keep DrawScrollbar, HandleInput, ScrollUp/Down/PageUp/Down/ToTop/Bottom methods.
    # Ensure DrawScrollbar uses the correct ScrollOffsetY, MaxScrollY, and _contentHeight for calculations.
    # Update SetCell calls in DrawScrollbar to use hex colors.
    [void] DrawScrollbar() {
        $scrollbarX = $this.Width - 1
        if ($this.HasBorder) { 
            $scrollbarY = 1 
        } else { 
            $scrollbarY = 0 
        }
        if ($this.HasBorder) { 
            $scrollbarTrackHeight = $this.Height - 2 
        } else { 
            $scrollbarTrackHeight = $this.Height - 0 
        }

        if ($this._contentHeight -le $scrollbarTrackHeight) { 
            # If content fits, clear any previous scrollbar
            $bgColor = Get-ThemeColor "Background"
            for ($i = 0; $i -lt $scrollbarTrackHeight; $i++) {
                $this._private_buffer.SetCell($scrollbarX, $scrollbarY + $i, [TuiCell]::new(' ', $bgColor, $bgColor))
            }
            return 
        } 

        $scrollFg = Get-ThemeColor "list.scrollbar"
        $scrollBg = Get-ThemeColor "Background"

        # Calculate thumb size and position
        $thumbSize = [Math]::Max(1, [int]($scrollbarTrackHeight * $scrollbarTrackHeight / $this._contentHeight))
        $thumbPos = [int](($scrollbarTrackHeight - $thumbSize) * $this.ScrollOffsetY / $this.MaxScrollY)
        
        for ($i = 0; $i -lt $scrollbarTrackHeight; $i++) {
            $y = $scrollbarY + $i
            $char = '│' # Default track character
            
            if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) {
                $char = '█' # Thumb character
            }
            $this._private_buffer.SetCell($scrollbarX, $y, [TuiCell]::new($char, $scrollFg, $scrollBg))
        }
    }

    # Ensure other scrolling methods call RequestRedraw and UpdateMaxScroll
    [void] ScrollUp([int]$lines = 1) {
        $oldScroll = $this.ScrollOffsetY
        $this.ScrollOffsetY = [Math]::Max(0, $this.ScrollOffsetY - $lines)
        if ($this.ScrollOffsetY -ne $oldScroll) {
            $this.RequestRedraw()
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': Scrolled up to $($this.ScrollOffsetY)."
        }
    }

    [void] ScrollDown([int]$lines = 1) {
        $oldScroll = $this.ScrollOffsetY
        $this.ScrollOffsetY = [Math]::Min($this.MaxScrollY, $this.ScrollOffsetY + $lines)
        if ($this.ScrollOffsetY -ne $oldScroll) {
            $this.RequestRedraw()
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': Scrolled down to $($this.ScrollOffsetY)."
        }
    }

    [void] ScrollPageUp() {
        $pageSize = $this.ContentHeight
        $this.ScrollUp($pageSize)
    }

    [void] ScrollPageDown() {
        $pageSize = $this.ContentHeight
        $this.ScrollDown($pageSize)
    }

    [void] ScrollToTop() {
        $oldScroll = $this.ScrollOffsetY
        $this.ScrollOffsetY = 0
        if ($this.ScrollOffsetY -ne $oldScroll) {
            $this.RequestRedraw()
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': Scrolled to top."
        }
    }

    [void] ScrollToBottom() {
        $oldScroll = $this.ScrollOffsetY
        $this.ScrollOffsetY = $this.MaxScrollY
        if ($this.ScrollOffsetY -ne $oldScroll) {
            $this.RequestRedraw()
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': Scrolled to bottom."
        }
    }
}

#<!-- END_PAGE: ACO.012 -->

#<!-- PAGE: ACO.013 - GroupPanel Class -->
# ===== CLASS: GroupPanel =====
# Module: panels-class
# Dependencies: Panel
# Purpose: Themed panel for grouping
class GroupPanel : Panel {
    [bool]$IsExpanded = $true
    [bool]$CanCollapse = $true

    GroupPanel([string]$name) : base($name) {
        $this.BorderStyle = "Double"
        $this.BorderColor = "#008B8B"     # FIXED: DarkCyan in hex
        $this.BackgroundColor = "#000000" # FIXED: Black in hex
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Show children only if expanded
        foreach ($child in $this.Children) {
            $child.Visible = $this.IsExpanded
        }

        # Adjust height if collapsed
        if (-not $this.IsExpanded -and $this.CanCollapse) {
            $this._originalHeight = $this.Height
            $this.Height = 3  # Just title bar
        }
        elseif ($this.IsExpanded -and $this._originalHeight) {
            $this.Height = $this._originalHeight
        }

        # Add expand/collapse indicator to title
        if ($this.CanCollapse -and $this.Title) {
            $indicator = if ($this.IsExpanded) { "[-]" } else { "[+]" }
            $this.Title = "$indicator $($this.Title.TrimStart('[+]', '[-]').Trim())"
        }

        ([Panel]$this).OnRender()
    }

    hidden [int]$_originalHeight = 0

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or -not $this.CanCollapse) { return $false }
        
        if ($key.Key -eq [ConsoleKey]::Spacebar) {
            $this.Toggle()
            return $true
        }
        
        return $false
    }

    [void] Toggle() {
        $this.IsExpanded = -not $this.IsExpanded
        $this.RequestRedraw()
    }
}

#endregion Panel Components

#region Composite Components

#<!-- END_PAGE: ACO.013 -->

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

#<!-- PAGE: ACO.016 - CommandPalette Class -->
# ===== CLASS: CommandPalette =====
# Module: command-palette
# Dependencies: UIElement, Panel, ListBox, TextBoxComponent
# Purpose: Searchable command interface
class CommandPalette : UIElement {
    hidden [ListBox]$_listBox
    hidden [TextBoxComponent]$_searchBox
    hidden [Panel]$_panel
    hidden [List[object]]$_allActions
    hidden [List[object]]$_filteredActions
    [scriptblock]$OnExecute
    [scriptblock]$OnCancel

    CommandPalette([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Visible = $false
        $this.IsOverlay = $true
        $this.Width = 60
        $this.Height = 20
        
        $this._allActions = [List[object]]::new()
        $this._filteredActions = [List[object]]::new()
        
        $this.Initialize()
    }

    hidden [void] Initialize() {
        # Create main panel with border
        $this._panel = [Panel]::new("CommandPalette_Panel")
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
        $this._panel.Title = " Command Palette "
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height
        $this._panel.X = 0
        $this._panel.Y = 0
        $this.AddChild($this._panel)

        # Create search box
        $this._searchBox = [TextBoxComponent]::new("CommandPalette_Search")
        $this._searchBox.X = 2
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 3
        $this._searchBox.Placeholder = "Type to search commands..."
        
        # Connect search box to filtering
        $paletteRef = $this
        $this._searchBox.OnChange = { 
            param($sender, $text) 
            $paletteRef.FilterActions($text) 
        }.GetNewClosure()
        $this._panel.AddChild($this._searchBox)

        # Create list box for results
        $this._listBox = [ListBox]::new("CommandPalette_List")
        $this._listBox.X = 2
        $this._listBox.Y = 4
        $this._listBox.Width = $this.Width - 4
        $this._listBox.Height = $this.Height - 6
        $this._panel.AddChild($this._listBox)
    }

    [void] SetActions([object[]]$actionList) {
        $this._allActions.Clear()
        foreach ($action in $actionList) {
            $this._allActions.Add($action)
        }
        $this.FilterActions("")  # Show all actions initially
        
        # Set initial focus to search box
        $this._searchBox.IsFocused = $true
    }

    [void] FilterActions([string]$searchText) {
        $this._filteredActions.Clear()
        $this._listBox.ClearItems()
        
        $actionsToDisplay = if ([string]::IsNullOrWhiteSpace($searchText)) { 
            $this._allActions 
        } else {
            $searchLower = $searchText.ToLower()
            @($this._allActions | Where-Object {
                $_.Name.ToLower().Contains($searchLower) -or
                ($_.Description -and $_.Description.ToLower().Contains($searchLower)) -or
                ($_.Category -and $_.Category.ToLower().Contains($searchLower))
            })
        }

        foreach ($action in $actionsToDisplay) {
            $this._filteredActions.Add($action)
            $displayText = if ($action.Category) { 
                "[$($action.Category)] $($action.Name)" 
            } else { 
                $action.Name 
            }
            $this._listBox.AddItem("$displayText - $($action.Description)")
        }
        
        if ($this._filteredActions.Count -gt 0) { 
            $this._listBox.SelectedIndex = 0 
        }
        $this.RequestRedraw()
    }

    [void] SetInitialFocus() {
        if ($this._searchBox) {
            # Clear any previous search text
            $this._searchBox.Text = ""
            $this._searchBox.CursorPosition = 0
            $this._searchBox.IsFocused = $true
            $this._searchBox.RequestRedraw()
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $handled = $true
        
        switch ($key.Key) {
            ([ConsoleKey]::Escape) { 
                if ($this.OnCancel) {
                    & $this.OnCancel
                }
                return $true 
            }
            ([ConsoleKey]::Enter) {
                if ($this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                    $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                    if ($selectedAction -and $this.OnExecute) {
                        & $this.OnExecute $this $selectedAction
                        return $true
                    }
                }
                return $true
            }
            ([ConsoleKey]::Tab) {
                # Switch focus between search box and list
                if ($this._searchBox.IsFocused) {
                    $this._searchBox.IsFocused = $false
                    $this._listBox.IsFocusable = $true
                    # Focus would be set by parent focus manager
                } else {
                    $this._searchBox.IsFocused = $true
                    $this._listBox.IsFocusable = $false
                }
                $this.RequestRedraw()
                return $true
            }
            {$_ -in @([ConsoleKey]::UpArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::PageUp, [ConsoleKey]::PageDown, [ConsoleKey]::Home, [ConsoleKey]::End)} {
                # Navigation keys go to the list
                return $this._listBox.HandleInput($key)
            }
            default {
                # All other input goes to search box if it's focused
                if ($this._searchBox.IsFocused) {
                    return $this._searchBox.HandleInput($key)
                } else {
                    $handled = $false
                }
            }
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }

    [void] OnFocus() {
        ([UIElement]$this).OnFocus()
        # Set initial focus to search box
        if ($this._searchBox) {
            $this._searchBox.IsFocused = $true
            $this._searchBox.RequestRedraw()
        }
    }

    [void] OnBlur() {
        ([UIElement]$this).OnBlur()
        if ($this._searchBox) {
            $this._searchBox.IsFocused = $false
            $this._searchBox.RequestRedraw()
        }
    }

    [void] Cleanup() {
        if ($this._searchBox) {
            $this._searchBox.Text = ""
            $this._searchBox.CursorPosition = 0
        }
        if ($this._listBox) {
            $this._listBox.ClearItems()
            $this._listBox.SelectedIndex = -1
        }
        $this._allActions.Clear()
        $this._filteredActions.Clear()
    }
}

#<!-- END_PAGE: ACO.016 -->

#endregion Composite Components

#region Dialog Components

#<!-- PAGE: ACO.017 - Dialog Class -->
# ===== CLASS: Dialog =====
# Module: dialog-system-class
# Dependencies: UIElement, Panel
# Purpose: Base class for modal dialogs
class Dialog : UIElement {
    [string]$Title = ""
    [string]$Message = ""
    hidden [Panel]$_panel
    hidden [object]$Result = $null
    hidden [bool]$_isComplete = $false
    [scriptblock]$OnClose
    [DialogResult]$DialogResult = [DialogResult]::None

    Dialog([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Visible = $false
        $this.IsOverlay = $true
        $this.Width = 50
        $this.Height = 10
        
        $this.InitializeDialog()
    }

    hidden [void] InitializeDialog() {
        $this._panel = [Panel]::new($this.Name + "_Panel")
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
        $this._panel.BorderColor = "#00FFFF"    # FIXED: Use hex string for border
        $this._panel.BackgroundColor = "#000000" # FIXED: Use hex string for background
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height
        $this.AddChild($this._panel)
    }

    [void] Show([string]$title, [string]$message) {
        $this.Title = $title
        $this.Message = $message
        $this._panel.Title = " $title "
        $this._isComplete = $false
        $this.Result = $null
        $this.Visible = $true
        $this.RequestRedraw()
    }

    # Renamed from Close to Complete to match guide
    [void] Complete([object]$result) {
        $this.Result = $result
        $this._isComplete = $true
        
        # Call the OnClose scriptblock if provided
        if ($this.OnClose) {
            try { 
                & $this.OnClose $result 
            } catch { 
                # Write-Log -Level Warning -Message "Dialog '$($this.Name)': Error in OnClose callback: $($_.Exception.Message)" 
            }
        }
        
        # Publish a general dialog close event for DialogManager to pick up
        if ($global:TuiState.Services.EventManager) {
            $global:TuiState.Services.EventManager.Publish("Dialog.Completed", @{ Dialog = $this; Result = $result })
        }
        # The DialogManager will then call HideDialog for actual UI removal and focus restoration.
    }

    # Legacy method for compatibility
    [void] Close([object]$result) {
        $this.Complete($result)
    }

    # New method for DialogManager to call to set initial focus within the dialog
    [void] SetInitialFocus() {
        $firstFocusable = $this.Children | Where-Object { $_.IsFocusable -and $_.Visible -and $_.Enabled } | Sort-Object TabIndex, Y, X | Select-Object -First 1
        if ($firstFocusable -and $global:TuiState.Services.FocusManager) {
            $global:TuiState.Services.FocusManager.SetFocus($firstFocusable)
            # Write-Log -Level Debug -Message "Dialog '$($this.Name)': Set initial focus to '$($firstFocusable.Name)'."
        }
    }

    # Update Title on render
    [void] OnRender() {
        # Base Panel's OnRender already draws border and title using ThemeManager colors
        $this._panel.Title = " $this.Title " # Ensure title is updated on panel
        $this._panel.OnRender() # Render the internal panel
    }

    [object] ShowDialog([string]$title, [string]$message) {
        $this.Show($title, $message)
        
        # In a real implementation, this would block until dialog closes
        # For now, return immediately
        return $this.Result
    }
}

#<!-- END_PAGE: ACO.017 -->

#<!-- PAGE: ACO.018 - AlertDialog Class -->
# ===== CLASS: AlertDialog =====
# Module: dialog-system-class
# Dependencies: Dialog, ButtonComponent
# Purpose: Simple message dialog
class AlertDialog : Dialog {
    hidden [ButtonComponent]$_okButton

    AlertDialog([string]$name) : base($name) {
        $this.Height = 8
        $this.InitializeAlert()
    }

    hidden [void] InitializeAlert() {
        # OK button
        $this._okButton = [ButtonComponent]::new($this.Name + "_OK")
        $this._okButton.Text = "OK"
        $this._okButton.Width = 10
        $this._okButton.Height = 3
        $this._okButton.OnClick = {
            $this.Complete($true)
        }.GetNewClosure()
        $this._panel.AddChild($this._okButton)
    }

    [void] Show([string]$title, [string]$message) {
        ([Dialog]$this).Show($title, $message)
        
        # Position OK button
        $this._okButton.X = [Math]::Floor(($this.Width - $this._okButton.Width) / 2)
        $this._okButton.Y = $this.Height - 4
    }

    [void] OnRender() {
        ([Dialog]$this).OnRender()
        
        if ($this.Visible -and $this.Message) {
            # Draw message within the dialog's panel content area
            $panelContentX = $this._panel.ContentX
            $panelContentY = $this._panel.ContentY
            $maxWidth = $this.Width - 4 # Panel width - 2*border - 2*padding

            # Simple word wrap (use Write-TuiText)
            $words = $this.Message -split ' '
            $currentLine = ""
            $currentY = $panelContentY + 1 # Start drawing message below title

            foreach ($word in $words) {
                if (($currentLine + " " + $word).Length -gt $maxWidth) {
                    if ($currentLine) {
                        Write-TuiText -Buffer $this._panel._private_buffer -X $panelContentX -Y $currentY -Text $currentLine -Style @{ FG = Get-ThemeColor("dialog.foreground"); BG = Get-ThemeColor("dialog.background") }
                        $currentY++
                    }
                    $currentLine = $word
                }
                else {
                    $currentLine = if ($currentLine) { "$currentLine $word" } else { $word }
                }
            }
            if ($currentLine) {
                Write-TuiText -Buffer $this._panel._private_buffer -X $panelContentX -Y $currentY -Text $currentLine -Style @{ FG = Get-ThemeColor("dialog.foreground"); BG = Get-ThemeColor("dialog.background") }
            }
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }

        # Let OK button handle input first
        if ($this._okButton.HandleInput($key)) { return $true }
        
        if ($key.Key -eq [ConsoleKey]::Escape -or $key.Key -eq [ConsoleKey]::Enter) {
            $this.Complete($true) # Complete dialog
            return $true
        }
        return $false
    }

    [void] OnEnter() {
        # Set focus to the OK button when dialog appears
        $global:TuiState.Services.FocusManager?.SetFocus($this._okButton)
    }
}

#<!-- END_PAGE: ACO.018 -->

#<!-- PAGE: ACO.019 - ConfirmDialog Class -->
# ===== CLASS: ConfirmDialog =====
# Module: dialog-system-class
# Dependencies: Dialog, ButtonComponent
# Purpose: Yes/No confirmation dialog
class ConfirmDialog : Dialog {
    hidden [ButtonComponent]$_yesButton
    hidden [ButtonComponent]$_noButton
    # Removed manual focus tracking - will use FocusManager instead

    ConfirmDialog([string]$name) : base($name) {
        $this.Height = 8
        $this.InitializeConfirm()
    }

    hidden [void] InitializeConfirm() {
        # Yes button
        $this._yesButton = [ButtonComponent]::new($this.Name + "_Yes")
        $this._yesButton.Text = "Yes"
        $this._yesButton.Width = 10
        $this._yesButton.Height = 3
        $this._yesButton.TabIndex = 1 # Explicitly set tab order
        $this._yesButton.OnClick = {
            $this.Complete($true)
        }.GetNewClosure()
        $this._panel.AddChild($this._yesButton)

        # No button
        $this._noButton = [ButtonComponent]::new($this.Name + "_No")
        $this._noButton.Text = "No"
        $this._noButton.Width = 10
        $this._noButton.Height = 3
        $this._noButton.TabIndex = 2 # Explicitly set tab order
        $this._noButton.OnClick = {
            $this.Complete($false)
        }.GetNewClosure()
        $this._panel.AddChild($this._noButton)
    }

    [void] Show([string]$title, [string]$message) {
        ([Dialog]$this).Show($title, $message)
        
        # Position buttons
        $buttonY = $this.Height - 4
        $totalWidth = $this._yesButton.Width + $this._noButton.Width + 4
        $startX = [Math]::Floor(($this.Width - $totalWidth) / 2)
        
        $this._yesButton.X = $startX
        $this._yesButton.Y = $buttonY
        
        $this._noButton.X = $startX + $this._yesButton.Width + 4
        $this._noButton.Y = $buttonY
        
    }

    [void] OnEnter() {
        # When the dialog is shown, tell the FocusManager to focus the first element (Yes button)
        $global:TuiState.Services.FocusManager?.SetFocus($this._yesButton)
    }

    [void] OnRender() {
        ([Dialog]$this).OnRender()
        
        if ($this.Visible -and $this.Message) {
            # Draw message (same as AlertDialog)
            $panelContentX = $this._panel.ContentX
            $panelContentY = $this._panel.ContentY
            $maxWidth = $this.Width - 4
            
            $words = $this.Message -split ' '
            $currentLine = ""
            $currentY = $panelContentY + 1
            
            foreach ($word in $words) {
                if (($currentLine + " " + $word).Length -gt $maxWidth) {
                    if ($currentLine) {
                        Write-TuiText -Buffer $this._panel._private_buffer -X $panelContentX -Y $currentY -Text $currentLine -Style @{ FG = Get-ThemeColor("dialog.foreground"); BG = Get-ThemeColor("dialog.background") }
                        $currentY++
                    }
                    $currentLine = $word
                }
                else {
                    $currentLine = if ($currentLine) { "$currentLine $word" } else { $word }
                }
            }
            
            if ($currentLine) {
                Write-TuiText -Buffer $this._panel._private_buffer -X $panelContentX -Y $currentY -Text $currentLine -Style @{ FG = Get-ThemeColor("dialog.foreground"); BG = Get-ThemeColor("dialog.background") }
            }
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }

        # Handle Escape to cancel
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Complete($false) # Using new Complete method
            return $true
        }

        # The global input handler will route Tab/Shift+Tab to the FocusManager.
        # Left/Right arrow keys can be used to switch between Yes/No buttons
        if ($key.Key -eq [ConsoleKey]::LeftArrow -or $key.Key -eq [ConsoleKey]::RightArrow) {
            $focusManager = $global:TuiState.Services.FocusManager
            if ($focusManager) {
                # Toggle focus between the two buttons
                if ($focusManager.FocusedComponent -eq $this._yesButton) {
                    $focusManager.SetFocus($this._noButton)
                } else {
                    $focusManager.SetFocus($this._yesButton)
                }
                return $true
            }
        }
        
        # Let the focused child handle the input
        # The FocusManager will have already routed input to the focused button
        return $false
    }
}

#<!-- END_PAGE: ACO.019 -->

#<!-- PAGE: ACO.020 - InputDialog Class -->
# ===== CLASS: InputDialog =====
# Module: dialog-system-class
# Dependencies: Dialog, TextBoxComponent, ButtonComponent
# Purpose: Text input dialog
class InputDialog : Dialog {
    hidden [TextBoxComponent]$_inputBox
    hidden [ButtonComponent]$_okButton
    hidden [ButtonComponent]$_cancelButton
    hidden [bool]$_focusOnInput = $true
    hidden [int]$_focusIndex = 0  # 0=input, 1=ok, 2=cancel

    InputDialog([string]$name) : base($name) {
        $this.Height = 10
        $this.InitializeInput()
    }

    hidden [void] InitializeInput() {
        # Input box
        $this._inputBox = [TextBoxComponent]::new($this.Name + "_Input")
        $this._inputBox.Width = $this.Width - 4
        $this._inputBox.Height = 3
        $this._inputBox.X = 2
        $this._inputBox.Y = 4
        $this._panel.AddChild($this._inputBox)

        # OK button
        $this._okButton = [ButtonComponent]::new($this.Name + "_OK")
        $this._okButton.Text = "OK"
        $this._okButton.Width = 10
        $this._okButton.Height = 3
        $this._okButton.OnClick = {
            $this.Close($this._inputBox.Text)
        }.GetNewClosure()
        $this._panel.AddChild($this._okButton)

        # Cancel button
        $this._cancelButton = [ButtonComponent]::new($this.Name + "_Cancel")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.Width = 10
        $this._cancelButton.Height = 3
        $this._cancelButton.OnClick = {
            $this.Close($null)
        }.GetNewClosure()
        $this._panel.AddChild($this._cancelButton)
    }

    [void] Show([string]$title, [string]$message, [string]$defaultValue = "") {
        ([Dialog]$this).Show($title, $message)
        
        $this._inputBox.Text = $defaultValue
        $this._inputBox.CursorPosition = $defaultValue.Length
        
        # Position buttons
        $buttonY = $this.Height - 4
        $totalWidth = $this._okButton.Width + $this._cancelButton.Width + 4
        $startX = [Math]::Floor(($this.Width - $totalWidth) / 2)
        
        $this._okButton.X = $startX
        $this._okButton.Y = $buttonY
        
        $this._cancelButton.X = $startX + $this._okButton.Width + 4
        $this._cancelButton.Y = $buttonY
        
        # Set initial focus
        $this._focusIndex = 0
        $this.UpdateFocus()
    }

    hidden [void] UpdateFocus() {
        $this._inputBox.IsFocused = ($this._focusIndex -eq 0)
        $this._okButton.IsFocused = ($this._focusIndex -eq 1)
        $this._cancelButton.IsFocused = ($this._focusIndex -eq 2)
    }

    [void] OnRender() {
        ([Dialog]$this).OnRender()
        
        if ($this.Visible -and $this.Message) {
            # Draw message
            $this._panel._private_buffer.WriteString(2, 2, 
                $this.Message, [ConsoleColor]::White, [ConsoleColor]::Black)
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Close($null)
            return $true
        }
        
        if ($key.Key -eq [ConsoleKey]::Tab) {
            $this._focusIndex = ($this._focusIndex + 1) % 3
            $this.UpdateFocus()
            $this.RequestRedraw()
            return $true
        }
        
        switch ($this._focusIndex) {
            0 { return $this._inputBox.HandleInput($key) }
            1 { return $this._okButton.HandleInput($key) }
            2 { return $this._cancelButton.HandleInput($key) }
        }
        
        return $false
    }
}

# Task Create/Edit Dialog
class TaskDialog : Dialog {
    hidden [TextBoxComponent] $_titleBox
    hidden [MultilineTextBoxComponent] $_descriptionBox
    hidden [ComboBoxComponent] $_statusCombo
    hidden [ComboBoxComponent] $_priorityCombo
    hidden [NumericInputComponent] $_progressInput
    hidden [ButtonComponent] $_saveButton
    hidden [ButtonComponent] $_cancelButton
    hidden [PmcTask] $_task
    hidden [bool] $_isNewTask
    
    TaskDialog([string]$title, [PmcTask]$task) : base($title) {
        $this._task = if ($task) { $task } else { [PmcTask]::new() }
        $this._isNewTask = ($null -eq $task)
        $this.Width = 60
        $this.Height = 20
    }
    
    [void] Initialize() {
        ([Dialog]$this).Initialize()
        
        $contentY = 2
        $labelWidth = 12
        $inputX = $labelWidth + 2
        $inputWidth = $this.ContentWidth - $inputX - 2
        
        # Title
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Title:"
        $titleLabel.X = 2
        $titleLabel.Y = $contentY
        $this._panel.AddChild($titleLabel)
        
        $this._titleBox = [TextBoxComponent]::new("TitleBox")
        $this._titleBox.X = $inputX
        $this._titleBox.Y = $contentY
        $this._titleBox.Width = $inputWidth
        $this._titleBox.Height = 1
        $this._titleBox.Text = $this._task.Title
        $this._panel.AddChild($this._titleBox)
        $contentY += 2
        
        # Description
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = 2
        $descLabel.Y = $contentY
        $this._panel.AddChild($descLabel)
        
        $this._descriptionBox = [MultilineTextBoxComponent]::new("DescBox")
        $this._descriptionBox.X = $inputX
        $this._descriptionBox.Y = $contentY
        $this._descriptionBox.Width = $inputWidth
        $this._descriptionBox.Height = 3
        $this._descriptionBox.Text = $this._task.Description
        $this._panel.AddChild($this._descriptionBox)
        $contentY += 4
        
        # Status
        $statusLabel = [LabelComponent]::new("StatusLabel")
        $statusLabel.Text = "Status:"
        $statusLabel.X = 2
        $statusLabel.Y = $contentY
        $this._panel.AddChild($statusLabel)
        
        $this._statusCombo = [ComboBoxComponent]::new("StatusCombo")
        $this._statusCombo.X = $inputX
        $this._statusCombo.Y = $contentY
        $this._statusCombo.Width = $inputWidth
        $this._statusCombo.Height = 1
        $this._statusCombo.Items = @([TaskStatus]::GetEnumNames())
        $this._statusCombo.SelectedIndex = [Array]::IndexOf($this._statusCombo.Items, $this._task.Status.ToString())
        $this._panel.AddChild($this._statusCombo)
        $contentY += 2
        
        # Priority
        $priorityLabel = [LabelComponent]::new("PriorityLabel")
        $priorityLabel.Text = "Priority:"
        $priorityLabel.X = 2
        $priorityLabel.Y = $contentY
        $this._panel.AddChild($priorityLabel)
        
        $this._priorityCombo = [ComboBoxComponent]::new("PriorityCombo")
        $this._priorityCombo.X = $inputX
        $this._priorityCombo.Y = $contentY
        $this._priorityCombo.Width = $inputWidth
        $this._priorityCombo.Height = 1
        $this._priorityCombo.Items = @([TaskPriority]::GetEnumNames())
        $this._priorityCombo.SelectedIndex = [Array]::IndexOf($this._priorityCombo.Items, $this._task.Priority.ToString())
        $this._panel.AddChild($this._priorityCombo)
        $contentY += 2
        
        # Progress
        $progressLabel = [LabelComponent]::new("ProgressLabel")
        $progressLabel.Text = "Progress %:"
        $progressLabel.X = 2
        $progressLabel.Y = $contentY
        $this._panel.AddChild($progressLabel)
        
        $this._progressInput = [NumericInputComponent]::new("ProgressInput")
        $this._progressInput.X = $inputX
        $this._progressInput.Y = $contentY
        $this._progressInput.Width = 10
        $this._progressInput.Height = 1
        $this._progressInput.MinValue = 0
        $this._progressInput.MaxValue = 100
        $this._progressInput.Value = $this._task.Progress
        $this._panel.AddChild($this._progressInput)
        $contentY += 3
        
        # Buttons
        $buttonY = $this.ContentHeight - 3
        $buttonWidth = 12
        $spacing = 2
        $totalButtonWidth = ($buttonWidth * 2) + $spacing
        $startX = [Math]::Floor(($this.ContentWidth - $totalButtonWidth) / 2)
        
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = "Save"
        $this._saveButton.X = $startX
        $this._saveButton.Y = $buttonY
        $this._saveButton.Width = $buttonWidth
        $this._saveButton.Height = 1
        $thisDialog = $this
        $this._saveButton.OnClick = {
            $thisDialog.DialogResult = [DialogResult]::OK
            $thisDialog.Complete($thisDialog.DialogResult)
        }.GetNewClosure()
        $this._panel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.X = $startX + $buttonWidth + $spacing
        $this._cancelButton.Y = $buttonY
        $this._cancelButton.Width = $buttonWidth
        $this._cancelButton.Height = 1
        $this._cancelButton.OnClick = {
            $thisDialog.DialogResult = [DialogResult]::Cancel
            $thisDialog.Complete($thisDialog.DialogResult)
        }.GetNewClosure()
        $this._panel.AddChild($this._cancelButton)
        
        # Set initial focus
        Set-ComponentFocus -Component $this._titleBox
    }
    
    [PmcTask] GetTask() {
        if ($this.DialogResult -eq [DialogResult]::OK) {
            # Update task with form values
            $this._task.Title = $this._titleBox.Text
            $this._task.Description = $this._descriptionBox.Text
            $this._task.Status = [TaskStatus]::($this._statusCombo.Items[$this._statusCombo.SelectedIndex])
            $this._task.Priority = [TaskPriority]::($this._priorityCombo.Items[$this._priorityCombo.SelectedIndex])
            $this._task.SetProgress($this._progressInput.Value)
            $this._task.UpdatedAt = [DateTime]::Now
        }
        return $this._task
    }
}

# Task Delete Confirmation Dialog
class TaskDeleteDialog : ConfirmDialog { 
    hidden [PmcTask] $_task
    
    TaskDeleteDialog([PmcTask]$task) : base("Confirm Delete", "Are you sure you want to delete this task?") {
        $this._task = $task
    }
    
    [void] Initialize() {
        ([ConfirmDialog]$this).Initialize()
        
        # Add task details to the message
        if ($this._task) {
            $detailsLabel = [LabelComponent]::new("TaskDetails")
            $detailsLabel.Text = "Task: $($this._task.Title)"
            $detailsLabel.X = 2
            $detailsLabel.Y = 4
            $detailsLabel.ForegroundColor = Get-ThemeColor -ColorName "Warning" -DefaultColor "#FFA500"
            $this._panel.AddChild($detailsLabel)
        }
    }
}

#endregion Dialog Components

#region Navigation Components

#<!-- END_PAGE: ACO.020 -->

#<!-- PAGE: ACO.021 - NavigationMenu Class -->
# ===== CLASS: NavigationMenu =====
# Module: navigation-class
# Dependencies: UIElement, NavigationItem
# Purpose: Local menu component
class NavigationMenu : UIElement {
    [List[NavigationItem]]$Items
    [int]$SelectedIndex = 0
    [string]$Orientation = "Horizontal"  # Horizontal or Vertical
    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$SelectedBackgroundColor = "#0078D4"
    [string]$SelectedForegroundColor = "#FFFF00"

    NavigationMenu([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Items = [List[NavigationItem]]::new()
        $this.Height = 1
    }

    [void] AddItem([NavigationItem]$item) {
        $this.Items.Add($item)
        $this.RequestRedraw()
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', $this.ForegroundColor, $this.BackgroundColor))
            
            if ($this.Orientation -eq "Horizontal") {
                $this.RenderHorizontal()
            }
            else {
                $this.RenderVertical()
            }
        }
        catch {}
    }

    hidden [void] RenderHorizontal() {
        $currentX = 0
        
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex -and $this.IsFocused)
            
            $fg = if ($isSelected) { $this.SelectedForegroundColor } else { $this.ForegroundColor }
            $bg = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.BackgroundColor }
            
            # Draw item
            $text = " $($item.Label) "
            if ($item.Key) {
                $text = " $($item.Label) ($($item.Key)) "
            }
            
            if ($currentX + $text.Length -le $this.Width) {
                for ($x = 0; $x -lt $text.Length; $x++) {
                    $this._private_buffer.SetCell($currentX + $x, 0, 
                        [TuiCell]::new($text[$x], $fg, $bg))
                }
            }
            
            $currentX += $text.Length + 1
        }
    }

    hidden [void] RenderVertical() {
        # Ensure height matches item count
        if ($this.Height -ne $this.Items.Count -and $this.Items.Count -gt 0) {
            $this.Height = $this.Items.Count
            # Resize the buffer to match new height
            if ($this._private_buffer) {
                $this._private_buffer.Resize($this.Width, $this.Height)
            }
        }
        
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex -and $this.IsFocused)
            
            $fg = if ($isSelected) { $this.SelectedForegroundColor } else { $this.ForegroundColor }
            $bg = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.BackgroundColor }
            
            # Clear line
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this._private_buffer.SetCell($x, $i, [TuiCell]::new(' ', $fg, $bg))
            }
            
            # Draw item
            $text = $item.Label
            if ($item.Key) {
                $text = "$($item.Label) ($($item.Key))"
            }
            
            if ($text.Length -gt $this.Width) {
                $text = $text.Substring(0, $this.Width - 3) + "..."
            }
            
            $this._private_buffer.WriteString(0, $i, $text, @{ FG = $fg; BG = $bg })
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or $this.Items.Count -eq 0) { return $false }
        
        $handled = $true
        
        if ($this.Orientation -eq "Horizontal") {
            switch ($key.Key) {
                ([ConsoleKey]::LeftArrow) {
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                        $this.SelectedIndex++
                    }
                }
                ([ConsoleKey]::Enter) {
                    $this.ExecuteItem($this.SelectedIndex)
                }
                default {
                    # Check hotkeys
                    $handled = $this.CheckHotkey($key)
                }
            }
        }
        else {
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
                ([ConsoleKey]::Enter) {
                    $this.ExecuteItem($this.SelectedIndex)
                }
                default {
                    $handled = $this.CheckHotkey($key)
                }
            }
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }

    hidden [bool] CheckHotkey([System.ConsoleKeyInfo]$key) {
        foreach ($i in 0..($this.Items.Count - 1)) {
            $item = $this.Items[$i]
            if ($item.Key -and $item.Key.ToUpper() -eq $key.KeyChar.ToString().ToUpper()) {
                $this.SelectedIndex = $i
                $this.ExecuteItem($i)
                return $true
            }
        }
        return $false
    }

    hidden [void] ExecuteItem([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            $item = $this.Items[$index]
            if ($item.Action) {
                try {
                    & $item.Action
                }
                catch {}
            }
        }
    }
}

#<!-- END_PAGE: ACO.021 -->

#<!-- PAGE: ACO.022 - DataGridComponent Class -->
# ===== CLASS: DataGridComponent =====
# Module: data-grid-component
# Dependencies: UIElement, TuiCell
# Purpose: Generic data grid for displaying tabular data with scrolling and selection
class DataGridComponent : UIElement {
    [hashtable[]]$Columns = @()
    [hashtable[]]$Items = @()
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowHeaders = $true
    [string]$HeaderBackgroundColor = "#333333"
    [string]$HeaderForegroundColor = "#FFFFFF"
    [string]$SelectedBackgroundColor = "#0078D4"
    [string]$SelectedForegroundColor = "#FFFFFF"
    [string]$NormalBackgroundColor = "#000000"
    [string]$NormalForegroundColor = "#C0C0C0"
    [scriptblock]$OnSelectionChanged
    
    DataGridComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 60
        $this.Height = 20
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        $y = 0
        
        # Render headers if enabled
        if ($this.ShowHeaders -and $this.Columns.Count -gt 0) {
            $x = 0
            foreach ($column in $this.Columns) {
                $header = if ($column.Header) { $column.Header } else { $column.Name }
                $width = if ($column.Width) { $column.Width } else { 10 }
                
                # Truncate header if needed
                if ($header.Length -gt $width) {
                    $header = $header.Substring(0, [Math]::Max(1, $width - 2)) + ".."
                }
                
                # Pad header to column width
                $header = $header.PadRight($width)
                
                Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $header -Style @{
                    FG = $this.HeaderForegroundColor
                    BG = $this.HeaderBackgroundColor
                }
                
                $x += $width + 1  # +1 for separator
            }
            $y++
        }
        
        # Calculate visible items
        $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
        $startIndex = $this.ScrollOffset
        $endIndex = [Math]::Min($this.Items.Count - 1, $startIndex + $visibleHeight - 1)
        
        # Render data rows
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            if ($i -ge $this.Items.Count) { break }
            
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            $x = 0
            foreach ($column in $this.Columns) {
                $value = if ($item.ContainsKey($column.Name)) { $item[$column.Name] } else { "" }
                $width = if ($column.Width) { $column.Width } else { 10 }
                
                # Convert value to string and truncate if needed
                $text = $value.ToString()
                if ($text.Length -gt $width) {
                    $text = $text.Substring(0, [Math]::Max(1, $width - 2)) + ".."
                }
                
                # Pad text to column width
                $text = $text.PadRight($width)
                
                # Set colors based on selection
                $fgColor = if ($isSelected) { $this.SelectedForegroundColor } else { $this.NormalForegroundColor }
                $bgColor = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.NormalBackgroundColor }
                
                Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $text -Style @{
                    FG = $fgColor
                    BG = $bgColor
                }
                
                $x += $width + 1  # +1 for separator
            }
            $y++
        }
        
        $this._needs_redraw = $false
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.Enabled -or -not $this.IsFocused) { return $false }
        
        $handled = $false
        $oldSelectedIndex = $this.SelectedIndex
        
        switch ($key.Key) {
            "UpArrow" {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this._EnsureVisible()
                    $handled = $true
                }
            }
            "DownArrow" {
                if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                    $this.SelectedIndex++
                    $this._EnsureVisible()
                    $handled = $true
                }
            }
            "PageUp" {
                $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $visibleHeight)
                $this._EnsureVisible()
                $handled = $true
            }
            "PageDown" {
                $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $visibleHeight)
                $this._EnsureVisible()
                $handled = $true
            }
            "Home" {
                $this.SelectedIndex = 0
                $this._EnsureVisible()
                $handled = $true
            }
            "End" {
                $this.SelectedIndex = [Math]::Max(0, $this.Items.Count - 1)
                $this._EnsureVisible()
                $handled = $true
            }
        }
        
        # Fire selection changed event if selection changed
        if ($handled -and $oldSelectedIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
            & $this.OnSelectionChanged $this $this.SelectedIndex
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    hidden [void] _EnsureVisible() {
        if ($this.Items.Count -eq 0) { return }
        
        $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
        
        # Scroll up if selected item is above visible area
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        }
        # Scroll down if selected item is below visible area
        elseif ($this.SelectedIndex -gt ($this.ScrollOffset + $visibleHeight - 1)) {
            $this.ScrollOffset = $this.SelectedIndex - $visibleHeight + 1
        }
        
        # Ensure scroll offset is within bounds
        $this.ScrollOffset = [Math]::Max(0, [Math]::Min($this.ScrollOffset, $this.Items.Count - $visibleHeight))
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SetItems([hashtable[]]$items) {
        $this.Items = $items
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this.RequestRedraw()
    }
    
    [void] SetColumns([hashtable[]]$columns) {
        $this.Columns = $columns
        $this.RequestRedraw()
    }
}
#<!-- END_PAGE: ACO.022 -->

#endregion Navigation Components

#region Command Palette

# ===== CLASS: CommandPalette =====
# Module: command-palette
# Dependencies: Panel, TextBoxComponent, ListBox
# Purpose: Searchable command interface with proper focus management
class CommandPalette : Panel {
    hidden [TextBoxComponent]$_searchBox
    hidden [ListBox]$_listBox
    hidden [List[object]]$_allActions
    hidden [List[object]]$_filteredActions
    [scriptblock]$OnExecute
    [scriptblock]$OnCancel
    
    CommandPalette([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Visible = $false
        $this.IsOverlay = $true
        $this.Width = 60
        $this.Height = 20
        $this.HasBorder = $true
        $this.BorderStyle = "Double"
        $this.Title = " Command Palette "
        
        $this._allActions = [List[object]]::new()
        $this._filteredActions = [List[object]]::new()
        
        $this._CreateControls()
    }
    
    hidden [void] _CreateControls() {
        # Search box at top
        $this._searchBox = [TextBoxComponent]::new("SearchBox")
        $this._searchBox.X = 2
        $this._searchBox.Y = 2
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 3
        $this._searchBox.Placeholder = "Type to search commands..."
        $thisCommandPalette = $this
        $this._searchBox.OnChange = {
            param($sender, $text)
            $thisCommandPalette._FilterActions($text)
        }.GetNewClosure()
        $this.AddChild($this._searchBox)
        
        # Results list below search box
        $this._listBox = [ListBox]::new("ResultsList")
        $this._listBox.X = 2
        $this._listBox.Y = 6
        $this._listBox.Width = $this.Width - 4
        $this._listBox.Height = $this.Height - 8
        $this.AddChild($this._listBox)
    }
    
    [void] SetActions([object[]]$actionList) {
        $this._allActions.Clear()
        foreach ($action in $actionList) {
            $this._allActions.Add($action)
        }
        $this._FilterActions("")  # Show all actions initially
    }
    
    hidden [void] _FilterActions([string]$searchText) {
        $this._filteredActions.Clear()
        $this._listBox.ClearItems()
        
        $actionsToDisplay = if ([string]::IsNullOrWhiteSpace($searchText)) { 
            $this._allActions 
        } else {
            $searchLower = $searchText.ToLower()
            @($this._allActions | Where-Object {
                $_.Name.ToLower().Contains($searchLower) -or
                ($_.Description -and $_.Description.ToLower().Contains($searchLower)) -or
                ($_.Category -and $_.Category.ToLower().Contains($searchLower))
            })
        }

        foreach ($action in $actionsToDisplay) {
            $this._filteredActions.Add($action)
            $displayText = if ($action.Category) { 
                "[$($action.Category)] $($action.Name)" 
            } else { 
                $action.Name 
            }
            if ($action.Description) {
                $displayText += " - $($action.Description)"
            }
            $this._listBox.AddItem($displayText)
        }
        
        if ($this._filteredActions.Count -gt 0) { 
            $this._listBox.SelectedIndex = 0 
        }
        $this.RequestRedraw()
    }
    
    [void] SetInitialFocus() {
        # Clear search text and focus search box
        $this._searchBox.Text = ""
        $this._searchBox.CursorPosition = 0
        
        $focusManager = $global:TuiState.Services.FocusManager
        if ($focusManager) {
            $focusManager.SetFocus($this._searchBox)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                if ($this.OnCancel) {
                    & $this.OnCancel
                }
                return $true
            }
            ([ConsoleKey]::Enter) {
                if ($this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                    $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                    if ($selectedAction -and $this.OnExecute) {
                        & $this.OnExecute $this $selectedAction
                    }
                }
                return $true
            }
            ([ConsoleKey]::Tab) {
                # Switch focus between search box and list
                $focusManager = $global:TuiState.Services.FocusManager
                if ($focusManager) {
                    if ($this._searchBox.IsFocused) {
                        $focusManager.SetFocus($this._listBox)
                    } else {
                        $focusManager.SetFocus($this._searchBox)
                    }
                }
                return $true
            }
            {$_ -in @([ConsoleKey]::UpArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::PageUp, [ConsoleKey]::PageDown, [ConsoleKey]::Home, [ConsoleKey]::End)} {
                # Navigation keys go to the list
                $focusManager = $global:TuiState.Services.FocusManager
                if ($focusManager) {
                    $focusManager.SetFocus($this._listBox)
                }
                return $this._listBox.HandleInput($keyInfo)
            }
            default {
                # All other input goes to search box
                $focusManager = $global:TuiState.Services.FocusManager
                if ($focusManager) {
                    $focusManager.SetFocus($this._searchBox)
                }
                return $this._searchBox.HandleInput($keyInfo)
            }
        }
        return $false
    }
}

#endregion

