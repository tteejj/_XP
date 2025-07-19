# FastFileListBox - Ultra-fast file browser list component
# Optimized for handling thousands of files with zero overhead

class FastFileListBox : FastComponentBase {
    # Core state
    [array]$Items = @()           # Pre-formatted display strings
    [array]$FileObjects = @()     # Actual FileInfo/DirectoryInfo objects
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$HasBorder = $true
    [bool]$IsFocused = $false
    
    # File browser specific
    [int]$LastSelectedIndex = -1  # For change detection
    [bool]$ShowIcons = $true
    [bool]$ShowSize = $true
    [bool]$ShowDate = $false
    
    # Pre-computed values
    hidden [int]$_visibleItems
    hidden [string]$_borderTop
    hidden [string]$_borderBottom
    hidden [hashtable]$_iconCache = @{
        ".ps1" = "🔷"
        ".txt" = "📄"
        ".md" = "📝"
        ".json" = "📋"
        ".xml" = "📋"
        ".jpg" = "🖼️"
        ".png" = "🖼️"
        ".mp3" = "🎵"
        ".mp4" = "🎬"
        ".zip" = "📦"
        ".exe" = "⚙️"
        "_default" = "📄"
        "_folder" = "📁"
    }
    
    FastFileListBox([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        $this.PrecomputeBorders()
        if ($this.HasBorder) {
            $this._visibleItems = $height - 2
        } else {
            $this._visibleItems = $height
        }
    }
    
    [void] PrecomputeBorders() {
        $this._borderTop = "┌" + ("─" * ($this.Width - 2)) + "┐"
        $this._borderBottom = "└" + ("─" * ($this.Width - 2)) + "┘"
    }
    
    # Set files with pre-formatting
    [void] SetFiles([array]$fileObjects) {
        $this.FileObjects = $fileObjects
        $this.Items = @()
        
        foreach ($obj in $fileObjects) {
            $this.Items += $this.FormatFileItem($obj)
        }
        
        $this.SelectedIndex = if ($fileObjects.Count -gt 0) { 0 } else { -1 }
        $this.ScrollOffset = 0
        $this.LastSelectedIndex = -1
    }
    
    # Format file item once
    [string] FormatFileItem([object]$item) {
        if ($null -eq $item) { return "" }
        
        $icon = ""
        $name = ""
        $size = ""
        
        if ($item -is [System.IO.DirectoryInfo]) {
            $icon = $this._iconCache["_folder"]
            $name = $item.Name
            if ($name -eq "..") {
                $icon = "⬆️"
            }
        }
        elseif ($item -is [System.IO.FileInfo]) {
            $ext = $item.Extension.ToLower()
            $icon = if ($this._iconCache.ContainsKey($ext)) { 
                $this._iconCache[$ext] 
            } else { 
                $this._iconCache["_default"] 
            }
            $name = $item.Name
            
            if ($this.ShowSize) {
                $size = $this.FormatFileSize($item.Length)
            }
        }
        else {
            return $item.ToString()
        }
        
        # Build formatted string
        $result = ""
        if ($this.ShowIcons) {
            $result = "$icon "
        }
        
        # Truncate name if needed
        $maxNameLen = $this.Width - 4
        if ($this.ShowIcons) { $maxNameLen -= 2 }
        if ($this.ShowSize) { $maxNameLen -= 10 }
        
        if ($name.Length -gt $maxNameLen) {
            $name = $name.Substring(0, $maxNameLen - 3) + "..."
        }
        
        $result += $name
        
        if ($this.ShowSize -and $size) {
            $padding = $this.Width - $result.Length - $size.Length - 4
            if ($padding -gt 0) {
                $result += " " * $padding + $size
            }
        }
        
        return $result
    }
    
    [string] FormatFileSize([long]$bytes) {
        if ($bytes -lt 1024) { return "$bytes B" }
        if ($bytes -lt 1048576) { return "$([Math]::Round($bytes / 1024, 1)) KB" }
        if ($bytes -lt 1073741824) { return "$([Math]::Round($bytes / 1048576, 1)) MB" }
        return "$([Math]::Round($bytes / 1073741824, 1)) GB"
    }
    
    # Get selected file object
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.FileObjects.Count) {
            return $this.FileObjects[$this.SelectedIndex]
        }
        return $null
    }
    
    # Check if selection changed
    [bool] HasSelectionChanged() {
        if ($this.SelectedIndex -ne $this.LastSelectedIndex) {
            $this.LastSelectedIndex = $this.SelectedIndex
            return $true
        }
        return $false
    }
    
    # Direct render
    [string] Render() {
        if (-not $this.Visible -or $this.Items.Count -eq 0) { return "" }
        
        $out = [System.Text.StringBuilder]::new(4096)
        
        # Border color
        $borderColor = if ($this.IsFocused) { 
            [FastComponentBase]::VTCache.Colors['Focus'] 
        } else { 
            "`e[38;2;80;80;100m" 
        }
        
        # Draw top border
        if ($this.HasBorder) {
            [void]$out.Append($this.MT($this.X, $this.Y))
            [void]$out.Append($borderColor)
            [void]$out.Append($this._borderTop)
            [void]$out.Append([FastComponentBase]::VTCache.Reset)
        }
        
        # Ensure selected item is visible
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $this._visibleItems) {
            $this.ScrollOffset = $this.SelectedIndex - $this._visibleItems + 1
        }
        
        # Draw items
        if ($this.HasBorder) {
            $contentX = $this.X + 1
            $contentY = $this.Y + 1
            $contentWidth = $this.Width - 2
        } else {
            $contentX = $this.X
            $contentY = $this.Y
            $contentWidth = $this.Width
        }
        
        $endIndex = [Math]::Min($this.ScrollOffset + $this._visibleItems, $this.Items.Count)
        
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $y = $contentY + ($i - $this.ScrollOffset)
            
            # Draw item background
            [void]$out.Append($this.MT($this.X, $y))
            
            if ($this.HasBorder) {
                [void]$out.Append($borderColor)
                [void]$out.Append("│")
                [void]$out.Append([FastComponentBase]::VTCache.Reset)
            }
            
            [void]$out.Append($this.MT($contentX, $y))
            
            if ($i -eq $this.SelectedIndex) {
                [void]$out.Append([FastComponentBase]::VTCache.Colors['Selected'])
            } else {
                [void]$out.Append([FastComponentBase]::VTCache.Colors['Normal'])
            }
            
            # Pad and truncate item
            $item = $this.Items[$i]
            if ($item.Length -gt $contentWidth) {
                $item = $item.Substring(0, $contentWidth)
            } else {
                $item = $item.PadRight($contentWidth)
            }
            
            [void]$out.Append($item)
            [void]$out.Append([FastComponentBase]::VTCache.Reset)
            
            if ($this.HasBorder) {
                [void]$out.Append($this.MT($this.X + $this.Width - 1, $y))
                [void]$out.Append($borderColor)
                [void]$out.Append("│")
                [void]$out.Append([FastComponentBase]::VTCache.Reset)
            }
        }
        
        # Fill empty space
        for ($i = $endIndex - $this.ScrollOffset; $i -lt $this._visibleItems; $i++) {
            $y = $contentY + $i
            [void]$out.Append($this.MT($this.X, $y))
            
            if ($this.HasBorder) {
                [void]$out.Append($borderColor)
                [void]$out.Append("│")
                [void]$out.Append(" " * ($this.Width - 2))
                [void]$out.Append("│")
            } else {
                [void]$out.Append(" " * $this.Width)
            }
            
            [void]$out.Append([FastComponentBase]::VTCache.Reset)
        }
        
        # Draw bottom border
        if ($this.HasBorder) {
            [void]$out.Append($this.MT($this.X, $this.Y + $this.Height - 1))
            [void]$out.Append($borderColor)
            [void]$out.Append($this._borderBottom)
            [void]$out.Append([FastComponentBase]::VTCache.Reset)
        }
        
        return $out.ToString()
    }
    
    # Handle input
    [bool] Input([ConsoleKey]$key) {
        if ($this.Items.Count -eq 0) { return $false }
        
        switch ($key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    return $true
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectedIndex++
                    return $true
                }
            }
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this.ScrollOffset = 0
                return $true
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
                return $true
            }
            ([ConsoleKey]::PageUp) {
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $this._visibleItems)
                return $true
            }
            ([ConsoleKey]::PageDown) {
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $this._visibleItems)
                return $true
            }
        }
        
        return $false
    }
}