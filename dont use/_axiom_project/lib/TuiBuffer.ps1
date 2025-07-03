class TuiBuffer {
    [TuiCell[,]] $Cells
    [int] $Width
    [int] $Height
    [string] $Name
    [bool] $IsDirty = $true

    # Constructor
    TuiBuffer([int]$width, [int]$height, [string]$name = "Unnamed") {
        if ($width -le 0 -or $height -le 0) {
            throw [ArgumentException]::new("Buffer dimensions must be positive")
        }
        
        $this.Width = $width
        $this.Height = $height
        $this.Name = $name
        $this.Cells = New-Object 'TuiCell[,]' $height, $width
        $this.Clear()
    }

    # Clear buffer with default cell
    [void] Clear() {
        $this.Clear([TuiCell]::new())
    }

    # Clear buffer with specific cell
    [void] Clear([TuiCell]$fillCell) {
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.Cells[$y, $x] = [TuiCell]::new($fillCell)
            }
        }
        $this.IsDirty = $true
    }

    # Get cell at position (safe)
    [TuiCell] GetCell([int]$x, [int]$y) {
        if ($x -lt 0 -or $x -ge $this.Width -or $y -lt 0 -or $y -ge $this.Height) {
            return [TuiCell]::new()  # Return empty cell for out-of-bounds
        }
        return $this.Cells[$y, $x]
    }

    # Set cell at position (safe)
    [void] SetCell([int]$x, [int]$y, [TuiCell]$cell) {
        if ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height -and $null -ne $cell) {
            $this.Cells[$y, $x] = $cell
            $this.IsDirty = $true
        }
    }

    # Write string to buffer
    [void] WriteString([int]$x, [int]$y, [string]$text, [ConsoleColor]$fg, [ConsoleColor]$bg) {
        if ([string]::IsNullOrEmpty($text) -or $y -lt 0 -or $y -ge $this.Height) {
            return
        }

        $currentX = $x
        foreach ($char in $text.ToCharArray()) {
            if ($currentX -ge $this.Width) { break }
            if ($currentX -ge 0) {
                $this.SetCell($currentX, $y, [TuiCell]::new($char, $fg, $bg))
            }
            $currentX++
        }
    }

    # Blend another buffer onto this one at specified position
    [void] BlendBuffer([TuiBuffer]$other, [int]$offsetX, [int]$offsetY) {
        if ($null -eq $other) { return }

        for ($y = 0; $y -lt $other.Height; $y++) {
            for ($x = 0; $x -lt $other.Width; $x++) {
                $targetX = $offsetX + $x
                $targetY = $offsetY + $y
                
                if ($targetX -ge 0 -and $targetX -lt $this.Width -and $targetY -ge 0 -and $targetY -lt $this.Height) {
                    $sourceCell = $other.GetCell($x, $y)
                    $targetCell = $this.GetCell($targetX, $targetY)
                    $blendedCell = $targetCell.BlendWith($sourceCell)
                    $this.SetCell($targetX, $targetY, $blendedCell)
                }
            }
        }
    }

    # Create a sub-buffer view (read-only)
    [TuiBuffer] GetSubBuffer([int]$x, [int]$y, [int]$width, [int]$height) {
        $subBuffer = [TuiBuffer]::new($width, $height, "$($this.Name).Sub")
        
        for ($sy = 0; $sy -lt $height; $sy++) {
            for ($sx = 0; $sx -lt $width; $sx++) {
                $sourceCell = $this.GetCell($x + $sx, $y + $sy)
                $subBuffer.SetCell($sx, $sy, [TuiCell]::new($sourceCell))
            }
        }
        
        return $subBuffer
    }

    # Resize buffer (content is preserved where possible)
    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0 -or $newHeight -le 0) {
            throw [ArgumentException]::new("Buffer dimensions must be positive")
        }

        $oldCells = $this.Cells
        $oldWidth = $this.Width
        $oldHeight = $this.Height

        $this.Width = $newWidth
        $this.Height = $newHeight
        $this.Cells = New-Object 'TuiCell[,]' $newHeight, $newWidth
        $this.Clear()

        # Copy existing content
        $copyWidth = [Math]::Min($oldWidth, $newWidth)
        $copyHeight = [Math]::Min($oldHeight, $newHeight)

        for ($y = 0; $y -lt $copyHeight; $y++) {
            for ($x = 0; $x -lt $copyWidth; $x++) {
                $this.Cells[$y, $x] = $oldCells[$y, $x]
            }
        }

        $this.IsDirty = $true
    }
}
