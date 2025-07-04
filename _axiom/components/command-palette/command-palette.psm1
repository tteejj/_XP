# ==============================================================================
# PMC Terminal Axiom-Phoenix v4.0 - Command Palette Component
# ==============================================================================
# Purpose: A searchable, filterable command palette for executing actions
# Features:
#   - Fuzzy search through all registered actions
#   - Group-based filtering
#   - Recent command history
#   - Keyboard navigation
#   - Visual feedback for hotkeys
# ==============================================================================

using namespace System
using namespace System.Collections.Generic

class CommandPalette : UIElement {
    hidden [ActionService] $actionService
    hidden [TextBoxComponent] $searchBox
    hidden [List[Action]] $filteredActions
    hidden [List[Action]] $allActions
    hidden [int] $selectedIndex
    hidden [int] $maxVisibleItems
    hidden [int] $scrollOffset
    hidden [bool] $isOpen
    hidden [string] $lastQuery
    hidden [ConsoleColor] $borderColor
    hidden [ConsoleColor] $backgroundColor
    hidden [ConsoleColor] $foregroundColor
    hidden [ConsoleColor] $selectedColor
    hidden [ConsoleColor] $hotkeyColor
    hidden [ConsoleColor] $groupColor
    
    CommandPalette([ActionService]$actionService) : base("CommandPalette") {
        $this.actionService = $actionService
        $this.filteredActions = [List[Action]]::new()
        $this.allActions = [List[Action]]::new()
        $this.selectedIndex = 0
        $this.scrollOffset = 0
        $this.maxVisibleItems = 15
        $this.isOpen = $false
        $this.lastQuery = ""
        
        # Set up as a modal overlay
        $this.IsFocusable = $true
        $this.Enabled = $true
        $this.Visible = $false
        $this.ZIndex = 1000  # High z-index for overlay
        
        # Colors
        $this.borderColor = [ConsoleColor]::Cyan
        $this.backgroundColor = [ConsoleColor]::Black
        $this.foregroundColor = [ConsoleColor]::White
        $this.selectedColor = [ConsoleColor]::Blue
        $this.hotkeyColor = [ConsoleColor]::Yellow
        $this.groupColor = [ConsoleColor]::DarkGray
        
        # Create search box
        $this.searchBox = [TextBoxComponent]::new("CommandSearch")
        $this.searchBox.Placeholder = "Type to search commands..."
        $this.searchBox.X = 2
        $this.searchBox.Y = 2
        $this.searchBox.IsFocusable = $true
        $this.AddChild($this.searchBox)
        
        # Subscribe to search box changes
        $this.searchBox.OnTextChanged = {
            param($sender, $text)
            $this.UpdateFilter($text)
        }.GetNewClosure()
        
        # Subscribe to command palette open event
        Subscribe-Event -EventName "CommandPalette.Open" -Handler {
            $this.Show()
        }.GetNewClosure() -Source "CommandPalette"
        
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Position in center of screen
        $screenWidth = $global:TuiState.BufferWidth
        $screenHeight = $global:TuiState.BufferHeight
        
        $this.Width = [Math]::Min(80, $screenWidth - 10)
        $this.Height = [Math]::Min(25, $screenHeight - 5)
        
        $this.X = [Math]::Floor(($screenWidth - $this.Width) / 2)
        $this.Y = [Math]::Floor(($screenHeight - $this.Height) / 2)
        
        # Resize buffer
        if ($null -ne $this._private_buffer) {
            $this._private_buffer.Resize($this.Width, $this.Height)
        }
        
        # Size search box
        $this.searchBox.Width = $this.Width - 4
        
        # Load all actions
        $this.RefreshActions()
    }
    
    [void] Show() {
        Write-Log -Level Debug -Message "Opening command palette"
        
        $this.isOpen = $true
        $this.Visible = $true
        $this.selectedIndex = 0
        $this.scrollOffset = 0
        $this.lastQuery = ""
        $this.searchBox.Text = ""
        
        # Load recent actions first
        $this.ShowRecentActions()
        
        # Add to overlay stack
        Show-TuiOverlay -Element $this
        
        # Focus the search box
        Set-ComponentFocus -Component $this.searchBox
        
        Request-TuiRefresh
    }
    
    [void] Hide() {
        Write-Log -Level Debug -Message "Closing command palette"
        
        $this.isOpen = $false
        $this.Visible = $false
        
        # Remove from overlay stack
        Close-TopTuiOverlay
        
        Request-TuiRefresh
    }
    
    hidden [void] RefreshActions() {
        $this.allActions.Clear()
        $this.allActions.AddRange($this.actionService.GetAllActions())
    }
    
    hidden [void] ShowRecentActions() {
        $this.filteredActions.Clear()
        $recent = $this.actionService.GetRecentActions(10)
        
        if ($recent.Count -gt 0) {
            $this.filteredActions.AddRange($recent)
        }
        else {
            # Show all actions if no recent
            $this.filteredActions.AddRange($this.allActions)
        }
    }
    
    hidden [void] UpdateFilter([string]$query) {
        $this.lastQuery = $query
        $this.selectedIndex = 0
        $this.scrollOffset = 0
        
        if ([string]::IsNullOrWhiteSpace($query)) {
            $this.ShowRecentActions()
        }
        else {
            $this.filteredActions.Clear()
            $results = $this.actionService.SearchActions($query)
            $this.filteredActions.AddRange($results)
        }
        
        $this.RequestRedraw()
    }
    
    [void] OnRender() {
        if (-not $this.Visible) { return }
        
        # Clear buffer
        $clearCell = [TuiCell]::new(' ', $this.foregroundColor, $this.backgroundColor)
        $this._private_buffer.Clear($clearCell)
        
        # Draw border
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                     -Width $this.Width -Height $this.Height `
                     -Style "Double" -ForegroundColor $this.borderColor `
                     -BackgroundColor $this.backgroundColor
        
        # Draw title
        $title = " Command Palette "
        if ($this.filteredActions.Count -gt 0) {
            $title += "($($this.filteredActions.Count)) "
        }
        Write-TuiText -Buffer $this._private_buffer -Text $title `
                      -X 2 -Y 0 -ForegroundColor $this.foregroundColor
        
        # Draw help text
        $helpText = " ↑↓ Navigate | Enter Execute | Esc Cancel "
        $helpX = $this.Width - $helpText.Length - 2
        Write-TuiText -Buffer $this._private_buffer -Text $helpText `
                      -X $helpX -Y $this.Height - 1 `
                      -ForegroundColor [ConsoleColor]::DarkGray
        
        # Calculate list area
        $listY = 4
        $listHeight = $this.Height - 6
        $visibleCount = [Math]::Min($this.filteredActions.Count, $listHeight)
        
        # Draw action list
        for ($i = 0; $i -lt $visibleCount; $i++) {
            $index = $i + $this.scrollOffset
            if ($index -ge $this.filteredActions.Count) { break }
            
            $action = $this.filteredActions[$index]
            $y = $listY + $i
            $isSelected = ($index -eq $this.selectedIndex)
            
            # Background for selected item
            if ($isSelected) {
                for ($x = 1; $x -lt $this.Width - 1; $x++) {
                    $cell = $this._private_buffer.GetCell($x, $y)
                    $cell.BackgroundColor = $this.selectedColor
                    $this._private_buffer.SetCell($x, $y, $cell)
                }
            }
            
            # Draw action name
            $nameText = $action.Name
            if ($nameText.Length > 40) {
                $nameText = $nameText.Substring(0, 37) + "..."
            }
            Write-TuiText -Buffer $this._private_buffer -Text $nameText `
                          -X 3 -Y $y -ForegroundColor $this.foregroundColor
            
            # Draw group
            $groupX = 45
            Write-TuiText -Buffer $this._private_buffer -Text "[$($action.Group)]" `
                          -X $groupX -Y $y -ForegroundColor $this.groupColor
            
            # Draw hotkey if available
            if ($action.Hotkey) {
                $hotkeyX = $this.Width - $action.Hotkey.Length - 3
                Write-TuiText -Buffer $this._private_buffer -Text $action.Hotkey `
                              -X $hotkeyX -Y $y -ForegroundColor $this.hotkeyColor
            }
        }
        
        # Draw scrollbar if needed
        if ($this.filteredActions.Count -gt $listHeight) {
            $this.DrawScrollbar($listY, $listHeight)
        }
        
        # Draw "no results" message if needed
        if ($this.filteredActions.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($this.lastQuery)) {
            $noResultsText = "No commands match '$($this.lastQuery)'"
            $x = [Math]::Floor(($this.Width - $noResultsText.Length) / 2)
            Write-TuiText -Buffer $this._private_buffer -Text $noResultsText `
                          -X $x -Y ([Math]::Floor($this.Height / 2)) `
                          -ForegroundColor [ConsoleColor]::DarkGray
        }
    }
    
    hidden [void] DrawScrollbar([int]$y, [int]$height) {
        $scrollbarX = $this.Width - 2
        $scrollRatio = [double]$height / $this.filteredActions.Count
        $thumbSize = [Math]::Max(1, [Math]::Floor($height * $scrollRatio))
        $thumbPos = [Math]::Floor($this.scrollOffset * $scrollRatio)
        
        # Draw scrollbar track
        for ($i = 0; $i -lt $height; $i++) {
            $char = '│'
            $color = [ConsoleColor]::DarkGray
            
            # Draw thumb
            if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) {
                $char = '█'
                $color = [ConsoleColor]::Gray
            }
            
            Write-TuiText -Buffer $this._private_buffer -Text $char `
                          -X $scrollbarX -Y ($y + $i) -ForegroundColor $color
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if (-not $this.isOpen) { return $false }
        
        # Let search box handle text input first
        if ($this.searchBox.IsFocused -and $this.searchBox.HandleInput($keyInfo)) {
            return $true
        }
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $this.Hide()
                return $true
            }
            
            ([ConsoleKey]::Enter) {
                if ($this.filteredActions.Count -gt 0 -and $this.selectedIndex -lt $this.filteredActions.Count) {
                    $action = $this.filteredActions[$this.selectedIndex]
                    $this.Hide()
                    
                    # Execute action asynchronously to avoid UI blocking
                    try {
                        $this.actionService.ExecuteAction($action.Id, @{
                            Source = "CommandPalette"
                        })
                    }
                    catch {
                        Show-AlertDialog -Title "Action Failed" -Message $_.Exception.Message
                    }
                }
                return $true
            }
            
            ([ConsoleKey]::UpArrow) {
                if ($this.selectedIndex -gt 0) {
                    $this.selectedIndex--
                    $this.EnsureSelectedVisible()
                    $this.RequestRedraw()
                }
                return $true
            }
            
            ([ConsoleKey]::DownArrow) {
                if ($this.selectedIndex -lt $this.filteredActions.Count - 1) {
                    $this.selectedIndex++
                    $this.EnsureSelectedVisible()
                    $this.RequestRedraw()
                }
                return $true
            }
            
            ([ConsoleKey]::PageUp) {
                $this.selectedIndex = [Math]::Max(0, $this.selectedIndex - $this.maxVisibleItems)
                $this.EnsureSelectedVisible()
                $this.RequestRedraw()
                return $true
            }
            
            ([ConsoleKey]::PageDown) {
                $maxIndex = $this.filteredActions.Count - 1
                $this.selectedIndex = [Math]::Min($maxIndex, $this.selectedIndex + $this.maxVisibleItems)
                $this.EnsureSelectedVisible()
                $this.RequestRedraw()
                return $true
            }
            
            ([ConsoleKey]::Home) {
                $this.selectedIndex = 0
                $this.scrollOffset = 0
                $this.RequestRedraw()
                return $true
            }
            
            ([ConsoleKey]::End) {
                $this.selectedIndex = $this.filteredActions.Count - 1
                $this.EnsureSelectedVisible()
                $this.RequestRedraw()
                return $true
            }
        }
        
        return $false
    }
    
    hidden [void] EnsureSelectedVisible() {
        $listHeight = $this.Height - 6
        
        if ($this.selectedIndex -lt $this.scrollOffset) {
            $this.scrollOffset = $this.selectedIndex
        }
        elseif ($this.selectedIndex -ge ($this.scrollOffset + $listHeight)) {
            $this.scrollOffset = $this.selectedIndex - $listHeight + 1
        }
        
        # Clamp scroll offset
        $maxScroll = [Math]::Max(0, $this.filteredActions.Count - $listHeight)
        $this.scrollOffset = [Math]::Max(0, [Math]::Min($this.scrollOffset, $maxScroll))
    }
    
    [void] OnFocus() {
        # Forward focus to search box
        if ($this.searchBox) {
            Set-ComponentFocus -Component $this.searchBox
        }
    }
}

# Export function for creating command palette
function New-CommandPalette {
    param(
        [ActionService]$ActionService
    )
    
    if (-not $ActionService) {
        throw "ActionService is required for CommandPalette"
    }
    
    return [CommandPalette]::new($ActionService)
}

# Export module members
Export-ModuleMember -Function New-CommandPalette