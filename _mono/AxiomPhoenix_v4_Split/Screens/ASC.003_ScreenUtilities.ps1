# ==============================================================================
# Axiom-Phoenix v4.0 - Screen Utilities
# FIXED: Removed FocusManager dependency, uses direct input handling
# ==============================================================================

using namespace System.Collections.Generic

#region Screen Utilities

# ==============================================================================
# CommandPaletteScreen - Full screen command palette
# FIXED: Now handles its own focus management
# ==============================================================================
class CommandPaletteScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [TextBoxComponent] $_searchBox
    hidden [ListBox] $_listBox
    hidden [List[object]] $_allActions
    hidden [List[object]] $_filteredActions
    
    # Internal focus management
    hidden [string] $_activeComponent = "search"  # "search" or "list"
    hidden [string] $_searchText = ""
    
    CommandPaletteScreen([object]$serviceContainer) : base("CommandPaletteScreen", $serviceContainer) {
        $this._allActions = [List[object]]::new()
        $this._filteredActions = [List[object]]::new()
        Write-Log -Level Debug -Message "CommandPaletteScreen: Constructor called"
    }
    
    [void] Initialize() {
        Write-Log -Level Debug -Message "CommandPaletteScreen.Initialize: Starting"
        
        if (-not $this.ServiceContainer) { 
            Write-Log -Level Error -Message "CommandPaletteScreen.Initialize: ServiceContainer is null!"
            return 
        }
        
        # Main panel
        $this._mainPanel = [Panel]::new("CommandPalettePanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Command Palette "
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.BorderColor = [ConsoleColor]::Cyan
        $this.AddChild($this._mainPanel)
        
        # Search box
        $this._searchBox = [TextBoxComponent]::new("SearchBox")
        $this._searchBox.X = 2
        $this._searchBox.Y = 2
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 1
        $this._searchBox.Placeholder = "Type to search commands... (Esc to cancel)"
        $this._searchBox.IsFocusable = $false  # We handle input directly
        $this._searchBox.Enabled = $true
        $this._searchBox.ShowCursor = $true  # Show cursor initially
        $this._mainPanel.AddChild($this._searchBox)
        
        # List box for results
        $this._listBox = [ListBox]::new("ActionList")
        $this._listBox.X = 2
        $this._listBox.Y = 4
        $this._listBox.Width = $this.Width - 4
        $this._listBox.Height = $this.Height - 7
        $this._listBox.IsFocusable = $false  # We handle input directly
        $this._listBox.HasBorder = $true
        $this._listBox.BorderStyle = "Single"
        $this._mainPanel.AddChild($this._listBox)
        
        # Help text
        $helpText = [LabelComponent]::new("HelpText")
        $helpText.Text = "Enter: Execute | Tab: Toggle Focus | ↑↓: Navigate | Esc: Cancel"
        $helpText.X = 2
        $helpText.Y = $this.Height - 2
        $helpText.ForegroundColor = [ConsoleColor]::DarkGray
        $this._mainPanel.AddChild($helpText)
        
        Write-Log -Level Debug -Message "CommandPaletteScreen.Initialize: Completed"
    }
    
    [void] OnEnter() {
        Write-Log -Level Debug -Message "CommandPaletteScreen.OnEnter: Loading actions"
        
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
            Write-Log -Level Debug -Message "CommandPaletteScreen: Loaded $($this._allActions.Count) actions"
        }
        
        # Show all actions initially
        $this._searchText = ""
        $this._searchBox.Text = ""
        $this.FilterActions("")
        
        # Set initial focus state
        $this._activeComponent = "search"
        $this._UpdateVisualFocus()
        
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
            
            # Format display text with category and description
            $displayText = if ($action.Category) {
                "[$($action.Category)] $($action.Name)"
            } else {
                $action.Name
            }
            
            if ($action.Description) {
                $maxDescLength = $this._listBox.Width - $displayText.Length - 5
                if ($maxDescLength -gt 10) {
                    $desc = $action.Description
                    if ($desc.Length -gt $maxDescLength) {
                        $desc = $desc.Substring(0, $maxDescLength - 3) + "..."
                    }
                    $displayText += " - $desc"
                }
            }
            
            if ($action.Hotkey) {
                $displayText += " ($($action.Hotkey))"
            }
            
            $this._listBox.AddItem($displayText)
        }
        
        if ($this._filteredActions.Count -gt 0) {
            $this._listBox.SelectedIndex = 0
        }
        
        Write-Log -Level Debug -Message "CommandPaletteScreen: Filtered to $($this._filteredActions.Count) actions"
        $this.RequestRedraw()
    }
    
    hidden [void] _UpdateVisualFocus() {
        # Update visual indicators based on active component
        if ($this._activeComponent -eq "search") {
            $this._searchBox.ShowCursor = $true
            $this._searchBox.BorderColor = [ConsoleColor]::Cyan
            $this._listBox.BorderColor = [ConsoleColor]::DarkGray
        } else {
            $this._searchBox.ShowCursor = $false
            $this._searchBox.BorderColor = [ConsoleColor]::DarkGray
            $this._listBox.BorderColor = [ConsoleColor]::Cyan
        }
        $this.RequestRedraw()
    }
    
    hidden [void] _ExecuteSelectedAction() {
        if ($this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
            $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
            if ($selectedAction) {
                Write-Log -Level Debug -Message "CommandPaletteScreen: Executing action '$($selectedAction.Name)'"
                
                $actionService = $this.ServiceContainer?.GetService("ActionService")
                if ($actionService) {
                    # Go back first
                    $navService = $this.ServiceContainer?.GetService("NavigationService")
                    if ($navService -and $navService.CanGoBack()) {
                        $navService.GoBack()
                    }
                    
                    # Then execute action (deferred to avoid navigation conflicts)
                    $eventManager = $this.ServiceContainer?.GetService("EventManager")
                    if ($eventManager) {
                        $eventManager.Publish("DeferredAction", @{
                            ActionName = $selectedAction.Name
                        })
                    }
                }
            }
        }
    }
    
    # === INPUT HANDLING (DIRECT, NO FOCUS MANAGER) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "CommandPaletteScreen.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "CommandPaletteScreen.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)', Active=$($this._activeComponent)"
        
        # Global keys work regardless of focus
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
                if ($this._activeComponent -eq "search") {
                    $this._activeComponent = "list"
                } else {
                    $this._activeComponent = "search"
                }
                $this._UpdateVisualFocus()
                return $true
            }
        }
        
        # Handle based on active component
        if ($this._activeComponent -eq "search") {
            # Search box is active - handle text input
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($this._searchText.Length -gt 0) {
                        $this._searchText = $this._searchText.Substring(0, $this._searchText.Length - 1)
                        $this._searchBox.Text = $this._searchText
                        $this.FilterActions($this._searchText)
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    # Execute first result if any
                    if ($this._filteredActions.Count -gt 0) {
                        $this._ExecuteSelectedAction()
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    # Move to list if there are results
                    if ($this._filteredActions.Count -gt 0) {
                        $this._activeComponent = "list"
                        $this._UpdateVisualFocus()
                    }
                    return $true
                }
                default {
                    # Add character to search
                    if ($keyInfo.KeyChar -and ([char]::IsLetterOrDigit($keyInfo.KeyChar) -or 
                        [char]::IsPunctuation($keyInfo.KeyChar) -or 
                        [char]::IsWhiteSpace($keyInfo.KeyChar))) {
                        $this._searchText += $keyInfo.KeyChar
                        $this._searchBox.Text = $this._searchText
                        $this.FilterActions($this._searchText)
                        return $true
                    }
                }
            }
        } else {
            # List is active - handle navigation
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this._listBox.SelectedIndex -gt 0) {
                        $this._listBox.SelectedIndex--
                        $this.RequestRedraw()
                    } elseif ($this._listBox.SelectedIndex -eq 0) {
                        # Wrap to search box
                        $this._activeComponent = "search"
                        $this._UpdateVisualFocus()
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this._listBox.SelectedIndex -lt $this._filteredActions.Count - 1) {
                        $this._listBox.SelectedIndex++
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    $this._ExecuteSelectedAction()
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $this._listBox.SelectedIndex = 0
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::End) {
                    if ($this._filteredActions.Count -gt 0) {
                        $this._listBox.SelectedIndex = $this._filteredActions.Count - 1
                        $this.RequestRedraw()
                    }
                    return $true
                }
                default {
                    # Any other key returns focus to search
                    if ($keyInfo.KeyChar -and [char]::IsLetterOrDigit($keyInfo.KeyChar)) {
                        $this._activeComponent = "search"
                        $this._searchText += $keyInfo.KeyChar
                        $this._searchBox.Text = $this._searchText
                        $this.FilterActions($this._searchText)
                        $this._UpdateVisualFocus()
                        return $true
                    }
                }
            }
        }
        
        return $false
    }
}

#endregion

# ==============================================================================
# END OF SCREEN UTILITIES
# ==============================================================================
