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

# ===== CLASS: NavigationMenu =====
# Module: navigation-class
# Dependencies: UIElement, NavigationItem
# Purpose: Local menu component
class NavigationMenu : UIElement {
    [List[NavigationItem]]$Items
    [int]$SelectedIndex = 0
    [string]$Orientation = "Horizontal"  # Horizontal or Vertical
    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$SelectedBackgroundColor = "#0078D4"
    [string]$SelectedForegroundColor = "#FFFF00"

    NavigationMenu([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Items = [List[NavigationItem]]::new()
        $this.Height = 1
    }

    [void] AddItem([NavigationItem]$item) {
        $this.Items.Add($item)
        $this.RequestRedraw()
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', $this.ForegroundColor, $this.BackgroundColor))
            
            if ($this.Orientation -eq "Horizontal") {
                $this.RenderHorizontal()
            }
            else {
                $this.RenderVertical()
            }
        }
        catch {}
    }

    hidden [void] RenderHorizontal() {
        $currentX = 0
        
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex -and $this.IsFocused)
            
            $fg = if ($isSelected) { $this.SelectedForegroundColor } else { $this.ForegroundColor }
            $bg = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.BackgroundColor }
            
            # Draw item
            $text = " $($item.Label) "
            if ($item.Key) {
                $text = " $($item.Label) ($($item.Key)) "
            }
            
            if ($currentX + $text.Length -le $this.Width) {
                for ($x = 0; $x -lt $text.Length; $x++) {
                    $this._private_buffer.SetCell($currentX + $x, 0, 
                        [TuiCell]::new($text[$x], $fg, $bg))
                }
            }
            
            $currentX += $text.Length + 1
        }
    }

    hidden [void] RenderVertical() {
        # Ensure height matches item count
        if ($this.Height -ne $this.Items.Count -and $this.Items.Count -gt 0) {
            $this.Height = $this.Items.Count
            # Resize the buffer to match new height
            if ($this._private_buffer) {
                $this._private_buffer.Resize($this.Width, $this.Height)
            }
        }
        
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex -and $this.IsFocused)
            
            $fg = if ($isSelected) { $this.SelectedForegroundColor } else { $this.ForegroundColor }
            $bg = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.BackgroundColor }
            
            # Clear line
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this._private_buffer.SetCell($x, $i, [TuiCell]::new(' ', $fg, $bg))
            }
            
            # Draw item
            $text = $item.Label
            if ($item.Key) {
                $text = "$($item.Label) ($($item.Key))"
            }
            
            if ($text.Length -gt $this.Width) {
                $text = $text.Substring(0, $this.Width - 3) + "..."
            }
            
            $this._private_buffer.WriteString(0, $i, $text, @{ FG = $fg; BG = $bg })
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or $this.Items.Count -eq 0) { return $false }
        
        $handled = $true
        
        if ($this.Orientation -eq "Horizontal") {
            switch ($key.Key) {
                ([ConsoleKey]::LeftArrow) {
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                        $this.SelectedIndex++
                    }
                }
                ([ConsoleKey]::Enter) {
                    $this.ExecuteItem($this.SelectedIndex)
                }
                default {
                    # Check hotkeys
                    $handled = $this.CheckHotkey($key)
                }
            }
        }
        else {
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                        $this.SelectedIndex++
                    }
                }
                ([ConsoleKey]::Enter) {
                    $this.ExecuteItem($this.SelectedIndex)
                }
                default {
                    $handled = $this.CheckHotkey($key)
                }
            }
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }

    hidden [bool] CheckHotkey([System.ConsoleKeyInfo]$key) {
        foreach ($i in 0..($this.Items.Count - 1)) {
            $item = $this.Items[$i]
            if ($item.Key -and $item.Key.ToUpper() -eq $key.KeyChar.ToString().ToUpper()) {
                $this.SelectedIndex = $i
                $this.ExecuteItem($i)
                return $true
            }
        }
        return $false
    }

    hidden [void] ExecuteItem([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            $item = $this.Items[$index]
            if ($item.Action) {
                try {
                    & $item.Action
                }
                catch {}
            }
        }
    }
}

#<!-- END_PAGE: ACO.021 -->
