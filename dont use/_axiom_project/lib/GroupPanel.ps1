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
