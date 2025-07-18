# ==============================================================================
# Axiom-Phoenix v4.0 - Error Boundary Components
# React-style error boundaries for component error recovery
# ==============================================================================

using namespace System.Collections.Generic

#region Error Boundary Interface

# IErrorBoundary interface
# Components that handle errors from child components
#   HasError() -> bool
#   GetLastError() -> object
#   ClearError() -> void
#   OnComponentError(component, error) -> void

# Error recovery strategies
enum ErrorRecoveryStrategy {
    None
    Retry
    Fallback
    Hide
    Replace
}

#endregion

#region Error Boundary Component

class ErrorBoundaryComponent : LifecycleAwareUIElement {
    hidden [bool] $_hasError = $false
    hidden [System.Exception] $_lastError = $null
    hidden [object] $_failedComponent = $null
    hidden [ErrorRecoveryStrategy] $_recoveryStrategy = [ErrorRecoveryStrategy]::Fallback
    hidden [UIElement] $_fallbackComponent = $null
    hidden [int] $_retryCount = 0
    hidden [int] $_maxRetries = 3
    hidden [List[object]] $_errorLog = [List[object]]::new()
    
    ErrorBoundaryComponent([string]$name) : base($name) {
        $this.IsFocusable = $false
        $this.Width = 0
        $this.Height = 0
    }
    
    # Error state management
    [bool] HasError() {
        return $this._hasError
    }
    
    [object] GetLastError() {
        return $this._lastError
    }
    
    [void] ClearError() {
        $this._hasError = $false
        $this._lastError = $null
        $this._failedComponent = $null
        $this._retryCount = 0
    }
    
    # Configure error recovery
    [void] SetRecoveryStrategy([ErrorRecoveryStrategy]$strategy) {
        $this._recoveryStrategy = $strategy
    }
    
    [void] SetFallbackComponent([UIElement]$component) {
        $this._fallbackComponent = $component
    }
    
    [void] SetMaxRetries([int]$maxRetries) {
        $this._maxRetries = $maxRetries
    }
    
    # Error handling implementation
    [void] OnComponentError([object]$component, [System.Exception]$error) {
        $this._hasError = $true
        $this._lastError = $error
        $this._failedComponent = $component
        
        # Log the error
        $errorEntry = @{
            Timestamp = [DateTime]::Now
            Component = $component.Name
            Error = $error.Message
            StackTrace = $error.StackTrace
            RetryCount = $this._retryCount
        }
        $this._errorLog.Add($errorEntry)
        
        Write-Log -Level Error -Message "Error boundary caught error in component '$($component.Name)': $($error.Message)"
        
        # Apply recovery strategy
        switch ($this._recoveryStrategy) {
            ([ErrorRecoveryStrategy]::Retry) {
                $this.TryRetryComponent()
            }
            ([ErrorRecoveryStrategy]::Fallback) {
                $this.ShowFallbackComponent()
            }
            ([ErrorRecoveryStrategy]::Hide) {
                $this.HideFailedComponent()
            }
            ([ErrorRecoveryStrategy]::Replace) {
                $this.ReplaceFailedComponent()
            }
            default {
                # None - just log the error
                Write-Log -Level Warning -Message "Error boundary using no recovery strategy for component '$($component.Name)'"
            }
        }
        
        # Request redraw to show error state
        Request-OptimizedRedraw -Source "ErrorBoundary:$($this.Name)"
    }
    
    # Recovery strategy implementations
    [void] TryRetryComponent() {
        if ($this._retryCount -lt $this._maxRetries) {
            $this._retryCount++
            Write-Log -Level Info -Message "Error boundary retrying component '$($this._failedComponent.Name)' (attempt $($this._retryCount)/$($this._maxRetries))"
            
            try {
                # Try to reinitialize the component
                if ($this._failedComponent.PSObject.Methods['Initialize']) {
                    $this._failedComponent.Initialize()
                }
                
                # If successful, clear error
                $this.ClearError()
            } catch {
                Write-Log -Level Warning -Message "Error boundary retry failed for component '$($this._failedComponent.Name)': $($_.Exception.Message)"
                
                # If max retries reached, switch to fallback
                if ($this._retryCount -ge $this._maxRetries) {
                    $this.ShowFallbackComponent()
                }
            }
        }
    }
    
    [void] ShowFallbackComponent() {
        if ($this._fallbackComponent -and $this._failedComponent) {
            # Replace failed component with fallback
            $parent = $this._failedComponent.Parent
            if ($parent) {
                $index = $parent.Children.IndexOf($this._failedComponent)
                if ($index -ge 0) {
                    $parent.Children[$index] = $this._fallbackComponent
                    $this._fallbackComponent.Parent = $parent
                }
            }
            
            Write-Log -Level Info -Message "Error boundary showing fallback component for '$($this._failedComponent.Name)'"
        }
    }
    
    [void] HideFailedComponent() {
        if ($this._failedComponent) {
            $this._failedComponent.Visible = $false
            Write-Log -Level Info -Message "Error boundary hiding failed component '$($this._failedComponent.Name)'"
        }
    }
    
    [void] ReplaceFailedComponent() {
        if ($this._failedComponent -and $this._fallbackComponent) {
            # Create a new instance of the same type
            try {
                $componentType = $this._failedComponent.GetType()
                $newComponent = $componentType::new($this._failedComponent.Name + "_Recovered")
                
                # Copy basic properties
                $newComponent.X = $this._failedComponent.X
                $newComponent.Y = $this._failedComponent.Y
                $newComponent.Width = $this._failedComponent.Width
                $newComponent.Height = $this._failedComponent.Height
                $newComponent.Visible = $this._failedComponent.Visible
                
                # Replace in parent
                $parent = $this._failedComponent.Parent
                if ($parent) {
                    $index = $parent.Children.IndexOf($this._failedComponent)
                    if ($index -ge 0) {
                        $parent.Children[$index] = $newComponent
                        $newComponent.Parent = $parent
                    }
                }
                
                Write-Log -Level Info -Message "Error boundary replaced failed component '$($this._failedComponent.Name)' with new instance"
                $this.ClearError()
            } catch {
                Write-Log -Level Error -Message "Error boundary failed to replace component: $($_.Exception.Message)"
                $this.ShowFallbackComponent()
            }
        }
    }
    
    # Override render to show error state
    [void] OnRender() {
        if ($this._hasError -and $this.Visible) {
            # Render error indicator
            $errorMessage = "⚠️ Error in component"
            if ($this._failedComponent) {
                $errorMessage += ": $($this._failedComponent.Name)"
            }
            
            if ($this.Buffer) {
                $fgColor = if (Get-Command 'Get-ThemeColor' -ErrorAction SilentlyContinue) { Get-ThemeColor "status.error" "#FF0000" } else { "#FF0000" }
                $bgColor = if (Get-Command 'Get-ThemeColor' -ErrorAction SilentlyContinue) { Get-ThemeColor "panel.background" "#000000" } else { "#000000" }
                $this.Buffer.WriteString(0, 0, $errorMessage, $fgColor, $bgColor)
            }
        }
    }
    
    # Error reporting
    [hashtable] GetErrorReport() {
        return @{
            HasError = $this._hasError
            LastError = if ($this._lastError) { $this._lastError.Message } else { $null }
            FailedComponent = if ($this._failedComponent) { $this._failedComponent.Name } else { $null }
            RecoveryStrategy = $this._recoveryStrategy
            RetryCount = $this._retryCount
            MaxRetries = $this._maxRetries
            ErrorHistory = $this._errorLog.ToArray()
        }
    }
    
    # Cleanup on dispose
    [void] OnDispose() {
        $this._errorLog.Clear()
        $this._failedComponent = $null
        $this._fallbackComponent = $null
        $this._lastError = $null
    }
}

#endregion

#region Error Boundary Helpers

# Wrap component in error boundary
function New-ErrorBoundary {
    param(
        [UIElement]$Component,
        [ErrorRecoveryStrategy]$Strategy = [ErrorRecoveryStrategy]::Fallback,
        [UIElement]$FallbackComponent = $null,
        [int]$MaxRetries = 3
    )
    
    $boundary = [ErrorBoundaryComponent]::new("ErrorBoundary_$($Component.Name)")
    $boundary.SetRecoveryStrategy($Strategy)
    $boundary.SetMaxRetries($MaxRetries)
    
    if ($FallbackComponent) {
        $boundary.SetFallbackComponent($FallbackComponent)
    }
    
    # Wrap the component
    $boundary.AddChild($Component)
    
    return $boundary
}

# Create fallback component for errors
function New-ErrorFallback {
    param(
        [string]$Name,
        [string]$Message = "Component unavailable",
        [int]$Width = 20,
        [int]$Height = 3
    )
    
    $fallback = [LabelComponent]::new($Name)
    $fallback.Text = $Message
    $fallback.Width = $Width
    $fallback.Height = $Height
    $fallback.ForegroundColor = Get-ThemeColor "status.warning" "#FFAA00"
    $fallback.BackgroundColor = Get-ThemeColor "panel.background" "#000000"
    
    return $fallback
}

#endregion

Write-Host "Error Boundary system loaded" -ForegroundColor Green