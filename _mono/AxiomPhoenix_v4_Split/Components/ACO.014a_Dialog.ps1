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
        $this.IsOverlay = $true # This tells the renderer to treat it as an overlay
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
        # The panel is a child of the Dialog (Screen)
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
        if ($this._isComplete) { return } # Prevent double execution

        $this.Result = $result
        $this._isComplete = $true
        
        # Call the OnClose scriptblock if provided
        if ($this.OnClose) {
            try { 
                & $this.OnClose $result 
            } catch { 
                if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                    Write-Log -Level Warning -Message "Dialog '$($this.Name)': Error in OnClose callback: $($_.Exception.Message)" 
                }
            }
        }
        
        # Navigate back to previous screen
        $navService = $this.ServiceContainer.GetService("NavigationService")
        if ($navService -and $navService.CanGoBack()) {
            $navService.GoBack()
        }
    }

    # Legacy method for compatibility
    [void] Close([object]$result) {
        $this.Complete($result)
    }

    # Override Screen's OnEnter to set focus
    [void] OnEnter() {
        # Call base Screen method to enable focus management
        ([Screen]$this).OnEnter()
    }

    # Override HandleInput to provide Dialog-specific behavior
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        # Check for Escape at dialog level to cancel
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Complete($null)
            return $true
        }
        
        # Otherwise use default Screen behavior (Tab navigation, route to focused child)
        return ([Screen]$this).HandleInput($key)
    }

    # Override render to center the dialog's panel
    [void] OnRender() {
        # Clear the entire screen buffer with a dimmed/overlay effect
        # A simple way is to fill with a dark, semi-transparent character or just black
        $overlayCell = [TuiCell]::new(' ', "#000000", "#000000") 
        $this._private_buffer.Clear($overlayCell)

        # Center the panel within the dialog's screen area
        $this._panel.X = [Math]::Floor(($this.Width - $this._panel.Width) / 2)
        $this._panel.Y = [Math]::Floor(($this.Height - $this._panel.Height) / 2)
        
        # Update panel title
        $this._panel.Title = " $this.Title "

        # The base UIElement._RenderContent will handle rendering the child panel
    }
}

#<!-- END_PAGE: ACO.014a -->