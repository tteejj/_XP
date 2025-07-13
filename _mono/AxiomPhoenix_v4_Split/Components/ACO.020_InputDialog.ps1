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

# ===== CLASS: InputDialog =====
# Module: dialog-system-class
# Dependencies: Dialog, TextBoxComponent, ButtonComponent
# Purpose: Text input dialog
class InputDialog : Dialog {
    hidden [TextBoxComponent]$_inputBox
    hidden [ButtonComponent]$_okButton
    hidden [ButtonComponent]$_cancelButton
    # FIXED: Removed manual focus tracking. The Screen base class will manage focus.

    InputDialog([string]$name, [object]$serviceContainer) : base($name, $serviceContainer) {
        $this.Height = 12
        $this.Width = 60
        $this.InitializeInput()
    }

    hidden [void] InitializeInput() {
        # Input box
        $this._inputBox = [TextBoxComponent]::new($this.Name + "_Input")
        $this._inputBox.Width = $this.Width - 4
        $this._inputBox.Height = 3
        $this._inputBox.X = 2
        $this._inputBox.Y = 4
        $this._inputBox.IsFocusable = $true
        $this._inputBox.TabIndex = 0
        $this._panel.AddChild($this._inputBox)

        # OK button
        $this._okButton = [ButtonComponent]::new($this.Name + "_OK")
        $this._okButton.Text = "OK"
        $this._okButton.Width = 10
        $this._okButton.Height = 1
        $this._okButton.IsFocusable = $true
        $this._okButton.TabIndex = 1
        $thisDialog = $this
        $this._okButton.OnClick = {
            # FIXED: Use the Complete method from the base Dialog class
            $thisDialog.Complete($thisDialog._inputBox.Text)
        }.GetNewClosure()
        $this._panel.AddChild($this._okButton)

        # Cancel button
        $this._cancelButton = [ButtonComponent]::new($this.Name + "_Cancel")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.Width = 10
        $this._cancelButton.Height = 1
        $this._cancelButton.IsFocusable = $true
        $this._cancelButton.TabIndex = 2
        $this._cancelButton.OnClick = {
            # FIXED: Use the Complete method from the base Dialog class
            $thisDialog.Complete($null)
        }.GetNewClosure()
        $this._panel.AddChild($this._cancelButton)
    }

    [void] Show([string]$title, [string]$message, [string]$defaultValue = "") {
        ([Dialog]$this).Show($title, $message)
        
        $this._inputBox.Text = $defaultValue
        $this._inputBox.CursorPosition = $defaultValue.Length
    }

    # Override OnEnter to set initial focus
    [void] OnEnter() {
        ([Dialog]$this).OnEnter()
        $this.SetChildFocus($this._inputBox)
    }

    [void] OnRender() {
        # Call base Dialog render
        ([Dialog]$this).OnRender()
        
        # Position buttons
        $buttonY = $this._panel.ContentHeight - 2
        $totalWidth = $this._okButton.Width + $this._cancelButton.Width + 4
        $startX = [Math]::Floor(($this._panel.ContentWidth - $totalWidth) / 2)
        
        $this._okButton.X = $startX
        $this._okButton.Y = $buttonY
        
        $this._cancelButton.X = $startX + $this._okButton.Width + 4
        $this._cancelButton.Y = $buttonY
        
        # Draw message prompt
        if ($this.Visible -and $this.Message) {
            Write-TuiText -Buffer $this._panel.GetBuffer() -X ($this._panel.ContentX + 1) -Y ($this._panel.ContentY + 1) `
                -Text $this.Message -Style @{ FG = (Get-ThemeColor "Label.Foreground" "#e0e0e0") }
        }
    }

    # FIXED: Input handling is now managed by the Dialog base class and focused components.
    # No custom HandleInput override is needed here, as the base class handles Escape,
    # Tab navigation, and routes Enter/Space to the focused button.
}

# FIXED: Removed TaskDialog and TaskDeleteDialog from this file to resolve
# circular dependencies and load order issues. These complex dialogs should
# be in their own files and loaded after all their component dependencies.

#<!-- END_PAGE: ACO.020 -->