# ==============================================================================
# Axiom-Phoenix v4.0 - String Interning System
# Reduce memory overhead by interning frequently used strings
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent

#region String Interning Interface

# IStringInterner interface
# String interning interface for memory optimization
#   Intern(value) -> string
#   IsInterned(value) -> bool
#   ClearCache() -> void
#   GetStatistics() -> hashtable

#endregion

#region String Interner Implementation

class StringInterner {
    hidden [ConcurrentDictionary[string, string]] $_internedStrings
    hidden [ConcurrentDictionary[string, int]] $_usageCounts
    hidden [int] $_maxCacheSize = 1000
    hidden [int] $_internCount = 0
    hidden [int] $_hitCount = 0
    hidden [bool] $_disposed = $false
    
    StringInterner() {
        $this._internedStrings = [ConcurrentDictionary[string, string]]::new()
        $this._usageCounts = [ConcurrentDictionary[string, int]]::new()
        $this.PreInternCommonStrings()
    }
    
    StringInterner([int]$maxCacheSize) {
        $this._maxCacheSize = $maxCacheSize
        $this._internedStrings = [ConcurrentDictionary[string, string]]::new()
        $this._usageCounts = [ConcurrentDictionary[string, int]]::new()
        $this.PreInternCommonStrings()
    }
    
    # Pre-intern commonly used strings
    [void] PreInternCommonStrings() {
        $commonStrings = @(
            # UI Text
            "OK", "Cancel", "Yes", "No", "Close", "Save", "Load", "Delete", "Edit", "New",
            "File", "View", "Help", "Settings", "Options", "Exit", "Quit",
            
            # Status messages
            "Ready", "Loading", "Saving", "Error", "Warning", "Info", "Success", "Failed",
            "Connected", "Disconnected", "Processing", "Complete", "Pending",
            
            # Common UI elements
            "Button", "Label", "TextBox", "Panel", "Grid", "Menu", "Toolbar", "StatusBar",
            "Window", "Dialog", "Form", "Control", "Component",
            
            # Common characters and symbols
            " ", "", "...", "►", "◄", "▲", "▼", "■", "□", "●", "○", "✓", "✗", "⚠",
            
            # Theme keys (common ones)
            "foreground", "background", "border", "accent", "text", "primary", "secondary",
            "success", "warning", "error", "info", "disabled", "active", "inactive",
            
            # Common actions
            "Click", "Select", "Focus", "Blur", "Hover", "Press", "Release", "Enter", "Leave",
            
            # File operations
            "Open", "Create", "Remove", "Copy", "Move", "Rename", "Properties",
            
            # Data states
            "Empty", "Null", "Undefined", "True", "False", "Zero", "Default"
        )
        
        foreach ($str in $commonStrings) {
            $this.InternString($str)
        }
        
        Write-Log -Level Debug -Message "String interner pre-loaded with $($commonStrings.Count) common strings"
    }
    
    # Intern a string
    [string] Intern([string]$value) {
        if ($this._disposed -or [string]::IsNullOrEmpty($value)) {
            return $value
        }
        
        # Check if already interned
        $interned = ""
        if ($this._internedStrings.TryGetValue($value, [ref]$interned)) {
            $this._hitCount++
            $this._usageCounts.AddOrUpdate($value, 1, { param($k, $v) $v + 1 })
            return $interned
        }
        
        # Check cache size limit
        if ($this._internedStrings.Count -ge $this._maxCacheSize) {
            $this.EvictLeastUsed()
        }
        
        # Intern the string
        return $this.InternString($value)
    }
    
    hidden [string] InternString([string]$value) {
        # Use .NET string interning for maximum efficiency
        $internedValue = [string]::Intern($value)
        $this._internedStrings[$value] = $internedValue
        $this._usageCounts[$value] = 1
        $this._internCount++
        return $internedValue
    }
    
    # Check if string is interned
    [bool] IsInterned([string]$value) {
        if ([string]::IsNullOrEmpty($value)) {
            return $false
        }
        return $this._internedStrings.ContainsKey($value)
    }
    
    # Evict least used strings
    hidden [void] EvictLeastUsed() {
        $itemsToEvict = [Math]::Max(1, $this._maxCacheSize / 10)
        
        # Get least used entries
        $sortedEntries = $this._usageCounts.ToArray() | Sort-Object Value | Select-Object -First $itemsToEvict
        
        foreach ($entry in $sortedEntries) {
            [void]$this._internedStrings.TryRemove($entry.Key, [ref]$null)
            [void]$this._usageCounts.TryRemove($entry.Key, [ref]$null)
        }
        
        Write-Log -Level Debug -Message "Evicted $itemsToEvict least used strings from intern cache"
    }
    
    # Clear cache
    [void] ClearCache() {
        $this._internedStrings.Clear()
        $this._usageCounts.Clear()
        $this._internCount = 0
        $this._hitCount = 0
        $this.PreInternCommonStrings()
    }
    
    # Get statistics
    [hashtable] GetStatistics() {
        $totalRequests = $this._internCount + $this._hitCount
        $hitRate = if ($totalRequests -gt 0) {
            [Math]::Round(($this._hitCount / $totalRequests) * 100, 2)
        } else { 0 }
        
        return @{
            CacheSize = $this._internedStrings.Count
            MaxCacheSize = $this._maxCacheSize
            InternCount = $this._internCount
            HitCount = $this._hitCount
            HitRate = $hitRate
            MostUsedStrings = $this.GetMostUsedStrings(10)
            AverageStringLength = $this.GetAverageStringLength()
            MemorySavingEstimate = $this.EstimateMemorySaving()
        }
    }
    
    hidden [hashtable[]] GetMostUsedStrings([int]$count) {
        return $this._usageCounts.ToArray() | 
               Sort-Object Value -Descending | 
               Select-Object -First $count |
               ForEach-Object { @{ String = $_.Key; UsageCount = $_.Value; Length = $_.Key.Length } }
    }
    
    hidden [double] GetAverageStringLength() {
        if ($this._internedStrings.Count -eq 0) { return 0 }
        
        $totalLength = 0
        foreach ($str in $this._internedStrings.Keys) {
            $totalLength += $str.Length
        }
        
        return [Math]::Round($totalLength / $this._internedStrings.Count, 2)
    }
    
    hidden [hashtable] EstimateMemorySaving() {
        $totalUsage = 0
        $totalLength = 0
        
        foreach ($kvp in $this._usageCounts.GetEnumerator()) {
            $usage = $kvp.Value
            $length = $kvp.Key.Length
            $totalUsage += $usage
            $totalLength += $length * $usage
        }
        
        $estimatedSavings = if ($totalUsage -gt 1) {
            ($totalLength - ($this._internedStrings.Count * $this.GetAverageStringLength())) * 2 # 2 bytes per char
        } else { 0 }
        
        return @{
            EstimatedByteSavings = $estimatedSavings
            EstimatedKBSavings = [Math]::Round($estimatedSavings / 1024, 2)
            TotalStringInstances = $totalUsage
            UniqueStrings = $this._internedStrings.Count
            CompressionRatio = if ($this._internedStrings.Count -gt 0) {
                [Math]::Round($totalUsage / $this._internedStrings.Count, 2)
            } else { 0 }
        }
    }
    
    [void] Dispose() {
        if (-not $this._disposed) {
            $this._internedStrings.Clear()
            $this._usageCounts.Clear()
            $this._disposed = $true
        }
    }
}

#endregion

#region String Interning Extensions

# Extension methods for common string operations
class StringInterningExtensions {
    static [string] InternThemeKey([string]$key) {
        if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.StringInterner) {
            return $global:TuiState.Services.StringInterner.Intern($key.ToLower())
        }
        return $key
    }
    
    static [string] InternColorName([string]$colorName) {
        if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.StringInterner) {
            return $global:TuiState.Services.StringInterner.Intern($colorName)
        }
        return $colorName
    }
    
    static [string] InternComponentName([string]$name) {
        if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.StringInterner) {
            return $global:TuiState.Services.StringInterner.Intern($name)
        }
        return $name
    }
    
    static [string] InternStatusMessage([string]$message) {
        if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.StringInterner) {
            return $global:TuiState.Services.StringInterner.Intern($message)
        }
        return $message
    }
    
    static [string] InternUIText([string]$text) {
        if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.StringInterner) {
            # Only intern short strings (likely to be repeated)
            if ($text.Length -le 50) {
                return $global:TuiState.Services.StringInterner.Intern($text)
            }
        }
        return $text
    }
}

#endregion

#region String Interning Service

class StringInterningService {
    hidden [StringInterner] $_interner
    hidden [bool] $_disposed = $false
    
    [void] Initialize() {
        $enabled = Get-ConfigValue "Performance.StringInterningEnabled" $true
        if (-not $enabled) {
            Write-Log -Level Info -Message "String interning disabled by configuration"
            return
        }
        
        $maxCacheSize = Get-ConfigValue "Performance.StringInterningCacheSize" 1000
        $this._interner = [StringInterner]::new($maxCacheSize)
        
        Write-Log -Level Info -Message "String interning service initialized with max size: $maxCacheSize"
    }
    
    [string] Intern([string]$value) {
        if ($this._interner) {
            return $this._interner.Intern($value)
        }
        return $value
    }
    
    [bool] IsInterned([string]$value) {
        if ($this._interner) {
            return $this._interner.IsInterned($value)
        }
        return $false
    }
    
    [hashtable] GetStatistics() {
        if ($this._interner) {
            return $this._interner.GetStatistics()
        }
        return @{ Error = "String interning not enabled" }
    }
    
    [void] ClearCache() {
        if ($this._interner) {
            $this._interner.ClearCache()
        }
    }
    
    [void] OptimizeCache() {
        if ($this._interner) {
            $stats = $this._interner.GetStatistics()
            if ($stats.HitRate -lt 30) {
                # Poor hit rate, clear and rebuild
                $this._interner.ClearCache()
                Write-Log -Level Info -Message "String intern cache cleared due to poor hit rate: $($stats.HitRate)%"
            }
        }
    }
    
    [void] Dispose() {
        if (-not $this._disposed) {
            if ($this._interner) {
                $this._interner.Dispose()
            }
            $this._disposed = $true
            
            Write-Log -Level Info -Message "String interning service disposed"
        }
    }
}

#endregion

#region Helper Functions

# Intern a string using the global service
function Intern-String {
    param([string]$Value)
    
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.StringInterner) {
        return $global:TuiState.Services.StringInterner.Intern($Value)
    }
    
    return $Value
}

# Check if string is interned
function Test-StringInterned {
    param([string]$Value)
    
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.StringInterner) {
        return $global:TuiState.Services.StringInterner.IsInterned($Value)
    }
    
    return $false
}

# Get string interning statistics
function Get-StringInterningStats {
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.StringInterner) {
        return $global:TuiState.Services.StringInterner.GetStatistics()
    }
    
    return @{ Error = "String interning service not available" }
}

# Optimize string interning cache
function Optimize-StringInterning {
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.StringInterner) {
        $global:TuiState.Services.StringInterner.OptimizeCache()
    }
}

#endregion

#region Enhanced UIElement with String Interning

# Base class extension to use string interning automatically
class InternedUIElement : TypedUIElement {
    InternedUIElement([string]$name) : base([StringInterningExtensions]::InternComponentName($name)) {
        # Constructor with interned name
    }
    
    # Override property setters to use interning
    [void] SetName([string]$name) {
        $this.Name = [StringInterningExtensions]::InternComponentName($name)
    }
    
    [void] SetText([string]$text) {
        if ($this.PSObject.Properties['Text']) {
            $this.Text = [StringInterningExtensions]::InternUIText($text)
        }
    }
    
    [void] SetForegroundColorByName([string]$colorName) {
        $internedName = [StringInterningExtensions]::InternColorName($colorName)
        $this.ForegroundColor = $internedName
    }
    
    [void] SetBackgroundColorByName([string]$colorName) {
        $internedName = [StringInterningExtensions]::InternColorName($colorName)
        $this.BackgroundColor = $internedName
    }
}

#endregion

Write-Host "String Interning system loaded" -ForegroundColor Green