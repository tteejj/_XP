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

#region TuiFrameworkService - Framework State Management

# ==============================================================================
# CLASS: TuiFrameworkService
#
# INHERITS: N/A
#
# DEPENDENCIES: None (directly accesses global state)
#
# PURPOSE:
#   Provides a clean service interface for accessing framework state and
#   dimensions instead of components directly accessing $global:TuiState.
#   This encapsulates global state access and provides a more maintainable
#   architecture.
#
# KEY LOGIC:
#   - GetDimensions: Returns current buffer dimensions
#   - GetCurrentScreen: Returns the currently active screen
#   - IsRunning: Returns whether the engine is running
#   - RequestRedraw: Marks the global state as dirty for redraw
#   - GetFrameCount: Returns current frame count for debugging
# ==============================================================================
class TuiFrameworkService {
    [hashtable]$_globalState = $null
    
    TuiFrameworkService() {
        $this._globalState = $global:TuiState
        Write-Log -Level Debug -Message "TuiFrameworkService: Initialized with global state access"
    }
    
    [hashtable] GetDimensions() {
        return @{
            Width = $this._globalState.BufferWidth
            Height = $this._globalState.BufferHeight
        }
    }
    
    [int] GetWidth() {
        return $this._globalState.BufferWidth
    }
    
    [int] GetHeight() {
        return $this._globalState.BufferHeight
    }
    
    [object] GetCurrentScreen() {
        return $this._globalState.CurrentScreen
    }
    
    [bool] IsRunning() {
        return $this._globalState.Running
    }
    
    [void] RequestRedraw() {
        $this._globalState.IsDirty = $true
    }
    
    [int] GetFrameCount() {
        return $this._globalState.FrameCount
    }
    
    [object] GetCompositorBuffer() {
        return $this._globalState.CompositorBuffer
    }
    
    [object] GetFocusedComponent() {
        return $this._globalState.FocusedComponent
    }
    
    [System.Collections.Generic.List[UIElement]] GetOverlayStack() {
        return $this._globalState.OverlayStack
    }
    
    [void] AddOverlay([UIElement]$overlay) {
        $this._globalState.OverlayStack.Add($overlay)
        $this.RequestRedraw()
    }
    
    [bool] RemoveOverlay([UIElement]$overlay) {
        $removed = $this._globalState.OverlayStack.Remove($overlay)
        if ($removed) {
            $this.RequestRedraw()
        }
        return $removed
    }
    
    [void] Cleanup() {
        Write-Log -Level Debug -Message "TuiFrameworkService: Cleanup completed"
        # No cleanup needed - just reports completion
    }
}

#endregion
#<!-- END_PAGE: ASE.010 -->
