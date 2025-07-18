#!/usr/bin/env pwsh
# ==============================================================================
# Axiom-Phoenix v4.0 - Optimization Validation Test
# Verify the performance improvements are working
# ==============================================================================

# Load optimized framework
. "./Base/ABC.001_TuiAnsiHelper.ps1"
. "./Base/ABC.002_TuiCell.ps1"
. "./Base/ABC.003_TuiBuffer.ps1"

Write-Host "🚀 OPTIMIZED PERFORMANCE TEST" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green
Write-Host ""

function Test-OptimizedClearPerformance {
    Write-Host "1. Testing Optimized Buffer.Clear() Performance" -ForegroundColor Yellow
    
    $buffer = [TuiBuffer]::new(80, 24)
    
    # Test multiple buffer sizes
    $sizes = @(
        @{ W=20; H=10; Name="Small" },
        @{ W=80; H=24; Name="Medium" },
        @{ W=120; H=40; Name="Large" }
    )
    
    foreach ($size in $sizes) {
        $testBuffer = [TuiBuffer]::new($size.W, $size.H)
        
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $i -lt 10; $i++) {
            $testBuffer.Clear()
        }
        $sw.Stop()
        
        $cellCount = $size.W * $size.H
        $totalCells = $cellCount * 10
        $cellsPerSec = $totalCells / ($sw.ElapsedMilliseconds / 1000)
        
        Write-Host "  $($size.Name) ($($size.W)x$($size.H)): $($sw.ElapsedMilliseconds)ms for 10 clears"
        Write-Host "    Average: $($sw.ElapsedMilliseconds/10)ms per clear"
        Write-Host "    Rate: $([Math]::Round($cellsPerSec, 0)) cells/sec"
    }
}

function Test-OptimizedWriteStringPerformance {
    Write-Host "2. Testing Optimized WriteString Performance" -ForegroundColor Yellow
    
    $buffer = [TuiBuffer]::new(100, 50)
    $style = @{ FG = "#FFFFFF"; BG = "#000000" }
    
    # Test different string operations
    $tests = @(
        @{ Count=100; String="Short"; Name="Short strings" },
        @{ Count=100; String="Medium length test string"; Name="Medium strings" },
        @{ Count=50; String="This is a very long string that will test the performance of character processing in the optimized WriteString method"; Name="Long strings" }
    )
    
    foreach ($test in $tests) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        
        for ($i = 0; $i -lt $test.Count; $i++) {
            $y = $i % 50
            $buffer.WriteString(0, $y, $test.String, $style)
        }
        
        $sw.Stop()
        $opsPerSec = $test.Count / ($sw.ElapsedMilliseconds / 1000)
        
        Write-Host "  $($test.Name): $($sw.ElapsedMilliseconds)ms for $($test.Count) operations"
        Write-Host "    Rate: $([Math]::Round($opsPerSec, 0)) ops/sec"
    }
}

function Test-OptimizedAnsiCaching {
    Write-Host "3. Testing ANSI Caching Performance" -ForegroundColor Yellow
    
    # Test common ANSI combinations
    $combinations = @(
        @{ FG="#FFFFFF"; BG="#000000"; Attrs=@{} },
        @{ FG="#FF0000"; BG="#000000"; Attrs=@{Bold=$true} },
        @{ FG="#00FF00"; BG="#000000"; Attrs=@{Italic=$true} },
        @{ FG="#0000FF"; BG="#FFFFFF"; Attrs=@{Bold=$true; Underline=$true} }
    )
    
    $iterations = 1000
    
    # First run to populate cache
    Write-Host "  Populating cache..."
    foreach ($combo in $combinations) {
        [TuiAnsiHelper]::GetAnsiSequence($combo.FG, $combo.BG, $combo.Attrs) | Out-Null
    }
    
    # Test cached performance
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $combo = $combinations[$i % $combinations.Count]
        [TuiAnsiHelper]::GetAnsiSequence($combo.FG, $combo.BG, $combo.Attrs) | Out-Null
    }
    $sw.Stop()
    
    $opsPerSec = $iterations / ($sw.ElapsedMilliseconds / 1000)
    Write-Host "  Cached ANSI generation: $($sw.ElapsedMilliseconds)ms for $iterations operations"
    Write-Host "    Rate: $([Math]::Round($opsPerSec, 0)) ops/sec"
}

function Test-OptimizedCellOperations {
    Write-Host "4. Testing Optimized Cell Operations" -ForegroundColor Yellow
    
    $iterations = 1000
    
    # Test CopyFrom vs new object creation
    $sourceCell = [TuiCell]::new('X', "#FF0000", "#000000", $true, $false, $true, $false)
    $targetCells = @()
    
    # Pre-allocate target cells
    for ($i = 0; $i -lt $iterations; $i++) {
        $targetCells += [TuiCell]::new()
    }
    
    # Test CopyFrom performance
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $targetCells[$i].CopyFrom($sourceCell)
    }
    $sw1.Stop()
    
    # Test Reset performance
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $targetCells[$i].Reset()
    }
    $sw2.Stop()
    
    Write-Host "  CopyFrom operations: $($sw1.ElapsedMilliseconds)ms for $iterations operations"
    Write-Host "    Rate: $([Math]::Round($iterations/($sw1.ElapsedMilliseconds/1000), 0)) ops/sec"
    Write-Host "  Reset operations: $($sw2.ElapsedMilliseconds)ms for $iterations operations"
    Write-Host "    Rate: $([Math]::Round($iterations/($sw2.ElapsedMilliseconds/1000), 0)) ops/sec"
}

function Test-OptimizedFrameRendering {
    Write-Host "5. Testing Complete Frame Rendering Performance" -ForegroundColor Yellow
    
    $buffer = [TuiBuffer]::new(80, 24)
    $style = @{ FG = "#FFFFFF"; BG = "#000000" }
    $frames = 10
    
    $frameTimes = @()
    
    Write-Host "  Rendering $frames frames..."
    
    for ($frame = 0; $frame -lt $frames; $frame++) {
        $frameWatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Clear buffer
        $buffer.Clear()
        
        # Write content to entire screen
        for ($y = 0; $y -lt 24; $y++) {
            $lineContent = "Frame $frame Line $y " + ("." * (55 - "Frame $frame Line $y ".Length))
            $buffer.WriteString(0, $y, $lineContent, $style)
        }
        
        $frameWatch.Stop()
        $frameTimes += $frameWatch.ElapsedMilliseconds
    }
    
    $totalTime = ($frameTimes | Measure-Object -Sum).Sum
    $avgFrameTime = ($frameTimes | Measure-Object -Average).Average
    $maxFrameTime = ($frameTimes | Measure-Object -Maximum).Maximum
    $minFrameTime = ($frameTimes | Measure-Object -Minimum).Minimum
    $frameRate = 1000 / $avgFrameTime
    
    Write-Host "  Frame rendering results:" -ForegroundColor Cyan
    Write-Host "    Total time: ${totalTime}ms for $frames frames"
    Write-Host "    Average frame time: $([Math]::Round($avgFrameTime, 2))ms"
    Write-Host "    Min frame time: $([Math]::Round($minFrameTime, 2))ms"
    Write-Host "    Max frame time: $([Math]::Round($maxFrameTime, 2))ms"
    Write-Host "    Effective frame rate: $([Math]::Round($frameRate, 1)) FPS" -ForegroundColor Green
    
    # Performance targets
    if ($frameRate -gt 30) {
        Write-Host "    ✅ EXCELLENT: >30 FPS achieved!" -ForegroundColor Green
    } elseif ($frameRate -gt 20) {
        Write-Host "    ✅ GOOD: >20 FPS achieved" -ForegroundColor Yellow
    } elseif ($frameRate -gt 10) {
        Write-Host "    ⚠️  ACCEPTABLE: >10 FPS" -ForegroundColor Yellow
    } else {
        Write-Host "    ❌ NEEDS MORE WORK: <10 FPS" -ForegroundColor Red
    }
    
    return $frameRate
}

function Show-ComparisonSummary {
    param([float]$currentFPS)
    
    Write-Host ""
    Write-Host "📊 PERFORMANCE COMPARISON" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host ""
    
    $baselineFPS = 3.6
    $improvement = $currentFPS / $baselineFPS
    
    Write-Host "Baseline Performance (before optimization):" -ForegroundColor White
    Write-Host "  Frame Rate: $baselineFPS FPS"
    Write-Host "  WriteString: ~114 ops/sec"
    Write-Host "  Buffer Clear: ~117ms"
    Write-Host ""
    
    Write-Host "Current Performance (after optimization):" -ForegroundColor Green
    Write-Host "  Frame Rate: $([Math]::Round($currentFPS, 1)) FPS"
    Write-Host ""
    
    Write-Host "Performance Improvement:" -ForegroundColor Yellow
    Write-Host "  Frame Rate: $([Math]::Round($improvement, 1))x faster" -ForegroundColor $(if ($improvement -gt 5) { "Green" } else { "Yellow" })
    
    if ($improvement -gt 10) {
        Write-Host ""
        Write-Host "🎉 MISSION ACCOMPLISHED: 10x+ improvement achieved!" -ForegroundColor Green
    } elseif ($improvement -gt 5) {
        Write-Host ""
        Write-Host "🎯 GREAT SUCCESS: 5x+ improvement achieved!" -ForegroundColor Green
    } elseif ($improvement -gt 2) {
        Write-Host ""
        Write-Host "👍 GOOD PROGRESS: Significant improvement made" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "🔧 NEEDS MORE WORK: Improvement not sufficient" -ForegroundColor Red
    }
}

# Run all tests
Test-OptimizedClearPerformance
Write-Host ""
Test-OptimizedWriteStringPerformance
Write-Host ""
Test-OptimizedAnsiCaching
Write-Host ""
Test-OptimizedCellOperations
Write-Host ""
$finalFPS = Test-OptimizedFrameRendering

Show-ComparisonSummary -currentFPS $finalFPS

Write-Host ""
Write-Host "Optimization testing complete!" -ForegroundColor Green