# Panel Classes v5.1 - NCurses Compositor Foundation
# Provides Panel base class for layout management

# Panel Class - A specialized UIElement that acts as a container.
# It can draw a border and title, and it intelligently manages child elements,
# positioning them correctly within its bordered "content area".
class Panel : UIElement {
[string] $Title = ""
[string] $BorderStyle = "Single"
[ConsoleColor] $BorderColor = [ConsoleColor]::Gray
[ConsoleColor] $BackgroundColor = [ConsoleColor]::Black
[ConsoleColor] $TitleColor = [ConsoleColor]::White
[bool] $HasBorder = $true
[bool] $CanFocus = $false
[int] $ContentX = 0
[int] $ContentY = 0
[int] $ContentWidth = 0
[int] $ContentHeight = 0
[string] $LayoutType = "Manual"  # Manual, Vertical, Horizontal, Grid

# Constructor
Panel() : base() {
$this.Name = "Panel"
$this.IsFocusable = $false
$this.UpdateContentBounds()
}

# Constructor with position and size
Panel([int]$x, [int]$y, [int]$width, [int]$height) : base($x, $y, $width, $height) {
$this.Name = "Panel"
$this.IsFocusable = $false
$this.UpdateContentBounds()
}

# Constructor with title
Panel([int]$x, [int]$y, [int]$width, [int]$height, [string]$title) : base($x, $y, $width, $height) {
$this.Name = "Panel"
$this.Title = $title
$this.IsFocusable = $false
$this.UpdateContentBounds()
}

# Update content bounds based on border settings
[void] UpdateContentBounds() {
if ($this.HasBorder) {
$this.ContentX = 1
$this.ContentY = 1
$this.ContentWidth = [Math]::Max(0, $this.Width - 2)
$this.ContentHeight = [Math]::Max(0, $this.Height - 2)
} else {
$this.ContentX = 0
$this.ContentY = 0
$this.ContentWidth = $this.Width
$this.ContentHeight = $this.Height
}
}

# Override resize to update content bounds
[void] OnResize([int]$newWidth, [int]$newHeight) {
$this.UpdateContentBounds()
$this.PerformLayout()
}

# Perform automatic layout based on LayoutType
[void] PerformLayout() {
if ($this.Children.Count -eq 0) { return }

switch ($this.LayoutType) {
"Vertical" { $this.LayoutVertical() }
"Horizontal" { $this.LayoutHorizontal() }
"Grid" { $this.LayoutGrid() }
# "Manual" - no automatic layout
}
}

# Vertical layout - stack children top to bottom
[void] LayoutVertical() {
$currentY = $this.ContentY
$childWidth = $this.ContentWidth
$availableHeight = $this.ContentHeight
$childHeight = [Math]::Max(1, [Math]::Floor($availableHeight / $this.Children.Count))

for ($i = 0; $i -lt $this.Children.Count; $i++) {
$child = $this.Children[$i]
$child.X = $this.ContentX
$child.Y = $currentY

if ($i -eq ($this.Children.Count - 1)) {
$remainingHeight = $this.ContentY + $this.ContentHeight - $currentY
$child.Resize($childWidth, $remainingHeight)
} else {
$child.Resize($childWidth, $childHeight)
}

$currentY += $childHeight
}
}

# Horizontal layout - arrange children side by side
[void] LayoutHorizontal() {
$currentX = $this.ContentX
$childHeight = $this.ContentHeight
$availableWidth = $this.ContentWidth
$childWidth = [Math]::Max(1, [Math]::Floor($availableWidth / $this.Children.Count))

for ($i = 0; $i -lt $this.Children.Count; $i++) {
$child = $this.Children[$i]
$child.X = $currentX
$child.Y = $this.ContentY

if ($i -eq ($this.Children.Count - 1)) {
$remainingWidth = $this.ContentX + $this.ContentWidth - $currentX
$child.Resize($remainingWidth, $childHeight)
} else {
$child.Resize($childWidth, $childHeight)
}

$currentX += $childWidth
}
}

# Grid layout - arrange children in a grid
[void] LayoutGrid() {
if ($this.Children.Count -eq 0) { return }

$childCount = $this.Children.Count
$cols = [Math]::Ceiling([Math]::Sqrt($childCount))
$rows = [Math]::Ceiling($childCount / $cols)

$cellWidth = [Math]::Max(1, [Math]::Floor($this.ContentWidth / $cols))
$cellHeight = [Math]::Max(1, [Math]::Floor($this.ContentHeight / $rows))

for ($i = 0; $i -lt $this.Children.Count; $i++) {
$child = $this.Children[$i]
$row = [Math]::Floor($i / $cols)
$col = $i % $cols

$x = $this.ContentX + ($col * $cellWidth)
$y = $this.ContentY + ($row * $cellHeight)

$width = if ($col -eq ($cols - 1)) { $this.ContentX + $this.ContentWidth - $x } else { $cellWidth }
$height = if ($row -eq ($rows - 1)) { $this.ContentY + $this.ContentHeight - $y } else { $cellHeight }

$child.Move($x, $y)
$child.Resize($width, $height)
}
}

[void] SetBorderStyle([string]$style, [ConsoleColor]$color) {
$this.BorderStyle = $style
$this.BorderColor = $color
$this.RequestRedraw()
}

[void] SetBorder([bool]$hasBorder) {
$this.HasBorder = $hasBorder
$this.UpdateContentBounds()
$this.PerformLayout()
$this.RequestRedraw()
}

[void] SetTitle([string]$title) {
$this.Title = $title
$this.RequestRedraw()
}

[bool] ContainsContentPoint([int]$x, [int]$y) {
return ($x -ge $this.ContentX -and $x -lt ($this.ContentX + $this.ContentWidth) -and
$y -ge $this.ContentY -and $y -lt ($this.ContentY + $this.ContentHeight))
}

[hashtable] GetContentBounds() {
return @{ X = $this.ContentX; Y = $this.ContentY; Width = $this.ContentWidth; Height = $this.ContentHeight }
}

[hashtable] GetContentArea() {
return $this.GetContentBounds()
}

[void] WriteToBuffer([int]$x, [int]$y, [string]$text, [ConsoleColor]$fg, [ConsoleColor]$bg) {
if ($null -eq $this.{_private_buffer}) { return }
Write-TuiText -Buffer $this.{_private_buffer} -X $x -Y $y -Text $text -ForegroundColor $fg -BackgroundColor $bg
}

[void] DrawBoxToBuffer([int]$x, [int]$y, [int]$width, [int]$height, [ConsoleColor]$borderColor, [ConsoleColor]$bgColor) {
if ($null -eq $this.{_private_buffer}) { return }
Write-TuiBox -Buffer $this.{_private_buffer} -X $x -Y $y -Width $width -Height $height `
-BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
}

[void] ClearContent() {
if ($null -eq $this.{_private_buffer}) { return }
$clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor)
for ($y = $this.ContentY; $y -lt ($this.ContentY + $this.ContentHeight); $y++) {
for ($x = $this.ContentX; $x -lt ($this.ContentX + $this.ContentWidth); $x++) {
$this.{_private_buffer}.SetCell($x, $y, $clearCell)
}
}
}

[void] OnRender() {
if ($null -eq $this.{_private_buffer}) { return }
$bgCell = [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor)
$this.{_private_buffer}.Clear($bgCell)
if ($this.HasBorder) {
Write-TuiBox -Buffer $this.{_private_buffer} -X 0 -Y 0 -Width $this.Width -Height $this.Height `
-BorderStyle $this.BorderStyle -BorderColor $this.BorderColor -BackgroundColor $this.BackgroundColor -Title $this.Title
}
}

hidden [void] _RenderContent() {
$this.OnRender()
foreach ($child in $this.Children) {
if ($child.Visible) {
$child.Render()
if ($null -ne $child.{_private_buffer}) {
$this.{_private_buffer}.BlendBuffer($child.{_private_buffer}, ($child.X + $this.ContentX), ($child.Y + $this.ContentY))
}
}
}
}

[void] OnFocus() {
if ($this.CanFocus) {
$this.BorderColor = [ConsoleColor]::Cyan
$this.RequestRedraw()
}
}

[void] OnBlur() {
if ($this.CanFocus) {
$this.BorderColor = [ConsoleColor]::Gray
$this.RequestRedraw()
}
}

[UIElement] GetFirstFocusableChild() {
foreach ($child in $this.Children) {
if ($child.IsFocusable -and $child.Visible -and $child.Enabled) {
return $child
}
if ($child -is [Panel]) {
$nestedChild = $child.GetFirstFocusableChild()
if ($null -ne $nestedChild) {
return $nestedChild
}
}
}
return $null
}

[System.Collections.Generic.List[UIElement]] GetFocusableChildren() {
$focusable = [System.Collections.Generic.List[UIElement]]::new()
foreach ($child in $this.Children) {
if ($child.IsFocusable -and $child.Visible -and $child.Enabled) {
$focusable.Add($child)
}
if ($child -is [Panel]) {
$nestedFocusable = $child.GetFocusableChildren()
$focusable.AddRange($nestedFocusable)
}
}
return $focusable
}

[bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
if ($this.CanFocus -and $this.IsFocused) {
switch ($keyInfo.Key) {
([ConsoleKey]::Tab) {
$firstChild = $this.GetFirstFocusableChild()
if ($null -ne $firstChild) {
$firstChild.IsFocused = $true
$this.IsFocused = $false
return $true
}
}
([ConsoleKey]::Enter) {
$firstChild = $this.GetFirstFocusableChild()
if ($null -ne $firstChild) {
$firstChild.IsFocused = $true
$this.IsFocused = $false
return $true
}
}
}
}
foreach ($child in $this.Children) {
if ($child.Visible -and $child.Enabled -and $child.HandleInput($keyInfo)) {
return $true
}
}
return $false
}

[string] ToString() {
return "Panel($($this.Name), $($this.X),$($this.Y), $($this.Width)x$($this.Height), Children=$($this.Children.Count))"
}
}

#region Specialized Panel Types

class ScrollablePanel : Panel {
[int] $ScrollX = 0
[int] $ScrollY = 0
[int] $VirtualWidth = 0
[int] $VirtualHeight = 0
[bool] $ShowScrollbars = $true
[TuiBuffer] $_virtual_buffer = $null

ScrollablePanel() : base() {
$this.Name = "ScrollablePanel"
$this.IsFocusable = $true
$this.CanFocus = $true
}

ScrollablePanel([int]$x, [int]$y, [int]$width, [int]$height) : base($x, $y, $width, $height) {
$this.Name = "ScrollablePanel"
$this.IsFocusable = $true
$this.CanFocus = $true
}

[void] SetVirtualSize([int]$width, [int]$height) {
$this.VirtualWidth = $width
$this.VirtualHeight = $height
if ($width -gt 0 -and $height -gt 0) {
$this.{_virtual_buffer} = [TuiBuffer]::new($width, $height, "$($this.Name).Virtual")
}
$this.RequestRedraw()
}

[void] ScrollTo([int]$x, [int]$y) {
$maxScrollX = [Math]::Max(0, $this.VirtualWidth - $this.ContentWidth)
$maxScrollY = [Math]::Max(0, $this.VirtualHeight - $this.ContentHeight)
$this.ScrollX = [Math]::Max(0, [Math]::Min($x, $maxScrollX))
$this.ScrollY = [Math]::Max(0, [Math]::Min($y, $maxScrollY))
$this.RequestRedraw()
}

[void] ScrollBy([int]$deltaX, [int]$deltaY) {
$this.ScrollTo($this.ScrollX + $deltaX, $this.ScrollY + $deltaY)
}

[bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
if ($this.IsFocused) {
switch ($keyInfo.Key) {
([ConsoleKey]::UpArrow) { $this.ScrollBy(0, -1); return $true }
([ConsoleKey]::DownArrow) { $this.ScrollBy(0, 1); return $true }
([ConsoleKey]::LeftArrow) { $this.ScrollBy(-1, 0); return $true }
([ConsoleKey]::RightArrow) { $this.ScrollBy(1, 0); return $true }
([ConsoleKey]::PageUp) { $this.ScrollBy(0, -$this.ContentHeight); return $true }
([ConsoleKey]::PageDown) { $this.ScrollBy(0, $this.ContentHeight); return $true }
([ConsoleKey]::Home) { $this.ScrollTo(0, 0); return $true }
([ConsoleKey]::End) { $this.ScrollTo(0, $this.VirtualHeight); return $true }
}
}
return ([Panel]$this).HandleInput($keyInfo)
}

[void] OnRender() {
([Panel]$this).OnRender()
if ($null -ne $this.{_virtual_buffer}) {
$visibleBuffer = $this.{_virtual_buffer}.GetSubBuffer($this.ScrollX, $this.ScrollY, $this.ContentWidth, $this.ContentHeight)
$this.{_private_buffer}.BlendBuffer($visibleBuffer, $this.ContentX, $this.ContentY)
}
if ($this.ShowScrollbars -and $this.HasBorder) {
$this.DrawScrollbars()
}
}

[void] DrawScrollbars() {
if ($null -eq $this.{_private_buffer}) { return }
if ($this.VirtualHeight -gt $this.ContentHeight) {
$scrollbarX = $this.Width - 1
$scrollbarHeight = $this.Height - 2
$thumbPosition = [Math]::Floor(($this.ScrollY / [Math]::Max(1, $this.VirtualHeight - $this.ContentHeight)) * ($scrollbarHeight - 1))
for ($y = 1; $y -lt ($this.Height - 1); $y++) {
$char = if ($y -eq ($thumbPosition + 1)) { '█' } else { '▒' }
$cell = [TuiCell]::new($char, [ConsoleColor]::Gray, $this.BackgroundColor)
$this.{_private_buffer}.SetCell($scrollbarX, $y, $cell)
}
}
if ($this.VirtualWidth -gt $this.ContentWidth) {
$scrollbarY = $this.Height - 1
$scrollbarWidth = $this.Width - 2
$thumbPosition = [Math]::Floor(($this.ScrollX / [Math]::Max(1, $this.VirtualWidth - $this.ContentWidth)) * ($scrollbarWidth - 1))
for ($x = 1; $x -lt ($this.Width - 1); $x++) {
$char = if ($x -eq ($thumbPosition + 1)) { '█' } else { '▒' }
$cell = [TuiCell]::new($char, [ConsoleColor]::Gray, $this.BackgroundColor)
$this.{_private_buffer}.SetCell($x, $scrollbarY, $cell)
}
}
}

[TuiBuffer] GetVirtualBuffer() {
return $this.{_virtual_buffer}
}
}

class GroupPanel : Panel {
[bool] $IsCollapsed = $false
[int] $ExpandedHeight = 0
[int] $HeaderHeight = 1
[ConsoleColor] $HeaderColor = [ConsoleColor]::DarkBlue
[string] $CollapseChar = "▼"
[string] $ExpandChar = "▶"

GroupPanel() : base() {
$this.Name = "GroupPanel"
$this.IsFocusable = $true
$this.CanFocus = $true
$this.ExpandedHeight = $this.Height
}

GroupPanel([int]$x, [int]$y, [int]$width, [int]$height, [string]$title) : base($x, $y, $width, $height, $title) {
$this.Name = "GroupPanel"
$this.IsFocusable = $true
$this.CanFocus = $true
$this.ExpandedHeight = $height
}

[void] ToggleCollapsed() {
$this.IsCollapsed = -not $this.IsCollapsed
if ($this.IsCollapsed) {
$this.ExpandedHeight = $this.Height
$this.Resize($this.Width, $this.HeaderHeight + 2)
} else {
$this.Resize($this.Width, $this.ExpandedHeight)
}
foreach ($child in $this.Children) {
$child.Visible = -not $this.IsCollapsed
}
$this.RequestRedraw()
}

[bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
if ($this.IsFocused) {
switch ($keyInfo.Key) {
([ConsoleKey]::Enter) { $this.ToggleCollapsed(); return $true }
([ConsoleKey]::Spacebar) { $this.ToggleCollapsed(); return $true }
}
}
if (-not $this.IsCollapsed) {
return ([Panel]$this).HandleInput($keyInfo)
}
return $false
}

[void] OnRender() {
([Panel]$this).OnRender()
if ($this.HasBorder -and -not [string]::IsNullOrEmpty($this.Title)) {
$indicator = if ($this.IsCollapsed) { $this.ExpandChar } else { $this.CollapseChar }
$indicatorCell = [TuiCell]::new($indicator, $this.TitleColor, $this.BackgroundColor)
$this.{_private_buffer}.SetCell(2, 0, $indicatorCell)
}
}
}
#endregion

# --- END OF FULL REPLACEMENT for layout\panels-class\panels-class.psm1 ---
