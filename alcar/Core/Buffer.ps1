# Buffer class for double buffering
class Buffer {
    [object[,]]$Cells  # Array of Cell objects
    [int]$Width
    [int]$Height
    
    Buffer([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        $this.InitializeCells()
    }
    
    hidden [void] InitializeCells() {
        # Create a 2D array of objects first, then populate with Cell instances
        $this.Cells = New-Object 'object[,]' $this.Height,$this.Width
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.Cells[$y,$x] = [Cell]::new()
            }
        }
    }
    
    [void] Clear() {
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.Cells[$y,$x].Char = ' '
                $this.Cells[$y,$x].FG = '#FFFFFF'
                $this.Cells[$y,$x].BG = '#000000'
            }
        }
    }
    
    [void] SetCell([int]$x, [int]$y, [char]$char, [string]$fg, [string]$bg) {
        if ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height) {
            $this.Cells[$y,$x].Char = $char
            $this.Cells[$y,$x].FG = $fg
            $this.Cells[$y,$x].BG = $bg
        }
    }
    
    [Cell] GetCell([int]$x, [int]$y) {
        if ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height) {
            return $this.Cells[$y,$x]
        }
        return [Cell]::new()
    }
    
    [void] WriteString([int]$x, [int]$y, [string]$text, [string]$fg, [string]$bg) {
        for ($i = 0; $i -lt $text.Length; $i++) {
            $this.SetCell($x + $i, $y, $text[$i], $fg, $bg)
        }
    }
}