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

#region Core UI Components

# ===== CLASS: LabelComponent =====
# Module: tui-components
# Dependencies: UIElement
# Purpose: Static text display
class LabelComponent : UIElement {
    [string]$Text = ""
    
    # Output caching for performance
    hidden [object]$_renderCache = $null
    hidden [string]$_cacheKey = ""
    hidden [bool]$_cacheValid = $false

    LabelComponent([string]$name) : base($name) {
        $this.IsFocusable = $false
        $this.Width = 30  # Increased default width
        $this.Height = 1
    }
    
    # Generate cache key based on all rendering parameters
    hidden [string] _GenerateCacheKey() {
        # FIXED: Correctly check for $null by just checking the property's truthiness
        $fg = "default"
        if ($this.ForegroundColor) { $fg = $this.ForegroundColor }
        
        $bg = "default"
        if ($this.BackgroundColor) { $bg = $this.BackgroundColor }
        
        return "$($this.Text)_$($this.Width)_$($this.Height)_$($fg)_$($bg)"
    }
    
    # Invalidate cache when properties change
    hidden [void] _InvalidateCache() {
        $this._cacheValid = $false
        $this._cacheKey = ""
        $this._renderCache = $null
    }
    
    # FIXED: Removed SetText, SetForegroundColor, and SetBackgroundColor methods.
    # Direct property assignment (e.g., $label.Text = "...") is now the correct way.
    # The cache invalidation is handled automatically by the OnRender logic.

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Check if we can use cached output
        $currentCacheKey = $this._GenerateCacheKey()
        if ($this._cacheValid -and $this._cacheKey -eq $currentCacheKey -and $null -ne $this._renderCache) {
            # Fast path: Use cached render
            if ($this._renderCache.Width -eq $this.Width -and $this._renderCache.Height -eq $this.Height) {
                # Copy cached buffer directly
                for ($y = 0; $y -lt $this.Height; $y++) {
                    for ($x = 0; $x -lt $this.Width; $x++) {
                        if ($x -lt $this._renderCache.Width -and $y -lt $this._renderCache.Height) {
                            $cell = $this._renderCache.GetCell($x, $y)
                            $this._private_buffer.SetCell($x, $y, $cell)
                        }
                    }
                }
                $this._needs_redraw = $false
                return
            } else {
                # Cache invalid due to size change
                $this._InvalidateCache()
            }
        }
        
        # Slow path: Render and cache
        # Get background color using the effective color method from the base class
        $bgColor = $this.GetEffectiveBackgroundColor()
        
        # Clear buffer with background color
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Skip rendering if text is empty
        if ([string]::IsNullOrEmpty($this.Text)) {
            # Cache the empty result
            $this._renderCache = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Cache")
            $this._renderCache.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            $this._cacheKey = $currentCacheKey
            $this._cacheValid = $true
            $this._needs_redraw = $false
            return
        }
        
        # Get foreground color using the effective color method from the base class
        $fgColor = $this.GetEffectiveForegroundColor()
        
        # Draw text
        Write-TuiText -Buffer $this._private_buffer -X 0 -Y 0 -Text $this.Text -Style @{ FG = $fgColor; BG = $bgColor }
        
        # Cache the rendered result
        $this._renderCache = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Cache")
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $cell = $this._private_buffer.GetCell($x, $y)
                $this._renderCache.SetCell($x, $y, $cell)
            }
        }
        $this._cacheKey = $currentCacheKey
        $this._cacheValid = $true
        
        $this._needs_redraw = $false
    }

    # Override Resize to invalidate cache on size changes
    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($this.Width -ne $newWidth -or $this.Height -ne $newHeight) {
            $this._InvalidateCache()
        }
        ([UIElement]$this).Resize($newWidth, $newHeight)
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $false
    }
}
#<!-- END_PAGE: ACO.001 -->