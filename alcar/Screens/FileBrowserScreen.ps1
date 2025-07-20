# FileBrowserScreen - Ranger-style three-column file browser

class FileBrowserScreen : Screen {
    # Panels
    hidden [FastPanel]$ParentPanel
    hidden [FastPanel]$CurrentPanel
    hidden [FastPanel]$PreviewPanel
    
    # File lists
    [System.Collections.ArrayList]$ParentFiles
    [System.Collections.ArrayList]$CurrentFiles  
    [System.Collections.ArrayList]$PreviewFiles
    [int]$SelectedIndex = 0
    
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
        # Initialize file lists
        $this.ParentFiles = [System.Collections.ArrayList]::new()
        $this.CurrentFiles = [System.Collections.ArrayList]::new()
        $this.PreviewFiles = [System.Collections.ArrayList]::new()
        
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
    
    # Fast string rendering - maximum performance like TaskScreen
    [string] RenderContent() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Clear screen efficiently
        $output += [VT]::Clear()
        
        # Title bar
        $titleBar = " RANGER-STYLE FILE BROWSER "
        $titleX = [int](($width - $titleBar.Length) / 2)
        $output += [VT]::MoveTo($titleX, 1)
        $output += [VT]::RGB(100, 200, 255) + $titleBar + [VT]::Reset()
        
        # Calculate panel dimensions
        $panelWidth = [int]($width / 3)
        $panelHeight = $height - 4
        
        # Check for selection changes
        $this.OnCurrentSelectionChanged()
        
        # Render all three panels directly
        $output += $this.RenderPanelSimple("Parent", 0, 2, $panelWidth, $panelHeight, ($this.FocusedPanel -eq 0), $this.ParentFiles)
        $output += $this.RenderPanelSimple("Current", $panelWidth, 2, $panelWidth, $panelHeight, ($this.FocusedPanel -eq 1), $this.CurrentFiles)
        $output += $this.RenderPanelSimple("Preview", $panelWidth * 2, 2, $width - ($panelWidth * 2), $panelHeight, ($this.FocusedPanel -eq 2), $this.PreviewFiles)
        
        return $output
    }
    
    [string] RenderPanelSimple([string]$title, [int]$x, [int]$y, [int]$width, [int]$height, [bool]$focused, [System.Collections.ArrayList]$files) {
        $output = ""
        
        # Draw border
        $borderColor = if ($focused) {
            [VT]::RGB(100, 200, 255)
        } else {
            [VT]::RGB(100, 100, 150)
        }
        
        # Top border with title
        $output += [VT]::MoveTo($x, $y)
        $output += $borderColor + "┌" + ("─" * ($width - 2)) + "┐" + [VT]::Reset()
        
        if ($title) {
            $titleText = " $title "
            $output += [VT]::MoveTo($x + 2, $y)
            $output += $borderColor + $titleText + [VT]::Reset()
        }
        
        # Sides and content
        for ($panelY = 1; $panelY -lt $height - 1; $panelY++) {
            $output += [VT]::MoveTo($x, $y + $panelY)
            $output += $borderColor + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($x + $width - 1, $y + $panelY)
            $output += $borderColor + "│" + [VT]::Reset()
        }
        
        # Bottom border
        $output += [VT]::MoveTo($x, $y + $height - 1)
        $output += $borderColor + "└" + ("─" * ($width - 2)) + "┘" + [VT]::Reset()
        
        # Render file items
        $output += $this.RenderFileList($files, $x + 1, $y + 1, $width - 2, $height - 2, $focused)
        
        return $output
    }
    
    [string] RenderFileList([System.Collections.ArrayList]$files, [int]$x, [int]$y, [int]$width, [int]$height, [bool]$isCurrent) {
        $output = ""
        
        # Show first few items that fit
        $visibleCount = [Math]::Min($files.Count, $height)
        
        for ($i = 0; $i -lt $visibleCount; $i++) {
            $item = $files[$i]
            $itemY = $y + $i
            
            # Format item
            $text = $this.FormatFileItem($item)
            if ($text.Length -gt $width - 2) {
                $text = $text.Substring(0, $width - 5) + "..."
            }
            
            $output += [VT]::MoveTo($x, $itemY)
            
            # Highlight selected item in current panel
            if ($isCurrent -and $i -eq $this.SelectedIndex) {
                $output += [VT]::RGBBG(40, 40, 80) + [VT]::RGB(255, 255, 255)
                $output += " " + $text.PadRight($width - 2) + " "
                $output += [VT]::Reset()
            } else {
                $output += " " + $text
            }
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
        return "📄"  # Fallback return
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
            # Update screen title based on current directory
            $dirName = [System.IO.Path]::GetFileName($this.CurrentPath)
            if (-not $dirName) {
                $dirName = $this.CurrentPath
            }
            
            # Load parent directory
            $parent = [System.IO.Directory]::GetParent($this.CurrentPath)
            if ($parent) {
                $this.LoadParentDirectory($parent.FullName)
            } else {
                $this.ParentList.SetFiles(@())
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
            
            $this.CurrentFiles.Clear()
            foreach ($item in $items) {
                $this.CurrentFiles.Add($item) | Out-Null
            }
            
            # Reset selection
            $this.SelectedIndex = 0
            
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
            
            $this.ParentFiles.Clear()
            foreach ($item in $items) {
                $this.ParentFiles.Add($item) | Out-Null
            }
            
            # Select current directory in parent list (simple implementation)
        }
        catch {
            $this.ParentFiles.Clear()
        }
    }
    
    [void] OnCurrentSelectionChanged() {
        if ($this.SelectedIndex -ge $this.CurrentFiles.Count) {
            $this.PreviewFiles.Clear()
            return
        }
        
        $selected = $this.CurrentFiles[$this.SelectedIndex]
        if (-not $selected) {
            $this.PreviewFiles.Clear()
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
                $this.PreviewFiles.Clear()
                foreach ($item in $items) {
                    $this.PreviewFiles.Add($item) | Out-Null
                }
            }
            catch {
                $this.PreviewFiles.Clear()
                $this.PreviewFiles.Add("Access denied") | Out-Null
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
                $this.PreviewFiles.Clear()
                foreach ($line in $lines) {
                    $this.PreviewFiles.Add($line) | Out-Null
                }
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
                $this.PreviewFiles.Clear()
                foreach ($line in $info) {
                    $this.PreviewFiles.Add($line) | Out-Null
                }
            }
        }
        catch {
            $this.PreviewFiles.Clear()
            $this.PreviewFiles.Add("Cannot preview file") | Out-Null
        }
    }
    
    [void] UpdatePanelFocus() {
        # Panel focus is now handled in rendering
    }
    
    # Navigation methods
    [void] NavigateUp() {
        if ($this.FocusedPanel -eq 1 -and $this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.OnCurrentSelectionChanged()
        }
        $this.RequestRender()
    }
    
    [void] NavigateDown() {
        if ($this.FocusedPanel -eq 1 -and $this.SelectedIndex -lt $this.CurrentFiles.Count - 1) {
            $this.SelectedIndex++
            $this.OnCurrentSelectionChanged()
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
        if ($this.SelectedIndex -ge $this.CurrentFiles.Count) { return }
        $selected = $this.CurrentFiles[$this.SelectedIndex]
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
        if ($this.SelectedIndex -ge $this.CurrentFiles.Count) { return }
        $selected = $this.CurrentFiles[$this.SelectedIndex]
        if ($selected -is [System.IO.FileInfo]) {
            # Open simple text editor
            $editor = [SimpleTextEditor]::new($selected.FullName)
            $global:ScreenManager.Push($editor)
        }
    }
    
    [void] ViewSelected() {
        # Similar to edit but read-only
        $this.EditSelected()
    }
    
    [void] GoToTop() {
        if ($this.FocusedPanel -eq 1) {
            $this.SelectedIndex = 0
            $this.OnCurrentSelectionChanged()
        }
        $this.RequestRender()
    }
    
    [void] GoToBottom() {
        if ($this.FocusedPanel -eq 1 -and $this.CurrentFiles.Count -gt 0) {
            $this.SelectedIndex = $this.CurrentFiles.Count - 1
            $this.OnCurrentSelectionChanged()
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