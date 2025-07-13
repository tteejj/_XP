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

# ===== CLASS: AlertDialog =====
# Module: dialog-system-class
# Dependencies: Dialog, ButtonComponent
# Purpose: Simple message dialog
class AlertDialog : Dialog {
    hidden [ButtonComponent]$_okButton

    AlertDialog([string]$name, [object]$serviceContainer) : base($name, $serviceContainer) {
        $this.Height = 10
        $this.Width = 50
        $this.InitializeAlert()
    }

    hidden [void] InitializeAlert() {
        # OK button
        $this._okButton = [ButtonComponent]::new($this.Name + "_OK")
        $this._okButton.Text = "OK"
        $this._okButton.Width = 10
        $this._okButton.Height = 1 # A simple 1-line button is fine for a dialog
        $this._okButton.IsFocusable = $true
        $this._okButton.TabIndex = 0
        $thisDialog = $this
        $this._okButton.OnClick = {
            $thisDialog.Complete($true)
        }.GetNewClosure()

        # Add the button to the dialog's main panel
        $this._panel.AddChild($this._okButton)
    }

    # Override OnEnter to set focus to the OK button
    [void] OnEnter() {
        ([Dialog]$this).OnEnter() # Call base to set up focus management
        $this.SetChildFocus($this._okButton)
    }

    [void] OnRender() {
        # Call the base Dialog OnRender first. This clears the buffer and centers the panel.
        ([Dialog]$this).OnRender()
        
        # Position OK button at the bottom-center of the panel's content area
        $this._okButton.X = [Math]::Floor(($this._panel.ContentWidth - $this._okButton.Width) / 2)
        $this._okButton.Y = $this._panel.ContentHeight - 2
        
        # Draw the message text inside the panel's content area
        if ($this.Visible -and $this.Message) {
            $panelContentX = $this._panel.ContentX
            $panelContentY = $this._panel.ContentY
            $maxWidth = $this._panel.ContentWidth - 2 # Leave a margin

            # Simple word wrap
            $words = $this.Message -split ' '
            $currentLine = ""
            $currentY = $panelContentY + 1 # Start drawing message below title area

            foreach ($word in $words) {
                if (($currentLine + " " + $word).Length -gt $maxWidth) {
                    if ($currentLine) {
                        Write-TuiText -Buffer $this._panel.GetBuffer() -X ($panelContentX + 1) -Y $currentY -Text $currentLine -Style @{ FG = (Get-ThemeColor "Label.Foreground" "#e0e0e0"); BG = (Get-ThemeColor "Panel.Background" "#1e1e1e") }
                        $currentY++
                    }
                    $currentLine = $word
                }
                else {
                    $currentLine = if ($currentLine) { "$currentLine $word" } else { $word }
                }
            }
            # Write the last line
            if ($currentLine) {
                Write-TuiText -Buffer $this._panel.GetBuffer() -X ($panelContentX + 1) -Y $currentY -Text $currentLine -Style @{ FG = (Get-ThemeColor "Label.Foreground" "#e0e0e0"); BG = (Get-ThemeColor "Panel.Background" "#1e1e1e") }
            }
        }
    }

    # FIXED: Input handling is now managed by the Dialog base class and the focused ButtonComponent.
    # No custom HandleInput override is needed here.
}

#<!-- END_PAGE: ACO.018 -->