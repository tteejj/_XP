# ==============================================================================
# Axiom-Phoenix v4.0 - All Components
# UI components that extend UIElement - full implementations from axiom
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

#

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
