# FastComponent Base - Minimal overhead, maximum speed
# Components compile to direct VT sequences, no virtual calls

class FastComponentBase {
    # Minimal state - only what's absolutely needed
    [int]$X
    [int]$Y
    [int]$Width
    [int]$Height
    [bool]$Visible = $true
    
    # Pre-compiled VT sequences for common operations
    static [hashtable]$VTCache = @{
        Reset = [VT]::Reset()
        MoveTo = @{}  # Cached MoveTo sequences
        Colors = @{}  # Cached color sequences
    }
    
    # Static initializer to pre-cache common sequences
    static FastComponentBase() {
        # Pre-cache common movements
        for ($row = 1; $row -le 50; $row++) {
            for ($col = 1; $col -le 100; $col++) {
                [FastComponentBase]::VTCache.MoveTo["$col,$row"] = "`e[$row;${col}H"
            }
        }
        
        # Pre-cache common colors
        [FastComponentBase]::VTCache.Colors['Selected'] = "`e[48;2;40;40;80m`e[38;2;255;255;255m"
        [FastComponentBase]::VTCache.Colors['Normal'] = "`e[48;2;30;30;35m`e[38;2;200;200;200m"
        [FastComponentBase]::VTCache.Colors['Focus'] = "`e[38;2;100;200;255m"
    }
    
    # Direct render - returns VT string, no method calls
    [string] Render() {
        # Override in derived classes
        return ""
    }
    
    # Direct input - returns true if handled, minimal checks
    [bool] Input([ConsoleKey]$key) {
        # Override in derived classes
        return $false
    }
    
    # Helper to get cached MoveTo sequence
    [string] MT([int]$xPos, [int]$yPos) {
        $key = "$xPos,$yPos"
        $cached = [FastComponentBase]::VTCache.MoveTo[$key]
        if ($cached) { return $cached }
        # Cache miss - generate and cache
        $seq = "`e[$yPos;${xPos}H"
        [FastComponentBase]::VTCache.MoveTo[$key] = $seq
        return $seq
    }
}