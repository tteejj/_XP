# Advanced Data Components Module for PMC Terminal v5

# Phase 1 Migration Complete - Enhanced data display with proper UIElement inheritance

















#region Table Classes



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



# AI: REFACTORED - Table now properly inherits from UIElement

class Table : UIElement {

[System.Collections.Generic.List[TableColumn]]$Columns

[object[]]$Data = @()

[int]$SelectedIndex = 0

[bool]$ShowBorder = $true

[bool]$ShowHeader = $true

[bool]$IsFocused = $false



Table([string]$name) : base() {

$this.Name = $name

$this.Columns = [System.Collections.Generic.List[TableColumn]]::new()

$this.Data = @()

$this.SelectedIndex = 0

$this.IsFocusable = $true

$this.Width = 60

$this.Height = 15

}



[void] SetColumns([TableColumn[]]$columns) {

$this.Columns.Clear()

foreach ($col in $columns) {

$this.Columns.Add($col)

}

$this.RequestRedraw()

}



[void] SetData([object[]]$data) {

$this.Data = if ($null -eq $data) { @() } else { @($data) }

$dataCount = if ($this.Data -is [array]) { $this.Data.Count } else { 1 }

if ($this.SelectedIndex -ge $dataCount) {

$this.SelectedIndex = [Math]::Max(0, $dataCount - 1)

}

$this.RequestRedraw()

}



[void] SelectNext() {

$dataCount = if ($null -eq $this.Data) { 0 } elseif ($this.Data -is [array]) { $this.Data.Count } else { 1 }

if ($this.SelectedIndex -lt ($dataCount - 1)) {

$this.SelectedIndex++

$this.RequestRedraw()

}

}



[void] SelectPrevious() {

if ($this.SelectedIndex -gt 0) {

$this.SelectedIndex--

$this.RequestRedraw()

}

}



[object] GetSelectedItem() {

if ($null -eq $this.Data) { return $null }



$dataCount = if ($this.Data -is [array]) { $this.Data.Count } else { 1 }



if ($dataCount -gt 0 -and $this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $dataCount) {

return if ($this.Data -is [array]) { $this.Data[$this.SelectedIndex] } else { $this.Data }

}

return $null

}



# AI: REFACTORED - Now uses UIElement buffer system

[void] OnRender() {

if (-not $this.Visible -or $null -eq $this._private_buffer) { return }



try {

# Clear buffer

$this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))



# Draw border if enabled

if ($this.ShowBorder) {

Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `

-BorderStyle "Single" -BorderColor ([ConsoleColor]::Gray) -BackgroundColor ([ConsoleColor]::Black)

}



$currentY = if ($this.ShowBorder) { 1 } else { 0 }

$contentWidth = if ($this.ShowBorder) { $this.Width - 2 } else { $this.Width }

$renderX = if ($this.ShowBorder) { 1 } else { 0 }



# Header

if ($this.ShowHeader -and $this.Columns.Count -gt 0) {

$headerLine = ""

foreach ($col in $this.Columns) {

$headerText = $col.Header.PadRight($col.Width).Substring(0, [Math]::Min($col.Header.Length, $col.Width))

$headerLine += $headerText + " "

}



if ($headerLine.TrimEnd().Length -gt $contentWidth) {

$headerLine = $headerLine.Substring(0, $contentWidth)

}



Write-TuiText -Buffer $this._private_buffer -X $renderX -Y $currentY -Text $headerLine.TrimEnd() `

-ForegroundColor ([ConsoleColor]::Cyan) -BackgroundColor ([ConsoleColor]::Black)

$currentY++



Write-TuiText -Buffer $this._private_buffer -X $renderX -Y $currentY `

-Text ("-" * [Math]::Min($headerLine.TrimEnd().Length, $contentWidth)) `

-ForegroundColor ([ConsoleColor]::DarkGray) -BackgroundColor ([ConsoleColor]::Black)

$currentY++

}



# Data rows

$dataToRender = @()

if ($null -ne $this.Data) {

$dataToRender = if ($this.Data -is [array]) { $this.Data } else { @($this.Data) }

}



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

$propValue = $row.($col.Key)

if ($col.Key -eq 'DueDate' -and $propValue -is [DateTime]) {

$cellValue = $propValue.ToString('yyyy-MM-dd')

} else {

$cellValue = if ($null -ne $propValue) { $propValue.ToString() } else { "" }

}

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



if ($finalLine.Length -gt $contentWidth) {

$finalLine = $finalLine.Substring(0, $contentWidth)

}



Write-TuiText -Buffer $this._private_buffer -X $renderX -Y $currentY -Text $finalLine `

-ForegroundColor $fg -BackgroundColor $bg

$currentY++



# Don't exceed available space

if ($currentY -ge ($this.Height - 1)) { break }

}



if ($dataToRender.Count -eq 0) {

Write-TuiText -Buffer $this._private_buffer -X $renderX -Y $currentY -Text "  No data to display" `

-ForegroundColor ([ConsoleColor]::DarkGray) -BackgroundColor ([ConsoleColor]::Black)

}



} catch {

Write-Log -Level Error -Message "Table render error for '$($this.Name)': $_"

}

}



# AI: REFACTORED - Updated input handling

[bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {

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

([ConsoleKey]::Enter) {

$selectedItem = $this.GetSelectedItem()

if ($null -ne $selectedItem) {

# Trigger selection event or action

Write-Log -Level Debug -Message "Table item selected: $($selectedItem)"

}

return $true

}

}

} catch {

Write-Log -Level Error -Message "Table input error for '$($this.Name)': $_"

}



return $false

}



[void] OnFocus() {

$this.IsFocused = $true

$this.RequestRedraw()

}



[void] OnBlur() {

$this.IsFocused = $false

$this.RequestRedraw()

}

}



# AI: DELETED - Obsolete DataTableComponent class was here and has been removed.



#endregion



#region Factory Functions



function New-TuiTable {

# AI: REFACTORED - Creates a proper Table instance

param([hashtable]$Props = @{})



$name = $Props.Name ?? "Table_$([Guid]::NewGuid().ToString('N').Substring(0,8))"

$table = [Table]::new($name)



if ($Props.Columns) {

$table.SetColumns($Props.Columns)

}

if ($Props.Data) {

$table.SetData($Props.Data)

}



$table.X = $Props.X ?? $table.X

$table.Y = $Props.Y ?? $table.Y

$table.Width = $Props.Width ?? $table.Width

$table.Height = $Props.Height ?? $table.Height

$table.ShowBorder = $Props.ShowBorder ?? $table.ShowBorder

$table.ShowHeader = $Props.ShowHeader ?? $table.ShowHeader

$table.Visible = $Props.Visible ?? $table.Visible



return $table

}



#endregion
