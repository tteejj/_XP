# ==============================================================================
# Axiom-Phoenix v4.0 - Base Classes (Load First)
# Core framework classes with NO external dependencies
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ABC.###" to find specific sections.
# Each section ends with "END_PAGE: ABC.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Management.Automation
using namespace System.Threading

# Disable verbose output during TUI rendering
$script:TuiVerbosePreference = 'SilentlyContinue'

#<!-- PAGE: ABC.001 - TuiAnsiHelper Class -->
#region TuiAnsiHelper - ANSI Code Generation with Truecolor Support
class TuiAnsiHelper {
    # No caches needed, sequences are generated dynamically now.

    static [hashtable] HexToRgb([string]$hexColor) {
        if ([string]::IsNullOrEmpty($hexColor) -or -not $hexColor.StartsWith("#") -or $hexColor.Length -ne 7) {
            # Write-Log -Level Warning -Message "Invalid hex color format: '$hexColor'" # Use Write-Log
            return $null
        }
        try {
            return @{
                R = [System.Convert]::ToInt32($hexColor.Substring(1, 2), 16)
                G = [System.Convert]::ToInt32($hexColor.Substring(3, 2), 16)
                B = [System.Convert]::ToInt32($hexColor.Substring(5, 2), 16)
            }
        } catch {
            # Write-Log -Level Warning -Message "Error parsing hex color '$hexColor': $($_.Exception.Message)" -Data $_
            return $null
        }
    }

    static [string] GetAnsiSequence([string]$fgHex, [string]$bgHex, [hashtable]$attributes) {
        $sequences = [System.Collections.Generic.List[string]]::new()

        # Foreground color (Truecolor - SGR 38;2)
        if (-not [string]::IsNullOrEmpty($fgHex)) {
            $rgb = [TuiAnsiHelper]::HexToRgb($fgHex)
            if ($rgb) {
                $sequences.Add("38;2;$($rgb.R);$($rgb.G);$($rgb.B)")
            }
        }

        # Background color (Truecolor - SGR 48;2)
        if (-not [string]::IsNullOrEmpty($bgHex)) {
            $rgb = [TuiAnsiHelper]::HexToRgb($bgHex)
            if ($rgb) {
                $sequences.Add("48;2;$($rgb.R);$($rgb.G);$($rgb.B)")
            }
        }

        # Style attributes
        if ($attributes) {
            if ($attributes.ContainsKey('Bold') -and [bool]$attributes['Bold']) { $sequences.Add("1") }
            if ($attributes.ContainsKey('Italic') -and [bool]$attributes['Italic']) { $sequences.Add("3") }
            if ($attributes.ContainsKey('Underline') -and [bool]$attributes['Underline']) { $sequences.Add("4") }
            if ($attributes.ContainsKey('Strikethrough') -and [bool]$attributes['Strikethrough']) { $sequences.Add("9") }
        }

        if ($sequences.Count -eq 0) { return "" }
        return "`e[$($sequences -join ';')m"
    }

    static [string] Reset() { return "`e[0m" }
}
#endregion
#<!-- END_PAGE: ABC.001 -->

#<!-- PAGE: ABC.002 - TuiCell Class -->
#region TuiCell Class - Core Compositor Unit with Truecolor Support
class TuiCell {
    [char] $Char = ' '
    [string] $ForegroundColor = "#FFFFFF" # Changed to string for hex color
    [string] $BackgroundColor = "#000000" # Changed to string for hex color
    [bool] $Bold = $false
    [bool] $Underline = $false
    [bool] $Italic = $false
    [bool] $Strikethrough = $false # NEW Property for additional style
    [int] $ZIndex = 0        
    [object] $Metadata = $null 

    TuiCell() { }
    TuiCell([char]$char) { $this.Char = $char }
    
    # Constructor with 3 parameters (char, fg, bg)
    TuiCell([char]$char, [string]$fg, [string]$bg) {
        $this.Char = $char
        $this.ForegroundColor = $fg
        $this.BackgroundColor = $bg
    }
    
    # Full constructor with all parameters
    TuiCell([char]$char, [string]$fg, [string]$bg, [bool]$bold, [bool]$italic, [bool]$underline, [bool]$strikethrough) {
        $this.Char = $char
        $this.ForegroundColor = $fg
        $this.BackgroundColor = $bg
        $this.Bold = $bold
        $this.Italic = $italic
        $this.Underline = $underline
        $this.Strikethrough = $strikethrough # Assign new property
    }
    
    # Copy Constructor: Ensure it copies all new properties
    TuiCell([object]$other) {
        $this.Char = $other.Char
        $this.ForegroundColor = $other.ForegroundColor
        $this.BackgroundColor = $other.BackgroundColor
        $this.Bold = $other.Bold
        $this.Underline = $other.Underline
        $this.Italic = $other.Italic
        $this.Strikethrough = $other.Strikethrough # Make sure this is copied
        $this.ZIndex = $other.ZIndex
        $this.Metadata = $other.Metadata
    }

    [TuiCell] WithStyle([string]$fg, [string]$bg) { # Parameter types changed
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
        
        # If Z-Indexes are different, the higher one wins.
        if ($other.ZIndex -gt $this.ZIndex) { return [TuiCell]::new($other) }
        if ($other.ZIndex -lt $this.ZIndex) { return $this }

        # If Z-Indexes are the same, the 'other' (top) cell wins by default.
        # This is the most common and intuitive blending mode.
        # A more advanced system could check for a special transparent color.
        return [TuiCell]::new($other)
    }

    [bool] DiffersFrom([object]$other) {
        if ($null -eq $other) { return $true }
        
        return ($this.Char -ne $other.Char -or 
                $this.ForegroundColor -ne $other.ForegroundColor -or 
                $this.BackgroundColor -ne $other.BackgroundColor -or
                $this.Bold -ne $other.Bold -or
                $this.Underline -ne $other.Underline -or
                $this.Italic -ne $other.Italic -or
                $this.Strikethrough -ne $other.Strikethrough -or # NEW: Compare Strikethrough
                $this.ZIndex -ne $other.ZIndex)
    }

    [string] ToAnsiString() {
        # This is the crucial update to use the new TuiAnsiHelper.GetAnsiSequence
        $attributes = @{ 
            Bold=$this.Bold; Italic=$this.Italic; Underline=$this.Underline; Strikethrough=$this.Strikethrough 
        }
        $sequence = [TuiAnsiHelper]::GetAnsiSequence($this.ForegroundColor, $this.BackgroundColor, $attributes)
        return "$sequence$($this.Char)" # Append character directly
    }

    [hashtable] ToLegacyFormat() {
        return @{ Char = $this.Char; FG = $this.ForegroundColor; BG = $this.BackgroundColor }
    }
    
    [string] ToString() {
        return "TuiCell(Char='$($this.Char)', FG='$($this.ForegroundColor)', BG='$($this.BackgroundColor)', Bold=$($this.Bold), Underline=$($this.Underline), Italic=$($this.Italic), Strikethrough=$($this.Strikethrough), ZIndex=$($this.ZIndex))"
    }
}
#endregion
#<!-- END_PAGE: ABC.002 -->

#<!-- PAGE: ABC.003 - TuiBuffer Class -->
#region TuiBuffer Class - 2D Array of TuiCells
class TuiBuffer {
    $Cells       # 2D array of TuiCells - no type constraint to avoid assignment issues
    [int] $Width             
    [int] $Height            
    [string] $Name            
    [bool] $IsDirty = $true  

    # Constructor with 2 parameters
    TuiBuffer([int]$width, [int]$height) {
        if ($width -le 0) { throw [System.ArgumentOutOfRangeException]::new("width", "Width must be positive.") }
        if ($height -le 0) { throw [System.ArgumentOutOfRangeException]::new("height", "Height must be positive.") }
        $this.Width = $width
        $this.Height = $height
        $this.Name = "Unnamed"
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
        # Initialize cells in a simple way
        $this.InitializeCells()
        # Write-Verbose "TuiBuffer '$($this.Name)' initialized with dimensions: $($this.Width)x$($this.Height)."
    }

    hidden [void] InitializeCells() {
        # Create 2D array step by step to avoid assignment issues
        $tempArray = New-Object 'System.Object[,]' $this.Height,$this.Width
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $tempArray[$y,$x] = [TuiCell]::new()
            }
        }
        $this.Cells = $tempArray
    }

    [void] Clear() { $this.Clear([TuiCell]::new()) }

    [void] Clear([TuiCell]$fillCell) {
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.Cells[$y, $x] = [TuiCell]::new($fillCell) 
            }
        }
        $this.IsDirty = $true
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
        } else {
            # Write-Warning "Attempted to set cell out of bounds in TuiBuffer '$($this.Name)': ($x, $y) is outside 0..$($this.Width-1), 0..$($this.Height-1). Cell: '$($cell.Char)'."
        }
    }

    [void] WriteString([int]$x, [int]$y, [string]$text, [hashtable]$style = @{}) {
        if ([string]::IsNullOrEmpty($text) -or $y -lt 0 -or $y -ge $this.Height) {
            # Write-Log -Level Debug -Message "WriteString: Skipped for buffer '$($this.Name)' due to empty text or out-of-bounds Y."
            return
        }
        
        # Extract properties from the style object, providing safe defaults (now expecting hex colors)
        # Use hashtable indexing syntax to avoid "property not found" errors
        $fg = if ($style.ContainsKey('FG')) { $style['FG'] } else { "#FFFFFF" } # Default Foreground hex
        $bg = if ($style.ContainsKey('BG')) { $style['BG'] } else { "#000000" } # Default Background hex
        $bold = if ($style.ContainsKey('Bold')) { [bool]$style['Bold'] } else { $false }
        $italic = if ($style.ContainsKey('Italic')) { [bool]$style['Italic'] } else { $false }
        $underline = if ($style.ContainsKey('Underline')) { [bool]$style['Underline'] } else { $false }
        $strikethrough = if ($style.ContainsKey('Strikethrough')) { [bool]$style['Strikethrough'] } else { $false }
        $zIndex = if ($style.ContainsKey('ZIndex')) { [int]$style['ZIndex'] } else { 0 }

        $currentX = $x
        foreach ($char in $text.ToCharArray()) {
            if ($currentX -ge $this.Width) { break } 
            if ($currentX -ge 0) {
                # Pass all style parameters to TuiCell constructor
                $cell = [TuiCell]::new($char, $fg, $bg, $bold, $italic, $underline, $strikethrough)
                $cell.ZIndex = $zIndex # Assign ZIndex
                $this.SetCell($currentX, $y, $cell)
            }
            $currentX++
        }
        $this.IsDirty = $true
        # Write-Log -Level Debug -Message "WriteString: Wrote '$text' to buffer '$($this.Name)' at ($x, $y)."
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
        # Write-Verbose "BlendBuffer: Blended buffer '$($other.Name)' onto '$($this.Name)' at ($offsetX, $offsetY)."
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
        if ($newWidth -le 0) { throw [System.ArgumentOutOfRangeException]::new("newWidth", "New width must be positive.") }
        if ($newHeight -le 0) { throw [System.ArgumentOutOfRangeException]::new("newHeight", "New height must be positive.") }
        $oldCells = $this.Cells
        $oldWidth = $this.Width
        $oldHeight = $this.Height
        $this.Width = $newWidth
        $this.Height = $newHeight
        # Create new 2D array using helper method
        $this.InitializeCells()
        $copyWidth = [Math]::Min($oldWidth, $newWidth)
        $copyHeight = [Math]::Min($oldHeight, $newHeight)
        for ($y = 0; $y -lt $copyHeight; $y++) {
            for ($x = 0; $x -lt $copyWidth; $x++) {
                $this.Cells[$y, $x] = $oldCells[$y, $x]
            }
        }
        $this.IsDirty = $true
        # Write-Verbose "TuiBuffer '$($this.Name)' resized from $($oldWidth)x$($oldHeight) to $($newWidth)x$($newHeight)."
    }

    [string] ToString() {
        return "TuiBuffer(Name='$($this.Name)', Width=$($this.Width), Height=$($this.Height), IsDirty=$($this.IsDirty))"
    }

    # Additional helper methods needed by rendering pipeline
    [void] DrawText([int]$x, [int]$y, [string]$text, [hashtable]$style = @{}) {
        $this.WriteString($x, $y, $text, $style)
    }
    
    [void] DrawBox([int]$x, [int]$y, [int]$width, [int]$height, [hashtable]$style = @{}) {
        # This will now internally call the new Write-TuiBox function in AllFunctions.ps1
        # It's better to delegate complex drawing like boxes to the global functions.
        Write-TuiBox -Buffer $this -X $x -Y $y -Width $width -Height $height -Style $style
    }
    
    [void] FillRect([int]$x, [int]$y, [int]$width, [int]$height, [char]$char, [hashtable]$style = @{}) {
        # Create a single character string and use WriteString to fill the rectangle
        # This simplifies the logic by leveraging WriteString's styling capabilities.
        $charString = "$char" # Convert char to string
        for ($py = $y; $py -lt $y + $height; $py++) {
            # Write a line of characters
            $this.WriteString($x, $py, $charString * $width, $style)
        }
    }
    
    [TuiBuffer] Clone() {
        $clone = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name)_Clone")
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $clone.Cells[$y, $x] = [TuiCell]::new($this.Cells[$y, $x])
            }
        }
        return $clone
    }
}
#endregion
#<!-- END_PAGE: ABC.003 -->

#<!-- PAGE: ABC.004 - UIElement Class -->
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
    [bool] $IsOverlay = $false
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
        # Write-Verbose "UIElement 'Unnamed' created with default size ($($this.Width)x$($this.Height))."
    }

    UIElement([string]$name) {
        $this.Name = $name
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
        $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        # Write-Verbose "UIElement '$($this.Name)' created with default size ($($this.Width)x$($this.Height))."
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
        # Write-Verbose "UIElement 'Unnamed' created at ($x, $y) with dimensions $($width)x$($height)."
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
            
            # Call the lifecycle hook if the child has it defined
            if ($child.PSObject.Methods['AddedToParent']) {
                try {
                    $child.AddedToParent()
                }
                catch {
                    Write-Warning "Error calling AddedToParent on child '$($child.Name)': $($_.Exception.Message)"
                }
            }
            
            $this.RequestRedraw()
            # Write-Verbose "Added child '$($child.Name)' to parent '$($this.Name)'."
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
                
                # Call the lifecycle hook if the child has it defined
                if ($child.PSObject.Methods['RemovedFromParent']) {
                    try {
                        $child.RemovedFromParent()
                    }
                    catch {
                        Write-Warning "Error calling RemovedFromParent on child '$($child.Name)': $($_.Exception.Message)"
                    }
                }
                
                $this.RequestRedraw()
                # Write-Verbose "Removed child '$($child.Name)' from parent '$($this.Name)'."
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
        # Write-Verbose "Redraw requested for '$($this.Name)'."
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
                # Write-Verbose "Re-initialized buffer for '$($this.Name)' due to null buffer."
            }
            $this.RequestRedraw()
            $this.OnResize($newWidth, $newHeight)
            # Write-Verbose "Component '$($this.Name)' resized to $($newWidth)x$($newHeight)."
        }
        catch {
            Write-Error "Failed to resize component '$($this.Name)' to $($newWidth)x$($newHeight): $($_.Exception.Message)"
            throw
        }
    }

    [void] Move([int]$newX, [int]$newY) {
        if ($this.X -eq $newX -and $this.Y -eq $newY) {
            # Write-Verbose "Move: Component '$($this.Name)' already at target position ($($newX), $($newY)). No change."
            return
        }
        $this.X = $newX
        $this.Y = $newY
        $this.RequestRedraw()
        $this.OnMove($newX, $newY)
        # Write-Verbose "Component '$($this.Name)' moved to ($newX, $newY)."
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

    [void] OnRender() 
    {
        if ($null -ne $this._private_buffer) {
            $this._private_buffer.Clear()
        }
        # Write-Verbose "OnRender called for '$($this.Name)': Default buffer clear."
    }

    [void] OnResize([int]$newWidth, [int]$newHeight) 
    {
        # Write-Verbose "OnResize called for '$($this.Name)': No custom resize logic."
    }

    [void] OnMove([int]$newX, [int]$newY) 
    {
        # Write-Verbose "OnMove called for '$($this.Name)': No custom move logic."
    }

    [void] OnFocus() 
    { 
        # Write-Verbose "OnFocus called for '$($this.Name)'." 
    }
    
    [void] OnBlur() 
    { 
        # Write-Verbose "OnBlur called for '$($this.Name)'." 
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) 
    {
        # Write-Verbose "HandleInput called for '$($this.Name)': Key: $($keyInfo.Key)."
        return $false
    }

    [void] Cleanup()
    {
        # Cleanup all children recursively
        foreach ($child in $this.Children) {
            if ($child.PSObject.Methods['Cleanup']) {
                try { 
                    $child.Cleanup() 
                } 
                catch { 
                    Write-Warning "Failed to cleanup child '$($child.Name)': $($_.Exception.Message)" 
                }
            }
        }
        
        # Clear references
        $this.Children.Clear()
        $this.Parent = $null
        $this._private_buffer = $null
        
        # Write-Verbose "Cleanup completed for UIElement '$($this.Name)'."
    }

    [void] Render() 
    {
        if (-not $this.Visible) { 
            # Write-Verbose "Skipping Render for '$($this.Name)': Not visible."
            return 
        }
        $this._RenderContent() 
    }

    hidden [void] _RenderContent() 
    {
        if (-not $this.Visible) { return }
        if ($this._needs_redraw -or ($null -eq $this._private_buffer)) {
            if ($null -eq $this._private_buffer -or $this._private_buffer.Width -ne $this.Width -or $this._private_buffer.Height -ne $this.Height) {
                $bufferWidth = [Math]::Max(1, $this.Width)
                $bufferHeight = [Math]::Max(1, $this.Height)
                $this._private_buffer = [TuiBuffer]::new($bufferWidth, $bufferHeight, "$($this.Name).Buffer")
                # Write-Verbose "Re-initialized buffer for '$($this.Name)' due to null or dimension mismatch ($($bufferWidth)x$($bufferHeight))."
            }
            $this.OnRender()
            $this._needs_redraw = $false
            # Write-Verbose "Rendered own content for '$($this.Name)'."
        }
        foreach ($child in $this.Children | Sort-Object ZIndex) { 
            if ($child.Visible) {
                $child.Render()
                if ($null -ne $child._private_buffer) {
                    $this._private_buffer.BlendBuffer($child._private_buffer, $child.X, $child.Y)
                    # Write-Verbose "Blended child '$($child.Name)' onto '$($this.Name)' at ($($child.X), $($child.Y))."
                }
            }
        }
    }

    [object] GetBuffer() 
    { 
        return $this._private_buffer 
    }
    
    [string] ToString() 
    {
        return "$($this.GetType().Name)(Name='$($this.Name)', X=$($this.X), Y=$($this.Y), Width=$($this.Width), Height=$($this.Height), Visible=$($this.Visible))"
    }
}
#endregion
#<!-- END_PAGE: ABC.004 -->

#<!-- PAGE: ABC.005 - Component Class -->
#region Component - A generic container component
class Component : UIElement {
    Component([string]$name) : base($name) {
        $this.Name = $name
        # Write-Verbose "Component '$($this.Name)' created."
    }

    hidden [void] _RenderContent() {
        ([UIElement]$this)._RenderContent()
        # Write-Verbose "_RenderContent called for Component '$($this.Name)' (delegating to base UIElement)."
    }

    [string] ToString() {
        return "Component(Name='$($this.Name)', Children=$($this.Children.Count))"
    }
}
#endregion
#<!-- END_PAGE: ABC.005 -->

#<!-- PAGE: ABC.006 - Screen Class -->
#region Screen - Top-level Container for Application Views
class Screen : UIElement {
    [hashtable]$Services
    [object]$ServiceContainer 
    [System.Collections.Generic.Dictionary[string, object]]$State
    [System.Collections.Generic.List[UIElement]] $Panels
    
    $LastFocusedComponent
    
    hidden [bool] $_isInitialized = $false
    hidden [System.Collections.Generic.Dictionary[string, string]] $EventSubscriptions 

    Screen([string]$name, [hashtable]$services) : base($name) {
        $this.Services = $services
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        $this.ServiceContainer = $null
        # Write-Verbose "Screen '$($this.Name)' created with hashtable services."
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
                # Write-Verbose "Screen '$($this.Name)' populated Services hashtable from ServiceContainer."
            } catch {
                Write-Warning "Screen '$($this.Name)': Failed to enumerate services from container: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Screen '$($this.Name)' received a non-ServiceContainer object for DI. Services hashtable might be incomplete or inaccurate."
        }
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[UIElement]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.Dictionary[string, string]]::new()
        # Write-Verbose "Screen '$($this.Name)' created with ServiceContainer."
    }

    [void] Initialize() { 
        # Write-Verbose "Initialize called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnEnter() { 
        # Write-Verbose "OnEnter called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnExit() { 
        # Write-Verbose "OnExit called for Screen '$($this.Name)': Default (no-op)." 
    }
    [void] OnResume() { 
        # Write-Verbose "OnResume called for Screen '$($this.Name)': Default (no-op)." 
    }

    [void] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Write-Verbose "HandleInput called for Screen '$($this.Name)': Key: $($keyInfo.Key). Default (no-op)."
    }

    [void] HandleKeyPress([System.ConsoleKeyInfo]$keyInfo) {
        $this.HandleInput($keyInfo)
    }

    [void] HandleResize([int]$newWidth, [int]$newHeight) {
        $this.Resize($newWidth, $newHeight)
    }

    [void] Cleanup() {
        try {
            # Write-Verbose "Cleanup called for Screen '$($this.Name)'."
            
            # Screen-specific cleanup: Unsubscribe from events
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
            
            # Clear screen-specific collections
            $this.Panels.Clear()
            $this.State.Clear()
            
            # Call base UIElement cleanup (handles children recursively)
            ([UIElement]$this).Cleanup()
            
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
        $panelCount = if ($this.Panels) { $this.Panels.Count } else { 0 }
        return "Screen(Name='$($this.Name)', Panels=$panelCount, Visible=$($this.Visible))"
    }

    [void] Render([TuiBuffer]$buffer) {
        # First render self
        $this._RenderContent()
        
        # Then blend our buffer onto the target
        if ($null -ne $this._private_buffer) {
            $buffer.BlendBuffer($this._private_buffer, 0, 0)
        }
    }
}
#endregion
#<!-- END_PAGE: ABC.006 -->

#<!-- PAGE: ABC.007 - ServiceContainer Class -->
#region ServiceContainer Class
class ServiceContainer {
    hidden [hashtable] $_services = @{}
    hidden [hashtable] $_serviceFactories = @{}

    ServiceContainer() {
        # Don't use Write-Log during construction - Logger doesn't exist yet
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
#<!-- END_PAGE: ABC.007 -->
