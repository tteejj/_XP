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

# ===== CLASS: RadioButtonComponent =====
# Module: tui-components
# Dependencies: UIElement, TuiCell
# Purpose: Exclusive selection with group management
class RadioButtonComponent : UIElement {
    [string]$Text = ""
    [bool]$Selected = $false
    [string]$GroupName = "default"
    [scriptblock]$OnChange
    static [hashtable]$_groups = @{}

    RadioButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        if ($this.IsFocused) { 
            $fgColor = Get-ThemeColor("Primary") 
        } else { 
            $fgColor = Get-ThemeColor("Foreground") 
        }
        if ($this.Selected) { 
            $radioMark = "(o)" 
        } else { 
            $radioMark = "( )" 
        }
        $fullText = "$radioMark $($this.Text)"
        
        Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $fullText -Style @{ FG = $fgColor; BG = $bgColor }
        
        $this._needs_redraw = $false
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        if ($key.Key -eq [ConsoleKey]::Spacebar -and -not $this.Selected) {
            $this.Select()
            return $true
        }
        
        return $false
    }

    [void] Select() {
        # Deselect all others in group
        if ([RadioButtonComponent]::_groups.ContainsKey($this.GroupName)) {
            foreach ($radio in [RadioButtonComponent]::_groups[$this.GroupName]) {
                if ($radio -ne $this -and $radio.Selected) {
                    $radio.Selected = $false
                    $radio.RequestRedraw()
                    if ($radio.OnChange) {
                        try { 
                            & $radio.OnChange $radio $false 
                        } catch {
                            # Ignore errors in onChange handler
                        }
                    }
                }
            }
        }
        
        $this.Selected = $true
        $this.RequestRedraw()
        if ($this.OnChange) {
            try { 
                & $this.OnChange $this $true 
            } catch {
                # Ignore errors in onChange handler
            }
        }
    }

    [void] AddedToParent() {
        if (-not [RadioButtonComponent]::_groups.ContainsKey($this.GroupName)) {
            [RadioButtonComponent]::_groups[$this.GroupName] = [List[RadioButtonComponent]]::new()
        }
        [RadioButtonComponent]::_groups[$this.GroupName].Add($this)
    }

    [void] RemovedFromParent() {
        if ([RadioButtonComponent]::_groups.ContainsKey($this.GroupName)) {
            [RadioButtonComponent]::_groups[$this.GroupName].Remove($this)
        }
    }
}

#endregion Core UI Components

#region Advanced Components

#<!-- END_PAGE: ACO.005 -->
