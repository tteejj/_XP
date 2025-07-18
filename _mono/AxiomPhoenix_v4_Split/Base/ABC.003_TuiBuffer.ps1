# ==============================================================================
# Axiom-Phoenix v4.0 - Performance-Optimized TuiBuffer Class
# Removes excessive debug logging and adds performance optimizations
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Management.Automation
using namespace System.Threading

# Disable verbose output during TUI rendering
$script:TuiVerbosePreference = 'SilentlyContinue'

#region TuiBuffer Class - 2D Array of TuiCells
class TuiBuffer {
    $Cells       # 2D array of TuiCells - no type constraint to avoid assignment issues
    [int] $Width             
    [int] $Height            
    [string] $Name            
    [bool] $IsDirty = $true  
    
    # Performance tracking
    hidden [System.Collections.Generic.HashSet[int]]$_dirtyRows = $null
    hidden [bool]$_trackDirtyRegions = $true
    
    # PERFORMANCE: Object pooling for temporary cell operations
    hidden [TuiCell[]] $_cellPool = $null
    hidden [int] $_poolIndex = 0
    hidden [TuiCell] $_defaultCell = $null
    hidden [TuiCell] $_templateCell = $null

    # Constructor with 2 parameters
    TuiBuffer([int]$width, [int]$height) {
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        $this.Width = $width
        $this.Height = $height
        $this.Name = "Unnamed"
        $this._dirtyRows = [System.Collections.Generic.HashSet[int]]::new()
        # Initialize cells in a simple way
        $this.InitializeCells()
        # Write-Verbose "TuiBuffer '$($this.Name)' initialized with dimensions: $($this.Width)x$($this.Height)."
    }

    # Constructor with 3 parameters
    TuiBuffer([int]$width, [int]$height, [string]$name) {
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        $this.Width = $width
        $this.Height = $height
        $this.Name = $name
        $this._dirtyRows = [System.Collections.Generic.HashSet[int]]::new()
        # Initialize cells in a simple way
        $this.InitializeCells()
        # Write-Verbose "TuiBuffer '$($this.Name)' initialized with dimensions: $($this.Width)x$($this.Height)."
    }

    hidden [void] InitializeCells() {
        # PERFORMANCE: Pre-allocate ALL cells during initialization
        $tempArray = New-Object 'System.Object[,]' $this.Height,$this.Width
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $tempArray[$y,$x] = [TuiCell]::new()
            }
        }
        $this.Cells = $tempArray
        
        # PERFORMANCE: Initialize object pool for temporary operations
        $this._cellPool = @()
        for ($i = 0; $i -lt 50; $i++) {  # Pool of 50 temporary cells
            $this._cellPool += [TuiCell]::new()
        }
        
        # PERFORMANCE: Create reusable template cells
        $this._defaultCell = [TuiCell]::new()
        $this._templateCell = [TuiCell]::new()
    }

    # PERFORMANCE: Get pooled cell for temporary operations
    hidden [TuiCell] GetPooledCell() {
        if ($this._poolIndex -ge $this._cellPool.Length) { 
            $this._poolIndex = 0 
        }
        $cell = $this._cellPool[$this._poolIndex++]
        $cell.Reset()  # Reset to defaults
        return $cell
    }

    [void] Clear() { $this.Clear($this._defaultCell) }

    [void] Clear([TuiCell]$fillCell) {
        # PERFORMANCE: Update existing cells instead of creating new ones
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.Cells[$y, $x].CopyFrom($fillCell)
            }
        }
        $this.IsDirty = $true
        $this._dirtyRows.Clear()
        for ($y = 0; $y -lt $this.Height; $y++) {
            $this._dirtyRows.Add($y) | Out-Null
        }
        # Write-Verbose "TuiBuffer '$($this.Name)' cleared with specified cell."
    }

    [TuiCell] GetCell([int]$x, [int]$y) {
        if ($x -lt 0 -or $x -ge $this.Width -or $y -lt 0 -or $y -ge $this.Height) { return [TuiCell]::new() }
        return $this.Cells[$y, $x]
    }

    [void] SetCell([int]$x, [int]$y, [TuiCell]$cell) {
        if ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height) {
            $this.Cells[$y, $x] = $cell
            $this.IsDirty = $true
            # Track which rows are dirty for optimized rendering
            if ($this._trackDirtyRegions) {
                $this._dirtyRows.Add($y) | Out-Null
            }
        } else {
            Write-Log -Level Warning -Message "Attempted to set cell out of bounds in TuiBuffer '$($this.Name)': ($x, $y) is outside 0..$($this.Width-1), 0..$($this.Height-1). Cell: '$($cell.Char)'."
        }
    }

    # PERFORMANCE OPTIMIZATION: Batch string writing to reduce logging overhead
    [void] WriteString([int]$x, [int]$y, [string]$text, [hashtable]$style = @{}) {
        # PERFORMANCE: Fast bounds check and early exit
        if ([string]::IsNullOrEmpty($text) -or $y -lt 0 -or $y -ge $this.Height) {
            return
        }
        
        # PERFORMANCE: Use template cell and update it once
        $template = $this._templateCell
        $template.Reset()
        
        # PERFORMANCE: Batch extract style properties with minimal checks
        if ($style.ContainsKey('FG')) { $template.ForegroundColor = $style['FG'] }
        if ($style.ContainsKey('BG')) { $template.BackgroundColor = $style['BG'] }
        if ($style.ContainsKey('Bold')) { $template.Bold = [bool]$style['Bold'] }
        if ($style.ContainsKey('Italic')) { $template.Italic = [bool]$style['Italic'] }
        if ($style.ContainsKey('Underline')) { $template.Underline = [bool]$style['Underline'] }
        if ($style.ContainsKey('Strikethrough')) { $template.Strikethrough = [bool]$style['Strikethrough'] }
        if ($style.ContainsKey('ZIndex')) { $template.ZIndex = [int]$style['ZIndex'] }
        
        # PERFORMANCE: Direct character array processing with in-place updates
        $chars = $text.ToCharArray()
        $currentX = $x
        
        foreach ($char in $chars) {
            if ($currentX -ge $this.Width) { break } 
            if ($currentX -ge 0) {
                # PERFORMANCE: Update existing cell in buffer directly
                $existingCell = $this.Cells[$y, $currentX]
                $existingCell.CopyFrom($template)
                $existingCell.Char = $char
            }
            $currentX++
        }
        
        # PERFORMANCE: Minimal dirty tracking
        $this.IsDirty = $true
        if ($this._trackDirtyRegions) {
            [void]$this._dirtyRows.Add($y)
        }
    }

    # PERFORMANCE OPTIMIZATION: Smart blending that skips empty cells
    [void] BlendBuffer([object]$other, [int]$offsetX, [int]$offsetY) {
        # Early exit if source buffer is empty or completely out of bounds
        if ($null -eq $other -or 
            $offsetX -ge $this.Width -or $offsetY -ge $this.Height -or
            $offsetX + $other.Width -le 0 -or $offsetY + $other.Height -le 0) {
            return
        }
        
        # Calculate clipped bounds to avoid unnecessary iterations
        $startX = [Math]::Max(0, -$offsetX)
        $endX = [Math]::Min($other.Width, $this.Width - $offsetX)
        $startY = [Math]::Max(0, -$offsetY)
        $endY = [Math]::Min($other.Height, $this.Height - $offsetY)
        
        for ($y = $startY; $y -lt $endY; $y++) {
            for ($x = $startX; $x -lt $endX; $x++) {
                $targetX = $offsetX + $x
                $targetY = $offsetY + $y
                
                $sourceCell = $other.GetCell($x, $y)
                # Skip blending empty/default cells for performance
                if ($sourceCell.Char -eq ' ' -and $sourceCell.Background -eq "#000000") {
                    continue
                }
                
                $targetCell = $this.GetCell($targetX, $targetY)
                # PERFORMANCE: Use mutable blending to avoid cell creation
                $targetCell.BlendWithMutable($sourceCell)
                
                # PERFORMANCE: Track blend operations
                if ($global:TuiMemoryMetrics -and $global:TuiDebugMode) {
                    $global:TuiMemoryMetrics.BlendOperations++
                }
            }
        }
        $this.IsDirty = $true
        # Write-Verbose "BlendBuffer: Blended buffer '$($other.Name)' onto '$($this.Name)' at ($offsetX, $offsetY)."
    }

    # Get only dirty rows for optimized rendering
    [int[]] GetDirtyRows() {
        if ($this._trackDirtyRegions) {
            return @($this._dirtyRows)
        }
        # If not tracking, assume all rows are dirty
        $allRows = @()
        for ($i = 0; $i -lt $this.Height; $i++) {
            $allRows += $i
        }
        return $allRows
    }
    
    [void] ClearDirtyTracking() {
        $this._dirtyRows.Clear()
        $this.IsDirty = $false
    }

    [TuiBuffer] GetSubBuffer([int]$x, [int]$y, [int]$width, [int]$height) {
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        $subBuffer = [TuiBuffer]::new($width, $height, "$($this.Name).Sub")
        for ($sy = 0; $sy -lt $height; $sy++) {
            for ($sx = 0; $sx -lt $width; $sx++) {
                $sourceCell = $this.GetCell($x + $sx, $y + $sy)
                $subBuffer.SetCell($sx, $sy, [TuiCell]::new($sourceCell))
            }
        }
        # Write-Verbose "GetSubBuffer: Created sub-buffer '$($subBuffer.Name)' from '$($this.Name)' at ($x, $y) with dimensions $($width)x$($height)."
        return $subBuffer
    }

    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0) { throw [System.ArgumentOutOfRangeException]::new("newWidth", "Width must be positive.") }
        if ($newHeight -le 0) { throw [System.ArgumentOutOfRangeException]::new("newHeight", "Height must be positive.") }
        
        # Don't resize if dimensions haven't changed
        if ($this.Width -eq $newWidth -and $this.Height -eq $newHeight) {
            return
        }
        
        # Save old buffer content
        $oldCells = $this.Cells
        $oldWidth = $this.Width
        $oldHeight = $this.Height
        
        # Update dimensions and reinitialize
        $this.Width = $newWidth
        $this.Height = $newHeight
        $this.InitializeCells()
        
        # Copy over existing content (clipped to new dimensions)
        $copyWidth = [Math]::Min($oldWidth, $newWidth)
        $copyHeight = [Math]::Min($oldHeight, $newHeight)
        
        for ($y = 0; $y -lt $copyHeight; $y++) {
            for ($x = 0; $x -lt $copyWidth; $x++) {
                $this.Cells[$y, $x] = $oldCells[$y, $x]
            }
        }
        
        $this.IsDirty = $true
        $this._dirtyRows.Clear()
        for ($y = 0; $y -lt $this.Height; $y++) {
            $this._dirtyRows.Add($y) | Out-Null
        }
        
        Write-Verbose "TuiBuffer '$($this.Name)' resized from $($oldWidth)x$($oldHeight) to $($newWidth)x$($newHeight)."
    }
    
    # PERFORMANCE FIX: Add missing FillRect method
    [void] FillRect([int]$x, [int]$y, [int]$width, [int]$height, [char]$fillChar, [hashtable]$style) {
        if ($width -le 0 -or $height -le 0) { return }
        
        # Extract style properties
        $fg = "#FFFFFF"
        if ($style.ContainsKey('FG')) { $fg = $style['FG'] }
        
        $bg = "#000000"
        if ($style.ContainsKey('BG')) { $bg = $style['BG'] }
        
        $bold = $false
        if ($style.ContainsKey('Bold')) { $bold = [bool]$style['Bold'] }
        
        $italic = $false
        if ($style.ContainsKey('Italic')) { $italic = [bool]$style['Italic'] }
        
        $underline = $false
        if ($style.ContainsKey('Underline')) { $underline = [bool]$style['Underline'] }
        
        $strikethrough = $false
        if ($style.ContainsKey('Strikethrough')) { $strikethrough = [bool]$style['Strikethrough'] }
        
        # Fill the rectangle
        for ($fy = $y; $fy -lt ($y + $height); $fy++) {
            for ($fx = $x; $fx -lt ($x + $width); $fx++) {
                if ($fx -ge 0 -and $fx -lt $this.Width -and $fy -ge 0 -and $fy -lt $this.Height) {
                    $cell = [TuiCell]::new($fillChar, $fg, $bg, $bold, $italic, $underline, $strikethrough)
                    $this.SetCell($fx, $fy, $cell)
                }
            }
        }
    }

    [string] ToString() {
        return "TuiBuffer(Name='$($this.Name)', Size=$($this.Width)x$($this.Height), Dirty=$($this.IsDirty))"
    }
    
    # PERFORMANCE FIX: Add Clone method for efficient buffer copying
    [TuiBuffer] Clone() {
        $clone = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Clone")
        
        # Copy all cells
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $sourceCell = $this.GetCell($x, $y)
                $clone.SetCell($x, $y, [TuiCell]::new($sourceCell))
            }
        }
        
        # Copy state
        $clone.IsDirty = $this.IsDirty
        if ($this._trackDirtyRegions) {
            foreach ($row in $this._dirtyRows) {
                $clone._dirtyRows.Add($row) | Out-Null
            }
        }
        
        return $clone
    }
}
#endregion