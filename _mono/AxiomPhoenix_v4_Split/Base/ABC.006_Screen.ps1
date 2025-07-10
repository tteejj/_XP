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
    [hashtable]$Services
    [object]$ServiceContainer 
    [System.Collections.Generic.Dictionary[string, object]]$State
    [System.Collections.Generic.List[UIElement]] $Panels
    
    $LastFocusedComponent
    
    hidden [bool] $_isInitialized = $false
    hidden [System.Collections.Generic.Dictionary[string, string]] $EventSubscriptions 

    Screen([string]$name, [hashtable]$services) : base($name) {
        $this.Services = $services
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        $this.ServiceContainer = $null
        # Set initial screen dimensions to console size
        $this.Width = [Math]::Max(80, [Console]::WindowWidth)
        $this.Height = [Math]::Max(24, [Console]::WindowHeight)
        # Write-Verbose "Screen '$($this.Name)' created with hashtable services."
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
                # Write-Verbose "Screen '$($this.Name)' populated Services hashtable from ServiceContainer."
            } catch {
                Write-Warning "Screen '$($this.Name)': Failed to enumerate services from container: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Screen '$($this.Name)' received a non-ServiceContainer object for DI. Services hashtable might be incomplete or inaccurate."
        }
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        # Set initial screen dimensions to console size
        $this.Width = [Math]::Max(80, [Console]::WindowWidth)
        $this.Height = [Math]::Max(24, [Console]::WindowHeight)
        # Write-Verbose "Screen '$($this.Name)' created with ServiceContainer."
    }

    [void] Initialize() { 
        # Write-Verbose "Initialize called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnEnter() { 
        # Write-Verbose "OnEnter called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnExit() { 
        # Write-Verbose "OnExit called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnResume() { 
        # Write-Verbose "OnResume called for Screen '$($this.Name)': Default (no-op)." 
    }

    [void] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Write-Verbose "HandleInput called for Screen '$($this.Name)': Key: $($keyInfo.Key). Default (no-op)."
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
