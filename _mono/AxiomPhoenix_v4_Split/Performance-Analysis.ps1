#!/usr/bin/env pwsh
# ==============================================================================
# Axiom-Phoenix v4.0 - Performance Analysis
# Detailed profiling to identify bottlenecks
# ==============================================================================

# Load framework
. "./Base/ABC.001_TuiAnsiHelper.ps1"
. "./Base/ABC.002_TuiCell.ps1"
. "./Base/ABC.003_TuiBuffer.ps1"

Write-Host "Performance Bottleneck Analysis" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

function Test-CellCreationMethods {
    Write-Host "1. Cell Creation Method Comparison" -ForegroundColor Yellow
    
    $iterations = 1000
    
    # Method 1: Direct constructor
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $cell = [TuiCell]::new()
    }
    $sw1.Stop()
    
    # Method 2: Constructor with char
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $cell = [TuiCell]::new([char]'A')
    }
    $sw2.Stop()
    
    # Method 3: Full constructor
    $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $cell = [TuiCell]::new('A', "#FF0000", "#000000")
    }
    $sw3.Stop()
    
    Write-Host "  Default constructor: $($sw1.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw1.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Char constructor: $($sw2.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw2.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Full constructor: $($sw3.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw3.ElapsedMilliseconds*1000,0))/sec)"
}

function Test-BufferOperations {
    Write-Host "2. Buffer Operation Breakdown" -ForegroundColor Yellow
    
    $buffer = [TuiBuffer]::new(100, 50)
    $cell = [TuiCell]::new('X', "#FF0000", "#000000")
    $iterations = 1000
    
    # Test SetCell performance
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $x = $i % 100
        $y = ($i / 100) % 50
        $buffer.SetCell($x, $y, $cell)
    }
    $sw1.Stop()
    
    # Test GetCell performance
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $x = $i % 100
        $y = ($i / 100) % 50
        $retrieved = $buffer.GetCell($x, $y)
    }
    $sw2.Stop()
    
    # Test WriteString performance
    $style = @{ FG = "#FFFFFF"; BG = "#000000" }
    $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++) {
        $y = $i % 50
        $buffer.WriteString(0, $y, "Test string for performance", $style)
    }
    $sw3.Stop()
    
    Write-Host "  SetCell (1000 ops): $($sw1.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw1.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  GetCell (1000 ops): $($sw2.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw2.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  WriteString (100 ops): $($sw3.ElapsedMilliseconds)ms ($([Math]::Round(100/$sw3.ElapsedMilliseconds*1000,0))/sec)"
}

function Test-AnsiGeneration {
    Write-Host "3. ANSI Generation Performance" -ForegroundColor Yellow
    
    $iterations = 1000
    
    # Test simple cell ANSI generation
    $cell = [TuiCell]::new('A', "#FF0000", "#000000")
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $ansi = $cell.ToAnsiString()
    }
    $sw1.Stop()
    
    # Test complex cell ANSI generation
    $complexCell = [TuiCell]::new('B', "#FF0000", "#000000", $true, $true, $true, $true)
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $ansi = $complexCell.ToAnsiString()
    }
    $sw2.Stop()
    
    Write-Host "  Simple ANSI: $($sw1.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw1.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Complex ANSI: $($sw2.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw2.ElapsedMilliseconds*1000,0))/sec)"
}

function Test-StringOperations {
    Write-Host "4. String Operation Impact" -ForegroundColor Yellow
    
    $iterations = 1000
    
    # Test string concatenation
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $str = "Frame " + $i + " content " + ("x" * 20)
    }
    $sw1.Stop()
    
    # Test string interpolation
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $str = "Frame $i content " + ("x" * 20)
    }
    $sw2.Stop()
    
    # Test StringBuilder
    $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append("Frame ")
        [void]$sb.Append($i)
        [void]$sb.Append(" content ")
        [void]$sb.Append("x" * 20)
        $str = $sb.ToString()
    }
    $sw3.Stop()
    
    Write-Host "  String concatenation: $($sw1.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw1.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  String interpolation: $($sw2.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw2.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  StringBuilder: $($sw3.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw3.ElapsedMilliseconds*1000,0))/sec)"
}

function Test-CellBlending {
    Write-Host "5. Cell Blending Performance" -ForegroundColor Yellow
    
    $iterations = 1000
    
    $bottomCell = [TuiCell]::new('A', "#FF0000", "#000000")
    $bottomCell.ZIndex = 1
    $topCell = [TuiCell]::new('B', "#00FF00", "#FFFFFF")
    $topCell.ZIndex = 2
    
    # Test immutable blending
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $result = $bottomCell.BlendWith($topCell)
    }
    $sw1.Stop()
    
    # Test mutable blending
    $testCell = [TuiCell]::new($bottomCell)
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $testCell.BlendWithMutable($topCell)
        # Reset for next iteration
        $testCell = [TuiCell]::new($bottomCell)
    }
    $sw2.Stop()
    
    Write-Host "  Immutable blending: $($sw1.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw1.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  Mutable blending: $($sw2.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw2.ElapsedMilliseconds*1000,0))/sec)"
}

function Test-FrameRenderingBreakdown {
    Write-Host "6. Frame Rendering Breakdown" -ForegroundColor Yellow
    
    $buffer = [TuiBuffer]::new(80, 24)
    $style = @{ FG = "#FFFFFF"; BG = "#000000" }
    
    # Test buffer clear
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 10; $i++) {
        $buffer.Clear()
    }
    $sw1.Stop()
    
    # Test line writing
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 10; $i++) {
        for ($y = 0; $y -lt 24; $y++) {
            $buffer.WriteString(0, $y, "Line $y content " + ("." * 50), $style)
        }
    }
    $sw2.Stop()
    
    # Test full frame (clear + write)
    $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($frame = 0; $frame -lt 10; $frame++) {
        $buffer.Clear()
        for ($y = 0; $y -lt 24; $y++) {
            $buffer.WriteString(0, $y, "Frame $frame Line $y " + ("." * 50), $style)
        }
    }
    $sw3.Stop()
    
    Write-Host "  Buffer clear (10x): $($sw1.ElapsedMilliseconds)ms (avg: $($sw1.ElapsedMilliseconds/10)ms)"
    Write-Host "  Line writing (10x24 lines): $($sw2.ElapsedMilliseconds)ms (avg: $($sw2.ElapsedMilliseconds/240)ms per line)"
    Write-Host "  Full frame (10 frames): $($sw3.ElapsedMilliseconds)ms (avg: $($sw3.ElapsedMilliseconds/10)ms per frame)"
    Write-Host "  Implied FPS: $([Math]::Round(10000/$sw3.ElapsedMilliseconds, 1))"
}

function Test-ArrayAccess {
    Write-Host "7. Array Access Performance" -ForegroundColor Yellow
    
    $iterations = 1000
    
    # Create a 2D array similar to TuiBuffer
    $width = 100
    $height = 50
    $array2D = New-Object 'object[,]' $height, $width
    
    # Fill with test data
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $array2D[$y, $x] = [TuiCell]::new()
        }
    }
    
    # Test 2D array access
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $x = $i % $width
        $y = ($i / $width) % $height
        $cell = $array2D[$y, $x]
    }
    $sw1.Stop()
    
    # Test 2D array write
    $testCell = [TuiCell]::new('X')
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $iterations; $i++) {
        $x = $i % $width
        $y = ($i / $width) % $height
        $array2D[$y, $x] = $testCell
    }
    $sw2.Stop()
    
    Write-Host "  2D array read: $($sw1.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw1.ElapsedMilliseconds*1000,0))/sec)"
    Write-Host "  2D array write: $($sw2.ElapsedMilliseconds)ms ($([Math]::Round($iterations/$sw2.ElapsedMilliseconds*1000,0))/sec)"
}

# Run all tests
Test-CellCreationMethods
Write-Host ""
Test-BufferOperations
Write-Host ""
Test-AnsiGeneration
Write-Host ""
Test-StringOperations
Write-Host ""
Test-CellBlending
Write-Host ""
Test-FrameRenderingBreakdown
Write-Host ""
Test-ArrayAccess
Write-Host ""

Write-Host "Analysis Complete" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "Review the results above to identify the biggest bottlenecks." -ForegroundColor Yellow