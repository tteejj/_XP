# ==============================================================================
# Axiom-Phoenix v4.0 - All Components
# UI components that extend UIElement - full implementations from axiom
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ACO.###" to find specific sections.
# Each section ends with "END_PAGE: ACO.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#

# ===== CLASS: MultilineTextBoxComponent =====
# Module: advanced-input-components
# Dependencies: UIElement, TuiCell
# Purpose: Full text editor with scrolling
class MultilineTextBoxComponent : UIElement {
    [List[string]]$Lines
    [int]$CursorLine = 0
    [int]$CursorColumn = 0
    [int]$ScrollOffsetY = 0
    [int]$ScrollOffsetX = 0
    [bool]$ReadOnly = $false
    [scriptblock]$OnChange
    
    MultilineTextBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.TabIndex = 0
        $this.Lines = [List[string]]::new()
        $this.Lines.Add("")
        $this.Width = 40
        $this.Height = 10
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Get theme-aware colors, using component properties as defaults if not found in theme
            $bgColor = Get-ThemeColor -ColorName "input.background" -DefaultColor $this.BackgroundColor
            $fgColor = Get-ThemeColor -ColorName "input.foreground" -DefaultColor $this.ForegroundColor
            $borderColorValue = Get-ThemeColor -ColorName "component.border" -DefaultColor $this.BorderColor
            if ($this.IsFocused) { $borderColorValue = Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF" }
            
            # Clear buffer with background color
            $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            
            # Draw border
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                -Width $this.Width -Height $this.Height `
                -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = "Single" }
            
            # Calculate visible area
            $contentWidth = $this.Width - 2
            $contentHeight = $this.Height - 2
            
            # Adjust scroll to keep cursor visible
            if ($this.CursorLine -lt $this.ScrollOffsetY) {
                $this.ScrollOffsetY = $this.CursorLine
            }
            elseif ($this.CursorLine -ge $this.ScrollOffsetY + $contentHeight) {
                $this.ScrollOffsetY = $this.CursorLine - $contentHeight + 1
            }
            
            if ($this.CursorColumn -lt $this.ScrollOffsetX) {
                $this.ScrollOffsetX = $this.CursorColumn
            }
            elseif ($this.CursorColumn -ge $this.ScrollOffsetX + $contentWidth) {
                $this.ScrollOffsetX = $this.CursorColumn - $contentWidth + 1
            }
            
            # Draw visible lines
            for ($y = 0; $y -lt $contentHeight; $y++) {
                $lineIndex = $y + $this.ScrollOffsetY
                if ($lineIndex -lt $this.Lines.Count) {
                    $line = $this.Lines[$lineIndex]
                    $visiblePart = ""
                    
                    if ($line.Length -gt $this.ScrollOffsetX) {
                        $endPos = [Math]::Min($this.ScrollOffsetX + $contentWidth, $line.Length)
                        $visiblePart = $line.Substring($this.ScrollOffsetX, $endPos - $this.ScrollOffsetX)
                    }
                    
                    if ($visiblePart) {
                        Write-TuiText -Buffer $this._private_buffer -X 1 -Y ($y + 1) -Text $visiblePart -Style @{ FG = $fgColor; BG = $bgColor }
                    }
                }
            }
            
            # Draw cursor if focused
            if ($this.IsFocused -and -not $this.ReadOnly) {
                $cursorScreenY = $this.CursorLine - $this.ScrollOffsetY + 1
                $cursorScreenX = $this.CursorColumn - $this.ScrollOffsetX + 1
                
                if ($cursorScreenY -ge 1 -and $cursorScreenY -lt $this.Height - 1 -and
                    $cursorScreenX -ge 1 -and $cursorScreenX -lt $this.Width - 1) {
                    
                    $currentLine = $this.Lines[$this.CursorLine]
                    $cursorChar = ' '
                    if ($this.CursorColumn -lt $currentLine.Length) {
                        $cursorChar = $currentLine[$this.CursorColumn]
                    }
                    
                    # Invert colors for the cursor cell
                    $this._private_buffer.SetCell($cursorScreenX, $cursorScreenY,
                        [TuiCell]::new($cursorChar, $bgColor, $fgColor))
                }
            }
        }
        catch {
            # Log or handle rendering errors gracefully
            # Write-Error "Error rendering MultilineTextBoxComponent '$($this.Name)': $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or $this.ReadOnly) { return $false }
        
        $handled = $true
        $changed = $false
        
        switch ($key.Key) {
            ([ConsoleKey]::LeftArrow) {
                if ($this.CursorColumn -gt 0) {
                    $this.CursorColumn--
                }
                elseif ($this.CursorLine -gt 0) {
                    $this.CursorLine--
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
            }
            ([ConsoleKey]::RightArrow) {
                $currentLine = $this.Lines[$this.CursorLine]
                if ($this.CursorColumn -lt $currentLine.Length) {
                    $this.CursorColumn++
                }
                elseif ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $this.CursorLine++
                    $this.CursorColumn = 0
                }
            }
            ([ConsoleKey]::UpArrow) {
                if ($this.CursorLine -gt 0) {
                    $this.CursorLine--
                    $newLineLength = $this.Lines[$this.CursorLine].Length
                    if ($this.CursorColumn -gt $newLineLength) {
                        $this.CursorColumn = $newLineLength
                    }
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $this.CursorLine++
                    $newLineLength = $this.Lines[$this.CursorLine].Length
                    if ($this.CursorColumn -gt $newLineLength) {
                        $this.CursorColumn = $newLineLength
                    }
                }
            }
            ([ConsoleKey]::Home) {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    $this.CursorLine = 0
                    $this.CursorColumn = 0
                }
                else {
                    $this.CursorColumn = 0
                }
            }
            ([ConsoleKey]::End) {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    $this.CursorLine = $this.Lines.Count - 1
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
                else {
                    $this.CursorColumn = $this.Lines[$this.CursorLine].Length
                }
            }
            ([ConsoleKey]::Enter) {
                $currentLine = $this.Lines[$this.CursorLine]
                $beforeCursor = $currentLine.Substring(0, $this.CursorColumn)
                $afterCursor = $currentLine.Substring($this.CursorColumn)
                
                $this.Lines[$this.CursorLine] = $beforeCursor
                $this.Lines.Insert($this.CursorLine + 1, $afterCursor)
                
                $this.CursorLine++
                $this.CursorColumn = 0
                $changed = $true
            }
            ([ConsoleKey]::Backspace) {
                if ($this.CursorColumn -gt 0) {
                    $currentLine = $this.Lines[$this.CursorLine]
                    $this.Lines[$this.CursorLine] = $currentLine.Remove($this.CursorColumn - 1, 1)
                    $this.CursorColumn--
                    $changed = $true
                }
                elseif ($this.CursorLine -gt 0) {
                    $currentLine = $this.Lines[$this.CursorLine]
                    $previousLine = $this.Lines[$this.CursorLine - 1]
                    $this.CursorColumn = $previousLine.Length
                    $this.Lines[$this.CursorLine - 1] = $previousLine + $currentLine
                    $this.Lines.RemoveAt($this.CursorLine)
                    $this.CursorLine--
                    $changed = $true
                }
            }
            ([ConsoleKey]::Delete) {
                $currentLine = $this.Lines[$this.CursorLine]
                if ($this.CursorColumn -lt $currentLine.Length) {
                    $this.Lines[$this.CursorLine] = $currentLine.Remove($this.CursorColumn, 1)
                    $changed = $true
                }
                elseif ($this.CursorLine -lt $this.Lines.Count - 1) {
                    $nextLine = $this.Lines[$this.CursorLine + 1]
                    $this.Lines[$this.CursorLine] = $currentLine + $nextLine
                    $this.Lines.RemoveAt($this.CursorLine + 1)
                    $changed = $true
                }
            }
            default {
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    $currentLine = $this.Lines[$this.CursorLine]
                    $this.Lines[$this.CursorLine] = $currentLine.Insert($this.CursorColumn, $key.KeyChar)
                    $this.CursorColumn++
                    $changed = $true
                }
                else {
                    $handled = $false
                }
            }
        }
        
        if ($handled) {
            if ($changed -and $this.OnChange) {
                try { & $this.OnChange $this $this.GetText() } catch {}
            }
            $this.RequestRedraw()
            $global:TuiState.IsDirty = $true # Fixed: Added global:TuiState.IsDirty = $true
        }
        
        return $handled
    }
    
    [string] GetText() {
        return ($this.Lines -join "`n")
    }
    
    [void] SetText([string]$text) {
        $this.Lines.Clear()
        $splitLines = $text -split "`n"
        foreach ($line in $splitLines) {
            $this.Lines.Add($line)
        }
        if ($this.Lines.Count -eq 0) {
            $this.Lines.Add("")
        }
        $this.CursorLine = 0
        $this.CursorColumn = 0
        $this.ScrollOffsetY = 0
        $this.ScrollOffsetX = 0
        $this.RequestRedraw()
    }
}

#<!-- END_PAGE: ACO.006 -->