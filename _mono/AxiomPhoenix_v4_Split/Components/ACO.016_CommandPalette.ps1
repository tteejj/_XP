# ==============================================================================
# Axiom-Phoenix v4.0 - All Components
# UI components that extend UIElement - full implementations from axiom
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ACO.###" to find specific sections.
# Each section ends with "END_PAGE: ACO.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#

# ===== CLASS: CommandPalette =====
# Module: command-palette
# Dependencies: Dialog, Panel, ListBox, TextBoxComponent
# Purpose: Searchable command interface
class CommandPalette : Dialog {
    hidden [ListBox]$_listBox
    hidden [TextBoxComponent]$_searchBox
    hidden [List[object]]$_allActions
    hidden [List[object]]$_filteredActions
    [scriptblock]$OnExecute
    [scriptblock]$OnCancel

    CommandPalette([string]$name, [object]$serviceContainer) : base($name, $serviceContainer) {
        $this.Width = 60
        $this.Height = 20
        
        $this._allActions = [List[object]]::new()
        $this._filteredActions = [List[object]]::new()
        
        $this.InitializeControls()
    }

    hidden [void] InitializeControls() {
        # Dialog base class already provides _panel with border
        $this._panel.Title = " Command Palette "
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height

        # Create search box
        $this._searchBox = [TextBoxComponent]::new("CommandPalette_Search")
        $this._searchBox.X = 2
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 3
        $this._searchBox.Placeholder = "Type to search commands..."
        $this._searchBox.Visible = $true
        $this._searchBox.Enabled = $true
        $this._searchBox.IsFocusable = $true
        
        # Connect search box to filtering
        $paletteRef = $this
        $this._searchBox.OnChange = { 
            param($sender, $text) 
            $paletteRef.FilterActions($text) 
        }.GetNewClosure()
        $this._panel.AddChild($this._searchBox)

        # Create list box for results
        $this._listBox = [ListBox]::new("CommandPalette_List")
        $this._listBox.X = 2
        $this._listBox.Y = 4
        $this._listBox.Width = $this.Width - 4
        $this._listBox.Height = $this.Height - 6
        $this._panel.AddChild($this._listBox)
    }

    [void] SetActions([object[]]$actionList) {
        $this._allActions.Clear()
        foreach ($action in $actionList) {
            $this._allActions.Add($action)
        }
        $this.FilterActions("")  # Show all actions initially
    }

    [void] FilterActions([string]$searchText) {
        $this._filteredActions.Clear()
        $this._listBox.ClearItems()
        
        $actionsToDisplay = if ([string]::IsNullOrWhiteSpace($searchText)) { 
            $this._allActions 
        } else {
            $searchLower = $searchText.ToLower()
            @($this._allActions | Where-Object {
                $_.Name.ToLower().Contains($searchLower) -or
                ($_.Description -and $_.Description.ToLower().Contains($searchLower)) -or
                ($_.Category -and $_.Category.ToLower().Contains($searchLower))
            })
        }

        foreach ($action in $actionsToDisplay) {
            $this._filteredActions.Add($action)
            $displayText = if ($action.Category) { 
                "[$($action.Category)] $($action.Name)" 
            } else { 
                $action.Name 
            }
            $this._listBox.AddItem("$displayText - $($action.Description)")
        }
        
        if ($this._filteredActions.Count -gt 0) { 
            $this._listBox.SelectedIndex = 0 
        }
        $this.RequestRedraw()
    }

    [void] SetInitialFocus() {
        if ($this._searchBox) {
            # Clear any previous search text
            $this._searchBox.Text = ""
            $this._searchBox.CursorPosition = 0
            
            # Use FocusManager to properly set focus
            $focusManager = $global:TuiState.Services.FocusManager
            if ($focusManager) {
                $focusManager.SetFocus($this._searchBox)
            }
            $this.RequestRedraw()
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $focusManager = $global:TuiState.Services.FocusManager
        $focusedComponent = if ($focusManager) { $focusManager.FocusedComponent } else { $null }
        
        # Only handle container-level actions
        switch ($key.Key) {
            ([ConsoleKey]::Escape) { 
                $this.Complete($null)  # Signal cancellation
                return $true 
            }
            ([ConsoleKey]::Enter) {
                $focusedName = if ($null -ne $focusedComponent) { $focusedComponent.Name } else { 'null' }
                Write-Log -Level Debug -Message "CommandPalette: Enter key pressed, focused component: $focusedName"
                
                # Execute the currently selected action in the list, regardless of which component has focus
                if ($this._filteredActions.Count -gt 0 -and $this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                    $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                    if ($selectedAction) {
                        Write-Log -Level Debug -Message "CommandPalette: Executing selected action at index $($this._listBox.SelectedIndex): $($selectedAction.Name)"
                        Add-Content -Path "$PSScriptRoot\..\debug-trace.log" -Value "[$(Get-Date -Format 'HH:mm:ss.fff')] CommandPalette calling Complete() with action: $($selectedAction.Name)"
                        $this.Complete($selectedAction)
                        return $true
                    }
                }
                
                Write-Log -Level Debug -Message "CommandPalette: No valid selection to execute"
                return $false
            }
            ([ConsoleKey]::Tab) {
                # Toggle focus between search box and list
                if ($focusManager) {
                    if ($focusedComponent -eq $this._searchBox) {
                        $focusManager.SetFocus($this._listBox)
                    } else {
                        $focusManager.SetFocus($this._searchBox)
                    }
                }
                return $true
            }
            ([ConsoleKey]::UpArrow) {
                # If search box has focus, handle selection movement directly
                if ($focusedComponent -eq $this._searchBox -and $this._filteredActions.Count -gt 0) {
                    # Move selection up in the list (without changing focus)
                    if ($this._listBox.SelectedIndex -gt 0) {
                        $this._listBox.SelectedIndex--
                        $this._listBox.EnsureVisible($this._listBox.SelectedIndex)
                        $this._listBox.RequestRedraw()
                        $this.RequestRedraw()
                    }
                    return $true
                }
                return $false  # Let the list handle it if it has focus
            }
            ([ConsoleKey]::DownArrow) {
                # If search box has focus, handle selection movement directly
                if ($focusedComponent -eq $this._searchBox -and $this._filteredActions.Count -gt 0) {
                    # Move selection down in the list (without changing focus)
                    if ($this._listBox.SelectedIndex -lt $this._filteredActions.Count - 1) {
                        $this._listBox.SelectedIndex++
                        $this._listBox.EnsureVisible($this._listBox.SelectedIndex)
                        $this._listBox.RequestRedraw()
                        $this.RequestRedraw()
                    }
                    return $true
                }
                return $false  # Let the list handle it if it has focus
            }
            ([ConsoleKey]::PageUp) {
                # Move selection up by a page
                if ($this._filteredActions.Count -gt 0) {
                    $pageSize = [Math]::Max(1, $this._listBox.Height - 2)
                    $newIndex = [Math]::Max(0, $this._listBox.SelectedIndex - $pageSize)
                    $this._listBox.SelectedIndex = $newIndex
                    $this._listBox.EnsureVisible($this._listBox.SelectedIndex)
                    $this._listBox.RequestRedraw()
                    $this.RequestRedraw()
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::PageDown) {
                # Move selection down by a page
                if ($this._filteredActions.Count -gt 0) {
                    $pageSize = [Math]::Max(1, $this._listBox.Height - 2)
                    $newIndex = [Math]::Min($this._filteredActions.Count - 1, $this._listBox.SelectedIndex + $pageSize)
                    $this._listBox.SelectedIndex = $newIndex
                    $this._listBox.EnsureVisible($this._listBox.SelectedIndex)
                    $this._listBox.RequestRedraw()
                    $this.RequestRedraw()
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::Home) {
                # Move to first item
                if ($this._filteredActions.Count -gt 0) {
                    $this._listBox.SelectedIndex = 0
                    $this._listBox.EnsureVisible(0)
                    $this._listBox.RequestRedraw()
                    $this.RequestRedraw()
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::End) {
                # Move to last item
                if ($this._filteredActions.Count -gt 0) {
                    $this._listBox.SelectedIndex = $this._filteredActions.Count - 1
                    $this._listBox.EnsureVisible($this._listBox.SelectedIndex)
                    $this._listBox.RequestRedraw()
                    $this.RequestRedraw()
                    return $true
                }
                return $false
            }
            default {
                # Let the input routing system handle everything else
                return $false
            }
        }
        
        # Add explicit return false at end to satisfy all code paths
        return $false
    }

    [void] Cleanup() {
        if ($this._searchBox) {
            $this._searchBox.Text = ""
            $this._searchBox.CursorPosition = 0
        }
        if ($this._listBox) {
            $this._listBox.ClearItems()
            $this._listBox.SelectedIndex = -1
        }
        $this._allActions.Clear()
        $this._filteredActions.Clear()
    }
    
    # Override Complete to ensure proper cleanup
    [void] Complete([object]$result) {
        Write-Log -Level Debug -Message "CommandPalette.Complete called with result: $(if ($null -ne $result) { $result | ConvertTo-Json -Compress } else { 'null' })"
        
        # Clean up our state first
        $this.Cleanup()
        
        # Force a redraw to clear the screen before navigation
        $this.RequestRedraw()
        $global:TuiState.IsDirty = $true
        
        # Call parent Complete which handles navigation and OnClose callback
        ([Dialog]$this).Complete($result)
    }
}

#<!-- END_PAGE: ACO.016 -->

#endregion Composite Components

#region Dialog Components
