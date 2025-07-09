# Fixed FocusManager.SetFocus method - ensure no complex objects in events
[void] SetFocus([UIElement]$component) {
    if ($this.FocusedComponent -eq $component) {
        return
    }
    
    if ($null -ne $this.FocusedComponent) {
        $previousName = $this.FocusedComponent.Name
        $this.FocusedComponent.IsFocused = $false
        $this.FocusedComponent.OnBlur()
        $this.FocusedComponent.RequestRedraw()
    }

    $this.FocusedComponent = $null
    if ($null -ne $component -and $component.IsFocusable -and $component.Enabled -and $component.Visible) {
        $this.FocusedComponent = $component
        $component.IsFocused = $true
        $component.OnFocus()
        $component.RequestRedraw()
        
        # CRITICAL: Only pass simple data types in events
        if ($this.EventManager) {
            $this.EventManager.Publish("Focus.Changed", @{ 
                ComponentName = $component.Name
                ComponentType = $component.GetType().Name 
            })
        }
    }
    $global:TuiState.IsDirty = $true
}
