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

#region Core UI Components

# ===== CLASS: LabelComponent =====
# Module: tui-components
# Dependencies: UIElement
# Purpose: Static text display
class LabelComponent : UIElement {
    [string]$Text = ""
    [object]$ForegroundColor

    LabelComponent([string]$name) : base($name) {
        $this.IsFocusable = $false
        $this.Width = 30  # Increased default width
        $this.Height = 1
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer with theme background
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Get foreground color
        if ($this.ForegroundColor) {
            if ($this.ForegroundColor -is [ConsoleColor]) {
                # Convert ConsoleColor to hex if needed
                $fg = Get-ThemeColor("Foreground") # Use theme default instead
            } else {
                $fg = $this.ForegroundColor # Assume it's already hex
            }
        } else {
            $fg = Get-ThemeColor("Foreground")
        }
        
        # Draw text
        Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $this.Text -Style @{ FG = $fg; BG = $bgColor }
        
        $this._needs_redraw = $false
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $false
    }
}
#<!-- END_PAGE: ACO.001 -->
