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

#region NavigationService Class

# ===== CLASS: NavigationService =====
# Module: navigation-service (from axiom)
# Dependencies: EventManager (optional)
# Purpose: Screen navigation and history management
class NavigationService {
    [System.Collections.Generic.Stack[Screen]]$NavigationStack = [System.Collections.Generic.Stack[Screen]]::new() # Explicitly initialize
    [Screen]$CurrentScreen
    [EventManager]$EventManager
    [hashtable]$ScreenRegistry = @{}
    [int]$MaxStackSize = 10
    [hashtable]$Services # Added to store access to all services (for creating screens)

    # Add constructor that takes ServiceContainer (or hashtable of services)
    NavigationService([hashtable]$services) {
        $this.Services = $services
        $this.EventManager = $services.EventManager # Get EventManager if present
    }

    # IMPORTANT: Update NavigateTo method
    [void] NavigateTo([Screen]$screen) {
        if ($null -eq $screen) { throw [System.ArgumentNullException]::new("screen", "Cannot navigate to a null screen.") }
        
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
            if ($this.EventManager) {
                $this.EventManager.Publish("Navigation.ScreenChanged", @{
                    Screen = $screen
                    ScreenName = $screen.Name
                    StackDepth = $this.NavigationStack.Count
                })
            }
            
            # Update global TUI state (CRITICAL FIX)
            $global:TuiState.CurrentScreen = $screen
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
            if ($this.CurrentScreen) {
                # Write-Log -Level Debug -Message "NavigationService: Exiting screen '$($this.CurrentScreen.Name)' (going back)"
                $this.CurrentScreen.OnExit()
                $this.CurrentScreen.Cleanup() # Clean up the screen being exited/popped
            }
            
            # Pop and resume previous screen
            $previousScreen = $this.NavigationStack.Pop()
            $this.CurrentScreen = $previousScreen
            
            # Write-Log -Level Debug -Message "NavigationService: Resuming screen '$($previousScreen.Name)'"
            
            # Resize screen to match current console dimensions
            $previousScreen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)

            $previousScreen.OnResume() # Call lifecycle method
            
            # Publish navigation event
            if ($this.EventManager) {
                $this.EventManager.Publish("Navigation.BackNavigation", @{
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
