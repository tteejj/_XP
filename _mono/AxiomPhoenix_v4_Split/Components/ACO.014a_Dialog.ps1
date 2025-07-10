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
# Dependencies: Screen, Panel
# Purpose: Base class for modal dialogs - NOW A WINDOW TYPE
# FIXED: Dialog now inherits from Screen for proper window-based input
class Dialog : Screen {
    [string]$Title = ""
    [string]$Message = ""
    hidden [Panel]$_panel
    hidden [object]$Result = $null
    hidden [bool]$_isComplete = $false
    [scriptblock]$OnClose
    [DialogResult]$DialogResult = [DialogResult]::None
    
    # Store the screen we came from
    hidden [object]$_previousScreen = $null

    Dialog([string]$name, [object]$serviceContainer) : base($name, $serviceContainer) {
        $this.IsOverlay = $true
        $this.Width = 50
        $this.Height = 10
        
        $this.InitializeDialog()
    }

    hidden [void] InitializeDialog() {
        $this._panel = [Panel]::new($this.Name + "_Panel")
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
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

    [void] Complete([object]$result) {
        $this.Result = $result
        $this._isComplete = $true
        
        # Call the OnClose scriptblock if provided
        if ($this.OnClose) {
            try { 
                & $this.OnClose $result 
            } catch { 
                Write-Log -Level Warning -Message "Dialog '$($this.Name)': Error in OnClose callback: $($_.Exception.Message)" 
            }
        }
        
        # Navigate back to previous screen
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navService) {
            if ($navService.CanGoBack()) {
                $navService.GoBack()
            } else {
                Write-Log -Level Warning -Message "Dialog '$($this.Name)': Cannot go back, no previous screen"
            }
        }
    }

    # Legacy method for compatibility
    [void] Close([object]$result) {
        $this.Complete($result)
    }

    # Override Screen's OnEnter to set focus
    [void] OnEnter() {
        ([Screen]$this).OnEnter()
        $this.SetInitialFocus()
    }

    # Override HandleInput to provide Dialog-specific behavior
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        # Check for Escape at dialog level
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Complete($null)
            return $true
        }
        
        # Otherwise use default Screen behavior
        return ([Screen]$this).HandleInput($key)
    }

    [void] SetInitialFocus() {
        # Find first focusable child
        $firstFocusable = $null
        $this.FindFocusableChild($this._panel, [ref]$firstFocusable)
        
        if ($firstFocusable) {
            $focusManager = $this.ServiceContainer?.GetService("FocusManager")
            if ($focusManager) {
                $focusManager.SetFocus($firstFocusable)
                Write-Log -Level Debug -Message "Dialog '$($this.Name)': Set initial focus to '$($firstFocusable.Name)'."
            }
        }
    }
    
    hidden [void] FindFocusableChild([UIElement]$parent, [ref]$result) {
        if ($result.Value) { return }
        
        foreach ($child in $parent.Children) {
            if ($child.IsFocusable -and $child.Visible -and $child.Enabled) {
                $result.Value = $child
                return
            }
            if ($child.Children.Count -gt 0) {
                $this.FindFocusableChild($child, $result)
            }
        }
    }

    # Override render to center the dialog
    [void] OnRender() {
        # Center the panel
        $this._panel.X = [Math]::Floor(($this.Width - $this._panel.Width) / 2)
        $this._panel.Y = [Math]::Floor(($this.Height - $this._panel.Height) / 2)
        
        # Update panel title
        $this._panel.Title = " $this.Title "
        
        # Clear background with semi-transparent effect (simulate with darker color)
        $bgColor = Get-ThemeColor("overlay.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
    }

    [object] ShowDialog([string]$title, [string]$message) {
        $this.Show($title, $message)
        
        # Navigate to this dialog
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navService) {
            $navService.NavigateTo($this)
        }
        
        return $this.Result
    }
}

#<!-- END_PAGE: ACO.014a -->
