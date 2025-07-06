# ==============================================================================
# Axiom-Phoenix v4.0 - All Classes Consolidated
# Contains all PowerShell classes from the entire project
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Management.Automation
using namespace System.Threading

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

    [TuiCell] BlendWith([object]$other) {
        if ($null -eq $other) { return $this }
        
        if ($other.ZIndex -gt $this.ZIndex) { 
            return [TuiCell]::new($other)
        }
        
        if ($other.ZIndex -eq $this.ZIndex) {
            if ($other.Char -ne ' ' -or $other.Bold -or $other.Underline -or $other.Italic) {
                return [TuiCell]::new($other)
            }
            if ($other.BackgroundColor -ne $this.BackgroundColor) {
                return [TuiCell]::new($other)
            }
        }
        
        return $this
    }

    [bool] DiffersFrom([object]$other) {
        if ($null -eq $other) { return $true }
        
        return ($this.Char -ne $other.Char -or 
                $this.ForegroundColor -ne $other.ForegroundColor -or 
                $this.BackgroundColor -ne $other.BackgroundColor -or
                $this.Bold -ne $other.Bold -or
                $this.Underline -ne $other.Underline -or
                $this.Italic -ne $other.Italic -or
                $this.ZIndex -ne $other.ZIndex)
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

#region UIElement - Base Class for all UI Components
class UIElement {
    [string] $Name = "UIElement" 
    [int] $X = 0               
    [int] $Y = 0               
    [int] $Width = 10          
    [int] $Height = 3          
    [bool] $Visible = $true    
    [bool] $Enabled = $true    
    [bool] $IsFocusable = $false 
    [bool] $IsFocused = $false  
    [int] $TabIndex = 0        
    [int] $ZIndex = 0          
    [UIElement] $Parent = $null 
    [System.Collections.Generic.List[UIElement]] $Children 
    
    hidden [object] $_private_buffer = $null
    hidden [bool] $_needs_redraw = $true
    
    [hashtable] $Metadata = @{} 

    UIElement() {
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        Write-Verbose "UIElement 'Unnamed' created with default size ($($this.Width)x$($this.Height))."
    }

    UIElement([string]$name) {
        $this.Name = $name
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        Write-Verbose "UIElement '$($this.Name)' created with default size ($($this.Width)x$($this.Height))."
    }

    UIElement([int]$x, [int]$y, [int]$width, [int]$height) {
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($width, $height, "Unnamed.Buffer")
        Write-Verbose "UIElement 'Unnamed' created at ($x, $y) with dimensions $($width)x$($height)."
    }

    [hashtable] GetAbsolutePosition() {
        $absX = $this.X
        $absY = $this.Y
        $current = $this.Parent
        while ($null -ne $current) {
            $absX += $current.X
            $absY += $current.Y
            $current = $current.Parent
        }
        return @{ X = $absX; Y = $absY }
    }

    [void] AddChild([object]$child) {
        try {
            if ($child -eq $this) { throw [System.ArgumentException]::new("Cannot add an element as its own child.") }
            if ($this.Children.Contains($child)) {
                Write-Warning "Child '$($child.Name)' is already a child of '$($this.Name)'. Skipping addition."
                return
            }
            if ($child.Parent -ne $null) {
                Write-Warning "Child '$($child.Name)' already has a parent ('$($child.Parent.Name)'). Consider removing it from its current parent first."
            }
            $child.Parent = $this
            $this.Children.Add($child)
            $this.RequestRedraw()
            Write-Verbose "Added child '$($child.Name)' to parent '$($this.Name)'."
        }
        catch {
            Write-Error "Failed to add child '$($child.Name)' to '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    [void] RemoveChild([object]$child) {
        try {
            if ($this.Children.Remove($child)) {
                $child.Parent = $null
                $this.RequestRedraw()
                Write-Verbose "Removed child '$($child.Name)' from parent '$($this.Name)'."
            } else {
                Write-Warning "Child '$($child.Name)' not found in parent '$($this.Name)' for removal. No action taken."
            }
        }
        catch {
            Write-Error "Failed to remove child '$($child.Name)' from '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    [void] RequestRedraw() {
        $this._needs_redraw = $true
        if ($null -ne $this.Parent) {
            $this.Parent.RequestRedraw()
        }
        Write-Verbose "Redraw requested for '$($this.Name)'."
    }

    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -le 0) { throw [System.ArgumentOutOfRangeException]::new("newWidth", "New width must be positive.") }
        if ($newHeight -le 0) { throw [System.ArgumentOutOfRangeException]::new("newHeight", "New height must be positive.") }
        try {
            if ($this.Width -eq $newWidth -and $this.Height -eq $newHeight) {
                Write-Verbose "Resize: Component '$($this.Name)' already has target dimensions ($($newWidth)x$($newHeight)). No change."
                return
            }
            $this.Width = $newWidth
            $this.Height = $newHeight
            if ($null -ne $this._private_buffer) {
                $this._private_buffer.Resize($newWidth, $newHeight)
            } else {
                $this._private_buffer = [TuiBuffer]::new($newWidth, $newHeight, "$($this.Name).Buffer")
                Write-Verbose "Re-initialized buffer for '$($this.Name)' due to null buffer."
            }
            $this.RequestRedraw()
            $this.OnResize($newWidth, $newHeight)
            Write-Verbose "Component '$($this.Name)' resized to $($newWidth)x$($newHeight)."
        }
        catch {
            Write-Error "Failed to resize component '$($this.Name)' to $($newWidth)x$($newHeight): $($_.Exception.Message)"
            throw
        }
    }

    [void] Move([int]$newX, [int]$newY) {
        if ($this.X -eq $newX -and $this.Y -eq $newY) {
            Write-Verbose "Move: Component '$($this.Name)' already at target position ($($newX), $($newY)). No change."
            return
        }
        $this.X = $newX
        $this.Y = $newY
        $this.RequestRedraw()
        $this.OnMove($newX, $newY)
        Write-Verbose "Component '$($this.Name)' moved to ($newX, $newY)."
    }

    [bool] ContainsPoint([int]$x, [int]$y) {
        return ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height)
    }

    [object] GetChildAtPoint([int]$x, [int]$y) {
        for ($i = $this.Children.Count - 1; $i -ge 0; $i--) {
            $child = $this.Children[$i]
            if ($child.Visible -and $child.ContainsPoint($x - $child.X, $y - $child.Y)) {
                return $child
            }
        }
        return $null
    }

    [void] OnRender() {
        if ($null -ne $this._private_buffer) {
            $this._private_buffer.Clear()
        }
        Write-Verbose "OnRender called for '$($this.Name)': Default buffer clear."
    }

    [void] OnResize([int]$newWidth, [int]$newHeight) {
        Write-Verbose "OnResize called for '$($this.Name)': No custom resize logic."
    }

    [void] OnMove([int]$newX, [int]$newY) {
        Write-Verbose "OnMove called for '$($this.Name)': No custom move logic."
    }

    [void] OnFocus() { Write-Verbose "OnFocus called for '$($this.Name)'." }
    [void] OnBlur() { Write-Verbose "OnBlur called for '$($this.Name)'." }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        Write-Verbose "HandleInput called for '$($this.Name)': Key: $($keyInfo.Key)."
        return $false
    }

    [void] Render() {
        if (-not $this.Visible) { 
            Write-Verbose "Skipping Render for '$($this.Name)': Not visible."
            return 
        }
        $this._RenderContent() 
    }

    hidden [void] _RenderContent() {
        if (-not $this.Visible) { return }
        if ($this._needs_redraw -or ($null -eq $this._private_buffer)) {
            if ($null -eq $this._private_buffer -or $this._private_buffer.Width -ne $this.Width -or $this._private_buffer.Height -ne $this.Height) {
                $bufferWidth = [Math]::Max(1, $this.Width)
                $bufferHeight = [Math]::Max(1, $this.Height)
                $this._private_buffer = [TuiBuffer]::new($bufferWidth, $bufferHeight, "$($this.Name).Buffer")
                Write-Verbose "Re-initialized buffer for '$($this.Name)' due to null or dimension mismatch ($($bufferWidth)x$($bufferHeight))."
            }
            $this.OnRender()
            $this._needs_redraw = $false
            Write-Verbose "Rendered own content for '$($this.Name)'."
        }
        foreach ($child in $this.Children | Sort-Object ZIndex) { 
            if ($child.Visible) {
                $child.Render()
                if ($null -ne $child._private_buffer) {
                    $this._private_buffer.BlendBuffer($child._private_buffer, $child.X, $child.Y)
                    Write-Verbose "Blended child '$($child.Name)' onto '$($this.Name)' at ($($child.X), $($child.Y))."
                }
            }
        }
    }

    [object] GetBuffer() { return $this._private_buffer }
    
    [string] ToString() {
        return "$($this.GetType().Name)(Name='$($this.Name)', X=$($this.X), Y=$($this.Y), Width=$($this.Width), Height=$($this.Height), Visible=$($this.Visible))"
    }
}
#endregion

#region Component - A generic container component
class Component : UIElement {
    Component([string]$name) : base($name) {
        $this.Name = $name
        Write-Verbose "Component '$($this.Name)' created."
    }

    hidden [void] _RenderContent() {
        ([UIElement]$this)._RenderContent()
        Write-Verbose "_RenderContent called for Component '$($this.Name)' (delegating to base UIElement)."
    }

    [string] ToString() {
        return "Component(Name='$($this.Name)', Children=$($this.Children.Count))"
    }
}
#endregion

#region Screen - Top-level Container for Application Views
class Screen : UIElement {
    [hashtable]$Services
    [object]$ServiceContainer 
    [System.Collections.Generic.Dictionary[string, object]]$State
    [System.Collections.Generic.List[UIElement]] $Panels
    
    $LastFocusedComponent
    
    hidden [System.Collections.Generic.Dictionary[string, string]] $EventSubscriptions 

    Screen([string]$name, [hashtable]$services) : base($name) {
        $this.Services = $services
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        $this.ServiceContainer = $null
        Write-Verbose "Screen '$($this.Name)' created with hashtable services."
    }

    Screen([string]$name, [object]$serviceContainer) : base($name) {
        $this.ServiceContainer = $serviceContainer
        $this.Services = [hashtable]::new()
        if ($this.ServiceContainer.PSObject.Methods['GetAllRegisteredServices'] -and $this.ServiceContainer.PSObject.Methods['GetService']) { 
            try {
                $registeredServices = $this.ServiceContainer.GetAllRegisteredServices()
                foreach ($service in $registeredServices) {
                    try {
                        $this.Services[$service.Name] = $this.ServiceContainer.GetService($service.Name)
                    } catch {
                        Write-Warning "Screen '$($this.Name)': Failed to resolve service '$($service.Name)' from container: $($_.Exception.Message)"
                    }
                }
                Write-Verbose "Screen '$($this.Name)' populated Services hashtable from ServiceContainer."
            } catch {
                Write-Warning "Screen '$($this.Name)': Failed to enumerate services from container: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Screen '$($this.Name)' received a non-ServiceContainer object for DI. Services hashtable might be incomplete or inaccurate."
        }
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        Write-Verbose "Screen '$($this.Name)' created with ServiceContainer."
    }

    [void] Initialize() { Write-Verbose "Initialize called for Screen '$($this.Name)': Default (no-op)." }
    [void] OnEnter() { Write-Verbose "OnEnter called for Screen '$($this.Name)': Default (no-op)." }
    [void] OnExit() { Write-Verbose "OnExit called for Screen '$($this.Name)': Default (no-op)." }
    [void] OnResume() { Write-Verbose "OnResume called for Screen '$($this.Name)': Default (no-op)." }

    [void] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        Write-Verbose "HandleInput called for Screen '$($this.Name)': Key: $($keyInfo.Key). Default (no-op)."
    }

    [void] Cleanup() {
        try {
            Write-Verbose "Cleanup called for Screen '$($this.Name)'."
            foreach ($kvp in $this.EventSubscriptions.GetEnumerator()) {
                try {
                    if (Get-Command 'Unsubscribe-Event' -ErrorAction SilentlyContinue) {
                        Unsubscribe-Event -EventName $kvp.Key -HandlerId $kvp.Value
                        Write-Verbose "Unsubscribed event '$($kvp.Key)' (HandlerId: $($kvp.Value)) for screen '$($this.Name)'."
                    }
                }
                catch {
                    Write-Warning "Failed to unsubscribe event '$($kvp.Key)' (HandlerId: $($kvp.Value)) for screen '$($this.Name)': $($_.Exception.Message)"
                }
            }
            $this.EventSubscriptions.Clear()
            foreach ($child in $this.Children) {
                if ($child.PSObject.Methods['Cleanup']) {
                    try { $child.Cleanup() } catch { Write-Warning "Failed to cleanup child '$($child.Name)': $($_.Exception.Message)" }
                }
            }
            $this.Panels.Clear()
            $this.Children.Clear()
            Write-Verbose "Cleaned up resources for screen: $($this.Name)."
        }
        catch {
            Write-Error "Error during Cleanup for screen '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    [void] AddPanel([object]$panel) {
        try {
            $this.Panels.Add($panel)
            $this.AddChild($panel) 
            Write-Verbose "Added panel '$($panel.Name)' to screen '$($this.Name)'."
        }
        catch {
            Write-Error "Failed to add panel '$($panel.Name)' to screen '$($this.Name)': $($_.Exception.Message)"
            throw
        }
    }

    [void] SubscribeToEvent([string]$eventName, [scriptblock]$action) {
        try {
            if (Get-Command 'Subscribe-Event' -ErrorAction SilentlyContinue) {
                $subscriptionId = Subscribe-Event -EventName $eventName -Handler $action -Source $this.Name
                $this.EventSubscriptions[$eventName] = $subscriptionId
                Write-Verbose "Screen '$($this.Name)' subscribed to event '$eventName' with HandlerId: $subscriptionId."
            } else {
                Write-Warning "Subscribe-Event function not available. Event subscription for '$eventName' failed."
            }
        }
        catch {
            Write-Error "Failed for screen '$($this.Name)' to subscribe to event '$eventName': $($_.Exception.Message)"
            throw
        }
    }
    
    hidden [void] _RenderContent() {
        ([UIElement]$this)._RenderContent()
        Write-Verbose "_RenderContent called for Screen '$($this.Name)' (rendering UIElement children, including panels)."
    }

    [string] ToString() {
        return "Screen(Name='$($this.Name)', Panels=$($this.Panels.Count), Visible=$($this.Visible))"
    }
}
#endregion

#region ServiceContainer Class
class ServiceContainer {
    hidden [hashtable] $_services = @{}
    hidden [hashtable] $_serviceFactories = @{}

    ServiceContainer() {
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "ServiceContainer created."
        }
        Write-Verbose "ServiceContainer: Instance constructed."
    }

    [void] Register([string]$name, [object]$serviceInstance) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
        if ($null -eq $serviceInstance) { throw [System.ArgumentNullException]::new("serviceInstance") }

        if ($this._services.ContainsKey($name) -or $this._serviceFactories.ContainsKey($name)) {
            throw [System.InvalidOperationException]::new("A service or factory with the name '$name' is already registered.")
        }

        $this._services[$name] = $serviceInstance
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "Registered eager service instance: '$name'."
        }
        Write-Verbose "ServiceContainer: Registered eager instance for '$name' of type '$($serviceInstance.GetType().Name)'."
    }

    [void] RegisterFactory([string]$name, [scriptblock]$factory, [bool]$isSingleton = $true) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
        if ($null -eq $factory) { throw [System.ArgumentNullException]::new("factory") }

        if ($this._services.ContainsKey($name) -or $this._serviceFactories.ContainsKey($name)) {
            throw [System.InvalidOperationException]::new("A service or factory with the name '$name' is already registered.")
        }
        
        $this._serviceFactories[$name] = @{
            Factory = $factory
            IsSingleton = $isSingleton
            Instance = $null
        }
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "Registered service factory: '$name' (Singleton: $isSingleton)."
        }
        Write-Verbose "ServiceContainer: Registered factory for '$name' (Singleton: $isSingleton)."
    }

    [object] GetService([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }

        if ($this._services.ContainsKey($name)) {
            Write-Verbose "ServiceContainer: Returning eager-loaded instance of '$name'."
            return $this._services[$name]
        }

        if ($this._serviceFactories.ContainsKey($name)) {
            return $this._InitializeServiceFromFactory($name, [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase))
        }

        $available = $this.GetAllRegisteredServices() | Select-Object -ExpandProperty Name
        throw [System.InvalidOperationException]::new("Service '$name' not found. Available services: $($available -join ', ')")
    }
    
    [object[]] GetAllRegisteredServices() {
        $list = [System.Collections.Generic.List[object]]::new()
        
        foreach ($key in $this._services.Keys) {
            $list.Add([pscustomobject]@{
                Name = $key
                Type = 'Instance'
                Initialized = $true
                Lifestyle = 'Singleton'
            })
        }
        
        foreach ($key in $this._serviceFactories.Keys) {
            $factoryInfo = $this._serviceFactories[$key]
            $list.Add([pscustomobject]@{
                Name = $key
                Type = 'Factory'
                Initialized = ($null -ne $factoryInfo.Instance)
                Lifestyle = if ($factoryInfo.IsSingleton) { 'Singleton' } else { 'Transient' }
            })
        }
        
        return $list.ToArray() | Sort-Object Name
    }

    [void] Cleanup() {
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "ServiceContainer cleanup initiated."
        }
        Write-Verbose "ServiceContainer: Initiating cleanup of disposable singleton services."
        
        $instancesToClean = [System.Collections.Generic.List[object]]::new()
        $this._services.Values | ForEach-Object { $instancesToClean.Add($_) }
        $this._serviceFactories.Values | Where-Object { $_.IsSingleton -and $_.Instance } | ForEach-Object { $instancesToClean.Add($_.Instance) }

        foreach ($service in $instancesToClean) {
            if ($service -is [System.IDisposable]) {
                try {
                    Write-Verbose "ServiceContainer: Disposing service of type '$($service.GetType().FullName)'."
                    $service.Dispose()
                } catch {
                    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                        Write-Log -Level Error -Message "Error disposing service of type '$($service.GetType().FullName)': $($_.Exception.Message)"
                    }
                }
            }
        }
        
        $this._services.Clear()
        $this._serviceFactories.Clear()
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Info -Message "ServiceContainer cleanup complete."
        }
        Write-Verbose "ServiceContainer: Cleanup complete. All service registries cleared."
    }

    hidden [object] _InitializeServiceFromFactory([string]$name, [System.Collections.Generic.HashSet[string]]$resolutionChain) {
        $factoryInfo = $this._serviceFactories[$name]
        
        if ($factoryInfo.IsSingleton -and $null -ne $factoryInfo.Instance) {
            Write-Verbose "ServiceContainer: Returning cached singleton instance of '$name'."
            return $factoryInfo.Instance
        }

        if ($resolutionChain.Contains($name)) {
            $chain = ($resolutionChain -join ' -> ') + " -> $name"
            throw [System.InvalidOperationException]::new("Circular dependency detected while resolving service '$name'. Chain: $chain")
        }
        [void]$resolutionChain.Add($name)
        
        if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
            Write-Log -Level Debug -Message "Instantiating service '$name' from factory."
        }
        Write-Verbose "ServiceContainer: Invoking factory to create instance of '$name'."
        
        $serviceInstance = & $factoryInfo.Factory $this

        if ($factoryInfo.IsSingleton) {
            $factoryInfo.Instance = $serviceInstance
            if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Debug -Message "Cached singleton instance of service '$name'."
            }
            Write-Verbose "ServiceContainer: Cached new singleton instance of '$name'."
        }

        [void]$resolutionChain.Remove($name)
        
        return $serviceInstance
    }
}
#endregion

#region CommandPalette Class
class CommandPalette : UIElement {
    hidden [object] $_actionService
    hidden [object] $_searchBox
    hidden [object[]] $_filteredActions
    hidden [object[]] $_allActions
    hidden [int] $_selectedIndex
    hidden [int] $_scrollOffset
    hidden [string] $_lastQuery

    CommandPalette([object]$actionService) : base("CommandPalette") {
        if (-not $actionService) {
            throw [System.ArgumentNullException]::new('actionService')
        }
        
        $this._actionService = $actionService
        $this._filteredActions = @()
        $this._allActions = @()
        $this._selectedIndex = 0
        $this._scrollOffset = 0
        $this._lastQuery = ""
        
        $this.IsFocusable = $true
        $this.Enabled = $true
        $this.Visible = $false
        $this.ZIndex = 1000
        
        Write-Verbose "CommandPalette: Constructor called"
    }

    [void] Initialize() {
        Write-Verbose "CommandPalette: Initialize called"
        
        $this._searchBox = New-TuiTextBox -Props @{
            Name = 'CommandPaletteSearch'
            Placeholder = "Type to search actions..."
            Width = 70
            Height = 3
        }
        
        $paletteInstance = $this
        $this._searchBox.OnChange = {
            param($NewValue)
            $paletteInstance._UpdateFilter($NewValue)
        }.GetNewClosure()
        
        $this.AddChild($this._searchBox)
        
        if (Get-Command 'Subscribe-Event' -ErrorAction SilentlyContinue) {
            Subscribe-Event -EventName "CommandPalette.Open" -Handler {
                [void]$paletteInstance.Show()
            }.GetNewClosure() -Source "CommandPalette"
        }
        
        Write-Verbose "CommandPalette: Initialization complete"
    }

    [void] Show() {
        try {
            Write-Log -Level Debug -Message "Opening Command Palette"
            
            $screenWidth = $global:TuiState.BufferWidth
            $screenHeight = $global:TuiState.BufferHeight
            
            $this.Width = [Math]::Min(80, ($screenWidth - 10))
            $this.Height = [Math]::Min(20, ($screenHeight - 6))
            $this.X = [Math]::Floor(($screenWidth - $this.Width) / 2)
            $this.Y = [Math]::Floor(($screenHeight - $this.Height) / 4)
            
            if ($null -eq $this._private_buffer -or $this._private_buffer.Width -ne $this.Width -or $this._private_buffer.Height -ne $this.Height) {
                $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
            }

            $this._searchBox.Move(2, 2)
            $this._searchBox.Resize(($this.Width - 4), 3)

            $this.Visible = $true
            $this._selectedIndex = 0
            $this._scrollOffset = 0
            $this._searchBox.Text = ""
            $this._lastQuery = ""

            $this._allActions = $this._actionService.GetAllActions()
            $this._filteredActions = $this._allActions
            
            Show-TuiOverlay -Element $this
            Set-ComponentFocus -Component $this._searchBox
            Request-TuiRefresh
            
            Write-Verbose "CommandPalette: Shown successfully"
        }
        catch {
            Write-Error "CommandPalette: Error showing palette: $($_.Exception.Message)"
        }
    }

    [void] Hide() {
        try {
            Write-Log -Level Debug -Message "Closing Command Palette"
            $this.Visible = $false
            Close-TopTuiOverlay
            if ($global:TuiState.FocusedComponent -eq $this._searchBox) { Set-ComponentFocus -Component $null }
            Request-TuiRefresh
            Write-Verbose "CommandPalette: Hidden successfully"
        }
        catch { Write-Error "CommandPalette: Error hiding palette: $($_.Exception.Message)" }
    }

    hidden [void] _UpdateFilter([string]$query) {
        try {
            $this._lastQuery = $query
            $this._selectedIndex = 0
            $this._scrollOffset = 0
            if ([string]::IsNullOrWhiteSpace($query)) {
                $this._filteredActions = $this._allActions
            } else {
                $this._filteredActions = $this._allActions | Where-Object { $_.Name -like "*$query*" -or $_.Description -like "*$query*" }
            }
            $this.RequestRedraw()
            Write-Verbose "CommandPalette: Filter updated, $($this._filteredActions.Count) results"
        }
        catch { Write-Error "CommandPalette: Error updating filter: $($_.Exception.Message)" }
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor 'Background'
            $borderColor = Get-ThemeColor 'Accent'
            $fgColor = Get-ThemeColor 'Foreground'
            $selectionBg = Get-ThemeColor 'Selection'
            $selectionFg = Get-ThemeColor 'Background'
            $subtleColor = Get-ThemeColor 'Subtle'
            
            $clearCell = [TuiCell]::new(' ', $fgColor, $bgColor)
            $clearCell.ZIndex = 100
            $this._private_buffer.Clear($clearCell)
            
            $title = " Command Palette ($($this._filteredActions.Count)) "
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -Title $title -BorderStyle "Double" -BorderColor $borderColor -BackgroundColor $bgColor

            $helpText = " [↑↓] Navigate | [Enter] Execute | [Esc] Close "
            if ($helpText.Length -lt ($this.Width - 2)) {
                $helpX = $this.Width - $helpText.Length - 1
                Write-TuiText -Buffer $this._private_buffer -X $helpX -Y ($this.Height - 1) -Text $helpText -ForegroundColor $subtleColor -BackgroundColor $bgColor
            }

            $listY = 5
            $listHeight = $this.Height - 6
            
            for ($i = 0; $i -lt $listHeight; $i++) {
                $dataIndex = $i + $this._scrollOffset
                if ($dataIndex -ge $this._filteredActions.Count) { break }
                $action = $this._filteredActions[$dataIndex]
                $yPos = $listY + $i
                $isSelected = ($dataIndex -eq $this._selectedIndex)
                $itemBg = if ($isSelected) { $selectionBg } else { $bgColor }
                $itemFg = if ($isSelected) { $selectionFg } else { $fgColor }
                
                $highlightText = ' ' * ($this.Width - 2)
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y $yPos -Text $highlightText -ForegroundColor $itemFg -BackgroundColor $itemBg

                $displayText = " $($action.Name)"
                if ($action.Description) { $displayText += ": $($action.Description)" }
                
                $maxWidth = $this.Width - 4
                if ($displayText.Length -gt $maxWidth) { $displayText = $displayText.Substring(0, $maxWidth - 3) + "..." }
                
                Write-TuiText -Buffer $this._private_buffer -X 2 -Y $yPos -Text $displayText -ForegroundColor $itemFg -BackgroundColor $itemBg
            }

            if ($this._filteredActions.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($this._lastQuery)) {
                $noResultsText = "No actions match '$($this._lastQuery)'"
                $centerX = [Math]::Floor(($this.Width - $noResultsText.Length) / 2)
                $centerY = [Math]::Floor($this.Height / 2)
                Write-TuiText -Buffer $this._private_buffer -X $centerX -Y $centerY -Text $noResultsText -ForegroundColor $subtleColor -BackgroundColor $bgColor
            }
            Write-Verbose "CommandPalette: Rendered successfully"
        }
        catch { Write-Error "CommandPalette: Error during render: $($_.Exception.Message)" }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if (-not $this.Visible) { return $false }
        if ($null -eq $keyInfo) { return $false }
        
        try {
            if ($this._searchBox.IsFocused) {
                switch ($keyInfo.Key) {
                    { $_ -in @([ConsoleKey]::UpArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::PageUp, [ConsoleKey]::PageDown, [ConsoleKey]::Home, [ConsoleKey]::End, [ConsoleKey]::Enter, [ConsoleKey]::Escape) } {
                        # Swallow navigation keys
                    }
                    default {
                        if ($this._searchBox.HandleInput($keyInfo)) {
                            return $true
                        }
                    }
                }
            }
            
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Escape) { $this.Hide(); return $true }
                ([ConsoleKey]::Enter) {
                    if ($this._filteredActions.Count -gt 0 -and $this._selectedIndex -lt $this._filteredActions.Count) {
                        $action = $this._filteredActions[$this._selectedIndex]
                        $this.Hide()
                        try {
                            $this._actionService.ExecuteAction($action.Name)
                            Write-Log -Level Info -Message "Executed action: $($action.Name)"
                        }
                        catch {
                            Write-Error "Failed to execute action '$($action.Name)': $($_.Exception.Message)"
                            if (Get-Command Show-AlertDialog -ErrorAction SilentlyContinue) { Show-AlertDialog -Title "Action Failed" -Message "Failed to execute action: $($_.Exception.Message)" }
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this._selectedIndex -gt 0) {
                        $this._selectedIndex--
                        $this._EnsureSelectedVisible()
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this._selectedIndex -lt ($this._filteredActions.Count - 1)) {
                        $this._selectedIndex++
                        $this._EnsureSelectedVisible()
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::PageUp) {
                    $pageSize = $this.Height - 6
                    $this._selectedIndex = [Math]::Max(0, ($this._selectedIndex - $pageSize))
                    $this._EnsureSelectedVisible()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::PageDown) {
                    $pageSize = $this.Height - 6
                    $this._selectedIndex = [Math]::Min(($this._filteredActions.Count - 1), ($this._selectedIndex + $pageSize))
                    $this._EnsureSelectedVisible()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $this._selectedIndex = 0
                    $this._EnsureSelectedVisible()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::End) {
                    $this._selectedIndex = $this._filteredActions.Count - 1
                    $this._EnsureSelectedVisible()
                    $this.RequestRedraw()
                    return $true
                }
            }
            return $false
        }
        catch {
            Write-Error "CommandPalette: Error handling input: $($_.Exception.Message)"
            return $false
        }
    }
    
    hidden [void] _EnsureSelectedVisible() {
        $listHeight = $this.Height - 6
        if ($this._selectedIndex -lt $this._scrollOffset) { $this._scrollOffset = $this._selectedIndex }
        elseif ($this._selectedIndex -ge ($this._scrollOffset + $listHeight)) { $this._scrollOffset = $this._selectedIndex - $listHeight + 1 }
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
    }

    [string] ToString() {
        return "CommandPalette(Name='$($this.Name)', Actions=$($this._allActions.Count), Filtered=$($this._filteredActions.Count), Selected=$($this._selectedIndex))"
    }
}
#endregion

#region TUI Component Classes
class LabelComponent : UIElement {
    [string]$Text = ""
    [object]$ForegroundColor

    LabelComponent([string]$name) : base($name) {
        $this.IsFocusable = $false
        $this.Width = 10
        $this.Height = 1
        Write-Verbose "LabelComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = $this.ForegroundColor ?? (Get-ThemeColor 'Foreground')
            $bg = Get-ThemeColor 'Background'
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $this.Text -ForegroundColor $fg -BackgroundColor $bg
            Write-Verbose "LabelComponent '$($this.Name)': Rendered text '$($this.Text)'"
        }
        catch {
            Write-Error "LabelComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $false
    }

    [string] ToString() {
        return "LabelComponent(Name='$($this.Name)', Text='$($this.Text)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

class ButtonComponent : UIElement {
    [string]$Text = "Button"
    [bool]$IsPressed = $false
    [scriptblock]$OnClick

    ButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 10
        $this.Height = 3
        Write-Verbose "ButtonComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $state = if ($this.IsPressed) { "pressed" } elseif ($this.IsFocused) { "focus" } else { "normal" }
            
            $bgColor = Get-ThemeColor "button.$state.background"
            $borderColor = Get-ThemeColor "button.$state.border"
            $fgColor = Get-ThemeColor "button.$state.foreground"
            
            if (-not $bgColor) {
                $bgColor = if ($this.IsPressed) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Background' }
            }
            if (-not $borderColor) {
                $borderColor = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Border' }
            }
            if (-not $fgColor) {
                $fgColor = if ($this.IsPressed) { Get-ThemeColor 'Background' } else { Get-ThemeColor 'Foreground' }
            }

            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor
            
            $textX = [Math]::Floor(($this.Width - $this.Text.Length) / 2)
            $textY = [Math]::Floor(($this.Height - 1) / 2)
            Write-TuiText -Buffer $this._private_buffer -X $textX -Y $textY -Text $this.Text -ForegroundColor $fgColor -BackgroundColor $bgColor
            
            Write-Verbose "ButtonComponent '$($this.Name)': Rendered in state '$state'"
        }
        catch {
            Write-Error "ButtonComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            try {
                $this.IsPressed = $true
                $this.RequestRedraw()
                
                if ($this.OnClick) {
                    try {
                        & $this.OnClick
                    } catch {
                        Write-Error "ButtonComponent '$($this.Name)': Error in OnClick handler: $($_.Exception.Message)"
                    }
                }
                
                Start-Sleep -Milliseconds 50
                $this.IsPressed = $false
                $this.RequestRedraw()
                
                Write-Verbose "ButtonComponent '$($this.Name)': Click event handled"
                return $true
            }
            catch {
                Write-Error "ButtonComponent '$($this.Name)': Error handling click: $($_.Exception.Message)"
                $this.IsPressed = $false
                $this.RequestRedraw()
            }
        }
        return $false
    }

    [string] ToString() {
        return "ButtonComponent(Name='$($this.Name)', Text='$($this.Text)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

class TextBoxComponent : UIElement {
    [string]$Text = ""
    [string]$Placeholder = ""
    [ValidateRange(1, [int]::MaxValue)][int]$MaxLength = 100
    [int]$CursorPosition = 0
    [scriptblock]$OnChange
    hidden [int]$_scrollOffset = 0

    TextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 3
        Write-Verbose "TextBoxComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor 'Background'
            $borderColor = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Border' }
            $textColor = Get-ThemeColor 'Foreground'
            $placeholderColor = Get-ThemeColor 'Subtle'
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $textColor, $bgColor))
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor $bgColor

            $textAreaWidth = $this.Width - 2
            $displayText = $this.Text ?? ""
            $currentTextColor = $textColor

            if ([string]::IsNullOrEmpty($displayText) -and -not $this.IsFocused) {
                $displayText = $this.Placeholder ?? ""
                $currentTextColor = $placeholderColor
            }

            if ($displayText.Length -gt $textAreaWidth) {
                $displayText = $displayText.Substring($this._scrollOffset, [Math]::Min($textAreaWidth, $displayText.Length - $this._scrollOffset))
            }

            if (-not [string]::IsNullOrEmpty($displayText)) {
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $displayText -ForegroundColor $currentTextColor -BackgroundColor $bgColor
            }

            if ($this.IsFocused) {
                $cursorX = 1 + ($this.CursorPosition - $this._scrollOffset)
                if ($cursorX -ge 1 -and $cursorX -lt ($this.Width - 1)) {
                    $cell = $this._private_buffer.GetCell($cursorX, 1)
                    if ($null -ne $cell) {
                        $cell.BackgroundColor = Get-ThemeColor 'Accent'
                        $cell.ForegroundColor = Get-ThemeColor 'Background'
                        $this._private_buffer.SetCell($cursorX, 1, $cell)
                    }
                }
            }
            
            Write-Verbose "TextBoxComponent '$($this.Name)': Rendered text (length: $($this.Text.Length), cursor: $($this.CursorPosition))"
        }
        catch {
            Write-Error "TextBoxComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        try {
            $currentText = $this.Text ?? ""
            $cursorPos = $this.CursorPosition
            $originalText = $currentText
            $handled = $true

            switch ($key.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($cursorPos -gt 0) {
                        $this.Text = $currentText.Remove($cursorPos - 1, 1)
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::Delete) {
                    if ($cursorPos -lt $currentText.Length) {
                        $this.Text = $currentText.Remove($cursorPos, 1)
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($cursorPos -gt 0) {
                        $this.CursorPosition--
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($cursorPos -lt $this.Text.Length) {
                        $this.CursorPosition++
                    }
                }
                ([ConsoleKey]::Home) {
                    $this.CursorPosition = 0
                }
                ([ConsoleKey]::End) {
                    $this.CursorPosition = $this.Text.Length
                }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar) -and $currentText.Length -lt $this.MaxLength) {
                        $this.Text = $currentText.Insert($cursorPos, $key.KeyChar)
                        $this.CursorPosition++
                    } else {
                        $handled = $false
                    }
                }
            }

            if ($handled) {
                $this._UpdateScrollOffset()
                
                if ($this.Text -ne $originalText -and $this.OnChange) {
                    try {
                        & $this.OnChange -NewValue $this.Text
                    } catch {
                        Write-Error "TextBoxComponent '$($this.Name)': Error in OnChange handler: $($_.Exception.Message)"
                    }
                }
                
                $this.RequestRedraw()
                Write-Verbose "TextBoxComponent '$($this.Name)': Input handled, new text: '$($this.Text)'"
            }
            
            return $handled
        }
        catch {
            Write-Error "TextBoxComponent '$($this.Name)': Error handling input: $($_.Exception.Message)"
            return $false
        }
    }

    hidden [void] _UpdateScrollOffset() {
        $textAreaWidth = $this.Width - 2
        
        if ($this.CursorPosition -gt ($this._scrollOffset + $textAreaWidth - 1)) {
            $this._scrollOffset = $this.CursorPosition - $textAreaWidth + 1
        }
        
        if ($this.CursorPosition -lt $this._scrollOffset) {
            $this._scrollOffset = $this.CursorPosition
        }
        
        $maxScroll = [Math]::Max(0, $this.Text.Length - $textAreaWidth)
        $this._scrollOffset = [Math]::Min($this._scrollOffset, $maxScroll)
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
    }

    [string] ToString() {
        return "TextBoxComponent(Name='$($this.Name)', Text='$($this.Text)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

class CheckBoxComponent : UIElement {
    [string]$Text = "Checkbox"
    [bool]$Checked = $false
    [scriptblock]$OnChange

    CheckBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
        Write-Verbose "CheckBoxComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Foreground' }
            $bg = Get-ThemeColor 'Background'
            
            $checkbox = if ($this.Checked) { "[X]" } else { "[ ]" }
            $displayText = "$checkbox $($this.Text)"
            
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg -BackgroundColor $bg
            Write-Verbose "CheckBoxComponent '$($this.Name)': Rendered (Checked: $($this.Checked))"
        }
        catch {
            Write-Error "CheckBoxComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            try {
                $this.Checked = -not $this.Checked
                
                if ($this.OnChange) {
                    try {
                        & $this.OnChange -NewValue $this.Checked
                    } catch {
                        Write-Error "CheckBoxComponent '$($this.Name)': Error in OnChange handler: $($_.Exception.Message)"
                    }
                }
                
                $this.RequestRedraw()
                Write-Verbose "CheckBoxComponent '$($this.Name)': State changed to $($this.Checked)"
                return $true
            }
            catch {
                Write-Error "CheckBoxComponent '$($this.Name)': Error handling toggle: $($_.Exception.Message)"
            }
        }
        return $false
    }

    [string] ToString() {
        return "CheckBoxComponent(Name='$($this.Name)', Text='$($this.Text)', Checked=$($this.Checked), Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

class RadioButtonComponent : UIElement {
    [string]$Text = "Option"
    [bool]$Selected = $false
    [string]$GroupName = ""
    [scriptblock]$OnChange

    RadioButtonComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 1
        Write-Verbose "RadioButtonComponent: Constructor called for '$($this.Name)'"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear()
            $fg = if ($this.IsFocused) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Foreground' }
            $bg = Get-ThemeColor 'Background'
            
            $radio = if ($this.Selected) { "(●)" } else { "( )" }
            $displayText = "$radio $($this.Text)"
            
            Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $displayText -ForegroundColor $fg -BackgroundColor $bg
            Write-Verbose "RadioButtonComponent '$($this.Name)': Rendered (Selected: $($this.Selected))"
        }
        catch {
            Write-Error "RadioButtonComponent '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            try {
                if (-not $this.Selected) {
                    $this.Selected = $true
                    
                    if ($this.Parent -and $this.GroupName) {
                        $this.Parent.Children | Where-Object { 
                            $_ -is [RadioButtonComponent] -and $_.GroupName -eq $this.GroupName -and $_ -ne $this 
                        } | ForEach-Object {
                            $_.Selected = $false
                            $_.RequestRedraw()
                        }
                    }
                    
                    if ($this.OnChange) {
                        try {
                            & $this.OnChange -NewValue $this.Selected
                        } catch {
                            Write-Error "RadioButtonComponent '$($this.Name)': Error in OnChange handler: $($_.Exception.Message)"
                        }
                    }
                    
                    $this.RequestRedraw()
                    Write-Verbose "RadioButtonComponent '$($this.Name)': Selected in group '$($this.GroupName)'"
                }
                return $true
            }
            catch {
                Write-Error "RadioButtonComponent '$($this.Name)': Error handling selection: $($_.Exception.Message)"
            }
        }
        return $false
    }

    [string] ToString() {
        return "RadioButtonComponent(Name='$($this.Name)', Text='$($this.Text)', Selected=$($this.Selected), Group='$($this.GroupName)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}
#endregion