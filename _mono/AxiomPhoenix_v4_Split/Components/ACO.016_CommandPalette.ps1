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
# Dependencies: UIElement, Panel, ListBox, TextBoxComponent
# Purpose: Searchable command interface
class CommandPalette : UIElement {
    hidden [ListBox]$_listBox
    hidden [TextBoxComponent]$_searchBox
    hidden [Panel]$_panel
    hidden [List[object]]$_allActions
    hidden [List[object]]$_filteredActions
    [scriptblock]$OnExecute
    [scriptblock]$OnCancel

    CommandPalette([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Visible = $false
        $this.IsOverlay = $true
        $this.Width = 60
        $this.Height = 20
        
        $this._allActions = [List[object]]::new()
        $this._filteredActions = [List[object]]::new()
        
        $this.Initialize()
    }

    hidden [void] Initialize() {
        # Create main panel with border
        $this._panel = [Panel]::new("CommandPalette_Panel")
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
        $this._panel.Title = " Command Palette "
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height
        $this._panel.X = 0
        $this._panel.Y = 0
        $this.AddChild($this._panel)

        # Create search box
        $this._searchBox = [TextBoxComponent]::new("CommandPalette_Search")
        $this._searchBox.X = 2
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 3
        $this._searchBox.Placeholder = "Type to search commands..."
        $this._searchBox.Visible = $true  # Ensure visible
        $this._searchBox.Enabled = $true  # Ensure enabled
        
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
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $handled = $true
        
        switch ($key.Key) {
            ([ConsoleKey]::Escape) { 
                if ($this.OnCancel) {
                    & $this.OnCancel
                }
                return $true 
            }
            ([ConsoleKey]::Enter) {
                if ($this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                    $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                    if ($selectedAction -and $this.OnExecute) {
                        & $this.OnExecute $this $selectedAction
                        return $true
                    }
                }
                return $true
            }
            ([ConsoleKey]::Tab) {
                # Switch focus between search box and list
                if ($this._searchBox.IsFocused) {
                    $this._searchBox.IsFocused = $false
                    $this._listBox.IsFocusable = $true
                    # Focus would be set by parent focus manager
                } else {
                    $this._searchBox.IsFocused = $true
                    $this._listBox.IsFocusable = $false
                }
                $this.RequestRedraw()
                return $true
            }
            {$_ -in @([ConsoleKey]::UpArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::PageUp, [ConsoleKey]::PageDown, [ConsoleKey]::Home, [ConsoleKey]::End)} {
                # Navigation keys go to the list
                return $this._listBox.HandleInput($key)
            }
            default {
                # All other input goes to search box if it's focused
                if ($this._searchBox.IsFocused) {
                    return $this._searchBox.HandleInput($key)
                } else {
                    $handled = $false
                }
            }
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
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
