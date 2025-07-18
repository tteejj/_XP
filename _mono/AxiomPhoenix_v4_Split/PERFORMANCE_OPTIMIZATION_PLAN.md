# Axiom-Phoenix v4.0 Performance Optimization Plan

## Current Performance Issues (8 FPS is unacceptable)

### Critical Bottlenecks Identified:

## 1. 🔥 WriteString Performance - MASSIVE BOTTLENECK
- **Current**: 114-578 operations/sec
- **Impact**: Major frame rate killer
- **Root Cause**: Character-by-character processing with cell creation

### Analysis:
- String length impact: 2 chars (235/sec) vs 95 chars (57/sec) = 4x slowdown
- Style processing is NOT the issue (571-578/sec regardless of style complexity)
- **Problem**: Each character creates a new TuiCell object in a loop

## 2. 🔥 Buffer Clear Performance - WAY TOO SLOW  
- **Current**: 108-238ms per clear for typical buffer sizes
- **Impact**: Massive frame time overhead
- **Root Cause**: Creating new TuiCell objects for every position

### Analysis:
- 80x24 buffer (1920 cells): 117ms to clear = ~16,354 cells/sec
- 120x40 buffer (4800 cells): 238ms to clear = ~20,151 cells/sec
- **Problem**: `new TuiCell()` call for every cell position

## 3. 🔥 Cell Creation Overhead
- **Current**: 6,757-10,870 cells/sec
- **Optimization potential**: Pre-allocation shows 45,455/sec (6.7x improvement!)
- **Impact**: Every WriteString and Clear operation

## 4. ANSI Generation Bottleneck
- **Current**: 1,142-3,378/sec 
- **Impact**: Moderate but fixable with caching

---

## 🚀 OPTIMIZATION STRATEGIES (Priority Order)

### Priority 1: ELIMINATE CELL CREATION IN HOT PATHS

#### A) Implement True Object Pooling in TuiBuffer
```powershell
# Current problematic pattern in WriteString:
$templateCell = [TuiCell]::new(' ', $fg, $bg, $bold, $italic, $underline, $strikethrough)

# Optimization: Pre-allocated cell pool per buffer
class TuiBuffer {
    hidden [TuiCell[]] $_cellPool
    hidden [int] $_poolIndex = 0
    
    [TuiCell] GetPooledCell() {
        if ($_poolIndex -ge $_cellPool.Length) { $_poolIndex = 0 }
        $cell = $_cellPool[$_poolIndex++]
        $cell.Reset()  # Reset to defaults
        return $cell
    }
}
```

#### B) Optimize Buffer.Clear()
```powershell
# Current: Creates new TuiCell for every position
# Optimization: Use single template cell, copy properties only
[void] Clear([TuiCell]$fillCell) {
    for ($y = 0; $y -lt $this.Height; $y++) {
        for ($x = 0; $x -lt $this.Width; $x++) {
            $this.Cells[$y, $x].CopyFrom($fillCell)  # Instead of new object
        }
    }
}
```

### Priority 2: OPTIMIZE WRITESTRING CHARACTER PROCESSING

#### A) Batch Character Processing
```powershell
# Current: Character-by-character with individual cell creation
# Optimization: Process string as array, reuse template
[void] WriteString([int]$x, [int]$y, [string]$text, [hashtable]$style) {
    $template = $this.GetStyledTemplate($style)  # Create once
    $chars = $text.ToCharArray()
    $currentX = $x
    
    foreach ($char in $chars) {
        if ($currentX -ge $this.Width) { break }
        if ($currentX -ge 0) {
            $cell = $this.Cells[$y, $currentX]
            $cell.CopyFrom($template)  # Copy, don't create
            $cell.Char = $char
        }
        $currentX++
    }
}
```

### Priority 3: IMPLEMENT ANSI CACHING

#### A) Cache Common ANSI Sequences
```powershell
class AnsiCache {
    static [hashtable] $_cache = @{}
    
    static [string] GetCachedSequence([string]$fg, [string]$bg, [hashtable]$attrs) {
        $key = "$fg|$bg|$($attrs.GetHashCode())"
        if (-not $_cache.ContainsKey($key)) {
            $_cache[$key] = [TuiAnsiHelper]::GenerateSequence($fg, $bg, $attrs)
        }
        return $_cache[$key]
    }
}
```

### Priority 4: MEMORY LAYOUT OPTIMIZATION

#### A) Pre-allocate Everything
```powershell
# Buffer initialization should pre-allocate ALL cells
TuiBuffer([int]$width, [int]$height) {
    $this.Width = $width
    $this.Height = $height
    $this.Cells = New-Object 'TuiCell[,]' $height, $width
    
    # Pre-allocate ALL cells
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $this.Cells[$y, $x] = [TuiCell]::new()
        }
    }
    
    # Create pool for temporary operations
    $this._cellPool = @()
    for ($i = 0; $i -lt 100; $i++) {
        $this._cellPool += [TuiCell]::new()
    }
}
```

---

## 🎯 EXPECTED PERFORMANCE GAINS

Based on test results:

### Cell Creation Optimization:
- **Current**: 6,757 cells/sec
- **With pooling**: 45,455 cells/sec  
- **Improvement**: **6.7x faster**

### WriteString Optimization:
- **Current**: 114-578 ops/sec
- **With pooling + batch processing**: Est. 2,000-5,000 ops/sec
- **Improvement**: **5-10x faster**

### Buffer Clear Optimization:
- **Current**: 117ms for 80x24 buffer
- **With in-place updates**: Est. 10-20ms
- **Improvement**: **6-12x faster**

### Combined Frame Rate Impact:
- **Current**: 3.6 FPS (281ms per frame)
- **After optimizations**: Est. 30-60 FPS (16-33ms per frame)
- **Improvement**: **8-17x faster**

---

## 🔧 IMPLEMENTATION ORDER

1. **Fix TuiBuffer.Clear()** - Biggest single impact
2. **Implement cell pooling in WriteString** - Major throughput improvement  
3. **Add ANSI sequence caching** - Moderate but easy win
4. **Pre-allocate all buffer cells** - Memory efficiency
5. **Optimize string processing** - Final polish

## 🧪 SUCCESS METRICS

Target performance after optimizations:
- **Frame Rate**: 30+ FPS (vs current 3.6 FPS)
- **WriteString**: 2,000+ ops/sec (vs current 114/sec)
- **Buffer Clear**: <20ms (vs current 117ms)
- **Overall**: **10x+ performance improvement**

---

## 💡 KEY INSIGHTS

1. **Object creation is the killer** - Pre-allocation is 6.7x faster
2. **WriteString performance scales with string length** - Character processing overhead
3. **Buffer Clear is unexpectedly expensive** - Every cell gets new object
4. **ANSI generation is fixable** - Caching will help significantly
5. **Array access is fast** - The data structures aren't the problem

The path to 30+ FPS is clear and achievable with these optimizations.