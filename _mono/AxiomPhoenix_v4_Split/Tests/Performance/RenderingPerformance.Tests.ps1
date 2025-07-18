# ==============================================================================
# Axiom-Phoenix v4.0 - Rendering Performance Tests
# Performance benchmarking for rendering and buffer operations
# ==============================================================================

# Import the framework dependencies in correct order
$testRoot = $PSScriptRoot
if (-not $testRoot) { 
    $testRoot = Split-Path $MyInvocation.MyCommand.Path 
}
$frameworkRoot = Split-Path (Split-Path $testRoot -Parent) -Parent

# Load dependencies with explicit error handling
try {
    . (Join-Path $frameworkRoot "Base/ABC.001_TuiAnsiHelper.ps1")
    . (Join-Path $frameworkRoot "Base/ABC.002_TuiCell.ps1")
    . (Join-Path $frameworkRoot "Base/ABC.003_TuiBuffer.ps1")
} catch {
    Write-Host "Failed to load framework dependencies: $_" -ForegroundColor Red
    throw
}

Describe "Rendering Performance Tests" {
    Context "Buffer Writing Performance" {
        It "Should write single characters efficiently" {
            $buffer = [TuiBuffer]::new(80, 24)
            $iterations = 1000
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $x = $i % 80
                $y = ($i / 80) % 24
                $buffer.WriteCharacter($x, $y, [char](65 + ($i % 26)))
            }
            
            $stopwatch.Stop()
            
            # Should complete 1000 character writes in under 50ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 50
            
            Write-Host "Single character writes: $($stopwatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
        }
        
        It "Should write strings efficiently" {
            $buffer = [TuiBuffer]::new(120, 30)
            $testString = "Performance test string with various characters 123!@#"
            $iterations = 100
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $y = $i % 30
                $buffer.WriteString(0, $y, $testString)
            }
            
            $stopwatch.Stop()
            
            # Should complete 100 string writes in under 100ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 100
            
            Write-Host "String writes: $($stopwatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
        }
        
        It "Should write colored strings efficiently" {
            $buffer = [TuiBuffer]::new(100, 25)
            $testString = "Colored performance test"
            $iterations = 200
            $colors = @([ConsoleColor]::Red, [ConsoleColor]::Green, [ConsoleColor]::Blue, [ConsoleColor]::Yellow)
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $x = ($i * 25) % 76  # Vary position
                $y = $i % 25
                $fgColor = $colors[$i % 4]
                $bgColor = $colors[($i + 2) % 4]
                $buffer.WriteString($x, $y, $testString, $fgColor, $bgColor)
            }
            
            $stopwatch.Stop()
            
            # Should complete 200 colored string writes in under 150ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 150
            
            Write-Host "Colored string writes: $($stopwatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
        }
    }
    
    Context "Buffer Operations Performance" {
        It "Should clear buffer efficiently" {
            $buffer = [TuiBuffer]::new(120, 40)
            
            # Fill buffer with content first
            for ($y = 0; $y -lt 40; $y++) {
                $buffer.WriteString(0, $y, "X" * 120)
            }
            
            $iterations = 50
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $buffer.Clear()
                # Refill to make clear actually work
                if ($i -lt $iterations - 1) {
                    $buffer.WriteString(0, 0, "Test")
                }
            }
            
            $stopwatch.Stop()
            
            # Should complete 50 buffer clears in under 100ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 100
            
            Write-Host "Buffer clears: $($stopwatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
        }
        
        It "Should resize buffer efficiently" {
            $buffer = [TuiBuffer]::new(50, 20)
            $iterations = 20
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $newWidth = 80 + ($i % 40)
                $newHeight = 24 + ($i % 16)
                $buffer.Resize($newWidth, $newHeight)
            }
            
            $stopwatch.Stop()
            
            # Should complete 20 buffer resizes in under 200ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 200
            
            Write-Host "Buffer resizes: $($stopwatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
        }
        
        It "Should copy buffer regions efficiently" {
            $source = [TuiBuffer]::new(100, 50)
            $target = [TuiBuffer]::new(100, 50)
            
            # Fill source with test data
            for ($y = 0; $y -lt 50; $y++) {
                $source.WriteString(0, $y, "Source line $y with test content")
            }
            
            $iterations = 25
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $target.CopyFrom($source)
            }
            
            $stopwatch.Stop()
            
            # Should complete 25 full buffer copies in under 150ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 150
            
            Write-Host "Buffer copies: $($stopwatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
        }
    }
    
    Context "Memory Allocation Performance" {
        It "Should create TuiCells efficiently" {
            $iterations = 10000
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $cells = @()
            for ($i = 0; $i -lt $iterations; $i++) {
                $cells += [TuiCell]::new()
            }
            
            $stopwatch.Stop()
            
            # Should create 10,000 cells in under 200ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 200
            
            Write-Host "TuiCell creation: $($stopwatch.ElapsedMilliseconds)ms for $iterations cells" -ForegroundColor Cyan
            
            # Verify we actually created the cells
            $cells.Count | Should -Be $iterations
        }
        
        It "Should create buffers efficiently" {
            $iterations = 100
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $buffers = @()
            for ($i = 0; $i -lt $iterations; $i++) {
                $width = 80 + ($i % 40)
                $height = 24 + ($i % 16)
                $buffers += [TuiBuffer]::new($width, $height)
            }
            
            $stopwatch.Stop()
            
            # Should create 100 buffers in under 500ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 500
            
            Write-Host "TuiBuffer creation: $($stopwatch.ElapsedMilliseconds)ms for $iterations buffers" -ForegroundColor Cyan
            
            # Verify we actually created the buffers
            $buffers.Count | Should -Be $iterations
        }
    }
    
    Context "Dirty Cell Tracking Performance" {
        It "Should track dirty cells efficiently" {
            $buffer = [TuiBuffer]::new(100, 50)
            $iterations = 1000
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $x = $i % 100
                $y = ($i / 100) % 50
                $buffer.WriteCharacter($x, $y, 'D')
                
                # Check dirty state every 10 operations
                if ($i % 10 -eq 0) {
                    $hasDirty = $buffer.HasDirtyCells()
                }
            }
            
            $stopwatch.Stop()
            
            # Should complete dirty tracking operations in under 100ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 100
            
            Write-Host "Dirty cell tracking: $($stopwatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
        }
        
        It "Should clear dirty flags efficiently" {
            $buffer = [TuiBuffer]::new(120, 30)
            
            # Make many cells dirty
            for ($y = 0; $y -lt 30; $y++) {
                $buffer.WriteString(0, $y, "X" * 120)
            }
            
            $iterations = 50
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $buffer.ClearDirtyFlags()
                # Make some cells dirty again for next iteration
                if ($i -lt $iterations - 1) {
                    $buffer.WriteString(0, 0, "Test")
                }
            }
            
            $stopwatch.Stop()
            
            # Should complete 50 dirty flag clears in under 75ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 75
            
            Write-Host "Dirty flag clears: $($stopwatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
        }
    }
    
    Context "Large Buffer Performance" {
        It "Should handle large buffers efficiently" {
            $largeBuffer = [TuiBuffer]::new(200, 100)  # Large terminal buffer
            $testData = "Large buffer performance test " * 5  # ~150 chars
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Fill entire large buffer
            for ($y = 0; $y -lt 100; $y++) {
                $buffer.WriteString(0, $y, $testData.Substring(0, [Math]::Min($testData.Length, 200)))
            }
            
            $stopwatch.Stop()
            
            # Should fill large buffer (20,000 cells) in under 300ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 300
            
            Write-Host "Large buffer fill: $($stopwatch.ElapsedMilliseconds)ms for 200x100 buffer" -ForegroundColor Cyan
        }
        
        It "Should read from large buffers efficiently" {
            $largeBuffer = [TuiBuffer]::new(150, 80)
            
            # Fill with test data
            for ($y = 0; $y -lt 80; $y++) {
                $largeBuffer.WriteString(0, $y, "Line ${y}: " + ("X" * 140))
            }
            
            $iterations = 500
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $y = $i % 80
                $text = $largeBuffer.GetStringAt(0, $y, 50)
            }
            
            $stopwatch.Stop()
            
            # Should complete 500 reads from large buffer in under 50ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 50
            
            Write-Host "Large buffer reads: $($stopwatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
        }
    }
    
    Context "Overall Performance Benchmark" {
        It "Should maintain acceptable frame rate simulation" {
            $buffer = [TuiBuffer]::new(120, 30)
            $frames = 60  # Simulate 60 frames
            $targetFrameTime = 16.67  # ~60 FPS (16.67ms per frame)
            
            $totalTime = 0
            $frameTimings = @()
            
            for ($frame = 0; $frame -lt $frames; $frame++) {
                $frameWatch = [System.Diagnostics.Stopwatch]::StartNew()
                
                # Simulate typical frame operations
                $buffer.Clear()
                
                # Simulate UI rendering
                for ($y = 0; $y -lt 30; $y++) {
                    $lineContent = "Frame $frame Line $y " + ("." * (80 - 20))
                    $buffer.WriteString(0, $y, $lineContent.Substring(0, [Math]::Min($lineContent.Length, 120)))
                }
                
                # Simulate some color changes
                for ($i = 0; $i -lt 20; $i++) {
                    $x = $i * 6
                    $y = 15
                    $buffer.WriteString($x, $y, "CLR", [ConsoleColor]::Red, [ConsoleColor]::Black)
                }
                
                $frameWatch.Stop()
                $frameTime = $frameWatch.ElapsedMilliseconds
                $frameTimings += $frameTime
                $totalTime += $frameTime
            }
            
            $averageFrameTime = $totalTime / $frames
            $maxFrameTime = ($frameTimings | Measure-Object -Maximum).Maximum
            $frameRate = 1000 / $averageFrameTime
            
            Write-Host "Frame simulation results:" -ForegroundColor Yellow
            Write-Host "  Average frame time: $([Math]::Round($averageFrameTime, 2))ms" -ForegroundColor Cyan
            Write-Host "  Max frame time: $([Math]::Round($maxFrameTime, 2))ms" -ForegroundColor Cyan
            Write-Host "  Effective frame rate: $([Math]::Round($frameRate, 1)) FPS" -ForegroundColor Cyan
            Write-Host "  Total time for $frames frames: $([Math]::Round($totalTime, 2))ms" -ForegroundColor Cyan
            
            # Should maintain reasonable frame rate (at least 30 FPS average)
            $frameRate | Should -BeGreaterThan 30
            
            # No single frame should take longer than 33ms (30 FPS minimum)
            $maxFrameTime | Should -BeLessThan 33
        }
    }
}

Write-Host "Rendering performance tests loaded" -ForegroundColor Green