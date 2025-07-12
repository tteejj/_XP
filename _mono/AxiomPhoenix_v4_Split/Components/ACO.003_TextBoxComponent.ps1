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
    hidden [string]$_backgroundColorValue = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$BorderColor = "#808080"
    [string]$PlaceholderColor = "#808080"

    TextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer with theme background
        $bgColor = Get-ThemeColor "Input.Background" "#2d2d30"
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Determine colors
        $fgColor = if ($this.IsFocused) { Get-ThemeColor "Input.Foreground" "#d4d4d4" } else { Get-ThemeColor "Label.Foreground" "#9ca3af" }
        $bgColor = Get-ThemeColor "Input.Background" "#2d2d30"
        $borderColorValue = if ($this.IsFocused) { Get-ThemeColor "Input.FocusedBorder" "#007acc" } else { Get-ThemeColor "Input.Border" "#404040" }
        
        # Ensure we have valid colors
        if (-not $fgColor) { $fgColor = "#FFFFFF" }
        if (-not $bgColor) { $bgColor = "#000000" }
        if (-not $borderColorValue) { $borderColorValue = "#808080" }
        
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
            
            $textStyle = @{ FG = Get-ThemeColor "Input.Foreground" "#666666"; BG = $bgColor }
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
                    
                    # Get the cell at cursor position with bounds checking
                    if ($cursorX -ge 0 -and $cursorX -lt $this._private_buffer.Width -and $contentY -ge 0 -and $contentY -lt $this._private_buffer.Height) {
                        $cellUnderCursor = $this._private_buffer.GetCell($cursorX, $contentY)
                        
                        # Invert its colors to represent the cursor
                        $cursorFg = $cellUnderCursor.BackgroundColor
                        $cursorBg = $cellUnderCursor.ForegroundColor
                        # Use the 4-parameter constructor for bold cursor
                        $newCell = [TuiCell]::new($cellUnderCursor.Char, $cursorBg, $cursorFg, $true)
                        $this._private_buffer.SetCell($cursorX, $contentY, $newCell)
                    }
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
            if ($oldText -ne $this.Text) {
                if ($this.OnChange) {
                    try { 
                        & $this.OnChange $this $this.Text 
                    } catch {
                        Write-Log -Level Error -Message "TextBox '$($this.Name)': Error in OnChange handler: $_"
                    }
                }
            }
            $this.RequestRedraw()
            $global:TuiState.IsDirty = $true
        }
        
        return $handled
    }
}

#<!-- END_PAGE: ACO.003 -->
