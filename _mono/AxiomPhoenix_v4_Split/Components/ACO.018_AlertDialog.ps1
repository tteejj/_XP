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

    AlertDialog([string]$name) : base($name) {
        $this.Height = 8
        $this.InitializeAlert()
    }

    hidden [void] InitializeAlert() {
        # OK button
        $this._okButton = [ButtonComponent]::new($this.Name + "_OK")
        $this._okButton.Text = "OK"
        $this._okButton.Width = 10
        $this._okButton.Height = 3
        $this._okButton.OnClick = {
            $this.Complete($true)
        }.GetNewClosure()
        $this._panel.AddChild($this._okButton)
    }

    [void] Show([string]$title, [string]$message) {
        ([Dialog]$this).Show($title, $message)
        
        # Position OK button
        $this._okButton.X = [Math]::Floor(($this.Width - $this._okButton.Width) / 2)
        $this._okButton.Y = $this.Height - 4
    }

    [void] OnRender() {
        ([Dialog]$this).OnRender()
        
        if ($this.Visible -and $this.Message) {
            # Draw message within the dialog's panel content area
            $panelContentX = $this._panel.ContentX
            $panelContentY = $this._panel.ContentY
            $maxWidth = $this.Width - 4 # Panel width - 2*border - 2*padding

            # Simple word wrap (use Write-TuiText)
            $words = $this.Message -split ' '
            $currentLine = ""
            $currentY = $panelContentY + 1 # Start drawing message below title

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

        # Let OK button handle input first
        if ($this._okButton.HandleInput($key)) { return $true }
        
        if ($key.Key -eq [ConsoleKey]::Escape -or $key.Key -eq [ConsoleKey]::Enter) {
            $this.Complete($true) # Complete dialog
            return $true
        }
        return $false
    }

    [void] OnEnter() {
        # Set focus to the OK button when dialog appears
        $global:TuiState.Services.FocusManager?.SetFocus($this._okButton)
    }
}

#<!-- END_PAGE: ACO.018 -->
