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

# ===== CLASS: DataGridComponent =====
# Module: data-grid-component
# Dependencies: UIElement, TuiCell
# Purpose: Generic data grid for displaying tabular data with scrolling and selection
class DataGridComponent : UIElement {
    [hashtable[]]$Columns = @()
    [hashtable[]]$Items = @()
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowHeaders = $true
    [string]$HeaderBackgroundColor = "#333333"
    [string]$HeaderForegroundColor = "#FFFFFF"
    [string]$SelectedBackgroundColor = "#0078D4"
    [string]$SelectedForegroundColor = "#FFFFFF"
    [string]$NormalBackgroundColor = "#000000"
    [string]$NormalForegroundColor = "#C0C0C0"
    [scriptblock]$OnSelectionChanged
    
    DataGridComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 60
        $this.Height = 20
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer
        $bgColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        $y = 0
        
        # Render headers if enabled
        if ($this.ShowHeaders -and $this.Columns.Count -gt 0) {
            $x = 0
            foreach ($column in $this.Columns) {
                $header = if ($column.Header) { $column.Header } else { $column.Name }
                $width = if ($column.Width) { $column.Width } else { 10 }
                
                # Truncate header if needed
                if ($header.Length -gt $width) {
                    $header = $header.Substring(0, [Math]::Max(1, $width - 2)) + ".."
                }
                
                # Pad header to column width
                $header = $header.PadRight($width)
                
                Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $header -Style @{
                    FG = $this.HeaderForegroundColor
                    BG = $this.HeaderBackgroundColor
                }
                
                $x += $width + 1  # +1 for separator
            }
            $y++
        }
        
        # Calculate visible items
        $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
        $startIndex = $this.ScrollOffset
        $endIndex = [Math]::Min($this.Items.Count - 1, $startIndex + $visibleHeight - 1)
        
        # Render data rows
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            if ($i -ge $this.Items.Count) { break }
            
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            $x = 0
            foreach ($column in $this.Columns) {
                $value = if ($item.ContainsKey($column.Name)) { $item[$column.Name] } else { "" }
                $width = if ($column.Width) { $column.Width } else { 10 }
                
                # Convert value to string and truncate if needed
                $text = $value.ToString()
                if ($text.Length -gt $width) {
                    $text = $text.Substring(0, [Math]::Max(1, $width - 2)) + ".."
                }
                
                # Pad text to column width
                $text = $text.PadRight($width)
                
                # Set colors based on selection
                $fgColor = if ($isSelected) { $this.SelectedForegroundColor } else { $this.NormalForegroundColor }
                $bgColor = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.NormalBackgroundColor }
                
                Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $text -Style @{
                    FG = $fgColor
                    BG = $bgColor
                }
                
                $x += $width + 1  # +1 for separator
            }
            $y++
        }
        
        $this._needs_redraw = $false
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.Enabled -or -not $this.IsFocused) { return $false }
        
        $handled = $false
        $oldSelectedIndex = $this.SelectedIndex
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this._EnsureVisible()
                    $handled = $true
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                    $this.SelectedIndex++
                    $this._EnsureVisible()
                    $handled = $true
                }
            }
            ([ConsoleKey]::PageUp) {
                $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $visibleHeight)
                $this._EnsureVisible()
                $handled = $true
            }
            ([ConsoleKey]::PageDown) {
                $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $visibleHeight)
                $this._EnsureVisible()
                $handled = $true
            }
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this._EnsureVisible()
                $handled = $true
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = [Math]::Max(0, $this.Items.Count - 1)
                $this._EnsureVisible()
                $handled = $true
            }
        }
        
        # Fire selection changed event if selection changed
        if ($handled -and $oldSelectedIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
            & $this.OnSelectionChanged $this $this.SelectedIndex
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    hidden [void] _EnsureVisible() {
        if ($this.Items.Count -eq 0) { return }
        
        $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
        
        # Scroll up if selected item is above visible area
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        }
        # Scroll down if selected item is below visible area
        elseif ($this.SelectedIndex -gt ($this.ScrollOffset + $visibleHeight - 1)) {
            $this.ScrollOffset = $this.SelectedIndex - $visibleHeight + 1
        }
        
        # Ensure scroll offset is within bounds
        $this.ScrollOffset = [Math]::Max(0, [Math]::Min($this.ScrollOffset, $this.Items.Count - $visibleHeight))
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SetItems([hashtable[]]$items) {
        $this.Items = $items
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this.RequestRedraw()
    }
    
    [void] SetColumns([hashtable[]]$columns) {
        $this.Columns = $columns
        $this.RequestRedraw()
    }
}
#<!-- END_PAGE: ACO.022 -->