# ==============================================================================
# Command Palette Module v5.0
# Advanced command palette with fuzzy search and action execution
# ==============================================================================

using module ui-classes
using module tui-primitives
using module theme-manager
using module tui-components
using namespace System.Management.Automation

#region Command Palette Class

class CommandPalette : UIElement {
    hidden [object] $_actionService
    hidden [TextBoxComponent] $_searchBox
    hidden [object[]] $_filteredActions
    hidden [object[]] $_allActions
    hidden [int] $_selectedIndex
    hidden [int] $_scrollOffset
    hidden [string] $_lastQuery

    CommandPalette([object]$actionService) : base("CommandPalette") {
        if (-not $actionService) {
            throw [System.ArgumentNullException]::new('actionService')
        }
        
        $this._actionService = $actionService
        $this._filteredActions = @()
        $this._allActions = @()
        $this._selectedIndex = 0
        $this._scrollOffset = 0
        $this._lastQuery = ""
        
        # Setup as a modal overlay
        $this.IsFocusable = $true
        $this.Enabled = $true
        $this.Visible = $false
        $this.ZIndex = 1000
        
        Write-Verbose "CommandPalette: Constructor called"
        
        # Create and configure the search box child component
        $this._searchBox = New-TuiTextBox -Props @{
            Name = 'CommandPaletteSearch'
            Placeholder = "Type to search actions..."
            Width = 70
            Height = 3
        }
        
        # Set up change handler for search box
        $this._searchBox.OnChange = {
            param($NewValue)
            $this._UpdateFilter($NewValue)
        }.GetNewClosure()
        
        $this.AddChild($this._searchBox)
        
        # Listen for activation events
        $paletteInstance = $this
        Subscribe-Event -EventName "CommandPalette.Open" -Handler {
            $paletteInstance.Show()
        }.GetNewClosure() -Source "CommandPalette"
        
        Write-Verbose "CommandPalette: Initialization complete"
    }

    [void] Show() {
        try {
            Write-Log -Level Debug -Message "Opening Command Palette"
            
            # Center and size the palette based on current screen dimensions
            $screenWidth = $global:TuiState.BufferWidth
            $screenHeight = $global:TuiState.BufferHeight
            
            $this.Width = [Math]::Min(80, $screenWidth - 10)
            $this.Height = [Math]::Min(20, $screenHeight - 6)
            $this.X = [Math]::Floor(($screenWidth - $this.Width) / 2)
            $this.Y = [Math]::Floor(($screenHeight - $this.Height) / 4)
            
            # Ensure buffer is properly sized
            if ($null -eq $this._private_buffer -or $this._private_buffer.Width -ne $this.Width -or $this._private_buffer.Height -ne $this.Height) {
                $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
            }

            # Position and size the search box within the palette
            $this._searchBox.Move(2, 2)
            $this._searchBox.Resize($this.Width - 4, 3)

            # Reset state
            $this.Visible = $true
            $this._selectedIndex = 0
            $this._scrollOffset = 0
            $this._searchBox.Text = ""
            $this._lastQuery = ""

            # Load actions from service
            $this._allActions = $this._actionService.GetAllActions()
            $this._filteredActions = $this._allActions
            
            # Show overlay and set focus
            Show-TuiOverlay -Element $this
            Set-ComponentFocus -Component $this._searchBox
            Request-TuiRefresh
            
            Write-Verbose "CommandPalette: Shown successfully"
        }
        catch {
            Write-Error "CommandPalette: Error showing palette: $($_.Exception.Message)"
        }
    }

    [void] Hide() {
        try {
            Write-Log -Level Debug -Message "Closing Command Palette"
            
            $this.Visible = $false
            Close-TopTuiOverlay
            
            # Clear focus
            if ($global:TuiState.FocusedComponent -eq $this._searchBox) {
                Set-ComponentFocus -Component $null
            }
            
            Request-TuiRefresh
            
            Write-Verbose "CommandPalette: Hidden successfully"
        }
        catch {
            Write-Error "CommandPalette: Error hiding palette: $($_.Exception.Message)"
        }
    }

    hidden [void] _UpdateFilter([string]$query) {
        try {
            $this._lastQuery = $query
            $this._selectedIndex = 0
            $this._scrollOffset = 0

            if ([string]::IsNullOrWhiteSpace($query)) {
                $this._filteredActions = $this._allActions
            }
            else {
                # Perform fuzzy search on name and description
                $this._filteredActions = $this._allActions | Where-Object { 
                    $_.Name -like "*$query*" -or $_.Description -like "*$query*" 
                }
            }
            
            $this.RequestRedraw()
            Write-Verbose "CommandPalette: Filter updated, $($this._filteredActions.Count) results"
        }
        catch {
            Write-Error "CommandPalette: Error updating filter: $($_.Exception.Message)"
        }
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = Get-ThemeColor 'Background'
            $borderColor = Get-ThemeColor 'Accent'
            $fgColor = Get-ThemeColor 'Foreground'
            $selectionBg = Get-ThemeColor 'Selection'
            $selectionFg = Get-ThemeColor 'Background'
            $subtleColor = Get-ThemeColor 'Subtle'
            
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            
            # Draw border with title
            $title = " Command Palette ($($this._filteredActions.Count)) "
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -Title $title -BorderStyle "Double" -BorderColor $borderColor -BackgroundColor $bgColor

            # Draw help text in bottom border
            $helpText = " [↑↓] Navigate | [Enter] Execute | [Esc] Close "
            if ($helpText.Length -lt ($this.Width - 2)) {
                $helpX = $this.Width - $helpText.Length - 1
                Write-TuiText -Buffer $this._private_buffer -X $helpX -Y ($this.Height - 1) -Text $helpText -ForegroundColor $subtleColor -BackgroundColor $bgColor
            }

            # Calculate list area
            $listY = 5 # Start list below the search box
            $listHeight = $this.Height - 6
            
            # Render action list
            for ($i = 0; $i -lt $listHeight; $i++) {
                $dataIndex = $i + $this._scrollOffset
                if ($dataIndex -ge $this._filteredActions.Count) { break }
                
                $action = $this._filteredActions[$dataIndex]
                $yPos = $listY + $i
                $isSelected = ($dataIndex -eq $this._selectedIndex)
                
                # Colors based on selection
                $itemBg = if ($isSelected) { $selectionBg } else { $bgColor }
                $itemFg = if ($isSelected) { $selectionFg } else { $fgColor }
                
                # Draw selection highlight bar
                $highlightText = ' ' * ($this.Width - 2)
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y $yPos -Text $highlightText -ForegroundColor $itemFg -BackgroundColor $itemBg

                # Draw action name and description
                $displayText = " $($action.Name)"
                if ($action.Description) {
                    $displayText += ": $($action.Description)"
                }
                
                # Truncate if too long
                $maxWidth = $this.Width - 4
                if ($displayText.Length -gt $maxWidth) {
                    $displayText = $displayText.Substring(0, $maxWidth - 3) + "..."
                }
                
                Write-TuiText -Buffer $this._private_buffer -X 2 -Y $yPos -Text $displayText -ForegroundColor $itemFg -BackgroundColor $itemBg
            }

            # Show "no results" message if needed
            if ($this._filteredActions.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($this._lastQuery)) {
                $noResultsText = "No actions match '$($this._lastQuery)'"
                $centerX = [Math]::Floor(($this.Width - $noResultsText.Length) / 2)
                $centerY = [Math]::Floor($this.Height / 2)
                Write-TuiText -Buffer $this._private_buffer -X $centerX -Y $centerY -Text $noResultsText -ForegroundColor $subtleColor -BackgroundColor $bgColor
            }
            
            Write-Verbose "CommandPalette: Rendered successfully"
        }
        catch {
            Write-Error "CommandPalette: Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if (-not $this.Visible) { return $false }
        if ($null -eq $keyInfo) { return $false }
        
        try {
            # If search box is focused, let it handle character input first
            if ($this._searchBox.IsFocused) {
                # But we intercept navigation keys before the textbox can consume them
                switch ($keyInfo.Key) {
                    ([ConsoleKey]::UpArrow) { }
                    ([ConsoleKey]::DownArrow) { }
                    ([ConsoleKey]::PageUp) { }
                    ([ConsoleKey]::PageDown) { }
                    ([ConsoleKey]::Home) { }
                    ([ConsoleKey]::End) { }
                    ([ConsoleKey]::Enter) { }
                    ([ConsoleKey]::Escape) { }
                    default { 
                        if ($this._searchBox.HandleInput($keyInfo)) {
                            return $true
                        }
                    }
                }
            }
            
            # Handle palette-specific navigation
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Escape) {
                    $this.Hide()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($this._filteredActions.Count -gt 0 -and $this._selectedIndex -lt $this._filteredActions.Count) {
                        $action = $this._filteredActions[$this._selectedIndex]
                        $this.Hide()
                        
                        try {
                            # Execute the selected action
                            $this._actionService.ExecuteAction($action.Name)
                            Write-Log -Level Info -Message "Executed action: $($action.Name)"
                        }
                        catch {
                            Write-Error "Failed to execute action '$($action.Name)': $($_.Exception.Message)"
                            if (Get-Command Show-AlertDialog -ErrorAction SilentlyContinue) {
                                Show-AlertDialog -Title "Action Failed" -Message "Failed to execute action: $($_.Exception.Message)"
                            }
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this._selectedIndex -gt 0) {
                        $this._selectedIndex--
                        $this._EnsureSelectedVisible()
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this._selectedIndex -lt ($this._filteredActions.Count - 1)) {
                        $this._selectedIndex++
                        $this._EnsureSelectedVisible()
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::PageUp) {
                    $pageSize = $this.Height - 6
                    $this._selectedIndex = [Math]::Max(0, $this._selectedIndex - $pageSize)
                    $this._EnsureSelectedVisible()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::PageDown) {
                    $pageSize = $this.Height - 6
                    $this._selectedIndex = [Math]::Min($this._filteredActions.Count - 1, $this._selectedIndex + $pageSize)
                    $this._EnsureSelectedVisible()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $this._selectedIndex = 0
                    $this._EnsureSelectedVisible()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::End) {
                    $this._selectedIndex = $this._filteredActions.Count - 1
                    $this._EnsureSelectedVisible()
                    $this.RequestRedraw()
                    return $true
                }
            }
            
            return $false
        }
        catch {
            Write-Error "CommandPalette: Error handling input: $($_.Exception.Message)"
            return $false
        }
    }
    
    hidden [void] _EnsureSelectedVisible() {
        $listHeight = $this.Height - 6
        
        # Scroll up if selected item is above visible area
        if ($this._selectedIndex -lt $this._scrollOffset) {
            $this._scrollOffset = $this._selectedIndex
        }
        # Scroll down if selected item is below visible area
        elseif ($this._selectedIndex -ge ($this._scrollOffset + $listHeight)) {
            $this._scrollOffset = $this._selectedIndex - $listHeight + 1
        }
        
        # Ensure scroll offset is within bounds
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
    }

    [string] ToString() {
        return "CommandPalette(Name='$($this.Name)', Actions=$($this._allActions.Count), Filtered=$($this._filteredActions.Count), Selected=$($this._selectedIndex))"
    }
}

#endregion

#region Factory Functions

function Register-CommandPalette {
    <#
    .SYNOPSIS
    Registers the Command Palette component with the application.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ActionService,
        
        [Parameter(Mandatory)]
        [object]$KeybindingService
    )

    try {
        Write-Log -Level Info -Message "Registering Command Palette"
        
        # Create the Command Palette instance
        $palette = [CommandPalette]::new($ActionService)

        # Register the action that opens the palette
        $ActionService.RegisterAction(
            "app.showCommandPalette", 
            "Show the command palette for quick action access", 
            { 
                Publish-Event -EventName "CommandPalette.Open" 
            }, 
            "Application",
            $false # Don't force overwrite
        )

        # FIX: The call to SetBinding is now unambiguous.
        # It uses [System.ConsoleKey]::P which uniquely matches the ConsoleKey overload.
        $KeybindingService.SetBinding("app.showCommandPalette", [System.ConsoleKey]::P, [string[]]@('Ctrl'))
        
        Write-Log -Level Info -Message "Command Palette registered successfully with Ctrl+P keybinding"
        
        return $palette
    }
    catch {
        Write-Error "Failed to register Command Palette: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Module Exports

# Export public functions
Export-ModuleMember -Function Register-CommandPalette

# Classes are automatically exported in PowerShell 7+
# CommandPalette class is available when module is imported

#endregion