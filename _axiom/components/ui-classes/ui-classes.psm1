#using module 'tui-primitives'
# ==============================================================================
# PMC Terminal v5 - Base UI Class Hierarchy
# Provides the foundational classes for all UI components with NCurses compositor support.
# ==============================================================================

#region UIElement - Base Class for all UI Components
class UIElement {
    [string] $Name = "UIElement" 
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
    
    hidden [TuiBuffer] $_private_buffer = $null
    hidden [bool] $_needs_redraw = $true
    
    [hashtable] $Metadata = @{} 

    UIElement() {
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        Write-Verbose "UIElement 'Unnamed' created with default size ($($this.Width)x$($this.Height))."
    }

    UIElement([string]$name) {
        $this.Name = $name
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        Write-Verbose "UIElement '$($this.Name)' created with default size ($($this.Width)x$($this.Height))."
    }

    UIElement([int]$x, [int]$y, [int]$width, [int]$height) {
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($width, $height, "Unnamed.Buffer")
        Write-Verbose "UIElement 'Unnamed' created at ($x, $y) with dimensions $($width)x$($height)."
    }

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

    # FIX: Removed the [UIElement] type hint from the $child parameter
    # to prevent cross-module type conversion errors.
    [void] AddChild([object]$child) {
        try {
            if ($child -eq $this) { throw [System.ArgumentException]::new("Cannot add an element as its own child.") }
            if ($this.Children.Contains($child)) {
                Write-Warning "Child '$($child.Name)' is already a child of '$($this.Name)'. Skipping addition."
                return
            }
            if ($child.Parent -ne $null) {
                Write-Warning "Child '$($child.Name)' already has a parent ('$($child.Parent.Name)'). Consider removing it from its current parent first."
            }
            $child.Parent = $this
            $this.Children.Add($child)
            $this.RequestRedraw()
            Write-Verbose "Added child '$($child.Name)' to parent '$($this.Name)'."
        }
        catch {
            Write-Error "Failed to add child '$($child.Name)' to '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    # FIX: Removed the [UIElement] type hint from the $child parameter
    # to prevent cross-module type conversion errors.
    [void] RemoveChild([object]$child) {
        try {
            if ($this.Children.Remove($child)) {
                $child.Parent = $null
                $this.RequestRedraw()
                Write-Verbose "Removed child '$($child.Name)' from parent '$($this.Name)'."
            } else {
                Write-Warning "Child '$($child.Name)' not found in parent '$($this.Name)' for removal. No action taken."
            }
        }
        catch {
            Write-Error "Failed to remove child '$($child.Name)' from '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    [void] RequestRedraw() {
        $this._needs_redraw = $true
        if ($null -ne $this.Parent) {
            $this.Parent.RequestRedraw()
        }
        Write-Verbose "Redraw requested for '$($this.Name)'."
    }

    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0) { throw [System.ArgumentOutOfRangeException]::new("newWidth", "New width must be positive.") }
        if ($newHeight -le 0) { throw [System.ArgumentOutOfRangeException]::new("newHeight", "New height must be positive.") }
        try {
            if ($this.Width -eq $newWidth -and $this.Height -eq $newHeight) {
                Write-Verbose "Resize: Component '$($this.Name)' already has target dimensions ($($newWidth)x$($newHeight)). No change."
                return
            }
            $this.Width = $newWidth
            $this.Height = $newHeight
            if ($null -ne $this._private_buffer) {
                $this._private_buffer.Resize($newWidth, $newHeight)
            } else {
                $this._private_buffer = [TuiBuffer]::new($newWidth, $newHeight, "$($this.Name).Buffer")
                Write-Verbose "Re-initialized buffer for '$($this.Name)' due to null buffer."
            }
            $this.RequestRedraw()
            $this.OnResize($newWidth, $newHeight)
            Write-Verbose "Component '$($this.Name)' resized to $($newWidth)x$($newHeight)."
        }
        catch {
            Write-Error "Failed to resize component '$($this.Name)' to $($newWidth)x$($newHeight): $($_.Exception.Message)"
            throw
        }
    }

    [void] Move([int]$newX, [int]$newY) {
        if ($this.X -eq $newX -and $this.Y -eq $newY) {
            Write-Verbose "Move: Component '$($this.Name)' already at target position ($($newX), $($newY)). No change."
            return
        }
        $this.X = $newX
        $this.Y = $newY
        $this.RequestRedraw()
        $this.OnMove($newX, $newY)
        Write-Verbose "Component '$($this.Name)' moved to ($newX, $newY)."
    }

    [bool] ContainsPoint([int]$x, [int]$y) {
        return ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height)
    }

    # FIX: Removed the [UIElement] return type hint to prevent cross-module type conversion errors.
    [object] GetChildAtPoint([int]$x, [int]$y) {
        for ($i = $this.Children.Count - 1; $i -ge 0; $i--) {
            $child = $this.Children[$i]
            if ($child.Visible -and $child.ContainsPoint($x - $child.X, $y - $child.Y)) {
                return $child
            }
        }
        return $null
    }

    [void] OnRender() {
        if ($null -ne $this._private_buffer) {
            $this._private_buffer.Clear()
        }
        Write-Verbose "OnRender called for '$($this.Name)': Default buffer clear."
    }

    [void] OnResize([int]$newWidth, [int]$newHeight) {
        Write-Verbose "OnResize called for '$($this.Name)': No custom resize logic."
    }

    [void] OnMove([int]$newX, [int]$newY) {
        Write-Verbose "OnMove called for '$($this.Name)': No custom move logic."
    }

    [void] OnFocus() { Write-Verbose "OnFocus called for '$($this.Name)'." }
    [void] OnBlur() { Write-Verbose "OnBlur called for '$($this.Name)'." }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        Write-Verbose "HandleInput called for '$($this.Name)': Key: $($keyInfo.Key)."
        return $false
    }

    [void] Render() {
        if (-not $this.Visible) { 
            Write-Verbose "Skipping Render for '$($this.Name)': Not visible."
            return 
        }
        $this._RenderContent() 
    }

    hidden [void] _RenderContent() {
        if (-not $this.Visible) { return }
        if ($this._needs_redraw -or ($null -eq $this._private_buffer)) {
            if ($null -eq $this._private_buffer -or $this._private_buffer.Width -ne $this.Width -or $this._private_buffer.Height -ne $this.Height) {
                $bufferWidth = [Math]::Max(1, $this.Width)
                $bufferHeight = [Math]::Max(1, $this.Height)
                $this._private_buffer = [TuiBuffer]::new($bufferWidth, $bufferHeight, "$($this.Name).Buffer")
                Write-Verbose "Re-initialized buffer for '$($this.Name)' due to null or dimension mismatch ($($bufferWidth)x$($bufferHeight))."
            }
            $this.OnRender()
            $this._needs_redraw = $false
            Write-Verbose "Rendered own content for '$($this.Name)'."
        }
        foreach ($child in $this.Children | Sort-Object ZIndex) { 
            if ($child.Visible) {
                $child.Render()
                if ($null -ne $child._private_buffer) {
                    $this._private_buffer.BlendBuffer($child._private_buffer, $child.X, $child.Y)
                    Write-Verbose "Blended child '$($child.Name)' onto '$($this.Name)' at ($($child.X), $($child.Y))."
                }
            }
        }
    }

    [TuiBuffer] GetBuffer() { return $this._private_buffer }
    
    [string] ToString() {
        return "$($this.GetType().Name)(Name='$($this.Name)', X=$($this.X), Y=$($this.Y), Width=$($this.Width), Height=$($this.Height), Visible=$($this.Visible))"
    }
}
#endregion

#region Component - A generic container component
class Component : UIElement {
    Component([string]$name) : base($name) {
        $this.Name = $name
        Write-Verbose "Component '$($this.Name)' created."
    }

    hidden [void] _RenderContent() {
        ([UIElement]$this)._RenderContent()
        Write-Verbose "_RenderContent called for Component '$($this.Name)' (delegating to base UIElement)."
    }

    [string] ToString() {
        return "Component(Name='$($this.Name)', Children=$($this.Children.Count))"
    }
}
#endregion

#region Screen - Top-level Container for Application Views
class Screen : UIElement {
    [hashtable]$Services
    [object]$ServiceContainer 
    [System.Collections.Generic.Dictionary[string, object]]$State
    [System.Collections.Generic.List[UIElement]] $Panels
    
    # FIX: Removed the [UIElement] type hint to prevent cross-module conversion errors.
    $LastFocusedComponent
    
    hidden [System.Collections.Generic.Dictionary[string, string]] $EventSubscriptions 

    Screen([string]$name, [hashtable]$services) : base($name) {
        $this.Services = $services
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        $this.ServiceContainer = $null
        Write-Verbose "Screen '$($this.Name)' created with hashtable services."
    }

    Screen([string]$name, [object]$serviceContainer) : base($name) {
        $this.ServiceContainer = $serviceContainer
        $this.Services = [hashtable]::new()
        if ($this.ServiceContainer.PSObject.Methods['GetAllRegisteredServices'] -and $this.ServiceContainer.PSObject.Methods['GetService']) { 
            try {
                $registeredServices = $this.ServiceContainer.GetAllRegisteredServices()
                foreach ($service in $registeredServices) {
                    try {
                        $this.Services[$service.Name] = $this.ServiceContainer.GetService($service.Name)
                    } catch {
                        Write-Warning "Screen '$($this.Name)': Failed to resolve service '$($service.Name)' from container: $($_.Exception.Message)"
                    }
                }
                Write-Verbose "Screen '$($this.Name)' populated Services hashtable from ServiceContainer."
            } catch {
                Write-Warning "Screen '$($this.Name)': Failed to enumerate services from container: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Screen '$($this.Name)' received a non-ServiceContainer object for DI. Services hashtable might be incomplete or inaccurate."
        }
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        Write-Verbose "Screen '$($this.Name)' created with ServiceContainer."
    }

    [void] Initialize() { Write-Verbose "Initialize called for Screen '$($this.Name)': Default (no-op)." }
    [void] OnEnter() { Write-Verbose "OnEnter called for Screen '$($this.Name)': Default (no-op)." }
    [void] OnExit() { Write-Verbose "OnExit called for Screen '$($this.Name)': Default (no-op)." }
    [void] OnResume() { Write-Verbose "OnResume called for Screen '$($this.Name)': Default (no-op)." }

    [void] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        Write-Verbose "HandleInput called for Screen '$($this.Name)': Key: $($keyInfo.Key). Default (no-op)."
    }

    [void] Cleanup() {
        try {
            Write-Verbose "Cleanup called for Screen '$($this.Name)'."
            foreach ($kvp in $this.EventSubscriptions.GetEnumerator()) {
                try {
                    if (Get-Command 'Unsubscribe-Event' -ErrorAction SilentlyContinue) {
                        Unsubscribe-Event -EventName $kvp.Key -HandlerId $kvp.Value
                        Write-Verbose "Unsubscribed event '$($kvp.Key)' (HandlerId: $($kvp.Value)) for screen '$($this.Name)'."
                    }
                }
                catch {
                    Write-Warning "Failed to unsubscribe event '$($kvp.Key)' (HandlerId: $($kvp.Value)) for screen '$($this.Name)': $($_.Exception.Message)"
                }
            }
            $this.EventSubscriptions.Clear()
            foreach ($child in $this.Children) {
                if ($child.PSObject.Methods['Cleanup']) {
                    try { $child.Cleanup() } catch { Write-Warning "Failed to cleanup child '$($child.Name)': $($_.Exception.Message)" }
                }
            }
            $this.Panels.Clear()
            $this.Children.Clear()
            Write-Verbose "Cleaned up resources for screen: $($this.Name)."
        }
        catch {
            Write-Error "Error during Cleanup for screen '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    # FIX: Removed the [UIElement] type hint from the $panel parameter
    # to prevent cross-module type conversion errors.
    [void] AddPanel([object]$panel) {
        try {
            $this.Panels.Add($panel)
            $this.AddChild($panel) 
            Write-Verbose "Added panel '$($panel.Name)' to screen '$($this.Name)'."
        }
        catch {
            Write-Error "Failed to add panel '$($panel.Name)' to screen '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    [void] SubscribeToEvent([string]$eventName, [scriptblock]$action) {
        try {
            if (Get-Command 'Subscribe-Event' -ErrorAction SilentlyContinue) {
                $subscriptionId = Subscribe-Event -EventName $eventName -Handler $action -Source $this.Name
                $this.EventSubscriptions[$eventName] = $subscriptionId
                Write-Verbose "Screen '$($this.Name)' subscribed to event '$eventName' with HandlerId: $subscriptionId."
            } else {
                Write-Warning "Subscribe-Event function not available. Event subscription for '$eventName' failed."
            }
        }
        catch {
            Write-Error "Failed for screen '$($this.Name)' to subscribe to event '$eventName': $($_.Exception.Message)"
            throw
        }
    }
    
    hidden [void] _RenderContent() {
        ([UIElement]$this)._RenderContent()
        Write-Verbose "_RenderContent called for Screen '$($this.Name)' (rendering UIElement children, including panels)."
    }

    [string] ToString() {
        return "Screen(Name='$($this.Name)', Panels=$($this.Panels.Count), Visible=$($this.Visible))"
    }
}
#endregion