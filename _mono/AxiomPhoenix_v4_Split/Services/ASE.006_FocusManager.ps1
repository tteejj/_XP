# ==============================================================================
# Axiom-Phoenix v4.0 - FocusManager Stub Service
# DEPRECATED: This service is no longer used. Screens manage their own focus.
# This stub exists only to prevent errors during transition.
# ==============================================================================

# ==============================================================================
# DEPRECATION NOTICE:
# FocusManager has been removed from the framework. The ncurses window model
# means each Screen manages its own focus internally. This stub service exists
# only to prevent errors in code that hasn't been updated yet.
#
# DO NOT USE THIS SERVICE IN NEW CODE!
# ==============================================================================

class FocusManager {
    hidden [string] $_warningShown = $false
    
    FocusManager() {
        Write-Log -Level Warning -Message "FocusManager is DEPRECATED. Screens should manage their own focus."
    }
    
    # Stub methods that do nothing but log warnings
    [void] SetFocus([object]$component) {
        if (-not $this._warningShown) {
            Write-Log -Level Warning -Message "FocusManager.SetFocus called - this service is deprecated. Update your screen to manage focus internally."
            $this._warningShown = $true
        }
    }
    
    [object] GetFocusedComponent() {
        if (-not $this._warningShown) {
            Write-Log -Level Warning -Message "FocusManager.GetFocusedComponent called - this service is deprecated."
            $this._warningShown = $true
        }
        return $null
    }
    
    [void] ClearFocus() {
        if (-not $this._warningShown) {
            Write-Log -Level Warning -Message "FocusManager.ClearFocus called - this service is deprecated."
            $this._warningShown = $true
        }
    }
    
    [void] FocusNext() {
        if (-not $this._warningShown) {
            Write-Log -Level Warning -Message "FocusManager.FocusNext called - this service is deprecated."
            $this._warningShown = $true
        }
    }
    
    [void] FocusPrevious() {
        if (-not $this._warningShown) {
            Write-Log -Level Warning -Message "FocusManager.FocusPrevious called - this service is deprecated."
            $this._warningShown = $true
        }
    }
    
    [bool] IsFocusedComponent([object]$component) {
        return $false
    }
}

# ==============================================================================
# END OF DEPRECATED FOCUSMANAGER
# ==============================================================================
