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
        $this.ForegroundColor = $fg # Fixed: Direct assignment as TuiCell has no SetForegroundColor method
        $this.BackgroundColor = $bg # Fixed: Direct assignment as TuiCell has no SetBackgroundColor method
    }
    
    # Constructor with 4 parameters (char, fg, bg, bold)
    TuiCell([char]$char, [string]$fg, [string]$bg, [bool]$bold) {
        $this.Char = $char
        $this.ForegroundColor = $fg # Fixed: Direct assignment as TuiCell has no SetForegroundColor method
        $this.BackgroundColor = $bg # Fixed: Direct assignment as TuiCell has no SetBackgroundColor method
        $this.Bold = $bold
    }
    
    # Full constructor with all parameters
    TuiCell([char]$char, [string]$fg, [string]$bg, [bool]$bold, [bool]$italic, [bool]$underline, [bool]$strikethrough) {
        $this.Char = $char
        $this.ForegroundColor = $fg # Fixed: Direct assignment as TuiCell has no SetForegroundColor method
        $this.BackgroundColor = $bg # Fixed: Direct assignment as TuiCell has no SetBackgroundColor method
        $this.Bold = $bold
        $this.Italic = $italic
        $this.Underline = $underline
        $this.Strikethrough = $strikethrough # Assign new property
    }
    
    # Copy Constructor: Ensure it copies all new properties
    TuiCell([object]$other) {
        $this.Char = $other.Char
        $this.ForegroundColor = $other.ForegroundColor # Fixed: Direct assignment as TuiCell has no SetForegroundColor method
        $this.BackgroundColor = $other.BackgroundColor # Fixed: Direct assignment as TuiCell has no SetBackgroundColor method
        $this.Bold = $other.Bold
        $this.Underline = $other.Underline
        $this.Italic = $other.Italic
        $this.Strikethrough = $other.Strikethrough # Make sure this is copied
        $this.ZIndex = $other.ZIndex
        $this.Metadata = $other.Metadata
    }

    [TuiCell] WithStyle([string]$fg, [string]$bg) { # Parameter types changed
        $copy = [TuiCell]::new($this)
        $copy.ForegroundColor = $fg # Fixed: Direct assignment as TuiCell has no SetForegroundColor method
        $copy.BackgroundColor = $bg # Fixed: Direct assignment as TuiCell has no SetBackgroundColor method
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
    
    # PERFORMANCE: Mutable version that modifies this cell in-place
    [void] BlendWithMutable([object]$other) {
        if ($null -eq $other) { return }
        
        try {
            # If Z-Indexes are different, the higher one wins.
            if ($other.ZIndex -gt $this.ZIndex) {
                $this.Char = $other.Char
                $this.ForegroundColor = $other.ForegroundColor
                $this.BackgroundColor = $other.BackgroundColor
                $this.Bold = $other.Bold
                $this.Italic = $other.Italic
                $this.Underline = $other.Underline
                $this.Strikethrough = $other.Strikethrough
                $this.ZIndex = $other.ZIndex
                $this.Metadata = $other.Metadata
            }
            elseif ($other.ZIndex -eq $this.ZIndex) {
                # If Z-Indexes are the same, the 'other' (top) cell wins by default
                $this.Char = $other.Char
                $this.ForegroundColor = $other.ForegroundColor
                $this.BackgroundColor = $other.BackgroundColor
                $this.Bold = $other.Bold
                $this.Italic = $other.Italic
                $this.Underline = $other.Underline
                $this.Strikethrough = $other.Strikethrough
                $this.ZIndex = $other.ZIndex
                $this.Metadata = $other.Metadata
            }
            # If other.ZIndex < this.ZIndex, do nothing (this cell wins)
        }
        catch {
            # FALLBACK: If mutable blending fails, fall back to immutable blending
            if ($global:TuiDebugMode) {
                Write-Log -Level Warning -Message "BlendWithMutable failed, falling back to immutable blend: $_"
            }
            $blended = $this.BlendWith($other)
            if ($blended) {
                $this.Char = $blended.Char
                $this.ForegroundColor = $blended.ForegroundColor
                $this.BackgroundColor = $blended.BackgroundColor
                $this.Bold = $blended.Bold
                $this.Italic = $blended.Italic
                $this.Underline = $blended.Underline
                $this.Strikethrough = $blended.Strikethrough
                $this.ZIndex = $blended.ZIndex
                $this.Metadata = $blended.Metadata
            }
        }
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
        
        # Validate colors before passing to TuiAnsiHelper
        $fgColor = $this.ForegroundColor
        $bgColor = $this.BackgroundColor
        
        if ($fgColor -is [bool] -or $fgColor -eq $true -or $fgColor -eq $false) {
            Write-Log -Level Error -Message "TuiCell.ToAnsiString: Invalid foreground color '$fgColor' - using default"
            $fgColor = "#FFFFFF"
        }
        
        if ($bgColor -is [bool] -or $bgColor -eq $true -or $bgColor -eq $false) {
            Write-Log -Level Error -Message "TuiCell.ToAnsiString: Invalid background color '$bgColor' - using default"
            $bgColor = "#000000"
        }
        
        $sequence = [TuiAnsiHelper]::GetAnsiSequence($fgColor, $bgColor, $attributes)
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