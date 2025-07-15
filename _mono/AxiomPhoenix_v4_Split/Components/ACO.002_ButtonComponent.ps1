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
            $fgColor = Get-ThemeColor "button.normal.foreground" ($this.GetEffectiveForegroundColor())
            $bgColor = Get-ThemeColor "button.normal.background" ($this.GetEffectiveBackgroundColor())
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
        # Don't cache theme colors - get them fresh during render
        $this.RequestRedraw()
    }
    
    [void] OnBlur() {
        # Don't cache theme colors - get them fresh during render
        $this.RequestRedraw()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { 
            Write-Log -Level Debug -Message "Button '$($this.Name)': Received null key"
            return $false 
        }
        
        Write-Log -Level Debug -Message "Button '$($this.Name)': Received key $($key.Key), Enabled: $($this.Enabled), IsFocused: $($this.IsFocused)"
        
        if (-not $this.Enabled -or -not $this.IsFocused) { 
            Write-Log -Level Debug -Message "Button '$($this.Name)': Not handling key - not enabled or not focused"
            return $false 
        }

        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            Write-Log -Level Debug -Message "Button '$($this.Name)': Processing Enter/Space key"
            $this.IsPressed = $true
            $this.RequestRedraw()
            
            if ($this.OnClick) {
                Write-Log -Level Debug -Message "Button '$($this.Name)': Executing OnClick handler"
                try {
                    & $this.OnClick
                    Write-Log -Level Debug -Message "Button '$($this.Name)': OnClick executed successfully"
                }
                catch {
                    # Log the actual error
                    if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Error -Message "Button '$($this.Name)' OnClick error: $_"
                    }
                    # Silently continue if Write-Log not available - no console output in TUI
                }
            } else {
                Write-Log -Level Warning -Message "Button '$($this.Name)': No OnClick handler defined"
            }
            
            $this.IsPressed = $false
            $this.RequestRedraw()
            
            return $true
        }
        Write-Log -Level Debug -Message "Button '$($this.Name)': Key $($key.Key) not handled"
        return $false
    }
}

#<!-- END_PAGE: ACO.002 -->