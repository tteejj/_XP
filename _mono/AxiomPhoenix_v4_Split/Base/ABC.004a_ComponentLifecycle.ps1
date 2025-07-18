# ==============================================================================
# Axiom-Phoenix v4.0 - Component Lifecycle Management
# Proper Initialize/Dispose pattern with cleanup and resource management
# ==============================================================================

using namespace System.Collections.Generic

#region Lifecycle Interfaces

# Component lifecycle states
enum ComponentState {
    Uninitialized
    Initializing
    Initialized
    Disposing
    Disposed
}

# Component lifecycle interface
# IComponentLifecycle - Components that need lifecycle management
#   GetState() -> ComponentState
#   Initialize() -> void
#   Dispose() -> void
#   IsDisposed() -> bool

# Resource cleanup interface  
# IResourceCleanup - Components that manage resources
#   CleanupResources() -> void
#   GetManagedResources() -> string[]

#endregion

#region Enhanced UIElement Base Class

class LifecycleAwareUIElement : UIElement {
    hidden [ComponentState] $_state = [ComponentState]::Uninitialized
    hidden [List[string]] $_managedResources = [List[string]]::new()
    hidden [List[object]] $_eventSubscriptions = [List[object]]::new()
    hidden [hashtable] $_timers = @{}
    hidden [bool] $_disposed = $false
    
    LifecycleAwareUIElement([string]$name) : base($name) {
        # Initialize lifecycle tracking
        $this._state = [ComponentState]::Uninitialized
    }
    
    # Lifecycle state management
    [ComponentState] GetState() {
        return $this._state
    }
    
    [bool] IsDisposed() {
        return $this._disposed
    }
    
    # Enhanced initialization with error handling
    [void] Initialize() {
        if ($this._state -ne [ComponentState]::Uninitialized) {
            return
        }
        
        $this._state = [ComponentState]::Initializing
        
        try {
            # Call derived class initialization
            $this.OnInitialize()
            
            # Setup default event handlers
            $this.SetupEventHandlers()
            
            $this._state = [ComponentState]::Initialized
            Write-Log -Level Debug -Message "Component '$($this.Name)' initialized successfully"
        } catch {
            $this._state = [ComponentState]::Uninitialized
            Write-Log -Level Error -Message "Component '$($this.Name)' initialization failed: $($_.Exception.Message)"
            throw
        }
    }
    
    # Virtual method for derived classes to override
    [void] OnInitialize() {
        # Default implementation - override in derived classes
    }
    
    # Setup default event handlers
    [void] SetupEventHandlers() {
        # Track focus events for cleanup
        if ($this.IsFocusable) {
            $this.RegisterEventHandler('OnFocus', {
                param($sender, $args)
                Request-OptimizedRedraw -Source "Component:$($sender.Name):Focus"
            })
            
            $this.RegisterEventHandler('OnBlur', {
                param($sender, $args)
                Request-OptimizedRedraw -Source "Component:$($sender.Name):Blur"
            })
        }
    }
    
    # Event handler registration with cleanup tracking
    [void] RegisterEventHandler([string]$eventName, [scriptblock]$handler) {
        $subscription = @{
            EventName = $eventName
            Handler = $handler
            RegisteredAt = [DateTime]::Now
        }
        $this._eventSubscriptions.Add($subscription)
    }
    
    # Resource tracking
    [void] AddManagedResource([string]$resourceId) {
        $this._managedResources.Add($resourceId)
    }
    
    [string[]] GetManagedResources() {
        return $this._managedResources.ToArray()
    }
    
    # Timer management
    [void] StartTimer([string]$timerId, [int]$intervalMs, [scriptblock]$callback) {
        if ($this._timers.ContainsKey($timerId)) {
            $this.StopTimer($timerId)
        }
        
        $timer = [System.Timers.Timer]::new($intervalMs)
        $timer.AutoReset = $true
        $timer.Enabled = $true
        
        # Use event handler that keeps component reference
        $timer.add_Elapsed({
            param($sender, $args)
            try {
                & $callback
            } catch {
                Write-Log -Level Error -Message "Timer '$timerId' callback error: $($_.Exception.Message)"
            }
        })
        
        $this._timers[$timerId] = $timer
        $this.AddManagedResource("Timer:$timerId")
    }
    
    [void] StopTimer([string]$timerId) {
        if ($this._timers.ContainsKey($timerId)) {
            $timer = $this._timers[$timerId]
            $timer.Stop()
            $timer.Dispose()
            $this._timers.Remove($timerId)
        }
    }
    
    # Resource cleanup implementation
    [void] CleanupResources() {
        try {
            # Stop and dispose all timers
            foreach ($kvp in $this._timers.GetEnumerator()) {
                $kvp.Value.Stop()
                $kvp.Value.Dispose()
            }
            $this._timers.Clear()
            
            # Cleanup event subscriptions
            $this._eventSubscriptions.Clear()
            
            # Clear managed resources
            $this._managedResources.Clear()
            
            Write-Log -Level Debug -Message "Component '$($this.Name)' resources cleaned up"
        } catch {
            Write-Log -Level Warning -Message "Error cleaning up resources for '$($this.Name)': $($_.Exception.Message)"
        }
    }
    
    # Enhanced disposal with lifecycle management
    [void] Dispose() {
        if ($this._disposed -or $this._state -eq [ComponentState]::Disposed) {
            return
        }
        
        $this._state = [ComponentState]::Disposing
        
        try {
            # Call derived class cleanup
            $this.OnDispose()
            
            # Cleanup managed resources
            $this.CleanupResources()
            
            # Dispose child components
            if ($this.Children) {
                foreach ($child in $this.Children) {
                    if ($child.PSObject.Methods['Dispose']) {
                        $child.Dispose()
                    }
                }
                $this.Children.Clear()
            }
            
            $this._state = [ComponentState]::Disposed
            $this._disposed = $true
            
            Write-Log -Level Debug -Message "Component '$($this.Name)' disposed successfully"
        } catch {
            Write-Log -Level Error -Message "Component '$($this.Name)' disposal failed: $($_.Exception.Message)"
            $this._disposed = $true
        }
    }
    
    # Virtual method for derived classes to override
    [void] OnDispose() {
        # Default implementation - override in derived classes
    }
    
    # Health check for component
    [hashtable] HealthCheck() {
        return @{
            Name = $this.Name
            State = $this._state
            IsDisposed = $this._disposed
            ManagedResources = $this._managedResources.Count
            EventSubscriptions = $this._eventSubscriptions.Count
            ActiveTimers = $this._timers.Count
            ChildComponents = if ($this.Children) { $this.Children.Count } else { 0 }
            MemoryUsage = [GC]::GetTotalMemory($false)
        }
    }
}

#endregion

#endregion

# Screen lifecycle management will be loaded later after Screen class is available

Write-Host "Component Lifecycle Management system loaded" -ForegroundColor Green