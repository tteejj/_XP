# TUI Primitives v5.0 - NCurses Compositor Foundation
# Provides core TuiCell class and primitive drawing operations
# CORRECTED ORDERING: TuiAnsiHelper is defined BEFORE TuiCell to resolve parse-time dependency.



#region TuiAnsiHelper - ANSI Code Generation
class TuiAnsiHelper {
    static [hashtable] $ColorMap = @{
        Black = 30; DarkBlue = 34; DarkGreen = 32; DarkCyan = 36
        DarkRed = 31; DarkMagenta = 35; DarkYellow = 33; Gray = 37
        DarkGray = 90; Blue = 94; Green = 92; Cyan = 96
        Red = 91; Magenta = 95; Yellow = 93; White = 97
    }

    static [int] GetForegroundCode([ConsoleColor]$color) {
        return [TuiAnsiHelper]::ColorMap[$color.ToString()]
    }

    static [int] GetBackgroundCode([ConsoleColor]$color) {
        return [TuiAnsiHelper]::ColorMap[$color.ToString()] + 10
    }

    static [string] Reset() {
        return "`e[0m"
    }

    static [string] Bold() {
        return "`e[1m"
    }

    static [string] Underline() {
        return "`e[4m"
    }

    static [string] Italic() {
        return "`e[3m"
    }
}
#endregion

#region TuiCell Class - Core Compositor Unit
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
#endregion

#region TuiBuffer Class - 2D Array of TuiCells
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
#endregion

#region Drawing Primitives - High-Level Drawing Functions
function Write-TuiText {
    param(
        [TuiBuffer]$Buffer,
        [int]$X,
        [int]$Y,
        [string]$Text,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        [bool]$Bold = $false,
        [bool]$Underline = $false
    )
    
    if ($null -eq $Buffer -or [string]::IsNullOrEmpty($Text)) { return }
    
    $cell = [TuiCell]::new(' ', $ForegroundColor, $BackgroundColor)
    $cell.Bold = $Bold
    $cell.Underline = $Underline
    
    $currentX = $X
    foreach ($char in $Text.ToCharArray()) {
        if ($currentX -ge $Buffer.Width) { break }
        if ($currentX -ge 0) {
            $charCell = [TuiCell]::new($cell)
            $charCell.Char = $char
            $Buffer.SetCell($currentX, $Y, $charCell)
        }
        $currentX++
    }
}

function Write-TuiBox {
    param(
        [TuiBuffer]$Buffer,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [string]$BorderStyle = "Single",
        [ConsoleColor]$BorderColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        [string]$Title = ""
    )
    
    if ($null -eq $Buffer -or $Width -le 0 -or $Height -le 0) { return }
    
    $borders = Get-TuiBorderChars -Style $BorderStyle
    
    # Top border
    $topLine = "$($borders.TopLeft)$($borders.Horizontal * ($Width - 2))$($borders.TopRight)"
    Write-TuiText -Buffer $Buffer -X $X -Y $Y -Text $topLine -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    
    # Title if specified
    if (-not [string]::IsNullOrEmpty($Title)) {
        $titleText = " $Title "
        if ($titleText.Length -le ($Width - 2)) {
            $titleX = $X + [Math]::Floor(($Width - $titleText.Length) / 2)
            Write-TuiText -Buffer $Buffer -X $titleX -Y $Y -Text $titleText -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        }
    }
    
    # Side borders and fill
    for ($i = 1; $i -lt ($Height - 1); $i++) {
        $currentY = $Y + $i
        
        # Left border
        Write-TuiText -Buffer $Buffer -X $X -Y $currentY -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        
        # Fill
        $fillText = ' ' * ($Width - 2)
        Write-TuiText -Buffer $Buffer -X ($X + 1) -Y $currentY -Text $fillText -BackgroundColor $BackgroundColor
        
        # Right border
        Write-TuiText -Buffer $Buffer -X ($X + $Width - 1) -Y $currentY -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
    
    # Bottom border
    if ($Height -gt 1) {
        $bottomLine = "$($borders.BottomLeft)$($borders.Horizontal * ($Width - 2))$($borders.BottomRight)"
        Write-TuiText -Buffer $Buffer -X $X -Y ($Y + $Height - 1) -Text $bottomLine -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
}

function Get-TuiBorderChars {
    param([string]$Style = "Single")
    
    $styles = @{
        Single = @{
            TopLeft = '┌'; TopRight = '┐'; BottomLeft = '└'; BottomRight = '┘'
            Horizontal = '─'; Vertical = '│'
        }
        Double = @{
            TopLeft = '╔'; TopRight = '╗'; BottomLeft = '╚'; BottomRight = '╝'
            Horizontal = '═'; Vertical = '║'
        }
        Rounded = @{
            TopLeft = '╭'; TopRight = '╮'; BottomLeft = '╰'; BottomRight = '╯'
            Horizontal = '─'; Vertical = '│'
        }
        Thick = @{
            TopLeft = '┏'; TopRight = '┓'; BottomLeft = '┗'; BottomRight = '┛'
            Horizontal = '━'; Vertical = '┃'
        }
    }
    
    return $styles[$Style] ?? $styles.Single
}
#endregion

# Export all functions
