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
    # Removed manual focus tracking - will use FocusManager instead

    ConfirmDialog([string]$name) : base($name) {
        $this.Height = 8
        $this.InitializeConfirm()
    }

    hidden [void] InitializeConfirm() {
        # Yes button
        $this._yesButton = [ButtonComponent]::new($this.Name + "_Yes")
        $this._yesButton.Text = "Yes"
        $this._yesButton.Width = 10
        $this._yesButton.Height = 3
        $this._yesButton.TabIndex = 1 # Explicitly set tab order
        $this._yesButton.OnClick = {
            $this.Complete($true)
        }.GetNewClosure()
        $this._panel.AddChild($this._yesButton)

        # No button
        $this._noButton = [ButtonComponent]::new($this.Name + "_No")
        $this._noButton.Text = "No"
        $this._noButton.Width = 10
        $this._noButton.Height = 3
        $this._noButton.TabIndex = 2 # Explicitly set tab order
        $this._noButton.OnClick = {
            $this.Complete($false)
        }.GetNewClosure()
        $this._panel.AddChild($this._noButton)
    }

    [void] Show([string]$title, [string]$message) {
        ([Dialog]$this).Show($title, $message)
        
        # Position buttons
        $buttonY = $this.Height - 4
        $totalWidth = $this._yesButton.Width + $this._noButton.Width + 4
        $startX = [Math]::Floor(($this.Width - $totalWidth) / 2)
        
        $this._yesButton.X = $startX
        $this._yesButton.Y = $buttonY
        
        $this._noButton.X = $startX + $this._yesButton.Width + 4
        $this._noButton.Y = $buttonY
        
    }

    [void] OnEnter() {
        # When the dialog is shown, tell the FocusManager to focus the first element (Yes button)
        $global:TuiState.Services.FocusManager?.SetFocus($this._yesButton)
    }

    [void] OnRender() {
        ([Dialog]$this).OnRender()
        
        if ($this.Visible -and $this.Message) {
            # Draw message (same as AlertDialog)
            $panelContentX = $this._panel.ContentX
            $panelContentY = $this._panel.ContentY
            $maxWidth = $this.Width - 4
            
            $words = $this.Message -split ' '
            $currentLine = ""
            $currentY = $panelContentY + 1
            
            foreach ($word in $words) {
                if (($currentLine + " " + $word).Length -gt $maxWidth) {
                    if ($currentLine) {
                        Write-TuiText -Buffer $this._panel._private_buffer -X $panelContentX -Y $currentY -Text $currentLine -Style @{ FG = Get-ThemeColor "Label.Foreground" "#e0e0e0"; BG = Get-ThemeColor "Panel.Background" "#1e1e1e" }
                        $currentY++
                    }
                    $currentLine = $word
                }
                else {
                    $currentLine = if ($currentLine) { "$currentLine $word" } else { $word }
                }
            }
            
            if ($currentLine) {
                Write-TuiText -Buffer $this._panel._private_buffer -X $panelContentX -Y $currentY -Text $currentLine -Style @{ FG = Get-ThemeColor "Label.Foreground" "#e0e0e0"; BG = Get-ThemeColor "Panel.Background" "#1e1e1e" }
            }
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }

        # Handle Escape to cancel
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Complete($false) # Using new Complete method
            return $true
        }

        # The global input handler will route Tab/Shift+Tab to the FocusManager.
        # Left/Right arrow keys can be used to switch between Yes/No buttons
        if ($key.Key -eq [ConsoleKey]::LeftArrow -or $key.Key -eq [ConsoleKey]::RightArrow) {
            $focusManager = $global:TuiState.Services.FocusManager
            if ($focusManager) {
                # Toggle focus between the two buttons
                if ($focusManager.FocusedComponent -eq $this._yesButton) {
                    $focusManager.SetFocus($this._noButton)
                } else {
                    $focusManager.SetFocus($this._yesButton)
                }
                return $true
            }
        }
        
        # Let the focused child handle the input
        # The FocusManager will have already routed input to the focused button
        return $false
    }
}

#<!-- END_PAGE: ACO.019 -->
