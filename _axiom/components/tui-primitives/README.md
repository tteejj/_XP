# tui-primitives Module

## Overview
The `tui-primitives` module provides the foundational building blocks for the PMC Terminal TUI (Text User Interface) system. This is the lowest-level module in the AXIOM architecture with zero dependencies.

## Classes

### TuiAnsiHelper
Static helper class for ANSI escape code generation.

**Methods:**
- `GetForegroundCode([ConsoleColor]$color)` - Returns ANSI code for foreground color
- `GetBackgroundCode([ConsoleColor]$color)` - Returns ANSI code for background color
- `Reset()` - Returns ANSI reset code
- `Bold()` - Returns ANSI bold code
- `Underline()` - Returns ANSI underline code
- `Italic()` - Returns ANSI italic code

### TuiCell
Represents a single character cell in the terminal with styling information.

**Properties:**
- `[char] $Char` - The character to display
- `[ConsoleColor] $ForegroundColor` - Text color
- `[ConsoleColor] $BackgroundColor` - Background color
- `[bool] $Bold` - Bold text flag
- `[bool] $Underline` - Underline text flag
- `[bool] $Italic` - Italic text flag
- `[int] $ZIndex` - Layer index for compositing
- `[object] $Metadata` - Optional metadata

**Key Methods:**
- `WithStyle($fg, $bg)` - Create styled copy
- `WithChar($char)` - Create copy with different character
- `BlendWith($other)` - Blend with another cell (Z-order aware)
- `DiffersFrom($other)` - Check if different from another cell
- `ToAnsiString()` - Generate ANSI escape sequence

### TuiBuffer
2D array of TuiCell objects representing a drawable area.

**Properties:**
- `[int] $Width` - Buffer width
- `[int] $Height` - Buffer height
- `[string] $Name` - Buffer identifier
- `[bool] $IsDirty` - Changed flag

**Key Methods:**
- `Clear()` - Clear buffer
- `GetCell($x, $y)` - Get cell at position
- `SetCell($x, $y, $cell)` - Set cell at position
- `WriteString($x, $y, $text, $fg, $bg)` - Write text
- `BlendBuffer($other, $offsetX, $offsetY)` - Composite another buffer
- `GetSubBuffer($x, $y, $width, $height)` - Extract region
- `Resize($newWidth, $newHeight)` - Resize preserving content

## Functions

### Write-TuiText
Write text to a buffer at specified position with styling.

```powershell
Write-TuiText -Buffer $buffer -X 5 -Y 10 -Text "Hello" -ForegroundColor White -Bold
```

### Write-TuiBox
Draw a box with optional title.

```powershell
Write-TuiBox -Buffer $buffer -X 0 -Y 0 -Width 20 -Height 10 -BorderStyle "Double" -Title "My Box"
```

### Get-TuiBorderChars
Get border characters for different box styles (Single, Double, Rounded, Thick).

## Dependencies
None - This is the foundational module.

## Usage Example
```powershell
Import-Module tui-primitives

# Create a buffer
$buffer = [TuiBuffer]::new(80, 24, "Main")

# Write some text
Write-TuiText -Buffer $buffer -X 10 -Y 5 -Text "Hello World" -ForegroundColor Cyan

# Draw a box
Write-TuiBox -Buffer $buffer -X 5 -Y 3 -Width 30 -Height 10 -BorderStyle "Double"

# Access individual cells
$cell = $buffer.GetCell(10, 5)
Write-Host "Cell at (10,5): $($cell.Char)"
```
