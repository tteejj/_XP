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
