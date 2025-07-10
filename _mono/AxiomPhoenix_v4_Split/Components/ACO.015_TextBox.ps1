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
