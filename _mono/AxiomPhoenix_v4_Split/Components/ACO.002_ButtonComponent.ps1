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

# ===== CLASS: ButtonComponent =====
# Module: tui-components
# Dependencies: UIElement, TuiCell
# Purpose: Interactive button with click events
class ButtonComponent : UIElement {
    [string]$Text = "Button"
    [bool]$IsPressed = $false
    [scriptblock]$OnClick

    ButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 10
        $this.Height = 3
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer with theme background
        $bgColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Determine colors based on state
        $fgColor = "#FFFFFF"
        $bgColor = "#333333"
        
        if ($this.IsPressed) {
            $fgColor = Get-ThemeColor "Button.Pressed.Foreground" "#d4d4d4"
            $bgColor = Get-ThemeColor "Button.Pressed.Background" "#4a5568"
        }
        elseif ($this.IsFocused) {
            $fgColor = Get-ThemeColor "Button.Focused.Foreground" "#ffffff"
            $bgColor = Get-ThemeColor "Button.Focused.Background" "#0e7490"
        }
        elseif (-not $this.Enabled) {
            $fgColor = Get-ThemeColor "Button.Disabled.Foreground" "#6b7280"
            $bgColor = Get-ThemeColor "Button.Disabled.Background" "#2d2d30"
        }
        else {
            $fgColor = Get-ThemeColor "Button.Normal.Foreground" "#ffffff"
            $bgColor = Get-ThemeColor "Button.Normal.Background" "#007acc"
        }
        
        # Draw button background
        $style = @{ FG = $fgColor; BG = $bgColor }
        $this._private_buffer.FillRect(0, 0, $this.Width, $this.Height, ' ', $style)
        
        # Draw button text centered
        if (-not [string]::IsNullOrEmpty($this.Text)) {
            $textX = [Math]::Max(0, [Math]::Floor(($this.Width - $this.Text.Length) / 2))
            $textY = [Math]::Floor($this.Height / 2)
            
            Write-TuiText -Buffer $this._private_buffer -X $textX -Y $textY -Text $this.Text -Style $style
        }
        
        $this._needs_redraw = $false
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            try {
                $this.IsPressed = $true
                $this.RequestRedraw()
                
                if ($this.OnClick) {
                    & $this.OnClick
                }
                
                Start-Sleep -Milliseconds 50
                $this.IsPressed = $false
                $this.RequestRedraw()
                
                return $true
            }
            catch {
                $this.IsPressed = $false
                $this.RequestRedraw()
            }
        }
        return $false
    }
}

#<!-- END_PAGE: ACO.002 -->
