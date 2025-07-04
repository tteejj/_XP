# ==============================================================================
# Advanced Data Components Module v3.0
# High-performance, theme-aware data display components for TUI applications
# ==============================================================================

using namespace System.Collections.Generic

#region Table Classes

class TableColumn {
    [string]$Key
    [string]$Header
    [object]$Width # Can be [int] or the string 'Auto'
    [string]$Alignment = "Left"

    TableColumn([Parameter(Mandatory)][string]$key, [Parameter(Mandatory)][string]$header, [Parameter(Mandatory)][object]$width) {
        $this.Key = $key
        $this.Header = $header
        $this.Width = $width
    }

    [string] ToString() {
        return "TableColumn(Key='$($this.Key)', Header='$($this.Header)', Width=$($this.Width))"
    }
}

class Table : UIElement {
    [System.Collections.Generic.List[TableColumn]]$Columns
    [object[]]$Data = @()
    [int]$SelectedIndex = 0
    [bool]$ShowBorder = $true
    [bool]$ShowHeader = $true
    [scriptblock]$OnSelectionChanged
    hidden [int]$_scrollOffset = 0 # The index of the first visible row

    Table([Parameter(Mandatory)][string]$name) : base($name) {
        $this.Columns = [System.Collections.Generic.List[TableColumn]]::new()
        $this.IsFocusable = $true
        $this.Width = 60
        $this.Height = 15
        Write-Verbose "Table: Constructor called for '$($this.Name)'"
    }

    [void] SetColumns([Parameter(Mandatory)][TableColumn[]]$columns) {
        try {
            $this.Columns.Clear()
            foreach ($col in $columns) {
                $this.Columns.Add($col)
            }
            $this.RequestRedraw()
            Write-Verbose "Table '$($this.Name)': Set $($columns.Count) columns"
        }
        catch {
            Write-Error "Table '$($this.Name)': Error setting columns: $($_.Exception.Message)"
            throw
        }
    }

    [void] SetData([Parameter(Mandatory)][object[]]$data) {
        try {
            $this.Data = @($data) # Consistently cast to an array
            if ($this.SelectedIndex -ge $this.Data.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.Data.Count - 1)
            }
            $this._scrollOffset = 0 # Reset scroll on new data
            $this.RequestRedraw()
            Write-Verbose "Table '$($this.Name)': Set data with $($this.Data.Count) items"
        }
        catch {
            Write-Error "Table '$($this.Name)': Error setting data: $($_.Exception.Message)"
            throw
        }
    }

    [void] SelectNext() {
        if ($this.SelectedIndex -lt ($this.Data.Count - 1)) {
            $this.SelectedIndex++
            $this._EnsureVisible()
            $this.RequestRedraw()
            Write-Verbose "Table '$($this.Name)': Selected next item (index $($this.SelectedIndex))"
        }
    }

    [void] SelectPrevious() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this._EnsureVisible()
            $this.RequestRedraw()
            Write-Verbose "Table '$($this.Name)': Selected previous item (index $($this.SelectedIndex))"
        }
    }

    [object] GetSelectedItem() {
        if ($this.Data.Count -gt 0 -and $this.SelectedIndex -in (0..($this.Data.Count - 1))) {
            return $this.Data[$this.SelectedIndex]
        }
        return $null
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear buffer with theme-aware colors
            $bgColor = Get-ThemeColor 'Background'
            $fgColor = Get-ThemeColor 'Foreground'
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            
            # Draw border if enabled
            if ($this.ShowBorder) {
                $borderColor = Get-ThemeColor 'Border'
                Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
            }

            $contentWidth = if ($this.ShowBorder) { $this.Width - 2 } else { $this.Width }
            $contentHeight = $this._GetContentHeight()
            $renderX = if ($this.ShowBorder) { 1 } else { 0 }
            $currentY = if ($this.ShowBorder) { 1 } else { 0 }
            
            # Resolve auto-sized column widths
            $resolvedColumns = $this._ResolveColumnWidths($contentWidth)
            
            # Header
            if ($this.ShowHeader -and $resolvedColumns.Count -gt 0) {
                $headerColor = Get-ThemeColor 'Header'
                $xOffset = 0
                foreach ($col in $resolvedColumns) {
                    $headerText = $this._FormatCell($col.Header, $col.ResolvedWidth, $col.Alignment)
                    Write-TuiText -Buffer $this._private_buffer -X ($renderX + $xOffset) -Y $currentY -Text $headerText -ForegroundColor $headerColor -BackgroundColor $bgColor
                    $xOffset += $col.ResolvedWidth
                }
                $currentY++
            }
            
            # Data rows (respecting scroll offset)
            for ($i = 0; $i -lt $contentHeight; $i++) {
                $dataIndex = $i + $this._scrollOffset
                if ($dataIndex -ge $this.Data.Count) { break }
                $row = $this.Data[$dataIndex]
                if (-not $row) { continue }

                $isSelected = ($dataIndex -eq $this.SelectedIndex)
                $bg = if ($isSelected -and $this.IsFocused) { Get-ThemeColor 'Selection' } else { $bgColor }
                $fg = if ($isSelected -and $this.IsFocused) { Get-ThemeColor 'Background' } else { $fgColor }

                $xOffset = 0
                foreach ($col in $resolvedColumns) {
                    $propValue = $row | Select-Object -ExpandProperty $col.Key -ErrorAction SilentlyContinue
                    $cellValue = if ($propValue) { $propValue.ToString() } else { "" }
                    $cellText = $this._FormatCell($cellValue, $col.ResolvedWidth, $col.Alignment)
                    Write-TuiText -Buffer $this._private_buffer -X ($renderX + $xOffset) -Y $currentY -Text $cellText -ForegroundColor $fg -BackgroundColor $bg
                    $xOffset += $col.ResolvedWidth
                }
                $currentY++
            }

            # Show message if no data
            if ($this.Data.Count -eq 0) {
                $subtleColor = Get-ThemeColor 'Subtle'
                Write-TuiText -Buffer $this._private_buffer -X $renderX -Y $currentY -Text " (No data to display) " -ForegroundColor $subtleColor -BackgroundColor $bgColor
            }
        }
        catch {
            Write-Error "Table '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([Parameter(Mandatory)][System.ConsoleKeyInfo]$keyInfo) {
        try {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) { 
                    $this.SelectPrevious()
                    return $true
                }
                ([ConsoleKey]::DownArrow) { 
                    $this.SelectNext()
                    return $true
                }
                ([ConsoleKey]::PageUp) { 
                    0..($this._GetContentHeight() - 1) | ForEach-Object { $this.SelectPrevious() }
                    return $true
                }
                ([ConsoleKey]::PageDown) { 
                    0..($this._GetContentHeight() - 1) | ForEach-Object { $this.SelectNext() }
                    return $true
                }
                ([ConsoleKey]::Home) { 
                    $this.SelectedIndex = 0
                    $this._EnsureVisible()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::End) { 
                    $this.SelectedIndex = $this.Data.Count - 1
                    $this._EnsureVisible()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($this.OnSelectionChanged) {
                        $item = $this.GetSelectedItem()
                        if ($item) {
                            Invoke-WithErrorHandling -Component "$($this.Name).OnSelectionChanged" -ScriptBlock {
                                & $this.OnSelectionChanged -SelectedItem $item
                            }
                        }
                    }
                    return $true
                }
            }
        }
        catch {
            Write-Error "Table '$($this.Name)': Error handling input: $($_.Exception.Message)"
        }
        return $false
    }
    
    # Ensure the selected item is visible in the viewport
    hidden [void] _EnsureVisible() {
        $contentHeight = $this._GetContentHeight()
        
        # Scroll down if selected item is below visible area
        if ($this.SelectedIndex -ge ($this._scrollOffset + $contentHeight)) {
            $this._scrollOffset = $this.SelectedIndex - $contentHeight + 1
        }
        
        # Scroll up if selected item is above visible area
        if ($this.SelectedIndex -lt $this._scrollOffset) {
            $this._scrollOffset = $this.SelectedIndex
        }
        
        # Ensure scroll offset is within bounds
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
    }
    
    # Calculate available height for content (excluding border and header)
    hidden [int] _GetContentHeight() {
        $h = $this.Height
        if ($this.ShowBorder) { $h -= 2 }
        if ($this.ShowHeader) { $h -= 1 }
        return [Math]::Max(0, $h)
    }

    # Format cell content with proper alignment and overflow handling
    hidden [string] _FormatCell([string]$text, [int]$width, [string]$alignment) {
        if ([string]::IsNullOrEmpty($text)) { return ' ' * $width }
        
        # Handle overflow with ellipsis
        if ($text.Length -gt $width) { 
            $text = $text.Substring(0, $width - 1) + '…' 
        }
        
        # Apply alignment
        return switch ($alignment.ToLower()) {
            'right' { $text.PadLeft($width) }
            'center' { 
                $pad = [Math]::Max(0, ($width - $text.Length) / 2)
                $padded = (' ' * $pad) + $text
                $padded.PadRight($width)
            }
            default { $text.PadRight($width) }
        }
    }
    
    # Resolve column widths, handling 'Auto' sizing
    hidden [object[]] _ResolveColumnWidths([int]$totalWidth) {
        $fixedWidth = 0
        $autoCols = @()
        $resolved = @()

        # First pass: calculate fixed widths and identify auto columns
        foreach ($col in $this.Columns) {
            if ($col.Width -is [int]) {
                $fixedWidth += $col.Width
                $resolved += [pscustomobject]@{ 
                    Original = $col
                    ResolvedWidth = $col.Width
                    Key = $col.Key
                    Header = $col.Header
                    Alignment = $col.Alignment
                }
            } else {
                $autoCols += $col
            }
        }

        # Second pass: distribute remaining width among auto columns
        if ($autoCols.Count -gt 0) {
            $remainingWidth = $totalWidth - $fixedWidth
            $autoWidth = [Math]::Max(1, [Math]::Floor($remainingWidth / $autoCols.Count))
            
            foreach ($col in $autoCols) {
                $resolved += [pscustomobject]@{ 
                    Original = $col
                    ResolvedWidth = $autoWidth
                    Key = $col.Key
                    Header = $col.Header
                    Alignment = $col.Alignment
                }
            }
        }

        # Return in original column order
        $orderedResolved = @()
        foreach ($originalCol in $this.Columns) {
            $matchedCol = $resolved | Where-Object { $_.Original -eq $originalCol } | Select-Object -First 1
            if ($matchedCol) {
                $orderedResolved += $matchedCol
            }
        }
        
        return $orderedResolved
    }

    [string] ToString() {
        return "Table(Name='$($this.Name)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height), Data=$($this.Data.Count) items, Selected=$($this.SelectedIndex))"
    }
}

#endregion

#region Factory Functions

function New-TuiTable {
    <#
    .SYNOPSIS
    Creates a new Table component with specified properties.
    
    .DESCRIPTION
    Factory function to create a Table component with configurable properties.
    The table supports scrolling, theme integration, and event-driven selection.
    
    .PARAMETER Props
    Hashtable of properties to apply to the table component.
    
    .EXAMPLE
    $table = New-TuiTable -Props @{
        Name = "MyTable"
        Width = 60
        Height = 15
        ShowBorder = $true
        OnSelectionChanged = { param($SelectedItem) Write-Host "Selected: $($SelectedItem.Name)" }
    }
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Props = @{}
    )
    
    try {
        $tableName = $Props.Name ?? "Table_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $table = [Table]::new($tableName)
        
        # Apply properties
        $Props.GetEnumerator() | ForEach-Object {
            $propertyName = $_.Name
            $propertyValue = $_.Value
            
            if ($table.PSObject.Properties.Match($propertyName)) {
                $table.($propertyName) = $propertyValue
            }
        }
        
        # Special handling for columns and data
        if ($Props.Columns) {
            $table.SetColumns($Props.Columns)
        }
        if ($Props.Data) {
            $table.SetData($Props.Data)
        }
        
        Write-Verbose "Created table '$tableName' with $($Props.Count) properties"
        return $table
    }
    catch {
        Write-Error "Failed to create table: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Module Exports

# Export public functions
Export-ModuleMember -Function New-TuiTable

# Classes are automatically exported in PowerShell 7+
# Table, TableColumn classes are available when module is imported

#endregion
