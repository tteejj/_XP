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

    CommandPalette([string]$name) : base($name) {
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
        $this._searchBox.Visible = $true  # Ensure visible
        $this._searchBox.Enabled = $true  # Ensure enabled
        $this._searchBox.IsFocusable = $true  # Ensure focusable
        
        # Connect search box to filtering
        $paletteRef = $this
        $this._searchBox.OnChange = { 
            param($sender, $text) 
            Write-Log -Level Debug -Message "CommandPalette: Search text changed to '$text'"
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
        
        # Set initial focus to search box
        $this._searchBox.IsFocused = $true
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
                Write-Log -Level Debug -Message "CommandPalette.SetInitialFocus: About to set focus to search box"
                Write-Log -Level Debug -Message "  - SearchBox Name: $($this._searchBox.Name)"
                Write-Log -Level Debug -Message "  - SearchBox IsFocusable: $($this._searchBox.IsFocusable)"
                Write-Log -Level Debug -Message "  - SearchBox Enabled: $($this._searchBox.Enabled)"
                Write-Log -Level Debug -Message "  - SearchBox Visible: $($this._searchBox.Visible)"
                $focusManager.SetFocus($this._searchBox)
                Write-Log -Level Debug -Message "  - FocusManager.FocusedComponent: $($focusManager.FocusedComponent?.Name)"
                Write-Log -Level Debug -Message "  - SearchBox IsFocused: $($this._searchBox.IsFocused)"
            } else {
                Write-Log -Level Error -Message "CommandPalette.SetInitialFocus: FocusManager is null!"
            }
            $this._searchBox.RequestRedraw()
            $this.RequestRedraw()  # Also redraw the palette to ensure everything is visible
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
                # Only handle Enter if the list has focus and a selection
                if ($focusedComponent -eq $this._listBox) {
                    if ($this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                        $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                        if ($selectedAction) {
                            $this.Complete($selectedAction)  # Signal completion with result
                            return $true
                        }
                    }
                }
                return $false  # Let the focused component handle Enter
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
                # If search box has focus and user presses arrow keys, move focus to list
                if ($focusedComponent -eq $this._searchBox -and $this._filteredActions.Count -gt 0) {
                    $focusManager.SetFocus($this._listBox)
                    # Let the list handle the actual arrow key
                    return $this._listBox.HandleInput($key)
                }
                return $false  # Let the focused component handle it
            }
            ([ConsoleKey]::DownArrow) {
                # If search box has focus and user presses arrow keys, move focus to list
                if ($focusedComponent -eq $this._searchBox -and $this._filteredActions.Count -gt 0) {
                    $focusManager.SetFocus($this._listBox)
                    # Let the list handle the actual arrow key
                    return $this._listBox.HandleInput($key)
                }
                return $false  # Let the focused component handle it
            }
            default {
                # Let the input routing system handle everything else
                return $false
            }
        }
        
        # This should never be reached due to the switch statement, but added for safety
        return $false
    }

    [void] OnFocus() {
        ([UIElement]$this).OnFocus()
        # Set initial focus to search box
        if ($this._searchBox) {
            $this._searchBox.IsFocused = $true
            $this._searchBox.RequestRedraw()
        }
    }

    [void] OnBlur() {
        ([UIElement]$this).OnBlur()
        if ($this._searchBox) {
            $this._searchBox.IsFocused = $false
            $this._searchBox.RequestRedraw()
        }
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
}

#<!-- END_PAGE: ACO.016 -->

#endregion Composite Components

#region Dialog Components
