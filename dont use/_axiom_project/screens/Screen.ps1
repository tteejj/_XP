class Screen : UIElement {
    [hashtable]$Services
    [System.Collections.Generic.Dictionary[string, object]]$State
    [System.Collections.Generic.List[UIElement]]$Panels
    [UIElement]$LastFocusedComponent # <<< ADD THIS LINE
    hidden [System.Collections.Generic.Dictionary[string, string]]$EventSubscriptions

    Screen([string]$name, [hashtable]$services) : base($name) {
        if (-not $services) { throw [ArgumentNullException]::new("services") }
        
        $this.Services = $services
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
    }
    
    [void] Initialize() { }
    [void] OnEnter() { }
    [void] OnExit() { }
    [void] OnResume() { }
    [void] HandleInput([System.ConsoleKeyInfo]$key) { }

    [void] Cleanup() {
        foreach ($kvp in $this.EventSubscriptions.GetEnumerator()) {
            try {
                Unsubscribe-Event -EventName $kvp.Key -SubscriberId $kvp.Value
            }
            catch {
                Write-Log -Level Warning -Message "Failed to unregister event '$($kvp.Key)' for screen '$($this.Name)'."
            }
        }
        $this.EventSubscriptions.Clear()
        $this.Panels.Clear()
        Write-Log -Level Debug -Message "Cleaned up screen: $($this.Name)"
    }
    
    [void] AddPanel([UIElement]$panel) {
        if (-not $panel) { throw [ArgumentNullException]::new("panel") }
        $this.Panels.Add($panel)
    }

    [void] SubscribeToEvent([string]$eventName, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($eventName)) { throw [ArgumentException]::new("Event name cannot be null or empty.") }
        if (-not $action) { throw [ArgumentNullException]::new("action") }
        
        # AI: Fixed parameter name from -Action to -Handler to match event-system.psm1 function signature
        $subscriptionId = Subscribe-Event -EventName $eventName -Handler $action -Source $this.Name
        $this.EventSubscriptions[$eventName] = $subscriptionId
    }
    
    # AI: Override _RenderContent to render all panels to buffer
    hidden [void] _RenderContent() {
        # Call base implementation for buffer management
        ([UIElement]$this)._RenderContent()
        
        # Render all panels in the screen to the back-buffer
        foreach ($panel in $this.Panels) {
            if ($panel.Visible) {
                $panel.Render()
            }
        }
    }
}
