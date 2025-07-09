# ===== CLASS: CommandPalette =====
# Module: command-palette
# Dependencies: UIElement, Panel, ListBox, TextBox
# Purpose: Searchable command interface
class CommandPalette : UIElement {
    hidden [ListBox]$_listBox
    hidden [TextBox]$_searchBox
    hidden [Panel]$_panel
    hidden [List[object]]$_allActions
    hidden [List[object]]$_filteredActions
    hidden [object]$_actionService
    hidden [scriptblock]$OnCancel
    hidden [scriptblock]$OnSelect
    hidden [System.DateTime]$_lastSearchTime = [DateTime]::MinValue
    hidden [string]$_pendingSearchText = ""

    CommandPalette([string]$name, [object]$actionService) : base($name) {
        $this.IsFocusable = $true
        $this.Visible = $false
        $this.IsOverlay = $true
        $this.Width = 60
        $this.Height = 20
        $this._actionService = $actionService
        
        $this.Initialize()
    }

    hidden [void] Initialize() {
        # Create main panel
        $this._panel = [Panel]::new("CommandPalette_Panel")
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
        $this._panel.BorderColor = "#00FFFF"    # FIXED: Cyan in hex
        $this._panel.BackgroundColor = "#000000" # FIXED: Black in hex
        $this._panel.Title = " Command Palette "
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height
        $this.AddChild($this._panel)

        # Create search box
        $this._searchBox = [TextBox]::new("CommandPalette_Search")
        $this._searchBox.X = 2
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 3
        $this._searchBox._textBox.Placeholder = "Type to search commands..."
        
        # Fix the OnChange handler to properly capture $this
        $commandPalette = $this
        $this._searchBox._textBox.OnChange = {
            param($sender, $text)
            $commandPalette.FilterActions($text)
        }.GetNewClosure()
        
        $this._panel.AddChild($this._searchBox)

        # Create list box
        $this._listBox = [ListBox]::new("CommandPalette_List")
        $this._listBox.X = 2
        $this._listBox.Y = 4
        $this._listBox.Width = $this.Width - 4
        $this._listBox.Height = $this.Height - 6
        $this._panel.AddChild($this._listBox)

        # Initialize action lists
        $this._allActions = [List[object]]::new()
        $this._filteredActions = [List[object]]::new()
    }

    [void] Show() {
        # Center the command palette on screen
        $consoleWidth = $global:TuiState.BufferWidth
        $consoleHeight = $global:TuiState.BufferHeight
        $this.X = [Math]::Max(0, [Math]::Floor(($consoleWidth - $this.Width) / 2))
        $this.Y = [Math]::Max(0, [Math]::Floor(($consoleHeight - $this.Height) / 2))
        
        $this.RefreshActions()
        $this._searchBox.Clear()
        $this.FilterActions("")
        $this.Visible = $true
        $this._searchBox.Focus()
        $this.RequestRedraw()
    }

    [void] Hide() {
        $this.Visible = $false
        
        # Force a full redraw of the entire screen to clear any rendering artifacts
        $global:TuiState.IsDirty = $true
        
        # Get current screen through NavigationService
        $navService = $global:TuiState.Services.NavigationService
        if ($navService -and $navService.CurrentScreen) {
            $navService.CurrentScreen.RequestRedraw()
        }
        
        if ($this.OnCancel) {
            & $this.OnCancel
        }
    }

    [void] RefreshActions() {
        $this._allActions.Clear()
        
        if ($this._actionService) {
            $actions = $this._actionService.GetAllActions()
            # Use Write-Log instead of Write-Host
            Write-Log -Level "Debug" -Message "CommandPalette: RefreshActions - got $($actions.Count) actions from service"
            
            if ($actions -and $actions.Values) {
                foreach ($action in $actions.Values) {
                    if ($action) {
                        $this._allActions.Add($action)
                    }
                }
            }
        }
        
        # Sort by category and name
        $sorted = $this._allActions | Sort-Object Category, Name
        $this._allActions.Clear()
        foreach ($item in $sorted) {
            $this._allActions.Add($item)
        }
        
        Write-Log -Level "Debug" -Message "CommandPalette: RefreshActions complete - $($this._allActions.Count) actions loaded"
    }

    [void] FilterActions([string]$searchText) {
        # Implement debouncing
        $now = [DateTime]::Now
        if (($now - $this._lastSearchTime).TotalMilliseconds -lt 100) {
            $this._pendingSearchText = $searchText
            return
        }
        $this._lastSearchTime = $now
        
        $this._filteredActions.Clear()
        $this._listBox.ClearItems()
        
        if ([string]::IsNullOrWhiteSpace($searchText)) {
            # Show all actions
            foreach ($action in $this._allActions) {
                $this._filteredActions.Add($action)
                if ($action.Category) { 
                    $displayText = "[$($action.Category)] $($action.Name) - $($action.Description)" 
                } else { 
                    $displayText = "$($action.Name) - $($action.Description)" 
                }
                $this._listBox.AddItem($displayText)
            }
        }
        else {
            # Use simple contains for better performance
            $searchLower = $searchText.ToLower()
            foreach ($action in $this._allActions) {
                # Quick check for name match first (most likely)
                if ($action.Name.ToLower().Contains($searchLower) -or
                    ($action.Description -and $action.Description.ToLower().Contains($searchLower)) -or
                    ($action.Category -and $action.Category.ToLower().Contains($searchLower))) {
                    
                    $this._filteredActions.Add($action)
                    if ($action.Category) { 
                        $displayText = "[$($action.Category)] $($action.Name) - $($action.Description)" 
                    } else { 
                        $displayText = "$($action.Name) - $($action.Description)" 
                    }
                    $this._listBox.AddItem($displayText)
                }
            }
        }
        
        # Reset selection
        if ($this._filteredActions.Count -gt 0) {
            $this._listBox.SelectedIndex = 0
            Write-Log -Level "Debug" -Message "CommandPalette: FilterActions set SelectedIndex=0, filtered count=$($this._filteredActions.Count)"
        }
        else {
            Write-Log -Level "Debug" -Message "CommandPalette: FilterActions - no filtered items"
        }
        
        # Ensure list is refreshed
        $this._listBox.RequestRedraw()
        $this.RequestRedraw()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        # Handle global escape
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Hide()
            return $true
        }
        
        # Handle Enter for action selection
        if ($key.Key -eq [ConsoleKey]::Enter) {
            # Log for debugging
            Write-Log -Level "Debug" -Message "CommandPalette: Enter pressed. SelectedIndex=$($this._listBox.SelectedIndex), FilteredActions=$($this._filteredActions.Count)"
            
            # Always execute if we have a selection, regardless of which component has focus
            if ($this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                Write-Log -Level "Debug" -Message "CommandPalette: Selected action: $($selectedAction.Name)"
                
                if ($selectedAction) {
                    $this.Hide()
                    if ($this.OnSelect) {
                        & $this.OnSelect $selectedAction
                    }
                    else {
                        # Execute action directly
                        Write-Log -Level "Debug" -Message "CommandPalette: Executing action $($selectedAction.Name)"
                        try {
                            $this._actionService.ExecuteAction($selectedAction.Name, @{})
                        }
                        catch {
                            Write-Log -Level "Error" -Message "CommandPalette: Failed to execute action $($selectedAction.Name): $_"
                        }
                    }
                    return $true
                }
            }
            else {
                Write-Log -Level "Debug" -Message "CommandPalette: Cannot execute - no selection or no filtered actions"
            }
        }
        
        # Navigation keys always go to list box
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) { 
                $result = $this._listBox.HandleInput($key)
                $this.RequestRedraw()
                return $result
            }
            ([ConsoleKey]::DownArrow) { 
                $result = $this._listBox.HandleInput($key)
                $this.RequestRedraw()
                return $result
            }
            ([ConsoleKey]::PageUp) { 
                $result = $this._listBox.HandleInput($key)
                $this.RequestRedraw()
                return $result
            }
            ([ConsoleKey]::PageDown) { 
                $result = $this._listBox.HandleInput($key)
                $this.RequestRedraw()
                return $result
            }
            ([ConsoleKey]::Home) { 
                $result = $this._listBox.HandleInput($key)
                $this.RequestRedraw()
                return $result
            }
            ([ConsoleKey]::End) { 
                $result = $this._listBox.HandleInput($key)
                $this.RequestRedraw()
                return $result
            }
            default {
                # All other input goes to search box
                $result = $this._searchBox.HandleInput($key)
                if ($result) {
                    $this.RequestRedraw()
                }
                return $result
            }
        }
    }
}
