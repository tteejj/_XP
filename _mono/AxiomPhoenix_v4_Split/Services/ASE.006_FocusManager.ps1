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
    [System.Collections.Generic.Stack[UIElement]]$FocusStack = [System.Collections.Generic.Stack[UIElement]]::new()  # NEW: Focus history stack

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
    
    # NEW: Save current focus state to stack
    [void] PushFocusState() {
        $focusName = if ($null -ne $this.FocusedComponent) { $this.FocusedComponent.Name } else { 'null' }
        Write-Log -Level Debug -Message "FocusManager.PushFocusState: Saving focus on $focusName"
        $this.FocusStack.Push($this.FocusedComponent)  # Can push null
    }
    
    # NEW: Restore focus from stack
    [void] PopFocusState() {
        if ($this.FocusStack.Count -gt 0) {
            $previousFocus = $this.FocusStack.Pop()
            $focusName = if ($null -ne $previousFocus) { $previousFocus.Name } else { 'null' }
            Write-Log -Level Debug -Message "FocusManager.PopFocusState: Restoring focus to $focusName"
            $this.SetFocus($previousFocus)
        } else {
            Write-Log -Level Debug -Message "FocusManager.PopFocusState: No saved focus state to restore"
            $this.SetFocus($null)
        }
    }

    [void] Cleanup() {
        $this.FocusedComponent = $null
        $this.FocusStack.Clear()  # NEW: Clear the focus stack
        # Write-Log -Level Debug -Message "FocusManager: Cleanup complete."
    }
}

# ===== CLASS: DialogManager =====
# Module: dialog-manager (new service)
# Dependencies: NavigationService
# Purpose: Convenience facade for dialog management
class DialogManager {
    [object]$NavigationService = $null  # Using object to avoid type issues
    [object]$ServiceContainer = $null

    DialogManager([object]$serviceContainer) {
        if ($null -eq $serviceContainer) {
            throw [System.ArgumentNullException]::new("serviceContainer")
        }
        $this.ServiceContainer = $serviceContainer
        # NavigationService will be resolved when needed
        # Write-Log -Level Debug -Message "DialogManager: Initialized."
    }

    [void] ShowDialog([object]$dialog) {
        if ($null -eq $dialog) {
            throw [System.ArgumentException]::new("Provided dialog is null.", "dialog")
        }
        
        # Verify it's a Dialog (which is a Screen)
        if (-not ($dialog.PSObject.Properties['IsOverlay'])) {
            throw [System.ArgumentException]::new("Expected Dialog-derived object but got $($dialog.GetType().Name)")
        }
        
        # Ensure dialog is marked as overlay
        $dialog.IsOverlay = $true
        
        # Get NavigationService lazily
        if ($null -eq $this.NavigationService) {
            $this.NavigationService = $this.ServiceContainer.GetService("NavigationService")
        }
        
        # Navigate to the dialog - NavigationService handles focus saving
        if ($this.NavigationService) {
            $this.NavigationService.NavigateTo($dialog)
        } else {
            throw [System.InvalidOperationException]::new("NavigationService not available")
        }
        
        # Write-Log -Level Info -Message "DialogManager: Showing dialog '$($dialog.Name)'."
    }

    [void] HideDialog([object]$dialog) {
        # This method is now just a convenience wrapper
        # Dialogs should call NavigationService.GoBack() themselves via Complete()
        Write-Log -Level Warning -Message "DialogManager.HideDialog is deprecated. Use dialog.Complete() instead."
        
        # For backward compatibility, try to navigate back
        if ($null -eq $this.NavigationService) {
            $this.NavigationService = $this.ServiceContainer.GetService("NavigationService")
        }
        
        if ($this.NavigationService -and $this.NavigationService.CanGoBack()) {
            $this.NavigationService.GoBack()
        }
    }

    [void] Cleanup() {
        # Nothing to clean up - NavigationService manages all windows
        # Write-Log -Level Debug -Message "DialogManager: Cleanup complete."
    }
}

#endregion
#<!-- END_PAGE: ASE.009 -->
