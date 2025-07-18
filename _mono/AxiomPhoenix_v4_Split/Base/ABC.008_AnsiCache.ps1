# ==============================================================================
# Axiom-Phoenix v4.0 - ANSI Sequence Caching
# Cache frequently used ANSI sequences to reduce string concatenation overhead
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Text

#region ANSI Cache Interface

# IAnsiCache interface
# ANSI sequence caching interface
#   GetSequence(key) -> string
#   CacheSequence(key, sequence) -> void
#   ClearCache() -> void
#   GetStatistics() -> hashtable

#endregion

#region ANSI Sequence Cache

class AnsiSequenceCache {
    hidden [ConcurrentDictionary[string, string]] $_cache
    hidden [ConcurrentDictionary[string, int]] $_hitCounts
    hidden [int] $_maxCacheSize = 500
    hidden [int] $_totalHits = 0
    hidden [int] $_totalMisses = 0
    hidden [bool] $_disposed = $false
    
    AnsiSequenceCache() {
        $this._cache = [ConcurrentDictionary[string, string]]::new()
        $this._hitCounts = [ConcurrentDictionary[string, int]]::new()
        $this.PreCacheCommonSequences()
    }
    
    AnsiSequenceCache([int]$maxCacheSize) {
        $this._maxCacheSize = $maxCacheSize
        $this._cache = [ConcurrentDictionary[string, string]]::new()
        $this._hitCounts = [ConcurrentDictionary[string, int]]::new()
        $this.PreCacheCommonSequences()
    }
    
    # Pre-cache common ANSI sequences
    [void] PreCacheCommonSequences() {
        # Color sequences (foreground)
        $colorMap = @{
            "Black" = 30; "DarkRed" = 31; "DarkGreen" = 32; "DarkYellow" = 33
            "DarkBlue" = 34; "DarkMagenta" = 35; "DarkCyan" = 36; "Gray" = 37
            "DarkGray" = 90; "Red" = 91; "Green" = 92; "Yellow" = 93
            "Blue" = 94; "Magenta" = 95; "Cyan" = 96; "White" = 97
        }
        
        foreach ($color in $colorMap.Keys) {
            $sequence = [char]27 + "[" + $colorMap[$color] + "m"
            $this._cache["fg_$color"] = $sequence
            $this._hitCounts["fg_$color"] = 0
        }
        
        # Background colors
        foreach ($color in $colorMap.Keys) {
            $sequence = [char]27 + "[" + ($colorMap[$color] + 10) + "m"
            $this._cache["bg_$color"] = $sequence
            $this._hitCounts["bg_$color"] = 0
        }
        
        # Common control sequences
        $this._cache["reset"] = [char]27 + "[0m"
        $this._cache["clear_screen"] = [char]27 + "[2J"
        $this._cache["clear_line"] = [char]27 + "[2K"
        $this._cache["cursor_home"] = [char]27 + "[H"
        $this._cache["cursor_hide"] = [char]27 + "[?25l"
        $this._cache["cursor_show"] = [char]27 + "[?25h"
        $this._cache["bold"] = [char]27 + "[1m"
        $this._cache["dim"] = [char]27 + "[2m"
        $this._cache["underline"] = [char]27 + "[4m"
        $this._cache["blink"] = [char]27 + "[5m"
        $this._cache["reverse"] = [char]27 + "[7m"
        
        # Initialize hit counts
        foreach ($key in $this._cache.Keys) {
            if (-not $this._hitCounts.ContainsKey($key)) {
                $this._hitCounts[$key] = 0
            }
        }
        
        Write-Log -Level Debug -Message "ANSI cache pre-loaded with $($this._cache.Count) common sequences"
    }
    
    # Get cached sequence
    [string] GetSequence([string]$key) {
        if ($this._disposed) {
            return ""
        }
        
        $sequence = ""
        if ($this._cache.TryGetValue($key, [ref]$sequence)) {
            $this._totalHits++
            $this._hitCounts.AddOrUpdate($key, 1, { param($k, $v) $v + 1 })
            return $sequence
        }
        
        $this._totalMisses++
        return $null
    }
    
    # Cache a sequence
    [void] CacheSequence([string]$key, [string]$sequence) {
        if ($this._disposed -or [string]::IsNullOrEmpty($key) -or [string]::IsNullOrEmpty($sequence)) {
            return
        }
        
        # Check cache size limit
        if ($this._cache.Count -ge $this._maxCacheSize) {
            $this.EvictLeastUsed()
        }
        
        $this._cache[$key] = $sequence
        $this._hitCounts[$key] = 0
    }
    
    # Evict least used entries
    hidden [void] EvictLeastUsed() {
        $itemsToEvict = [Math]::Max(1, $this._maxCacheSize / 10)
        
        # Get least used entries
        $sortedEntries = $this._hitCounts.ToArray() | Sort-Object Value | Select-Object -First $itemsToEvict
        
        foreach ($entry in $sortedEntries) {
            [void]$this._cache.TryRemove($entry.Key, [ref]$null)
            [void]$this._hitCounts.TryRemove($entry.Key, [ref]$null)
        }
        
        Write-Log -Level Debug -Message "Evicted $itemsToEvict least used ANSI sequences from cache"
    }
    
    # Clear entire cache
    [void] ClearCache() {
        $this._cache.Clear()
        $this._hitCounts.Clear()
        $this._totalHits = 0
        $this._totalMisses = 0
        $this.PreCacheCommonSequences()
    }
    
    # Get cache statistics
    [hashtable] GetStatistics() {
        $totalRequests = $this._totalHits + $this._totalMisses
        $hitRate = if ($totalRequests -gt 0) {
            [Math]::Round(($this._totalHits / $totalRequests) * 100, 2)
        } else { 0 }
        
        return @{
            CacheSize = $this._cache.Count
            MaxCacheSize = $this._maxCacheSize
            TotalHits = $this._totalHits
            TotalMisses = $this._totalMisses
            HitRate = $hitRate
            MostUsedSequences = $this.GetMostUsedSequences(5)
            LeastUsedSequences = $this.GetLeastUsedSequences(5)
        }
    }
    
    hidden [hashtable[]] GetMostUsedSequences([int]$count) {
        return $this._hitCounts.ToArray() | 
               Sort-Object Value -Descending | 
               Select-Object -First $count |
               ForEach-Object { @{ Key = $_.Key; HitCount = $_.Value } }
    }
    
    hidden [hashtable[]] GetLeastUsedSequences([int]$count) {
        return $this._hitCounts.ToArray() | 
               Sort-Object Value | 
               Select-Object -First $count |
               ForEach-Object { @{ Key = $_.Key; HitCount = $_.Value } }
    }
    
    [void] Dispose() {
        if (-not $this._disposed) {
            $this._cache.Clear()
            $this._hitCounts.Clear()
            $this._disposed = $true
        }
    }
}

#endregion

#region Enhanced ANSI Helper with Caching

class CachedAnsiHelper : TuiAnsiHelper {
    hidden [AnsiSequenceCache] $_cache
    hidden [StringBuilder] $_stringBuilder
    
    CachedAnsiHelper() : base() {
        $this.InitializeCache()
    }
    
    CachedAnsiHelper([AnsiSequenceCache]$cache) : base() {
        $this._cache = $cache
        $this._stringBuilder = [StringBuilder]::new(256)
    }
    
    hidden [void] InitializeCache() {
        $maxCacheSize = Get-ConfigValue "Performance.AnsiCacheSize" 500
        $this._cache = [AnsiSequenceCache]::new($maxCacheSize)
        $this._stringBuilder = [StringBuilder]::new(256)
    }
    
    # Override color methods to use caching
    [string] SetForegroundColor([ConsoleColor]$color) {
        $key = "fg_$color"
        $cached = $this._cache.GetSequence($key)
        if ($cached) {
            return $cached
        }
        
        # Generate and cache
        $sequence = ([TuiAnsiHelper]$this).SetForegroundColor($color)
        $this._cache.CacheSequence($key, $sequence)
        return $sequence
    }
    
    [string] SetBackgroundColor([ConsoleColor]$color) {
        $key = "bg_$color"
        $cached = $this._cache.GetSequence($key)
        if ($cached) {
            return $cached
        }
        
        # Generate and cache
        $sequence = ([TuiAnsiHelper]$this).SetBackgroundColor($color)
        $this._cache.CacheSequence($key, $sequence)
        return $sequence
    }
    
    # Cached cursor positioning
    [string] SetCursorPosition([int]$x, [int]$y) {
        $key = "pos_$x" + "_$y"
        $cached = $this._cache.GetSequence($key)
        if ($cached) {
            return $cached
        }
        
        # Generate and cache (limit caching for position to avoid memory explosion)
        if ($x -le 200 -and $y -le 100) {
            $sequence = ([TuiAnsiHelper]$this).SetCursorPosition($x, $y)
            $this._cache.CacheSequence($key, $sequence)
            return $sequence
        }
        
        # Don't cache very large coordinates
        return ([TuiAnsiHelper]$this).SetCursorPosition($x, $y)
    }
    
    # Cached RGB color sequences
    [string] SetForegroundColorRgb([int]$r, [int]$g, [int]$b) {
        $key = "fg_rgb_$r" + "_$g" + "_$b"
        $cached = $this._cache.GetSequence($key)
        if ($cached) {
            return $cached
        }
        
        $sequence = ([TuiAnsiHelper]$this).SetForegroundColorRgb($r, $g, $b)
        $this._cache.CacheSequence($key, $sequence)
        return $sequence
    }
    
    [string] SetBackgroundColorRgb([int]$r, [int]$g, [int]$b) {
        $key = "bg_rgb_$r" + "_$g" + "_$b"
        $cached = $this._cache.GetSequence($key)
        if ($cached) {
            return $cached
        }
        
        $sequence = ([TuiAnsiHelper]$this).SetBackgroundColorRgb($r, $g, $b)
        $this._cache.CacheSequence($key, $sequence)
        return $sequence
    }
    
    # Common cached sequences
    [string] Reset() {
        return $this._cache.GetSequence("reset")
    }
    
    [string] ClearScreen() {
        return $this._cache.GetSequence("clear_screen")
    }
    
    [string] ClearLine() {
        return $this._cache.GetSequence("clear_line")
    }
    
    [string] CursorHome() {
        return $this._cache.GetSequence("cursor_home")
    }
    
    [string] HideCursor() {
        return $this._cache.GetSequence("cursor_hide")
    }
    
    [string] ShowCursor() {
        return $this._cache.GetSequence("cursor_show")
    }
    
    # Optimized string building with caching
    [string] BuildColoredString([string]$text, [ConsoleColor]$foreground, [ConsoleColor]$background) {
        $this._stringBuilder.Clear()
        
        # Use cached sequences
        $fgSequence = $this.SetForegroundColor($foreground)
        $bgSequence = $this.SetBackgroundColor($background)
        $resetSequence = $this.Reset()
        
        [void]$this._stringBuilder.Append($fgSequence)
        [void]$this._stringBuilder.Append($bgSequence)
        [void]$this._stringBuilder.Append($text)
        [void]$this._stringBuilder.Append($resetSequence)
        
        return $this._stringBuilder.ToString()
    }
    
    # Get cache statistics
    [hashtable] GetCacheStatistics() {
        return $this._cache.GetStatistics()
    }
    
    # Cache management
    [void] ClearCache() {
        $this._cache.ClearCache()
    }
    
    [void] OptimizeCache() {
        $stats = $this._cache.GetStatistics()
        if ($stats.HitRate -lt 50) {
            # Poor hit rate, clear and rebuild
            $this._cache.ClearCache()
            Write-Log -Level Info -Message "ANSI cache cleared due to poor hit rate: $($stats.HitRate)%"
        }
    }
}

#endregion

#region ANSI Cache Service

class AnsiCacheService {
    hidden [AnsiSequenceCache] $_cache
    hidden [CachedAnsiHelper] $_helper
    hidden [bool] $_disposed = $false
    
    [void] Initialize() {
        $maxCacheSize = Get-ConfigValue "Performance.AnsiCacheSize" 500
        $this._cache = [AnsiSequenceCache]::new($maxCacheSize)
        $this._helper = [CachedAnsiHelper]::new($this._cache)
        
        Write-Log -Level Info -Message "ANSI cache service initialized with max size: $maxCacheSize"
    }
    
    [AnsiSequenceCache] GetCache() {
        return $this._cache
    }
    
    [CachedAnsiHelper] GetHelper() {
        return $this._helper
    }
    
    [hashtable] GetStatistics() {
        if ($this._cache) {
            return $this._cache.GetStatistics()
        }
        return @{ Error = "Cache not initialized" }
    }
    
    [void] OptimizeCache() {
        if ($this._helper) {
            $this._helper.OptimizeCache()
        }
    }
    
    [void] ClearCache() {
        if ($this._cache) {
            $this._cache.ClearCache()
        }
    }
    
    [void] Dispose() {
        if (-not $this._disposed) {
            if ($this._cache) {
                $this._cache.Dispose()
            }
            $this._helper = $null
            $this._disposed = $true
            
            Write-Log -Level Info -Message "ANSI cache service disposed"
        }
    }
}

#endregion

#region Helper Functions

# Get cached ANSI helper
function Get-CachedAnsiHelper {
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.AnsiCache) {
        return $global:TuiState.Services.AnsiCache.GetHelper()
    }
    
    # Fallback to regular helper
    return [TuiAnsiHelper]::new()
}

# Get ANSI cache statistics
function Get-AnsiCacheStats {
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.AnsiCache) {
        return $global:TuiState.Services.AnsiCache.GetStatistics()
    }
    
    return @{ Error = "ANSI cache service not available" }
}

# Optimize ANSI cache
function Optimize-AnsiCache {
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.AnsiCache) {
        $global:TuiState.Services.AnsiCache.OptimizeCache()
    }
}

#endregion

Write-Host "ANSI Sequence Caching system loaded" -ForegroundColor Green