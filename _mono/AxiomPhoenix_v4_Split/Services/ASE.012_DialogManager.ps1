# ==============================================================================
# Axiom-Phoenix v4.0 - DialogManager Service
# Manages modal dialogs and the overlay stack
# ==============================================================================

# ===== CLASS: DialogManager =====
# Module: dialog-manager (merged from original ASE.009 with enhancements)
# Dependencies: EventManager, FocusManager
# Purpose: Centralized dialog management with proper focus handling
class DialogManager {
    [System.Collections.Generic.List[UIElement]] $_activeDialogs = [System.Collections.Generic.List[UIElement]]::new()
    [EventManager]$EventManager = $null
    [FocusManager]$FocusManager = $null
    hidden [UIElement]$_previousFocus = $null

    DialogManager([EventManager]$eventManager, [FocusManager]$focusManager) {
        $this.EventManager = $eventManager
        $this.FocusManager = $focusManager
        Write-Log -Level Debug -Message "DialogManager: Initialized."
    }

    [void] ShowDialog([UIElement]$dialog) {
        if ($null -eq $dialog) {
            throw [System.ArgumentException]::new("Provided element is null.", "dialog")
        }
        
        # Store previous focus for restoration
        if ($this.FocusManager) {
            $this._previousFocus = $this.FocusManager.FocusedComponent
        }
        
        # Calculate center position based on console size
        $consoleWidth = $global:TuiState.BufferWidth
        $consoleHeight = $global:TuiState.BufferHeight

        $dialog.X = [Math]::Max(0, [Math]::Floor(($consoleWidth - $dialog.Width) / 2))
        $dialog.Y = [Math]::Max(0, [Math]::Floor(($consoleHeight - $dialog.Height) / 2))

        # If there's a currently focused component, release it
        if ($this.FocusManager) {
            $this.FocusManager.ReleaseFocus() # Release current focus
        }

        # Add to local tracking list and global overlay stack
        $this._activeDialogs.Add($dialog)
        $dialog.Visible = $true
        $dialog.IsOverlay = $true # Mark as an overlay for rendering

        # Explicitly add to global overlay stack
        if (-not $global:TuiState.OverlayStack) {
            $global:TuiState.OverlayStack = [System.Collections.Stack]::new()
        }
        $global:TuiState.OverlayStack.Push($dialog)
        
        # Initialize and enter the dialog if it implements these methods
        if ($dialog.PSObject.Methods['Initialize'] -and -not $dialog._isInitialized) {
            $dialog.Initialize()
            $dialog._isInitialized = $true
        }
        if ($dialog.PSObject.Methods['OnEnter']) {
            $dialog.OnEnter()
        }

        $dialog.RequestRedraw()
        Write-Log -Level Info -Message "DialogManager: Showing dialog '$($dialog.Name)' at X=$($dialog.X), Y=$($dialog.Y)."
        
        # Set focus to the dialog itself or its first focusable child
        if ($this.FocusManager) {
            # Let the dialog class handle finding its first internal focusable
            if ($dialog.PSObject.Methods['SetInitialFocus']) {
                # Force a redraw first to ensure components are ready
                $dialog.RequestRedraw()
                $global:TuiState.IsDirty = $true
                
                # Now set initial focus
                $dialog.SetInitialFocus()
            } else {
                $this.FocusManager.SetFocus($dialog) # Fallback to focusing the dialog container
            }
        }
        
        # Publish event
        if ($this.EventManager) {
            $this.EventManager.Publish("Dialog.Shown", @{ DialogName = $dialog.Name })
        }
    }

    [void] HideDialog([UIElement]$dialog) {
        if ($null -eq $dialog) { return }

        if ($this._activeDialogs.Remove($dialog)) {
            $dialog.Visible = $false
            $dialog.IsOverlay = $false

            # Remove from global overlay stack
            if ($global:TuiState.OverlayStack -and $global:TuiState.OverlayStack.Count -gt 0) {
                if ($global:TuiState.OverlayStack.Peek() -eq $dialog) {
                    $global:TuiState.OverlayStack.Pop() | Out-Null
                } else {
                    Write-Log -Level Warning -Message "Dialog is not at top of overlay stack"
                    # Try to remove it anyway
                    $tempStack = [System.Collections.Stack]::new()
                    while ($global:TuiState.OverlayStack.Count -gt 0) {
                        $item = $global:TuiState.OverlayStack.Pop()
                        if ($item -ne $dialog) {
                            $tempStack.Push($item)
                        }
                    }
                    while ($tempStack.Count -gt 0) {
                        $global:TuiState.OverlayStack.Push($tempStack.Pop())
                    }
                }
            }

            # Call OnExit if the dialog has it
            if ($dialog.PSObject.Methods['OnExit']) {
                $dialog.OnExit()
            }

            # Call Cleanup on the dialog to release its resources
            $dialog.Cleanup()

            # Restore previous focus
            if ($this.FocusManager -and $this._previousFocus) {
                if ($this._previousFocus.Visible -and $this._previousFocus.Enabled) {
                    $this.FocusManager.SetFocus($this._previousFocus)
                }
            }

            $dialog.RequestRedraw() # Force redraw to remove dialog from screen
            $global:TuiState.IsDirty = $true
            
            Write-Log -Level Info -Message "DialogManager: Hiding dialog '$($dialog.Name)'."
            
            # Publish event
            if ($this.EventManager) {
                $this.EventManager.Publish("Dialog.Hidden", @{ DialogName = $dialog.Name })
            }
        } else {
            Write-Log -Level Warning -Message "DialogManager: Attempted to hide a dialog '$($dialog.Name)' that was not active."
        }
    }
    
    [UIElement] GetActiveDialog() {
        if ($this._activeDialogs.Count -gt 0) {
            return $this._activeDialogs[-1]  # Return the most recently shown dialog
        }
        return $null
    }
    
    [bool] HasActiveDialog() {
        return $this._activeDialogs.Count -gt 0
    }
    
    [void] HideAllDialogs() {
        # Use ToArray to avoid collection modification during iteration
        foreach ($dialog in $this._activeDialogs.ToArray()) {
            $this.HideDialog($dialog)
        }
    }

    [void] Cleanup() {
        $this.HideAllDialogs()
        $this._activeDialogs.Clear()
        Write-Log -Level Debug -Message "DialogManager: Cleanup complete."
    }
}

#<!-- END_PAGE: ASE.012 -->
