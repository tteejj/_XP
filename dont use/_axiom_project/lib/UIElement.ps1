class UIElement {
    [string] $Name = ""
    [int] $X = 0
    [int] $Y = 0
    [int] $Width = 10
    [int] $Height = 3
    [bool] $Visible = $true
    [bool] $Enabled = $true
    [bool] $IsFocusable = $false
    [bool] $IsFocused = $false
    [int] $TabIndex = 0
    [int] $ZIndex = 0
    [UIElement] $Parent = $null
    [System.Collections.Generic.List[UIElement]] $Children
    [TuiBuffer] $_private_buffer = $null
    [bool] $_needs_redraw = $true
    [hashtable] $Metadata = @{}

    # Constructor
    UIElement() {
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this.{_private_buffer} = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
    }

    # Constructor with name
    UIElement([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [ArgumentException]::new("UIElement name cannot be null or empty.")
        }
        $this.Name = $name
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this.{_private_buffer} = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
    }

    # Constructor with position and size
    UIElement([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this.{_private_buffer} = [TuiBuffer]::new($width, $height, "$($this.Name).Buffer")
    }

    # Get absolute screen position
    [hashtable] GetAbsolutePosition() {
        $absX = $this.X
        $absY = $this.Y
        $current = $this.Parent
        
        while ($null -ne $current) {
            $absX += $current.X
            $absY += $current.Y
            $current = $current.Parent
        }
        
        return @{ X = $absX; Y = $absY }
    }

    # Add child component
    [void] AddChild([UIElement]$child) {
        if ($null -ne $child) {
            $child.Parent = $this
            $this.Children.Add($child)
            $this.RequestRedraw()
        }
    }

    # Remove child component
    [void] RemoveChild([UIElement]$child) {
        if ($null -ne $child) {
            $child.Parent = $null
            [void]$this.Children.Remove($child)
            $this.RequestRedraw()
        }
    }

    # Request redraw for this component and parents
    [void] RequestRedraw() {
        $this.{_needs_redraw} = $true
        if ($null -ne $this.Parent) {
            $this.Parent.RequestRedraw()
        }
    }

    # Resize the component and its buffer
    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0 -or $newHeight -le 0) { return }
        
        $this.Width = $newWidth
        $this.Height = $newHeight
        
        if ($null -ne $this.{_private_buffer}) {
            $this.{_private_buffer}.Resize($newWidth, $newHeight)
        }
        
        $this.RequestRedraw()
        $this.OnResize($newWidth, $newHeight)
    }

    # Move the component
    [void] Move([int]$newX, [int]$newY) {
        $this.X = $newX
        $this.Y = $newY
        $this.RequestRedraw()
        $this.OnMove($newX, $newY)
    }

    # Check if point is within component bounds
    [bool] ContainsPoint([int]$x, [int]$y) {
        return ($x -ge $this.X -and $x -lt ($this.X + $this.Width) -and 
                $y -ge $this.Y -and $y -lt ($this.Y + $this.Height))
    }

    # Get child at specific point (relative to this component)
    [UIElement] GetChildAtPoint([int]$x, [int]$y) {
        for ($i = $this.Children.Count - 1; $i -ge 0; $i--) {
            $child = $this.Children[$i]
            if ($child.Visible -and $child.ContainsPoint($x - $this.X, $y - $this.Y)) {
                return $child
            }
        }
        return $null
    }

    # Virtual methods for subclasses to override
    [void] OnRender() {
        # Default implementation - clear buffer
        if ($null -ne $this.{_private_buffer}) {
            $this.{_private_buffer}.Clear()
        }
    }

    [void] OnResize([int]$newWidth, [int]$newHeight) {
        # Override in subclasses
    }

    [void] OnMove([int]$newX, [int]$newY) {
        # Override in subclasses
    }

    [void] OnFocus() {
        # Override in subclasses
    }

    [void] OnBlur() {
        # Override in subclasses
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Override in subclasses - return true if input was handled
        return $false
    }

    # Main render method with error handling - calls _RenderContent and renders children
    [void] Render() {
        Invoke-WithErrorHandling -Component $this.Name -Context "Render" -ScriptBlock {
            if (-not $this.Visible) { return }
            $this._RenderContent()
        } -AdditionalData @{ ComponentType = $this.GetType().Name }
    }

    # Protected render implementation - can be overridden by subclasses
    hidden [void] _RenderContent() {
        if (-not $this.Visible) { return }

        # Render this component to its private buffer
        if ($this.{_needs_redraw} -or ($null -eq $this.{_private_buffer})) {
            if ($null -eq $this.{_private_buffer}) {
                $this.{_private_buffer} = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
            }
            
            $this.OnRender()
            $this.{_needs_redraw} = $false
        }

        # Render children to their buffers, then composite onto parent
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $child.Render()
                
                # Composite child's buffer onto this component's buffer
                if ($null -ne $child.{_private_buffer}) {
                    $this.{_private_buffer}.BlendBuffer($child.{_private_buffer}, $child.X, $child.Y)
                }
            }
        }
    }

    # Get the final rendered buffer
    [TuiBuffer] GetBuffer() {
        return $this.{_private_buffer}
    }
    
    [string] ToString() {
        return "$($this.GetType().Name): $($this.Name)"
    }
}
