# ==============================================================================
# Panel Classes v5.2 - Axiom-Phoenix Layout Foundation
# Provides Panel base class for layout management and specialized panel types.
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#region Panel Class - A specialized UIElement
# A Panel is a container UIElement that can draw a border and title,
# and it intelligently manages child elements, positioning them correctly
# within its bordered "content area".
class Panel : UIElement {
    [string] $Title = ""                     # Title displayed on the top border
    [string] $BorderStyle = "Single"         # Style of the border (e.g., "Single", "Double", "Rounded", "Thick")
    [ConsoleColor] $BorderColor = [ConsoleColor]::Gray # Color of the border
    [ConsoleColor] $BackgroundColor = [ConsoleColor]::Black # Background color of the panel's interior
    [ConsoleColor] $TitleColor = [ConsoleColor]::White # Color of the title text
    [bool] $HasBorder = $true                # Whether the panel should draw a border
    [bool] $CanFocus = $false                # Can this panel itself receive focus (e.g., for navigation)?
    [int] $ContentX = 0                      # X-coordinate of the panel's content area (relative to panel's origin)
    [int] $ContentY = 0                      # Y-coordinate of the panel's content area (relative to panel's origin)
    [int] $ContentWidth = 0                   # Width of the panel's content area
    [int] $ContentHeight = 0                  # Height of the panel's content area
    [string] $LayoutType = "Manual"          # Defines how children are automatically laid out ("Manual", "Vertical", "Horizontal", "Grid")

    # Default constructor.
    # Initializes a Panel with a default name and updates its content bounds.
    Panel() : base() {
        $this.Name = "Panel_$(Get-Random -Maximum 1000)" # Assign a unique default name
        $this.IsFocusable = $false # Panels themselves are typically not focusable by default
        $this.UpdateContentBounds()
        Write-Verbose "Panel: Default constructor called for '$($this.Name)'."
    }

    # Constructor with position and size.
    # Initializes a Panel with specified dimensions and updates content bounds.
    Panel(
        [Parameter(Mandatory)][int]$x,
        [Parameter(Mandatory)][int]$y,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$width,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$height
    ) : base($x, $y, $width, $height) {
        $this.Name = "Panel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
        Write-Verbose "Panel: Constructor with dimensions called for '$($this.Name)' at ($x, $y) with $($width)x$($height)."
    }

    # Constructor with title.
    # Initializes a Panel with specified dimensions and a title.
    Panel(
        [Parameter(Mandatory)][int]$x,
        [Parameter(Mandatory)][int]$y,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$width,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$height,
        [Parameter(Mandatory)][string]$title
    ) : base($x, $y, $width, $height) {
        $this.Name = "Panel_$(Get-Random -Maximum 1000)" # Ensure a unique name if not explicitly set
        $this.Title = $title
        $this.IsFocusable = $false
        $this.UpdateContentBounds()
        Write-Verbose "Panel: Constructor with title called for '$($this.Name)' ('$title') at ($x, $y) with $($width)x$($height)."
    }

    # UpdateContentBounds: Calculates the size and position of the interior content area,
    # accounting for the border if present.
    [void] UpdateContentBounds() {
        if ($this.HasBorder) {
            $this.ContentX = 1
            $this.ContentY = 1
            # Content width/height is reduced by 2 for borders (1 on each side).
            # Ensure dimensions do not go below 0.
            $this.ContentWidth = [Math]::Max(0, $this.Width - 2)
            $this.ContentHeight = [Math]::Max(0, $this.Height - 2)
        } else {
            # If no border, content area is the full panel size.
            $this.ContentX = 0
            $this.ContentY = 0
            $this.ContentWidth = $this.Width
            $this.ContentHeight = $this.Height
        }
        Write-Verbose "Panel '$($this.Name)': Content bounds updated to ($($this.ContentX), $($this.ContentY)) - $($this.ContentWidth)x$($this.ContentHeight) (HasBorder: $($this.HasBorder))."
    }

    # OnResize: Overrides UIElement's virtual method.
    # Called when the panel's dimensions change. It updates content bounds and performs layout.
    [void] OnResize([Parameter(Mandatory)][int]$newWidth, [Parameter(Mandatory)][int]$newHeight) {
        # Call base implementation first
        ([UIElement]$this).OnResize($newWidth, $newHeight) 

        $this.UpdateContentBounds() # Recalculate content area based on new size
        $this.PerformLayout()        # Re-layout children based on new content area
        Write-Verbose "Panel '$($this.Name)': OnResize triggered, new content bounds calculated and layout performed."
    }

    # PerformLayout: Automatically arranges child elements based on the LayoutType property.
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
                "Manual" { Write-Verbose "Panel '$($this.Name)': LayoutType is Manual, skipping auto-layout." } # No automatic layout
                default { Write-Warning "Panel '$($this.Name)': Unknown LayoutType '$($this.LayoutType)'. Skipping auto-layout." }
            }
            Write-Verbose "Panel '$($this.Name)': Layout performed for type '$($this.LayoutType)'."
        }
        catch {
            Write-Error "Panel '$($this.Name)': Error during PerformLayout for type '$($this.LayoutType)': $($_.Exception.Message)"
            throw # Re-throw for Invoke-WithErrorHandling to catch
        }
    }

    # LayoutVertical: Arranges children stacked vertically within the content area.
    hidden [void] LayoutVertical() {
        if ($this.Children.Count -eq 0) { return }
        if ($this.ContentHeight -eq 0) {
            Write-Warning "Panel '$($this.Name)': ContentHeight is 0 for vertical layout. Children will have 0 height."
        }

        $currentY = $this.ContentY # Start Y position for children
        $childWidth = $this.ContentWidth # Children fill the full content width
        $availableHeight = $this.ContentHeight
        
        # Ensure childHeight is at least 1 to avoid zero-height components
        $childHeight = [Math]::Max(1, [Math]::Floor($availableHeight / $this.Children.Count)) 

        for ($i = 0; $i -lt $this.Children.Count; $i++) {
            $child = $this.Children[$i]
            $child.X = $this.ContentX # Child's X relative to panel's origin
            $child.Y = $currentY       # Child's Y relative to panel's origin
            
            # For the last child, assign remaining height to fill any gaps due to floor() division.
            if ($i -eq ($this.Children.Count - 1)) {
                $remainingHeight = $this.ContentY + $this.ContentHeight - $currentY
                $child.Resize($childWidth, [Math]::Max(1, $remainingHeight)) # Ensure height is at least 1
            } else {
                $child.Resize($childWidth, $childHeight)
            }
            
            $currentY += $child.Height # Advance Y for next child
        }
        Write-Verbose "Panel '$($this.Name)': Performed Vertical Layout for $($this.Children.Count) children."
    }

    # LayoutHorizontal: Arranges children side-by-side horizontally within the content area.
    hidden [void] LayoutHorizontal() {
        if ($this.Children.Count -eq 0) { return }
        if ($this.ContentWidth -eq 0) {
            Write-Warning "Panel '$($this.Name)': ContentWidth is 0 for horizontal layout. Children will have 0 width."
        }

        $currentX = $this.ContentX # Start X position for children
        $childHeight = $this.ContentHeight # Children fill the full content height
        $availableWidth = $this.ContentWidth
        
        # Ensure childWidth is at least 1 to avoid zero-width components
        $childWidth = [Math]::Max(1, [Math]::Floor($availableWidth / $this.Children.Count))

        for ($i = 0; $i -lt $this.Children.Count; $i++) {
            $child = $this.Children[$i]
            $child.X = $currentX # Child's X relative to panel's origin
            $child.Y = $this.ContentY # Child's Y relative to panel's origin
            
            # For the last child, assign remaining width to fill any gaps.
            if ($i -eq ($this.Children.Count - 1)) {
                $remainingWidth = $this.ContentX + $this.ContentWidth - $currentX
                $child.Resize([Math]::Max(1, $remainingWidth), $childHeight) # Ensure width is at least 1
            } else {
                $child.Resize($childWidth, $childHeight)
            }
            
            $currentX += $child.Width # Advance X for next child
        }
        Write-Verbose "Panel '$($this.Name)': Performed Horizontal Layout for $($this.Children.Count) children."
    }

    # LayoutGrid: Arranges children in a grid pattern within the content area.
    hidden [void] LayoutGrid() {
        if ($this.Children.Count -eq 0) { return }
        if ($this.ContentWidth -eq 0 -or $this.ContentHeight -eq 0) {
            Write-Warning "Panel '$($this.Name)': Content dimensions are zero for grid layout. Children will have 0 dimensions."
        }

        $childCount = $this.Children.Count
        $cols = [Math]::Ceiling([Math]::Sqrt($childCount)) # Calculate number of columns
        $rows = [Math]::Ceiling($childCount / $cols)     # Calculate number of rows
        
        # Ensure cell dimensions are at least 1
        $cellWidth = [Math]::Max(1, [Math]::Floor($this.ContentWidth / $cols))
        $cellHeight = [Math]::Max(1, [Math]::Floor($this.ContentHeight / $rows))

        for ($i = 0; $i -lt $this.Children.Count; $i++) {
            $child = $this.Children[$i]
            $row = [Math]::Floor($i / $cols)
            $col = $i % $cols
            
            # Calculate child's absolute position within the panel
            $x = $this.ContentX + ($col * $cellWidth)
            $y = $this.ContentY + ($row * $cellHeight)
            
            # Adjust last column/row to fill remaining space
            $width = if ($col -eq ($cols - 1)) { $this.ContentX + $this.ContentWidth - $x } else { $cellWidth }
            $height = if ($row -eq ($rows - 1)) { $this.ContentY + $this.ContentHeight - $y } else { $cellHeight }
            
            $child.Move($x, $y) # Move child to calculated position
            $child.Resize([Math]::Max(1, $width), [Math]::Max(1, $height)) # Resize child
        }
        Write-Verbose "Panel '$($this.Name)': Performed Grid Layout for $($this.Children.Count) children ($rows x $cols grid)."
    }

    # SetBorderStyle: Updates the border style and color.
    [void] SetBorderStyle(
        [Parameter(Mandatory)][ValidateSet("Single", "Double", "Rounded", "Thick")][string]$style,
        [Parameter(Mandatory)][ConsoleColor]$color
    ) {
        $this.BorderStyle = $style
        $this.BorderColor = $color
        $this.RequestRedraw()
        Write-Verbose "Panel '$($this.Name)': Border style set to '$style' with color '$color'."
    }

    # SetBorder: Enables or disables the border, updating content bounds and layout.
    [void] SetBorder([Parameter(Mandatory)][bool]$hasBorder) {
        if ($this.HasBorder -eq $hasBorder) {
            Write-Verbose "Panel '$($this.Name)': Border status already $($hasBorder). No change."
            return # No change needed
        }
        $this.HasBorder = $hasBorder
        $this.UpdateContentBounds() # Recalculate content area
        $this.PerformLayout()        # Re-layout children
        $this.RequestRedraw()       # Request redraw for visual update
        Write-Verbose "Panel '$($this.Name)': Border set to '$hasBorder'. Content bounds updated and layout performed."
    }

    # SetTitle: Updates the panel's title.
    [void] SetTitle([Parameter(Mandatory)][string]$title) {
        if ($this.Title -eq $title) {
            Write-Verbose "Panel '$($this.Name)': Title already set to '$title'. No change."
            return
        }
        $this.Title = $title
        $this.RequestRedraw()
        Write-Verbose "Panel '$($this.Name)': Title set to '$title'."
    }

    # ContainsContentPoint: Checks if a point (relative to panel's origin) is within its content area.
    [bool] ContainsContentPoint([Parameter(Mandatory)][int]$x, [Parameter(Mandatory)][int]$y) {
        return ($x -ge $this.ContentX -and $x -lt ($this.ContentX + $this.ContentWidth) -and 
                $y -ge $this.ContentY -and $y -lt ($this.ContentY + $this.ContentHeight))
    }

    # GetContentBounds: Returns a hashtable describing the content area's position and dimensions.
    [hashtable] GetContentBounds() {
        return @{ X = $this.ContentX; Y = $this.ContentY; Width = $this.ContentWidth; Height = $this.ContentHeight }
    }
    
    # GetContentArea: Alias for GetContentBounds.
    [hashtable] GetContentArea() {
        return $this.GetContentBounds()
    }
    
    # WriteToBuffer: Helper to write text directly to the panel's internal buffer, within its coordinates.
    [void] WriteToBuffer(
        [Parameter(Mandatory)][int]$x,
        [Parameter(Mandatory)][int]$y,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$text,
        [Parameter(Mandatory)][ConsoleColor]$fg,
        [Parameter(Mandatory)][ConsoleColor]$bg
    ) {
        # Check if the panel's buffer is initialized before attempting to write.
        if ($null -eq $this._private_buffer) { 
            Write-Warning "Panel '$($this.Name)': Internal buffer is null, cannot write text. (Call OnRender first)."
            return 
        }
        Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $text -ForegroundColor $fg -BackgroundColor $bg
        Write-Verbose "Panel '$($this.Name)': Wrote text to buffer at ($x, $y)."
    }
    
    # DrawBoxToBuffer: Helper to draw a sub-box directly to the panel's internal buffer.
    [void] DrawBoxToBuffer(
        [Parameter(Mandatory)][int]$x,
        [Parameter(Mandatory)][int]$y,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$width,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$height,
        [Parameter(Mandatory)][ConsoleColor]$borderColor,
        [Parameter(Mandatory)][ConsoleColor]$bgColor
    ) {
        if ($null -eq $this._private_buffer) { 
            Write-Warning "Panel '$($this.Name)': Internal buffer is null, cannot draw box. (Call OnRender first)."
            return 
        }
        Write-TuiBox -Buffer $this._private_buffer -X $x -Y $y -Width $width -Height $height `
            -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
        Write-Verbose "Panel '$($this.Name)': Drew sub-box on buffer at ($x, $y) with $($width)x$($height)."
    }

    # ClearContent: Clears only the interior content area of the panel.
    [void] ClearContent() {
        if ($null -eq $this._private_buffer) { return } # Should not be null if rendered
        $clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor)
        for ($y = $this.ContentY; $y -lt ($this.ContentY + $this.ContentHeight); $y++) {
            for ($x = $this.ContentX; $x -lt ($this.ContentX + $this.ContentWidth); $x++) {
                $this._private_buffer.SetCell($x, $y, $clearCell)
            }
        }
        $this.RequestRedraw() # Clearing content means it needs redraw
        Write-Verbose "Panel '$($this.Name)': Content area cleared."
    }

    # OnRender: Overrides UIElement's virtual method.
    # This is where the Panel draws its own border and background.
    [void] OnRender() {
        # Ensure the buffer is ready. Base UIElement handles its creation/resize.
        if ($null -eq $this._private_buffer) { 
            Write-Warning "Panel '$($this.Name)': OnRender called but internal buffer is null. Skipping render."
            return 
        }
        
        # Clear the entire panel buffer with its background color.
        $bgCell = [TuiCell]::new(' ', [ConsoleColor]::White, $this.BackgroundColor)
        $this._private_buffer.Clear($bgCell)
        
        # Draw border if enabled.
        if ($this.HasBorder) {
            # Write-TuiBox handles clipping automatically.
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle $this.BorderStyle -BorderColor $this.BorderColor -BackgroundColor $this.BackgroundColor -Title $this.Title
        }
        Write-Verbose "Panel '$($this.Name)': OnRender completed (background and border)."
    }

    # OnFocus: Overrides UIElement's virtual method.
    # Changes border color when the panel gains focus, if it's focusable.
    [void] OnFocus() {
        ([UIElement]$this).OnFocus() # Call base implementation
        if ($this.CanFocus) {
            $this.BorderColor = Get-ThemeColor 'Accent'
            $this.RequestRedraw()
            Write-Verbose "Panel '$($this.Name)': Gained focus, border color set to theme accent."
        }
    }

    # OnBlur: Overrides UIElement's virtual method.
    # Changes border color back when the panel loses focus.
    [void] OnBlur() {
        ([UIElement]$this).OnBlur() # Call base implementation
        if ($this.CanFocus) {
            $this.BorderColor = Get-ThemeColor 'Border'
            $this.RequestRedraw()
            Write-Verbose "Panel '$($this.Name)': Lost focus, border color set to theme border."
        }
    }

    # GetFirstFocusableChild: Finds the first focusable child within this panel or its nested panels.
    [UIElement] GetFirstFocusableChild() {
        foreach ($child in $this.Children | Sort-Object TabIndex) { # Sort by TabIndex to get logical order
            if ($child.IsFocusable -and $child.Visible -and $child.Enabled) {
                Write-Verbose "Panel '$($this.Name)': Found first focusable child '$($child.Name)'."
                return $child
            }
            # Recursively check if child is a Panel and has focusable children
            if ($child -is [Panel]) {
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

    # GetFocusableChildren: Collects all focusable children, including those nested in child panels.
    [System.Collections.Generic.List[UIElement]] GetFocusableChildren() {
        $focusable = [System.Collections.Generic.List[UIElement]]::new()
        foreach ($child in $this.Children | Sort-Object TabIndex) { # Sort by TabIndex for logical order
            if ($child.IsFocusable -and $child.Visible -and $child.Enabled) {
                [void]$focusable.Add($child)
            }
            # Recursively collect from nested panels
            if ($child -is [Panel]) {
                $nestedFocusable = $child.GetFocusableChildren()
                $focusable.AddRange($nestedFocusable)
            }
        }
        Write-Verbose "Panel '$($this.Name)': Collected $($focusable.Count) focusable children."
        return $focusable
    }

    # HandleInput: Overrides UIElement's virtual method.
    # Handles basic navigation (Tab, Enter) to move focus to its first child if CanFocus is true.
    # Then delegates input to its children.
    [bool] HandleInput([Parameter(Mandatory)][System.ConsoleKeyInfo]$keyInfo) {
        try {
            ([UIElement]$this).HandleInput($keyInfo) # Call base implementation for verbose logging etc.

            if ($this.CanFocus -and $this.IsFocused) {
                switch ($keyInfo.Key) {
                    ([ConsoleKey]::Tab) {
                        # Move focus to the first focusable child when panel is tabbed into.
                        $firstChild = $this.GetFirstFocusableChild()
                        if ($null -ne $firstChild) {
                            $this.IsFocused = $false # Panel loses focus
                            # Set-ComponentFocus is usually a global function from TUIEngine.
                            # It's assumed to be available or managed externally.
                            # Example: Set-ComponentFocus -Component $firstChild
                            Write-Verbose "Panel '$($this.Name)': Redirecting focus to first child '$($firstChild.Name)' on Tab press."
                            return $true # Handled
                        }
                    }
                    ([ConsoleKey]::Enter) {
                        # Similar to Tab, Enter can also pass focus into the panel.
                        $firstChild = $this.GetFirstFocusableChild()
                        if ($null -ne $firstChild) {
                            $this.IsFocused = $false
                            # Set-ComponentFocus -Component $firstChild
                            Write-Verbose "Panel '$($this.Name)': Redirecting focus to first child '$($firstChild.Name)' on Enter press."
                            return $true # Handled
                        }
                    }
                }
            }
            
            # Delegate input to children if not handled by the panel itself.
            # Children are sorted by TabIndex for predictable input delegation order (e.g., for mouse/click events if applicable).
            foreach ($child in $this.Children | Sort-Object TabIndex) {
                if ($child.Visible -and $child.Enabled) {
                    if ($child.HandleInput($keyInfo)) {
                        Write-Verbose "Panel '$($this.Name)': Child '$($child.Name)' handled input."
                        return $true # Child handled the input
                    }
                }
            }
            Write-Verbose "Panel '$($this.Name)': Did not handle input. Key: $($keyInfo.Key)."
        }
        catch {
            Write-Error "Panel '$($this.Name)': Error handling input (Key: $($keyInfo.Key)): $($_.Exception.Message)"
            throw # Re-throw for Invoke-WithErrorHandling
        }
        return $false # Input not handled by panel or its children
    }

    # ToString: Provides a human-readable string representation for debugging.
    [string] ToString() {
        return "Panel(Name='$($this.Name)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height), HasBorder=$($this.HasBorder), Children=$($this.Children.Count))"
    }
}
#endregion

#region Specialized Panel Types

# ScrollablePanel: A panel that supports scrolling its content.
class ScrollablePanel : Panel {
    [ValidateRange(0, [int]::MaxValue)][int] $ScrollX = 0 # Horizontal scroll offset
    [ValidateRange(0, [int]::MaxValue)][int] $ScrollY = 0 # Vertical scroll offset
    [ValidateRange(0, [int]::MaxValue)][int] $VirtualWidth = 0 # Total width of content, possibly larger than panel's width
    [ValidateRange(0, [int]::MaxValue)][int] $VirtualHeight = 0 # Total height of content, possibly larger than panel's height
    [bool] $ShowScrollbars = $true # Whether to display scrollbar indicators
    
    hidden [TuiBuffer] $_virtual_buffer = $null # Buffer holding the entire virtual (scrollable) content

    # Default constructor.
    ScrollablePanel() : base() {
        $this.Name = "ScrollablePanel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $true # Scrollable panels are typically focusable
        $this.CanFocus = $true
        Write-Verbose "ScrollablePanel: Default constructor called for '$($this.Name)'."
    }

    # Constructor with position and size.
    ScrollablePanel(
        [Parameter(Mandatory)][int]$x,
        [Parameter(Mandatory)][int]$y,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$width,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$height
    ) : base($x, $y, $width, $height) {
        $this.Name = "ScrollablePanel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $true
        $this.CanFocus = $true
        Write-Verbose "ScrollablePanel: Constructor with dimensions called for '$($this.Name)'."
    }

    # SetVirtualSize: Sets the total "virtual" size of the content, which might be larger than the panel's visible area.
    # This determines the scrollable range.
    [void] SetVirtualSize(
        [Parameter(Mandatory)][ValidateRange(0, [int]::MaxValue)][int]$width,
        [Parameter(Mandatory)][ValidateRange(0, [int]::MaxValue)][int]$height
    ) {
        try {
            if ($this.VirtualWidth -eq $width -and $this.VirtualHeight -eq $height) {
                Write-Verbose "ScrollablePanel '$($this.Name)': Virtual size already set to $($width)x$($height). No change."
                return # No change needed
            }
            $this.VirtualWidth = $width
            $this.VirtualHeight = $height
            
            # Recreate or resize the virtual buffer to match the new virtual size.
            if ($width -gt 0 -and $height -gt 0) {
                if ($null -ne $this._virtual_buffer -and $this._virtual_buffer.Width -eq $width -and $this._virtual_buffer.Height -eq $height) {
                    Write-Verbose "ScrollablePanel '$($this.Name)': Virtual buffer already correct size."
                } else {
                    $this._virtual_buffer = [TuiBuffer]::new($width, $height, "$($this.Name).Virtual")
                    Write-Verbose "ScrollablePanel '$($this.Name)': Virtual buffer re-initialized to $($width)x$($height)."
                }
            } else {
                $this._virtual_buffer = $null # Clear virtual buffer if dimensions are zero
                Write-Verbose "ScrollablePanel '$($this.Name)': Virtual size set to 0, clearing virtual buffer."
            }
            
            # Adjust scroll position to be within new bounds.
            $this.ScrollTo($this.ScrollX, $this.ScrollY)
            $this.RequestRedraw()
            Write-Verbose "ScrollablePanel '$($this.Name)': Virtual size set to $($width)x$($height)."
        }
        catch {
            Write-Error "ScrollablePanel '$($this.Name)': Error setting virtual size to $($width)x$($height): $($_.Exception.Message)"
            throw
        }
    }

    # ScrollTo: Sets the current scroll offset.
    # The scroll position is clamped to valid ranges based on virtual and content size.
    [void] ScrollTo([Parameter(Mandatory)][int]$x, [Parameter(Mandatory)][int]$y) {
        $maxScrollX = [Math]::Max(0, $this.VirtualWidth - $this.ContentWidth)
        $maxScrollY = [Math]::Max(0, $this.VirtualHeight - $this.ContentHeight)
        
        $newScrollX = [Math]::Max(0, [Math]::Min($x, $maxScrollX))
        $newScrollY = [Math]::Max(0, [Math]::Min($y, $maxScrollY))

        if ($this.ScrollX -eq $newScrollX -and $this.ScrollY -eq $newScrollY) {
            Write-Verbose "ScrollablePanel '$($this.Name)': Scroll position already at ($newScrollX, $newScrollY). No change."
            return # No change needed
        }

        $this.ScrollX = $newScrollX
        $this.ScrollY = $newScrollY
        $this.RequestRedraw()
        Write-Verbose "ScrollablePanel '$($this.Name)': Scrolled to ($($this.ScrollX), $($this.ScrollY))."
    }

    # ScrollBy: Adjusts the scroll offset by a delta.
    [void] ScrollBy([Parameter(Mandatory)][int]$deltaX, [Parameter(Mandatory)][int]$deltaY) {
        $this.ScrollTo($this.ScrollX + $deltaX, $this.ScrollY + $deltaY)
        Write-Verbose "ScrollablePanel '$($this.Name)': Scrolled by ($deltaX, $deltaY)."
    }

    # HandleInput: Overrides Panel's method to process scrolling-related key presses.
    [bool] HandleInput([Parameter(Mandatory)][System.ConsoleKeyInfo]$keyInfo) {
        try {
            ([Panel]$this).HandleInput($keyInfo) # Call base Panel method for focus/child delegation

            if ($this.IsFocused) {
                switch ($keyInfo.Key) {
                    ([ConsoleKey]::UpArrow) { $this.ScrollBy(0, -1); return $true }
                    ([ConsoleKey]::DownArrow) { $this.ScrollBy(0, 1); return $true }
                    ([ConsoleKey]::LeftArrow) { $this.ScrollBy(-1, 0); return $true }
                    ([ConsoleKey]::RightArrow) { $this.ScrollBy(1, 0); return $true }
                    ([ConsoleKey]::PageUp) { $this.ScrollBy(0, -$this.ContentHeight); return $true }
                    ([ConsoleKey]::PageDown) { $this.ScrollBy(0, $this.ContentHeight); return $true }
                    ([ConsoleKey]::Home) { $this.ScrollTo(0, 0); return $true }
                    ([ConsoleKey]::End) { $this.ScrollTo(0, $this.VirtualHeight); return $true } # Scroll to bottom of virtual content
                }
            }
            Write-Verbose "ScrollablePanel '$($this.Name)': Did not handle input. Key: $($keyInfo.Key)."
        }
        catch {
            Write-Error "ScrollablePanel '$($this.Name)': Error handling input (Key: $($keyInfo.Key)): $($_.Exception.Message)"
            throw
        }
        return $false # Input not handled by this panel
    }

    # OnRender: Overrides Panel's method to render virtual content and scrollbars.
    [void] OnRender() {
        # Call base Panel's OnRender to draw border and background.
        ([Panel]$this).OnRender()
        Write-Verbose "ScrollablePanel '$($this.Name)': Base Panel OnRender completed."

        # If a virtual buffer exists, get the visible portion and blend it onto the panel's buffer.
        if ($null -ne $this._virtual_buffer -and $this.ContentWidth -gt 0 -and $this.ContentHeight -gt 0) {
            # GetSubBuffer automatically clips to its requested dimensions.
            $visibleBuffer = $this._virtual_buffer.GetSubBuffer($this.ScrollX, $this.ScrollY, $this.ContentWidth, $this.ContentHeight)
            # Blend the visible part of the virtual buffer into the panel's content area.
            $this._private_buffer.BlendBuffer($visibleBuffer, $this.ContentX, $this.ContentY)
            Write-Verbose "ScrollablePanel '$($this.Name)': Blended virtual content."
        } else {
            Write-Verbose "ScrollablePanel '$($this.Name)': No virtual content to blend or content area is zero."
        }

        # Draw scrollbars if enabled and if content exceeds visible area.
        if ($this.ShowScrollbars -and $this.HasBorder) {
            $this.DrawScrollbars()
            Write-Verbose "ScrollablePanel '$($this.Name)': Scrollbars drawn."
        }
    }

    # DrawScrollbars: Draws horizontal and/or vertical scrollbars on the panel's border area.
    hidden [void] DrawScrollbars() {
        if ($null -eq $this._private_buffer) { return } # Should not be null if OnRender called
        
        # Vertical Scrollbar
        if ($this.VirtualHeight -gt $this.ContentHeight -and $this.Width -gt 1) { # Only draw if scrollable vertically and enough width for border
            $scrollbarX = $this.Width - 1 # Rightmost column of the panel
            $scrollbarTrackHeight = $this.Height - 2 # Exclude top/bottom borders of panel
            
            # Calculate thumb position relative to the scrollbar track height
            $scrollRatioY = ($this.ScrollY / [Math]::Max(1, $this.VirtualHeight - $this.ContentHeight))
            $thumbPositionInTrack = [Math]::Floor($scrollRatioY * ($scrollbarTrackHeight - 1))
            
            for ($y = 1; $y -lt ($this.Height - 1); $y++) { # Iterate along the vertical track (excluding panel corners)
                $char = if ($y -eq ($thumbPositionInTrack + 1)) { '█' } else { '▒' } # Thumb character vs. track character
                $cell = [TuiCell]::new($char, (Get-ThemeColor 'Subtle'), $this.BackgroundColor)
                $this._private_buffer.SetCell($scrollbarX, $y, $cell)
            }
            Write-Verbose "ScrollablePanel '$($this.Name)': Vertical scrollbar drawn."
        }

        # Horizontal Scrollbar
        if ($this.VirtualWidth -gt $this.ContentWidth -and $this.Height -gt 1) { # Only draw if scrollable horizontally and enough height for border
            $scrollbarY = $this.Height - 1 # Bottommost row of the panel
            $scrollbarTrackWidth = $this.Width - 2 # Exclude left/right borders of panel
            
            # Calculate thumb position relative to the scrollbar track width
            $scrollRatioX = ($this.ScrollX / [Math]::Max(1, $this.VirtualWidth - $this.ContentWidth))
            $thumbPositionInTrack = [Math]::Floor($scrollRatioX * ($scrollbarTrackWidth - 1))
            
            for ($x = 1; $x -lt ($this.Width - 1); $x++) { # Iterate along the horizontal track (excluding panel corners)
                $char = if ($x -eq ($thumbPositionInTrack + 1)) { '█' } else { '▒' }
                $cell = [TuiCell]::new($char, (Get-ThemeColor 'Subtle'), $this.BackgroundColor)
                $this._private_buffer.SetCell($x, $scrollbarY, $cell)
            }
            Write-Verbose "ScrollablePanel '$($this.Name)': Horizontal scrollbar drawn."
        }
    }

    # GetVirtualBuffer: Returns the internal buffer that holds the entire scrollable content.
    # This allows external code to draw directly onto the virtual content.
    [TuiBuffer] GetVirtualBuffer() {
        return $this._virtual_buffer
    }

    # ToString: Provides a human-readable string representation for debugging.
    [string] ToString() {
        return "ScrollablePanel(Name='$($this.Name)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height), VirtualSize=$($this.VirtualWidth)x$($this.VirtualHeight), Scroll=($($this.ScrollX),$($this.ScrollY)))"
    }
}

# GroupPanel: A specialized panel that can be collapsed/expanded.
class GroupPanel : Panel {
    [bool] $IsCollapsed = $false         # Current state of the panel
    [ValidateRange(1, [int]::MaxValue)][int] $ExpandedHeight = 0 # Height when expanded
    [int] $HeaderHeight = 1              # Height of the header (title bar part)
    [ConsoleColor] $HeaderColor = [ConsoleColor]::DarkBlue # Color of the header (e.g., indicator)
    [string] $CollapseChar = "▼"         # Character displayed when expanded, allows collapsing
    [string] $ExpandChar = "▶"           # Character displayed when collapsed, allows expanding

    # Default constructor.
    GroupPanel() : base() {
        $this.Name = "GroupPanel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $true
        $this.CanFocus = $true
        $this.ExpandedHeight = $this.Height # Initial height is the expanded height
        Write-Verbose "GroupPanel: Default constructor called for '$($this.Name)'."
    }

    # Constructor with position, size, and title.
    GroupPanel(
        [Parameter(Mandatory)][int]$x,
        [Parameter(Mandatory)][int]$y,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$width,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$height,
        [Parameter(Mandatory)][string]$title
    ) : base($x, $y, $width, $height, $title) {
        $this.Name = "GroupPanel_$(Get-Random -Maximum 1000)"
        $this.IsFocusable = $true
        $this.CanFocus = $true
        $this.ExpandedHeight = $height # Initial height is the expanded height
        Write-Verbose "GroupPanel: Constructor with dimensions and title called for '$($this.Name)' ('$title')."
    }

    # ToggleCollapsed: Toggles the collapsed state of the panel.
    [void] ToggleCollapsed() {
        try {
            $this.IsCollapsed = -not $this.IsCollapsed
            if ($this.IsCollapsed) {
                # Save current height as expanded height before collapsing.
                $this.ExpandedHeight = $this.Height
                $this.Resize($this.Width, [Math]::Max(1, $this.HeaderHeight + 2)) # Resize to header + borders
                Write-Verbose "GroupPanel '$($this.Name)': Collapsed. Resized to $($this.Width)x$($this.Height)."
            } else {
                # Restore to saved expanded height.
                $this.Resize($this.Width, [Math]::Max(1, $this.ExpandedHeight))
                Write-Verbose "GroupPanel '$($this.Name)': Expanded. Resized to $($this.Width)x$($this.Height)."
            }
            
            # Update visibility of all children based on collapsed state.
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

    # HandleInput: Overrides Panel's method to handle Enter/Spacebar for toggling collapse.
    [bool] HandleInput([Parameter(Mandatory)][System.ConsoleKeyInfo]$keyInfo) {
        try {
            ([Panel]$this).HandleInput($keyInfo) # Call base Panel method for focus/child delegation

            if ($this.IsFocused) {
                switch ($keyInfo.Key) {
                    ([ConsoleKey]::Enter) { $this.ToggleCollapsed(); return $true }
                    ([ConsoleKey]::Spacebar) { $this.ToggleCollapsed(); return $true }
                }
            }
            
            # Only delegate input to children if the panel is not collapsed.
            if (-not $this.IsCollapsed) {
                Write-Verbose "GroupPanel '$($this.Name)': Not collapsed, delegating input to children."
                return ([Panel]$this).HandleInput($keyInfo) # Re-call base to delegate to children
            }
            Write-Verbose "GroupPanel '$($this.Name)': Did not handle input. Key: $($keyInfo.Key)."
        }
        catch {
            Write-Error "GroupPanel '$($this.Name)': Error handling input (Key: $($keyInfo.Key)): $($_.Exception.Message)"
            throw
        }
        return $false
    }

    # OnRender: Overrides Panel's method to draw the collapse/expand indicator.
    [void] OnRender() {
        # Call base Panel's OnRender to draw border and background.
        ([Panel]$this).OnRender()
        Write-Verbose "GroupPanel '$($this.Name)': Base Panel OnRender completed."

        # Draw the collapse/expand indicator character on the top border.
        if ($this.HasBorder -and -not [string]::IsNullOrEmpty($this.Title)) {
            $indicator = if ($this.IsCollapsed) { $this.ExpandChar } else { $this.CollapseChar }
            $indicatorCell = [TuiCell]::new($indicator, $this.TitleColor, $this.BackgroundColor)
            
            # Position indicator after a few spaces on the left, ensuring it's within bounds
            if (3 -lt ($this.Width - 1)) {
                $this._private_buffer.SetCell(2, 0, $indicatorCell)
                Write-Verbose "GroupPanel '$($this.Name)': Indicator '$indicator' drawn."
            }
        }
    }

    # ToString: Provides a human-readable string representation for debugging.
    [string] ToString() {
        return "GroupPanel(Name='$($this.Name)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height), Collapsed=$($this.IsCollapsed))"
    }
}
#endregion

#region Module Exports

# Export all public classes from this module.
Export-ModuleMember -Class Panel, ScrollablePanel, GroupPanel

#endregion
