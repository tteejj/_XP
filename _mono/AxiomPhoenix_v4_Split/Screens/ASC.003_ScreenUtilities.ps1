# ==============================================================================
# Axiom-Phoenix v4.0 - All Screens (Load After Components)
# Application screens that extend Screen base class
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASC.###" to find specific sections.
# Each section ends with "END_PAGE: ASC.###"
# ==============================================================================

using namespace System.Collections.Generic

#region Screen Utilities

# ==============================================================================
# CommandPaletteScreen - Full screen command palette
# ==============================================================================
class CommandPaletteScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [TextBoxComponent] $_searchBox
    hidden [ListBox] $_listBox
    hidden [List[object]] $_allActions
    hidden [List[object]] $_filteredActions
    
    CommandPaletteScreen([object]$serviceContainer) : base("CommandPaletteScreen", $serviceContainer) {
        $this._allActions = [List[object]]::new()
        $this._filteredActions = [List[object]]::new()
    }
    
    [void] Initialize() {
        if (-not $this.ServiceContainer) { return }
        
        # Main panel
        $this._mainPanel = [Panel]::new("CommandPalettePanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Command Palette "
        $this.AddChild($this._mainPanel)
        
        # Search box
        $this._searchBox = [TextBoxComponent]::new("SearchBox")
        $this._searchBox.X = 2
        $this._searchBox.Y = 2
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 1
        $this._searchBox.Placeholder = "Type to search commands... (Esc to cancel)"
        $this._searchBox.IsFocusable = $true
        $this._searchBox.Enabled = $true
        
        $thisScreen = $this
        $this._searchBox.OnChange = {
            param($sender, $text)
            $thisScreen.FilterActions($text)
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._searchBox)
        
        # List box for results
        $this._listBox = [ListBox]::new("ActionList")
        $this._listBox.X = 2
        $this._listBox.Y = 4
        $this._listBox.Width = $this.Width - 4
        $this._listBox.Height = $this.Height - 7
        $this._mainPanel.AddChild($this._listBox)
        
        # Help text
        $helpText = [LabelComponent]::new("HelpText")
        $helpText.Text = "Enter: Execute | Tab: Toggle Focus | Esc: Cancel"
        $helpText.X = 2
        $helpText.Y = $this.Height - 2
        $helpText.ForegroundColor = Get-ThemeColor -ColorName "Subtle"
        $this._mainPanel.AddChild($helpText)
    }
    
    [void] OnEnter() {
        # Load all actions
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if ($actionService) {
            $this._allActions.Clear()
            $allActions = $actionService.GetAllActions()
            foreach ($actionEntry in $allActions.GetEnumerator()) {
                $actionData = $actionEntry.Value
                $this._allActions.Add([PSCustomObject]@{
                    Name = $actionEntry.Key
                    Description = $actionData.Description
                    Category = $actionData.Category
                    Hotkey = $actionData.Hotkey
                })
            }
        }
        
        # Show all actions initially
        $this.FilterActions("")
        
        # Set focus to search box
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager -and $this._searchBox) {
            $focusManager.SetFocus($this._searchBox)
        }
        
        $this.RequestRedraw()
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
            if ($action.Description) {
                $displayText += " - $($action.Description)"
            }
            $this._listBox.AddItem($displayText)
        }
        
        if ($this._filteredActions.Count -gt 0) {
            $this._listBox.SelectedIndex = 0
        }
        $this.RequestRedraw()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        $focusedComponent = if ($focusManager) { $focusManager.FocusedComponent } else { $null }
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                # Go back
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
            ([ConsoleKey]::Tab) {
                # Toggle focus between search and list
                if ($focusManager) {
                    if ($focusedComponent -eq $this._searchBox) {
                        $focusManager.SetFocus($this._listBox)
                    } else {
                        $focusManager.SetFocus($this._searchBox)
                    }
                }
                return $true
            }
            ([ConsoleKey]::Enter) {
                # Execute selected action if list has focus
                if ($focusedComponent -eq $this._listBox) {
                    if ($this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                        $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                        if ($selectedAction) {
                            $actionService = $this.ServiceContainer?.GetService("ActionService")
                            if ($actionService) {
                                # Go back first
                                $navService = $this.ServiceContainer?.GetService("NavigationService")
                                if ($navService -and $navService.CanGoBack()) {
                                    $navService.GoBack()
                                }
                                # Then execute action
                                $actionService.ExecuteAction($selectedAction.Name)
                            }
                        }
                    }
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::UpArrow) {
                # Move focus to list if on search box
                if ($focusedComponent -eq $this._searchBox -and $this._filteredActions.Count -gt 0) {
                    $focusManager.SetFocus($this._listBox)
                    return $this._listBox.HandleInput($keyInfo)
                }
                return $false
            }
            ([ConsoleKey]::DownArrow) {
                # Move focus to list if on search box
                if ($focusedComponent -eq $this._searchBox -and $this._filteredActions.Count -gt 0) {
                    $focusManager.SetFocus($this._listBox)
                    return $this._listBox.HandleInput($keyInfo)
                }
                return $false
            }
        }
        
        return $false
    }
}

#endregion
#<!-- END_PAGE: ASC.003 -->
