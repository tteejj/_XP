# ==============================================================================
# Axiom-Phoenix v4.0 - All Services (Load After Components)
# Core application services: action, navigation, data, theming, logging, events
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASE.###" to find specific sections.
# Each section ends with "END_PAGE: ASE.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Management.Automation
using namespace System.Threading

#region NavigationService Class

# ===== CLASS: NavigationService =====
# Module: navigation-service (from axiom)
# Dependencies: ServiceContainer, EventManager (optional)
# Purpose: Screen navigation and history management
class NavigationService {
    [System.Collections.Generic.Stack[object]]$NavigationStack # FIXED: Changed from Stack[Screen] to Stack[object]
    [object]$CurrentScreen # FIXED: Changed from [Screen] to [object]
    [hashtable]$ScreenRegistry = @{}
    [int]$MaxStackSize = 10
    [object]$ServiceContainer # Store the container as object to avoid type issues

    # Updated constructor that takes ServiceContainer directly (as object to avoid type conversion issues)
    NavigationService([object]$serviceContainer) {
        # Initialize collections first
        $this.NavigationStack = [System.Collections.Generic.Stack[object]]::new()
        
        if ($null -eq $serviceContainer) {
            throw [System.ArgumentNullException]::new("serviceContainer")
        }
        # Verify it's actually a ServiceContainer at runtime
        if ($serviceContainer.GetType().Name -ne 'ServiceContainer') {
            throw [System.ArgumentException]::new("Expected ServiceContainer but got $($serviceContainer.GetType().Name)")
        }
        $this.ServiceContainer = $serviceContainer
    }

    # NEW: Get the window stack for rendering
    [object[]] GetWindows() {
        # Build array with current screen at the end (top of stack)
        $windows = @()
        
        # FIXED: Add all screens from navigation stack (bottom to top)
        $stackArray = $this.NavigationStack.ToArray()
        for ($i = $stackArray.Length - 1; $i -ge 0; $i--) {
            $windows += $stackArray[$i]
        }
        
        # Add current screen on top if it exists
        if ($this.CurrentScreen) {
            $windows += $this.CurrentScreen
        }
        
        return $windows
    }

    # IMPORTANT: Update NavigateTo method
    [void] NavigateTo([object]$screen) {
        if ($null -eq $screen) { throw [System.ArgumentNullException]::new("screen", "Cannot navigate to a null screen.") }
        
        # Verify it's actually a Screen at runtime
        if (-not ($screen.PSObject.Properties['ServiceContainer'] -and 
                  $screen.PSObject.Methods['Initialize'] -and
                  $screen.PSObject.Methods['OnEnter'])) {
            throw [System.ArgumentException]::new("Expected Screen-derived object but got $($screen.GetType().Name)")
        }
        
        try {
            # Exit current screen if one exists and push it to the stack
            if ($this.CurrentScreen) {
                $this.CurrentScreen.OnExit()
                $this.NavigationStack.Push($this.CurrentScreen)
            }
            
            # Set the new screen as current
            $this.CurrentScreen = $screen
            
            # Initialize if not already
            if (-not $screen._isInitialized) {
                $screen.Initialize()
                $screen._isInitialized = $true
            }
            
            # Resize screen to match current console dimensions
            $width = $global:TuiState.BufferWidth
            $height = $global:TuiState.BufferHeight
            $screen.Resize($width, $height)
            
            $screen.OnEnter() # Call lifecycle method
            
            # Publish navigation event
            $eventManager = $this.ServiceContainer.GetService("EventManager")
            if ($eventManager) {
                $eventManager.Publish("Navigation.ScreenChanged", @{
                    Screen = $screen
                    ScreenName = $screen.Name
                    StackDepth = $this.NavigationStack.Count
                })
            }
            
            # FIXED: Update global TUI state
            $global:TuiState.CurrentScreen = $screen
            $global:TuiState.IsDirty = $true
            $global:TuiState.FocusedComponent = $null

        }
        catch {
            Write-Error "NavigationService: Failed to navigate to screen '$($screen.Name)': $_"
            throw
        }
    }

    [void] NavigateToByName([string]$screenName) {
        if (-not $this.ScreenRegistry.ContainsKey($screenName)) {
            throw [System.ArgumentException]::new("Screen '$screenName' not found in registry. Registered: $($this.ScreenRegistry.Keys -join ', ').", "screenName")
        }
        
        $this.NavigateTo($this.ScreenRegistry[$screenName])
    }
    
    [bool] CanGoBack() {
        return $this.NavigationStack.Count -gt 0
    }
    
    # IMPORTANT: Update GoBack method
    [void] GoBack() {
        if (-not $this.CanGoBack()) {
            return
        }
        
        try {
            # Exit and cleanup current screen
            $exitingScreen = $this.CurrentScreen
            if ($exitingScreen) {
                $exitingScreen.OnExit()
                $exitingScreen.Cleanup()
            }
            
            # Pop and resume previous screen
            $previousScreen = $this.NavigationStack.Pop()
            $this.CurrentScreen = $previousScreen
            
            # Resize screen to match current console dimensions
            $previousScreen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)

            $previousScreen.OnResume() # Call lifecycle method
            
            # Publish navigation event
            $eventManager = $this.ServiceContainer.GetService("EventManager")
            if ($eventManager) {
                $eventManager.Publish("Navigation.BackNavigation", @{
                    Screen = $previousScreen
                    ScreenName = $previousScreen.Name
                    StackDepth = $this.NavigationStack.Count
                })
            }
            
            # FIXED: Update global TUI state
            $global:TuiState.CurrentScreen = $previousScreen
            $global:TuiState.IsDirty = $true
            $global:TuiState.FocusedComponent = $null

        }
        catch {
            Write-Error "NavigationService: Failed to go back: $_"
            throw
        }
    }
    
    [void] Reset() {
        # Cleanup all screens in stack and current screen
        while ($this.NavigationStack.Count -gt 0) {
            $screen = $this.NavigationStack.Pop()
            try { $screen.Cleanup() } catch { }
        }
        
        if ($this.CurrentScreen) {
            try { 
                $this.CurrentScreen.OnExit()
                $this.CurrentScreen.Cleanup() 
            } catch { }
            $this.CurrentScreen = $null
        }
    }
}

#endregion
#<!-- END_PAGE: ASE.004 -->