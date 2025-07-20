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
        $this.Fill(' ', '#FFFFFF', '#000000')
    }
    
    [void] Fill([char]$char, [string]$fg, [string]$bg) {
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.Cells[$y,$x].Char = $char
                $this.Cells[$y,$x].FG = $fg
                $this.Cells[$y,$x].BG = $bg
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
    
    [string] ToString() {
        $sb = [System.Text.StringBuilder]::new(8192)
        
        # Use cursor positioning instead of line-by-line rendering
        [void]$sb.Append("`e[H")  # Home cursor
        
        $lastFG = ""
        $lastBG = ""
        $currentRow = 0
        
        for ($y = 0; $y -lt $this.Height; $y++) {
            # Move to start of line
            [void]$sb.Append("`e[$($y + 1);1H")
            
            for ($x = 0; $x -lt $this.Width; $x++) {
                $cell = $this.Cells[$y,$x]
                
                # Only change colors when absolutely necessary
                if ($cell.FG -ne $lastFG -or $cell.BG -ne $lastBG) {
                    # Use cached color strings for performance
                    $fgEscape = $this.GetColorEscape($cell.FG, $true)
                    $bgEscape = $this.GetColorEscape($cell.BG, $false)
                    
                    [void]$sb.Append($fgEscape)
                    [void]$sb.Append($bgEscape)
                    
                    $lastFG = $cell.FG
                    $lastBG = $cell.BG
                }
                
                # Write character
                [void]$sb.Append($cell.Char)
            }
        }
        
        return $sb.ToString()
    }
    
    # Cache for color escape sequences
    static [hashtable]$ColorCache = @{}
    
    [string] GetColorEscape([string]$color, [bool]$isForeground) {
        $cacheKey = "$color-$isForeground"
        if ([Buffer]::ColorCache.ContainsKey($cacheKey)) {
            return [Buffer]::ColorCache[$cacheKey]
        }
        
        if ($color -match '^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$') {
            $r = [Convert]::ToInt32($Matches[1], 16)
            $g = [Convert]::ToInt32($Matches[2], 16)
            $b = [Convert]::ToInt32($Matches[3], 16)
            
            $escape = if ($isForeground) {
                "`e[38;2;$r;$g;${b}m"
            } else {
                "`e[48;2;$r;$g;${b}m"
            }
            
            [Buffer]::ColorCache[$cacheKey] = $escape
            return $escape
        }
        
        return ""
    }
}