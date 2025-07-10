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

#region Additional Service Classes

# ===== CLASS: FocusManager =====
# Module: focus-manager (new service)
# Dependencies: EventManager (optional)
# Purpose: Centralized focus management for UI components
class FocusManager {
    [UIElement]$FocusedComponent = $null
    [EventManager]$EventManager = $null

    FocusManager([EventManager]$eventManager) {
        $this.EventManager = $eventManager
        # Write-Log -Level Debug -Message "FocusManager: Initialized."
    }

    [void] SetFocus([UIElement]$component) {
        $componentName = if ($null -ne $component) { $component.Name } else { 'null' }
        Write-Log -Level Debug -Message "FocusManager.SetFocus called with: $componentName"
        
        if ($this.FocusedComponent -eq $component) {
            Write-Log -Level Debug -Message "  - Already focused, returning"
            return
        }
        
        if ($null -ne $this.FocusedComponent) {
            Write-Log -Level Debug -Message "  - Removing focus from: $($this.FocusedComponent.Name)"
            $this.FocusedComponent.IsFocused = $false
            $this.FocusedComponent.OnBlur()
            $this.FocusedComponent.RequestRedraw()
        }

        $this.FocusedComponent = $null
        if ($null -ne $component -and $component.IsFocusable -and $component.Enabled -and $component.Visible) {
            Write-Log -Level Debug -Message "  - Setting focus to: $($component.Name)"
            Write-Log -Level Debug -Message "    - IsFocusable: $($component.IsFocusable)"
            Write-Log -Level Debug -Message "    - Enabled: $($component.Enabled)"
            Write-Log -Level Debug -Message "    - Visible: $($component.Visible)"
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
            Write-Log -Level Debug -Message "  - Focus set successfully"
        } else {
            Write-Log -Level Debug -Message "  - Focus NOT set. Component check failed:"
            Write-Log -Level Debug -Message "    - Component null: $($null -eq $component)"
            if ($null -ne $component) {
                Write-Log -Level Debug -Message "    - IsFocusable: $($component.IsFocusable)"
                Write-Log -Level Debug -Message "    - Enabled: $($component.Enabled)"
                Write-Log -Level Debug -Message "    - Visible: $($component.Visible)"
            }
        }
        $global:TuiState.IsDirty = $true
    }

    [void] MoveFocus([bool]$reverse = $false) {
        if (-not $global:TuiState.CurrentScreen) { return }

        $focusableComponents = [System.Collections.Generic.List[UIElement]]::new()
        
        # Helper to recursively find all focusable components within the current screen
        function Find-Focusable([UIElement]$comp, [System.Collections.Generic.List[UIElement]]$list) {
            if ($comp -and $comp.IsFocusable -and $comp.Visible -and $comp.Enabled) {
                $list.Add($comp)
            }
            foreach ($child in $comp.Children) { Find-Focusable $child $list }
        }
        
        Find-Focusable $global:TuiState.CurrentScreen $focusableComponents
        
        if ($focusableComponents.Count -eq 0) {
            $this.SetFocus($null) # Clear focus if no focusable components
            return
        }
        
        # Sort components by TabIndex, then Y, then X for consistent order
        $sorted = $focusableComponents | Sort-Object { $_.TabIndex * 10000 + $_.Y * 100 + $_.X }

        $currentIndex = -1
        if ($this.FocusedComponent) {
            for ($i = 0; $i -lt $sorted.Count; $i++) {
                if ($sorted[$i] -eq $this.FocusedComponent) {
                    $currentIndex = $i
                    break
                }
            }
        }
        
        $nextIndex = -1
        if ($reverse) {
            $nextIndex = ($currentIndex - 1 + $sorted.Count) % $sorted.Count
        } else {
            $nextIndex = ($currentIndex + 1) % $sorted.Count
        }

        # If no component was focused or current one not found, default to first/last
        if ($currentIndex -eq -1) {
            $nextIndex = if ($reverse) { $sorted.Count - 1 } else { 0 }
        }

        $this.SetFocus($sorted[$nextIndex])
    }

    [void] ReleaseFocus() {
        $this.SetFocus($null)
        # Write-Log -Level Debug -Message "FocusManager: All focus released."
    }

    [void] Cleanup() {
        $this.FocusedComponent = $null
        # Write-Log -Level Debug -Message "FocusManager: Cleanup complete."
    }
}

# ===== CLASS: DialogManager =====
# Module: dialog-manager (new service)
# Dependencies: EventManager, FocusManager
# Purpose: Centralized dialog management
class DialogManager {
    [System.Collections.Generic.List[UIElement]] $_activeDialogs = [System.Collections.Generic.List[UIElement]]::new()
    [EventManager]$EventManager = $null
    [FocusManager]$FocusManager = $null
    hidden [UIElement]$_previousFocus = $null

    DialogManager([EventManager]$eventManager, [FocusManager]$focusManager) {
        $this.EventManager = $eventManager
        $this.FocusManager = $focusManager
        # Write-Log -Level Debug -Message "DialogManager: Initialized."
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
        $global:TuiState.OverlayStack.Add($dialog)
        
        # Initialize and enter the dialog if it implements these methods
        if ($dialog.PSObject.Methods['Initialize'] -and -not $dialog._isInitialized) {
            $dialog.Initialize()
            $dialog._isInitialized = $true
        }
        if ($dialog.PSObject.Methods['OnEnter']) {
            $dialog.OnEnter()
        }

        $dialog.RequestRedraw()
        # Write-Log -Level Info -Message "DialogManager: Showing dialog '$($dialog.Name)' at X=$($dialog.X), Y=$($dialog.Y)."
        
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
    }

    [void] HideDialog([UIElement]$dialog) {
        if ($null -eq $dialog) { return }

        if ($this._activeDialogs.Remove($dialog)) {
            $dialog.Visible = $false
            $dialog.IsOverlay = $false

            # Remove from global overlay stack
            if ($global:TuiState.OverlayStack.Contains($dialog)) {
                $global:TuiState.OverlayStack.Remove($dialog)
            }

            # Call Cleanup on the dialog to release its resources
            $dialog.Cleanup()

            # Restore previous focus
            if ($this.FocusManager) {
                $this.FocusManager.SetFocus($this._previousFocus)
            }

            $dialog.RequestRedraw() # Force redraw to remove dialog from screen
            # Write-Log -Level Info -Message "DialogManager: Hiding dialog '$($dialog.Name)'."
        } else {
            # Write-Log -Level Warning -Message "DialogManager: Attempted to hide a dialog '$($dialog.Name)' that was not active."
        }
    }

    [void] Cleanup() {
        foreach ($dialog in $this._activeDialogs.ToArray()) { # Use ToArray to avoid collection modification during iteration
            $this.HideDialog($dialog) # This will also cleanup and remove from overlay stack
        }
        $this._activeDialogs.Clear()
        # Write-Log -Level Debug -Message "DialogManager: Cleanup complete."
    }
}

#endregion
#<!-- END_PAGE: ASE.009 -->
