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
    [object]$ServiceContainer # Changed to object to avoid type conversion issues
    [System.Collections.Generic.Dictionary[string, object]]$State
    [System.Collections.Generic.List[UIElement]] $Panels
    [bool]$IsOverlay = $false  # NEW: Indicates if this screen renders as an overlay
    
    # Focus management (per-screen, ncurses model)
    hidden [UIElement]$_focusedChild = $null
    hidden [System.Collections.Generic.List[UIElement]]$_focusableCache = $null
    hidden [bool]$_focusCacheValid = $false
    
    hidden [bool] $_isInitialized = $false
    hidden [System.Collections.Generic.Dictionary[string, string]] $EventSubscriptions 

    # Primary constructor - takes ServiceContainer directly
    Screen([string]$name, [object]$serviceContainer) : base($name) {
        if ($null -eq $serviceContainer) {
            throw [System.ArgumentNullException]::new("serviceContainer")
        }
        # Verify it's actually a ServiceContainer at runtime
        if ($serviceContainer.GetType().Name -ne 'ServiceContainer') {
            throw [System.ArgumentException]::new("Expected ServiceContainer but got $($serviceContainer.GetType().Name)")
        }
        $this.ServiceContainer = $serviceContainer
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        # Set initial screen dimensions to console size
        $this.Width = [Math]::Max(80, [Console]::WindowWidth)
        $this.Height = [Math]::Max(24, [Console]::WindowHeight)
        # Write-Verbose "Screen '$($this.Name)' created with ServiceContainer."
    }

    # Legacy constructor for backward compatibility (deprecated)
    Screen([string]$name, [hashtable]$services) : base($name) {
        Write-Warning "Screen '$($this.Name)': Using deprecated hashtable constructor. Please update to use ServiceContainer."
        # This constructor is kept for backward compatibility but should be removed in future versions
        $this.ServiceContainer = $null
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        # Set initial screen dimensions to console size
        $this.Width = [Math]::Max(80, [Console]::WindowWidth)
        $this.Height = [Math]::Max(24, [Console]::WindowHeight)
    }

    [void] Initialize() { 
        # Write-Verbose "Initialize called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnEnter() { 
        # Focus first focusable component when entering screen
        $this.InvalidateFocusCache()
        $this.FocusFirstChild()
        # Write-Verbose "OnEnter called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnExit() { 
        # Write-Verbose "OnExit called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnResume() { 
        # Write-Verbose "OnResume called for Screen '$($this.Name)': Default (no-op)." 
    }

    # ===== FOCUS MANAGEMENT (ncurses window model) =====
    [UIElement] GetFocusedChild() {
        return $this._focusedChild
    }
    
    [bool] SetChildFocus([UIElement]$component) {
        if ($this._focusedChild -eq $component) { return $true }
        
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
        if ($focusable.Count -eq 0) { return }
        
        $currentIndex = -1
        if ($null -ne $this._focusedChild) {
            $currentIndex = $focusable.IndexOf($this._focusedChild)
        }
        
        $nextIndex = ($currentIndex + 1) % $focusable.Count
        $this.SetChildFocus($focusable[$nextIndex])
    }
    
    [void] FocusPreviousChild() {
        $focusable = $this._GetFocusableChildren()
        if ($focusable.Count -eq 0) { return }
        
        $currentIndex = $focusable.Count - 1
        if ($null -ne $this._focusedChild) {
            $currentIndex = $focusable.IndexOf($this._focusedChild)
        }
        
        $prevIndex = ($currentIndex - 1 + $focusable.Count) % $focusable.Count
        $this.SetChildFocus($focusable[$prevIndex])
    }
    
    [void] FocusFirstChild() {
        $focusable = $this._GetFocusableChildren()
        if ($focusable.Count -gt 0) {
            $this.SetChildFocus($focusable[0])
        }
    }
    
    hidden [System.Collections.Generic.List[UIElement]] _GetFocusableChildren() {
        if (-not $this._focusCacheValid -or $null -eq $this._focusableCache) {
            $this._focusableCache = [System.Collections.Generic.List[UIElement]]::new()
            $this._CollectFocusableRecursive($this, $this._focusableCache)
            
            # Sort by TabIndex for predictable tab order
            $sorted = $this._focusableCache | Sort-Object TabIndex
            $this._focusableCache.Clear()
            foreach ($item in $sorted) {
                $this._focusableCache.Add($item)
            }
            
            $this._focusCacheValid = $true
        }
        return $this._focusableCache
    }
    
    hidden [void] _CollectFocusableRecursive([UIElement]$element, [System.Collections.Generic.List[UIElement]]$result) {
        # Don't include the screen itself
        if ($element -ne $this -and $element.IsFocusable -and $element.Visible -and $element.Enabled) {
            $result.Add($element)
        }
        
        foreach ($child in $element.Children) {
            $this._CollectFocusableRecursive($child, $result)
        }
    }
    
    [void] InvalidateFocusCache() {
        $this._focusCacheValid = $false
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
        
        # Check global keybindings
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
                            Write-Log -Level Error -Message "Failed to execute action '$action': $($_.Exception.Message)"
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
            
            # Clear focus before cleanup
            $this.ClearFocus()
            $this._focusableCache = $null
            $this._focusCacheValid = $false
            
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
            
            # Clear screen-specific collections
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
            $this.InvalidateFocusCache()  # Invalidate focus cache when adding children
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
        Write-Verbose "_RenderContent called for Screen '$($this.Name)' (rendering UIElement children, including panels)."
    }

    [string] ToString() {
        $panelCount = if ($this.Panels) { $this.Panels.Count } else { 0 }
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
