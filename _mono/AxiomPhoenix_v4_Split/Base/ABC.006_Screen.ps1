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
        # Focus first focusable component when entering screen.
        # All debugging has been removed from this method.
        $this.InvalidateFocusCache()
        $this.FocusFirstChild()
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
        if ($this._focusedChild -eq $component) { 
            return $true 
        }
        
        # Blur current component
        if ($null -ne $this._focusedChild) {
            $this._focusedChild.IsFocused = $false
            $this._focusedChild.OnBlur()
            $this._focusedChild.RequestRedraw()
        }
        
        # Focus new component
        $this._focusedChild = $component
        if ($null -ne $component) {
            if ($component.IsFocusable -and $component.Enabled -and $component.Visible) {
                $component.IsFocused = $true
                $component.OnFocus()
                $component.RequestRedraw()
                
                # SET GLOBAL STATE
                if ($global:TuiState) {
                    $global:TuiState.FocusedComponent = $component
                }
                return $true
            } else {
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
        if ($focusable.Count -eq 0) { 
            return 
        }
        
        # Get current index - ensure we have a valid starting point
        $currentIndex = -1
        if ($null -ne $this._focusedChild) {
            $currentIndex = $focusable.IndexOf($this._focusedChild)
            
            # If current focused component is not in the focusable list, invalidate cache and retry
            if ($currentIndex -eq -1) {
                $this.InvalidateFocusCache()
                $focusable = $this._GetFocusableChildren()
                $currentIndex = $focusable.IndexOf($this._focusedChild)
            }
        }
        
        # Calculate next index
        $nextIndex = ($currentIndex + 1) % $focusable.Count
        $nextComponent = $focusable[$nextIndex]
        
        # Try to focus the next component
        if ($this.SetChildFocus($nextComponent)) {
            return
        }
        
        # If that failed, try all other components in order
        for ($i = 1; $i -lt $focusable.Count; $i++) {
            $tryIndex = ($currentIndex + 1 + $i) % $focusable.Count
            $tryComponent = $focusable[$tryIndex]
            if ($this.SetChildFocus($tryComponent)) {
                return
            }
        }
    }
    
    [void] FocusPreviousChild() {
        $focusable = $this._GetFocusableChildren()
        if ($focusable.Count -eq 0) { 
            return 
        }
        
        $currentIndex = 0 # Default to 0 if no focus
        if ($null -ne $this._focusedChild) {
            $currentIndex = $focusable.IndexOf($this._focusedChild)
        }
        
        $prevIndex = ($currentIndex - 1 + $focusable.Count) % $focusable.Count
        $prevComponent = $focusable[$prevIndex]
        $this.SetChildFocus($prevComponent)
    }
    
    [void] FocusFirstChild() {
        $focusable = $this._GetFocusableChildren()
        if ($focusable.Count -gt 0) {
            $success = $this.SetChildFocus($focusable[0])
            if (-not $success) {
                # Try other focusable components if first fails
                for ($i = 1; $i -lt $focusable.Count; $i++) {
                    if ($this.SetChildFocus($focusable[$i])) {
                        break
                    }
                }
            }
        }
    }
    
    hidden [System.Collections.Generic.List[UIElement]] _GetFocusableChildren() {
        # Prevent recursive calls during focus collection
        if ($this._collectingFocus) {
            return [System.Collections.Generic.List[UIElement]]::new()
        }
        
        # PERFORMANCE: Only rebuild if cache is invalid
        if (-not $this._focusCacheValid -or $null -eq $this._focusableCache) {
            $this._collectingFocus = $true
            try {
                # PERFORMANCE: If we had a previous cache, try incremental update
                if ($null -ne $this._focusableCache -and $this._focusableCache.Count -gt 0) {
                    # Check if any cached elements are now invalid
                    $needsFullRebuild = $false
                    for ($i = $this._focusableCache.Count - 1; $i -ge 0; $i--) {
                        $element = $this._focusableCache[$i]
                        if (-not $element.Visible -or -not $element.Enabled -or -not $element.IsFocusable) {
                            $this._focusableCache.RemoveAt($i)
                            $needsFullRebuild = $true
                        }
                    }
                    
                    # Only do full rebuild if we found invalid elements
                    if (-not $needsFullRebuild) {
                        $this._focusCacheValid = $true
                        return $this._focusableCache
                    }
                }
                
                $this._focusableCache = [System.Collections.Generic.List[UIElement]]::new()
                $visitedElements = [System.Collections.Generic.HashSet[UIElement]]::new()
                $this._CollectFocusableRecursive($this, $this._focusableCache, $visitedElements)
                
                # PERFORMANCE: Use ArrayList for faster sorting with large collections
                if ($this._focusableCache.Count -gt 10) {
                    $sortedArray = [System.Collections.ArrayList]::new($this._focusableCache)
                    $sortedArray.Sort({ param($x, $y) $x.TabIndex.CompareTo($y.TabIndex) })
                    $this._focusableCache.Clear()
                    foreach ($item in $sortedArray) {
                        $this._focusableCache.Add($item)
                    }
                } else {
                    # Use standard sort for small collections
                    $items = $this._focusableCache.ToArray()
                    $sortedArray = $items | Sort-Object TabIndex
                    $this._focusableCache.Clear()
                    foreach ($item in $sortedArray) {
                        $this._focusableCache.Add($item)
                    }
                }
                
                $this._focusCacheValid = $true
            }
            finally {
                $this._collectingFocus = $false
            }
        }
        return $this._focusableCache
    }
    
    hidden [void] _CollectFocusableRecursive([UIElement]$element, [System.Collections.Generic.List[UIElement]]$result, [System.Collections.Generic.HashSet[UIElement]]$visited) {
        if ($visited.Contains($element)) {
            return
        }
        
        $visited.Add($element) | Out-Null
        
        # If the current element is focusable, add it.
        # We must exclude the screen itself from being a focusable child.
        if ($element -ne $this -and $element.IsFocusable -and $element.Visible -and $element.Enabled) {
            $result.Add($element)
        }

        # Recurse into the children of the current element
        foreach ($child in $element.Children) {
            if ($child.Visible -and $child.Enabled) { # Only search visible and enabled branches
                $this._CollectFocusableRecursive($child, $result, $visited)
            }
        }
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
        
        # Handle Tab navigation at screen level FIRST (per guide - automatic Tab handling)
        if ($keyInfo.Key -eq [ConsoleKey]::Tab) {
            if (($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) -eq [ConsoleModifiers]::Shift) {
                $this.FocusPreviousChild()
            } else {
                $this.FocusNextChild()
            }
            return $true
        }
        
        # Route input to focused child
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