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
    [object[]]$RawItems = @()  # Store original items for transformation
    [hashtable]$ViewDefinition = $null  # ViewDefinition from ViewDefinitionService
    [string[]]$DisplayStringCache = @()  # Cache for pre-formatted display strings
    [bool]$CacheValid = $false  # Flag to track cache validity
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
        $this.TabIndex = 0
        $this.Width = 60
        $this.Height = 20
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer
        $bgColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Use ViewDefinition if available, otherwise fall back to manual columns
        if ($this.ViewDefinition) {
            $this._RenderWithViewDefinition()
        } else {
            $this._RenderWithColumns()
        }
        
        $this._needs_redraw = $false
    }
    
    hidden [void] _RenderWithViewDefinition() {
        # Ensure cache is valid
        $this._EnsureDisplayCache()
        
        $y = 0
        $viewColumns = $this.ViewDefinition.Columns
        
        # Render headers if enabled
        if ($this.ShowHeaders -and $viewColumns.Count -gt 0) {
            $x = 0
            foreach ($column in $viewColumns) {
                $header = $column.Header
                $width = $column.Width
                
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
        
        # Render data rows using cached display strings
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            if ($i -ge $this.Items.Count) { break }
            
            $transformedItem = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            $x = 0
            foreach ($column in $viewColumns) {
                $value = if ($transformedItem.ContainsKey($column.Name)) { $transformedItem[$column.Name] } else { "" }
                $width = $column.Width
                
                # Handle style-aware cell data
                $text = ""
                $styleKey = "datagrid.cell.normal"
                
                if ($value -is [hashtable] -and $value.ContainsKey("Text")) {
                    # Enhanced style-aware format
                    $text = $value.Text
                    $styleKey = $value.Style ?? "datagrid.cell.normal"
                } else {
                    # Legacy format - convert to string
                    $text = $value.ToString()
                }
                
                # Truncate text if needed
                if ($text.Length -gt $width) {
                    $text = $text.Substring(0, [Math]::Max(1, $width - 2)) + ".."
                }
                
                # Pad text to column width
                $text = $text.PadRight($width)
                
                # Get colors from theme using semantic style key
                $fgColor = $this.NormalForegroundColor
                $bgColor = $this.NormalBackgroundColor
                
                if ($isSelected) {
                    # Override with selection colors
                    $fgColor = $this.SelectedForegroundColor
                    $bgColor = $this.SelectedBackgroundColor
                } else {
                    # Use theme colors based on style key
                    try {
                        $fgColor = Get-ThemeColor "$styleKey.foreground" $this.NormalForegroundColor
                        $bgColor = Get-ThemeColor "$styleKey.background" $this.NormalBackgroundColor
                    } catch {
                        # Fallback to normal colors if theme key not found
                        $fgColor = $this.NormalForegroundColor
                        $bgColor = $this.NormalBackgroundColor
                    }
                }
                
                Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $text -Style @{
                    FG = $fgColor
                    BG = $bgColor
                }
                
                $x += $width + 1  # +1 for separator
            }
            $y++
        }
    }
    
    hidden [void] _RenderWithColumns() {
        # Original rendering logic for backward compatibility
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
            Request-OptimizedRedraw -Source "DataGrid:$($this.Name)"
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
    
    [object] GetSelectedRawItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.RawItems.Count) {
            return $this.RawItems[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SetItems([object[]]$items) {
        $this.RawItems = $items
        $this.CacheValid = $false  # Invalidate cache
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        Request-OptimizedRedraw -Source "DataGrid:$($this.Name)"
    }
    
    [void] SetViewDefinition([hashtable]$viewDefinition) {
        $this.ViewDefinition = $viewDefinition
        $this.CacheValid = $false  # Invalidate cache
        Request-OptimizedRedraw -Source "DataGrid:$($this.Name)"
    }
    
    hidden [void] _EnsureDisplayCache() {
        if ($this.CacheValid -and $this.Items.Count -eq $this.RawItems.Count) {
            return  # Cache is valid
        }
        
        # Rebuild cache
        $this.Items = @()
        $this.DisplayStringCache = @()
        
        if ($this.ViewDefinition -and $this.ViewDefinition.Transformer) {
            $transformer = $this.ViewDefinition.Transformer
            
            foreach ($rawItem in $this.RawItems) {
                try {
                    # Transform the raw item using the ViewDefinition transformer
                    $transformedItem = & $transformer $rawItem
                    $this.Items += $transformedItem
                    
                    # Pre-format display string for performance (future enhancement)
                    # For now, we'll use the transformed item directly
                    $this.DisplayStringCache += ""  # Placeholder for future string caching
                }
                catch {
                    Write-Warning "DataGridComponent: Failed to transform item: $($_.Exception.Message)"
                    # Add empty item to maintain index consistency
                    $this.Items += @{}
                    $this.DisplayStringCache += ""
                }
            }
        } else {
            # No transformer, use raw items directly
            $this.Items = $this.RawItems
            $this.DisplayStringCache = @()
        }
        
        $this.CacheValid = $true
    }
    
    [void] SetColumns([hashtable[]]$columns) {
        $this.Columns = $columns
        Request-OptimizedRedraw -Source "DataGrid:$($this.Name)"
    }
}
#<!-- END_PAGE: ACO.022 -->