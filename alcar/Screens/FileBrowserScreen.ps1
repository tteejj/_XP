# FileBrowserScreen - Ranger-style three-column file browser

class FileBrowserScreen : Screen {
    # Panels
    hidden [Panel]$ParentPanel
    hidden [Panel]$CurrentPanel
    hidden [Panel]$PreviewPanel
    
    # ListBoxes
    hidden [ListBox]$ParentList
    hidden [ListBox]$CurrentList
    hidden [ListBox]$PreviewList
    
    # State
    [string]$CurrentPath
    [int]$FocusedPanel = 1  # 0=parent, 1=current, 2=preview
    hidden [hashtable]$FileCache = @{}
    
    FileBrowserScreen() {
        $this.Title = "File Browser"
        $this.CurrentPath = (Get-Location).Path
        $this.Initialize()
    }
    
    [void] Initialize() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        $panelWidth = [int]($width / 3)
        
        # Parent directory panel
        $this.ParentPanel = [Panel]::new("ParentPanel")
        $this.ParentPanel.X = 0
        $this.ParentPanel.Y = 2
        $this.ParentPanel.Width = $panelWidth
        $this.ParentPanel.Height = $height - 4
        $this.ParentPanel.Title = "Parent"
        $this.ParentPanel.BorderStyle = "Single"
        
        $this.ParentList = [ListBox]::new("ParentList")
        $this.ParentList.X = 1
        $this.ParentList.Y = 1
        $this.ParentList.Width = $panelWidth - 2
        $this.ParentList.Height = $height - 6
        $this.ParentList.HasBorder = $false
        $this.ParentList.ItemFormatter = { param($item) $this.FormatFileItem($item) }.GetNewClosure()
        $this.ParentPanel.AddChild($this.ParentList)
        
        # Current directory panel
        $this.CurrentPanel = [Panel]::new("CurrentPanel")
        $this.CurrentPanel.X = $panelWidth
        $this.CurrentPanel.Y = 2
        $this.CurrentPanel.Width = $panelWidth
        $this.CurrentPanel.Height = $height - 4
        $this.CurrentPanel.Title = "Current"
        $this.CurrentPanel.BorderStyle = "Double"
        
        $this.CurrentList = [ListBox]::new("CurrentList")
        $this.CurrentList.X = 1
        $this.CurrentList.Y = 1
        $this.CurrentList.Width = $panelWidth - 2
        $this.CurrentList.Height = $height - 6
        $this.CurrentList.HasBorder = $false
        $this.CurrentList.ItemFormatter = { param($item) $this.FormatFileItem($item) }.GetNewClosure()
        $this.CurrentList.OnSelectionChanged = { param($sender, $index) $this.OnCurrentSelectionChanged() }.GetNewClosure()
        $this.CurrentPanel.AddChild($this.CurrentList)
        
        # Preview panel
        $this.PreviewPanel = [Panel]::new("PreviewPanel")
        $this.PreviewPanel.X = $panelWidth * 2
        $this.PreviewPanel.Y = 2
        $this.PreviewPanel.Width = $width - ($panelWidth * 2)
        $this.PreviewPanel.Height = $height - 4
        $this.PreviewPanel.Title = "Preview"
        $this.PreviewPanel.BorderStyle = "Single"
        
        $this.PreviewList = [ListBox]::new("PreviewList")
        $this.PreviewList.X = 1
        $this.PreviewList.Y = 1
        $this.PreviewList.Width = $this.PreviewPanel.Width - 2
        $this.PreviewList.Height = $height - 6
        $this.PreviewList.HasBorder = $false
        $this.PreviewPanel.AddChild($this.PreviewList)
        
        # Load initial directory
        $this.LoadDirectory($this.CurrentPath)
        
        # Key bindings
        $this.InitializeKeyBindings()
        
        # Status bar
        $this.UpdateStatusBar()
    }
    
    [void] InitializeKeyBindings() {
        # Navigation
        $this.BindKey([ConsoleKey]::UpArrow, { $this.NavigateUp() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.NavigateDown() })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.NavigateLeft() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.NavigateRight() })
        $this.BindKey([ConsoleKey]::Enter, { $this.OpenSelected() })
        $this.BindKey([ConsoleKey]::Backspace, { $this.NavigateUp() })
        
        # Quick navigation
        $this.BindKey('h', { $this.NavigateLeft() })
        $this.BindKey('j', { $this.NavigateDown() })
        $this.BindKey('k', { $this.NavigateUp() })
        $this.BindKey('l', { $this.NavigateRight() })
        $this.BindKey('g', { $this.GoToTop() })
        $this.BindKey('G', { $this.GoToBottom() })
        
        # File operations
        $this.BindKey('e', { $this.EditSelected() })
        $this.BindKey('v', { $this.ViewSelected() })
        $this.BindKey('/', { $this.StartSearch() })
        $this.BindKey('.', { $this.ToggleHidden() })
        
        # Exit
        $this.BindKey('q', { $this.Active = $false })
        $this.BindKey([ConsoleKey]::Escape, { $this.Active = $false })
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        $this.AddStatusItem('hjkl/arrows', 'navigate')
        $this.AddStatusItem('enter', 'open')
        $this.AddStatusItem('e', 'edit')
        $this.AddStatusItem('v', 'view')
        $this.AddStatusItem('.', 'hidden')
        $this.AddStatusItem('q', 'quit')
        
        # Add path info
        $this.StatusBarItems.Add(@{
            Label = " Path: $($this.CurrentPath)"
            Align = "Right"
        }) | Out-Null
    }
    
    [string] RenderContent() {
        $output = ""
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Clear background
        for ($y = 1; $y -le $height; $y++) {
            $output += [VT]::MoveTo(1, $y)
            $output += " " * $width
        }
        
        # Title bar
        $titleBar = " RANGER-STYLE FILE BROWSER "
        $x = [int](($width - $titleBar.Length) / 2)
        $output += [VT]::MoveTo($x, 1)
        $output += [VT]::RGB(100, 200, 255) + $titleBar + [VT]::Reset()
        
        # Update panel focus indicators
        $this.UpdatePanelFocus()
        
        # Render panels (using simple rendering for now)
        $output += $this.RenderPanel($this.ParentPanel, $this.ParentList)
        $output += $this.RenderPanel($this.CurrentPanel, $this.CurrentList)
        $output += $this.RenderPanel($this.PreviewPanel, $this.PreviewList)
        
        return $output
    }
    
    [string] RenderPanel([Panel]$panel, [ListBox]$listbox) {
        $output = ""
        
        # Draw border
        $borderColor = if ($panel -eq $this.CurrentPanel -and $this.FocusedPanel -eq 1) {
            [VT]::RGB(100, 200, 255)
        } else {
            [VT]::RGB(100, 100, 150)
        }
        
        # Top border with title
        $output += [VT]::MoveTo($panel.X, $panel.Y)
        $output += $borderColor + "┌" + ("─" * ($panel.Width - 2)) + "┐" + [VT]::Reset()
        
        if ($panel.Title) {
            $titleText = " $($panel.Title) "
            $output += [VT]::MoveTo($panel.X + 2, $panel.Y)
            $output += $borderColor + $titleText + [VT]::Reset()
        }
        
        # Sides and content
        for ($y = 1; $y -lt $panel.Height - 1; $y++) {
            $output += [VT]::MoveTo($panel.X, $panel.Y + $y)
            $output += $borderColor + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($panel.X + $panel.Width - 1, $panel.Y + $y)
            $output += $borderColor + "│" + [VT]::Reset()
        }
        
        # Bottom border
        $output += [VT]::MoveTo($panel.X, $panel.Y + $panel.Height - 1)
        $output += $borderColor + "└" + ("─" * ($panel.Width - 2)) + "┘" + [VT]::Reset()
        
        # Render list items
        $output += $this.RenderListBox($listbox, $panel.X + 1, $panel.Y + 1, $panel.Width - 2, $panel.Height - 2)
        
        return $output
    }
    
    [string] RenderListBox([ListBox]$listbox, [int]$x, [int]$y, [int]$width, [int]$height) {
        $output = ""
        
        # Calculate visible range
        $listbox.EnsureVisible()
        $endIndex = [Math]::Min($listbox.ScrollOffset + $height, $listbox.Items.Count)
        
        for ($i = $listbox.ScrollOffset; $i -lt $endIndex; $i++) {
            $item = $listbox.Items[$i]
            $itemY = $y + ($i - $listbox.ScrollOffset)
            
            # Format item
            $text = $this.FormatFileItem($item)
            if ($text.Length -gt $width - 1) {
                $text = $text.Substring(0, $width - 4) + "..."
            }
            
            $output += [VT]::MoveTo($x, $itemY)
            
            # Highlight selected item
            if ($i -eq $listbox.SelectedIndex) {
                $output += [VT]::RGBBG(40, 40, 80) + [VT]::RGB(255, 255, 255)
                $output += " " + $text.PadRight($width - 1)
                $output += [VT]::Reset()
            } else {
                $output += " " + $text
            }
        }
        
        # Scrollbar if needed
        if ($listbox.Items.Count -gt $height) {
            $this.RenderScrollbar($output, $x + $width - 1, $y, $height, $listbox.ScrollOffset, $listbox.Items.Count)
        }
        
        return $output
    }
    
    [string] FormatFileItem([object]$item) {
        if ($item -is [System.IO.DirectoryInfo]) {
            return "📁 " + $item.Name + "/"
        } elseif ($item -is [System.IO.FileInfo]) {
            $icon = $this.GetFileIcon($item.Extension)
            $size = $this.FormatFileSize($item.Length)
            return "$icon $($item.Name) ($size)"
        } elseif ($item -eq "..") {
            return "📁 ../"
        } else {
            return $item.ToString()
        }
    }
    
    [string] GetFileIcon([string]$extension) {
        switch ($extension.ToLower()) {
            ".ps1" { return "🔷" }
            ".txt" { return "📄" }
            ".md" { return "📝" }
            ".json" { return "📋" }
            ".xml" { return "📋" }
            ".jpg" { return "🖼️" }
            ".png" { return "🖼️" }
            ".mp3" { return "🎵" }
            ".mp4" { return "🎬" }
            ".zip" { return "📦" }
            ".exe" { return "⚙️" }
            default { return "📄" }
        }
    }
    
    [string] FormatFileSize([long]$bytes) {
        if ($bytes -lt 1024) { return "$bytes B" }
        if ($bytes -lt 1048576) { return "$([Math]::Round($bytes / 1024, 1)) KB" }
        if ($bytes -lt 1073741824) { return "$([Math]::Round($bytes / 1048576, 1)) MB" }
        return "$([Math]::Round($bytes / 1073741824, 1)) GB"
    }
    
    [void] LoadDirectory([string]$path) {
        try {
            $this.CurrentPath = [System.IO.Path]::GetFullPath($path)
            $this.CurrentPanel.Title = [System.IO.Path]::GetFileName($this.CurrentPath)
            if (-not $this.CurrentPanel.Title) {
                $this.CurrentPanel.Title = $this.CurrentPath
            }
            
            # Load parent directory
            $parent = [System.IO.Directory]::GetParent($this.CurrentPath)
            if ($parent) {
                $this.LoadParentDirectory($parent.FullName)
            } else {
                $this.ParentList.Clear()
            }
            
            # Load current directory
            $items = @()
            
            # Add parent directory link if not at root
            if ($parent) {
                $items += ".."
            }
            
            # Get directories
            $dirs = Get-ChildItem -Path $this.CurrentPath -Directory -Force | Sort-Object Name
            $items += $dirs
            
            # Get files
            $files = Get-ChildItem -Path $this.CurrentPath -File -Force | Sort-Object Name
            $items += $files
            
            $this.CurrentList.SetItems($items)
            
            # Update preview
            $this.OnCurrentSelectionChanged()
            
            $this.RequestRender()
        }
        catch {
            Write-Error "Failed to load directory: $_"
        }
    }
    
    [void] LoadParentDirectory([string]$path) {
        try {
            $items = @()
            
            # Add grandparent if exists
            $grandparent = [System.IO.Directory]::GetParent($path)
            if ($grandparent) {
                $items += ".."
            }
            
            # Get directories
            $dirs = Get-ChildItem -Path $path -Directory -Force | Sort-Object Name
            $items += $dirs
            
            # Get files
            $files = Get-ChildItem -Path $path -File -Force | Sort-Object Name
            $items += $files
            
            $this.ParentList.SetItems($items)
            
            # Select current directory in parent list
            $currentDirName = [System.IO.Path]::GetFileName($this.CurrentPath)
            for ($i = 0; $i -lt $this.ParentList.Items.Count; $i++) {
                $item = $this.ParentList.Items[$i]
                if ($item -is [System.IO.DirectoryInfo] -and $item.Name -eq $currentDirName) {
                    $this.ParentList.SelectedIndex = $i
                    break
                }
            }
        }
        catch {
            $this.ParentList.Clear()
        }
    }
    
    [void] OnCurrentSelectionChanged() {
        $selected = $this.CurrentList.GetSelectedItem()
        if (-not $selected) {
            $this.PreviewList.Clear()
            return
        }
        
        if ($selected -is [System.IO.DirectoryInfo]) {
            # Preview directory contents
            try {
                $items = @()
                $dirs = Get-ChildItem -Path $selected.FullName -Directory -Force | Select-Object -First 20 | Sort-Object Name
                $files = Get-ChildItem -Path $selected.FullName -File -Force | Select-Object -First 20 | Sort-Object Name
                $items += $dirs
                $items += $files
                $this.PreviewList.SetItems($items)
            }
            catch {
                $this.PreviewList.SetItems(@("Access denied"))
            }
        }
        elseif ($selected -is [System.IO.FileInfo]) {
            # Preview file contents
            $this.PreviewFile($selected.FullName)
        }
    }
    
    [void] PreviewFile([string]$path) {
        try {
            $ext = [System.IO.Path]::GetExtension($path).ToLower()
            
            # Text files - show content
            if ($ext -in @(".txt", ".md", ".ps1", ".json", ".xml", ".yml", ".yaml", ".ini", ".cfg")) {
                $lines = Get-Content -Path $path -TotalCount 50 -ErrorAction Stop
                $this.PreviewList.SetItems($lines)
            }
            # Binary files - show info
            else {
                $file = Get-Item $path
                $info = @(
                    "File: $($file.Name)",
                    "Size: $($this.FormatFileSize($file.Length))",
                    "Created: $($file.CreationTime)",
                    "Modified: $($file.LastWriteTime)",
                    "Extension: $($file.Extension)"
                )
                $this.PreviewList.SetItems($info)
            }
        }
        catch {
            $this.PreviewList.SetItems(@("Cannot preview file"))
        }
    }
    
    [void] UpdatePanelFocus() {
        # Update border colors based on focus
        $this.ParentPanel.IsFocused = ($this.FocusedPanel -eq 0)
        $this.CurrentPanel.IsFocused = ($this.FocusedPanel -eq 1)
        $this.PreviewPanel.IsFocused = ($this.FocusedPanel -eq 2)
    }
    
    # Navigation methods
    [void] NavigateUp() {
        switch ($this.FocusedPanel) {
            0 { $this.ParentList.HandleInput([System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::UpArrow, $false, $false, $false)) }
            1 { $this.CurrentList.HandleInput([System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::UpArrow, $false, $false, $false)) }
            2 { $this.PreviewList.HandleInput([System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::UpArrow, $false, $false, $false)) }
        }
        $this.RequestRender()
    }
    
    [void] NavigateDown() {
        switch ($this.FocusedPanel) {
            0 { $this.ParentList.HandleInput([System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)) }
            1 { $this.CurrentList.HandleInput([System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)) }
            2 { $this.PreviewList.HandleInput([System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)) }
        }
        $this.RequestRender()
    }
    
    [void] NavigateLeft() {
        if ($this.FocusedPanel -gt 0) {
            $this.FocusedPanel--
        } else {
            # Go up one directory
            $parent = [System.IO.Directory]::GetParent($this.CurrentPath)
            if ($parent) {
                $this.LoadDirectory($parent.FullName)
            }
        }
        $this.RequestRender()
    }
    
    [void] NavigateRight() {
        if ($this.FocusedPanel -lt 2) {
            $this.FocusedPanel++
        } else {
            # Enter selected directory
            $this.OpenSelected()
        }
        $this.RequestRender()
    }
    
    [void] OpenSelected() {
        $selected = $this.CurrentList.GetSelectedItem()
        if ($selected -eq "..") {
            $parent = [System.IO.Directory]::GetParent($this.CurrentPath)
            if ($parent) {
                $this.LoadDirectory($parent.FullName)
            }
        }
        elseif ($selected -is [System.IO.DirectoryInfo]) {
            $this.LoadDirectory($selected.FullName)
        }
        elseif ($selected -is [System.IO.FileInfo]) {
            $this.EditSelected()
        }
    }
    
    [void] EditSelected() {
        $selected = $this.CurrentList.GetSelectedItem()
        if ($selected -is [System.IO.FileInfo]) {
            # Open text editor
            $editor = [TextEditorScreen]::new($selected.FullName)
            $global:ScreenManager.Push($editor)
        }
    }
    
    [void] ViewSelected() {
        # Similar to edit but read-only
        $this.EditSelected()
    }
    
    [void] GoToTop() {
        switch ($this.FocusedPanel) {
            0 { $this.ParentList.SelectedIndex = 0; $this.ParentList.ScrollOffset = 0 }
            1 { $this.CurrentList.SelectedIndex = 0; $this.CurrentList.ScrollOffset = 0 }
            2 { $this.PreviewList.SelectedIndex = 0; $this.PreviewList.ScrollOffset = 0 }
        }
        $this.RequestRender()
    }
    
    [void] GoToBottom() {
        switch ($this.FocusedPanel) {
            0 { $this.ParentList.SelectedIndex = $this.ParentList.Items.Count - 1 }
            1 { $this.CurrentList.SelectedIndex = $this.CurrentList.Items.Count - 1 }
            2 { $this.PreviewList.SelectedIndex = $this.PreviewList.Items.Count - 1 }
        }
        $this.RequestRender()
    }
    
    [void] StartSearch() {
        # TODO: Implement search functionality
        Write-Host "Search not yet implemented"
    }
    
    [void] ToggleHidden() {
        # TODO: Implement hidden file toggle
        Write-Host "Hidden file toggle not yet implemented"
    }
}