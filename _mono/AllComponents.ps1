# ==============================================================================
# Axiom-Phoenix v4.0 - All Components CLEAN (No Verbose)
# UI components that extend UIElement - NO VERBOSE OUTPUT
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#region Core UI Components

class LabelComponent : UIElement {
    [string]$Text = ""
    [object]$ForegroundColor

    LabelComponent([string]$name) : base($name) {
        $this.IsFocusable = $false
        $this.Width = 10
        $this.Height = 1
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = $this.ForegroundColor ?? [ConsoleColor]::White
            $bg = [ConsoleColor]::Black
            $this._private_buffer.WriteString(0, 0, $this.Text, $fg, $bg)
        }
        catch {
            # Silently handle errors in render
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $false
    }
}

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
        
        try {
            $bgColor = if ($this.IsPressed) { [ConsoleColor]::DarkGray } else { [ConsoleColor]::Black }
            $borderColor = if ($this.IsFocused) { [ConsoleColor]::Cyan } else { [ConsoleColor]::Gray }
            $fgColor = if ($this.IsPressed) { [ConsoleColor]::Black } else { [ConsoleColor]::White }

            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this._private_buffer.SetCell($x, 0, [TuiCell]::new('-', $borderColor, $bgColor))
                $this._private_buffer.SetCell($x, $this.Height - 1, [TuiCell]::new('-', $borderColor, $bgColor))
            }
            for ($y = 0; $y -lt $this.Height; $y++) {
                $this._private_buffer.SetCell(0, $y, [TuiCell]::new('|', $borderColor, $bgColor))
                $this._private_buffer.SetCell($this.Width - 1, $y, [TuiCell]::new('|', $borderColor, $bgColor))
            }
            
            $this._private_buffer.SetCell(0, 0, [TuiCell]::new('+', $borderColor, $bgColor))
            $this._private_buffer.SetCell($this.Width - 1, 0, [TuiCell]::new('+', $borderColor, $bgColor))
            $this._private_buffer.SetCell(0, $this.Height - 1, [TuiCell]::new('+', $borderColor, $bgColor))
            $this._private_buffer.SetCell($this.Width - 1, $this.Height - 1, [TuiCell]::new('+', $borderColor, $bgColor))
            
            $textX = [Math]::Floor(($this.Width - $this.Text.Length) / 2)
            $textY = [Math]::Floor(($this.Height - 1) / 2)
            $this._private_buffer.WriteString($textX, $textY, $this.Text, $fgColor, $bgColor)
        }
        catch {}
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

class TextBoxComponent : UIElement {
    [string]$Text = ""
    [string]$Placeholder = ""
    [ValidateRange(1, [int]::MaxValue)][int]$MaxLength = 100
    [int]$CursorPosition = 0
    [scriptblock]$OnChange
    hidden [int]$_scrollOffset = 0

    TextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = [ConsoleColor]::Black
            $borderColor = if ($this.IsFocused) { [ConsoleColor]::Cyan } else { [ConsoleColor]::Gray }
            $textColor = [ConsoleColor]::White
            $placeholderColor = [ConsoleColor]::DarkGray
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $textColor, $bgColor))
            
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this._private_buffer.SetCell($x, 0, [TuiCell]::new('-', $borderColor, $bgColor))
                $this._private_buffer.SetCell($x, $this.Height - 1, [TuiCell]::new('-', $borderColor, $bgColor))
            }
            for ($y = 0; $y -lt $this.Height; $y++) {
                $this._private_buffer.SetCell(0, $y, [TuiCell]::new('|', $borderColor, $bgColor))
                $this._private_buffer.SetCell($this.Width - 1, $y, [TuiCell]::new('|', $borderColor, $bgColor))
            }
            
            $this._private_buffer.SetCell(0, 0, [TuiCell]::new('+', $borderColor, $bgColor))
            $this._private_buffer.SetCell($this.Width - 1, 0, [TuiCell]::new('+', $borderColor, $bgColor))
            $this._private_buffer.SetCell(0, $this.Height - 1, [TuiCell]::new('+', $borderColor, $bgColor))
            $this._private_buffer.SetCell($this.Width - 1, $this.Height - 1, [TuiCell]::new('+', $borderColor, $bgColor))

            $textAreaWidth = $this.Width - 2
            $displayText = $this.Text ?? ""
            $currentTextColor = $textColor

            if ([string]::IsNullOrEmpty($displayText) -and -not $this.IsFocused) {
                $displayText = $this.Placeholder ?? ""
                $currentTextColor = $placeholderColor
            }

            if ($displayText.Length -gt $textAreaWidth) {
                $displayText = $displayText.Substring($this._scrollOffset, [Math]::Min($textAreaWidth, $displayText.Length - $this._scrollOffset))
            }

            if (-not [string]::IsNullOrEmpty($displayText)) {
                $this._private_buffer.WriteString(1, 1, $displayText, $currentTextColor, $bgColor)
            }

            if ($this.IsFocused) {
                $cursorX = 1 + ($this.CursorPosition - $this._scrollOffset)
                if ($cursorX -ge 1 -and $cursorX -lt ($this.Width - 1)) {
                    $cell = $this._private_buffer.GetCell($cursorX, 1)
                    if ($null -ne $cell) {
                        $cell.BackgroundColor = [ConsoleColor]::Cyan
                        $cell.ForegroundColor = [ConsoleColor]::Black
                        $this._private_buffer.SetCell($cursorX, 1, $cell)
                    }
                }
            }
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        try {
            $currentText = $this.Text ?? ""
            $cursorPos = $this.CursorPosition
            $originalText = $currentText
            $handled = $true

            switch ($key.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($cursorPos -gt 0) {
                        $this.Text = $currentText.Remove($cursorPos - 1, 1)
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($cursorPos -lt $currentText.Length) {
                        $this.Text = $currentText.Remove($cursorPos, 1)
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($cursorPos -gt 0) {
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($cursorPos -lt $this.Text.Length) {
                        $this.CursorPosition++
                    }
                }
                ([ConsoleKey]::Home) {
                    $this.CursorPosition = 0
                }
                ([ConsoleKey]::End) {
                    $this.CursorPosition = $this.Text.Length
                }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar) -and $currentText.Length -lt $this.MaxLength) {
                        $this.Text = $currentText.Insert($cursorPos, $key.KeyChar)
                        $this.CursorPosition++
                    } else {
                        $handled = $false
                    }
                }
            }

            if ($handled) {
                $this._UpdateScrollOffset()
                
                if ($this.Text -ne $originalText -and $this.OnChange) {
                    & $this.OnChange -NewValue $this.Text
                }
                
                $this.RequestRedraw()
            }
            
            return $handled
        }
        catch {
            return $false
        }
    }

    hidden [void] _UpdateScrollOffset() {
        $textAreaWidth = $this.Width - 2
        
        if ($this.CursorPosition -gt ($this._scrollOffset + $textAreaWidth - 1)) {
            $this._scrollOffset = $this.CursorPosition - $textAreaWidth + 1
        }
        
        if ($this.CursorPosition -lt $this._scrollOffset) {
            $this._scrollOffset = $this.CursorPosition
        }
        
        $maxScroll = [Math]::Max(0, $this.Text.Length - $textAreaWidth)
        $this._scrollOffset = [Math]::Min($this._scrollOffset, $maxScroll)
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
    }
}

class CheckBoxComponent : UIElement {
    [string]$Text = "Checkbox"
    [bool]$Checked = $false
    [scriptblock]$OnChange

    CheckBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = if ($this.IsFocused) { [ConsoleColor]::Cyan } else { [ConsoleColor]::White }
            $bg = [ConsoleColor]::Black
            
            $checkbox = if ($this.Checked) { "[X]" } else { "[ ]" }
            $displayText = "$checkbox $($this.Text)"
            
            $this._private_buffer.WriteString(0, 0, $displayText, $fg, $bg)
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            try {
                $this.Checked = -not $this.Checked
                
                if ($this.OnChange) {
                    & $this.OnChange -NewValue $this.Checked
                }
                
                $this.RequestRedraw()
                return $true
            }
            catch {}
        }
        return $false
    }
}

class RadioButtonComponent : UIElement {
    [string]$Text = "Option"
    [bool]$Selected = $false
    [string]$GroupName = ""
    [scriptblock]$OnChange

    RadioButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = if ($this.IsFocused) { [ConsoleColor]::Cyan } else { [ConsoleColor]::White }
            $bg = [ConsoleColor]::Black
            
            $radio = if ($this.Selected) { "(●)" } else { "( )" }
            $displayText = "$radio $($this.Text)"
            
            $this._private_buffer.WriteString(0, 0, $displayText, $fg, $bg)
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            try {
                if (-not $this.Selected) {
                    $this.Selected = $true
                    
                    if ($this.Parent -and $this.GroupName) {
                        $this.Parent.Children | Where-Object { 
                            $_ -is [RadioButtonComponent] -and $_.GroupName -eq $this.GroupName -and $_ -ne $this 
                        } | ForEach-Object {
                            $_.Selected = $false
                            $_.RequestRedraw()
                        }
                    }
                    
                    if ($this.OnChange) {
                        & $this.OnChange -NewValue $this.Selected
                    }
                    
                    $this.RequestRedraw()
                }
                return $true
            }
            catch {}
        }
        return $false
    }
}

#endregion

#region Advanced Input Components

# ===== CLASS: MultilineTextBoxComponent =====
# Module: advanced-input-components (from axiom)
# Dependencies: UIElement, theme colors
# Purpose: Full text editor with viewport scrolling
class MultilineTextBoxComponent : UIElement {
    [string[]]$Lines = @("")
    [string]$Placeholder = "Enter text..."
    [ValidateRange(1, 100)][int]$MaxLines = 10
    [ValidateRange(1, 1000)][int]$MaxLineLength = 100
    [int]$CurrentLine = 0
    [int]$CursorPosition = 0
    [scriptblock]$OnChange
    
    hidden [int]$_scrollOffsetY = 0
    hidden [int]$_scrollOffsetX = 0

    MultilineTextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 40
        $this.Height = 8
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors (fallback to default if no theme)
            $bgColor = [ConsoleColor]::Black
            $borderColor = if ($this.IsFocused) { [ConsoleColor]::Cyan } else { [ConsoleColor]::Gray }
            $fgColor = [ConsoleColor]::White
            $placeholderColor = [ConsoleColor]::DarkGray
            $cursorColor = [ConsoleColor]::Cyan
            
            # Clear buffer and draw border
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            $this._private_buffer.DrawBox(0, 0, $this.Width, $this.Height, $borderColor, $bgColor, $false)

            $textAreaHeight = $this.Height - 2
            $textAreaWidth = $this.Width - 2
            
            # Render visible lines
            for ($i = 0; $i -lt $textAreaHeight; $i++) {
                $lineIndex = $i + $this._scrollOffsetY
                if ($lineIndex -ge $this.Lines.Count) { break }
                
                $lineText = $this.Lines[$lineIndex]
                $displayLine = ""
                
                if ($lineText.Length -gt $this._scrollOffsetX) {
                    $displayLine = $lineText.Substring($this._scrollOffsetX, [Math]::Min($textAreaWidth, $lineText.Length - $this._scrollOffsetX))
                }
                
                if (-not [string]::IsNullOrEmpty($displayLine)) {
                    $this._private_buffer.WriteString(1, $i + 1, $displayLine, $fgColor, $bgColor)
                }
            }

            # Show placeholder if empty and not focused
            if ($this.Lines.Count -eq 1 -and [string]::IsNullOrEmpty($this.Lines[0]) -and -not $this.IsFocused) {
                $this._private_buffer.WriteString(1, 1, $this.Placeholder, $placeholderColor, $bgColor)
            }

            # Render cursor
            if ($this.IsFocused) {
                $cursorLineY = $this.CurrentLine - $this._scrollOffsetY
                if ($cursorLineY -ge 0 -and $cursorLineY -lt $textAreaHeight) {
                    $cursorX = 1 + ($this.CursorPosition - $this._scrollOffsetX)
                    if ($cursorX -ge 1 -and $cursorX -le $textAreaWidth) {
                        $cell = $this._private_buffer.GetCell($cursorX, $cursorLineY + 1)
                        if ($null -ne $cell) {
                            $cell.BackgroundColor = $cursorColor
                            $cell.ForegroundColor = $bgColor
                            $this._private_buffer.SetCell($cursorX, $cursorLineY + 1, $cell)
                        }
                    }
                }
            }
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        try {
            $handled = $true
            $currentLineText = $this.Lines[$this.CurrentLine]
            $originalText = $this.Lines -join "`n"
            
            switch ($key.Key) {
                ([ConsoleKey]::Enter) {
                    if ($this.Lines.Count -lt $this.MaxLines) {
                        $beforeCursor = $currentLineText.Substring(0, $this.CursorPosition)
                        $afterCursor = $currentLineText.Substring($this.CursorPosition)
                        
                        $this.Lines[$this.CurrentLine] = $beforeCursor
                        $this.Lines = $this.Lines[0..$this.CurrentLine] + @($afterCursor) + $this.Lines[($this.CurrentLine + 1)..($this.Lines.Count - 1)]
                        
                        $this.CurrentLine++
                        $this.CursorPosition = 0
                    }
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CursorPosition -gt 0) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Remove($this.CursorPosition - 1, 1)
                        $this.CursorPosition--
                    }
                    elseif ($this.CurrentLine -gt 0) {
                        $this.CursorPosition = $this.Lines[$this.CurrentLine - 1].Length
                        $this.Lines[$this.CurrentLine - 1] += $currentLineText
                        $this.Lines = $this.Lines[0..($this.CurrentLine - 1)] + $this.Lines[($this.CurrentLine + 1)..($this.Lines.Count - 1)]
                        $this.CurrentLine--
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($this.CursorPosition -lt $currentLineText.Length) {
                        $this.Lines[$this.CurrentLine] = $currentLineText.Remove($this.CursorPosition, 1)
                    }
                    elseif ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $this.Lines[$this.CurrentLine] += $this.Lines[$this.CurrentLine + 1]
                        $this.Lines = $this.Lines[0..$this.CurrentLine] + $this.Lines[($this.CurrentLine + 2)..($this.Lines.Count - 1)]
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.CursorPosition -gt 0) {
                        $this.CursorPosition--
                    }
                    elseif ($this.CurrentLine -gt 0) {
                        $this.CurrentLine--
                        $this.CursorPosition = $this.Lines[$this.CurrentLine].Length
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.CursorPosition -lt $currentLineText.Length) {
                        $this.CursorPosition++
                    }
                    elseif ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $this.CurrentLine++
                        $this.CursorPosition = 0
                    }
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this.CurrentLine -gt 0) {
                        $this.CurrentLine--
                        $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.Lines[$this.CurrentLine].Length)
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.CurrentLine -lt ($this.Lines.Count - 1)) {
                        $this.CurrentLine++
                        $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.Lines[$this.CurrentLine].Length)
                    }
                }
                ([ConsoleKey]::Home) {
                    $this.CursorPosition = 0
                }
                ([ConsoleKey]::End) {
                    $this.CursorPosition = $currentLineText.Length
                }
                ([ConsoleKey]::PageUp) {
                    $this.CurrentLine = [Math]::Max(0, $this.CurrentLine - ($this.Height - 2))
                    $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.Lines[$this.CurrentLine].Length)
                }
                ([ConsoleKey]::PageDown) {
                    $this.CurrentLine = [Math]::Min($this.Lines.Count - 1, $this.CurrentLine + ($this.Height - 2))
                    $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.Lines[$this.CurrentLine].Length)
                }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
                        $newLine = $currentLineText.Insert($this.CursorPosition, $key.KeyChar)
                        if ($newLine.Length -le $this.MaxLineLength) {
                            $this.Lines[$this.CurrentLine] = $newLine
                            $this.CursorPosition++
                        }
                    } else {
                        $handled = $false
                    }
                }
            }
            
            if ($handled) {
                $this._UpdateScrolling()
                
                # Fire change event if text changed
                $newText = $this.Lines -join "`n"
                if ($newText -ne $originalText -and $this.OnChange) {
                    & $this.OnChange -NewValue $newText
                }
                
                $this.RequestRedraw()
            }
            
            return $handled
        }
        catch {
            return $false
        }
    }

    hidden [void] _UpdateScrolling() {
        $textAreaHeight = $this.Height - 2
        $textAreaWidth = $this.Width - 2
        
        # Vertical scrolling
        if ($this.CurrentLine -lt $this._scrollOffsetY) {
            $this._scrollOffsetY = $this.CurrentLine
        }
        elseif ($this.CurrentLine -ge ($this._scrollOffsetY + $textAreaHeight)) {
            $this._scrollOffsetY = $this.CurrentLine - $textAreaHeight + 1
        }
        
        # Horizontal scrolling
        if ($this.CursorPosition -lt $this._scrollOffsetX) {
            $this._scrollOffsetX = $this.CursorPosition
        }
        elseif ($this.CursorPosition -ge ($this._scrollOffsetX + $textAreaWidth)) {
            $this._scrollOffsetX = $this.CursorPosition - $textAreaWidth + 1
        }
        
        # Ensure scroll offsets are within bounds
        $this._scrollOffsetY = [Math]::Max(0, $this._scrollOffsetY)
        $this._scrollOffsetX = [Math]::Max(0, $this._scrollOffsetX)
    }

    [string] GetText() {
        return $this.Lines -join "`n"
    }

    [void] SetText([string]$text) {
        if ([string]::IsNullOrEmpty($text)) {
            $this.Lines = @("")
        } else {
            $this.Lines = $text -split "`n"
        }
        $this.CurrentLine = 0
        $this.CursorPosition = 0
        $this._scrollOffsetY = 0
        $this._scrollOffsetX = 0
        $this.RequestRedraw()
    }
}

# ===== CLASS: NumericInputComponent =====
# Module: advanced-input-components (from axiom)
# Dependencies: UIElement
# Purpose: Numeric input with spinners and validation
class NumericInputComponent : UIElement {
    [double]$Value = 0
    [double]$MinValue = [double]::MinValue
    [double]$MaxValue = [double]::MaxValue
    [double]$Step = 1
    [int]$DecimalPlaces = 0
    [string]$Suffix = ""
    [string]$TextValue = "0"
    [int]$CursorPosition = 0
    [scriptblock]$OnChange

    NumericInputComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3
        $this.TextValue = $this.Value.ToString()
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = [ConsoleColor]::Black
            $borderColor = if ($this.IsFocused) { [ConsoleColor]::Cyan } else { [ConsoleColor]::Gray }
            $fgColor = [ConsoleColor]::White
            $suffixColor = [ConsoleColor]::DarkGray
            $cursorColor = [ConsoleColor]::Cyan
            
            # Clear buffer and draw border
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            $this._private_buffer.DrawBox(0, 0, $this.Width, $this.Height, $borderColor, $bgColor, $false)
            
            # Draw main value
            $displayText = $this.TextValue
            if (-not [string]::IsNullOrEmpty($this.Suffix)) {
                $displayText += $this.Suffix
            }
            
            $this._private_buffer.WriteString(2, 1, $displayText, $fgColor, $bgColor)
            
            # Draw spinner arrows
            $spinnerColor = if ($this.IsFocused) { $borderColor } else { [ConsoleColor]::DarkGray }
            $this._private_buffer.WriteString($this.Width - 3, 0, "▲", $spinnerColor, $bgColor)
            $this._private_buffer.WriteString($this.Width - 3, 2, "▼", $spinnerColor, $bgColor)
            
            # Draw cursor
            if ($this.IsFocused -and $this.CursorPosition -le $this.TextValue.Length) {
                $cursorX = 2 + $this.CursorPosition
                if ($cursorX -lt ($this.Width - 4)) {
                    $cell = $this._private_buffer.GetCell($cursorX, 1)
                    if ($null -ne $cell) {
                        $cell.BackgroundColor = $cursorColor
                        $cell.ForegroundColor = $bgColor
                        $this._private_buffer.SetCell($cursorX, 1, $cell)
                    }
                }
            }
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        try {
            $handled = $true
            $originalValue = $this.Value
            
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    $this.Value = [Math]::Min($this.MaxValue, $this.Value + $this.Step)
                    $this._UpdateTextValue()
                }
                ([ConsoleKey]::DownArrow) {
                    $this.Value = [Math]::Max($this.MinValue, $this.Value - $this.Step)
                    $this._UpdateTextValue()
                }
                ([ConsoleKey]::Enter) {
                    if ($this._ValidateAndSetValue($this.TextValue)) {
                        # Value was valid and set
                    }
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CursorPosition -gt 0) {
                        $this.TextValue = $this.TextValue.Remove($this.CursorPosition - 1, 1)
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($this.CursorPosition -lt $this.TextValue.Length) {
                        $this.TextValue = $this.TextValue.Remove($this.CursorPosition, 1)
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.CursorPosition -gt 0) {
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.CursorPosition -lt $this.TextValue.Length) {
                        $this.CursorPosition++
                    }
                }
                ([ConsoleKey]::Home) {
                    $this.CursorPosition = 0
                }
                ([ConsoleKey]::End) {
                    $this.CursorPosition = $this.TextValue.Length
                }
                default {
                    if ($key.KeyChar -and $this._IsValidNumericChar($key.KeyChar)) {
                        $this.TextValue = $this.TextValue.Insert($this.CursorPosition, $key.KeyChar)
                        $this.CursorPosition++
                    } else {
                        $handled = $false
                    }
                }
            }
            
            if ($handled) {
                # Fire change event if value changed
                if ($this.Value -ne $originalValue -and $this.OnChange) {
                    & $this.OnChange -NewValue $this.Value
                }
                
                $this.RequestRedraw()
            }
            
            return $handled
        }
        catch {
            return $false
        }
    }

    hidden [bool] _IsValidNumericChar([char]$char) {
        return [char]::IsDigit($char) -or $char -eq '.' -or $char -eq '-'
    }

    hidden [bool] _ValidateAndSetValue([string]$text) {
        try {
            $parsedValue = [double]::Parse($text)
            if ($parsedValue -ge $this.MinValue -and $parsedValue -le $this.MaxValue) {
                $this.Value = $parsedValue
                $this._UpdateTextValue()
                return $true
            }
        }
        catch {
            # Invalid format, revert to current value
            $this._UpdateTextValue()
        }
        return $false
    }

    hidden [void] _UpdateTextValue() {
        $this.TextValue = $this.Value.ToString("F$($this.DecimalPlaces)")
        $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.TextValue.Length)
    }
}

# ===== CLASS: DateInputComponent =====
# Module: advanced-input-components (from axiom)
# Dependencies: UIElement
# Purpose: Date picker with validation
class DateInputComponent : UIElement {
    [DateTime]$Value = (Get-Date)
    [DateTime]$MinDate = [DateTime]::MinValue
    [DateTime]$MaxDate = [DateTime]::MaxValue
    [string]$DateFormat = "yyyy-MM-dd"
    [string]$TextValue = ""
    [int]$CursorPosition = 0
    [bool]$ShowCalendar = $false
    [scriptblock]$OnChange

    DateInputComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 25
        $this.Height = 3
        $this.TextValue = $this.Value.ToString($this.DateFormat)
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = [ConsoleColor]::Black
            $borderColor = if ($this.IsFocused) { [ConsoleColor]::Cyan } else { [ConsoleColor]::Gray }
            $fgColor = [ConsoleColor]::White
            $cursorColor = [ConsoleColor]::Cyan
            
            # Clear buffer and draw border
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            $this._private_buffer.DrawBox(0, 0, $this.Width, $this.Height, $borderColor, $bgColor, $false)
            
            # Draw date value
            $this._private_buffer.WriteString(2, 1, $this.TextValue, $fgColor, $bgColor)
            
            # Draw calendar icon
            $iconColor = if ($this.IsFocused) { $borderColor } else { [ConsoleColor]::DarkGray }
            $this._private_buffer.WriteString($this.Width - 3, 1, "📅", $iconColor, $bgColor)
            
            # Draw cursor
            if ($this.IsFocused -and $this.CursorPosition -le $this.TextValue.Length) {
                $cursorX = 2 + $this.CursorPosition
                if ($cursorX -lt ($this.Width - 4)) {
                    $cell = $this._private_buffer.GetCell($cursorX, 1)
                    if ($null -ne $cell) {
                        $cell.BackgroundColor = $cursorColor
                        $cell.ForegroundColor = $bgColor
                        $this._private_buffer.SetCell($cursorX, 1, $cell)
                    }
                }
            }
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        try {
            $handled = $true
            $originalValue = $this.Value
            
            switch ($key.Key) {
                ([ConsoleKey]::Enter) {
                    if ($this._ValidateAndSetDate($this.TextValue)) {
                        # Date was valid and set
                    }
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CursorPosition -gt 0) {
                        $this.TextValue = $this.TextValue.Remove($this.CursorPosition - 1, 1)
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($this.CursorPosition -lt $this.TextValue.Length) {
                        $this.TextValue = $this.TextValue.Remove($this.CursorPosition, 1)
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.CursorPosition -gt 0) {
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.CursorPosition -lt $this.TextValue.Length) {
                        $this.CursorPosition++
                    }
                }
                ([ConsoleKey]::Home) {
                    $this.CursorPosition = 0
                }
                ([ConsoleKey]::End) {
                    $this.CursorPosition = $this.TextValue.Length
                }
                default {
                    if ($key.KeyChar -and $this._IsValidDateChar($key.KeyChar)) {
                        $this.TextValue = $this.TextValue.Insert($this.CursorPosition, $key.KeyChar)
                        $this.CursorPosition++
                    } else {
                        $handled = $false
                    }
                }
            }
            
            if ($handled) {
                # Fire change event if value changed
                if ($this.Value -ne $originalValue -and $this.OnChange) {
                    & $this.OnChange -NewValue $this.Value
                }
                
                $this.RequestRedraw()
            }
            
            return $handled
        }
        catch {
            return $false
        }
    }

    hidden [bool] _IsValidDateChar([char]$char) {
        return [char]::IsDigit($char) -or $char -eq '-' -or $char -eq '/' -or $char -eq '.'
    }

    hidden [bool] _ValidateAndSetDate([string]$text) {
        try {
            $date = [DateTime]::ParseExact($text, $this.DateFormat, $null)
            if ($date -ge $this.MinDate -and $date -le $this.MaxDate) {
                $this.Value = $date
                $this._UpdateTextValue()
                return $true
            }
        }
        catch {
            # Invalid format, revert to current value
            $this._UpdateTextValue()
        }
        return $false
    }

    hidden [void] _UpdateTextValue() {
        $this.TextValue = $this.Value.ToString($this.DateFormat)
        $this.CursorPosition = [Math]::Min($this.CursorPosition, $this.TextValue.Length)
    }
}

# ===== CLASS: ComboBoxComponent =====
# Module: advanced-input-components (from axiom)
# Dependencies: UIElement
# Purpose: Dropdown with search and overlay rendering
class ComboBoxComponent : UIElement {
    [string[]]$Items = @()
    [int]$SelectedIndex = -1
    [string]$SelectedItem = ""
    [string]$DisplayText = ""
    [string]$SearchText = ""
    [bool]$IsDropDownOpen = $false
    [bool]$AllowSearch = $true
    [ValidateRange(3, 20)][int]$MaxDropDownHeight = 8
    [int]$ScrollOffset = 0
    [scriptblock]$OnSelectionChanged
    
    hidden [TuiBuffer]$_dropdownBuffer = $null
    hidden [string[]]$_filteredItems = @()

    ComboBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 30
        $this.Height = 3
        $this._filteredItems = $this.Items
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = [ConsoleColor]::Black
            $borderColor = if ($this.IsFocused) { [ConsoleColor]::Cyan } else { [ConsoleColor]::Gray }
            $fgColor = [ConsoleColor]::White
            
            # Clear buffer and draw border
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            $this._private_buffer.DrawBox(0, 0, $this.Width, $this.Height, $borderColor, $bgColor, $false)
            
            # Draw current value or search text
            $displayValue = if ($this.IsDropDownOpen -and $this.AllowSearch) { $this.SearchText } else { $this.DisplayText }
            if (-not [string]::IsNullOrEmpty($displayValue)) {
                $maxTextWidth = $this.Width - 6
                if ($displayValue.Length -gt $maxTextWidth) {
                    $displayValue = $displayValue.Substring(0, $maxTextWidth - 3) + "..."
                }
                $this._private_buffer.WriteString(2, 1, $displayValue, $fgColor, $bgColor)
            }
            
            # Draw dropdown arrow
            $arrow = if ($this.IsDropDownOpen) { "▲" } else { "▼" }
            $arrowColor = if ($this.IsFocused) { $borderColor } else { [ConsoleColor]::DarkGray }
            $this._private_buffer.WriteString($this.Width - 3, 1, $arrow, $arrowColor, $bgColor)
            
            # Render dropdown overlay if open
            if ($this.IsDropDownOpen) {
                $this._RenderDropdownOverlay()
            }
        }
        catch {}
    }

    hidden [void] _RenderDropdownOverlay() {
        try {
            # Get theme colors
            $bgColor = [ConsoleColor]::Black
            $borderColor = [ConsoleColor]::Cyan
            $fgColor = [ConsoleColor]::White
            $selectionBg = [ConsoleColor]::Blue
            $selectionFg = [ConsoleColor]::White
            
            $dropdownHeight = [Math]::Min($this.MaxDropDownHeight, ($this._filteredItems.Count + 2))
            
            # Create or resize dropdown buffer
            if (-not $this._dropdownBuffer -or $this._dropdownBuffer.Height -ne $dropdownHeight -or $this._dropdownBuffer.Width -ne $this.Width) {
                $this._dropdownBuffer = [TuiBuffer]::new($this.Width, $dropdownHeight, "$($this.Name).Dropdown")
            }
            
            # Clear and draw dropdown
            $this._dropdownBuffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            $this._dropdownBuffer.DrawBox(0, 0, $this.Width, $dropdownHeight, $borderColor, $bgColor, $false)
            
            # Draw items
            $visibleItems = [Math]::Min($this.MaxDropDownHeight - 2, $this._filteredItems.Count)
            for ($i = 0; $i -lt $visibleItems; $i++) {
                $itemIndex = $i + $this.ScrollOffset
                if ($itemIndex -ge $this._filteredItems.Count) { break }
                
                $item = $this._filteredItems[$itemIndex]
                $isSelected = ($itemIndex -eq $this.SelectedIndex)
                
                $itemBg = if ($isSelected) { $selectionBg } else { $bgColor }
                $itemFg = if ($isSelected) { $selectionFg } else { $fgColor }
                
                # Draw selection background
                $highlightText = ' ' * ($this.Width - 2)
                $this._dropdownBuffer.WriteString(1, $i + 1, $highlightText, $itemFg, $itemBg)
                
                # Draw item text
                $itemText = " $item"
                $maxItemWidth = $this.Width - 4
                if ($itemText.Length -gt $maxItemWidth) {
                    $itemText = $itemText.Substring(0, $maxItemWidth - 3) + "..."
                }
                $this._dropdownBuffer.WriteString(2, $i + 1, $itemText, $itemFg, $itemBg)
            }
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        try {
            $handled = $true
            $originalSelection = $this.SelectedItem
            
            if ($this.IsDropDownOpen) {
                switch ($key.Key) {
                    ([ConsoleKey]::Escape) {
                        $this.IsDropDownOpen = $false
                        $this.SearchText = ""
                        $this._UpdateFilteredItems()
                    }
                    ([ConsoleKey]::Enter) {
                        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this._filteredItems.Count) {
                            $this.SelectedItem = $this._filteredItems[$this.SelectedIndex]
                            $this.DisplayText = $this.SelectedItem
                            $this.IsDropDownOpen = $false
                            $this.SearchText = ""
                            $this._UpdateFilteredItems()
                        }
                    }
                    ([ConsoleKey]::UpArrow) {
                        if ($this.SelectedIndex -gt 0) {
                            $this.SelectedIndex--
                            $this._EnsureSelectedVisible()
                        }
                    }
                    ([ConsoleKey]::DownArrow) {
                        if ($this.SelectedIndex -lt ($this._filteredItems.Count - 1)) {
                            $this.SelectedIndex++
                            $this._EnsureSelectedVisible()
                        }
                    }
                    ([ConsoleKey]::Backspace) {
                        if ($this.AllowSearch -and $this.SearchText.Length -gt 0) {
                            $this.SearchText = $this.SearchText.Substring(0, $this.SearchText.Length - 1)
                            $this._UpdateFilteredItems()
                        }
                    }
                    default {
                        if ($this.AllowSearch -and $key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
                            $this.SearchText += $key.KeyChar
                            $this._UpdateFilteredItems()
                        } else {
                            $handled = $false
                        }
                    }
                }
            } else {
                switch ($key.Key) {
                    ([ConsoleKey]::Enter) {
                        $this.IsDropDownOpen = $true
                        $this.SelectedIndex = 0
                        $this._UpdateFilteredItems()
                    }
                    ([ConsoleKey]::Spacebar) {
                        $this.IsDropDownOpen = $true
                        $this.SelectedIndex = 0
                        $this._UpdateFilteredItems()
                    }
                    ([ConsoleKey]::DownArrow) {
                        $this.IsDropDownOpen = $true
                        $this.SelectedIndex = 0
                        $this._UpdateFilteredItems()
                    }
                    default {
                        $handled = $false
                    }
                }
            }
            
            if ($handled) {
                # Fire selection changed event
                if ($this.SelectedItem -ne $originalSelection -and $this.OnSelectionChanged) {
                    & $this.OnSelectionChanged -SelectedItem $this.SelectedItem
                }
                
                $this.RequestRedraw()
            }
            
            return $handled
        }
        catch {
            return $false
        }
    }

    hidden [void] _UpdateFilteredItems() {
        if ([string]::IsNullOrWhiteSpace($this.SearchText)) {
            $this._filteredItems = $this.Items
        } else {
            $this._filteredItems = $this.Items | Where-Object { $_ -like "*$($this.SearchText)*" }
        }
        
        # Reset selection if current selection is no longer valid
        if ($this.SelectedIndex -ge $this._filteredItems.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this._filteredItems.Count - 1)
        }
        
        $this.ScrollOffset = 0
    }

    hidden [void] _EnsureSelectedVisible() {
        $visibleItems = $this.MaxDropDownHeight - 2
        
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        }
        elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $visibleItems)) {
            $this.ScrollOffset = $this.SelectedIndex - $visibleItems + 1
        }
    }

    [void] SetItems([string[]]$items) {
        $this.Items = $items
        $this._filteredItems = $items
        $this.SelectedIndex = -1
        $this.SelectedItem = ""
        $this.DisplayText = ""
        $this.RequestRedraw()
    }
}

#endregion

#region Data Components

# ===== CLASS: TableColumn =====
# Module: advanced-data-components (from axiom)
# Dependencies: None
# Purpose: Defines a column for the Table component
class TableColumn {
    [string]$Key
    [string]$Header
    [object]$Width # Can be [int] or the string 'Auto'
    [string]$Alignment = "Left"

    TableColumn([string]$key, [string]$header, [object]$width) {
        if ([string]::IsNullOrWhiteSpace($key)) { throw [System.ArgumentException]::new("Parameter 'key' cannot be null or empty.") }
        if ([string]::IsNullOrWhiteSpace($header)) { throw [System.ArgumentException]::new("Parameter 'header' cannot be null or empty.") }
        if ($null -eq $width) { throw [System.ArgumentNullException]::new("width") }

        $this.Key = $key
        $this.Header = $header
        $this.Width = $width
    }

    [string] ToString() {
        return "TableColumn(Key='$($this.Key)', Header='$($this.Header)', Width=$($this.Width))"
    }
}

# ===== CLASS: Table =====
# Module: advanced-data-components (from axiom)
# Dependencies: UIElement, TableColumn
# Purpose: High-performance data grid with virtual scrolling
class Table : UIElement {
    [System.Collections.Generic.List[TableColumn]]$Columns
    [object[]]$Data = @()
    [int]$SelectedIndex = 0
    [bool]$ShowBorder = $true
    [bool]$ShowHeader = $true
    [scriptblock]$OnSelectionChanged
    hidden [int]$_scrollOffset = 0 # The index of the first visible row

    Table([string]$name) : base($name) {
        $this.Columns = [System.Collections.Generic.List[TableColumn]]::new()
        $this.IsFocusable = $true
        $this.Width = 60
        $this.Height = 15
    }

    [void] SetColumns([TableColumn[]]$columns) {
        try {
            if ($null -eq $columns) { throw [System.ArgumentNullException]::new("columns") }
            $this.Columns.Clear()
            foreach ($col in $columns) {
                $this.Columns.Add($col)
            }
            $this.RequestRedraw()
        }
        catch {
            throw
        }
    }

    [void] SetData([object[]]$data) {
        try {
            if ($null -eq $data) { throw [System.ArgumentNullException]::new("data") }
            $this.Data = @($data) # Consistently cast to an array
            if ($this.SelectedIndex -ge $this.Data.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.Data.Count - 1)
            }
            $this._scrollOffset = 0 # Reset scroll on new data
            $this.RequestRedraw()
        }
        catch {
            throw
        }
    }

    [void] SelectNext() {
        if ($this.SelectedIndex -lt ($this.Data.Count - 1)) {
            $this.SelectedIndex++
            $this._EnsureVisible()
            $this.RequestRedraw()
        }
    }

    [void] SelectPrevious() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this._EnsureVisible()
            $this.RequestRedraw()
        }
    }

    [object] GetSelectedItem() {
        if ($this.Data.Count -gt 0 -and $this.SelectedIndex -in (0..($this.Data.Count - 1))) {
            return $this.Data[$this.SelectedIndex]
        }
        return $null
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear buffer with theme-aware colors
            $bgColor = [ConsoleColor]::Black
            $fgColor = [ConsoleColor]::White
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            
            # Draw border if enabled
            if ($this.ShowBorder) {
                $borderColor = [ConsoleColor]::Gray
                $this._private_buffer.DrawBox(0, 0, $this.Width, $this.Height, $borderColor, $bgColor, $false)
            }

            $contentWidth = if ($this.ShowBorder) { $this.Width - 2 } else { $this.Width }
            $contentHeight = $this._GetContentHeight()
            $renderX = if ($this.ShowBorder) { 1 } else { 0 }
            $currentY = if ($this.ShowBorder) { 1 } else { 0 }
            
            # Resolve auto-sized column widths
            $resolvedColumns = $this._ResolveColumnWidths($contentWidth)
            
            # Header
            if ($this.ShowHeader -and $resolvedColumns.Count -gt 0) {
                $headerColor = [ConsoleColor]::Cyan
                $xOffset = 0
                foreach ($col in $resolvedColumns) {
                    $headerText = $this._FormatCell($col.Header, $col.ResolvedWidth, $col.Alignment)
                    $this._private_buffer.WriteString($renderX + $xOffset, $currentY, $headerText, $headerColor, $bgColor)
                    $xOffset += $col.ResolvedWidth
                }
                $currentY++
            }
            
            # Data rows (respecting scroll offset)
            for ($i = 0; $i -lt $contentHeight; $i++) {
                $dataIndex = $i + $this._scrollOffset
                if ($dataIndex -ge $this.Data.Count) { break }
                $row = $this.Data[$dataIndex]
                if (-not $row) { continue }

                $isSelected = ($dataIndex -eq $this.SelectedIndex)
                $bg = if ($isSelected -and $this.IsFocused) { [ConsoleColor]::Blue } else { $bgColor }
                $fg = if ($isSelected -and $this.IsFocused) { [ConsoleColor]::White } else { $fgColor }

                $xOffset = 0
                foreach ($col in $resolvedColumns) {
                    $propValue = $row | Select-Object -ExpandProperty $col.Key -ErrorAction SilentlyContinue
                    $cellValue = if ($propValue) { $propValue.ToString() } else { "" }
                    $cellText = $this._FormatCell($cellValue, $col.ResolvedWidth, $col.Alignment)
                    $this._private_buffer.WriteString($renderX + $xOffset, $currentY, $cellText, $fg, $bg)
                    $xOffset += $col.ResolvedWidth
                }
                $currentY++
            }

            # Show message if no data
            if ($this.Data.Count -eq 0) {
                $subtleColor = [ConsoleColor]::DarkGray
                $this._private_buffer.WriteString($renderX, $currentY, " (No data to display) ", $subtleColor, $bgColor)
            }
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        try {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) { 
                    $this.SelectPrevious()
                    return $true
                }
                ([ConsoleKey]::DownArrow) { 
                    $this.SelectNext()
                    return $true
                }
                ([ConsoleKey]::PageUp) { 
                    0..($this._GetContentHeight() - 1) | ForEach-Object { $this.SelectPrevious() }
                    return $true
                }
                ([ConsoleKey]::PageDown) { 
                    0..($this._GetContentHeight() - 1) | ForEach-Object { $this.SelectNext() }
                    return $true
                }
                ([ConsoleKey]::Home) { 
                    $this.SelectedIndex = 0
                    $this._EnsureVisible()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::End) { 
                    $this.SelectedIndex = $this.Data.Count - 1
                    $this._EnsureVisible()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($this.OnSelectionChanged) {
                        $item = $this.GetSelectedItem()
                        if ($item) {
                            & $this.OnSelectionChanged -SelectedItem $item
                        }
                    }
                    return $true
                }
            }
        }
        catch {}
        return $false
    }
    
    # Ensure the selected item is visible in the viewport
    hidden [void] _EnsureVisible() {
        $contentHeight = $this._GetContentHeight()
        
        # Scroll down if selected item is below visible area
        if ($this.SelectedIndex -ge ($this._scrollOffset + $contentHeight)) {
            $this._scrollOffset = $this.SelectedIndex - $contentHeight + 1
        }
        
        # Scroll up if selected item is above visible area
        if ($this.SelectedIndex -lt $this._scrollOffset) {
            $this._scrollOffset = $this.SelectedIndex
        }
        
        # Ensure scroll offset is within bounds
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
    }
    
    # Calculate available height for content (excluding border and header)
    hidden [int] _GetContentHeight() {
        $h = $this.Height
        if ($this.ShowBorder) { $h -= 2 }
        if ($this.ShowHeader) { $h -= 1 }
        return [Math]::Max(0, $h)
    }

    # Format cell content with proper alignment and overflow handling
    hidden [string] _FormatCell([string]$text, [int]$width, [string]$alignment) {
        if ([string]::IsNullOrEmpty($text)) { return ' ' * $width }
        
        # Handle overflow with ellipsis
        if ($text.Length -gt $width) { 
            $text = $text.Substring(0, $width - 1) + '…' 
        }
        
        # Apply alignment
        $result = switch ($alignment.ToLower()) {
            'right' { $text.PadLeft($width) }
            'center' { 
                $pad = [Math]::Max(0, ($width - $text.Length) / 2)
                $padded = (' ' * $pad) + $text
                $padded.PadRight($width)
            }
            default { $text.PadRight($width) }
        }
        return $result
    }
    
    # Resolve column widths, handling 'Auto' sizing
    hidden [object[]] _ResolveColumnWidths([int]$totalWidth) {
        $fixedWidth = 0
        $autoCols = @()
        $resolved = @()

        # First pass: calculate fixed widths and identify auto columns
        foreach ($col in $this.Columns) {
            if ($col.Width -is [int]) {
                $fixedWidth += $col.Width
                $resolved += [pscustomobject]@{ 
                    Original = $col
                    ResolvedWidth = $col.Width
                    Key = $col.Key
                    Header = $col.Header
                    Alignment = $col.Alignment
                }
            } else {
                $autoCols += $col
            }
        }

        # Second pass: distribute remaining width among auto columns
        if ($autoCols.Count -gt 0) {
            $remainingWidth = $totalWidth - $fixedWidth
            $autoWidth = [Math]::Max(1, [Math]::Floor($remainingWidth / $autoCols.Count))
            
            foreach ($col in $autoCols) {
                $resolved += [pscustomobject]@{ 
                    Original = $col
                    ResolvedWidth = $autoWidth
                    Key = $col.Key
                    Header = $col.Header
                    Alignment = $col.Alignment
                }
            }
        }

        # Return in original column order
        $orderedResolved = @()
        foreach ($originalCol in $this.Columns) {
            $matchedCol = $resolved | Where-Object { $_.Original -eq $originalCol } | Select-Object -First 1
            if ($matchedCol) {
                $orderedResolved += $matchedCol
            }
        }
        
        return $orderedResolved
    }
}

#endregion

#region Dialog System

# ===== CLASS: Dialog =====
# Module: dialog-system-class (from axiom)
# Dependencies: UIElement
# Purpose: Base dialog class with promise-based API
class Dialog : UIElement {
    [string] $Title = "Dialog"
    [string] $Message = ""
    hidden [object] $_result = $null
    hidden [bool] $_isClosed = $false

    Dialog([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 50
        $this.Height = 10
    }

    [void] Show() {
        try {
            # Center the dialog on screen
            $this.X = [Math]::Floor(($global:TuiState.BufferWidth - $this.Width) / 2)
            $this.Y = [Math]::Floor(($global:TuiState.BufferHeight - $this.Height) / 4)
            
            # Show as overlay
            if (Get-Command 'Show-TuiOverlay' -ErrorAction SilentlyContinue) {
                Show-TuiOverlay -Element $this
            }
            if (Get-Command 'Set-ComponentFocus' -ErrorAction SilentlyContinue) {
                Set-ComponentFocus -Component $this
            }
        }
        catch {}
    }

    [void] Close([object]$result, [bool]$wasCancelled = $false) {
        try {
            $this._result = $result
            $this._isClosed = $true
            
            if (Get-Command 'Close-TopTuiOverlay' -ErrorAction SilentlyContinue) {
                Close-TopTuiOverlay
            }
        }
        catch {}
    }

    [void] OnRender() {
        if (-not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = [ConsoleColor]::Black
            $borderColor = [ConsoleColor]::Gray
            $titleColor = [ConsoleColor]::Cyan
            
            # Clear buffer with higher z-index for proper overlay rendering
            $clearCell = [TuiCell]::new(' ', $titleColor, $bgColor)
            $clearCell.ZIndex = 100  # Ensure dialog is above background content
            $this._private_buffer.Clear($clearCell)
            
            # Draw dialog box
            $this._private_buffer.DrawBox(0, 0, $this.Width, $this.Height, $borderColor, $bgColor, $true)
            
            # Draw title
            if (-not [string]::IsNullOrWhiteSpace($this.Title)) {
                $titleText = " $($this.Title) "
                $titleX = [Math]::Floor(($this.Width - $titleText.Length) / 2)
                $this._private_buffer.WriteString($titleX, 0, $titleText, $titleColor, $bgColor)
            }
            
            # Render message if present
            if (-not [string]::IsNullOrWhiteSpace($this.Message)) {
                $this._RenderMessage()
            }
            
            # Allow subclasses to render their specific content
            $this.RenderDialogContent()
        }
        catch {}
    }

    hidden [void] _RenderMessage() {
        try {
            $messageColor = [ConsoleColor]::White
            $bgColor = [ConsoleColor]::Black
            
            $messageY = 2
            $messageX = 2
            $maxWidth = $this.Width - 4
            
            # Simple word wrap
            $words = $this.Message -split ' '
            $lines = @()
            $currentLine = ""
            
            foreach ($word in $words) {
                $testLine = if ($currentLine) { "$currentLine $word" } else { $word }
                if ($testLine.Length -le $maxWidth) {
                    $currentLine = $testLine
                } else {
                    if ($currentLine) { $lines += $currentLine }
                    $currentLine = $word
                }
            }
            if ($currentLine) { $lines += $currentLine }
            
            foreach ($line in $lines) {
                if ($messageY -ge ($this.Height - 3)) { break }
                $this._private_buffer.WriteString($messageX, $messageY, $line, $messageColor, $bgColor)
                $messageY++
            }
        }
        catch {}
    }

    # Virtual method for subclasses to render their specific content
    [void] RenderDialogContent() { 
        # Override in subclasses
    }

    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Close($null, $true)
            return $true
        }
        return $false
    }
}

# ===== CLASS: AlertDialog =====
# Module: dialog-system-class (from axiom)
# Dependencies: Dialog
# Purpose: Simple message dialog with OK button
class AlertDialog : Dialog {
    AlertDialog([string]$title, [string]$message) : base("AlertDialog") {
        $this.Title = $title
        $this.Message = $message
        $this.Height = 8
        $this.Width = [Math]::Min(70, [Math]::Max(40, $message.Length + 10))
    }

    [void] RenderDialogContent() {
        try {
            # Get theme colors for button
            $buttonFg = [ConsoleColor]::Black
            $buttonBg = [ConsoleColor]::Cyan
            
            $buttonY = $this.Height - 2
            $buttonLabel = " [ OK ] "
            $buttonX = [Math]::Floor(($this.Width - $buttonLabel.Length) / 2)
            
            $this._private_buffer.WriteString($buttonX, $buttonY, $buttonLabel, $buttonFg, $buttonBg)
        }
        catch {}
    }

    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            $this.Close($true)
            return $true
        }
        return ([Dialog]$this).HandleInput($key)
    }
}

# ===== CLASS: ConfirmDialog =====
# Module: dialog-system-class (from axiom)
# Dependencies: Dialog
# Purpose: Confirmation dialog with Yes/No buttons
class ConfirmDialog : Dialog {
    hidden [int] $_selectedButton = 0

    ConfirmDialog([string]$title, [string]$message) : base("ConfirmDialog") {
        $this.Title = $title
        $this.Message = $message
        $this.Height = 8
        $this.Width = [Math]::Min(70, [Math]::Max(50, $message.Length + 10))
    }

    [void] RenderDialogContent() {
        try {
            # Get theme colors
            $normalFg = [ConsoleColor]::White
            $normalBg = [ConsoleColor]::Black
            $focusFg = [ConsoleColor]::Black
            $focusBg = [ConsoleColor]::Cyan
            
            $buttonY = $this.Height - 3
            $buttons = @("  Yes  ", "  No   ")
            $startX = [Math]::Floor(($this.Width - 24) / 2)
            
            for ($i = 0; $i -lt $buttons.Count; $i++) {
                $isFocused = ($i -eq $this._selectedButton)
                $label = if ($isFocused) { "[ $($buttons[$i].Trim()) ]" } else { $buttons[$i] }
                $fg = if ($isFocused) { $focusFg } else { $normalFg }
                $bg = if ($isFocused) { $focusBg } else { $normalBg }
                
                $this._private_buffer.WriteString($startX + ($i * 14), $buttonY, $label, $fg, $bg)
            }
        }
        catch {}
    }

    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            { $_ -in @([ConsoleKey]::LeftArrow, [ConsoleKey]::RightArrow, [ConsoleKey]::Tab) } {
                $this._selectedButton = ($this._selectedButton + 1) % 2
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Enter) {
                $result = ($this._selectedButton -eq 0) # True for Yes, False for No
                $this.Close($result)
                return $true
            }
        }
        return ([Dialog]$this).HandleInput($key)
    }
}

# ===== CLASS: InputDialog =====
# Module: dialog-system-class (from axiom)
# Dependencies: Dialog, TextBoxComponent
# Purpose: Text input dialog
class InputDialog : Dialog {
    hidden [TextBoxComponent] $_textBox
    
    InputDialog([string]$title, [string]$message, [string]$defaultValue = "") : base("InputDialog") {
        $this.Title = $title
        $this.Message = $message
        $this.Height = 10
        $this.Width = [Math]::Min(70, [Math]::Max(50, $message.Length + 20))
        # Store default value in metadata for use during initialization
        $this.Metadata.DefaultValue = $defaultValue
    }

    # Create child components during the Initialize lifecycle hook
    [void] OnInitialize() {
        try {
            $this._textBox = [TextBoxComponent]::new('DialogInput')
            $this._textBox.Text = $this.Metadata.DefaultValue
            $this._textBox.Width = $this.Width - 4
            $this._textBox.Height = 3
            $this._textBox.X = 2
            $this._textBox.Y = 4
            $this.AddChild($this._textBox)
        }
        catch {}
    }

    [void] OnResize([int]$newWidth, [int]$newHeight) {
        if ($this._textBox) {
            $this._textBox.Move(2, 4)
            $this._textBox.Resize($newWidth - 4, 3)
        }
    }

    [void] RenderDialogContent() {
        try {
            # The textbox is a child, so the base UIElement.Render() will handle it.
            # We just need to render the buttons.
            $normalFg = [ConsoleColor]::White
            $focusFg = [ConsoleColor]::Cyan
            $bgColor = [ConsoleColor]::Black
            
            $buttonY = $this.Height - 2
            $okLabel = "[ OK ]"
            $cancelLabel = "[ Cancel ]"
            $startX = $this.Width - $okLabel.Length - $cancelLabel.Length - 6
            
            $this._private_buffer.WriteString($startX, $buttonY, $okLabel, $focusFg, $bgColor)
            $this._private_buffer.WriteString($startX + $okLabel.Length + 2, $buttonY, $cancelLabel, $normalFg, $bgColor)
        }
        catch {}
    }

    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter) {
            $result = if ($this._textBox) { $this._textBox.Text } else { "" }
            $this.Close($result)
            return $true
        }
        
        # Let the textbox handle all other input
        if ($this._textBox -and $this._textBox.HandleInput($key)) {
            return $true
        }
        
        return ([Dialog]$this).HandleInput($key)
    }
}

#endregion

#region Navigation Menu

# ===== CLASS: NavigationMenu =====
# Module: navigation-class (from axiom)
# Dependencies: UIElement, NavigationItem (from AllModels.ps1)
# Purpose: Contextual navigation menu component
class NavigationMenu : UIElement {
    [System.Collections.Generic.List[NavigationItem]]$Items
    [ValidateSet("Vertical", "Horizontal")][string]$Orientation = "Vertical"
    [string]$Separator = " | "
    [int]$SelectedIndex = 0

    NavigationMenu([string]$name) : base($name) {
        $this.Items = [System.Collections.Generic.List[NavigationItem]]::new()
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 10
    }

    [void] AddItem([NavigationItem]$item) {
        try {
            if (-not $item) {
                throw [System.ArgumentNullException]::new("item")
            }
            
            # Check for duplicate keys
            $existingItem = $this.Items | Where-Object { $_.Key -eq $item.Key }
            if ($existingItem) {
                throw [System.InvalidOperationException]::new("Item with key '$($item.Key)' already exists")
            }
            
            $this.Items.Add($item)
            $this.RequestRedraw()
        }
        catch {
            throw
        }
    }

    [void] AddSeparator() {
        try {
            $separatorItem = [NavigationItem]::new("-", "---", {})
            $separatorItem.Enabled = $false
            $this.Items.Add($separatorItem)
            $this.RequestRedraw()
        }
        catch {}
    }

    [void] RemoveItem([string]$key) {
        try {
            if ([string]::IsNullOrWhiteSpace($key)) { return }
            $item = $this.Items | Where-Object { $_.Key -eq $key.ToUpper() }
            if ($item) {
                $this.Items.Remove($item)
                
                # Adjust selected index if needed
                if ($this.SelectedIndex -ge $this.Items.Count) {
                    $this.SelectedIndex = [Math]::Max(0, $this.Items.Count - 1)
                }
                
                $this.RequestRedraw()
            }
        }
        catch {}
    }

    [NavigationItem] GetItem([string]$key) {
        if ([string]::IsNullOrWhiteSpace($key)) { return $null }
        return $this.Items | Where-Object { $_.Key -eq $key.ToUpper() } | Select-Object -First 1
    }

    [void] ExecuteSelectedItem() {
        try {
            $visibleItems = @($this.Items | Where-Object { $_.Visible })
            if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $visibleItems.Count) {
                $selectedItem = $visibleItems[$this.SelectedIndex]
                if ($selectedItem.Enabled -and $selectedItem.Key -ne "-") {
                    $selectedItem.Execute()
                }
            }
        }
        catch {}
    }

    [void] ExecuteByKey([string]$key) {
        try {
            if ([string]::IsNullOrWhiteSpace($key)) { return }
            $item = $this.GetItem($key)
            if ($item -and $item.Enabled -and $item.Visible) {
                $item.Execute()
            }
        }
        catch {}
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = [ConsoleColor]::Black
            $fgColor = [ConsoleColor]::White
            
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            
            $visibleItems = @($this.Items | Where-Object { $_.Visible })
            if ($visibleItems.Count -eq 0) {
                return
            }

            # Ensure selected index is valid
            if ($this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $visibleItems.Count) {
                $this.SelectedIndex = 0
            }

            if ($this.Orientation -eq "Horizontal") {
                $this._RenderHorizontal($visibleItems)
            } else {
                $this._RenderVertical($visibleItems)
            }
        }
        catch {}
    }

    hidden [void] _RenderHorizontal([NavigationItem[]]$items) {
        try {
            $currentX = 0
            $maxY = 0
            
            for ($i = 0; $i -lt $items.Count; $i++) {
                if ($currentX -ge $this.Width) { break }
                
                $item = $items[$i]
                $isSelected = ($i -eq $this.SelectedIndex)
                $isFocused = ($isSelected -and $this.IsFocused)
                
                # Get colors based on state
                $itemFg = if (-not $item.Enabled) {
                    [ConsoleColor]::DarkGray
                } elseif ($isFocused) {
                    [ConsoleColor]::Black
                } else {
                    [ConsoleColor]::White
                }
                
                $itemBg = if ($isFocused) {
                    [ConsoleColor]::Cyan
                } else {
                    [ConsoleColor]::Black
                }
                
                # Format item text
                $text = if ($item.Key -eq "-") {
                    "---"
                } else {
                    "[$($item.Key)] $($item.Label)"
                }
                
                # Draw item
                $textLength = [Math]::Min($text.Length, $this.Width - $currentX)
                $displayText = $text.Substring(0, $textLength)
                
                $this._private_buffer.WriteString($currentX, 0, $displayText, $itemFg, $itemBg)
                $currentX += $textLength
                
                # Add separator if not last item and space available
                if ($i -lt ($items.Count - 1) -and ($currentX + $this.Separator.Length) -lt $this.Width) {
                    $separatorColor = [ConsoleColor]::DarkGray
                    $this._private_buffer.WriteString($currentX, 0, $this.Separator, $separatorColor, [ConsoleColor]::Black)
                    $currentX += $this.Separator.Length
                }
            }
        }
        catch {}
    }

    hidden [void] _RenderVertical([NavigationItem[]]$items) {
        try {
            $maxItems = [Math]::Min($items.Count, $this.Height)
            
            for ($i = 0; $i -lt $maxItems; $i++) {
                $item = $items[$i]
                $isSelected = ($i -eq $this.SelectedIndex)
                $isFocused = ($isSelected -and $this.IsFocused)
                
                # Handle separators
                if ($item.Key -eq "-") {
                    $separatorColor = [ConsoleColor]::DarkGray
                    $line = '─' * $this.Width
                    $this._private_buffer.WriteString(0, $i, $line, $separatorColor, [ConsoleColor]::Black)
                    continue
                }
                
                # Get colors based on state
                $itemBg = if ($isFocused) {
                    [ConsoleColor]::Cyan
                } else {
                    [ConsoleColor]::Black
                }
                
                $prefixFg = if ($isFocused) {
                    [ConsoleColor]::Black
                } else {
                    [ConsoleColor]::Cyan
                }
                
                $keyFg = if (-not $item.Enabled) {
                    [ConsoleColor]::DarkGray
                } elseif ($isFocused) {
                    [ConsoleColor]::Black
                } else {
                    [ConsoleColor]::Cyan
                }
                
                $labelFg = if (-not $item.Enabled) {
                    [ConsoleColor]::DarkGray
                } elseif ($isFocused) {
                    [ConsoleColor]::Black
                } else {
                    [ConsoleColor]::White
                }
                
                # Draw selection highlight background
                $highlightText = ' ' * $this.Width
                $this._private_buffer.WriteString(0, $i, $highlightText, $labelFg, $itemBg)
                
                # Draw selection prefix
                $prefix = if ($isSelected) { "> " } else { "  " }
                $this._private_buffer.WriteString(0, $i, $prefix, $prefixFg, $itemBg)
                
                # Draw hotkey
                $keyText = "[$($item.Key)]"
                $this._private_buffer.WriteString(2, $i, $keyText, $keyFg, $itemBg)
                
                # Draw label
                $labelX = 2 + $keyText.Length + 1
                $maxLabelWidth = $this.Width - $labelX
                $labelText = $item.Label
                if ($labelText.Length -gt $maxLabelWidth) {
                    $labelText = $labelText.Substring(0, $maxLabelWidth - 3) + "..."
                }
                $this._private_buffer.WriteString($labelX, $i, $labelText, $labelFg, $itemBg)
            }
        }
        catch {}
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        try {
            $visibleItems = @($this.Items | Where-Object { $_.Visible })
            if ($visibleItems.Count -eq 0) {
                return $false
            }
            
            # Handle direct hotkey access
            $keyChar = $keyInfo.KeyChar.ToString().ToUpper()
            $hotkeyItem = $visibleItems | Where-Object { $_.Key -eq $keyChar -and $_.Enabled }
            if ($hotkeyItem) {
                $hotkeyItem.Execute()
                return $true
            }
            
            # Handle navigation keys
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Enter) {
                    $this.ExecuteSelectedItem()
                    return $true
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this.Orientation -eq "Vertical") {
                        $this._MovePrevious($visibleItems)
                        return $true
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.Orientation -eq "Vertical") {
                        $this._MoveNext($visibleItems)
                        return $true
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.Orientation -eq "Horizontal") {
                        $this._MovePrevious($visibleItems)
                        return $true
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.Orientation -eq "Horizontal") {
                        $this._MoveNext($visibleItems)
                        return $true
                    }
                }
                ([ConsoleKey]::Home) {
                    $this.SelectedIndex = 0
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::End) {
                    $this.SelectedIndex = $visibleItems.Count - 1
                    $this.RequestRedraw()
                    return $true
                }
            }
            
            return $false
        }
        catch {
            return $false
        }
    }

    hidden [void] _MovePrevious([NavigationItem[]]$items) {
        do {
            $this.SelectedIndex = if ($this.SelectedIndex -le 0) { $items.Count - 1 } else { $this.SelectedIndex - 1 }
        } while ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $items.Count -and (-not $items[$this.SelectedIndex].Enabled -or $items[$this.SelectedIndex].Key -eq "-"))
        
        $this.RequestRedraw()
    }

    hidden [void] _MoveNext([NavigationItem[]]$items) {
        do {
            $this.SelectedIndex = if ($this.SelectedIndex -ge ($items.Count - 1)) { 0 } else { $this.SelectedIndex + 1 }
        } while ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $items.Count -and (-not $items[$this.SelectedIndex].Enabled -or $items[$this.SelectedIndex].Key -eq "-"))
        
        $this.RequestRedraw()
    }

    [void] OnFocus() {
        ([UIElement]$this).OnFocus()
        $this.RequestRedraw()
    }

    [void] OnBlur() {
        ([UIElement]$this).OnBlur()
        $this.RequestRedraw()
    }
}

#endregion

#region ListBox Component

class ListBox : UIElement {
    [System.Collections.Generic.List[string]] $Items
    [int] $SelectedIndex = -1
    $BackgroundColor = [ConsoleColor]::Black
    $ForegroundColor = [ConsoleColor]::White
    $SelectedBackgroundColor = [ConsoleColor]::Blue
    $SelectedForegroundColor = [ConsoleColor]::White
    [int] $ScrollOffset = 0
    
    ListBox([int]$x, [int]$y, [int]$width, [int]$height) : base($x, $y, $width, $height) {
        $this.Items = [System.Collections.Generic.List[string]]::new()
        $this.IsFocusable = $true
    }
    
    [void] AddItem([string]$item) {
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
        
        $this._private_buffer.Clear([TuiCell]::new(' ', $this.ForegroundColor, $this.BackgroundColor))
        
        $visibleItems = [Math]::Min($this.Height, $this.Items.Count - $this.ScrollOffset)
        
        for ($i = 0; $i -lt $visibleItems; $i++) {
            $itemIndex = $i + $this.ScrollOffset
            $item = $this.Items[$itemIndex]
            
            $isSelected = ($itemIndex -eq $this.SelectedIndex)
            $fg = if ($isSelected) { $this.SelectedForegroundColor } else { $this.ForegroundColor }
            $bg = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.BackgroundColor }
            
            # Fill the entire line with background color
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this._private_buffer.SetCell($x, $i, [TuiCell]::new(' ', $fg, $bg))
            }
            
            # Draw the text
            $displayText = if ($item.Length -gt $this.Width) { 
                $item.Substring(0, $this.Width - 3) + "..."
            } else { 
                $item 
            }
            $this._private_buffer.WriteString(0, $i, $displayText, $fg, $bg)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or $this.Items.Count -eq 0) { return $false }
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureVisible()
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectedIndex++
                    $this.EnsureVisible()
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this.ScrollOffset = 0
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
                $this.EnsureVisible()
                $this.RequestRedraw()
                return $true
            }
        }
        return $false
    }
    
    hidden [void] EnsureVisible() {
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        }
        elseif ($this.SelectedIndex -ge $this.ScrollOffset + $this.Height) {
            $this.ScrollOffset = $this.SelectedIndex - $this.Height + 1
        }
    }
}

#endregion

#region TextBox Component

class TextBox : TextBoxComponent {
    # Wrapper class to match CommandPalette's expectations
    
    TextBox([int]$x, [int]$y, [int]$width, [string]$placeholder) : base("TextBox") {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = 3
        $this.Placeholder = $placeholder
    }
    
    [void] Clear() {
        $this.Text = ""
        $this.CursorPosition = 0
        $this.RequestRedraw()
    }
    
    [void] Focus() {
        $this.IsFocused = $true
        $global:TuiState.FocusedComponent = $this
        $this.RequestRedraw()
    }
}

#endregion

#region CommandPalette Component

class CommandPalette : UIElement {
    hidden [ListBox] $_listBox
    hidden [TextBox] $_searchBox
    hidden [Panel] $_panel
    hidden [ActionService] $_actionService
    hidden [System.Collections.Generic.List[hashtable]] $_filteredActions
    hidden [bool] $_isVisible = $false
    
    CommandPalette([ActionService]$actionService) : base("CommandPalette") {
        $this._actionService = $actionService
        $this.IsFocusable = $true
        $this.ZIndex = 1000  # Always on top
        
        # Size and position (centered overlay)
        $this.Width = 60
        $this.Height = 20
        
        # Create panel
        $this._panel = [Panel]::new(0, 0, $this.Width, $this.Height, "Command Palette")
        $this._panel.BorderStyle = "Double"
        $this._panel.BorderColor = "#00FF00"  # Truecolor green
        $this._panel.BackgroundColor = "#1a1a1a"  # Dark background
        $this._panel.TitleColor = "#FFFF00"  # Yellow title
        $this.AddChild($this._panel)
        
        # Create search box
        $this._searchBox = [TextBox]::new(2, 2, $this.Width - 4, "Search commands...")
        $this._searchBox.BackgroundColor = "#2a2a2a"
        $this._searchBox.ForegroundColor = "#FFFFFF"
        $this._panel.AddChild($this._searchBox)
        
        # Create list box
        $this._listBox = [ListBox]::new(2, 4, $this.Width - 4, $this.Height - 5)
        $this._listBox.BackgroundColor = "#1a1a1a"
        $this._listBox.ForegroundColor = "#CCCCCC"
        $this._listBox.SelectedBackgroundColor = "#0066CC"
        $this._listBox.SelectedForegroundColor = "#FFFFFF"
        $this._panel.AddChild($this._listBox)
        
        $this.RefreshActions()
    }
    
    [void] Show() {
        # Center on screen
        $screenWidth = $global:TuiState.BufferWidth
        $screenHeight = $global:TuiState.BufferHeight
        $this.X = [Math]::Max(0, ($screenWidth - $this.Width) / 2)
        $this.Y = [Math]::Max(0, ($screenHeight - $this.Height) / 2)
        
        $this._isVisible = $true
        $this.Visible = $true
        $this._searchBox.Clear()
        $this._searchBox.Focus()
        $this.RefreshActions()
        $this.RequestRedraw()
        
        # Request immediate redraw
        $global:TuiState.IsDirty = $true
    }
    
    [void] Hide() {
        $this._isVisible = $false
        $this.Visible = $false
        $this.RequestRedraw()
        $global:TuiState.IsDirty = $true
    }
    
    [void] RefreshActions([string]$filter = "") {
        $allActions = $this._actionService.GetAllActions()
        
        if ([string]::IsNullOrWhiteSpace($filter)) {
            $this._filteredActions = $allActions
        } else {
            $this._filteredActions = $allActions | Where-Object {
                $_.Name -like "*$filter*" -or $_.Description -like "*$filter*"
            }
        }
        
        $this._listBox.ClearItems()
        foreach ($action in $this._filteredActions) {
            $this._listBox.AddItem("$($action.Name) - $($action.Description)")
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if (-not $this._isVisible) { return $false }
        
        switch ($keyInfo.Key) {
            'Escape' {
                $this.Hide()
                return $true
            }
            'Enter' {
                if ($this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                    $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                    $this.Hide()
                    $this._actionService.ExecuteAction($selectedAction.Name)
                }
                return $true
            }
            'UpArrow' {
                $this._listBox.HandleInput($keyInfo)
                return $true
            }
            'DownArrow' {
                $this._listBox.HandleInput($keyInfo)
                return $true
            }
            default {
                # Pass to search box
                $oldText = $this._searchBox.Text
                $this._searchBox.HandleInput($keyInfo)
                if ($this._searchBox.Text -ne $oldText) {
                    $this.RefreshActions($this._searchBox.Text)
                }
                return $true
            }
        }
    }
}

#endregion

#region Panel Classes

class Panel : UIElement {
    [string] $Title = ""
    [string] $BorderStyle = "Single"
    $BorderColor = [ConsoleColor]::Gray  # Supports ConsoleColor or hex string
    $BackgroundColor = [ConsoleColor]::Black  # Supports ConsoleColor or hex string
    $TitleColor = [ConsoleColor]::White  # Supports ConsoleColor or hex string
    [bool] $HasBorder = $true
    [bool] $CanFocus = $false
    [int] $ContentX = 0
    [int] $ContentY = 0
    [int] $ContentWidth = 0
    [int] $ContentHeight = 0
    [string] $LayoutType = "Manual"

    Panel() : base() {
        $this.Name = "Panel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
    }

    Panel([int]$x, [int]$y, [int]$width, [int]$height) : base($x, $y, $width, $height) {
        $this.Name = "Panel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
    }

    Panel([int]$x, [int]$y, [int]$width, [int]$height, [string]$title) : base($x, $y, $width, $height) {
        $this.Name = "Panel_$(Get-Random -Maximum 1000)"
        $this.Title = $title
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
    }

    [void] UpdateContentBounds() {
        if ($this.HasBorder) {
            $this.ContentX = 1
            $this.ContentY = 1
            $this.ContentWidth = [Math]::Max(0, $this.Width - 2)
            $this.ContentHeight = [Math]::Max(0, $this.Height - 2)
        } else {
            $this.ContentX = 0
            $this.ContentY = 0
            $this.ContentWidth = $this.Width
            $this.ContentHeight = $this.Height
        }
    }
    
    [void] ClearContent() {
        if (-not $this._private_buffer) { return }
        
        for ($y = $this.ContentY; $y -lt ($this.ContentY + $this.ContentHeight); $y++) {
            for ($x = $this.ContentX; $x -lt ($this.ContentX + $this.ContentWidth); $x++) {
                $this._private_buffer.SetCell($x, $y, [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor))
            }
        }
    }

    [void] OnResize([int]$newWidth, [int]$newHeight) {
        ([UIElement]$this).OnResize($newWidth, $newHeight) 
        $this.UpdateContentBounds()
        $this.PerformLayout()
    }

    [void] PerformLayout() {
        try {
            if ($this.Children.Count -eq 0) { return }
            switch ($this.LayoutType) {
                "Vertical" { $this.LayoutVertical() }
                "Horizontal" { $this.LayoutHorizontal() }
                "Grid" { $this.LayoutGrid() }
                "Manual" { }
                default { }
            }
        }
        catch {}
    }

    hidden [void] LayoutVertical() {
        if ($this.Children.Count -eq 0) { return }
        
        $y = $this.ContentY
        $spacing = 1
        
        foreach ($child in $this.Children | Where-Object { $_.Visible }) {
            $child.X = $this.ContentX
            $child.Y = $y
            $child.Width = $this.ContentWidth
            $y += $child.Height + $spacing
        }
    }

    hidden [void] LayoutHorizontal() {
        if ($this.Children.Count -eq 0) { return }
        
        $x = $this.ContentX
        $spacing = 1
        
        foreach ($child in $this.Children | Where-Object { $_.Visible }) {
            $child.X = $x
            $child.Y = $this.ContentY
            $x += $child.Width + $spacing
        }
    }

    hidden [void] LayoutGrid() {
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor))
            
            if ($this.HasBorder) {
                for ($x = 0; $x -lt $this.Width; $x++) {
                    $this._private_buffer.SetCell($x, 0, [TuiCell]::new('-', $this.BorderColor, $this.BackgroundColor))
                    $this._private_buffer.SetCell($x, $this.Height - 1, [TuiCell]::new('-', $this.BorderColor, $this.BackgroundColor))
                }
                for ($y = 0; $y -lt $this.Height; $y++) {
                    $this._private_buffer.SetCell(0, $y, [TuiCell]::new('|', $this.BorderColor, $this.BackgroundColor))
                    $this._private_buffer.SetCell($this.Width - 1, $y, [TuiCell]::new('|', $this.BorderColor, $this.BackgroundColor))
                }
                
                $this._private_buffer.SetCell(0, 0, [TuiCell]::new('+', $this.BorderColor, $this.BackgroundColor))
                $this._private_buffer.SetCell($this.Width - 1, 0, [TuiCell]::new('+', $this.BorderColor, $this.BackgroundColor))
                $this._private_buffer.SetCell(0, $this.Height - 1, [TuiCell]::new('+', $this.BorderColor, $this.BackgroundColor))
                $this._private_buffer.SetCell($this.Width - 1, $this.Height - 1, [TuiCell]::new('+', $this.BorderColor, $this.BackgroundColor))
                
                if (-not [string]::IsNullOrEmpty($this.Title)) {
                    $titleText = " $($this.Title) "
                    $titleX = [Math]::Floor(($this.Width - $titleText.Length) / 2)
                    if ($titleX -lt 1) { $titleX = 1 }
                    $this._private_buffer.WriteString($titleX, 0, $titleText, $this.TitleColor, $this.BackgroundColor)
                }
            }
        }
        catch {}
    }
}

class ScrollablePanel : Panel {
    [int] $ScrollOffsetY = 0
    [int] $MaxScrollY = 0
    [int] $ScrollbarWidth = 1
    [bool] $ShowScrollbar = $true
    [ConsoleColor] $ScrollbarColor = [ConsoleColor]::DarkGray
    [ConsoleColor] $ScrollbarThumbColor = [ConsoleColor]::Gray

    ScrollablePanel() : base() {
        $this.IsFocusable = $true
    }

    ScrollablePanel([int]$x, [int]$y, [int]$width, [int]$height) : base($x, $y, $width, $height) {
        $this.IsFocusable = $true
    }

    ScrollablePanel([int]$x, [int]$y, [int]$width, [int]$height, [string]$title) : base($x, $y, $width, $height, $title) {
        $this.IsFocusable = $true
    }

    [void] UpdateContentBounds() {
        ([Panel]$this).UpdateContentBounds()
        if ($this.ShowScrollbar -and $this.ContentWidth -gt 0) {
            $this.ContentWidth -= $this.ScrollbarWidth
        }
    }

    [void] UpdateMaxScroll() {
        $totalContentHeight = 0
        foreach ($child in $this.Children | Where-Object { $_.Visible }) {
            $childBottom = $child.Y + $child.Height
            if ($childBottom -gt $totalContentHeight) {
                $totalContentHeight = $childBottom
            }
        }
        $this.MaxScrollY = [Math]::Max(0, $totalContentHeight - $this.ContentHeight)
    }

    [void] ScrollUp([int]$lines = 1) {
        $this.ScrollOffsetY = [Math]::Max(0, $this.ScrollOffsetY - $lines)
        $this.RequestRedraw()
    }

    [void] ScrollDown([int]$lines = 1) {
        $this.UpdateMaxScroll()
        $this.ScrollOffsetY = [Math]::Min($this.MaxScrollY, $this.ScrollOffsetY + $lines)
        $this.RequestRedraw()
    }

    [void] ScrollToTop() {
        $this.ScrollOffsetY = 0
        $this.RequestRedraw()
    }

    [void] ScrollToBottom() {
        $this.UpdateMaxScroll()
        $this.ScrollOffsetY = $this.MaxScrollY
        $this.RequestRedraw()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                $this.ScrollUp()
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                $this.ScrollDown()
                return $true
            }
            ([ConsoleKey]::PageUp) {
                $this.ScrollUp($this.ContentHeight)
                return $true
            }
            ([ConsoleKey]::PageDown) {
                $this.ScrollDown($this.ContentHeight)
                return $true
            }
            ([ConsoleKey]::Home) {
                $this.ScrollToTop()
                return $true
            }
            ([ConsoleKey]::End) {
                $this.ScrollToBottom()
                return $true
            }
        }
        
        return $false
    }

    [void] OnRender() {
        ([Panel]$this).OnRender()
        
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this.UpdateMaxScroll()
            
            if ($this.ShowScrollbar -and $this.MaxScrollY -gt 0) {
                $scrollbarX = $this.Width - $this.ScrollbarWidth
                if ($this.HasBorder) { $scrollbarX-- }
                
                $scrollbarStartY = if ($this.HasBorder) { 1 } else { 0 }
                $scrollbarHeight = if ($this.HasBorder) { $this.Height - 2 } else { $this.Height }
                
                for ($y = $scrollbarStartY; $y -lt $scrollbarStartY + $scrollbarHeight; $y++) {
                    $this._private_buffer.SetCell($scrollbarX, $y, [TuiCell]::new('│', $this.ScrollbarColor, $this.BackgroundColor))
                }
                
                $thumbHeight = [Math]::Max(1, [Math]::Floor($scrollbarHeight * ($this.ContentHeight / ($this.MaxScrollY + $this.ContentHeight))))
                $thumbPosition = [Math]::Floor($scrollbarHeight * ($this.ScrollOffsetY / ($this.MaxScrollY + $this.ContentHeight)))
                
                for ($y = 0; $y -lt $thumbHeight; $y++) {
                    $thumbY = $scrollbarStartY + $thumbPosition + $y
                    if ($thumbY -lt $scrollbarStartY + $scrollbarHeight) {
                        $this._private_buffer.SetCell($scrollbarX, $thumbY, [TuiCell]::new('█', $this.ScrollbarThumbColor, $this.BackgroundColor))
                    }
                }
            }
        }
        catch {}
    }

    hidden [void] _RenderContent() {
        $originalPositions = @{}
        
        foreach ($child in $this.Children) {
            $originalPositions[$child] = @{ Y = $child.Y }
            $child.Y -= $this.ScrollOffsetY
        }
        
        try {
            ([UIElement]$this)._RenderContent()
        }
        finally {
            foreach ($kvp in $originalPositions.GetEnumerator()) {
                $kvp.Key.Y = $kvp.Value.Y
            }
        }
    }
}

class GroupPanel : Panel {
    [hashtable] $GroupStyle = @{
        BorderColor = [ConsoleColor]::DarkGray
        TitleColor = [ConsoleColor]::Cyan
        BorderStyle = "Single"
    }

    GroupPanel() : base() {
        $this.ApplyGroupStyle()
    }

    GroupPanel([int]$x, [int]$y, [int]$width, [int]$height, [string]$title) : base($x, $y, $width, $height, $title) {
        $this.ApplyGroupStyle()
    }

    [void] ApplyGroupStyle() {
        $this.BorderColor = $this.GroupStyle.BorderColor
        $this.TitleColor = $this.GroupStyle.TitleColor
        $this.BorderStyle = $this.GroupStyle.BorderStyle
        $this.HasBorder = $true
    }
}

#endregion
