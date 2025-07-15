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
        $this.TabIndex = 0
        $this.Width = 10
        $this.Height = 3
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Determine colors based on state, using effective colors for fallbacks
        # FIXED: Initialize variables at declaration to satisfy Set-StrictMode
        [string]$fgColor = $null
        [string]$bgColor = $null

        if ($this.IsPressed) {
            $fgColor = Get-ThemeColor "button.pressed.foreground" "#d4d4d4"
            $bgColor = Get-ThemeColor "button.pressed.background" "#4a5568"
        }
        elseif ($this.IsFocused) {
            $fgColor = Get-ThemeColor "button.focused.foreground" "#ffffff"
            $bgColor = Get-ThemeColor "button.focused.background" "#0e7490"
        }
        elseif (-not $this.Enabled) {
            $fgColor = Get-ThemeColor "button.disabled.foreground" "#6b7280"
            $bgColor = Get-ThemeColor "button.disabled.background" "#2d2d30"
        }
        else {
            # Use the effective colors from the base class for the normal state.
            # This allows instance-specific colors to override the theme.
            $fgColor = $this.GetEffectiveForegroundColor()
            $bgColor = $this.GetEffectiveBackgroundColor()
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

    [void] OnFocus() {
        $this.BackgroundColor = Get-ThemeColor "button.focused.background" "#0078d4"
        $this.ForegroundColor = Get-ThemeColor "button.focused.foreground" "#ffffff"
        $this.BorderColor = Get-ThemeColor "button.focused.border" "#00ff88"
        $this.RequestRedraw()
    }
    
    [void] OnBlur() {
        $this.BackgroundColor = Get-ThemeColor "button.normal.background" "#404040"
        $this.ForegroundColor = Get-ThemeColor "button.normal.foreground" "#d4d4d4"
        $this.BorderColor = Get-ThemeColor "button.border" "#666666"
        $this.RequestRedraw()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        if (-not $this.Enabled -or -not $this.IsFocused) { return $false }

        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            $this.IsPressed = $true
            $this.RequestRedraw()
            
            if ($this.OnClick) {
                try {
                    & $this.OnClick
                }
                catch {
                    # Log only errors, not debug info
                    if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Error -Message "Button '$($this.Name)' OnClick error: $_"
                    }
                }
            }
            
            $this.IsPressed = $false
            $this.RequestRedraw()
            
            return $true
        }
        return $false
    }
}

#<!-- END_PAGE: ACO.002 -->