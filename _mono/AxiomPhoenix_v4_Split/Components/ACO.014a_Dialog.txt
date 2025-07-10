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

# ===== CLASS: Dialog =====
# Module: dialog-system-class
# Dependencies: UIElement, Panel
# Purpose: Base class for modal dialogs
# NOTE: This file was renamed from ACO.017 to ACO.014a to ensure Dialog loads before its subclasses
class Dialog : UIElement {
    [string]$Title = ""
    [string]$Message = ""
    hidden [Panel]$_panel
    hidden [object]$Result = $null
    hidden [bool]$_isComplete = $false
    [scriptblock]$OnClose
    [DialogResult]$DialogResult = [DialogResult]::None

    Dialog([string]$name) : base($name) {
        $this.IsFocusable = $true  # FIXED: Dialog must be focusable to handle Escape
        $this.Visible = $false
        $this.IsOverlay = $true
        $this.Width = 50
        $this.Height = 10
        
        $this.InitializeDialog()
    }

    hidden [void] InitializeDialog() {
        $this._panel = [Panel]::new($this.Name + "_Panel")
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
        $this._panel.BorderColor = Get-ThemeColor("Primary")    # FIXED: Use theme color
        $this._panel.BackgroundColor = Get-ThemeColor("panel.background") # FIXED: Use theme color
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height
        $this.AddChild($this._panel)
    }

    [void] Show([string]$title, [string]$message) {
        $this.Title = $title
        $this.Message = $message
        $this._panel.Title = " $title "
        $this._isComplete = $false
        $this.Result = $null
        $this.Visible = $true
        $this.RequestRedraw()
    }

    # Renamed from Close to Complete to match guide
    [void] Complete([object]$result) {
        $this.Result = $result
        $this._isComplete = $true
        
        # Call the OnClose scriptblock if provided
        if ($this.OnClose) {
            try { 
                & $this.OnClose $result 
            } catch { 
                # Write-Log -Level Warning -Message "Dialog '$($this.Name)': Error in OnClose callback: $($_.Exception.Message)" 
            }
        }
        
        # Publish a general dialog close event for DialogManager to pick up
        if ($global:TuiState.Services.EventManager) {
            $global:TuiState.Services.EventManager.Publish("Dialog.Completed", @{ Dialog = $this; Result = $result })
        }
        # The DialogManager will then call HideDialog for actual UI removal and focus restoration.
    }

    # Legacy method for compatibility
    [void] Close([object]$result) {
        $this.Complete($result)
    }

    # New method for DialogManager to call to set initial focus within the dialog
    [void] SetInitialFocus() {
        $firstFocusable = $this.Children | Where-Object { $_.IsFocusable -and $_.Visible -and $_.Enabled } | Sort-Object TabIndex, Y, X | Select-Object -First 1
        if ($firstFocusable -and $global:TuiState.Services.FocusManager) {
            $global:TuiState.Services.FocusManager.SetFocus($firstFocusable)
            # Write-Log -Level Debug -Message "Dialog '$($this.Name)': Set initial focus to '$($firstFocusable.Name)'."
        }
    }

    # Update Title on render
    [void] OnRender() {
        # Base Panel's OnRender already draws border and title using ThemeManager colors
        $this._panel.Title = " $this.Title " # Ensure title is updated on panel
        $this._panel.OnRender() # Render the internal panel
    }

    [object] ShowDialog([string]$title, [string]$message) {
        $this.Show($title, $message)
        
        # In a real implementation, this would block until dialog closes
        # For now, return immediately
        return $this.Result
    }
}

#<!-- END_PAGE: ACO.014a -->
