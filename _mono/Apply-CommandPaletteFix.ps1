# ==============================================================================
# Apply-CommandPaletteFix.ps1
# This script replaces the CommandPalette class in AllComponents.ps1
# ==============================================================================

Write-Host "`nApplying CommandPalette FINAL FIX..." -ForegroundColor Green
Write-Host "This will replace the CommandPalette class in AllComponents.ps1" -ForegroundColor Yellow

# Read the current AllComponents.ps1
$componentsFile = Join-Path $PSScriptRoot "AllComponents.ps1"
$content = Get-Content -Path $componentsFile -Raw

if (-not $content) {
    Write-Error "Could not read AllComponents.ps1"
    exit 1
}

# Create backup
$backupFile = Join-Path $PSScriptRoot "AllComponents.ps1.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item -Path $componentsFile -Destination $backupFile -Force
Write-Host "Created backup: $backupFile" -ForegroundColor Gray

# Find the CommandPalette class section
$startMarker = "#<!-- PAGE: ACO.016 - CommandPalette Class -->"
$endMarker = "#<!-- END_PAGE: ACO.016 -->"

$startIndex = $content.IndexOf($startMarker)
$endIndex = $content.IndexOf($endMarker)

if ($startIndex -eq -1 -or $endIndex -eq -1) {
    Write-Error "Could not find CommandPalette class markers in AllComponents.ps1"
    exit 1
}

# Include the end marker in the replacement
$endIndex = $endIndex + $endMarker.Length

Write-Host "Found CommandPalette section at positions $startIndex to $endIndex" -ForegroundColor Gray

# Read the fixed CommandPalette class
$fixedContent = @'
#<!-- PAGE: ACO.016 - CommandPalette Class -->
# ===== CLASS: CommandPalette =====
# Module: command-palette
# Dependencies: UIElement, Panel, ListBox, TextBoxComponent
# Purpose: Searchable command interface - FINAL FIXED VERSION
class CommandPalette : UIElement {
    hidden [ListBox]$_listBox
    hidden [TextBoxComponent]$_searchBox  # Using TextBoxComponent directly
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
        # Create main panel
        $this._panel = [Panel]::new("CommandPalette_Panel")
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
        $this._panel.BorderColor = "#00FFFF"
        $this._panel.BackgroundColor = "#000000"
        $this._panel.Title = " Command Palette (Ctrl+P) "
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height
        $this._panel.X = 0
        $this._panel.Y = 0
        $this.AddChild($this._panel)

        # Create search box using TextBoxComponent directly
        $this._searchBox = [TextBoxComponent]::new("CommandPalette_Search")
        $this._searchBox.X = 2
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 3
        $this._searchBox.Placeholder = "Type to search commands..."
        
        # Set up search handler with proper closure
        $paletteRef = $this
        $this._searchBox.OnChange = {
            param($sender, $text)
            $paletteRef.FilterActions($text)
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
        
        # Refresh available actions
        $this.RefreshActions()
        
        # Clear search box
        $this._searchBox.Text = ""
        $this._searchBox.CursorPosition = 0
        $this._searchBox._scrollOffset = 0
        
        # Show all actions initially
        $this.FilterActions("")
        
        # Make visible
        $this.Visible = $true
        
        # Set focus to search box
        $focusManager = $global:TuiState.Services.FocusManager
        if ($focusManager) {
            $focusManager.SetFocus($this._searchBox)
        }
        
        # Request redraw
        $this.RequestRedraw()
        $global:TuiState.IsDirty = $true
    }

    [void] Hide() {
        $this.Visible = $false
        
        # Clear search on hide
        $this._searchBox.Text = ""
        $this._searchBox.CursorPosition = 0
        
        # Force a full screen redraw
        $global:TuiState.IsDirty = $true
        
        # Restore focus to current screen
        $navService = $global:TuiState.Services.NavigationService
        if ($navService -and $navService.CurrentScreen) {
            $navService.CurrentScreen.RequestRedraw()
            
            # Try to restore focus to a focusable element on the screen
            $focusManager = $global:TuiState.Services.FocusManager
            if ($focusManager) {
                $focusManager.FocusNext()
            }
        }
        
        if ($this.OnCancel) {
            & $this.OnCancel
        }
    }

    [void] RefreshActions() {
        $this._allActions.Clear()
        
        if ($this._actionService) {
            $actions = $this._actionService.GetAllActions()
            
            if ($actions -and $actions.Count -gt 0) {
                foreach ($key in $actions.Keys) {
                    $action = $actions[$key]
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
    }

    [void] FilterActions([string]$searchText) {
        $this._filteredActions.Clear()
        $this._listBox.ClearItems()
        
        if ([string]::IsNullOrWhiteSpace($searchText)) {
            # Show all actions
            foreach ($action in $this._allActions) {
                $this._filteredActions.Add($action)
                $displayText = $this.FormatActionDisplay($action)
                $this._listBox.AddItem($displayText)
            }
        }
        else {
            # Filter actions
            $searchLower = $searchText.ToLower()
            foreach ($action in $this._allActions) {
                $nameMatch = $action.Name -and $action.Name.ToLower().Contains($searchLower)
                $descMatch = $action.Description -and $action.Description.ToLower().Contains($searchLower)
                $catMatch = $action.Category -and $action.Category.ToLower().Contains($searchLower)
                
                if ($nameMatch -or $descMatch -or $catMatch) {
                    $this._filteredActions.Add($action)
                    $displayText = $this.FormatActionDisplay($action)
                    $this._listBox.AddItem($displayText)
                }
            }
        }
        
        # Set selection to first item if we have results
        if ($this._filteredActions.Count -gt 0) {
            $this._listBox.SelectedIndex = 0
        }
        
        # Ensure list is refreshed
        $this._listBox.RequestRedraw()
        $this.RequestRedraw()
    }

    hidden [string] FormatActionDisplay([object]$action) {
        $parts = @()
        if ($action.Category) {
            $parts += "[$($action.Category)]"
        }
        $parts += $action.Name
        if ($action.Description) {
            $parts += "- $($action.Description)"
        }
        return $parts -join " "
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        # Handle Escape - always close
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Hide()
            return $true
        }
        
        # Handle Enter - execute selected action
        if ($key.Key -eq [ConsoleKey]::Enter) {
            if ($this._listBox.SelectedIndex -ge 0 -and 
                $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                
                $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                
                if ($selectedAction) {
                    # Hide first
                    $this.Hide()
                    
                    # Then execute
                    if ($this.OnSelect) {
                        & $this.OnSelect $selectedAction
                    }
                    else {
                        # Execute action directly through action service
                        try {
                            $this._actionService.ExecuteAction($selectedAction.Name, @{})
                        }
                        catch {
                            Write-Log -Level "Error" -Message "Failed to execute action: $_"
                        }
                    }
                    return $true
                }
            }
            # If no selection, just stay open and let the Enter be handled by search box
            return $false
        }
        
        # Handle navigation keys - send to list box
        if ($key.Key -in @([ConsoleKey]::UpArrow, [ConsoleKey]::DownArrow, 
                          [ConsoleKey]::PageUp, [ConsoleKey]::PageDown,
                          [ConsoleKey]::Home, [ConsoleKey]::End)) {
            
            # Send to list box
            $handled = $this._listBox.HandleInput($key)
            if ($handled) {
                $this.RequestRedraw()
            }
            return $handled
        }
        
        # All other input goes to search box
        $handled = $this._searchBox.HandleInput($key)
        if ($handled) {
            $this.RequestRedraw()
        }
        return $handled
    }
    
    # Override OnRender to handle rendering properly
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear our buffer
        $bgColor = "#000000"
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # The panel and its children will render themselves through the normal hierarchy
        $this._needs_redraw = $false
    }
}

#<!-- END_PAGE: ACO.016 -->
'@

# Replace the CommandPalette section
$beforeSection = $content.Substring(0, $startIndex)
$afterSection = $content.Substring($endIndex)
$newContent = $beforeSection + $fixedContent + $afterSection

# Write the updated content
Set-Content -Path $componentsFile -Value $newContent -NoNewline -Encoding UTF8

Write-Host "`nCommandPalette fix applied successfully!" -ForegroundColor Green
Write-Host "`nKey changes made:" -ForegroundColor Yellow
Write-Host "  1. Using TextBoxComponent directly instead of TextBox wrapper" -ForegroundColor Gray
Write-Host "  2. Fixed Enter key handling to work regardless of focus" -ForegroundColor Gray
Write-Host "  3. Fixed text box width calculation" -ForegroundColor Gray
Write-Host "  4. Improved focus management" -ForegroundColor Gray
Write-Host "  5. Better action display formatting" -ForegroundColor Gray

Write-Host "`nTo test the fix:" -ForegroundColor Yellow
Write-Host "  1. Restart the application (.\Start.ps1)" -ForegroundColor Gray
Write-Host "  2. Press Ctrl+P to open Command Palette" -ForegroundColor Gray
Write-Host "  3. Type to search for commands" -ForegroundColor Gray
Write-Host "  4. Use arrows to navigate, Enter to execute" -ForegroundColor Gray
Write-Host "  5. Press Escape to close" -ForegroundColor Gray

Write-Host "`nBackup created at: $backupFile" -ForegroundColor Gray
