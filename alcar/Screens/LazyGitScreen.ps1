# LazyGitScreen - Complete LazyGit-style multi-panel interface
# Combines layout, panels, views, and focus management into a full screen

# Load required components
. "$PSScriptRoot/../Core/ILazyGitView.ps1"
. "$PSScriptRoot/../Core/LazyGitPanel.ps1"
. "$PSScriptRoot/../Core/LazyGitRenderer.ps1"
. "$PSScriptRoot/../Core/LazyGitLayout.ps1"
. "$PSScriptRoot/../Core/LazyGitFocusManager.ps1"
. "$PSScriptRoot/../Views/TestViews.ps1"

using namespace System.Text

class LazyGitScreen : Screen {
    # Core components
    [LazyGitLayout]$Layout
    [LazyGitRenderer]$Renderer
    [LazyGitFocusManager]$FocusManager
    
    # Panels
    [LazyGitPanel[]]$LeftPanels = @()
    [LazyGitPanel]$MainPanel
    [TestCommandPalette]$CommandPalette
    
    # Screen state
    [bool]$IsInitialized = $false
    [bool]$NeedsLayoutUpdate = $true
    [bool]$ShowHelp = $false
    [string]$StatusMessage = ""
    
    # Performance tracking
    [int]$FrameCount = 0
    [double]$AverageFrameTime = 0
    
    # Panel view configurations (customizable)
    [hashtable]$PanelViewConfigs = @{
        0 = @{ DefaultView = "FilterListView"; Title = "Filters" }
        1 = @{ DefaultView = "ProjectTreeView"; Title = "Projects" }
        2 = @{ DefaultView = "TestListView"; Title = "Tasks" }
        3 = @{ DefaultView = "TestListView"; Title = "Recent" }
        4 = @{ DefaultView = "TestListView"; Title = "Bookmarks" }
        5 = @{ DefaultView = "TestListView"; Title = "Actions" }
    }
    
    LazyGitScreen() {
        $this.Title = "LazyGit-Style Interface"
        $this.Initialize()
    }
    
    [void] Initialize() {
        try {
            Write-Host "Initializing LazyGitScreen..." -ForegroundColor Cyan
            
            # Create core components
            $this.Layout = [LazyGitLayout]::new()
            $this.Renderer = [LazyGitRenderer]::new(8192)
            $this.FocusManager = [LazyGitFocusManager]::new()
            $this.CommandPalette = [TestCommandPalette]::new()
            
            # Create panels based on layout
            $this.CreatePanels()
            
            # Setup views for each panel
            $this.SetupPanelViews()
            
            # Initialize focus management
            $this.FocusManager.Initialize($this.LeftPanels, $this.MainPanel, $this.CommandPalette)
            
            # Setup key bindings
            $this.InitializeKeyBindings()
            
            $this.IsInitialized = $true
            $this.NeedsLayoutUpdate = $true
            
            Write-Host "LazyGitScreen initialized successfully" -ForegroundColor Green
        } catch {
            Write-Host "LazyGitScreen initialization failed: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }
    
    # Create panels based on layout configuration
    [void] CreatePanels() {
        # Get layout configurations
        $leftConfigs = $this.Layout.GetLeftPanelConfigs()
        $mainConfig = $this.Layout.GetMainPanelConfig()
        
        # Create left panels
        $this.LeftPanels = @()
        foreach ($config in $leftConfigs) {
            $panelTitle = $this.PanelViewConfigs[$config.Index].Title
            $panel = [LazyGitPanel]::new(
                $panelTitle,
                $config.X,
                $config.Y,
                $config.Width,
                $config.Height
            )
            $panel.ShowBorder = $this.Layout.ShowBorders
            $this.LeftPanels += $panel
        }
        
        # Create main panel
        $this.MainPanel = [LazyGitPanel]::new(
            "Details",
            $mainConfig.X,
            $mainConfig.Y,
            $mainConfig.Width,
            $mainConfig.Height
        )
        $this.MainPanel.ShowBorder = $this.Layout.ShowBorders
        $this.MainPanel.ShowTabs = $false  # Main panel typically single view
    }
    
    # Setup views for each panel based on configuration
    [void] SetupPanelViews() {
        # Left panel views
        for ($i = 0; $i -lt $this.LeftPanels.Count; $i++) {
            $panel = $this.LeftPanels[$i]
            $config = $this.PanelViewConfigs[$i]
            
            switch ($config.DefaultView) {
                "FilterListView" {
                    $view = [FilterListView]::new()
                    $panel.AddView($view)
                }
                "ProjectTreeView" {
                    $view = [ProjectTreeView]::new()
                    $panel.AddView($view)
                    
                    # Add additional views to demonstrate tabs
                    $recentView = [TestListView]::new("Recent Projects", "REC", @("ALCAR.sln", "Phoenix.ps1", "TaskManager.proj"))
                    $panel.AddView($recentView)
                }
                "TestListView" {
                    # Create different test lists based on panel title
                    $items = switch ($panel.Title) {
                        "Tasks" { @("Implement LazyGit UI", "Fix render performance", "Add command palette", "Update documentation") }
                        "Recent" { @("TaskScreen.ps1", "LazyGitPanel.ps1", "test-phase1.ps1", "ALCAR_ANALYSIS.md") }
                        "Bookmarks" { @("Project Dashboard", "Critical Tasks", "Recent Commits", "Performance Metrics") }
                        "Actions" { @("New Task", "New Project", "Export Data", "Settings", "Refresh All", "Quit") }
                        default { @("Item 1", "Item 2", "Item 3", "Item 4", "Item 5") }
                    }
                    
                    $view = [TestListView]::new($panel.Title, $panel.Title.Substring(0, 3).ToUpper(), $items)
                    $panel.AddView($view)
                }
            }
        }
        
        # Main panel view (detail view)
        $detailView = [TaskDetailView]::new()
        $this.MainPanel.AddView($detailView)
    }
    
    # Initialize key bindings
    [void] InitializeKeyBindings() {
        # Global bindings (handled by FocusManager)
        # Ctrl+Tab, Ctrl+Shift+Tab - Panel navigation
        # Ctrl+P - Command palette
        # Alt+1-9,0 - Direct panel access
        # Esc - Exit command palette
        
        # Screen-specific bindings
        $this.BindKey([ConsoleKey]::F1, { $this.ToggleHelp() })
        $this.BindKey([ConsoleKey]::F5, { $this.RefreshAll() })
        $this.BindKey([ConsoleKey]::F12, { $this.ShowLayoutInfo() })
        $this.BindKey('q', { $this.Quit() })
    }
    
    # Main rendering method
    [string] RenderContent() {
        # Check if layout needs updating (terminal resize)
        if ($this.Layout.NeedsRecalculation()) {
            $this.UpdateLayout()
        }
        
        # Begin frame
        $buffer = $this.Renderer.BeginFrame()
        
        # Render all panels
        $this.Renderer.RenderPanels($this.LeftPanels)
        [void]$buffer.Append($this.MainPanel.Render())
        
        # Render command palette
        $this.RenderCommandPalette($buffer)
        
        # Render status line and help
        $this.RenderStatusAndHelp($buffer)
        
        # End frame and return content (but don't actually call EndFrame here)
        return $buffer.ToString()
    }
    
    # Handle input with focus management
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        # Let focus manager handle input first (global hotkeys, panel routing)
        if ($this.FocusManager.HandleInput($key)) {
            return $true
        }
        
        # Handle screen-specific keys
        switch ($key.Key) {
            ([ConsoleKey]::F1) {
                $this.ToggleHelp()
                return $true
            }
            ([ConsoleKey]::F5) {
                $this.RefreshAll()
                return $true
            }
            ([ConsoleKey]::F12) {
                $this.ShowLayoutInfo()
                return $true
            }
        }
        
        # Handle character keys
        if ($key.KeyChar) {
            switch ($key.KeyChar) {
                'q' {
                    if ($this.FocusManager.FocusMode -ne "Command") {
                        $this.Active = $false
                        return $true
                    }
                }
                'r' {
                    if ($this.FocusManager.FocusMode -ne "Command") {
                        $this.RefreshAll()
                        return $true
                    }
                }
                '?' {
                    if ($this.FocusManager.FocusMode -ne "Command") {
                        $this.ToggleHelp()
                        return $true
                    }
                }
            }
        }
        
        return $false
    }
    
    # Update layout on terminal resize
    [void] UpdateLayout() {
        $this.Layout.UpdateTerminalSize()
        $this.Layout.AutoAdjust()
        
        # Update panel positions and sizes
        $leftConfigs = $this.Layout.GetLeftPanelConfigs()
        for ($i = 0; $i -lt $this.LeftPanels.Count -and $i -lt $leftConfigs.Count; $i++) {
            $config = $leftConfigs[$i]
            $this.LeftPanels[$i].MoveTo($config.X, $config.Y)
            $this.LeftPanels[$i].Resize($config.Width, $config.Height)
        }
        
        # Update main panel
        $mainConfig = $this.Layout.GetMainPanelConfig()
        $this.MainPanel.MoveTo($mainConfig.X, $mainConfig.Y)
        $this.MainPanel.Resize($mainConfig.Width, $mainConfig.Height)
        
        $this.NeedsLayoutUpdate = $false
        $this.SetStatusMessage("Layout updated: $($this.Layout.LayoutMode) mode")
    }
    
    # Render command palette
    [void] RenderCommandPalette([StringBuilder]$buffer) {
        $paletteConfig = $this.Layout.GetCommandPaletteConfig()
        
        # Position cursor
        [void]$buffer.Append($this.Renderer.MoveTo($paletteConfig.X + 1, $paletteConfig.Y + 1))
        
        # Render palette content
        [void]$buffer.Append($this.CommandPalette.Render())
    }
    
    # Render status line and help
    [void] RenderStatusAndHelp([StringBuilder]$buffer) {
        $termHeight = $this.Layout.TerminalHeight
        $termWidth = $this.Layout.TerminalWidth
        
        # Status line (above command palette)
        $statusY = $termHeight - $this.Layout.CommandPaletteHeight
        [void]$buffer.Append($this.Renderer.MoveTo(1, $statusY))
        
        $focusState = $this.FocusManager.GetFocusState()
        $layoutStats = $this.Layout.GetLayoutStats()
        
        $statusText = "Panel: $($focusState.FocusedPanelName) | Layout: $($layoutStats.LayoutMode) | "
        if (-not [string]::IsNullOrEmpty($this.StatusMessage)) {
            $statusText += $this.StatusMessage
        } else {
            $statusText += "F1=Help F5=Refresh F12=Layout Q=Quit"
        }
        
        # Truncate status to fit
        if ($statusText.Length -gt ($termWidth - 2)) {
            $statusText = $statusText.Substring(0, $termWidth - 5) + "..."
        }
        
        [void]$buffer.Append($this.Renderer.GetVT("fg_dim"))
        [void]$buffer.Append($statusText)
        [void]$buffer.Append($this.Renderer.GetVT("reset"))
        
        # Help overlay
        if ($this.ShowHelp) {
            $this.RenderHelpOverlay($buffer)
        }
    }
    
    # Render help overlay
    [void] RenderHelpOverlay([StringBuilder]$buffer) {
        $helpLines = $this.FocusManager.GetNavigationHelp()
        $helpWidth = 50
        $helpHeight = $helpLines.Count + 2
        $startX = ([Console]::WindowWidth - $helpWidth) / 2
        $startY = ([Console]::WindowHeight - $helpHeight) / 2
        
        # Background
        for ($y = 0; $y -lt $helpHeight; $y++) {
            [void]$buffer.Append($this.Renderer.MoveTo($startX, $startY + $y))
            [void]$buffer.Append($this.Renderer.GetVT("bg_selected"))
            [void]$buffer.Append(" " * $helpWidth)
            [void]$buffer.Append($this.Renderer.GetVT("reset"))
        }
        
        # Help content
        for ($i = 0; $i -lt $helpLines.Count; $i++) {
            [void]$buffer.Append($this.Renderer.MoveTo($startX + 2, $startY + $i + 1))
            [void]$buffer.Append($this.Renderer.GetVT("fg_bright"))
            [void]$buffer.Append($helpLines[$i])
            [void]$buffer.Append($this.Renderer.GetVT("reset"))
        }
    }
    
    # Screen commands
    [void] ToggleHelp() {
        $this.ShowHelp = -not $this.ShowHelp
        $this.SetStatusMessage(if ($this.ShowHelp) { "Help shown" } else { "Help hidden" })
    }
    
    [void] RefreshAll() {
        foreach ($panel in $this.LeftPanels) {
            $panel.RefreshData()
        }
        $this.MainPanel.RefreshData()
        $this.SetStatusMessage("All panels refreshed")
    }
    
    [void] ShowLayoutInfo() {
        $layoutInfo = $this.Layout.ExportLayout()
        Write-Host $layoutInfo -ForegroundColor Yellow
        $this.SetStatusMessage("Layout info exported to console")
    }
    
    [void] Quit() {
        $this.Active = $false
    }
    
    [void] SetStatusMessage([string]$message) {
        $this.StatusMessage = $message
        # Clear status message after 3 seconds (in real implementation)
    }
    
    # Get screen statistics
    [hashtable] GetScreenStats() {
        $rendererStats = $this.Renderer.GetStats()
        $layoutStats = $this.Layout.GetLayoutStats()
        $focusStats = $this.FocusManager.GetFocusState()
        
        return @{
            FrameCount = $this.FrameCount
            AverageFrameTime = $this.AverageFrameTime
            LayoutMode = $layoutStats.LayoutMode
            LeftPanelCount = $layoutStats.LeftPanelCount
            FocusedPanel = $focusStats.FocusedPanelName
            RendererCacheSize = $rendererStats.CacheSize
            LastFrameSize = $rendererStats.LastFrameSize
        }
    }
    
    # Cleanup resources
    [void] Dispose() {
        if ($this.Renderer -ne $null) {
            $this.Renderer.Dispose()
        }
        
        if ($this.FocusManager -ne $null) {
            $this.FocusManager.Reset()
        }
    }
}