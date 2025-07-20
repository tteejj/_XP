# LazyGitRenderer - Enhanced StringBuilder-based double buffering system
# Optimized for high-performance LazyGit-style multi-panel rendering

using namespace System.Text

class LazyGitRenderer {
    # Double buffering with StringBuilder (not cell-based)
    hidden [StringBuilder]$_primaryBuffer
    hidden [StringBuilder]$_secondaryBuffer
    hidden [bool]$_useSecondary = $false
    
    # Performance settings
    [int]$InitialBufferCapacity = 8192
    [int]$MaxBufferCapacity = 65536
    [bool]$EnableVTOptimization = $true
    
    # VT sequence caching for performance
    hidden [hashtable]$_vt_cache = @{}
    hidden [string]$_lastPosition = ""
    
    # Rendering statistics (for debugging/optimization)
    [int]$FrameCount = 0
    [long]$TotalRenderTime = 0
    [int]$LastFrameSize = 0
    
    LazyGitRenderer() {
        $this.Initialize()
    }
    
    LazyGitRenderer([int]$initialCapacity) {
        $this.InitialBufferCapacity = $initialCapacity
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Create double buffers with initial capacity
        $this._primaryBuffer = [StringBuilder]::new($this.InitialBufferCapacity)
        $this._secondaryBuffer = [StringBuilder]::new($this.InitialBufferCapacity)
        
        # Pre-populate VT sequence cache
        $this.InitializeVTCache()
    }
    
    # Pre-compute common VT100 sequences for performance
    [void] InitializeVTCache() {
        # Common cursor movements (relative)
        $this._vt_cache["up"] = "`e[A"
        $this._vt_cache["down"] = "`e[B" 
        $this._vt_cache["right"] = "`e[C"
        $this._vt_cache["left"] = "`e[D"
        
        # Screen management
        $this._vt_cache["clear"] = "`e[2J`e[H"
        $this._vt_cache["clearline"] = "`e[2K"
        $this._vt_cache["home"] = "`e[H"
        $this._vt_cache["hide_cursor"] = "`e[?25l"
        $this._vt_cache["show_cursor"] = "`e[?25h"
        
        # Common colors (LazyGit palette)
        $this._vt_cache["reset"] = "`e[0m"
        $this._vt_cache["bold"] = "`e[1m"
        $this._vt_cache["dim"] = "`e[2m"
        
        # LazyGit-style colors
        $this._vt_cache["fg_normal"] = "`e[38;2;220;220;220m"
        $this._vt_cache["fg_dim"] = "`e[38;2;150;150;150m"
        $this._vt_cache["fg_bright"] = "`e[38;2;255;255;255m"
        $this._vt_cache["bg_selected"] = "`e[48;2;60;80;120m"
        $this._vt_cache["bg_active_panel"] = "`e[48;2;40;60;80m"
        $this._vt_cache["border_color"] = "`e[38;2;100;100;100m"
        $this._vt_cache["title_color"] = "`e[38;2;180;180;180m"
        $this._vt_cache["command_color"] = "`e[38;2;120;200;120m"
    }
    
    # Begin a new frame
    [StringBuilder] BeginFrame() {
        $startTime = Get-Date
        
        # Get current buffer
        $buffer = $this.GetCurrentBuffer()
        
        # Clear and prepare buffer
        $buffer.Clear()
        $buffer.EnsureCapacity($this.InitialBufferCapacity)
        
        # Start with common frame setup
        if ($this.EnableVTOptimization) {
            # Hide cursor during rendering to prevent flicker
            [void]$buffer.Append($this._vt_cache["hide_cursor"])
            
            # Clear screen and home cursor for frame start
            [void]$buffer.Append($this._vt_cache["clear"])
        }
        
        return $buffer
    }
    
    # Complete frame rendering and display
    [void] EndFrame() {
        $buffer = $this.GetCurrentBuffer()
        
        # Add cursor restoration if enabled
        if ($this.EnableVTOptimization) {
            [void]$buffer.Append($this._vt_cache["show_cursor"])
        }
        
        # Single atomic write to console (key to reducing flicker)
        [Console]::Write($buffer.ToString())
        
        # Swap buffers for next frame
        $this._useSecondary = -not $this._useSecondary
        
        # Update statistics
        $this.FrameCount++
        $this.LastFrameSize = $buffer.Length
    }
    
    # Get the current active buffer
    [StringBuilder] GetCurrentBuffer() {
        if ($this._useSecondary) {
            return $this._secondaryBuffer
        } else {
            return $this._primaryBuffer
        }
    }
    
    # Optimized cursor positioning with caching
    [string] MoveTo([int]$x, [int]$y) {
        $position = "`e[$y;${x}H"
        
        # Cache last position to avoid redundant moves
        if ($this._lastPosition -eq $position) {
            return ""
        }
        
        $this._lastPosition = $position
        return $position
    }
    
    # Optimized relative movement (when possible)
    [string] MoveRelative([int]$deltaX, [int]$deltaY) {
        $movement = ""
        
        # Vertical movement
        if ($deltaY -gt 0) {
            if ($deltaY -eq 1) { 
                $movement += $this._vt_cache["down"] 
            } else { 
                $movement += "`e[${deltaY}B" 
            }
        } elseif ($deltaY -lt 0) {
            $absY = [Math]::Abs($deltaY)
            if ($absY -eq 1) { 
                $movement += $this._vt_cache["up"] 
            } else { 
                $movement += "`e[${absY}A" 
            }
        }
        
        # Horizontal movement  
        if ($deltaX -gt 0) {
            if ($deltaX -eq 1) { 
                $movement += $this._vt_cache["right"] 
            } else { 
                $movement += "`e[${deltaX}C" 
            }
        } elseif ($deltaX -lt 0) {
            $absX = [Math]::Abs($deltaX)
            if ($absX -eq 1) { 
                $movement += $this._vt_cache["left"] 
            } else { 
                $movement += "`e[${absX}D" 
            }
        }
        
        return $movement
    }
    
    # Get cached VT sequence
    [string] GetVT([string]$name) {
        if ($this._vt_cache.ContainsKey($name)) {
            return $this._vt_cache[$name]
        }
        return ""
    }
    
    # Add custom VT sequence to cache
    [void] CacheVT([string]$name, [string]$sequence) {
        $this._vt_cache[$name] = $sequence
    }
    
    # Render multiple panels efficiently
    [void] RenderPanels([object[]]$panels) {
        $buffer = $this.GetCurrentBuffer()
        
        foreach ($panel in $panels) {
            if ($panel.IsDirty -or ($panel.CurrentView -ne $null -and $panel.CurrentView.IsDirty)) {
                [void]$buffer.Append($panel.Render())
            }
        }
    }
    
    # Render command palette at bottom
    [void] RenderCommandPalette([object]$palette, [int]$screenHeight) {
        if ($palette -eq $null) { return }
        
        $buffer = $this.GetCurrentBuffer()
        $paletteY = $screenHeight - 2
        
        [void]$buffer.Append($this.MoveTo(1, $paletteY))
        [void]$buffer.Append($palette.Render())
    }
    
    # Clear screen efficiently
    [void] ClearScreen() {
        $buffer = $this.GetCurrentBuffer()
        [void]$buffer.Append($this._vt_cache["clear"])
    }
    
    # Clear specific area
    [void] ClearArea([int]$x, [int]$y, [int]$width, [int]$height) {
        $buffer = $this.GetCurrentBuffer()
        
        for ($row = $y; $row -lt ($y + $height); $row++) {
            [void]$buffer.Append($this.MoveTo($x, $row))
            [void]$buffer.Append(" " * $width)
        }
    }
    
    # Performance optimization: batch text rendering with positioning
    [void] RenderTextAt([int]$x, [int]$y, [string]$text, [string]$color = "") {
        $buffer = $this.GetCurrentBuffer()
        
        [void]$buffer.Append($this.MoveTo($x, $y))
        if (-not [string]::IsNullOrEmpty($color)) {
            [void]$buffer.Append($color)
        }
        [void]$buffer.Append($text)
        if (-not [string]::IsNullOrEmpty($color)) {
            [void]$buffer.Append($this._vt_cache["reset"])
        }
    }
    
    # Render multiple lines with consistent positioning
    [void] RenderTextBlock([int]$x, [int]$y, [string[]]$lines, [string]$color = "") {
        $buffer = $this.GetCurrentBuffer()
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            [void]$buffer.Append($this.MoveTo($x, $y + $i))
            if (-not [string]::IsNullOrEmpty($color)) {
                [void]$buffer.Append($color)
            }
            [void]$buffer.Append($lines[$i])
            if (-not [string]::IsNullOrEmpty($color)) {
                [void]$buffer.Append($this._vt_cache["reset"])
            }
        }
    }
    
    # Get rendering performance stats
    [hashtable] GetStats() {
        return @{
            FrameCount = $this.FrameCount
            TotalRenderTime = $this.TotalRenderTime
            LastFrameSize = $this.LastFrameSize
            BufferCapacity = $this.GetCurrentBuffer().Capacity
            CacheSize = $this._vt_cache.Count
        }
    }
    
    # Reset performance counters
    [void] ResetStats() {
        $this.FrameCount = 0
        $this.TotalRenderTime = 0
        $this.LastFrameSize = 0
    }
    
    # Clear the buffer completely
    [void] ClearBuffer() {
        $this._primaryBuffer.Clear()
        $this._secondaryBuffer.Clear()
        # Force a clear screen output
        Write-Host -NoNewline $this._vt_cache["clear"]
    }
    
    # Cleanup resources
    [void] Dispose() {
        $this._primaryBuffer.Clear()
        $this._secondaryBuffer.Clear()
        $this._vt_cache.Clear()
    }
}