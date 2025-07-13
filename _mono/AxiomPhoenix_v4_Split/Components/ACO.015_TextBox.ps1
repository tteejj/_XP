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
        
        # FIXED: Proper focus setup according to guide
        $this.IsFocusable = $true
        $this.TabIndex = 0  # Set appropriate tab order
        
        # FIXED: Set colors using PROPERTIES, not methods
        $this.BackgroundColor = Get-ThemeColor "Input.Background"
        $this.ForegroundColor = Get-ThemeColor "Input.Foreground"
        $this.BorderColor = Get-ThemeColor "Input.Border"
        
        # FIXED: Override focus methods with Add-Member as per guide
        $this | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent"
            $this.ShowCursor = $true
            if ($this._textBox) {
                $this._textBox.IsFocused = $true
                $this._textBox.OnFocus()
            }
            $this.RequestRedraw()
        } -Force
        
        $this | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "border"
            $this.ShowCursor = $false
            if ($this._textBox) {
                $this._textBox.IsFocused = $false
                $this._textBox.OnBlur()
            }
            $this.RequestRedraw()
        } -Force
    }

    [string] GetText() { return $this._textBox.Text }
    [void] SetText([string]$value) { $this._textBox.Text = $value }
    
    [void] Clear() {
        $this._textBox.Text = ""
        $this._textBox.CursorPosition = 0
        $this._textBox.RequestRedraw()
    }

    # FIXED: Removed deprecated FocusManager call - focus is now handled by framework
    
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
