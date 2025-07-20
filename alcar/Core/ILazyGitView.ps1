# ILazyGitView Interface - Pluggable view system for LazyGit-style panels
# Provides contract for any component that can be displayed in a LazyGit panel

# Interface definition for LazyGit views
# All views must implement these methods for proper panel integration
class ILazyGitView {
    # Core view properties
    [string]$Name
    [string]$ShortName  # For tabs (2-3 chars)
    [bool]$IsActive = $false
    [bool]$IsDirty = $true
    
    # Parent panel reference
    [object]$ParentPanel = $null
    
    # Constructor
    ILazyGitView([string]$name, [string]$shortName) {
        $this.Name = $name
        $this.ShortName = $shortName
    }
    
    # Primary rendering method - must be implemented by derived classes
    # Returns VT100 string ready for console output
    [string] Render([int]$width, [int]$height) {
        throw "Render method must be implemented by derived class"
    }
    
    # Input handling - return $true if input was consumed
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        throw "HandleInput method must be implemented by derived class"
    }
    
    # Data retrieval for cross-panel communication
    [object[]] GetData() {
        throw "GetData method must be implemented by derived class"
    }
    
    # Optional: Get selected item for cross-panel updates
    [object] GetSelectedItem() {
        return $null
    }
    
    # Optional: Set selection programmatically (for cross-panel sync)
    [void] SetSelection([object]$item) {
        # Default: no-op
    }
    
    # Optional: Refresh data from source
    [void] RefreshData() {
        $this.IsDirty = $true
    }
    
    # Optional: Get context-sensitive commands for command palette
    [hashtable] GetContextCommands() {
        return @{}
    }
    
    # Optional: Handle view activation (when panel gains focus)
    [void] OnActivate() {
        $this.IsActive = $true
    }
    
    # Optional: Handle view deactivation (when panel loses focus)  
    [void] OnDeactivate() {
        $this.IsActive = $false
    }
    
    # Optional: Get status text for display
    [string] GetStatus() {
        return ""
    }
    
    # Optional: Initialize view with parent panel reference
    [void] Initialize([object]$parentPanel) {
        $this.ParentPanel = $parentPanel
    }
}

# Base implementation with common functionality
class LazyGitViewBase : ILazyGitView {
    # Common state
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [object[]]$Items = @()
    
    # Common colors (cached VT sequences)
    hidden [string]$_selectedBG = "`e[48;2;60;80;120m"
    hidden [string]$_normalFG = "`e[38;2;220;220;220m" 
    hidden [string]$_dimFG = "`e[38;2;150;150;150m"
    hidden [string]$_reset = "`e[0m"
    
    LazyGitViewBase([string]$name, [string]$shortName) : base($name, $shortName) {
    }
    
    # Common navigation methods
    [void] MoveUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.IsDirty = $true
            $this.EnsureVisible()
        }
    }
    
    [void] MoveDown() {
        if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
            $this.SelectedIndex++
            $this.IsDirty = $true
            $this.EnsureVisible()
        }
    }
    
    [void] PageUp([int]$pageSize) {
        $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
        $this.IsDirty = $true
        $this.EnsureVisible()
    }
    
    [void] PageDown([int]$pageSize) {
        $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $pageSize)
        $this.IsDirty = $true
        $this.EnsureVisible()
    }
    
    [void] EnsureVisible() {
        # This will be called with actual height from the view
    }
    
    [void] EnsureVisible([int]$visibleHeight) {
        # Scroll if selection is outside visible area
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $visibleHeight)) {
            $this.ScrollOffset = $this.SelectedIndex - $visibleHeight + 1
        }
    }
    
    # Default input handling for list-based views
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) { 
                $this.MoveUp()
                return $true
            }
            ([ConsoleKey]::DownArrow) { 
                $this.MoveDown()
                return $true
            }
            ([ConsoleKey]::PageUp) { 
                $this.PageUp(10)
                return $true
            }
            ([ConsoleKey]::PageDown) { 
                $this.PageDown(10)
                return $true
            }
            ([ConsoleKey]::Home) { 
                $this.SelectedIndex = 0
                $this.ScrollOffset = 0
                $this.IsDirty = $true
                return $true
            }
            ([ConsoleKey]::End) { 
                $this.SelectedIndex = $this.Items.Count - 1
                $this.EnsureVisible()
                $this.IsDirty = $true
                return $true
            }
        }
        return $false
    }
    
    # Helper method to render a list item with selection highlighting
    [string] RenderListItem([int]$index, [string]$text, [int]$width) {
        $truncated = if ($text.Length -gt $width) {
            $text.Substring(0, $width - 3) + "..."
        } else {
            $text.PadRight($width)
        }
        
        if ($index -eq $this.SelectedIndex -and $this.IsActive) {
            return "$($this._selectedBG)$truncated$($this._reset)"
        } else {
            return "$($this._normalFG)$truncated$($this._reset)"
        }
    }
    
    # Default implementations
    [object[]] GetData() {
        return $this.Items
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
}