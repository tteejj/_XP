# Advanced Data Components Module for PMC Terminal v5
# Enhanced data display components with sorting, filtering, and pagination

using namespace System.Text
using namespace System.Management.Automation
using module ..\components\ui-classes.psm1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#region Simple Table Classes

class TableColumn {
    [string]$Key
    [string]$Header
    [int]$Width
    [string]$Alignment = "Left"
    
    TableColumn([string]$key, [string]$header, [int]$width) {
        $this.Key = $key
        $this.Header = $header
        $this.Width = $width
    }
}

class Table : Component {
    [System.Collections.Generic.List[TableColumn]]$Columns
    [object[]]$Data = @()
    [int]$SelectedIndex = 0
    [bool]$ShowBorder = $true
    [bool]$ShowHeader = $true
    
    Table([string]$name) : base($name) {
        $this.Columns = [System.Collections.Generic.List[TableColumn]]::new()
        # AI: FIX - Explicit array initialization
        $this.Data = @()
        $this.SelectedIndex = 0
    }
    
    [void] SetColumns([TableColumn[]]$columns) {
        $this.Columns.Clear()
        foreach ($col in $columns) {
            $this.Columns.Add($col)
        }
    }
    
    [void] SetData([object[]]$data) {
        # AI: FIX - Defensive array initialization
        $this.Data = if ($null -eq $data) { @() } else { @($data) }
        # AI: FIX - Safe array count check
        $dataCount = if ($this.Data -is [array]) { $this.Data.Count } else { 1 }
        if ($this.SelectedIndex -ge $dataCount) {
            $this.SelectedIndex = [Math]::Max(0, $dataCount - 1)
        }
    }
    
    [void] SelectNext() {
        # AI: FIX - Safe array count check
        $dataCount = if ($null -eq $this.Data) { 0 } elseif ($this.Data -is [array]) { $this.Data.Count } else { 1 }
        if ($this.SelectedIndex -lt ($dataCount - 1)) {
            $this.SelectedIndex++
        }
    }
    
    [void] SelectPrevious() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
        }
    }
    
    [object] GetSelectedItem() {
        # AI: FIX - Safe array access with null checking
        if ($null -eq $this.Data) { return $null }
        
        $dataCount = if ($this.Data -is [array]) { $this.Data.Count } else { 1 }
        
        if ($dataCount -gt 0 -and $this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $dataCount) {
            return if ($this.Data -is [array]) { $this.Data[$this.SelectedIndex] } else { $this.Data }
        }
        return $null
    }
    
    hidden [void] _RenderContent() {
        # AI: Render table to buffer using Write-BufferString
        if (-not (Get-Command "Write-BufferString" -ErrorAction SilentlyContinue)) {
            return # Buffer functions not available
        }
        
        # AI: FIX - Get render position from parent panel if available
        $renderX = 0
        $renderY = 0
        $maxWidth = 120  # Default max width
        
        if ($this.Parent -and $this.Parent -is [Panel]) {
            $parentPanel = [Panel]$this.Parent
            $contentArea = $parentPanel.GetContentArea()
            $renderX = $contentArea.X
            $renderY = $contentArea.Y
            $maxWidth = $contentArea.Width
        }
        
        $currentY = $renderY
        
        # Header
        if ($this.ShowHeader -and $this.Columns.Count -gt 0) {
            $headerLine = ""
            foreach ($col in $this.Columns) {
                $headerText = $col.Header.PadRight($col.Width).Substring(0, [Math]::Min($col.Header.Length, $col.Width))
                $headerLine += $headerText + " "
            }
            # AI: FIX - Trim header to max width
            if ($headerLine.TrimEnd().Length -gt $maxWidth) {
                $headerLine = $headerLine.Substring(0, $maxWidth)
            }
            Write-BufferString -X $renderX -Y $currentY -Text $headerLine.TrimEnd() -ForegroundColor ([ConsoleColor]::Cyan) -BackgroundColor ([ConsoleColor]::Black)
            $currentY++
            Write-BufferString -X $renderX -Y $currentY -Text ("-" * [Math]::Min($headerLine.TrimEnd().Length, $maxWidth)) -ForegroundColor ([ConsoleColor]::DarkGray) -BackgroundColor ([ConsoleColor]::Black)
            $currentY++
        }
        
        # AI: FIX - Safe data array handling
        $dataToRender = @()
        if ($null -ne $this.Data) {
            $dataToRender = if ($this.Data -is [array]) { $this.Data } else { @($this.Data) }
        }
        
        # Data rows
        for ($i = 0; $i -lt $dataToRender.Count; $i++) {
            $row = $dataToRender[$i]
            if ($null -eq $row) { continue }
            
            $rowLine = ""
            $isSelected = ($i -eq $this.SelectedIndex)
            
            foreach ($col in $this.Columns) {
                $cellValue = ""
                if ($row -is [hashtable] -and $row.ContainsKey($col.Key)) {
                    $cellValue = $row[$col.Key]?.ToString() ?? ""
                } elseif ($row.PSObject.Properties[$col.Key]) {
                    $cellValue = $row.($col.Key)?.ToString() ?? ""
                }
                
                $cellText = $cellValue.PadRight($col.Width).Substring(0, [Math]::Min($cellValue.Length, $col.Width))
                $rowLine += $cellText + " "
            }
            
            $finalLine = $rowLine.TrimEnd()
            if ($isSelected) {
                $finalLine = "> $finalLine"
            } else {
                $finalLine = "  $finalLine"
            }
            
            $fg = if ($isSelected) { [ConsoleColor]::Black } else { [ConsoleColor]::White }
            $bg = if ($isSelected) { [ConsoleColor]::White } else { [ConsoleColor]::Black }
            # AI: FIX - Ensure line doesn't exceed parent bounds
            if ($finalLine.Length -gt $maxWidth) {
                $finalLine = $finalLine.Substring(0, $maxWidth)
            }
            Write-BufferString -X $renderX -Y $currentY -Text $finalLine -ForegroundColor $fg -BackgroundColor $bg
            $currentY++
        }
        
        if ($dataToRender.Count -eq 0) {
            Write-BufferString -X $renderX -Y $currentY -Text "  No data to display" -ForegroundColor ([ConsoleColor]::DarkGray) -BackgroundColor ([ConsoleColor]::Black)
        }
    }
}

#endregion

#region Advanced Data Table Class

class DataTableComponent : UIElement {
    # ... (class content is unchanged) ...
    [hashtable[]] $Data = @()
    [hashtable[]] $Columns = @()
    [int] $X = 0
    [int] $Y = 0
    [int] $Width = 80
    [int] $Height = 20
    [string] $Title = "Data Table"
    [bool] $ShowBorder = $true
    [bool] $IsFocusable = $true
    [int] $SelectedRow = 0
    [int] $ScrollOffset = 0
    [string] $SortColumn
    [string] $SortDirection = "Ascending"
    [string] $FilterText = ""
    [string] $FilterColumn
    [int] $PageSize = 0  # 0 = auto-calculate
    [int] $CurrentPage = 0
    [bool] $ShowHeader = $true
    [bool] $ShowFooter = $true
    [bool] $ShowRowNumbers = $false
    [bool] $AllowSort = $true
    [bool] $AllowFilter = $true
    [bool] $AllowSelection = $true
    [bool] $MultiSelect = $false
    [int[]] $SelectedRows = @()
    [hashtable[]] $FilteredData = @()
    [hashtable[]] $ProcessedData = @()
    [bool] $FilterMode = $false
    hidden [int] $_lastRenderedWidth = 0
    hidden [int] $_lastRenderedHeight = 0
    
    # Event handlers
    [scriptblock] $OnRowSelect
    [scriptblock] $OnSelectionChange
    
    DataTableComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
    }
    
    DataTableComponent([string]$name, [hashtable[]]$data, [hashtable[]]$columns) : base($name) {
        $this.IsFocusable = $true
        $this.Data = $data
        $this.Columns = $columns
        $this.ProcessData()
    }
    
    [void] ProcessData() {
        Invoke-WithErrorHandling -Component "$($this.Name).ProcessData" -Context "Processing table data" -ScriptBlock {
            # Filter data
            if ([string]::IsNullOrWhiteSpace($this.FilterText)) {
                $this.FilteredData = $this.Data
            } else {
                if ($this.FilterColumn) {
                    # Filter specific column
                    $this.FilteredData = @($this.Data | Where-Object {
                        $value = $_."$($this.FilterColumn)"
                        $value -and $value.ToString() -like "*$($this.FilterText)*"
                    })
                } else {
                    # Filter all columns
                    $this.FilteredData = @($this.Data | Where-Object {
                        $row = $_
                        $matched = $false
                        foreach ($col in $this.Columns) {
                            if ($col.Filterable -ne $false) {
                                $value = $row."$($col.Name)"
                                if ($value -and $value.ToString() -like "*$($this.FilterText)*") {
                                    $matched = $true
                                    break
                                }
                            }
                        }
                        $matched
                    })
                }
            }
            
            # Sort data
            if ($this.SortColumn -and $this.AllowSort) {
                $this.ProcessedData = $this.FilteredData | Sort-Object -Property $this.SortColumn -Descending:($this.SortDirection -eq "Descending")
            } else {
                $this.ProcessedData = $this.FilteredData
            }
            
            # Reset selection if needed
            if ($this.SelectedRow -ge $this.ProcessedData.Count) {
                $this.SelectedRow = [Math]::Max(0, $this.ProcessedData.Count - 1)
            }
            
            # Calculate page size if auto
            if ($this.PageSize -eq 0) {
                $headerLines = $this.ShowHeader ? 3 : 0
                $footerLines = $this.ShowFooter ? 2 : 0
                $filterLines = $this.AllowFilter ? 2 : 0
                $borderAdjust = $this.ShowBorder ? 2 : 0
                $calculatedPageSize = $this.Height - $headerLines - $footerLines - $filterLines - $borderAdjust
                $this.PageSize = [Math]::Max(1, $calculatedPageSize)
            }
            
            # Adjust current page
            $totalPages = [Math]::Ceiling($this.ProcessedData.Count / [Math]::Max(1, $this.PageSize))
            if ($this.CurrentPage -ge $totalPages) {
                $this.CurrentPage = [Math]::Max(0, $totalPages - 1)
            }
        }
    }
    
    [hashtable] GetContentBounds() {
        $borderOffset = $this.ShowBorder ? 1 : 0
        return @{
            X = $this.X + $borderOffset
            Y = $this.Y + $borderOffset
            Width = $this.Width - (2 * $borderOffset)
            Height = $this.Height - (2 * $borderOffset)
        }
    }
    
    hidden [void] _RenderContent() {
        # AI: TEMPORARY - Complex table rendering needs to be rewritten for buffer-based system
        # This is a placeholder until proper buffer rendering is implemented
        if (-not (Get-Command "Write-BufferString" -ErrorAction SilentlyContinue)) {
            return # Buffer functions not available
        }
        
        # Simple placeholder rendering
        Write-BufferString -X ($this.X + 1) -Y ($this.Y + 1) -Text "[DataTable: $($this.Title)]" -ForegroundColor ([ConsoleColor]::Yellow) -BackgroundColor ([ConsoleColor]::Black)
        
        return # TODO: Implement full buffer-based table rendering
        
        # ORIGINAL COMPLEX RENDERING CODE (commented out for now):
        $renderedContent = [StringBuilder]::new()
        
        # Force ProcessData if dimensions changed
        if ($this._lastRenderedWidth -ne $this.Width -or $this._lastRenderedHeight -ne $this.Height) {
            $this.ProcessData()
            $this._lastRenderedWidth = $this.Width
            $this._lastRenderedHeight = $this.Height
        }
        
        # Calculate content area based on border settings
        $contentX = $this.X
        $contentY = $this.Y
        $contentWidth = $this.Width
        $contentHeight = $this.Height

        if ($this.ShowBorder) {
            $borderColor = ($this.IsFocusable -and $this.IsFocused) ? (Get-ThemeColor "Accent") : (Get-ThemeColor "Border")
            
            [void]$renderedContent.Append($this.MoveCursor($this.X, $this.Y))
            [void]$renderedContent.Append($this.SetColor($borderColor))
            [void]$renderedContent.Append($this.RenderBorder($this.Title))
            
            # Adjust content area for border
            $contentX = $this.X + 1
            $contentY = $this.Y + 1
            $contentWidth = $this.Width - 2
            $contentHeight = $this.Height - 2
        }
        
        $currentY = $contentY
        
        # Filter bar
        if ($this.AllowFilter) {
            [void]$renderedContent.Append($this.MoveCursor($contentX + 1, $currentY))
            [void]$renderedContent.Append($this.SetColor([ConsoleColor]::White))
            [void]$renderedContent.Append("Filter: ")
            
            $filterDisplayText = $this.FilterText ? $this.FilterText : "Type to filter..."
            $filterColor = $this.FilterText ? [ConsoleColor]::Yellow : [ConsoleColor]::DarkGray
            [void]$renderedContent.Append($this.SetColor($filterColor))
            [void]$renderedContent.Append($filterDisplayText)
            
            $currentY += 2
        }
        
        # Calculate column widths
        $totalDefinedWidth = ($this.Columns | Where-Object { $_.Width } | Measure-Object -Property Width -Sum).Sum ?? 0
        $flexColumns = @($this.Columns | Where-Object { -not $_.Width })
        $columnSeparators = $this.Columns.Count -gt 1 ? $this.Columns.Count - 1 : 0
        $rowNumberWidth = $this.ShowRowNumbers ? 5 : 0
        $remainingWidth = $contentWidth - $totalDefinedWidth - $rowNumberWidth - $columnSeparators
        
        $flexWidth = ($flexColumns.Count -gt 0) ? [Math]::Floor($remainingWidth / $flexColumns.Count) : 0
        
        # Assign calculated widths
        foreach ($col in $this.Columns) {
            $col.CalculatedWidth = $col.Width ?? [Math]::Max(5, $flexWidth)
        }
        
        # Header
        if ($this.ShowHeader) {
            $headerX = $contentX
            
            if ($this.ShowRowNumbers) {
                [void]$renderedContent.Append($this.MoveCursor($headerX, $currentY))
                [void]$renderedContent.Append($this.SetColor([ConsoleColor]::Cyan))
                [void]$renderedContent.Append("#".PadRight(4))
                $headerX += 5
            }
            
            foreach ($col in $this.Columns) {
                $headerText = $col.Header ?? $col.Name
                $columnWidth = $col.CalculatedWidth
                
                if ($this.AllowSort -and $col.Sortable -ne $false -and $col.Name -eq $this.SortColumn) {
                    $sortIndicator = ($this.SortDirection -eq "Ascending") ? "▲" : "▼"
                    $headerText = "$headerText $sortIndicator"
                }
                
                if ($headerText.Length -gt $columnWidth) {
                    $maxLength = [Math]::Max(0, $columnWidth - 3)
                    $headerText = $headerText.Substring(0, $maxLength) + "..."
                }
                
                $alignedText = switch ($col.Align) {
                    "Right" { $headerText.PadLeft($columnWidth) }
                    "Center" {
                        $padding = $columnWidth - $headerText.Length
                        $leftPad = [Math]::Floor($padding / 2)
                        $rightPad = $padding - $leftPad
                        " " * $leftPad + $headerText + " " * $rightPad
                    }
                    default { $headerText.PadRight($columnWidth) }
                }
                
                [void]$renderedContent.Append($this.MoveCursor($headerX, $currentY))
                [void]$renderedContent.Append($this.SetColor([ConsoleColor]::Cyan))
                [void]$renderedContent.Append($alignedText)
                
                $headerX += $columnWidth + 1
            }
            
            $currentY++
            
            [void]$renderedContent.Append($this.MoveCursor($contentX, $currentY))
            [void]$renderedContent.Append($this.SetColor([ConsoleColor]::DarkGray))
            [void]$renderedContent.Append("─" * $contentWidth)
            $currentY++
        }
        
        # Data rows
        $dataToRender = ($this.ProcessedData.Count -eq 0 -and $this.Data.Count -gt 0) ? $this.Data : $this.ProcessedData
        
        $startIdx = $this.CurrentPage * $this.PageSize
        $endIdx = [Math]::Min($startIdx + $this.PageSize - 1, $dataToRender.Count - 1)
        
        for ($i = $startIdx; $i -le $endIdx; $i++) {
            $row = $dataToRender[$i]
            $rowX = $contentX
            
            $isSelected = $this.MultiSelect ? ($this.SelectedRows -contains $i) : ($i -eq $this.SelectedRow)
            
            $rowBg = $isSelected ? [ConsoleColor]::Cyan : [ConsoleColor]::Black
            $rowFg = $isSelected ? [ConsoleColor]::Black : [ConsoleColor]::White
            
            if ($isSelected) {
                [void]$renderedContent.Append($this.MoveCursor($rowX, $currentY))
                [void]$renderedContent.Append($this.SetBackgroundColor($rowBg))
                [void]$renderedContent.Append(" " * $contentWidth)
            }
            
            if ($this.ShowRowNumbers) {
                [void]$renderedContent.Append($this.MoveCursor($rowX, $currentY))
                [void]$renderedContent.Append($this.SetColor([ConsoleColor]::DarkGray))
                [void]$renderedContent.Append($this.SetBackgroundColor($rowBg))
                [void]$renderedContent.Append(($i + 1).ToString().PadRight(4))
                $rowX += 5
            }
            
            foreach ($col in $this.Columns) {
                $value = $row."$($col.Name)"
                $columnWidth = $col.CalculatedWidth
                
                $displayValue = if ($col.Format -and $value) { & $col.Format $value } else { "$($value)" }
                
                if ($displayValue.Length -gt $columnWidth) {
                    $maxLength = [Math]::Max(0, $columnWidth - 3)
                    $displayValue = ($maxLength -le 0) ? "..." : ($displayValue.Substring(0, $maxLength) + "...")
                }
                
                $alignedValue = switch ($col.Align) {
                    "Right" { $displayValue.PadLeft($columnWidth) }
                    "Center" {
                        $padding = $columnWidth - $displayValue.Length
                        $leftPad = [Math]::Floor($padding / 2)
                        $rightPad = $padding - $leftPad
                        " " * $leftPad + $displayValue + " " * $rightPad
                    }
                    default { $displayValue.PadRight($columnWidth) }
                }
                
                $cellFg = if ($col.Color -and -not $isSelected) {
                    Get-ThemeColor (& $col.Color $value $row)
                } else {
                    $rowFg
                }
                
                [void]$renderedContent.Append($this.MoveCursor($rowX, $currentY))
                [void]$renderedContent.Append($this.SetColor($cellFg))
                [void]$renderedContent.Append($this.SetBackgroundColor($rowBg))
                [void]$renderedContent.Append($alignedValue)
                
                $rowX += $columnWidth + 1
            }
            
            $currentY++
        }
        
        # Empty state
        if ($dataToRender.Count -eq 0) {
            $emptyMessage = $this.FilterText ? "No results match the filter" : "No data to display"
            $msgX = $contentX + [Math]::Floor(($contentWidth - $emptyMessage.Length) / 2)
            $msgY = $contentY + [Math]::Floor($contentHeight / 2)
            [void]$renderedContent.Append($this.MoveCursor($msgX, $msgY))
            [void]$renderedContent.Append($this.SetColor([ConsoleColor]::DarkGray))
            [void]$renderedContent.Append($emptyMessage)
        }
        
        # Footer
        if ($this.ShowFooter) {
            $footerY = $contentY + $contentHeight - 1
            
            $statusText = "$($dataToRender.Count) rows"
            if ($this.FilterText) { $statusText += " (filtered from $($this.Data.Count))" }
            if ($this.MultiSelect) { $statusText += " | $($this.SelectedRows.Count) selected" }
            
            [void]$renderedContent.Append($this.MoveCursor($contentX + 1, $footerY))
            [void]$renderedContent.Append($this.SetColor([ConsoleColor]::DarkGray))
            [void]$renderedContent.Append($statusText)
            
            if ($dataToRender.Count -gt $this.PageSize) {
                $totalPages = [Math]::Ceiling($dataToRender.Count / [Math]::Max(1, $this.PageSize))
                $pageText = "Page $($this.CurrentPage + 1)/$totalPages"
                [void]$renderedContent.Append($this.MoveCursor($contentX + $contentWidth - $pageText.Length - 1, $footerY))
                [void]$renderedContent.Append($this.SetColor([ConsoleColor]::Blue))
                [void]$renderedContent.Append($pageText)
            }
        }
        
        # [void]$renderedContent.Append($this.ResetColor())
        # return $renderedContent.ToString()
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        # Filter mode
        if ($key.Modifiers -band [ConsoleModifiers]::Control) {
            switch ($key.Key) {
                ([ConsoleKey]::F) {
                    $this.FilterMode = -not $this.FilterMode
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::S) {
                    if ($this.AllowSort) {
                        $sortableCols = @($this.Columns | Where-Object { $_.Sortable -ne $false })
                        if ($sortableCols.Count -gt 0) {
                            $currentIdx = [array]::IndexOf($sortableCols.Name, $this.SortColumn)
                            $nextIdx = ($currentIdx + 1) % $sortableCols.Count
                            $this.SortColumn = $sortableCols[$nextIdx].Name
                            $this.ProcessData()
                            Request-TuiRefresh
                        }
                    }
                    return $true
                }
            }
        }
        
        # Filter text input
        if ($this.FilterMode) {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this.FilterMode = $false
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    $this.FilterMode = $false
                    $this.ProcessData()
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.FilterText.Length -gt 0) {
                        $this.FilterText = $this.FilterText.Substring(0, $this.FilterText.Length - 1)
                        $this.ProcessData()
                        Request-TuiRefresh
                    }
                    return $true
                }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
                        $this.FilterText += $key.KeyChar
                        $this.ProcessData()
                        Request-TuiRefresh
                        return $true
                    }
                }
            }
            return $false
        }
        
        # Normal navigation
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedRow -gt 0) {
                    $this.SelectedRow--
                    if ($this.SelectedRow -lt ($this.CurrentPage * $this.PageSize)) {
                        $this.CurrentPage--
                    }
                    Request-TuiRefresh
                }
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedRow -lt ($this.ProcessedData.Count - 1)) {
                    $this.SelectedRow++
                    if ($this.SelectedRow -ge (($this.CurrentPage + 1) * $this.PageSize)) {
                        $this.CurrentPage++
                    }
                    Request-TuiRefresh
                }
                return $true
            }
            ([ConsoleKey]::Enter) {
                if ($this.OnRowSelect -and $this.ProcessedData.Count -gt 0) {
                    $selectedData = $this.MultiSelect ? @($this.SelectedRows | ForEach-Object { $this.ProcessedData[$_] }) : $this.ProcessedData[$this.SelectedRow]
                    & $this.OnRowSelect $selectedData $this.SelectedRow
                }
                return $true
            }
        }
        
        return $false
    }
    
    # AI: Helper methods removed - using buffer-based rendering instead of ANSI
    
    # Public methods
    [void] RefreshData() {
        $this.ProcessData()
        Request-TuiRefresh
    }
    
    [void] SetData([hashtable[]]$data) {
        $this.Data = $data
        $this.ProcessData()
        Request-TuiRefresh
    }
    
    [void] SetColumns([hashtable[]]$columns) {
        $this.Columns = $columns
        $this.ProcessData()
        Request-TuiRefresh
    }
}
#endregion

#region Factory Functions for Backward Compatibility

function New-TuiDataTable {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "DataTable_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $data = $Props.Data ?? @()
    $columns = $Props.Columns ?? @()
    
    $table = [DataTableComponent]::new($name, $data, $columns)
    
    $table.X = $Props.X ?? $table.X
    $table.Y = $Props.Y ?? $table.Y
    $table.Width = $Props.Width ?? $table.Width
    $table.Height = $Props.Height ?? $table.Height
    $table.Title = $Props.Title ?? $table.Title
    $table.ShowBorder = $Props.ShowBorder ?? $table.ShowBorder
    $table.ShowHeader = $Props.ShowHeader ?? $table.ShowHeader
    $table.ShowFooter = $Props.ShowFooter ?? $table.ShowFooter
    $table.ShowRowNumbers = $Props.ShowRowNumbers ?? $table.ShowRowNumbers
    $table.AllowSort = $Props.AllowSort ?? $table.AllowSort
    $table.AllowFilter = $Props.AllowFilter ?? $table.AllowFilter
    $table.AllowSelection = $Props.AllowSelection ?? $table.AllowSelection
    $table.MultiSelect = $Props.MultiSelect ?? $table.MultiSelect
    $table.Visible = $Props.Visible ?? $table.Visible
    $table.OnRowSelect = $Props.OnRowSelect ?? $table.OnRowSelect
    $table.OnSelectionChange = $Props.OnSelectionChange ?? $table.OnSelectionChange
    
    return $table
}
#endregion

Export-ModuleMember -Function 'New-TuiDataTable'
