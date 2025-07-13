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

# ===== CLASS: ConfirmDialog =====
# Module: dialog-system-class
# Dependencies: Dialog, ButtonComponent
# Purpose: Yes/No confirmation dialog
class ConfirmDialog : Dialog {
    hidden [ButtonComponent]$_yesButton
    hidden [ButtonComponent]$_noButton
    # FIXED: Removed manual focus tracking. The Screen base class will manage focus.

    ConfirmDialog([string]$name, [object]$serviceContainer) : base($name, $serviceContainer) {
        $this.Height = 10
        $this.Width = 50
        $this.InitializeConfirm()
    }

    hidden [void] InitializeConfirm() {
        # Yes button
        $this._yesButton = [ButtonComponent]::new($this.Name + "_Yes")
        $this._yesButton.Text = "Yes"
        $this._yesButton.Width = 10
        $this._yesButton.Height = 1
        $this._yesButton.IsFocusable = $true
        $this._yesButton.TabIndex = 0 # First in tab order
        $thisDialog = $this
        $this._yesButton.OnClick = {
            $thisDialog.Complete($true)
        }.GetNewClosure()
        $this._panel.AddChild($this._yesButton)

        # No button
        $this._noButton = [ButtonComponent]::new($this.Name + "_No")
        $this._noButton.Text = "No"
        $this._noButton.Width = 10
        $this._noButton.Height = 1
        $this._noButton.IsFocusable = $true
        $this._noButton.TabIndex = 1 # Second in tab order
        $this._noButton.OnClick = {
            $thisDialog.Complete($false)
        }.GetNewClosure()
        $this._panel.AddChild($this._noButton)
    }

    # Override OnEnter to set initial focus
    [void] OnEnter() {
        ([Dialog]$this).OnEnter()
        # When the dialog is shown, set focus to the "Yes" button by default.
        $this.SetChildFocus($this._yesButton)
    }

    [void] OnRender() {
        # Call the base Dialog OnRender first
        ([Dialog]$this).OnRender()
        
        # Position buttons
        $buttonY = $this._panel.ContentHeight - 2
        $totalWidth = $this._yesButton.Width + $this._noButton.Width + 4 # 4 for spacing
        $startX = [Math]::Floor(($this._panel.ContentWidth - $totalWidth) / 2)
        
        $this._yesButton.X = $startX
        $this._yesButton.Y = $buttonY
        
        $this._noButton.X = $startX + $this._yesButton.Width + 4
        $this._noButton.Y = $buttonY
        
        # Draw message text
        if ($this.Visible -and $this.Message) {
            $panelContentX = $this._panel.ContentX
            $panelContentY = $this._panel.ContentY
            $maxWidth = $this._panel.ContentWidth - 2

            $words = $this.Message -split ' '
            $currentLine = ""
            $currentY = $panelContentY + 1
            
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
            
            if ($currentLine) {
                Write-TuiText -Buffer $this._panel.GetBuffer() -X ($panelContentX + 1) -Y $currentY -Text $currentLine -Style @{ FG = (Get-ThemeColor "Label.Foreground" "#e0e0e0"); BG = (Get-ThemeColor "Panel.Background" "#1e1e1e") }
            }
        }
    }

    # FIXED: Simplified input handling to use the Hybrid Window Model
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }

        # Let the base Dialog/Screen class handle Tab, Escape, and routing to focused child first
        if (([Dialog]$this).HandleInput($key)) {
            return $true
        }

        # Add convenient Left/Right arrow key navigation between buttons
        if ($key.Key -eq [ConsoleKey]::LeftArrow -or $key.Key -eq [ConsoleKey]::RightArrow) {
            $focusedComponent = $this.GetFocusedChild()
            if ($focusedComponent -eq $this._yesButton) {
                $this.SetChildFocus($this._noButton)
            } elseif ($focusedComponent -eq $this._noButton) {
                $this.SetChildFocus($this._yesButton)
            }
            return $true
        }
        
        return $false
    }
}

#<!-- END_PAGE: ACO.019 -->