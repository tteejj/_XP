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

# ===== CLASS: CheckBoxComponent =====
# Module: tui-components
# Dependencies: UIElement, TuiCell
# Purpose: Boolean checkbox input
class CheckBoxComponent : UIElement {
    [string]$Text = ""
    [bool]$Checked = $false
    [scriptblock]$OnChange

    CheckBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.TabIndex = 0
        $this.Width = 20
        $this.Height = 1
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        $bgColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        if ($this.IsFocused) { 
            $fgColor = Get-ThemeColor "Panel.Title" "#007acc"
        } else { 
            $fgColor = Get-ThemeColor "Label.Foreground" "#d4d4d4"
        }
        if ($this.Checked) { 
            $checkMark = "[X]" 
        } else { 
            $checkMark = "[ ]" 
        }
        $fullText = "$checkMark $($this.Text)"
        
        Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $fullText -Style @{ FG = $fgColor; BG = $bgColor }
        
        $this._needs_redraw = $false
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        if ($key.Key -eq [ConsoleKey]::Spacebar) {
            $this.Checked = -not $this.Checked
            if ($this.OnChange) {
                try { 
                    & $this.OnChange $this $this.Checked 
                } catch {
                    # Ignore errors in onChange handler
                }
            }
            $this.RequestRedraw()
            return $true
        }
        
        return $false
    }
}

#<!-- END_PAGE: ACO.004 -->
