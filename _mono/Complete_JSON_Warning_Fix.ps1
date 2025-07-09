# Axiom-Phoenix v4.0 - JSON Serialization Warning Fix
# Apply these changes to eliminate "JSON is truncated" warnings

# ============================================
# 1. In Start.ps1 - Add at the very beginning
# ============================================
# Disable verbose output to prevent JSON serialization warnings
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'

# Only enable verbose output if explicitly requested
if ($env:AXIOM_VERBOSE -eq '1') {
    $VerbosePreference = 'Continue'
}

# ============================================
# 2. In Start.ps1 - After creating Logger
# ============================================
# Find this line:
# $logger = [Logger]::new()
# Add after it:
$logger.MinimumLevel = "Info"  # Only log Info, Warning, Error, Fatal
$logger.EnableConsoleLogging = $false  # Disable console logging by default

# ============================================
# 3. In AllServices.ps1 - Replace FocusManager.SetFocus method
# ============================================
# Find the SetFocus method in FocusManager class and replace it entirely with:
[void] SetFocus([UIElement]$component) {
    if ($this.FocusedComponent -eq $component) {
        return
    }
    
    if ($null -ne $this.FocusedComponent) {
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
                ComponentName = if ($component.Name) { $component.Name } else { "Unnamed" }
                ComponentType = $component.GetType().Name 
            })
        }
    }
    $global:TuiState.IsDirty = $true
}

# ============================================
# 4. In AllServices.ps1 - Replace EventManager.Publish method
# ============================================
# Find the Publish method in EventManager class and replace it with the sanitized version:
[void] Publish([string]$eventName, [hashtable]$eventData = @{}) {
    # Sanitize event data to prevent circular reference issues
    $sanitizedData = @{}
    foreach ($key in $eventData.Keys) {
        $value = $eventData[$key]
        if ($value -is [string] -or $value -is [int] -or $value -is [double] -or 
            $value -is [bool] -or $value -is [datetime] -or $value -eq $null) {
            # Simple types are safe
            $sanitizedData[$key] = $value
        }
        elseif ($value -is [UIElement]) {
            # Never store UIElement objects
            $sanitizedData[$key] = "[UIElement: $($value.Name)]"
        }
        else {
            # For other complex types, just store the type name
            $sanitizedData[$key] = "[Object: $($value.GetType().Name)]"
        }
    }
    
    # Add to history if enabled (using sanitized data)
    if ($this.EnableHistory) {
        $historyEntry = @{
            EventName = $eventName
            EventData = $sanitizedData
            Timestamp = [DateTime]::Now
            HandlerCount = 0
        }
        
        $this.EventHistory.Add($historyEntry)
        
        if ($this.EventHistory.Count -gt $this.MaxHistorySize) {
            $this.EventHistory.RemoveAt(0)
        }
    }
    
    # Execute handlers with original data
    if ($this.EventHandlers.ContainsKey($eventName)) {
        $handlers = @($this.EventHandlers[$eventName].GetEnumerator())
        
        if ($this.EnableHistory -and $this.EventHistory.Count -gt 0) {
            $this.EventHistory[-1].HandlerCount = $handlers.Count
        }
        
        foreach ($entry in $handlers) {
            try {
                $handlerData = $entry.Value
                $handlerData.ExecutionCount++
                & $handlerData.Handler $eventData
            }
            catch {
                # Log errors without complex data
                if ($global:TuiState.Services.Logger) {
                    $global:TuiState.Services.Logger.Log(
                        "EventManager: Error in handler '$($entry.Key)' for event '$eventName': $($_.Exception.Message)", 
                        "Error"
                    )
                }
            }
        }
    }
}

# ============================================
# 5. OPTIONAL: Disable EventManager history entirely
# ============================================
# In Start.ps1, after creating EventManager:
# $eventManager = [EventManager]::new()
# Add:
$eventManager.EnableHistory = $false  # Disable event history to prevent any serialization
