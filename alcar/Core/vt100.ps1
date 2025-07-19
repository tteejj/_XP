# VT100/ANSI Core for BOLT-AXIOM with True Color Support

class VT {
    # Cursor movement
    static [string] MoveTo([int]$x, [int]$y) { return "`e[$($y);$($x)H" }
    static [string] SavePos() { return "`e[s" }
    static [string] RestorePos() { return "`e[u" }
    static [string] Hide() { return "`e[?25l" }
    static [string] Show() { return "`e[?25h" }
    
    # Screen control
    static [string] Clear() { return "`e[H`e[2J" }  # Clear screen and home
    static [string] ClearLine() { return "`e[K" }
    static [string] Home() { return "`e[H" }      # Just home position
    static [string] ClearToEnd() { return "`e[J" }  # Clear from cursor to end
    
    # Basic styles
    static [string] Reset() { return "`e[0m" }
    static [string] Bold() { return "`e[1m" }
    static [string] Dim() { return "`e[2m" }
    
    # 24-bit True Color
    static [string] RGB([int]$r, [int]$g, [int]$b) { 
        return "`e[38;2;$r;$g;$($b)m" 
    }
    static [string] RGBBG([int]$r, [int]$g, [int]$b) { 
        return "`e[48;2;$r;$g;$($b)m" 
    }
    
    # Wireframe color palette (true color)
    static [string] Border() { return [VT]::RGB(0, 255, 255) }      # Cyan
    static [string] BorderDim() { return [VT]::RGB(0, 128, 128) }   # Dark cyan
    static [string] BorderActive() { return [VT]::RGB(255, 255, 255) } # White
    static [string] Text() { return [VT]::RGB(192, 192, 192) }      # Light gray
    static [string] TextDim() { return [VT]::RGB(128, 128, 128) }   # Gray
    static [string] TextBright() { return [VT]::RGB(255, 255, 255) } # White
    static [string] Accent() { return [VT]::RGB(0, 255, 0) }        # Green
    static [string] Warning() { return [VT]::RGB(255, 255, 0) }     # Yellow
    static [string] Error() { return [VT]::RGB(255, 0, 0) }         # Red
    static [string] Selected() { return [VT]::RGB(255, 255, 255) + [VT]::RGBBG(0, 64, 128) } # White on dark blue
    
    # Box drawing - single lines for speed
    static [string] TL() { return "┌" }     # Top left
    static [string] TR() { return "┐" }     # Top right
    static [string] BL() { return "└" }     # Bottom left
    static [string] BR() { return "┘" }     # Bottom right
    static [string] H() { return "─" }      # Horizontal
    static [string] V() { return "│" }      # Vertical
    static [string] Cross() { return "┼" }  # Cross
    static [string] T() { return "┬" }      # T down
    static [string] B() { return "┴" }      # T up
    static [string] L() { return "├" }      # T right
    static [string] R() { return "┤" }      # T left
    
    # Double lines for emphasis
    static [string] DTL() { return "╔" }
    static [string] DTR() { return "╗" }
    static [string] DBL() { return "╚" }
    static [string] DBR() { return "╝" }
    static [string] DH() { return "═" }
    static [string] DV() { return "║" }
}

# Layout measurement helpers
class Measure {
    static [int] TextWidth([string]$text) {
        # Remove ANSI sequences for accurate measurement
        $clean = $text -replace '\x1b\[[0-9;]*m', ''
        return $clean.Length
    }
    
    static [string] Truncate([string]$text, [int]$maxWidth) {
        $clean = $text -replace '\x1b\[[0-9;]*m', ''
        if ($clean.Length -le $maxWidth) { return $text }
        return $clean.Substring(0, $maxWidth - 3) + "..."
    }
    
    static [string] Pad([string]$text, [int]$width, [string]$align = "Left") {
        $textWidth = [Measure]::TextWidth($text)
        if ($textWidth -ge $width) { return [Measure]::Truncate($text, $width) }
        
        $padding = $width - $textWidth
        switch ($align) {
            "Left" { return $text + (" " * $padding) }
            "Right" { return (" " * $padding) + $text }
            "Center" { 
                $left = [int]($padding / 2)
                $right = $padding - $left
                return (" " * $left) + $text + (" " * $right)
            }
        }
        return $text
    }
}