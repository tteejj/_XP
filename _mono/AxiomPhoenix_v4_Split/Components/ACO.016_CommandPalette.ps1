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
        $this._searchBox.TabIndex = 0  # First in tab order
        
        # Set colors using properties
        $this._searchBox.BackgroundColor = Get-ThemeColor "Input.Background"
        $this._searchBox.ForegroundColor = Get-ThemeColor "Input.Foreground"
        $this._searchBox.BorderColor = Get-ThemeColor "Input.Border"
        
        # Add focus visual feedback
        $this._searchBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force

        $this._searchBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "Input.Border"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
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
        $this._listBox.IsFocusable = $true
        $this._listBox.TabIndex = 1  # Second in tab order
        
        # Set colors using properties
        $this._listBox.BackgroundColor = Get-ThemeColor "List.Background"
        $this._listBox.ForegroundColor = Get-ThemeColor "List.Foreground"
        $this._listBox.BorderColor = Get-ThemeColor "List.Border"
        
        # Add focus visual feedback
        $this._listBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent"
            $this.RequestRedraw()
        } -Force

        $this._listBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "List.Border"
            $this.RequestRedraw()
        } -Force
        
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

    [void] OnEnter() {
        # Initialize search box
        if ($this._searchBox) {
            $this._searchBox.Text = ""
            $this._searchBox.CursorPosition = 0
        }
        
        # Call base to set initial focus automatically
        ([Dialog]$this).OnEnter()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # ALWAYS FIRST - Let base handle Tab and component routing
        if (([Dialog]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # ONLY screen-level shortcuts here
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) { 
                $this.Complete($null)  # Signal cancellation
                return $true 
            }
            ([ConsoleKey]::Enter) {
                # Execute the currently selected action in the list
                if ($this._filteredActions.Count -gt 0 -and $this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                    $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                    if ($selectedAction) {
                        Write-Log -Level Debug -Message "CommandPalette: Executing selected action: $($selectedAction.Name)"
                        $this.Complete($selectedAction)
                        return $true
                    }
                }
                return $false
            }
            ([ConsoleKey]::UpArrow) {
                # Allow list navigation when search box has focus
                if ($this._filteredActions.Count -gt 0 -and $this._listBox.SelectedIndex -gt 0) {
                    $this._listBox.SelectedIndex--
                    $this._listBox.EnsureVisible($this._listBox.SelectedIndex)
                    $this._listBox.RequestRedraw()
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::DownArrow) {
                # Allow list navigation when search box has focus
                if ($this._filteredActions.Count -gt 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count - 1) {
                    $this._listBox.SelectedIndex++
                    $this._listBox.EnsureVisible($this._listBox.SelectedIndex)
                    $this._listBox.RequestRedraw()
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::PageUp) {
                # Move selection up by a page
                if ($this._filteredActions.Count -gt 0) {
                    $pageSize = [Math]::Max(1, $this._listBox.Height - 2)
                    $newIndex = [Math]::Max(0, $this._listBox.SelectedIndex - $pageSize)
                    $this._listBox.SelectedIndex = $newIndex
                    $this._listBox.EnsureVisible($this._listBox.SelectedIndex)
                    $this._listBox.RequestRedraw()
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
                    return $true
                }
                return $false
            }
        }
        
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
