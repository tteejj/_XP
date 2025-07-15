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

# FIXED: Removed duplicated LabelComponent class definition from this file.

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
    # The following color properties are inherited from UIElement:
    # [string]$ForegroundColor
    # [string]$BackgroundColor
    # [string]$BorderColor
    [string]$PlaceholderColor = "#808080"
    [bool]$ShowCursor = $true # To control cursor visibility

    TextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.TabIndex = 0
        $this.Width = 20
        $this.Height = 3 # A height of 3 is standard for a bordered input box (top border, content, bottom border)
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Get theme colors dynamically - don't cache them
        $bgColor = Get-ThemeColor "input.background" ($this.GetEffectiveBackgroundColor())
        $fgColor = Get-ThemeColor "input.foreground" ($this.GetEffectiveForegroundColor())
        $borderColorValue = Get-ThemeColor "input.border" ($this.GetEffectiveBorderColor())
        if ($this.IsFocused) { $borderColorValue = Get-ThemeColor "input.focused.border" "#007acc" }
        
        # Clear buffer with the correct background color
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Draw border
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
            -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = "Single" }
            
        # Define content area
        $contentY = 1
        $contentStartX = 1
        $contentWidth = $this.Width - 2
        if ($contentWidth -le 0) { return } # Not enough space to render content

        if ($this.Text.Length -eq 0 -and -not [string]::IsNullOrEmpty($this.Placeholder)) {
            # Draw placeholder
            $placeholderText = $this.Placeholder
            if ($this.Placeholder.Length -gt $contentWidth) {
                $placeholderText = $this.Placeholder.Substring(0, $contentWidth)
            }
            
            $textStyle = @{ FG = $this.PlaceholderColor; BG = $bgColor }
            Write-TuiText -Buffer $this._private_buffer -X $contentStartX -Y $contentY -Text $placeholderText -Style $textStyle
        }
        else {
            # Calculate scroll offset to keep cursor in view
            if ($this.CursorPosition -lt $this._scrollOffset) {
                $this._scrollOffset = $this.CursorPosition
            }
            elseif ($this.CursorPosition -ge ($this._scrollOffset + $contentWidth)) {
                $this._scrollOffset = $this.CursorPosition - $contentWidth + 1
            }
            
            # Draw visible portion of text
            $visibleText = ""
            if ($this.Text.Length -gt $this._scrollOffset) {
                $len = [Math]::Min($contentWidth, $this.Text.Length - $this._scrollOffset)
                $visibleText = $this.Text.Substring($this._scrollOffset, $len)
            }
            
            if ($visibleText) {
                $textStyle = @{ FG = $fgColor; BG = $bgColor }
                Write-TuiText -Buffer $this._private_buffer -X $contentStartX -Y $contentY -Text $visibleText -Style $textStyle
            }
        }

        # Draw cursor if focused (non-destructive)
        if ($this.IsFocused -and $this.ShowCursor) {
            $cursorScreenPos = $this.CursorPosition - $this._scrollOffset
            if ($cursorScreenPos -ge 0 -and $cursorScreenPos -lt $contentWidth) {
                $cursorX = $contentStartX + $cursorScreenPos
                
                # FIXED: Simplified cursor rendering
                $charUnderCursor = ' '
                if ($this.CursorPosition -lt $this.Text.Length) { $charUnderCursor = $this.Text[$this.CursorPosition] }
                
                $cursorFg = $bgColor
                $cursorBg = $fgColor
                
                $cursorCell = [TuiCell]::new($charUnderCursor, $cursorFg, $cursorBg, $true)
                $this._private_buffer.SetCell($cursorX, $contentY, $cursorCell)
            }
        }
        
        $this._needs_redraw = $false
    }

    [void] OnFocus() {
        # Don't cache theme colors - get them fresh each time
        $this.ShowCursor = $true
        $this.RequestRedraw()
    }
    
    [void] OnBlur() {
        # Don't cache theme colors - get them fresh each time
        $this.ShowCursor = $false
        $this.RequestRedraw()
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
            # FIXED: Call OnChange handler if text was modified
            if ($oldText -ne $this.Text -and $this.OnChange) {
                try { 
                    $this.OnChange.Invoke($this, $this.Text)
                } catch {
                    if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Error -Message "TextBox '$($this.Name)': Error in OnChange handler: $_"
                    }
                }
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
}

#<!-- END_PAGE: ACO.003 -->