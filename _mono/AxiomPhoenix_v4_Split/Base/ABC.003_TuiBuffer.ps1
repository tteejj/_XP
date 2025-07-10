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
            Write-Log -Level Warning -Message "Attempted to set cell out of bounds in TuiBuffer '$($this.Name)': ($x, $y) is outside 0..$($this.Width-1), 0..$($this.Height-1). Cell: '$($cell.Char)'."
        }
    }

    [void] WriteString([int]$x, [int]$y, [string]$text, [hashtable]$style = @{}) {
        if ([string]::IsNullOrEmpty($text) -or $y -lt 0 -or $y -ge $this.Height) {
            Write-Log -Level Debug -Message "WriteString: Skipped for buffer '$($this.Name)' due to empty text or out-of-bounds Y."
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
        Write-Log -Level Debug -Message "WriteString: Wrote '$text' to buffer '$($this.Name)' at ($x, $y)."
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
