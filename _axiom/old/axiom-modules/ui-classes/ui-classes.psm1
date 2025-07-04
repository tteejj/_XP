# ==============================================================================
# PMC Terminal v5 - Base UI Class Hierarchy
# Provides the foundational classes for all UI components with NCurses compositor support.
# ==============================================================================

# --- Enhanced UI Element with Buffer Management ---
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
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
    }

    # Constructor with name
    UIElement([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [ArgumentException]::new("UIElement name cannot be null or empty.")
        }
        $this.Name = $name
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
    }

    # Constructor with position and size
    UIElement([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($width, $height, "$($this.Name).Buffer")
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
        $this._needs_redraw = $true
        if ($null -ne $this.Parent) {
            $this.Parent.RequestRedraw()
        }
    }

    # Resize the component and its buffer
    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0 -or $newHeight -le 0) { return }

        $this.Width = $newWidth
        $this.Height = $newHeight

        if ($null -ne $this._private_buffer) {
            $this._private_buffer.Resize($newWidth, $newHeight)
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
        if ($null -ne $this._private_buffer) {
            $this._private_buffer.Clear()
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
        if (-not $this.Visible) { return }
        
        try {
            $this._RenderContent()
        }
        catch {
            # Simple error handling without logger dependency
            Write-Host "Error rendering component $($this.Name): $_" -ForegroundColor Red
            throw
        }
    }

    # Protected render implementation - can be overridden by subclasses
    hidden [void] _RenderContent() {
        if (-not $this.Visible) { return }

        # Render this component to its private buffer
        if ($this._needs_redraw -or ($null -eq $this._private_buffer)) {
            if ($null -eq $this._private_buffer) {
                $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
            }

            $this.OnRender()
            $this._needs_redraw = $false
        }

        # Render children to their buffers, then composite onto parent
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $child.Render()

                # Composite child's buffer onto this component's buffer
                if ($null -ne $child._private_buffer) {
                    $this._private_buffer.BlendBuffer($child._private_buffer, $child.X, $child.Y)
                }
            }
        }
    }

    # Get the final rendered buffer
    [TuiBuffer] GetBuffer() {
        return $this._private_buffer
    }

    [string] ToString() {
        return "$($this.GetType().Name): $($this.Name)"
    }
}

# --- Base Component (can contain children) ---
class Component : UIElement {
    Component([string]$name) : base($name) {
    }

    # Default implementation renders all visible children to buffer
    hidden [void] _RenderContent() {
        # Call parent implementation for buffer management
        ([UIElement]$this)._RenderContent()
    }
}

# Note: Panel class is now defined in layout\panels-class.psm1

# --- Base Screen (top-level container) ---
class Screen : UIElement {
    [hashtable]$Services
    [object]$ServiceContainer  # Can be ServiceContainer or null
    [System.Collections.Generic.Dictionary[string, object]]$State
    [System.Collections.Generic.List[UIElement]]$Panels
    [UIElement]$LastFocusedComponent
    hidden [System.Collections.Generic.Dictionary[string, string]]$EventSubscriptions

    # Constructor with hashtable services (backward compatibility)
    Screen([string]$name, [hashtable]$services) : base($name) {
        if (-not $services) { throw [ArgumentNullException]::new("services") }

        $this.Services = $services
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        $this.ServiceContainer = $null
    }

    # Constructor with ServiceContainer (new DI approach)
    Screen([string]$name, [object]$serviceContainer) : base($name) {
        if (-not $serviceContainer) { throw [ArgumentNullException]::new("serviceContainer") }

        $this.ServiceContainer = $serviceContainer
        # Create services hashtable from container for backward compatibility
        $this.Services = @{}
        foreach ($serviceName in $serviceContainer.GetRegisteredServices()) {
            $this.Services[$serviceName] = $serviceContainer.Resolve($serviceName)
        }

        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
    }

    [void] Initialize() { }
    [void] OnEnter() { }
    [void] OnExit() { }
    [void] OnResume() { }
    [void] HandleInput([System.ConsoleKeyInfo]$key) { }

    [void] Cleanup() {
        # Event cleanup handled by screen implementations
        $this.EventSubscriptions.Clear()
        $this.Panels.Clear()
    }

    [void] AddPanel([UIElement]$panel) {
        if (-not $panel) { throw [ArgumentNullException]::new("panel") }
        $this.Panels.Add($panel)
    }

    [void] SubscribeToEvent([string]$eventName, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($eventName)) { throw [ArgumentException]::new("Event name cannot be null or empty.") }
        if (-not $action) { throw [ArgumentNullException]::new("action") }

        # Store subscription info - actual subscription handled by implementations
        $subscriptionId = [Guid]::NewGuid().ToString()
        $this.EventSubscriptions[$eventName] = $subscriptionId
    }

    # Override _RenderContent to render all panels to buffer
    hidden [void] _RenderContent() {
        # Call base implementation for buffer management
        ([UIElement]$this)._RenderContent()

        # Render all panels in the screen to the back-buffer
        foreach ($panel in $this.Panels) {
            if ($panel.Visible) {
                $panel.Render()
            }
        }
    }
}

# Export nothing - classes are automatically exported in PowerShell
