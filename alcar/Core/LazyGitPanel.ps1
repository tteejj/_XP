# LazyGitPanel - Multi-tab panel container for LazyGit-style interface
# Manages multiple views with tab switching and rendering

using namespace System.Text

class LazyGitPanel {
    # Panel identity and positioning
    [string]$Title
    [int]$X
    [int]$Y  
    [int]$Width
    [int]$Height
    [bool]$IsActive = $false
    [bool]$IsDirty = $true
    
    # Tab management
    [hashtable]$AvailableViews = @{}
    [string[]]$TabOrder = @()
    [int]$CurrentTab = 0
    [ILazyGitView]$CurrentView = $null
    
    # Visual settings
    [bool]$ShowBorder = $false  # LazyGit style = no borders
    [bool]$ShowTabs = $true
    [string]$BorderColor = "`e[38;2;100;100;100m"
    [string]$ActiveTabColor = "`e[38;2;120;160;200m"
    [string]$InactiveTabColor = "`e[38;2;100;100;100m"
    [string]$TitleColor = "`e[38;2;180;180;180m"
    [string]$Reset = "`e[0m"
    
    # Parent screen reference
    [object]$ParentScreen = $null
    
    # Cached rendering elements
    hidden [string]$_lastRendered = ""
    hidden [int]$_lastWidth = 0
    hidden [int]$_lastHeight = 0
    
    LazyGitPanel([string]$title, [int]$x, [int]$y, [int]$width, [int]$height) {
        $this.Title = $title
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
    }
    
    # Add a view to this panel
    [void] AddView([ILazyGitView]$view) {
        $this.AvailableViews[$view.Name] = $view
        $this.TabOrder += $view.Name
        $view.Initialize($this)
        
        # Set as current if first view
        if ($this.CurrentView -eq $null) {
            $this.SwitchToView($view.Name)
        }
    }
    
    # Remove a view from this panel
    [void] RemoveView([string]$viewName) {
        if ($this.AvailableViews.ContainsKey($viewName)) {
            $this.AvailableViews.Remove($viewName)
            $this.TabOrder = $this.TabOrder | Where-Object { $_ -ne $viewName }
            
            # Switch to first available view if current was removed
            if ($this.CurrentView.Name -eq $viewName -and $this.TabOrder.Count -gt 0) {
                $this.SwitchToView($this.TabOrder[0])
            }
        }
    }
    
    # Switch to a specific view by name
    [void] SwitchToView([string]$viewName) {
        if ($this.AvailableViews.ContainsKey($viewName)) {
            # Deactivate current view
            if ($this.CurrentView -ne $null) {
                $this.CurrentView.OnDeactivate()
            }
            
            # Switch to new view
            $this.CurrentView = $this.AvailableViews[$viewName]
            $this.CurrentTab = $this.TabOrder.IndexOf($viewName)
            
            # Activate new view
            $this.CurrentView.OnActivate()
            $this.CurrentView.IsActive = $this.IsActive
            $this.IsDirty = $true
        }
    }
    
    # Switch to next tab
    [void] NextTab() {
        if ($this.TabOrder.Count -gt 1) {
            $this.CurrentTab = ($this.CurrentTab + 1) % $this.TabOrder.Count
            $this.SwitchToView($this.TabOrder[$this.CurrentTab])
        }
    }
    
    # Switch to previous tab
    [void] PrevTab() {
        if ($this.TabOrder.Count -gt 1) {
            $this.CurrentTab = if ($this.CurrentTab -eq 0) { $this.TabOrder.Count - 1 } else { $this.CurrentTab - 1 }
            $this.SwitchToView($this.TabOrder[$this.CurrentTab])
        }
    }
    
    # Set panel active state
    [void] SetActive([bool]$active) {
        $this.IsActive = $active
        if ($this.CurrentView -ne $null) {
            $this.CurrentView.IsActive = $active
            if ($active) {
                $this.CurrentView.OnActivate()
            } else {
                $this.CurrentView.OnDeactivate()
            }
        }
        $this.IsDirty = $true
    }
    
    # Handle input - delegate to current view
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($this.CurrentView -eq $null) {
            return $false
        }
        
        # Check for tab switching first
        if ($key.Key -eq [ConsoleKey]::Tab -and $key.Modifiers -eq [ConsoleModifiers]::None) {
            $this.NextTab()
            return $true
        }
        
        if ($key.Key -eq [ConsoleKey]::Tab -and $key.Modifiers -eq [ConsoleModifiers]::Shift) {
            $this.PrevTab()
            return $true
        }
        
        # Delegate to current view
        return $this.CurrentView.HandleInput($key)
    }
    
    # Main rendering method
    [string] Render() {
        # Check if render is needed
        if (-not $this.IsDirty -and 
            -not ($this.CurrentView -ne $null -and $this.CurrentView.IsDirty) -and
            $this.Width -eq $this._lastWidth -and 
            $this.Height -eq $this._lastHeight) {
            return $this._lastRendered
        }
        
        $output = [StringBuilder]::new(1024)
        
        # Calculate content area
        $contentY = $this.Y
        $contentHeight = $this.Height
        
        # Render tabs if enabled
        if ($this.ShowTabs -and $this.TabOrder.Count -gt 1) {
            [void]$output.Append($this.RenderTabs())
            $contentY += 1
            $contentHeight -= 1
        }
        
        # Render title
        if (-not [string]::IsNullOrEmpty($this.Title)) {
            [void]$output.Append($this.RenderTitle())
            $contentY += 1
            $contentHeight -= 1
        }
        
        # Render current view content
        if ($this.CurrentView -ne $null) {
            $viewContent = $this.CurrentView.Render($this.Width, $contentHeight)
            
            # Position the view content
            $lines = $viewContent -split "`n"
            for ($i = 0; $i -lt [Math]::Min($lines.Count, $contentHeight); $i++) {
                [void]$output.Append("`e[$($contentY + $i + 1);$($this.X + 1)H")
                [void]$output.Append($lines[$i])
            }
            
            $this.CurrentView.IsDirty = $false
        }
        
        # Cache the result
        $this._lastRendered = $output.ToString()
        $this._lastWidth = $this.Width
        $this._lastHeight = $this.Height
        $this.IsDirty = $false
        
        return $this._lastRendered
    }
    
    # Render tab bar
    [string] RenderTabs() {
        $output = [StringBuilder]::new(256)
        [void]$output.Append("`e[$($this.Y + 1);$($this.X + 1)H")
        
        $remainingWidth = $this.Width
        
        for ($i = 0; $i -lt $this.TabOrder.Count; $i++) {
            $viewName = $this.TabOrder[$i]
            $view = $this.AvailableViews[$viewName]
            $tabText = " $($view.ShortName) "
            
            # Add separator between tabs
            if ($i -gt 0) {
                [void]$output.Append(" │ ")  # Vertical bar separator
                $remainingWidth -= 3
            }
            
            if ($remainingWidth -lt $tabText.Length) {
                break  # No more space
            }
            
            # Tab color based on active state
            if ($i -eq $this.CurrentTab) {
                [void]$output.Append("$($this.ActiveTabColor)$tabText$($this.Reset)")
            } else {
                [void]$output.Append("$($this.InactiveTabColor)$tabText$($this.Reset)")
            }
            
            $remainingWidth -= $tabText.Length
        }
        
        return $output.ToString()
    }
    
    # Render panel title
    [string] RenderTitle() {
        $titleY = if ($this.ShowTabs -and $this.TabOrder.Count -gt 1) { $this.Y + 2 } else { $this.Y + 1 }
        $titleText = $this.Title.Length -gt $this.Width ? $this.Title.Substring(0, $this.Width) : $this.Title
        
        return "`e[$titleY;$($this.X + 1)H$($this.TitleColor)$titleText$($this.Reset)"
    }
    
    # Get current view's selected item for cross-panel communication
    [object] GetSelectedItem() {
        if ($this.CurrentView -ne $null) {
            return $this.CurrentView.GetSelectedItem()
        }
        return $null
    }
    
    # Get current view's data
    [object[]] GetData() {
        if ($this.CurrentView -ne $null) {
            return $this.CurrentView.GetData()
        }
        return @()
    }
    
    # Get context commands from current view
    [hashtable] GetContextCommands() {
        if ($this.CurrentView -ne $null) {
            return $this.CurrentView.GetContextCommands()
        }
        return @{}
    }
    
    # Get status from current view
    [string] GetStatus() {
        if ($this.CurrentView -ne $null) {
            return $this.CurrentView.GetStatus()
        }
        return ""
    }
    
    # Refresh current view data
    [void] RefreshData() {
        if ($this.CurrentView -ne $null) {
            $this.CurrentView.RefreshData()
        }
    }
    
    # Force re-render on next frame
    [void] Invalidate() {
        $this.IsDirty = $true
        if ($this.CurrentView -ne $null) {
            $this.CurrentView.IsDirty = $true
        }
    }
    
    # Resize panel
    [void] Resize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        $this.Invalidate()
    }
    
    # Move panel
    [void] MoveTo([int]$x, [int]$y) {
        $this.X = $x
        $this.Y = $y
        $this.Invalidate()
    }
}