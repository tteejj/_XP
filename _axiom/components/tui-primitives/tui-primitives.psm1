# ==============================================================================
# MODULE: tui-primitives (Axiom-Phoenix v4.0 - Truecolor Edition)
# PURPOSE: Provides core TuiCell class and primitive drawing operations
#          with support for 24-bit truecolor.
# ==============================================================================

#region TuiAnsiHelper - ANSI Code Generation with Truecolor Support
class TuiAnsiHelper {
    hidden static [System.Collections.Concurrent.ConcurrentDictionary[string, string]] $_fgCache = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()
    hidden static [System.Collections.Concurrent.ConcurrentDictionary[string, string]] $_bgCache = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()

    static [hashtable] $ColorMap = @{
        Black = 30; DarkBlue = 34; DarkGreen = 32; DarkCyan = 36
        DarkRed = 31; DarkMagenta = 35; DarkYellow = 33; Gray = 37
        DarkGray = 90; Blue = 94; Green = 92; Cyan = 96
        Red = 91; Magenta = 95; Yellow = 93; White = 97
    }

    static [int[]] ParseHexColor([string]$hexColor) {
        if ([string]::IsNullOrWhiteSpace($hexColor) -or -not $hexColor.StartsWith("#")) { return $null }
        $hex = $hexColor.Substring(1)
        if ($hex.Length -eq 3) { $hex = "$($hex[0])$($hex[0])$($hex[1])$($hex[1])$($hex[2])$($hex[2])" }
        if ($hex.Length -ne 6) { return $null }
        try {
            $r = [System.Convert]::ToInt32($hex.Substring(0, 2), 16)
            $g = [System.Convert]::ToInt32($hex.Substring(2, 2), 16)
            $b = [System.Convert]::ToInt32($hex.Substring(4, 2), 16)
            return @($r, $g, $b)
        } catch { return $null }
    }

    static [string] GetForegroundCode($color) {
        if ($color -is [ConsoleColor]) {
            return "`e[$([TuiAnsiHelper]::ColorMap[$color.ToString()] ?? 37)m"
        } elseif ($color -is [string] -and $color.StartsWith("#")) {
            return [TuiAnsiHelper]::GetForegroundSequence($color)
        } else {
            return "`e[37m" 
        }
    }

    static [string] GetBackgroundCode($color) {
        if ($color -is [ConsoleColor]) {
            $code = ([TuiAnsiHelper]::ColorMap[$color.ToString()] ?? 30) + 10
            return "`e[${code}m"
        } elseif ($color -is [string] -and $color.StartsWith("#")) {
            return [TuiAnsiHelper]::GetBackgroundSequence($color)
        } else {
            return "`e[40m" 
        }
    }

    static [string] GetForegroundSequence([string]$hexColor) {
        if ([string]::IsNullOrEmpty($hexColor)) { return "" }
        if ([TuiAnsiHelper]::_fgCache.ContainsKey($hexColor)) { 
            return [TuiAnsiHelper]::_fgCache[$hexColor] 
        }
        $rgb = [TuiAnsiHelper]::ParseHexColor($hexColor)
        if (-not $rgb) { return "" }
        $sequence = "`e[38;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m"
        [TuiAnsiHelper]::_fgCache[$hexColor] = $sequence
        return $sequence
    }
    
    static [string] GetBackgroundSequence([string]$hexColor) {
        if ([string]::IsNullOrEmpty($hexColor)) { return "" }
        if ([TuiAnsiHelper]::_bgCache.ContainsKey($hexColor)) { 
            return [TuiAnsiHelper]::_bgCache[$hexColor] 
        }
        $rgb = [TuiAnsiHelper]::ParseHexColor($hexColor)
        if (-not $rgb) { return "" }
        $sequence = "`e[48;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m"
        [TuiAnsiHelper]::_bgCache[$hexColor] = $sequence
        return $sequence
    }
    
    static [string] Reset() { return "`e[0m" }
    static [string] Bold() { return "`e[1m" }
    static [string] Underline() { return "`e[4m" }
    static [string] Italic() { return "`e[3m" }
}
#endregion

#region TuiCell Class - Core Compositor Unit with Truecolor Support
class TuiCell {
    [char] $Char = ' '
    $ForegroundColor = [ConsoleColor]::White
    $BackgroundColor = [ConsoleColor]::Black
    [bool] $Bold = $false
    [bool] $Underline = $false
    [bool] $Italic = $false
    [string] $StyleFlags = "" 
    [int] $ZIndex = 0        
    [object] $Metadata = $null 

    TuiCell() { }
    TuiCell([char]$char) { $this.Char = $char }
    TuiCell([char]$char, $fg, $bg) {
        $this.Char = $char
        $this.ForegroundColor = $fg
        $this.BackgroundColor = $bg
    }
    TuiCell([char]$char, $fg, $bg, [bool]$bold, [bool]$underline) {
        $this.Char = $char
        $this.ForegroundColor = $fg
        $this.BackgroundColor = $bg
        $this.Bold = $bold
        $this.Underline = $underline
    }
    # FIX: Removed the [TuiCell] type hint from the $other parameter
    # to prevent cross-module type conversion errors.
    TuiCell([object]$other) {
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

    [TuiCell] WithStyle($fg, $bg) {
        $copy = [TuiCell]::new($this)
        $copy.ForegroundColor = $fg
        $copy.BackgroundColor = $bg
        return $copy
    }

    [TuiCell] WithChar([char]$char) {
        $copy = [TuiCell]::new($this)
        $copy.Char = $char
        return $copy
    }

    # FIX: Removed the [TuiCell] type hint from the $other parameter
    # to prevent cross-module type conversion errors.
    [TuiCell] BlendWith([object]$other) {
        if ($other.ZIndex -gt $this.ZIndex) { return $other }
        if ($other.ZIndex -eq $this.ZIndex -and $other.Char -ne ' ') { return $other }
        return $this
    }

    # FIX: Removed the [TuiCell] type hint from the $other parameter
    # to prevent cross-module type conversion errors.
    [bool] DiffersFrom([object]$other) {
        if ($null -eq $other) { return $true }
        return ($this.Char -ne $other.Char -or 
                $this.ForegroundColor -ne $other.ForegroundColor -or 
                $this.BackgroundColor -ne $other.BackgroundColor -or
                $this.Bold -ne $other.Bold -or
                $this.Underline -ne $other.Underline -or
                $this.Italic -ne $other.Italic)
    }

    [string] ToAnsiString() {
        $sb = [System.Text.StringBuilder]::new()
        $fgCode = [TuiAnsiHelper]::GetForegroundCode($this.ForegroundColor)
        $bgCode = [TuiAnsiHelper]::GetBackgroundCode($this.BackgroundColor)
        [void]$sb.Append($fgCode).Append($bgCode)
        if ($this.Bold) { [void]$sb.Append([TuiAnsiHelper]::Bold()) }
        if ($this.Underline) { [void]$sb.Append([TuiAnsiHelper]::Underline()) }
        if ($this.Italic) { [void]$sb.Append([TuiAnsiHelper]::Italic()) }
        [void]$sb.Append($this.Char)
        return $sb.ToString()
    }

    [hashtable] ToLegacyFormat() {
        return @{ Char = $this.Char; FG = $this.ForegroundColor; BG = $this.BackgroundColor }
    }
    [string] ToString() {
        return "TuiCell(Char='$($this.Char)', FG='$($this.ForegroundColor)', BG='$($this.BackgroundColor)', Bold=$($this.Bold), Underline=$($this.Underline), Italic=$($this.Italic), ZIndex=$($this.ZIndex))"
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

    TuiBuffer([int]$width, [int]$height, [string]$name = "Unnamed") {
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        $this.Width = $width
        $this.Height = $height
        $this.Name = $name
        $this.Cells = New-Object 'TuiCell[,]' $height, $width
        $this.Clear()
        Write-Verbose "TuiBuffer '$($this.Name)' initialized with dimensions: $($this.Width)x$($this.Height)."
    }

    [void] Clear() { $this.Clear([TuiCell]::new()) }

    [void] Clear([TuiCell]$fillCell) {
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.Cells[$y, $x] = [TuiCell]::new($fillCell) 
            }
        }
        $this.IsDirty = $true
        Write-Verbose "TuiBuffer '$($this.Name)' cleared with specified cell."
    }

    [TuiCell] GetCell([int]$x, [int]$y) {
        if ($x -lt 0 -or $x -ge $this.Width -or $y -lt 0 -or $y -ge $this.Height) { return [TuiCell]::new() }
        return $this.Cells[$y, $x]
    }

    [void] SetCell([int]$x, [int]$y, [TuiCell]$cell) {
        if ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height) {
            $this.Cells[$y, $x] = $cell
            $this.IsDirty = $true
        } else {
            Write-Warning "Attempted to set cell out of bounds in TuiBuffer '$($this.Name)': ($x, $y) is outside 0..$($this.Width-1), 0..$($this.Height-1). Cell: '$($cell.Char)'."
        }
    }

    [void] WriteString([int]$x, [int]$y, [string]$text, $fg, $bg) {
        if ($y -lt 0 -or $y -ge $this.Height) {
            Write-Warning "Skipping WriteString: Y coordinate ($y) out of bounds for buffer '$($this.Name)' (0..$($this.Height-1)). Text: '$text'."
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
        $this.IsDirty = $true
        Write-Verbose "WriteString: Wrote '$text' to buffer '$($this.Name)' at ($x, $y)."
    }

    # FIX: Removed the [TuiBuffer] type hint from the $other parameter
    # to prevent cross-module type conversion errors.
    [void] BlendBuffer([object]$other, [int]$offsetX, [int]$offsetY) {
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
        $this.IsDirty = $true
        Write-Verbose "BlendBuffer: Blended buffer '$($other.Name)' onto '$($this.Name)' at ($offsetX, $offsetY)."
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
        Write-Verbose "GetSubBuffer: Created sub-buffer '$($subBuffer.Name)' from '$($this.Name)' at ($x, $y) with dimensions $($width)x$($height)."
        return $subBuffer
    }

    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0) { throw [System.ArgumentOutOfRangeException]::new("newWidth", "New width must be positive.") }
        if ($newHeight -le 0) { throw [System.ArgumentOutOfRangeException]::new("newHeight", "New height must be positive.") }
        $oldCells = $this.Cells
        $oldWidth = $this.Width
        $oldHeight = $this.Height
        $this.Width = $newWidth
        $this.Height = $newHeight
        $this.Cells = New-Object 'TuiCell[,]' $newHeight, $newWidth
        $this.Clear()
        $copyWidth = [Math]::Min($oldWidth, $newWidth)
        $copyHeight = [Math]::Min($oldHeight, $newHeight)
        for ($y = 0; $y -lt $copyHeight; $y++) {
            for ($x = 0; $x -lt $copyWidth; $x++) {
                $this.Cells[$y, $x] = $oldCells[$y, $x]
            }
        }
        $this.IsDirty = $true
        Write-Verbose "TuiBuffer '$($this.Name)' resized from $($oldWidth)x$($oldHeight) to $($newWidth)x$($newHeight)."
    }

    [string] ToString() {
        return "TuiBuffer(Name='$($this.Name)', Width=$($this.Width), Height=$($this.Height), IsDirty=$($this.IsDirty))"
    }
}
#endregion

#region Drawing Primitives - High-Level Drawing Functions with Truecolor Support
function Write-TuiText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][TuiBuffer]$Buffer,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][string]$Text,
        $ForegroundColor = [ConsoleColor]::White,
        $BackgroundColor = [ConsoleColor]::Black,
        [bool]$Bold = $false,
        [bool]$Underline = $false,
        [bool]$Italic = $false
    )
    try {
        if ($Y -lt 0 -or $Y -ge $Buffer.Height) {
            Write-Warning "Skipping Write-TuiText: Y coordinate ($Y) for text '$Text' is out of buffer '$($Buffer.Name)' vertical bounds (0..$($Buffer.Height-1))."
            return
        }
        $baseCell = [TuiCell]::new(' ', $ForegroundColor, $BackgroundColor)
        $baseCell.Bold = $Bold
        $baseCell.Underline = $Underline
        $baseCell.Italic = $Italic
        $currentX = $X
        foreach ($char in $Text.ToCharArray()) {
            if ($currentX -ge $Buffer.Width) { break } 
            if ($currentX -ge 0) {
                $charCell = [TuiCell]::new($baseCell)
                $charCell.Char = $char
                $Buffer.SetCell($currentX, $Y, $charCell)
            }
            $currentX++
        }
        Write-Verbose "Write-TuiText: Wrote '$Text' to buffer '$($Buffer.Name)' at ($X, $Y)."
    }
    catch {
        Write-Error "Failed to write text to TUI buffer '$($Buffer.Name)' at ($X, $Y): $($_.Exception.Message)"
        throw
    }
}

function Write-TuiBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][TuiBuffer]$Buffer,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$Width,
        [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$Height,
        [ValidateSet("Single", "Double", "Rounded", "Thick")][string]$BorderStyle = "Single",
        $BorderColor = [ConsoleColor]::White,
        $BackgroundColor = [ConsoleColor]::Black,
        [string]$Title = ""
    )
    try {
        if ($X -ge $Buffer.Width -or ($X + $Width) -le 0 -or $Y -ge $Buffer.Height -or ($Y + $Height) -le 0) {
            Write-Verbose "Skipping Write-TuiBox: Box at ($X, $Y) with dimensions $($Width)x$($Height) is entirely outside buffer '$($Buffer.Name)'."
            return
        }
        $borders = Get-TuiBorderChars -Style $BorderStyle
        $drawStartX = [Math]::Max(0, $X)
        $drawStartY = [Math]::Max(0, $Y)
        $drawEndX = [Math]::Min($Buffer.Width, $X + $Width)
        $drawEndY = [Math]::Min($Buffer.Height, $Y + $Height)
        $effectiveWidth = $drawEndX - $drawStartX
        $effectiveHeight = $drawEndY - $drawStartY
        if ($effectiveWidth -le 0 -or $effectiveHeight -le 0) {
            Write-Verbose "Write-TuiBox: Effective drawing area is invalid after clipping. Skipping."
            return
        }
        $fillCell = [TuiCell]::new(' ', $BorderColor, $BackgroundColor)
        for ($currentY = $drawStartY; $currentY -lt $drawEndY; $currentY++) {
            for ($currentX = $drawStartX; $currentX -lt $drawEndX; $currentX++) {
                $Buffer.SetCell($currentX, $currentY, [TuiCell]::new($fillCell))
            }
        }
        if ($X -ge 0 -and $Y -ge 0) { $Buffer.SetCell($X, $Y, [TuiCell]::new($borders.TopLeft, $BorderColor, $BackgroundColor)) }
        if (($X + $Width - 1) -lt $Buffer.Width -and $Y -ge 0) { $Buffer.SetCell($X + $Width - 1, $Y, [TuiCell]::new($borders.TopRight, $BorderColor, $BackgroundColor)) }
        if ($X -ge 0 -and ($Y + $Height - 1) -lt $Buffer.Height) { $Buffer.SetCell($X, $Y + $Height - 1, [TuiCell]::new($borders.BottomLeft, $BorderColor, $BackgroundColor)) }
        if (($X + $Width - 1) -lt $Buffer.Width -and ($Y + $Height - 1) -lt $Buffer.Height) { $Buffer.SetCell($X + $Width - 1, $Y + $Height - 1, [TuiCell]::new($borders.BottomRight, $BorderColor, $BackgroundColor)) }
        for ($cx = 1; $cx -lt ($Width - 1); $cx++) {
            if (($X + $cx) -ge 0 -and ($X + $cx) -lt $Buffer.Width) {
                if ($Y -ge 0 -and $Y -lt $Buffer.Height) { $Buffer.SetCell($X + $cx, $Y, [TuiCell]::new($borders.Horizontal, $BorderColor, $BackgroundColor)) }
                if ($Height -gt 1 -and ($Y + $Height - 1) -ge 0 -and ($Y + $Height - 1) -lt $Buffer.Height) { $Buffer.SetCell($X + $cx, $Y + $Height - 1, [TuiCell]::new($borders.Horizontal, $BorderColor, $BackgroundColor)) }
            }
        }
        for ($cy = 1; $cy -lt ($Height - 1); $cy++) {
            if (($Y + $cy) -ge 0 -and ($Y + $cy) -lt $Buffer.Height) {
                if ($X -ge 0 -and $X -lt $Buffer.Width) { $Buffer.SetCell($X, $Y + $cy, [TuiCell]::new($borders.Vertical, $BorderColor, $BackgroundColor)) }
                if ($Width -gt 1 -and ($X + $Width - 1) -ge 0 -and ($X + $Width - 1) -lt $Buffer.Width) { $Buffer.SetCell($X + $Width - 1, $Y + $cy, [TuiCell]::new($borders.Vertical, $BorderColor, $BackgroundColor)) }
            }
        }
        if (-not [string]::IsNullOrEmpty($Title) -and $Y -ge 0 -and $Y -lt $Buffer.Height) {
            $titleText = " $Title "
            if ($titleText.Length -le ($Width - 2)) { 
                $titleX = $X + [Math]::Floor(($Width - $titleText.Length) / 2)
                Write-TuiText -Buffer $Buffer -X $titleX -Y $Y -Text $titleText -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
            }
        }
        Write-Verbose "Write-TuiBox: Drew '$BorderStyle' box on buffer '$($Buffer.Name)' at ($X, $Y) with dimensions $($Width)x$($Height)."
    }
    catch {
        Write-Error "Failed to draw TUI box on buffer '$($Buffer.Name)' at ($X, $Y), $($Width)x$($Height): $($_.Exception.Message)"
        throw
    }
}

function Get-TuiBorderChars {
    [CmdletBinding()]
    param(
        [ValidateSet("Single", "Double", "Rounded", "Thick")][string]$Style = "Single"
    )
    try {
        $styles = @{
            Single = @{ TopLeft = '┌'; TopRight = '┐'; BottomLeft = '└'; BottomRight = '┘'; Horizontal = '─'; Vertical = '│' }
            Double = @{ TopLeft = '╔'; TopRight = '╗'; BottomLeft = '╚'; BottomRight = '╝'; Horizontal = '═'; Vertical = '║' }
            Rounded = @{ TopLeft = '╭'; TopRight = '╮'; BottomLeft = '╰'; BottomRight = '╯'; Horizontal = '─'; Vertical = '│' }
            Thick = @{ TopLeft = '┏'; TopRight = '┓'; BottomLeft = '┗'; BottomRight = '┛'; Horizontal = '━'; Vertical = '┃' }
        }
        $selectedStyle = $styles[$Style]
        if ($null -eq $selectedStyle) {
            Write-Warning "Get-TuiBorderChars: Border style '$Style' not found. Returning 'Single' style."
            return $styles.Single
        }
        Write-Verbose "Get-TuiBorderChars: Retrieved TUI border characters for style: $Style."
        return $selectedStyle
    }
    catch {
        Write-Error "Failed to get TUI border characters for style '$Style': $($_.Exception.Message)"
        throw
    }
}
#endregion