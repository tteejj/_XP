#!/usr/bin/env pwsh
# ==============================================================================
# Axiom-Phoenix v4.0 - Bottleneck Investigation
# Deep dive into the worst performing operations
# ==============================================================================

# Load framework
. "./Base/ABC.001_TuiAnsiHelper.ps1"
. "./Base/ABC.002_TuiCell.ps1"
. "./Base/ABC.003_TuiBuffer.ps1"

Write-Host "Bottleneck Deep Dive Analysis" -ForegroundColor Red
Write-Host "=============================" -ForegroundColor Red
Write-Host ""

Write-Host "CRITICAL FINDINGS from initial analysis:" -ForegroundColor Yellow
Write-Host "1. WriteString: Only 114 ops/sec - MASSIVE BOTTLENECK" -ForegroundColor Red
Write-Host "2. Buffer Clear: 108ms per clear - WAY too slow" -ForegroundColor Red  
Write-Host "3. ANSI Generation: 1,381/sec - Major bottleneck" -ForegroundColor Red
Write-Host "4. Frame Rate: 3.6 FPS - Unacceptable" -ForegroundColor Red
Write-Host ""

function Investigate-WriteStringBottleneck {
    Write-Host "🔍 WriteString Bottleneck Investigation" -ForegroundColor Cyan
    
    $buffer = [TuiBuffer]::new(100, 50)
    $style = @{ FG = "#FFFFFF"; BG = "#000000" }
    
    # Test different string lengths
    $shortString = "Hi"
    $mediumString = "Medium length string"
    $longString = "This is a very long string that might cause performance issues due to character processing overhead"
    
    Write-Host "Testing different string lengths:" -ForegroundColor Yellow
    
    # Short strings
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++) {
        $buffer.WriteString(0, $i % 50, $shortString, $style)
    }
    $sw1.Stop()
    
    # Medium strings  
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++) {
        $buffer.WriteString(0, $i % 50, $mediumString, $style)
    }
    $sw2.Stop()
    
    # Long strings
    $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++) {
        $buffer.WriteString(0, $i % 50, $longString, $style)
    }
    $sw3.Stop()
    
    Write-Host "  Short strings (2 chars): $($sw1.ElapsedMilliseconds)ms ($([Math]::Round(100/$sw1.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Medium strings (20 chars): $($sw2.ElapsedMilliseconds)ms ($([Math]::Round(100/$sw2.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Long strings (95 chars): $($sw3.ElapsedMilliseconds)ms ($([Math]::Round(100/$sw3.ElapsedMilliseconds*1000,0))/sec)"
    
    # Test style processing overhead
    Write-Host "Testing style processing overhead:" -ForegroundColor Yellow
    
    $emptyStyle = @{}
    $simpleStyle = @{ FG = "#FFFFFF" }
    $complexStyle = @{ FG = "#FF0000"; BG = "#000000"; Bold = $true; Italic = $true; Underline = $true }
    
    $testString = "Test string"
    
    $sw4 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++) {
        $buffer.WriteString(0, $i % 50, $testString, $emptyStyle)
    }
    $sw4.Stop()
    
    $sw5 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++) {
        $buffer.WriteString(0, $i % 50, $testString, $simpleStyle)
    }
    $sw5.Stop()
    
    $sw6 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++) {
        $buffer.WriteString(0, $i % 50, $testString, $complexStyle)
    }
    $sw6.Stop()
    
    Write-Host "  Empty style: $($sw4.ElapsedMilliseconds)ms ($([Math]::Round(100/$sw4.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Simple style: $($sw5.ElapsedMilliseconds)ms ($([Math]::Round(100/$sw5.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Complex style: $($sw6.ElapsedMilliseconds)ms ($([Math]::Round(100/$sw6.ElapsedMilliseconds*1000,0))/sec)"
}

function Investigate-BufferClearBottleneck {
    Write-Host "🔍 Buffer Clear Bottleneck Investigation" -ForegroundColor Cyan
    
    # Test different buffer sizes
    $smallBuffer = [TuiBuffer]::new(20, 10)
    $mediumBuffer = [TuiBuffer]::new(80, 24)
    $largeBuffer = [TuiBuffer]::new(120, 40)
    
    Write-Host "Testing different buffer sizes:" -ForegroundColor Yellow
    
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 10; $i++) {
        $smallBuffer.Clear()
    }
    $sw1.Stop()
    
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 10; $i++) {
        $mediumBuffer.Clear()
    }
    $sw2.Stop()
    
    $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 10; $i++) {
        $largeBuffer.Clear()
    }
    $sw3.Stop()
    
    Write-Host "  Small (20x10=200 cells): $($sw1.ElapsedMilliseconds)ms (avg: $($sw1.ElapsedMilliseconds/10)ms)"
    Write-Host "  Medium (80x24=1920 cells): $($sw2.ElapsedMilliseconds)ms (avg: $($sw2.ElapsedMilliseconds/10)ms)"
    Write-Host "  Large (120x40=4800 cells): $($sw3.ElapsedMilliseconds)ms (avg: $($sw3.ElapsedMilliseconds/10)ms)"
    
    # Calculate cells per second for clear operation
    $smallCellsPerSec = (200 * 10) / ($sw1.ElapsedMilliseconds / 1000)
    $mediumCellsPerSec = (1920 * 10) / ($sw2.ElapsedMilliseconds / 1000)
    $largeCellsPerSec = (4800 * 10) / ($sw3.ElapsedMilliseconds / 1000)
    
    Write-Host "  Small clear rate: $([Math]::Round($smallCellsPerSec, 0)) cells/sec"
    Write-Host "  Medium clear rate: $([Math]::Round($mediumCellsPerSec, 0)) cells/sec"
    Write-Host "  Large clear rate: $([Math]::Round($largeCellsPerSec, 0)) cells/sec"
}

function Investigate-AnsiGenerationBottleneck {
    Write-Host "🔍 ANSI Generation Bottleneck Investigation" -ForegroundColor Cyan
    
    # Test what's slow in ANSI generation
    $simpleCell = [TuiCell]::new('A')
    $colorCell = [TuiCell]::new('B', "#FF0000", "#000000")
    $styledCell = [TuiCell]::new('C', "#FF0000", "#000000", $true, $false, $false, $false)
    $complexCell = [TuiCell]::new('D', "#FF0000", "#000000", $true, $true, $true, $true)
    
    $iterations = 500
    
    Write-Host "Testing ANSI generation complexity:" -ForegroundColor Yellow
    
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $ansi = $simpleCell.ToAnsiString()
    }
    $sw1.Stop()
    
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $ansi = $colorCell.ToAnsiString()
    }
    $sw2.Stop()
    
    $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $ansi = $styledCell.ToAnsiString()
    }
    $sw3.Stop()
    
    $sw4 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $ansi = $complexCell.ToAnsiString()
    }
    $sw4.Stop()
    
    Write-Host "  Simple cell: $($sw1.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw1.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Color cell: $($sw2.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw2.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Styled cell: $($sw3.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw3.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Complex cell: $($sw4.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw4.ElapsedMilliseconds*1000,0))/sec)"
    
    # Test the ansi helper directly
    Write-Host "Testing TuiAnsiHelper directly:" -ForegroundColor Yellow
    
    $attributes = @{ Bold=$true; Italic=$true; Underline=$true; Strikethrough=$true }
    
    $sw5 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $sequence = [TuiAnsiHelper]::GetAnsiSequence("#FF0000", "#000000", $attributes)
    }
    $sw5.Stop()
    
    Write-Host "  Direct ANSI helper: $($sw5.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw5.ElapsedMilliseconds*1000,0))/sec)"
}

function Test-OptimizationStrategies {
    Write-Host "🚀 Testing Optimization Strategies" -ForegroundColor Green
    
    # Strategy 1: Pre-allocate cells
    Write-Host "Strategy 1: Cell pre-allocation" -ForegroundColor Yellow
    
    $cellPool = @()
    for ($i = 0; $i -lt 1000; $i++) {
        $cellPool += [TuiCell]::new()
    }
    
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 1000; $i++) {
        $cell = $cellPool[$i]
        $cell.Char = [char](65 + ($i % 26))
    }
    $sw1.Stop()
    
    Write-Host "  Reusing pre-allocated cells: $($sw1.ElapsedMilliseconds)ms ($([Math]::Round(1000/$sw1.ElapsedMilliseconds*1000,0))/sec)"
    
    # Strategy 2: Batch operations
    Write-Host "Strategy 2: Batch operations" -ForegroundColor Yellow
    
    $buffer = [TuiBuffer]::new(80, 24)
    
    # Test individual SetCell vs batch
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++) {
        $x = $i % 80
        $y = ($i / 80) % 24
        $cell = [TuiCell]::new([char](65 + ($i % 26)))
        $buffer.SetCell($x, $y, $cell)
    }
    $sw2.Stop()
    
    Write-Host "  Individual SetCell operations: $($sw2.ElapsedMilliseconds)ms"
    
    # Strategy 3: String building optimization
    Write-Host "Strategy 3: String optimization" -ForegroundColor Yellow
    
    $chars = 'A'..'Z'
    
    # Test string building methods
    $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++) {
        $line = ""
        for ($j = 0; $j -lt 80; $j++) {
            $line += $chars[$j % 26]
        }
    }
    $sw3.Stop()
    
    $sw4 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++) {
        $sb = [System.Text.StringBuilder]::new(80)
        for ($j = 0; $j -lt 80; $j++) {
            [void]$sb.Append($chars[$j % 26])
        }
        $line = $sb.ToString()
    }
    $sw4.Stop()
    
    Write-Host "  String concatenation: $($sw3.ElapsedMilliseconds)ms"
    Write-Host "  StringBuilder: $($sw4.ElapsedMilliseconds)ms"
}

# Run investigations
Investigate-WriteStringBottleneck
Write-Host ""
Investigate-BufferClearBottleneck
Write-Host ""
Investigate-AnsiGenerationBottleneck
Write-Host ""
Test-OptimizationStrategies
Write-Host ""

Write-Host "🎯 OPTIMIZATION PRIORITIES:" -ForegroundColor Red
Write-Host "1. WriteString performance (current: ~114/sec)" -ForegroundColor Red
Write-Host "2. Buffer Clear performance (current: ~108ms)" -ForegroundColor Red
Write-Host "3. ANSI generation caching (current: ~1381/sec)" -ForegroundColor Red
Write-Host "4. Cell object creation overhead" -ForegroundColor Red