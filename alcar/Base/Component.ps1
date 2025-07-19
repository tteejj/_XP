# Component - Enhanced base class for UI components
# Minimal overhead while providing better architecture

class Component {
    [string]$Name
    [int]$X = 0
    [int]$Y = 0
    [int]$Width = 10
    [int]$Height = 1
    [bool]$Visible = $true
    [bool]$IsFocusable = $false
    [bool]$IsFocused = $false
    
    # Performance optimization flags
    hidden [bool]$_needsRedraw = $true
    hidden [hashtable]$_renderCache = @{}
    hidden [int]$_lastWidth = -1
    hidden [int]$_lastHeight = -1
    
    # Component lifecycle hooks
    [scriptblock]$OnMount = $null
    [scriptblock]$OnUnmount = $null
    [scriptblock]$OnFocus = $null
    [scriptblock]$OnBlur = $null
    
    Component([string]$name) {
        $this.Name = $name
    }
    
    # Check if component needs redrawing
    [bool] NeedsRedraw() {
        return $this._needsRedraw -or 
               $this._lastWidth -ne $this.Width -or 
               $this._lastHeight -ne $this.Height
    }
    
    # Mark component for redraw
    [void] Invalidate() {
        $this._needsRedraw = $true
        $this._renderCache.Clear()
    }
    
    # Base render method to be overridden
    [void] Render([object]$buffer) {
        if (-not $this.Visible) { return }
        
        # Update size tracking
        $this._lastWidth = $this.Width
        $this._lastHeight = $this.Height
        
        # Call derived class render
        $this.OnRender($buffer)
        
        # Mark as rendered
        $this._needsRedraw = $false
    }
    
    # Override in derived classes
    [void] OnRender([object]$buffer) {
        # Base implementation does nothing
    }
    
    # Lifecycle methods
    [void] Mount() {
        if ($this.OnMount) {
            & $this.OnMount $this
        }
    }
    
    [void] Unmount() {
        if ($this.OnUnmount) {
            & $this.OnUnmount $this
        }
    }
    
    [void] Focus() {
        if ($this.IsFocusable) {
            $this.IsFocused = $true
            $this.Invalidate()
            if ($this.OnFocus) {
                & $this.OnFocus $this
            }
        }
    }
    
    [void] Blur() {
        if ($this.IsFocused) {
            $this.IsFocused = $false
            $this.Invalidate()
            if ($this.OnBlur) {
                & $this.OnBlur $this
            }
        }
    }
    
    # Input handling - override in derived classes
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $false
    }
    
    # Helper method for bounds checking
    [bool] IsInBounds([int]$x, [int]$y) {
        return $x -ge $this.X -and 
               $x -lt ($this.X + $this.Width) -and
               $y -ge $this.Y -and 
               $y -lt ($this.Y + $this.Height)
    }
}

# Container component for managing child components
class Container : Component {
    hidden [System.Collections.ArrayList]$Children = [System.Collections.ArrayList]::new()
    hidden [int]$FocusedChildIndex = -1
    
    Container([string]$name) : base($name) {
    }
    
    [void] AddChild([Component]$child) {
        $this.Children.Add($child) | Out-Null
        $child.Mount()
        $this.Invalidate()
    }
    
    [void] RemoveChild([Component]$child) {
        $child.Unmount()
        $this.Children.Remove($child)
        $this.Invalidate()
    }
    
    [void] OnRender([object]$buffer) {
        # Render children
        foreach ($child in $this.Children) {
            if ($child.Visible -and $child.NeedsRedraw()) {
                # Create sub-buffer for child
                $childBuffer = [Buffer]::new($child.Width, $child.Height)
                $child.Render($childBuffer)
                
                # Copy child buffer to parent buffer at child position
                for ($y = 0; $y -lt $child.Height; $y++) {
                    for ($x = 0; $x -lt $child.Width; $x++) {
                        $cell = $childBuffer.GetCell($x, $y)
                        if ($cell) {
                            $buffer.SetCell($this.X + $child.X + $x, $this.Y + $child.Y + $y, $cell)
                        }
                    }
                }
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Route input to focused child
        if ($this.FocusedChildIndex -ge 0 -and $this.FocusedChildIndex -lt $this.Children.Count) {
            $focusedChild = $this.Children[$this.FocusedChildIndex]
            if ($focusedChild.HandleInput($key)) {
                return $true
            }
        }
        
        # Handle tab navigation between focusable children
        if ($key.Key -eq [ConsoleKey]::Tab) {
            return $this.FocusNextChild($key.Modifiers -band [ConsoleModifiers]::Shift)
        }
        
        return $false
    }
    
    [bool] FocusNextChild([bool]$reverse = $false) {
        $focusableChildren = @()
        for ($i = 0; $i -lt $this.Children.Count; $i++) {
            if ($this.Children[$i].IsFocusable) {
                $focusableChildren += $i
            }
        }
        
        if ($focusableChildren.Count -eq 0) { return $false }
        
        # Blur current child
        if ($this.FocusedChildIndex -ge 0) {
            $this.Children[$this.FocusedChildIndex].Blur()
        }
        
        # Find next focusable child
        $currentIndex = [Array]::IndexOf($focusableChildren, $this.FocusedChildIndex)
        if ($reverse) {
            $currentIndex--
            if ($currentIndex -lt 0) { $currentIndex = $focusableChildren.Count - 1 }
        } else {
            $currentIndex++
            if ($currentIndex -ge $focusableChildren.Count) { $currentIndex = 0 }
        }
        
        $this.FocusedChildIndex = $focusableChildren[$currentIndex]
        $this.Children[$this.FocusedChildIndex].Focus()
        
        return $true
    }
}