class TuiCell {
    [char] $Char = ' '
    [ConsoleColor] $ForegroundColor = [ConsoleColor]::White
    [ConsoleColor] $BackgroundColor = [ConsoleColor]::Black
    [bool] $Bold = $false
    [bool] $Underline = $false
    [bool] $Italic = $false
    [string] $StyleFlags = ""
    [int] $ZIndex = 0
    [object] $Metadata = $null

    # Default constructor
    TuiCell() {
        $this.Char = ' '
        $this.ForegroundColor = [ConsoleColor]::White
        $this.BackgroundColor = [ConsoleColor]::Black
    }

    # Character constructor
    TuiCell([char]$char) {
        $this.Char = $char
        $this.ForegroundColor = [ConsoleColor]::White
        $this.BackgroundColor = [ConsoleColor]::Black
    }

    # Full constructor
    TuiCell([char]$char, [ConsoleColor]$fg, [ConsoleColor]$bg) {
        $this.Char = $char
        $this.ForegroundColor = $fg
        $this.BackgroundColor = $bg
    }

    # Style constructor
    TuiCell([char]$char, [ConsoleColor]$fg, [ConsoleColor]$bg, [bool]$bold, [bool]$underline) {
        $this.Char = $char
        $this.ForegroundColor = $fg
        $this.BackgroundColor = $bg
        $this.Bold = $bold
        $this.Underline = $underline
    }

    # Copy constructor
    TuiCell([TuiCell]$other) {
        if ($null -ne $other) {
            $this.Char = $other.Char
            $this.ForegroundColor = $other.ForegroundColor
            $this.BackgroundColor = $other.BackgroundColor
            $this.Bold = $other.Bold
            $this.Underline = $other.Underline
            $this.Italic = $other.Italic
            $this.StyleFlags = $other.StyleFlags
            $this.ZIndex = $other.ZIndex
            $this.Metadata = $other.Metadata
        }
    }

    # Create a styled copy
    [TuiCell] WithStyle([ConsoleColor]$fg, [ConsoleColor]$bg) {
        $copy = [TuiCell]::new($this)
        $copy.ForegroundColor = $fg
        $copy.BackgroundColor = $bg
        return $copy
    }

    # Create a character copy
    [TuiCell] WithChar([char]$char) {
        $copy = [TuiCell]::new($this)
        $copy.Char = $char
        return $copy
    }

    # Blend this cell with another (higher Z-index wins)
    [TuiCell] BlendWith([TuiCell]$other) {
        if ($null -eq $other) { return $this }
        if ($other.ZIndex -gt $this.ZIndex) { return $other }
        if ($other.ZIndex -eq $this.ZIndex -and $other.Char -ne ' ') { return $other }
        return $this
    }

    # Check if this cell differs from another
    [bool] DiffersFrom([TuiCell]$other) {
        if ($null -eq $other) { return $true }
        return ($this.Char -ne $other.Char -or 
                $this.ForegroundColor -ne $other.ForegroundColor -or 
                $this.BackgroundColor -ne $other.BackgroundColor -or
                $this.Bold -ne $other.Bold -or
                $this.Underline -ne $other.Underline -or
                $this.Italic -ne $other.Italic)
    }

    # Generate ANSI escape sequence for this cell
    [string] ToAnsiString() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Color codes - This now works because TuiAnsiHelper is known to the parser.
        $fgCode = [TuiAnsiHelper]::GetForegroundCode($this.ForegroundColor)
        $bgCode = [TuiAnsiHelper]::GetBackgroundCode($this.BackgroundColor)
        [void]$sb.Append("`e[${fgCode};${bgCode}")
        
        # Style codes
        if ($this.Bold) { [void]$sb.Append(";1") }
        if ($this.Underline) { [void]$sb.Append(";4") }
        if ($this.Italic) { [void]$sb.Append(";3") }
        
        [void]$sb.Append("m").Append($this.Char)
        return $sb.ToString()
    }

    # Convert to legacy buffer format for compatibility
    [hashtable] ToLegacyFormat() {
        return @{
            Char = $this.Char
            FG = $this.ForegroundColor
            BG = $this.BackgroundColor
        }
    }

    # String representation
    [string] ToString() {
        return "TuiCell($($this.Char), $($this.ForegroundColor), $($this.BackgroundColor))"
    }
}
