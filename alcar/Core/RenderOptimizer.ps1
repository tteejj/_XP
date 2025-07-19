# Rendering Optimizer - Reduces flicker and improves performance

class RenderOptimizer {
    static [string]$LastFrame = ""
    static [bool]$UseAlternateBuffer = $true
    
    # Enter alternate screen buffer
    static [string] EnterAltBuffer() {
        if ([RenderOptimizer]::UseAlternateBuffer) {
            return "`e[?1049h"  # Save screen and use alternate buffer
        }
        return ""
    }
    
    # Exit alternate screen buffer
    static [string] ExitAltBuffer() {
        if ([RenderOptimizer]::UseAlternateBuffer) {
            return "`e[?1049l"  # Restore original screen
        }
        return ""
    }
    
    # Optimized render - only update changed parts
    static [string] OptimizedRender([string]$newFrame) {
        # For now, just return the new frame
        # Could implement diff algorithm later
        [RenderOptimizer]::LastFrame = $newFrame
        return $newFrame
    }
    
    # Clear with optimization
    static [string] SmartClear() {
        # Use home position only, no clear
        return "`e[H"
    }
    
    # Double buffer write
    static [void] WriteDoubleBuffered([string]$content) {
        # Build complete frame in memory
        $frame = [VT]::Hide()  # Hide cursor during update
        $frame += [VT]::Home()  # Go to top
        $frame += $content
        $frame += [VT]::Hide()  # Keep cursor hidden
        
        # Write entire frame at once
        [Console]::Write($frame)
    }
}