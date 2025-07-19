# Simple cell class for double buffering
class Cell {
    [char]$Char = ' '
    [string]$FG = '#FFFFFF'
    [string]$BG = '#000000'
    
    Cell() {}
    
    Cell([char]$char, [string]$fg, [string]$bg) {
        $this.Char = $char
        $this.FG = $fg
        $this.BG = $bg
    }
    
    [bool] Equals($other) {
        if ($null -eq $other) { return $false }
        return $this.Char -eq $other.Char -and 
               $this.FG -eq $other.FG -and 
               $this.BG -eq $other.BG
    }
    
    [void] CopyFrom($other) {
        $this.Char = $other.Char
        $this.FG = $other.FG
        $this.BG = $other.BG
    }
}