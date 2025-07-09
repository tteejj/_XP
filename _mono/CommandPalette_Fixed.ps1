# ===== CLASS: CommandPalette =====
# Module: command-palette
# Dependencies: UIElement, Panel, ListBox, TextBoxComponent
# Purpose: Searchable command interface - FINAL FIXED VERSION
class CommandPalette : UIElement {
    hidden [ListBox]$_listBox
    hidden [TextBoxComponent]$_searchBox
    hidden [Panel]$_panel
    hidden [List[object]]$_allActions
    hidden [List[object]]$_filteredActions
    hidden [object]$_actionService
    hidden [scriptblock]$OnCancel
    hidden [scriptblock]$OnSelect

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
        $this._panel = [Panel]::new("CommandPalette_Panel")
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
        $this._panel.Title = " Command Palette "
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height
        $this.AddChild($this._panel)

        $this._searchBox = [TextBoxComponent]::new("CommandPalette_Search")
        $this._searchBox.X = 2
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 3
        $this._searchBox.Placeholder = "Type to search commands..."
        
        # Fix: Properly capture $this reference for the closure
        $paletteRef = $this
        $this._searchBox.OnChange = {
            param($sender, $text)
            $paletteRef.FilterActions($text)
        }.GetNewClosure()
        $this._panel.AddChild($this._searchBox)

        $this._listBox = [ListBox]::new("CommandPalette_List")
        $this._listBox.X = 2
        $this._listBox.Y = 4
        $this._listBox.Width = $this.Width - 4
        $this._listBox.Height = $this.Height - 6
        $this._panel.AddChild($this._listBox)

        $this._allActions = [List[object]]::new()
        $this._filteredActions = [List[object]]::new()
    }

    [void] Show() {
        $consoleWidth = $global:TuiState.BufferWidth
        $consoleHeight = $global:TuiState.BufferHeight
        $this.X = [Math]::Max(0, [Math]::Floor(($consoleWidth - $this.Width) / 2))
        $this.Y = [Math]::Max(0, [Math]::Floor(($consoleHeight - $this.Height) / 2))
        
        $this.RefreshActions()
        $this._searchBox.Text = ""
        $this._searchBox.CursorPosition = 0
        $this.FilterActions("")
        $this.Visible = $true
        
        if (-not $global:TuiState.OverlayStack.Contains($this)) {
            $global:TuiState.OverlayStack.Add($this)
        }
        
        $focusManager = $global:TuiState.Services.FocusManager
        if ($focusManager) {
            $focusManager.SetFocus($this._searchBox)
        }
        $global:TuiState.IsDirty = $true
    }

    [void] Hide() {
        $this.Visible = $false
        if ($global:TuiState.OverlayStack.Contains($this)) {
            $global:TuiState.OverlayStack.Remove($this)
        }
        $focusManager = $global:TuiState.Services.FocusManager
        if ($focusManager) {
            $focusManager.ReleaseFocus()
        }
        $global:TuiState.IsDirty = $true
        if ($this.OnCancel) { & $this.OnCancel }
    }

    [void] RefreshActions() {
        $this._allActions.Clear()
        if ($this._actionService) {
            $actions = $this._actionService.GetAllActions()
            if ($actions -and $actions.Values) {
                $sortedActions = $actions.Values | Sort-Object Category, Name
                foreach ($action in $sortedActions) {
                    $this._allActions.Add($action)
                }
            }
        }
    }

    [void] FilterActions([string]$searchText) {
        $this._filteredActions.Clear()
        $this._listBox.ClearItems()
        
        $actionsToDisplay = if ([string]::IsNullOrWhiteSpace($searchText)) { 
            $this._allActions 
        } else {
            $searchLower = $searchText.ToLower()
            $filtered = @()
            foreach ($action in $this._allActions) {
                if ($action.Name.ToLower().Contains($searchLower) -or
                    ($action.Description -and $action.Description.ToLower().Contains($searchLower)) -or
                    ($action.Category -and $action.Category.ToLower().Contains($searchLower))) {
                    $filtered += $action
                }
            }
            $filtered
        }

        foreach ($action in $actionsToDisplay) {
            $this._filteredActions.Add($action)
            $displayText = if ($action.Category) { "[$($action.Category)] $($action.Name)" } else { $action.Name }
            if ($action.Description) {
                $displayText = "$displayText - $($action.Description)"
            }
            $this._listBox.AddItem($displayText)
        }
        
        if ($this._filteredActions.Count -gt 0) { 
            $this._listBox.SelectedIndex = 0 
        }
        $this.RequestRedraw()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        # Fixed switch statement syntax - use commas for multiple values
        switch ($key.Key) {
            ([ConsoleKey]::Escape) { 
                $this.Hide()
                return $true 
            }
            ([ConsoleKey]::Enter) {
                if ($this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                    $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                    if ($selectedAction) {
                        $this.Hide()
                        try {
                            $this._actionService.ExecuteAction($selectedAction.Name, @{})
                        } catch {
                            Write-Log -Level Error -Message "CommandPalette: Error executing action '$($selectedAction.Name)': $_"
                        }
                    }
                }
                return $true
            }
            ([ConsoleKey]::UpArrow) {
                return $this._listBox.HandleInput($key)
            }
            ([ConsoleKey]::DownArrow) {
                return $this._listBox.HandleInput($key)
            }
            ([ConsoleKey]::PageUp) {
                return $this._listBox.HandleInput($key)
            }
            ([ConsoleKey]::PageDown) {
                return $this._listBox.HandleInput($key)
            }
            ([ConsoleKey]::Home) {
                return $this._listBox.HandleInput($key)
            }
            ([ConsoleKey]::End) {
                return $this._listBox.HandleInput($key)
            }
            default { 
                # Let the search box handle text input
                return $false 
            }
        }
    }
}
