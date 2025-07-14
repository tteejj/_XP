####\Base\ABC.006_Screen.ps1
# ==============================================================================
# Axiom-Phoenix v4.0 - Base Classes (Load First)
# Core framework classes with NO external dependencies
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ABC.###" to find specific sections.
# Each section ends with "END_PAGE: ABC.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Management.Automation
using namespace System.Threading

# Disable verbose output during TUI rendering
$script:TuiVerbosePreference = 'SilentlyContinue'

#region Screen - Top-level Container for Application Views

# ==============================================================================
# CLASS: Screen
#
# INHERITS:
#   - UIElement (ABC.004)
#
# DEPENDENCIES:
#   Classes:
#     - UIElement (ABC.004)
#     - ServiceContainer (ABC.007)
#   Services:
#     - All registered services via ServiceContainer
#
# PURPOSE:
#   Top-level container for application views. Screens represent complete
#   UI states (like Dashboard, Task List, Settings) and integrate with the
#   service container for dependency injection.
#
# KEY LOGIC:
#   - Initialize: Set up screen resources and state
#   - OnEnter: Called when navigating to this screen
#   - OnExit: Called when leaving this screen
#   - HandleInput: Process screen-level input
#   - SubscribeToEvent: Register for application events
#   - Cleanup: Unsubscribe from events and release resources
# ==============================================================================
class Screen : UIElement {
    [object]$ServiceContainer
    [System.Collections.Generic.Dictionary[string, object]]$State
    [System.Collections.Generic.List[UIElement]] $Panels
    [bool]$IsOverlay = $false
    
    # Focus management (per-screen, hybrid window model)
    hidden [UIElement]$_focusedChild = $null
    hidden [System.Collections.Generic.List[UIElement]]$_focusableCache = $null
    hidden [bool]$_focusCacheValid = $false
    hidden [bool]$_collectingFocus = $false  # Prevent recursive collection
    
    hidden [bool] $_isInitialized = $false
    hidden [System.Collections.Generic.Dictionary[string, string]] $EventSubscriptions 

    # Primary constructor - takes ServiceContainer directly
    Screen([string]$name, [object]$serviceContainer) : base($name) {
        if ($null -eq $serviceContainer) {
            throw [System.ArgumentNullException]::new("serviceContainer")
        }
        if ($serviceContainer.GetType().Name -ne 'ServiceContainer') {
            throw [System.ArgumentException]::new("Expected ServiceContainer but got $($serviceContainer.GetType().Name)")
        }
        $this.ServiceContainer = $serviceContainer
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        $this.Width = [Math]::Max(80, [Console]::WindowWidth)
        $this.Height = [Math]::Max(24, [Console]::WindowHeight)
    }

    # Legacy constructor for backward compatibility (deprecated)
    Screen([string]$name, [hashtable]$services) : base($name) {
        Write-Warning "Screen '$($this.Name)': Using deprecated hashtable constructor. Please update to use ServiceContainer."
        $this.ServiceContainer = $null
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        $this.Width = [Math]::Max(80, [Console]::WindowWidth)
        $this.Height = [Math]::Max(24, [Console]::WindowHeight)
    }

    [void] Initialize() { 
        # Write-Verbose "Initialize called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnEnter() { 
        # Focus first focusable component when entering screen
        Write-Log -Level Debug -Message "Screen.OnEnter: Setting initial focus for $($this.Name)"
        $this.InvalidateFocusCache()
        $focusable = $this.GetFocusableChildren()
        Write-Log -Level Debug -Message "Screen.OnEnter: Found $($focusable.Count) focusable components"
        $this.FocusFirstChild()
        $focused = $this.GetFocusedChild()
        $focusedName = "none"
        if ($focused) { $focusedName = $focused.Name }
        Write-Log -Level Debug -Message "Screen.OnEnter: Initial focus set to: $focusedName"
    }
    [void] OnExit() { 
        # Write-Verbose "OnExit called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnResume() { 
        # Write-Verbose "OnResume called for Screen '$($this.Name)': Default (no-op)." 
    }

    # ===== FOCUS MANAGEMENT (Hybrid Window Model) =====
    [UIElement] GetFocusedChild() {
        return $this._focusedChild
    }
    
    [bool] SetChildFocus([UIElement]$component) {
        $componentName = "null"
        if ($component) { $componentName = $component.Name }
        Write-Log -Level Debug -Message "Screen.SetChildFocus: Attempting to focus $componentName on screen $($this.Name)"
        
        if ($this._focusedChild -eq $component) { 
            Write-Log -Level Debug -Message "Screen.SetChildFocus: Component already has focus"
            return $true 
        }
        
        # Blur current component
        if ($null -ne $this._focusedChild) {
            Write-Log -Level Debug -Message "Screen.SetChildFocus: Blurring current focus: $($this._focusedChild.Name)"
            $this._focusedChild.IsFocused = $false
            $this._focusedChild.OnBlur()
            $this._focusedChild.RequestRedraw()
        }
        
        # Focus new component
        $this._focusedChild = $component
        if ($null -ne $component) {
            Write-Log -Level Debug -Message "Screen.SetChildFocus: Checking if component can receive focus - IsFocusable: $($component.IsFocusable), Enabled: $($component.Enabled), Visible: $($component.Visible)"
            if ($component.IsFocusable -and $component.Enabled -and $component.Visible) {
                Write-Log -Level Debug -Message "Screen.SetChildFocus: Setting focus on $($component.Name)"
                $component.IsFocused = $true
                $component.OnFocus()
                $component.RequestRedraw()
                return $true
            } else {
                Write-Log -Level Debug -Message "Screen.SetChildFocus: Component $($component.Name) cannot receive focus"
                $this._focusedChild = $null
                return $false
            }
        }
        return $true
    }
    
    [void] ClearFocus() {
        $this.SetChildFocus($null)
    }
    
    [void] FocusNextChild() {
        $focusable = $this._GetFocusableChildren()
        Write-Log -Level Debug -Message "navigation.nextComponent: Found $($focusable.Count) focusable components"
        if ($focusable.Count -eq 0) { 
            Write-Log -Level Debug -Message "navigation.nextComponent: No focusable components found"
            return 
        }
        
        $currentIndex = -1
        if ($null -ne $this._focusedChild) {
            $currentIndex = $focusable.IndexOf($this._focusedChild)
            Write-Log -Level Debug -Message "navigation.nextComponent: Current focus: $($this._focusedChild.Name)"
        } else {
            Write-Log -Level Debug -Message "navigation.nextComponent: No current focus"
        }
        
        # Try to focus next component, and if that fails, try subsequent ones
        for ($i = 0; $i -lt $focusable.Count; $i++) {
            $nextIndex = ($currentIndex + 1 + $i) % $focusable.Count
            $nextComponent = $focusable[$nextIndex]
            Write-Log -Level Debug -Message "navigation.nextComponent: Attempting to focus $($nextComponent.Name) at index $nextIndex"
            if ($this.SetChildFocus($nextComponent)) {
                $focusedName = "none"
                if ($this._focusedChild) { $focusedName = $this._focusedChild.Name }
                Write-Log -Level Debug -Message "navigation.nextComponent: New focus: $focusedName"
                return
            }
        }
        Write-Log -Level Warning -Message "navigation.nextComponent: Failed to focus any component"
    }
    
    [void] FocusPreviousChild() {
        $focusable = $this._GetFocusableChildren()
        Write-Log -Level Debug -Message "navigation.previousComponent: Found $($focusable.Count) focusable components"
        if ($focusable.Count -eq 0) { 
            Write-Log -Level Debug -Message "navigation.previousComponent: No focusable components found"
            return 
        }
        
        $currentIndex = 0 # Default to 0 if no focus
        if ($null -ne $this._focusedChild) {
            $currentIndex = $focusable.IndexOf($this._focusedChild)
            Write-Log -Level Debug -Message "navigation.previousComponent: Current focus: $($this._focusedChild.Name)"
        } else {
            Write-Log -Level Debug -Message "navigation.previousComponent: No current focus"
        }
        
        $prevIndex = ($currentIndex - 1 + $focusable.Count) % $focusable.Count
        $prevComponent = $focusable[$prevIndex]
        Write-Log -Level Debug -Message "navigation.previousComponent: Attempting to focus $($prevComponent.Name) at index $prevIndex"
        $this.SetChildFocus($prevComponent)
        $focusedName = "none"
        if ($this._focusedChild) { $focusedName = $this._focusedChild.Name }
        Write-Log -Level Debug -Message "navigation.previousComponent: New focus: $focusedName"
    }
    
    [void] FocusFirstChild() {
        $focusable = $this._GetFocusableChildren()
        Write-Log -Level Debug -Message "Screen.FocusFirstChild: Found $($focusable.Count) focusable children"
        if ($focusable.Count -gt 0) {
            Write-Log -Level Debug -Message "Screen.FocusFirstChild: Attempting to focus first child: $($focusable[0].Name)"
            $success = $this.SetChildFocus($focusable[0])
            if (-not $success) {
                Write-Log -Level Warning -Message "Screen.FocusFirstChild: Failed to focus first child $($focusable[0].Name), trying next focusable component"
                # Try other focusable components if first fails
                for ($i = 1; $i -lt $focusable.Count; $i++) {
                    Write-Log -Level Debug -Message "Screen.FocusFirstChild: Trying to focus component ${i}: $($focusable[$i].Name)"
                    if ($this.SetChildFocus($focusable[$i])) {
                        Write-Log -Level Debug -Message "Screen.FocusFirstChild: Successfully focused: $($focusable[$i].Name)"
                        break
                    }
                }
            }
        } else {
            Write-Log -Level Debug -Message "Screen.FocusFirstChild: No focusable children found"
        }
    }
    
    # PERFORMANCE FIX: Prevent duplicate focus collection with circular reference protection
    hidden [System.Collections.Generic.List[UIElement]] _GetFocusableChildren() {
        # Prevent recursive calls during focus collection
        if ($this._collectingFocus) {
            Write-Log -Level Warning -Message "Screen._GetFocusableChildren: Recursive call detected, returning empty list"
            return [System.Collections.Generic.List[UIElement]]::new()
        }
        
        if (-not $this._focusCacheValid -or $null -eq $this._focusableCache) {
            $this._collectingFocus = $true
            try {
                $this._focusableCache = [System.Collections.Generic.List[UIElement]]::new()
                $visitedElements = [System.Collections.Generic.HashSet[UIElement]]::new()
                $this._CollectFocusableRecursive($this, $this._focusableCache, $visitedElements)
                
                # CRITICAL FIX: Use PowerShell-native object identity tracking for reliable deduplication
                $uniqueTracker = @{}
                $cleanList = [System.Collections.Generic.List[UIElement]]::new()
                foreach ($element in $this._focusableCache) {
                    $objectId = $element.GetHashCode().ToString() + "_" + $element.Name
                    if (-not $uniqueTracker.ContainsKey($objectId)) {
                        $uniqueTracker[$objectId] = $true
                        $cleanList.Add($element)
                        Write-Log -Level Debug -Message "Screen._GetFocusableChildren: Added unique element: $($element.Name) (ID: $objectId)"
                    } else {
                        Write-Log -Level Debug -Message "Screen._GetFocusableChildren: Skipping duplicate element: $($element.Name) (ID: $objectId)"
                    }
                }
                
                # Sort by TabIndex for predictable tab order
                $sorted = $cleanList | Sort-Object TabIndex
                $this._focusableCache.Clear()
                foreach ($item in $sorted) {
                    $this._focusableCache.Add($item)
                }
                
                Write-Log -Level Debug -Message "Screen._GetFocusableChildren: Final focus list for $($this.Name) has $($this._focusableCache.Count) unique components"
                foreach ($component in $this._focusableCache) {
                    Write-Log -Level Debug -Message "  - Focusable: $($component.Name) (TabIndex: $($component.TabIndex), IsFocusable: $($component.IsFocusable), Visible: $($component.Visible), Enabled: $($component.Enabled))"
                }
                
                $this._focusCacheValid = $true
            }
            finally {
                $this._collectingFocus = $false
            }
        }
        return $this._focusableCache
    }
    
    # PERFORMANCE FIX: Add circular reference protection to prevent infinite loops
    hidden [void] _CollectFocusableRecursive([UIElement]$element, [System.Collections.Generic.List[UIElement]]$result, [System.Collections.Generic.HashSet[UIElement]]$visited) {
        # Create a simple tracking key using object hash and name to identify unique visits
        $visitKey = "$($element.GetHashCode())_$($element.Name)"
        
        # Check if we've already processed this exact element instance
        $alreadyVisited = $false
        foreach ($visitedElement in $visited) {
            $existingKey = "$($visitedElement.GetHashCode())_$($visitedElement.Name)"
            if ($visitKey -eq $existingKey) {
                $alreadyVisited = $true
                Write-Log -Level Debug -Message "Screen._CollectFocusableRecursive: Already visited $visitKey, skipping"
                break
            }
        }
        if ($alreadyVisited) { return }
        
        $visited.Add($element) | Out-Null
        Write-Log -Level Debug -Message "Screen._CollectFocusableRecursive: Visiting element: $($element.Name) ($visitKey)"
        
        # If the current element is focusable, add it.
        # We must exclude the screen itself from being a focusable child.
        if ($element -ne $this -and $element.IsFocusable -and $element.Visible -and $element.Enabled) {
            Write-Log -Level Debug -Message "Screen._CollectFocusableRecursive: Found focusable element: $($element.Name) (TabIndex: $($element.TabIndex))"
            $result.Add($element)
        } else {
            Write-Log -Level Debug -Message "Screen._CollectFocusableRecursive: Skipping element: $($element.Name) - IsFocusable: $($element.IsFocusable), Visible: $($element.Visible), Enabled: $($element.Enabled), IsScreen: $($element -eq $this)"
        }

        # CRITICAL FIX: Always recurse into the children of the current element,
        # regardless of whether the element itself is focusable. This allows the
        # search to find focusable components inside non-focusable containers like Panels.
        Write-Log -Level Debug -Message "Screen._CollectFocusableRecursive: Checking $($element.Children.Count) children of $($element.Name)"
        foreach ($child in $element.Children) {
            if ($child.Visible -and $child.Enabled) { # Only search visible and enabled branches
                $this._CollectFocusableRecursive($child, $result, $visited)
            } else {
                Write-Log -Level Debug -Message "Screen._CollectFocusableRecursive: Skipping invisible/disabled child: $($child.Name)"
            }
        }
        
        # DO NOT REMOVE from visited set - keep permanent record to prevent duplicates
        # Elements can be reached through multiple paths in complex UI hierarchies
    }
    
    [void] InvalidateFocusCache() {
        # Only invalidate if not currently collecting to prevent cascading invalidations
        if (-not $this._collectingFocus) {
            $this._focusCacheValid = $false
        }
    }

    # Public method for debugging focus issues
    [System.Collections.Generic.List[UIElement]] GetFocusableChildren() {
        return $this._GetFocusableChildren()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Handle Tab navigation within this screen
        if ($keyInfo.Key -eq [ConsoleKey]::Tab) {
            if ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) {
                $this.FocusPreviousChild()
            } else {
                $this.FocusNextChild()
            }
            return $true
        }
        
        # Route input to focused child first
        if ($null -ne $this._focusedChild) {
            if ($this._focusedChild.HandleInput($keyInfo)) {
                return $true
            }
        }
        
        # If child did not handle it, check for global keybindings
        if ($null -ne $this.ServiceContainer) {
            $keybindingService = $this.ServiceContainer.GetService("KeybindingService")
            if ($keybindingService) {
                $action = $keybindingService.GetAction($keyInfo)
                if ($action) {
                    $actionService = $this.ServiceContainer.GetService("ActionService")
                    if ($actionService) {
                        try {
                            $actionService.ExecuteAction($action, @{})
                            return $true
                        }
                        catch {
                            if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                                Write-Log -Level Error -Message "Failed to execute action '$action': $($_.Exception.Message)"
                            }
                        }
                    }
                }
            }
        }
        
        # Screen didn't handle the input
        return $false
    }

    [void] HandleKeyPress([System.ConsoleKeyInfo]$keyInfo) {
        $this.HandleInput($keyInfo)
    }

    [void] HandleResize([int]$newWidth, [int]$newHeight) {
        $this.Resize($newWidth, $newHeight)
    }

    [void] Cleanup() {
        try {
            # Write-Verbose "Cleanup called for Screen '$($this.Name)'."
            
            $this.ClearFocus()
            $this._focusableCache = $null
            $this._focusCacheValid = $false
            $this._collectingFocus = $false
            
            # Screen-specific cleanup: Unsubscribe from events
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
            
            $this.Panels.Clear()
            $this.State.Clear()
            
            # Call base UIElement cleanup (handles children recursively)
            ([UIElement]$this).Cleanup()
            
            Write-Verbose "Cleaned up resources for screen: $($this.Name)."
        }
        catch {
            Write-Error "Error during Cleanup for screen '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    [void] AddPanel([object]$panel) {
        try {
            $this.Panels.Add($panel)
            $this.AddChild($panel) 
            $this.InvalidateFocusCache()
            Write-Verbose "Added panel '$($panel.Name)' to screen '$($this.Name)'."
        }
        catch {
            Write-Error "Failed to add panel '$($panel.Name)' to screen '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }
    
    # Override AddChild to invalidate focus cache
    [void] AddChild([UIElement]$child) {
        ([UIElement]$this).AddChild($child)
        $this.InvalidateFocusCache()
    }
    
    # Override RemoveChild to invalidate focus cache  
    [void] RemoveChild([UIElement]$child) {
        if ($this._focusedChild -eq $child) {
            $this.ClearFocus()
        }
        ([UIElement]$this).RemoveChild($child)
        $this.InvalidateFocusCache()
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
        # Write-Verbose "_RenderContent called for Screen '$($this.Name)' (rendering UIElement children, including panels)."
    }

    [string] ToString() {
        $panelCount = 0
        if ($this.Panels) { $panelCount = $this.Panels.Count }
        return "Screen(Name='$($this.Name)', Panels=$panelCount, Visible=$($this.Visible))"
    }

    [void] Render([TuiBuffer]$buffer) {
        # First render self
        $this._RenderContent()
        
        # Then blend our buffer onto the target
        if ($null -ne $this._private_buffer) {
            $buffer.BlendBuffer($this._private_buffer, 0, 0)
        }
    }
}
#endregion
#<!-- END_PAGE: ABC.006 -->