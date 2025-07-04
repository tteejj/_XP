# ==============================================================================
# Advanced Input Components Module v5.0
# Sophisticated input controls with theme integration and overlay rendering
# ==============================================================================

using namespace System.Management.Automation
using namespace System.Collections.Generic

#region Advanced Input Classes

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
        Write-Verbose "MultilineTextBoxComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = Get-ThemeColor 'input.background' -Fallback (Get-ThemeColor 'Background')
            $borderColor = if ($this.IsFocused) { 
                Get-ThemeColor 'input.border.focus' -Fallback (Get-ThemeColor 'Accent') 
            } else { 
                Get-ThemeColor 'input.border.normal' -Fallback (Get-ThemeColor 'Border') 
            }
            $fgColor = Get-ThemeColor 'input.foreground' -Fallback (Get-ThemeColor 'Foreground')
            $placeholderColor = Get-ThemeColor 'input.placeholder' -Fallback (Get-ThemeColor 'Subtle')
            $cursorColor = Get-ThemeColor 'input.cursor' -Fallback (Get-ThemeColor 'Accent')
            
            # Clear buffer and draw border
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor

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
                    Write-TuiText -Buffer $this._private_buffer -X 1 -Y ($i + 1) -Text $displayLine -ForegroundColor $fgColor -BackgroundColor $bgColor
                }
            }

            # Show placeholder if empty and not focused
            if ($this.Lines.Count -eq 1 -and [string]::IsNullOrEmpty($this.Lines[0]) -and -not $this.IsFocused) {
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $this.Placeholder -ForegroundColor $placeholderColor -BackgroundColor $bgColor
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
            
            Write-Verbose "MultilineTextBoxComponent '$($this.Name)': Rendered successfully"
        }
        catch {
            Write-Error "MultilineTextBoxComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        try {
            $handled = $true
            $currentLine = $this.Lines[$this.CurrentLine]
            $originalText = $this.Lines -join "`n"
            
            switch ($key.Key) {
                ([ConsoleKey]::Enter) {
                    if ($this.Lines.Count -lt $this.MaxLines) {
                        $beforeCursor = $currentLine.Substring(0, $this.CursorPosition)
                        $afterCursor = $currentLine.Substring($this.CursorPosition)
                        
                        $this.Lines[$this.CurrentLine] = $beforeCursor
                        $this.Lines = $this.Lines[0..$this.CurrentLine] + @($afterCursor) + $this.Lines[($this.CurrentLine + 1)..($this.Lines.Count - 1)]
                        
                        $this.CurrentLine++
                        $this.CursorPosition = 0
                    }
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CursorPosition -gt 0) {
                        $this.Lines[$this.CurrentLine] = $currentLine.Remove($this.CursorPosition - 1, 1)
                        $this.CursorPosition--
                    }
                    elseif ($this.CurrentLine -gt 0) {
                        $this.CursorPosition = $this.Lines[$this.CurrentLine - 1].Length
                        $this.Lines[$this.CurrentLine - 1] += $currentLine
                        $this.Lines = $this.Lines[0..($this.CurrentLine - 1)] + $this.Lines[($this.CurrentLine + 1)..($this.Lines.Count - 1)]
                        $this.CurrentLine--
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($this.CursorPosition -lt $currentLine.Length) {
                        $this.Lines[$this.CurrentLine] = $currentLine.Remove($this.CursorPosition, 1)
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
                    if ($this.CursorPosition -lt $currentLine.Length) {
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
                    $this.CursorPosition = $currentLine.Length
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
                        $newLine = $currentLine.Insert($this.CursorPosition, $key.KeyChar)
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
                    Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock {
                        & $this.OnChange -NewValue $newText
                    }
                }
                
                $this.RequestRedraw()
            }
            
            return $handled
        }
        catch {
            Write-Error "MultilineTextBoxComponent '$($this.Name)': Error handling input: $($_.Exception.Message)"
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

    [string] ToString() {
        return "MultilineTextBoxComponent(Name='$($this.Name)', Lines=$($this.Lines.Count), Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

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
        Write-Verbose "NumericInputComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = Get-ThemeColor 'input.background' -Fallback (Get-ThemeColor 'Background')
            $borderColor = if ($this.IsFocused) { 
                Get-ThemeColor 'input.border.focus' -Fallback (Get-ThemeColor 'Accent') 
            } else { 
                Get-ThemeColor 'input.border.normal' -Fallback (Get-ThemeColor 'Border') 
            }
            $fgColor = Get-ThemeColor 'input.foreground' -Fallback (Get-ThemeColor 'Foreground')
            $suffixColor = Get-ThemeColor 'input.suffix' -Fallback (Get-ThemeColor 'Subtle')
            $cursorColor = Get-ThemeColor 'input.cursor' -Fallback (Get-ThemeColor 'Accent')
            
            # Clear buffer and draw border
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
            
            # Draw main value
            $displayText = $this.TextValue
            if (-not [string]::IsNullOrEmpty($this.Suffix)) {
                $displayText += $this.Suffix
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y 1 -Text $displayText -ForegroundColor $fgColor -BackgroundColor $bgColor
            
            # Draw spinner arrows
            $spinnerColor = if ($this.IsFocused) { $borderColor } else { (Get-ThemeColor 'Subtle') }
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 0 -Text "▲" -ForegroundColor $spinnerColor -BackgroundColor $bgColor
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 2 -Text "▼" -ForegroundColor $spinnerColor -BackgroundColor $bgColor
            
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
            
            Write-Verbose "NumericInputComponent '$($this.Name)': Rendered successfully"
        }
        catch {
            Write-Error "NumericInputComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
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
                    Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock {
                        & $this.OnChange -NewValue $this.Value
                    }
                }
                
                $this.RequestRedraw()
            }
            
            return $handled
        }
        catch {
            Write-Error "NumericInputComponent '$($this.Name)': Error handling input: $($_.Exception.Message)"
            return $false
        }
    }

    hidden [bool] _IsValidNumericChar([char]$char) {
        return [char]::IsDigit($char) -or $char -eq '.' -or $char -eq '-'
    }

    hidden [bool] _ValidateAndSetValue([string]$text) {
        try {
            $value = [double]::Parse($text)
            if ($value -ge $this.MinValue -and $value -le $this.MaxValue) {
                $this.Value = $value
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

    [string] ToString() {
        return "NumericInputComponent(Name='$($this.Name)', Value=$($this.Value), Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

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
        Write-Verbose "DateInputComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = Get-ThemeColor 'input.background' -Fallback (Get-ThemeColor 'Background')
            $borderColor = if ($this.IsFocused) { 
                Get-ThemeColor 'input.border.focus' -Fallback (Get-ThemeColor 'Accent') 
            } else { 
                Get-ThemeColor 'input.border.normal' -Fallback (Get-ThemeColor 'Border') 
            }
            $fgColor = Get-ThemeColor 'input.foreground' -Fallback (Get-ThemeColor 'Foreground')
            $cursorColor = Get-ThemeColor 'input.cursor' -Fallback (Get-ThemeColor 'Accent')
            
            # Clear buffer and draw border
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
            
            # Draw date value
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y 1 -Text $this.TextValue -ForegroundColor $fgColor -BackgroundColor $bgColor
            
            # Draw calendar icon
            $iconColor = if ($this.IsFocused) { $borderColor } else { (Get-ThemeColor 'Subtle') }
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 1 -Text "📅" -ForegroundColor $iconColor -BackgroundColor $bgColor
            
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
            
            Write-Verbose "DateInputComponent '$($this.Name)': Rendered successfully"
        }
        catch {
            Write-Error "DateInputComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
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
                    Invoke-WithErrorHandling -Component "$($this.Name).OnChange" -ScriptBlock {
                        & $this.OnChange -NewValue $this.Value
                    }
                }
                
                $this.RequestRedraw()
            }
            
            return $handled
        }
        catch {
            Write-Error "DateInputComponent '$($this.Name)': Error handling input: $($_.Exception.Message)"
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

    [string] ToString() {
        return "DateInputComponent(Name='$($this.Name)', Value=$($this.Value), Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

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
        Write-Verbose "ComboBoxComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = Get-ThemeColor 'input.background' -Fallback (Get-ThemeColor 'Background')
            $borderColor = if ($this.IsFocused) { 
                Get-ThemeColor 'input.border.focus' -Fallback (Get-ThemeColor 'Accent') 
            } else { 
                Get-ThemeColor 'input.border.normal' -Fallback (Get-ThemeColor 'Border') 
            }
            $fgColor = Get-ThemeColor 'input.foreground' -Fallback (Get-ThemeColor 'Foreground')
            
            # Clear buffer and draw border
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
            
            # Draw current value or search text
            $displayText = if ($this.IsDropDownOpen -and $this.AllowSearch) { $this.SearchText } else { $this.DisplayText }
            if (-not [string]::IsNullOrEmpty($displayText)) {
                $maxTextWidth = $this.Width - 6
                if ($displayText.Length -gt $maxTextWidth) {
                    $displayText = $displayText.Substring(0, $maxTextWidth - 3) + "..."
                }
                Write-TuiText -Buffer $this._private_buffer -X 2 -Y 1 -Text $displayText -ForegroundColor $fgColor -BackgroundColor $bgColor
            }
            
            # Draw dropdown arrow
            $arrow = if ($this.IsDropDownOpen) { "▲" } else { "▼" }
            $arrowColor = if ($this.IsFocused) { $borderColor } else { (Get-ThemeColor 'Subtle') }
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 1 -Text $arrow -ForegroundColor $arrowColor -BackgroundColor $bgColor
            
            # Render dropdown overlay if open
            if ($this.IsDropDownOpen) {
                $this._RenderDropdownOverlay()
            }
            
            Write-Verbose "ComboBoxComponent '$($this.Name)': Rendered successfully"
        }
        catch {
            Write-Error "ComboBoxComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    hidden [void] _RenderDropdownOverlay() {
        try {
            # Get theme colors
            $bgColor = Get-ThemeColor 'input.background' -Fallback (Get-ThemeColor 'Background')
            $borderColor = Get-ThemeColor 'input.border.focus' -Fallback (Get-ThemeColor 'Accent')
            $fgColor = Get-ThemeColor 'input.foreground' -Fallback (Get-ThemeColor 'Foreground')
            $selectionBg = Get-ThemeColor 'input.selection' -Fallback (Get-ThemeColor 'Selection')
            $selectionFg = Get-ThemeColor 'input.selection.foreground' -Fallback (Get-ThemeColor 'Background')
            
            $dropdownHeight = [Math]::Min($this.MaxDropDownHeight, $this._filteredItems.Count + 2)
            
            # Create or resize dropdown buffer
            if (-not $this._dropdownBuffer -or $this._dropdownBuffer.Height -ne $dropdownHeight -or $this._dropdownBuffer.Width -ne $this.Width) {
                $this._dropdownBuffer = [TuiBuffer]::new($this.Width, $dropdownHeight, "$($this.Name).Dropdown")
            }
            
            # Clear and draw dropdown
            $this._dropdownBuffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            Write-TuiBox -Buffer $this._dropdownBuffer -X 0 -Y 0 -Width $this.Width -Height $dropdownHeight -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
            
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
                Write-TuiText -Buffer $this._dropdownBuffer -X 1 -Y ($i + 1) -Text $highlightText -ForegroundColor $itemFg -BackgroundColor $itemBg
                
                # Draw item text
                $itemText = " $item"
                $maxItemWidth = $this.Width - 4
                if ($itemText.Length -gt $maxItemWidth) {
                    $itemText = $itemText.Substring(0, $maxItemWidth - 3) + "..."
                }
                Write-TuiText -Buffer $this._dropdownBuffer -X 2 -Y ($i + 1) -Text $itemText -ForegroundColor $itemFg -BackgroundColor $itemBg
            }
            
            # Add dropdown to overlay stack for rendering
            # Note: This would need integration with the TUI engine's overlay system
            # For now, we'll blend it directly onto the current screen
            
            Write-Verbose "ComboBoxComponent '$($this.Name)': Dropdown overlay rendered"
        }
        catch {
            Write-Error "ComboBoxComponent '$($this.Name)': Error rendering dropdown: $($_.Exception.Message)"
        }
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
                    ([ConsoleKey]::Enter), ([ConsoleKey]::Spacebar), ([ConsoleKey]::DownArrow) {
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
                    Invoke-WithErrorHandling -Component "$($this.Name).OnSelectionChanged" -ScriptBlock {
                        & $this.OnSelectionChanged -SelectedItem $this.SelectedItem
                    }
                }
                
                $this.RequestRedraw()
            }
            
            return $handled
        }
        catch {
            Write-Error "ComboBoxComponent '$($this.Name)': Error handling input: $($_.Exception.Message)"
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

    [string] ToString() {
        return "ComboBoxComponent(Name='$($this.Name)', Items=$($this.Items.Count), Selected='$($this.SelectedItem)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

#endregion

#region Factory Functions

function New-TuiMultilineTextBox {
    <#
    .SYNOPSIS
    Creates a new multiline text box component.
    
    .DESCRIPTION
    Factory function to create a MultilineTextBoxComponent with configurable properties.
    
    .PARAMETER Props
    Hashtable of properties to apply to the component.
    
    .EXAMPLE
    $multilineText = New-TuiMultilineTextBox -Props @{
        Name = "Description"
        Width = 60
        Height = 10
        MaxLines = 50
        Placeholder = "Enter description..."
    }
    #>
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $name = $Props.Name ?? "MultilineTextBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $component = [MultilineTextBoxComponent]::new($name)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($component.PSObject.Properties.Match($_.Name)) {
                $component.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created multiline text box '$name' with $($Props.Count) properties"
        return $component
    }
    catch {
        Write-Error "Failed to create multiline text box: $($_.Exception.Message)"
        throw
    }
}

function New-TuiNumericInput {
    <#
    .SYNOPSIS
    Creates a new numeric input component.
    
    .DESCRIPTION
    Factory function to create a NumericInputComponent with configurable properties.
    
    .PARAMETER Props
    Hashtable of properties to apply to the component.
    
    .EXAMPLE
    $numericInput = New-TuiNumericInput -Props @{
        Name = "Amount"
        MinValue = 0
        MaxValue = 1000
        DecimalPlaces = 2
        Step = 0.5
    }
    #>
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $name = $Props.Name ?? "NumericInput_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $component = [NumericInputComponent]::new($name)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($component.PSObject.Properties.Match($_.Name)) {
                $component.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created numeric input '$name' with $($Props.Count) properties"
        return $component
    }
    catch {
        Write-Error "Failed to create numeric input: $($_.Exception.Message)"
        throw
    }
}

function New-TuiDateInput {
    <#
    .SYNOPSIS
    Creates a new date input component.
    
    .DESCRIPTION
    Factory function to create a DateInputComponent with configurable properties.
    
    .PARAMETER Props
    Hashtable of properties to apply to the component.
    
    .EXAMPLE
    $dateInput = New-TuiDateInput -Props @{
        Name = "DueDate"
        DateFormat = "yyyy-MM-dd"
        MinDate = (Get-Date)
        MaxDate = (Get-Date).AddYears(1)
    }
    #>
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $name = $Props.Name ?? "DateInput_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $component = [DateInputComponent]::new($name)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($component.PSObject.Properties.Match($_.Name)) {
                $component.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created date input '$name' with $($Props.Count) properties"
        return $component
    }
    catch {
        Write-Error "Failed to create date input: $($_.Exception.Message)"
        throw
    }
}

function New-TuiComboBox {
    <#
    .SYNOPSIS
    Creates a new combo box component.
    
    .DESCRIPTION
    Factory function to create a ComboBoxComponent with configurable properties.
    
    .PARAMETER Props
    Hashtable of properties to apply to the component.
    
    .EXAMPLE
    $comboBox = New-TuiComboBox -Props @{
        Name = "Priority"
        Items = @("Low", "Medium", "High", "Critical")
        AllowSearch = $true
        MaxDropDownHeight = 6
    }
    #>
    [CmdletBinding()]
    param([hashtable]$Props = @{})
    
    try {
        $name = $Props.Name ?? "ComboBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $component = [ComboBoxComponent]::new($name)
        
        $Props.GetEnumerator() | ForEach-Object {
            if ($component.PSObject.Properties.Match($_.Name)) {
                $component.($_.Name) = $_.Value
            }
        }
        
        Write-Verbose "Created combo box '$name' with $($Props.Count) properties"
        return $component
    }
    catch {
        Write-Error "Failed to create combo box: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Module Exports

# Export public functions
Export-ModuleMember -Function New-TuiMultilineTextBox, New-TuiNumericInput, New-TuiDateInput, New-TuiComboBox

# Classes are automatically exported in PowerShell 7+
# MultilineTextBoxComponent, NumericInputComponent, DateInputComponent, ComboBoxComponent classes are available when module is imported

#endregion