# Explicitly declare dependencies for the parser
#using module '../ui-classes/ui-classes.psd1'
#using module '../tui-primitives/tui-primitives.psd1'
#using module '../../modules/theme-manager/theme-manager.psd1'
#change these to this method as root is set in run at op
#using module ui-classes
#using module tui-primitives
#using module theme-manager


# ==============================================================================
# Panel Classes v5.2 - Axiom-Phoenix Layout Foundation
# Provides Panel base class for layout management and specialized panel types.
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#region Panel Class - A specialized UIElement
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
    [string] $LayoutType = "Manual"

    Panel() : base() {
        $this.Name = "Panel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
        Write-Verbose "Panel: Default constructor called for '$($this.Name)'."
    }

    Panel([int]$x, [int]$y, [int]$width, [int]$height) : base($x, $y, $width, $height) { # FIX: Removed invalid attributes
        $this.Name = "Panel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
        Write-Verbose "Panel: Constructor with dimensions called for '$($this.Name)' at ($x, $y) with $($width)x$($height)."
    }

    Panel([int]$x, [int]$y, [int]$width, [int]$height, [string]$title) : base($x, $y, $width, $height) { # FIX: Removed invalid attributes
        $this.Name = "Panel_$(Get-Random -Maximum 1000)"
        $this.Title = $title
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
        Write-Verbose "Panel: Constructor with title called for '$($this.Name)' ('$title') at ($x, $y) with $($width)x$($height)."
    }

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
        Write-Verbose "Panel '$($this.Name)': Content bounds updated to ($($this.ContentX), $($this.ContentY)) - $($this.ContentWidth)x$($this.ContentHeight) (HasBorder: $($this.HasBorder))."
    }

    [void] OnResize([int]$newWidth, [int]$newHeight) { # FIX: Removed invalid attributes
        ([UIElement]$this).OnResize($newWidth, $newHeight) 
        $this.UpdateContentBounds()
        $this.PerformLayout()
        Write-Verbose "Panel '$($this.Name)': OnResize triggered, new content bounds calculated and layout performed."
    }

    [void] PerformLayout() {
        try {
            if ($this.Children.Count -eq 0) {
                Write-Verbose "Panel '$($this.Name)': No children to lay out."
                return
            }
            switch ($this.LayoutType) {
                "Vertical" { $this.LayoutVertical() }
                "Horizontal" { $this.LayoutHorizontal() }
                "Grid" { $this.LayoutGrid() }
                "Manual" { Write-Verbose "Panel '$($this.Name)': LayoutType is Manual, skipping auto-layout." }
                default { Write-Warning "Panel '$($this.Name)': Unknown LayoutType '$($this.LayoutType)'. Skipping auto-layout." }
            }
            Write-Verbose "Panel '$($this.Name)': Layout performed for type '$($this.LayoutType)'."
        }
        catch {
            Write-Error "Panel '$($this.Name)': Error during PerformLayout for type '$($this.LayoutType)': $($_.Exception.Message)"
            throw
        }
    }

    hidden [void] LayoutVertical() {
        if ($this.Children.Count -eq 0) { return }
        if ($this.ContentHeight -eq 0) { Write-Warning "Panel '$($this.Name)': ContentHeight is 0 for vertical layout. Children will have 0 height." }
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
                $child.Resize($childWidth, [Math]::Max(1, $remainingHeight))
            } else {
                $child.Resize($childWidth, $childHeight)
            }
            $currentY += $child.Height
        }
        Write-Verbose "Panel '$($this.Name)': Performed Vertical Layout for $($this.Children.Count) children."
    }

    hidden [void] LayoutHorizontal() {
        if ($this.Children.Count -eq 0) { return }
        if ($this.ContentWidth -eq 0) { Write-Warning "Panel '$($this.Name)': ContentWidth is 0 for horizontal layout. Children will have 0 width." }
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
                $child.Resize([Math]::Max(1, $remainingWidth), $childHeight)
            } else {
                $child.Resize($childWidth, $childHeight)
            }
            $currentX += $child.Width
        }
        Write-Verbose "Panel '$($this.Name)': Performed Horizontal Layout for $($this.Children.Count) children."
    }

    hidden [void] LayoutGrid() {
        if ($this.Children.Count -eq 0) { return }
        if ($this.ContentWidth -eq 0 -or $this.ContentHeight -eq 0) { Write-Warning "Panel '$($this.Name)': Content dimensions are zero for grid layout. Children will have 0 dimensions." }
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
            $child.Resize([Math]::Max(1, $width), [Math]::Max(1, $height))
        }
        Write-Verbose "Panel '$($this.Name)': Performed Grid Layout for $($this.Children.Count) children ($rows x $cols grid)."
    }

    [void] SetBorderStyle([string]$style, [ConsoleColor]$color) { # FIX: Removed invalid attributes
        $this.BorderStyle = $style
        $this.BorderColor = $color
        $this.RequestRedraw()
        Write-Verbose "Panel '$($this.Name)': Border style set to '$style' with color '$color'."
    }

    [void] SetBorder([bool]$hasBorder) { # FIX: Removed invalid attributes
        if ($this.HasBorder -eq $hasBorder) {
            Write-Verbose "Panel '$($this.Name)': Border status already $($hasBorder). No change."
            return
        }
        $this.HasBorder = $hasBorder
        $this.UpdateContentBounds()
        $this.PerformLayout()
        $this.RequestRedraw()
        Write-Verbose "Panel '$($this.Name)': Border set to '$hasBorder'. Content bounds updated and layout performed."
    }

    [void] SetTitle([string]$title) { # FIX: Removed invalid attributes
        if ($this.Title -eq $title) {
            Write-Verbose "Panel '$($this.Name)': Title already set to '$title'. No change."
            return
        }
        $this.Title = $title
        $this.RequestRedraw()
        Write-Verbose "Panel '$($this.Name)': Title set to '$title'."
    }

    [bool] ContainsContentPoint([int]$x, [int]$y) { # FIX: Removed invalid attributes
        return ($x -ge $this.ContentX -and $x -lt ($this.ContentX + $this.ContentWidth) -and 
                $y -ge $this.ContentY -and $y -lt ($this.ContentY + $this.ContentHeight))
    }

    [hashtable] GetContentBounds() { return @{ X = $this.ContentX; Y = $this.ContentY; Width = $this.ContentWidth; Height = $this.ContentHeight } }
    [hashtable] GetContentArea() { return $this.GetContentBounds() }
    
    [void] WriteToBuffer([int]$x, [int]$y, [string]$text, [ConsoleColor]$fg, [ConsoleColor]$bg) { # FIX: Removed invalid attributes
        if ($null -eq $this._private_buffer) { 
            Write-Warning "Panel '$($this.Name)': Internal buffer is null, cannot write text. (Call OnRender first)."
            return 
        }
        Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $text -ForegroundColor $fg -BackgroundColor $bg
        Write-Verbose "Panel '$($this.Name)': Wrote text to buffer at ($x, $y)."
    }
    
    [void] DrawBoxToBuffer([int]$x, [int]$y, [int]$width, [int]$height, [ConsoleColor]$borderColor, [ConsoleColor]$bgColor) { # FIX: Removed invalid attributes
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        if ($null -eq $this._private_buffer) { 
            Write-Warning "Panel '$($this.Name)': Internal buffer is null, cannot draw box. (Call OnRender first)."
            return 
        }
        Write-TuiBox -Buffer $this._private_buffer -X $x -Y $y -Width $width -Height $height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
        Write-Verbose "Panel '$($this.Name)': Drew sub-box on buffer at ($x, $y) with $($width)x$($height)."
    }

    [void] ClearContent() {
        if ($null -eq $this._private_buffer) { return }
        $clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor)
        for ($y = $this.ContentY; $y -lt ($this.ContentY + $this.ContentHeight); $y++) {
            for ($x = $this.ContentX; $x -lt ($this.ContentX + $this.ContentWidth); $x++) {
                $this._private_buffer.SetCell($x, $y, $clearCell)
            }
        }
        $this.RequestRedraw()
        Write-Verbose "Panel '$($this.Name)': Content area cleared."
    }

    [void] OnRender() {
        if ($null -eq $this._private_buffer) { 
            Write-Warning "Panel '$($this.Name)': OnRender called but internal buffer is null. Skipping render."
            return 
        }
        $bgCell = [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor)
        $this._private_buffer.Clear($bgCell)
        if ($this.HasBorder) {
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle $this.BorderStyle -BorderColor $this.BorderColor -BackgroundColor $this.BackgroundColor -Title $this.Title
        }
        Write-Verbose "Panel '$($this.Name)': OnRender completed (background and border)."
    }

    [void] OnFocus() {
        ([UIElement]$this).OnFocus()
        if ($this.CanFocus) {
            $this.BorderColor = Get-ThemeColor 'Accent'
            $this.RequestRedraw()
            Write-Verbose "Panel '$($this.Name)': Gained focus, border color set to theme accent."
        }
    }

    [void] OnBlur() {
        ([UIElement]$this).OnBlur()
        if ($this.CanFocus) {
            $this.BorderColor = Get-ThemeColor 'Border'
            $this.RequestRedraw()
            Write-Verbose "Panel '$($this.Name)': Lost focus, border color set to theme border."
        }
    }

    [object] GetFirstFocusableChild() {
        foreach ($child in $this.Children | Sort-Object TabIndex) {
            if ($child.IsFocusable -and $child.Visible -and $child.Enabled) {
                Write-Verbose "Panel '$($this.Name)': Found first focusable child '$($child.Name)'."
                return $child
            }
            if ($child.PSObject.TypeNames -contains 'Panel') {
                $nestedChild = $child.GetFirstFocusableChild()
                if ($null -ne $nestedChild) {
                    Write-Verbose "Panel '$($this.Name)': Found nested focusable child '$($nestedChild.Name)'."
                    return $nestedChild
                }
            }
        }
        Write-Verbose "Panel '$($this.Name)': No focusable children found."
        return $null
    }

    [System.Collections.Generic.List[object]] GetFocusableChildren() {
        $focusable = [System.Collections.Generic.List[object]]::new()
        foreach ($child in $this.Children | Sort-Object TabIndex) {
            if ($child.IsFocusable -and $child.Visible -and $child.Enabled) {
                [void]$focusable.Add($child)
            }
            if ($child -is [Panel]) {
                $nestedFocusable = $child.GetFocusableChildren()
                $focusable.AddRange($nestedFocusable)
            }
        }
        Write-Verbose "Panel '$($this.Name)': Collected $($focusable.Count) focusable children."
        return $focusable
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) { # FIX: Removed invalid attributes
        try {
            ([UIElement]$this).HandleInput($keyInfo)
            if ($this.CanFocus -and $this.IsFocused) {
                switch ($keyInfo.Key) {
                    ([ConsoleKey]::Tab) {
                        $firstChild = $this.GetFirstFocusableChild()
                        if ($null -ne $firstChild) {
                            $this.IsFocused = $false
                            Write-Verbose "Panel '$($this.Name)': Redirecting focus to first child '$($firstChild.Name)' on Tab press."
                            return $true
                        }
                    }
                    ([ConsoleKey]::Enter) {
                        $firstChild = $this.GetFirstFocusableChild()
                        if ($null -ne $firstChild) {
                            $this.IsFocused = $false
                            Write-Verbose "Panel '$($this.Name)': Redirecting focus to first child '$($firstChild.Name)' on Enter press."
                            return $true
                        }
                    }
                }
            }
            foreach ($child in $this.Children | Sort-Object TabIndex) {
                if ($child.Visible -and $child.Enabled) {
                    if ($child.HandleInput($keyInfo)) {
                        Write-Verbose "Panel '$($this.Name)': Child '$($child.Name)' handled input."
                        return $true
                    }
                }
            }
            Write-Verbose "Panel '$($this.Name)': Did not handle input. Key: $($keyInfo.Key)."
        }
        catch {
            Write-Error "Panel '$($this.Name)': Error handling input (Key: $($keyInfo.Key)): $($_.Exception.Message)"
            throw
        }
        return $false
    }

    [string] ToString() {
        return "Panel(Name='$($this.Name)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height), HasBorder=$($this.HasBorder), Children=$($this.Children.Count))"
    }
}
#endregion

#region Specialized Panel Types
class ScrollablePanel : Panel {
    [int] $ScrollX = 0 
    [int] $ScrollY = 0 
    [int] $VirtualWidth = 0 
    [int] $VirtualHeight = 0 
    [bool] $ShowScrollbars = $true 
    hidden [TuiBuffer] $_virtual_buffer = $null

    ScrollablePanel() : base() {
        $this.Name = "ScrollablePanel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $true
        $this.CanFocus = $true
        Write-Verbose "ScrollablePanel: Default constructor called for '$($this.Name)'."
    }

    ScrollablePanel([int]$x, [int]$y, [int]$width, [int]$height) : base($x, $y, $width, $height) { # FIX: Removed invalid attributes
        $this.Name = "ScrollablePanel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $true
        $this.CanFocus = $true
        Write-Verbose "ScrollablePanel: Constructor with dimensions called for '$($this.Name)'."
    }

    [void] SetVirtualSize([int]$width, [int]$height) { # FIX: Removed invalid attributes
        if ($width -lt 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width cannot be negative.") }
        if ($height -lt 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height cannot be negative.") }
        try {
            if ($this.VirtualWidth -eq $width -and $this.VirtualHeight -eq $height) {
                Write-Verbose "ScrollablePanel '$($this.Name)': Virtual size already set to $($width)x$($height). No change."
                return
            }
            $this.VirtualWidth = $width
            $this.VirtualHeight = $height
            if ($width -gt 0 -and $height -gt 0) {
                if ($null -ne $this._virtual_buffer -and $this._virtual_buffer.Width -eq $width -and $this._virtual_buffer.Height -eq $height) {
                    Write-Verbose "ScrollablePanel '$($this.Name)': Virtual buffer already correct size."
                } else {
                    $this._virtual_buffer = [TuiBuffer]::new($width, $height, "$($this.Name).Virtual")
                    Write-Verbose "ScrollablePanel '$($this.Name)': Virtual buffer re-initialized to $($width)x$($height)."
                }
            } else {
                $this._virtual_buffer = $null
                Write-Verbose "ScrollablePanel '$($this.Name)': Virtual size set to 0, clearing virtual buffer."
            }
            $this.ScrollTo($this.ScrollX, $this.ScrollY)
            $this.RequestRedraw()
            Write-Verbose "ScrollablePanel '$($this.Name)': Virtual size set to $($width)x$($height)."
        }
        catch {
            Write-Error "ScrollablePanel '$($this.Name)': Error setting virtual size to $($width)x$($height): $($_.Exception.Message)"
            throw
        }
    }

    [void] ScrollTo([int]$x, [int]$y) { # FIX: Removed invalid attributes
        $maxScrollX = [Math]::Max(0, $this.VirtualWidth - $this.ContentWidth)
        $maxScrollY = [Math]::Max(0, $this.VirtualHeight - $this.ContentHeight)
        $newScrollX = [Math]::Max(0, [Math]::Min($x, $maxScrollX))
        $newScrollY = [Math]::Max(0, [Math]::Min($y, $maxScrollY))
        if ($this.ScrollX -eq $newScrollX -and $this.ScrollY -eq $newScrollY) {
            Write-Verbose "ScrollablePanel '$($this.Name)': Scroll position already at ($newScrollX, $newScrollY). No change."
            return
        }
        $this.ScrollX = $newScrollX
        $this.ScrollY = $newScrollY
        $this.RequestRedraw()
        Write-Verbose "ScrollablePanel '$($this.Name)': Scrolled to ($($this.ScrollX), $($this.ScrollY))."
    }

    [void] ScrollBy([int]$deltaX, [int]$deltaY) { # FIX: Removed invalid attributes
        $this.ScrollTo($this.ScrollX + $deltaX, $this.ScrollY + $deltaY)
        Write-Verbose "ScrollablePanel '$($this.Name)': Scrolled by ($deltaX, $deltaY)."
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) { # FIX: Removed invalid attributes
        try {
            ([Panel]$this).HandleInput($keyInfo)
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
            Write-Verbose "ScrollablePanel '$($this.Name)': Did not handle input. Key: $($keyInfo.Key)."
        }
        catch {
            Write-Error "ScrollablePanel '$($this.Name)': Error handling input (Key: $($keyInfo.Key)): $($_.Exception.Message)"
            throw
        }
        return $false
    }

    [void] OnRender() {
        ([Panel]$this).OnRender()
        Write-Verbose "ScrollablePanel '$($this.Name)': Base Panel OnRender completed."
        if ($null -ne $this._virtual_buffer -and $this.ContentWidth -gt 0 -and $this.ContentHeight -gt 0) {
            $visibleBuffer = $this._virtual_buffer.GetSubBuffer($this.ScrollX, $this.ScrollY, $this.ContentWidth, $this.ContentHeight)
            $this._private_buffer.BlendBuffer($visibleBuffer, $this.ContentX, $this.ContentY)
            Write-Verbose "ScrollablePanel '$($this.Name)': Blended virtual content."
        } else {
            Write-Verbose "ScrollablePanel '$($this.Name)': No virtual content to blend or content area is zero."
        }
        if ($this.ShowScrollbars -and $this.HasBorder) {
            $this.DrawScrollbars()
            Write-Verbose "ScrollablePanel '$($this.Name)': Scrollbars drawn."
        }
    }

    hidden [void] DrawScrollbars() {
        if ($null -eq $this._private_buffer) { return }
        if ($this.VirtualHeight -gt $this.ContentHeight -and $this.Width -gt 1) {
            $scrollbarX = $this.Width - 1
            $scrollbarTrackHeight = $this.Height - 2
            $scrollRatioY = ($this.ScrollY / [Math]::Max(1, $this.VirtualHeight - $this.ContentHeight))
            $thumbPositionInTrack = [Math]::Floor($scrollRatioY * ($scrollbarTrackHeight - 1))
            for ($y = 1; $y -lt ($this.Height - 1); $y++) {
                $char = if ($y -eq ($thumbPositionInTrack + 1)) { '█' } else { '▒' }
                $cell = [TuiCell]::new($char, (Get-ThemeColor 'Subtle'), $this.BackgroundColor)
                $this._private_buffer.SetCell($scrollbarX, $y, $cell)
            }
            Write-Verbose "ScrollablePanel '$($this.Name)': Vertical scrollbar drawn."
        }
        if ($this.VirtualWidth -gt $this.ContentWidth -and $this.Height -gt 1) {
            $scrollbarY = $this.Height - 1
            $scrollbarTrackWidth = $this.Width - 2
            $scrollRatioX = ($this.ScrollX / [Math]::Max(1, $this.VirtualWidth - $this.ContentWidth))
            $thumbPositionInTrack = [Math]::Floor($scrollRatioX * ($scrollbarTrackWidth - 1))
            for ($x = 1; $x -lt ($this.Width - 1); $x++) {
                $char = if ($x -eq ($thumbPositionInTrack + 1)) { '█' } else { '▒' }
                $cell = [TuiCell]::new($char, (Get-ThemeColor 'Subtle'), $this.BackgroundColor)
                $this._private_buffer.SetCell($x, $scrollbarY, $cell)
            }
            Write-Verbose "ScrollablePanel '$($this.Name)': Horizontal scrollbar drawn."
        }
    }

    [object] GetVirtualBuffer() { return $this._virtual_buffer }

    [string] ToString() {
        return "ScrollablePanel(Name='$($this.Name)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height), VirtualSize=$($this.VirtualWidth)x$($this.VirtualHeight), Scroll=($($this.ScrollX),$($this.ScrollY)))"
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
        $this.Name = "GroupPanel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $true
        $this.CanFocus = $true
        $this.ExpandedHeight = $this.Height
        Write-Verbose "GroupPanel: Default constructor called for '$($this.Name)'."
    }

    GroupPanel([int]$x, [int]$y, [int]$width, [int]$height, [string]$title) : base($x, $y, $width, $height, $title) { # FIX: Removed invalid attributes
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        $this.Name = "GroupPanel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $true
        $this.CanFocus = $true
        $this.ExpandedHeight = $height
        Write-Verbose "GroupPanel: Constructor with dimensions and title called for '$($this.Name)' ('$title')."
    }

    [void] ToggleCollapsed() {
        try {
            $this.IsCollapsed = -not $this.IsCollapsed
            if ($this.IsCollapsed) {
                $this.ExpandedHeight = $this.Height
                $this.Resize($this.Width, [Math]::Max(1, $this.HeaderHeight + 2))
                Write-Verbose "GroupPanel '$($this.Name)': Collapsed. Resized to $($this.Width)x$($this.Height)."
            } else {
                $this.Resize($this.Width, [Math]::Max(1, $this.ExpandedHeight))
                Write-Verbose "GroupPanel '$($this.Name)': Expanded. Resized to $($this.Width)x$($this.Height)."
            }
            foreach ($child in $this.Children) {
                $child.Visible = -not $this.IsCollapsed
            }
            $this.RequestRedraw()
            Write-Verbose "GroupPanel '$($this.Name)': Toggled collapsed state to $($this.IsCollapsed). Children visibility updated."
        }
        catch {
            Write-Error "GroupPanel '$($this.Name)': Error toggling collapsed state: $($_.Exception.Message)"
            throw
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) { # FIX: Removed invalid attributes
        try {
            ([Panel]$this).HandleInput($keyInfo)
            if ($this.IsFocused) {
                switch ($keyInfo.Key) {
                    ([ConsoleKey]::Enter) { $this.ToggleCollapsed(); return $true }
                    ([ConsoleKey]::Spacebar) { $this.ToggleCollapsed(); return $true }
                }
            }
            if (-not $this.IsCollapsed) {
                Write-Verbose "GroupPanel '$($this.Name)': Not collapsed, delegating input to children."
                return ([Panel]$this).HandleInput($keyInfo)
            }
            Write-Verbose "GroupPanel '$($this.Name)': Did not handle input. Key: $($keyInfo.Key)."
        }
        catch {
            Write-Error "GroupPanel '$($this.Name)': Error handling input (Key: $($keyInfo.Key)): $($_.Exception.Message)"
            throw
        }
        return $false
    }

    [void] OnRender() {
        ([Panel]$this).OnRender()
        Write-Verbose "GroupPanel '$($this.Name)': Base Panel OnRender completed."
        if ($this.HasBorder -and -not [string]::IsNullOrEmpty($this.Title)) {
            $indicator = if ($this.IsCollapsed) { $this.ExpandChar } else { $this.CollapseChar }
            $indicatorCell = [TuiCell]::new($indicator, $this.TitleColor, $this.BackgroundColor)
            if (3 -lt ($this.Width - 1)) {
                $this._private_buffer.SetCell(2, 0, $indicatorCell)
                Write-Verbose "GroupPanel '$($this.Name)': Indicator '$indicator' drawn."
            }
        }
    }

    [string] ToString() {
        return "GroupPanel(Name='$($this.Name)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height), Collapsed=$($this.IsCollapsed))"
    }
}
#endregion

#region Module Exports
# This is handled by the .psd1 manifest.
#endregion