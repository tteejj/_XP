# ==============================================================================
# PMC Terminal v5 - Base UI Class Hierarchy
# Provides the foundational classes for all UI components with NCurses compositor support.
# ==============================================================================

#region UIElement - Base Class for all UI Components
# The foundational class for all visual components in the TUI.
# It provides basic properties like position, size, visibility, and a private TuiBuffer for rendering.
class UIElement {
    [string] $Name = "UIElement" # Default name for logging/debugging
    [int] $X = 0               # X-coordinate relative to parent or screen
    [int] $Y = 0               # Y-coordinate relative to parent or screen
    [int] $Width = 10          # Width of the element. Must be positive.
    [int] $Height = 3          # Height of the element. Must be positive.
    [bool] $Visible = $true    # Determines if the element is rendered
    [bool] $Enabled = $true    # Determines if the element can receive input or be focused
    [bool] $IsFocusable = $false # Can this element receive focus?
    [bool] $IsFocused = $false  # Is this element currently focused?
    [int] $TabIndex = 0        # For tab navigation order
    [int] $ZIndex = 0          # Determines rendering order, higher ZIndex means drawn on top
    [UIElement] $Parent = $null # Reference to parent UIElement
    [System.Collections.Generic.List[UIElement]] $Children # List of child UIElement instances
    
    # Private backing fields for buffer and redraw flag
    # These are marked 'hidden' to prevent accidental direct access and manipulation
    # from outside the class, enforcing proper rendering lifecycle.
    hidden [TuiBuffer] $_private_buffer = $null
    hidden [bool] $_needs_redraw = $true
    
    [hashtable] $Metadata = @{} # For arbitrary data attachment

    # Default Constructor: Initializes a basic UIElement.
    # Uses default dimensions (10x3) which are typically overridden.
    UIElement() {
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        # Initialize buffer with default dimensions. Actual dimensions might be set later.
        # Ensure TuiBuffer is imported and available here.
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        Write-Verbose "UIElement 'Unnamed' created with default size ($($this.Width)x$($this.Height))."
    }

    # Constructor with Name: Initializes a UIElement with a specified name.
    UIElement([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$name) {
        $this.Name = $name
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        Write-Verbose "UIElement '$($this.Name)' created with default size ($($this.Width)x$($this.Height))."
    }

    # Constructor with Position and Size: Initializes a UIElement with specified dimensions.
    UIElement(
        [Parameter(Mandatory)][int]$x,
        [Parameter(Mandatory)][int]$y,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$width,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$height
    ) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($width, $height, "Unnamed.Buffer")
        Write-Verbose "UIElement 'Unnamed' created at ($x, $y) with dimensions $($width)x$($height)."
    }

    # GetAbsolutePosition: Calculates the absolute screen coordinates of this element.
    # It aggregates the X and Y positions from itself and all its parent elements.
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

    # AddChild: Adds a child UIElement to this component.
    # The child's parent reference is set, and a redraw is requested.
    [void] AddChild([Parameter(Mandatory)][ValidateNotNull()][UIElement]$child) {
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

    # RemoveChild: Removes a specified child UIElement from this component.
    # The child's parent reference is nulled, and a redraw is requested.
    [void] RemoveChild([Parameter(Mandatory)][ValidateNotNull()][UIElement]$child) {
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

    # RequestRedraw: Marks this component and all its ancestors as needing a redraw.
    # This ensures that changes are propagated up the component tree to the root screen/engine.
    [void] RequestRedraw() {
        $this._needs_redraw = $true
        if ($null -ne $this.Parent) {
            $this.Parent.RequestRedraw() # Propagate redraw request up the hierarchy
        }
        Write-Verbose "Redraw requested for '$($this.Name)'."
    }

    # Resize: Resizes the component and its internal TuiBuffer.
    # Calls the virtual OnResize method for custom subclass logic.
    [void] Resize(
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$newWidth,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$newHeight
    ) {
        try {
            if ($this.Width -eq $newWidth -and $this.Height -eq $newHeight) {
                Write-Verbose "Resize: Component '$($this.Name)' already has target dimensions ($($newWidth)x$($newHeight)). No change."
                return # No change needed
            }

            $this.Width = $newWidth
            $this.Height = $newHeight
            
            if ($null -ne $this._private_buffer) {
                $this._private_buffer.Resize($newWidth, $newHeight)
            } else {
                # Recreate buffer if it was null (e.g., during initial construction before dimensions are final)
                $this._private_buffer = [TuiBuffer]::new($newWidth, $newHeight, "$($this.Name).Buffer")
                Write-Verbose "Re-initialized buffer for '$($this.Name)' due to null buffer."
            }
            
            $this.RequestRedraw()
            $this.OnResize($newWidth, $newHeight) # Call virtual method
            Write-Verbose "Component '$($this.Name)' resized to $($newWidth)x$($newHeight)."
        }
        catch {
            Write-Error "Failed to resize component '$($this.Name)' to $($newWidth)x$($newHeight): $($_.Exception.Message)"
            throw
        }
    }

    # Move: Moves the component to new coordinates.
    # Calls the virtual OnMove method for custom subclass logic.
    [void] Move([Parameter(Mandatory)][int]$newX, [Parameter(Mandatory)][int]$newY) {
        if ($this.X -eq $newX -and $this.Y -eq $newY) {
            Write-Verbose "Move: Component '$($this.Name)' already at target position ($($newX), $($newY)). No change."
            return # No change needed
        }

        $this.X = $newX
        $this.Y = $newY
        $this.RequestRedraw() # Position change always requires redraw
        $this.OnMove($newX, $newY) # Call virtual method
        Write-Verbose "Component '$($this.Name)' moved to ($newX, $newY)."
    }

    # ContainsPoint: Checks if a given point (relative to the component's own origin) falls within its bounds.
    [bool] ContainsPoint([Parameter(Mandatory)][int]$x, [Parameter(Mandatory)][int]$y) {
        return ($x -ge 0 -and $x -lt $this.Width -and # Check X within 0 to Width-1
                $y -ge 0 -and $y -lt $this.Height)  # Check Y within 0 to Height-1
    }

    # GetChildAtPoint: Finds the topmost visible child component at a specific point (relative to this component).
    # Iterates children in reverse order (from last added/highest ZIndex potentially) to find the top-most.
    [UIElement] GetChildAtPoint([Parameter(Mandatory)][int]$x, [Parameter(Mandatory)][int]$y) {
        # Iterate in reverse order to find the topmost child (higher ZIndex or later in list)
        # Note: If ZIndex is implemented, it would be ideal to sort children by ZIndex descending, then iterate.
        # The current implementation iterates by list order (last added child is 'on top' if ZIndex is equal).
        for ($i = $this.Children.Count - 1; $i -ge 0; $i--) {
            $child = $this.Children[$i]
            # Check if child is visible and the point falls within its relative bounds
            # The point ($x, $y) is relative to this parent, so transform it for the child.
            if ($child.Visible -and $child.ContainsPoint($x - $child.X, $y - $child.Y)) {
                return $child # Found the child, return it
            }
        }
        return $null # No child found at this point
    }

    # OnRender: Virtual method for subclasses to override.
    # This is where the component's own content drawing logic should reside.
    # Default implementation clears the component's private buffer.
    [void] OnRender() {
        if ($null -ne $this._private_buffer) {
            $this._private_buffer.Clear()
        }
        Write-Verbose "OnRender called for '$($this.Name)': Default buffer clear."
    }

    # OnResize: Virtual method for subclasses to override.
    # Called after the component's dimensions are updated by the Resize method.
    [void] OnResize([Parameter(Mandatory)][int]$newWidth, [Parameter(Mandatory)][int]$newHeight) {
        Write-Verbose "OnResize called for '$($this.Name)': No custom resize logic."
    }

    # OnMove: Virtual method for subclasses to override.
    # Called after the component's position is updated by the Move method.
    [void] OnMove([Parameter(Mandatory)][int]$newX, [Parameter(Mandatory)][int]$newY) {
        Write-Verbose "OnMove called for '$($this.Name)': No custom move logic."
    }

    # OnFocus: Virtual method for subclasses to override.
    # Called when the component gains focus.
    [void] OnFocus() {
        Write-Verbose "OnFocus called for '$($this.Name)'."
    }

    # OnBlur: Virtual method for subclasses to override.
    # Called when the component loses focus.
    [void] OnBlur() {
        Write-Verbose "OnBlur called for '$($this.Name)'."
    }

    # HandleInput: Virtual method for subclasses to override.
    # This is the primary entry point for a component to process keyboard input.
    # Returns $true if the input was handled, $false otherwise.
    [bool] HandleInput([Parameter(Mandatory)][System.ConsoleKeyInfo]$keyInfo) {
        Write-Verbose "HandleInput called for '$($this.Name)': Key: $($keyInfo.Key)."
        return $false # Default: Input not handled
    }

    # Render: The public entry point for rendering an element and its children.
    # This method coordinates the rendering process. The TUI Engine is expected to
    # wrap calls to this method with application-wide error handling (e.g., Invoke-WithErrorHandling).
    [void] Render() {
        if (-not $this.Visible) { 
            Write-Verbose "Skipping Render for '$($this.Name)': Not visible."
            return 
        }
        
        # _RenderContent is the internal, protected method that does the actual work.
        # It's explicitly called here. Error handling for this *entire* render call
        # (including all children and blending) is typically handled by the TUI Engine
        # which calls the root screen/overlay's Render() method.
        $this._RenderContent() 
    }

    # _RenderContent: Protected internal method for rendering the component's content and compositing children.
    # This method handles the core rendering logic: drawing the component itself,
    # then recursively rendering and blending its visible children.
    hidden [void] _RenderContent() {
        if (-not $this.Visible) { return } # Defensive check, should be caught by Render()

        # Step 1: Render this component's own content to its private buffer.
        # This only happens if the component is marked as dirty (_needs_redraw)
        # or if its private buffer has not yet been initialized.
        if ($this._needs_redraw -or ($null -eq $this._private_buffer)) {
            # Re-initialize buffer if it's null or dimensions changed drastically
            # (e.g. if the UIElement was constructed with default 10x3 size, then resized)
            if ($null -eq $this._private_buffer -or $this._private_buffer.Width -ne $this.Width -or $this._private_buffer.Height -ne $this.Height) {
                # Ensure dimensions are valid before creating buffer
                $bufferWidth = [Math]::Max(1, $this.Width)
                $bufferHeight = [Math]::Max(1, $this.Height)
                $this._private_buffer = [TuiBuffer]::new($bufferWidth, $bufferHeight, "$($this.Name).Buffer")
                Write-Verbose "Re-initialized buffer for '$($this.Name)' due to null or dimension mismatch ($($bufferWidth)x$($bufferHeight))."
            }
            
            $this.OnRender() # Call the virtual method for actual drawing logic
            $this._needs_redraw = $false # Reset redraw flag after rendering
            Write-Verbose "Rendered own content for '$($this.Name)'."
        }

        # Step 2: Recursively render visible children and composite their buffers onto this component's buffer.
        # Sorting by ZIndex ensures correct layering (lower ZIndex drawn first, higher last).
        foreach ($child in $this.Children | Sort-Object ZIndex) { 
            if ($child.Visible) {
                $child.Render() # Recursively call Render for child
                
                # Composite child's buffer onto this component's buffer
                if ($null -ne $child._private_buffer) {
                    # Children's coordinates are relative to their parent's content area.
                    $this._private_buffer.BlendBuffer($child._private_buffer, $child.X, $child.Y)
                    Write-Verbose "Blended child '$($child.Name)' onto '$($this.Name)' at ($($child.X), $($child.Y))."
                }
            }
        }
    }

    # GetBuffer: Returns the component's internal TuiBuffer containing its rendered content.
    [TuiBuffer] GetBuffer() {
        return $this._private_buffer
    }
    
    # ToString: Provides a human-readable string representation for debugging.
    [string] ToString() {
        return "$($this.GetType().Name)(Name='$($this.Name)', X=$($this.X), Y=$($this.Y), Width=$($this.Width), Height=$($this.Height), Visible=$($this.Visible))"
    }
}
#endregion

#region Component - A generic container component
# Inherits from UIElement and can contain other UI elements.
# Its primary purpose is to group children. Its _RenderContent defers to the base UIElement.
class Component : UIElement {
    # Constructor: Initializes a Component with a name.
    Component([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$name) : base($name) {
        $this.Name = $name # Explicitly set Name after base constructor (for clarity, though base does it)
        Write-Verbose "Component '$($this.Name)' created."
    }

    # _RenderContent: Overrides the base method but simply calls the parent's implementation.
    # This means a generic 'Component' does not draw anything itself beyond what UIElement does,
    # relying on its children to populate its buffer.
    hidden [void] _RenderContent() {
        # Call parent implementation for buffer management and child rendering
        ([UIElement]$this)._RenderContent()
        Write-Verbose "_RenderContent called for Component '$($this.Name)' (delegating to base UIElement)."
    }

    # ToString: Provides a human-readable string representation for debugging.
    [string] ToString() {
        return "Component(Name='$($this.Name)', Children=$($this.Children.Count))"
    }
}
#endregion

# Note: Panel class is now defined in layout\panels-class.psm1 (part of the monolith structure)

#region Screen - Top-level Container for Application Views
# Represents a full-screen application view. Screens manage panels and have their own lifecycle methods
# (Initialize, OnEnter, OnExit, OnResume) and service dependencies.
class Screen : UIElement {
    # Services are stored here, usually provided via Dependency Injection.
    # The 'Services' hashtable is for backward compatibility. 'ServiceContainer' is for new DI.
    [hashtable]$Services # For backward compatibility (legacy services hashtable)
    [object]$ServiceContainer # Direct reference to a DI container (e.g., [ServiceContainer])

    [System.Collections.Generic.Dictionary[string, object]]$State # To hold screen-specific data/state
    [System.Collections.Generic.List[UIElement]] $Panels          # List of top-level panels on this screen
    [UIElement]$LastFocusedComponent # Tracks the last component that had focus on this screen
    
    # Stores event subscription IDs (HandlerId) for cleanup when the screen exits.
    hidden [System.Collections.Generic.Dictionary[string, string]] $EventSubscriptions 

    # Constructor with hashtable services (backward compatibility):
    # Initializes a screen using a simple hashtable for services.
    Screen(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$name,
        [Parameter(Mandatory)][ValidateNotNull()][hashtable]$services
    ) : base($name) {
        $this.Services = $services
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        $this.ServiceContainer = $null # Explicitly null for this constructor type
        Write-Verbose "Screen '$($this.Name)' created with hashtable services."
    }

    # Constructor with ServiceContainer (new DI approach):
    # Initializes a screen using a proper service container for dependency resolution.
    # Assumes the ServiceContainer object has a 'GetRegisteredServices' and 'GetService' method.
    Screen(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$name,
        [Parameter(Mandatory)][ValidateNotNull()][object]$serviceContainer # Expects a ServiceContainer object
    ) : base($name) {
        $this.ServiceContainer = $serviceContainer
        # Create a Services hashtable from the container for backward compatibility/ease of access
        $this.Services = [hashtable]::new()
        # Check if the provided object actually looks like a ServiceContainer before trying to use its methods
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

    # Initialize: Virtual method for screen-specific setup that occurs once after creation.
    # Typically used for setting up components, initial data loading, etc.
    [void] Initialize() {
        Write-Verbose "Initialize called for Screen '$($this.Name)': Default (no-op)."
    }

    # OnEnter: Virtual method called when the screen becomes active (e.g., pushed onto navigation stack).
    # Useful for refreshing data, setting initial focus, or starting screen-specific processes.
    [void] OnEnter() {
        Write-Verbose "OnEnter called for Screen '$($this.Name)': Default (no-op)."
    }

    # OnExit: Virtual method called when the screen is no longer active (e.g., another screen pushed, or popped off stack).
    # Used for saving temporary state, pausing screen-specific activities, etc.
    [void] OnExit() {
        Write-Verbose "OnExit called for Screen '$($this.Name)': Default (no-op)."
    }

    # OnResume: Virtual method called when a screen becomes active again after another screen is popped off the stack.
    # Useful for refreshing data that might have changed while this screen was inactive.
    [void] OnResume() {
        Write-Verbose "OnResume called for Screen '$($this.Name)': Default (no-op)."
    }

    # HandleInput: Virtual method for screen-specific input handling.
    # It receives the raw ConsoleKeyInfo. Returns $true if input was handled.
    # Note: In this TUI architecture, focusable components usually handle input first.
    # This method is primarily for screen-wide shortcuts or unhandled input.
    [void] HandleInput([Parameter(Mandatory)][System.ConsoleKeyInfo]$keyInfo) {
        Write-Verbose "HandleInput called for Screen '$($this.Name)': Key: $($keyInfo.Key). Default (no-op)."
    }

    # Cleanup: Cleans up resources specific to this screen when it's no longer needed.
    # This critically includes unsubscribing from events to prevent memory leaks.
    [void] Cleanup() {
        try {
            Write-Verbose "Cleanup called for Screen '$($this.Name)'."
            # Unsubscribe from all events managed by this screen
            # This relies on the global 'Unsubscribe-Event' function from the EventSystem module.
            # It expects 'Unsubscribe-Event' to be available in the global scope where this module is loaded.
            foreach ($kvp in $this.EventSubscriptions.GetEnumerator()) {
                try {
                    # The value stored in EventSubscriptions is the HandlerId (subscriptionId) returned by Subscribe-Event
                    if (Get-Command 'Unsubscribe-Event' -ErrorAction SilentlyContinue) {
                        Unsubscribe-Event -EventName $kvp.Key -HandlerId $kvp.Value
                        Write-Verbose "Unsubscribed event '$($kvp.Key)' (HandlerId: $($kvp.Value)) for screen '$($this.Name)'."
                    }
                }
                catch {
                    Write-Warning "Failed to unsubscribe event '$($kvp.Key)' (HandlerId: $($kvp.Value)) for screen '$($this.Name)': $($_.Exception.Message)"
                }
            }
            $this.EventSubscriptions.Clear() # Clear the tracking list after unsubscription
            
            # Clean up child components that have their own cleanup
            foreach ($child in $this.Children) {
                if ($child.PSObject.Methods['Cleanup']) {
                    try {
                        $child.Cleanup()
                    } catch {
                        Write-Warning "Failed to cleanup child '$($child.Name)': $($_.Exception.Message)"
                    }
                }
            }
            
            $this.Panels.Clear() # Clear panels collection (panels handle their own children cleanup)
            $this.Children.Clear() # Clear direct children (if any)
            Write-Verbose "Cleaned up resources for screen: $($this.Name)."
        }
        catch {
            Write-Error "Error during Cleanup for screen '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    # AddPanel: Adds a UIElement (typically a Panel) to the screen's list of panels.
    # Panels are top-level children of a Screen that contribute to its layout.
    [void] AddPanel([Parameter(Mandatory)][ValidateNotNull()][UIElement]$panel) {
        try {
            # Add to panels list for screen-specific tracking.
            $this.Panels.Add($panel)
            # Crucial: Also add it as a regular child of the base UIElement.
            # This ensures it participates in the UIElement's general rendering hierarchy.
            $this.AddChild($panel) 
            Write-Verbose "Added panel '$($panel.Name)' to screen '$($this.Name)'."
        }
        catch {
            Write-Error "Failed to add panel '$($panel.Name)' to screen '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    # SubscribeToEvent: A helper method for screens to easily subscribe to global events
    # and automatically manage their unsubscription during cleanup.
    # This assumes the global 'Subscribe-Event' function from EventSystem is available.
    [void] SubscribeToEvent(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$eventName,
        [Parameter(Mandatory)][ValidateNotNull()][scriptblock]$action
    ) {
        try {
            # Call the global Subscribe-Event function and store the unique HandlerId it returns.
            # The 'Source' parameter is important for bulk cleanup (e.g., Remove-ComponentEventHandlers).
            if (Get-Command 'Subscribe-Event' -ErrorAction SilentlyContinue) {
                $subscriptionId = Subscribe-Event -EventName $eventName -Handler $action -Source $this.Name
                $this.EventSubscriptions[$eventName] = $subscriptionId # Store the actual HandlerId for later unsubscription
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
    
    # _RenderContent: Overrides the base UIElement method to correctly render the screen's content.
    hidden [void] _RenderContent() {
        # Call base implementation for buffer management (clearing, etc.) and direct children.
        # This base call will now correctly handle rendering of panels as well, because AddPanel
        # now adds them to the base UIElement's 'Children' collection.
        ([UIElement]$this)._RenderContent()
        
        Write-Verbose "_RenderContent called for Screen '$($this.Name)' (rendering UIElement children, including panels)."
        # Explicit loop for Panels is no longer necessary here as base _RenderContent handles all children.
        # Keeping $this.Panels as a distinct collection is still useful for semantic grouping or specific Screen-level logic.
    }

    # ToString: Provides a human-readable string representation for debugging.
    [string] ToString() {
        return "Screen(Name='$($this.Name)', Panels=$($this.Panels.Count), Visible=$($this.Visible))"
    }
}
#endregion

# Export all public classes so they are available when the module is imported.
Export-ModuleMember -Class UIElement, Component, Screen
