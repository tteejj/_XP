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
    [System.Collections.Generic.Stack[object]]$NavigationStack = [System.Collections.Generic.Stack[object]]::new() # Changed from Stack[Screen] to Stack[object]
    [object]$CurrentScreen # Changed from [Screen] to [object]
    [hashtable]$ScreenRegistry = @{}
    [int]$MaxStackSize = 10
    [object]$ServiceContainer # Store the container as object to avoid type issues

    # Updated constructor that takes ServiceContainer directly (as object to avoid type conversion issues)
    NavigationService([object]$serviceContainer) {
        if ($null -eq $serviceContainer) {
            throw [System.ArgumentNullException]::new("serviceContainer")
        }
        # Verify it's actually a ServiceContainer at runtime
        if ($serviceContainer.GetType().Name -ne 'ServiceContainer') {
            throw [System.ArgumentException]::new("Expected ServiceContainer but got $($serviceContainer.GetType().Name)")
        }
        $this.ServiceContainer = $serviceContainer
        # No need to store EventManager separately - get it when needed
    }

    # NEW: Get the window stack for rendering
    [object[]] GetWindows() {
        # Build array with current screen at the end (top of stack)
        $windows = @()
        
        # Add all screens from navigation stack (bottom to top)
        $stackArray = $this.NavigationStack.ToArray()
        for ($i = $stackArray.Length - 1; $i -ge 0; $i--) {
            $windows += $stackArray[$i]
        }
        
        # Add current screen on top
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
            # Exit current screen if one exists
            if ($this.CurrentScreen) {
                # Write-Log -Level Debug -Message "NavigationService: Exiting screen '$($this.CurrentScreen.Name)'"
                $this.CurrentScreen.OnExit()
                $this.NavigationStack.Push($this.CurrentScreen)
                
                # Limit stack size (optional, complex to trim from bottom of Stack)
                # If MaxStackSize is critical, consider switching NavigationStack to List<Screen> and managing explicitly.
            }
            
            # Enter new screen
            $this.CurrentScreen = $screen
            # Write-Log -Level Debug -Message "NavigationService: Entering screen '$($screen.Name)'"
            
            # Initialize if not already (screens passed via registry should be initialized via factory)
            if (-not $screen._isInitialized) {
                # Write-Log -Level Debug -Message "NavigationService: Initializing screen '$($screen.Name)'"
                $screen.Initialize()
                $screen._isInitialized = $true
            }
            
            # Resize screen to match current console dimensions
            $width = [Math]::Max(80, $global:TuiState.BufferWidth)
            $height = [Math]::Max(24, $global:TuiState.BufferHeight)
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
            
            # Update global TUI state (CRITICAL FIX)
            Write-Log -Level Debug -Message "NavigationService: Setting CurrentScreen to $($screen.Name)"
            $global:TuiState.CurrentScreen = $screen
            Write-Log -Level Debug -Message "NavigationService: CurrentScreen is now $($global:TuiState.CurrentScreen?.Name)"
            $global:TuiState.IsDirty = $true # Force redraw
            $global:TuiState.FocusedComponent = $null # Clear focus, screen OnEnter should set new focus

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
            # Write-Log -Level Warning -Message "NavigationService: Cannot go back - navigation stack is empty"
            return
        }
        
        try {
            # Exit current screen
            $exitingScreen = $this.CurrentScreen
            if ($exitingScreen) {
                # Write-Log -Level Debug -Message "NavigationService: Exiting screen '$($exitingScreen.Name)' (going back)"
                $exitingScreen.OnExit()
                $exitingScreen.Cleanup() # Clean up the screen being exited/popped
            }
            
            # Pop and resume previous screen
            $previousScreen = $this.NavigationStack.Pop()
            $this.CurrentScreen = $previousScreen
            
            # Write-Log -Level Debug -Message "NavigationService: Resuming screen '$($previousScreen.Name)'"
            
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
            
            # Update global TUI state (CRITICAL FIX)
            $global:TuiState.CurrentScreen = $previousScreen
            $global:TuiState.IsDirty = $true # Force redraw
            $global:TuiState.FocusedComponent = $null # Clear focus, screen OnResume should set new focus

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
            try { $screen.Cleanup() } catch { # Write-Log -Level Warning -Message "NavigationService: Error cleaning up stacked screen '$($screen.Name)': $($_.Exception.Message)" }
            }
        }
        
        if ($this.CurrentScreen) {
            try { 
                $this.CurrentScreen.OnExit()
                $this.CurrentScreen.Cleanup() 
            } catch { # Write-Log -Level Warning -Message "NavigationService: Error cleaning up current screen '$($this.CurrentScreen.Name)': $($_.Exception.Message)" }
            }
            $this.CurrentScreen = $null
        }
        # Write-Log -Level Debug -Message "NavigationService: Reset complete, all screens cleaned up."
    }
}

#endregion
#<!-- END_PAGE: ASE.004 -->
