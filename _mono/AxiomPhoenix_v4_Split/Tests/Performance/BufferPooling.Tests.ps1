# ==============================================================================
# Axiom-Phoenix v4.0 - Buffer Pooling Performance Tests
# Performance testing for object pooling and memory optimization
# ==============================================================================

# Import the framework
$scriptDir = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $scriptDir "Base/ABC.002_TuiCell.ps1")
. (Join-Path $scriptDir "Base/ABC.003_TuiBuffer.ps1")
. (Join-Path $scriptDir "Base/ABC.007_BufferPool.ps1")

Describe "Buffer Pooling Performance Tests" {
    Context "TuiCell Pool Performance" {
        It "Should rent cells faster than creating new ones" {
            $pool = [TuiCellBufferPool]::new(1000)
            $iterations = 5000
            
            # Test pool performance
            $poolWatch = [System.Diagnostics.Stopwatch]::StartNew()
            $pooledCells = @()
            for ($i = 0; $i -lt $iterations; $i++) {
                $pooledCells += $pool.Rent()
            }
            $poolWatch.Stop()
            
            # Test direct creation performance
            $directWatch = [System.Diagnostics.Stopwatch]::StartNew()
            $directCells = @()
            for ($i = 0; $i -lt $iterations; $i++) {
                $directCells += [TuiCell]::new()
            }
            $directWatch.Stop()
            
            Write-Host "Pool vs Direct Creation Results:" -ForegroundColor Yellow
            Write-Host "  Pool rental: $($poolWatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
            Write-Host "  Direct creation: $($directWatch.ElapsedMilliseconds)ms for $iterations operations" -ForegroundColor Cyan
            Write-Host "  Pool speedup: $([Math]::Round($directWatch.ElapsedMilliseconds / $poolWatch.ElapsedMilliseconds, 2))x" -ForegroundColor Green
            
            # Pool should be at least as fast as direct creation (usually faster due to pre-allocation)
            $poolWatch.ElapsedMilliseconds | Should -BeLessOrEqual $directWatch.ElapsedMilliseconds
            
            # Return cells to pool for cleanup
            foreach ($cell in $pooledCells) {
                $pool.Return($cell)
            }
        }
        
        It "Should maintain good hit rate under load" {
            $pool = [TuiCellBufferPool]::new(500)
            $iterations = 2000
            $cells = @()
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Rent and return cells in various patterns
            for ($i = 0; $i -lt $iterations; $i++) {
                if ($i % 3 -eq 0 -and $cells.Count -gt 0) {
                    # Return some cells
                    $toReturn = [Math]::Min(10, $cells.Count)
                    for ($j = 0; $j -lt $toReturn; $j++) {
                        $pool.Return($cells[$j])
                        $cells = $cells[1..($cells.Count-1)]
                    }
                } else {
                    # Rent more cells
                    $cells += $pool.Rent()
                }
            }
            
            $stopwatch.Stop()
            
            # Return remaining cells
            foreach ($cell in $cells) {
                $pool.Return($cell)
            }
            
            $stats = $pool.GetStatistics()
            
            Write-Host "Pool performance under load:" -ForegroundColor Yellow
            Write-Host "  Operations completed in: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
            Write-Host "  Pool hit rate: $($stats.PoolHitRate)%" -ForegroundColor Cyan
            Write-Host "  Total rents: $($stats.RentCount)" -ForegroundColor Cyan
            Write-Host "  Total returns: $($stats.ReturnCount)" -ForegroundColor Cyan
            Write-Host "  New creations: $($stats.CreateCount)" -ForegroundColor Cyan
            
            # Should maintain reasonable hit rate (>50%) under mixed load
            $stats.PoolHitRate | Should -BeGreaterThan 50
            
            # Should complete operations in reasonable time
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 500
        }
        
        It "Should handle burst allocations efficiently" {
            $pool = [TuiCellBufferPool]::new(200)
            $burstSize = 150
            $bursts = 10
            
            $totalTime = 0
            
            for ($burst = 0; $burst -lt $bursts; $burst++) {
                $burstWatch = [System.Diagnostics.Stopwatch]::StartNew()
                
                # Allocate burst
                $cells = @()
                for ($i = 0; $i -lt $burstSize; $i++) {
                    $cells += $pool.Rent()
                }
                
                # Use cells (simulate work)
                foreach ($cell in $cells) {
                    $cell.SetCharacter([char](65 + ($burst % 26)))
                }
                
                # Return all cells
                foreach ($cell in $cells) {
                    $pool.Return($cell)
                }
                
                $burstWatch.Stop()
                $totalTime += $burstWatch.ElapsedMilliseconds
                
                Write-Verbose "Burst $burst completed in $($burstWatch.ElapsedMilliseconds)ms"
            }
            
            $averageBurstTime = $totalTime / $bursts
            
            Write-Host "Burst allocation results:" -ForegroundColor Yellow
            Write-Host "  Total time for $bursts bursts: $($totalTime)ms" -ForegroundColor Cyan
            Write-Host "  Average burst time: $([Math]::Round($averageBurstTime, 2))ms" -ForegroundColor Cyan
            Write-Host "  Burst size: $burstSize cells" -ForegroundColor Cyan
            
            # Each burst should complete in reasonable time
            $averageBurstTime | Should -BeLessThan 50
            
            $stats = $pool.GetStatistics()
            Write-Host "  Final hit rate: $($stats.PoolHitRate)%" -ForegroundColor Cyan
        }
    }
    
    Context "PooledTuiBuffer Performance" {
        It "Should create pooled buffers efficiently" {
            $bufferPoolService = [BufferPoolService]::new()
            $bufferPoolService.Initialize()
            
            $iterations = 50
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $buffers = @()
            for ($i = 0; $i -lt $iterations; $i++) {
                $width = 80 + ($i % 40)
                $height = 24 + ($i % 16)
                $buffers += $bufferPoolService.CreatePooledBuffer($width, $height)
            }
            
            $stopwatch.Stop()
            
            Write-Host "Pooled buffer creation: $($stopwatch.ElapsedMilliseconds)ms for $iterations buffers" -ForegroundColor Cyan
            
            # Should create buffers efficiently
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 200
            
            # Cleanup
            foreach ($buffer in $buffers) {
                $buffer.Dispose()
            }
            $bufferPoolService.Dispose()
        }
        
        It "Should reuse pooled cells effectively" {
            $bufferPoolService = [BufferPoolService]::new()
            $bufferPoolService.Initialize()
            
            $buffer1 = $bufferPoolService.CreatePooledBuffer(100, 25)
            $buffer2 = $bufferPoolService.CreatePooledBuffer(100, 25)
            
            # Fill buffers to ensure cells are used
            for ($y = 0; $y -lt 25; $y++) {
                $buffer1.WriteString(0, $y, "Buffer 1 Line $y")
                $buffer2.WriteString(0, $y, "Buffer 2 Line $y")
            }
            
            # Dispose first buffer (returns cells to pool)
            $buffer1.Dispose()
            
            # Create new buffer (should reuse cells)
            $buffer3 = $bufferPoolService.CreatePooledBuffer(100, 25)
            
            $poolStats = $bufferPoolService.GetStatistics()
            
            Write-Host "Cell pool reuse stats:" -ForegroundColor Yellow
            Write-Host "  Pool hit rate: $($poolStats.CellPool.PoolHitRate)%" -ForegroundColor Cyan
            Write-Host "  Pool size: $($poolStats.CellPool.PoolSize)" -ForegroundColor Cyan
            Write-Host "  Total rents: $($poolStats.CellPool.RentCount)" -ForegroundColor Cyan
            
            # Should show evidence of cell reuse
            $poolStats.CellPool.PoolHitRate | Should -BeGreaterThan 0
            
            # Cleanup
            $buffer2.Dispose()
            $buffer3.Dispose()
            $bufferPoolService.Dispose()
        }
    }
    
    Context "Memory Pressure Testing" {
        It "Should handle memory pressure gracefully" {
            $pool = [TuiCellBufferPool]::new(100)  # Small pool
            $iterations = 1000  # Many allocations
            
            $initialMemory = [GC]::GetTotalMemory($true)
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Allocate more than pool can hold
            $cells = @()
            for ($i = 0; $i -lt $iterations; $i++) {
                $cells += $pool.Rent()
                
                # Periodically return some cells
                if ($i % 50 -eq 0 -and $cells.Count -gt 25) {
                    for ($j = 0; $j -lt 25; $j++) {
                        $pool.Return($cells[$j])
                    }
                    $cells = $cells[25..($cells.Count-1)]
                }
            }
            
            $stopwatch.Stop()
            
            # Return remaining cells
            foreach ($cell in $cells) {
                $pool.Return($cell)
            }
            
            $finalMemory = [GC]::GetTotalMemory($true)
            $memoryIncrease = $finalMemory - $initialMemory
            
            $stats = $pool.GetStatistics()
            
            Write-Host "Memory pressure test results:" -ForegroundColor Yellow
            Write-Host "  Time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
            Write-Host "  Memory increase: $([Math]::Round($memoryIncrease / 1024, 2)) KB" -ForegroundColor Cyan
            Write-Host "  Pool hit rate: $($stats.PoolHitRate)%" -ForegroundColor Cyan
            Write-Host "  New creations: $($stats.CreateCount)" -ForegroundColor Cyan
            
            # Should complete in reasonable time even under pressure
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000
            
            # Memory increase should be reasonable
            $memoryIncrease | Should -BeLessThan (1024 * 1024)  # Less than 1MB
        }
        
        It "Should optimize memory usage compared to direct allocation" {
            $iterations = 1000
            
            # Test with pooling
            $pool = [TuiCellBufferPool]::new(200)
            $poolInitialMemory = [GC]::GetTotalMemory($true)
            
            $poolCells = @()
            for ($i = 0; $i -lt $iterations; $i++) {
                $poolCells += $pool.Rent()
                if ($i % 10 -eq 0 -and $poolCells.Count -gt 5) {
                    # Return some cells periodically
                    for ($j = 0; $j -lt 5; $j++) {
                        $pool.Return($poolCells[$j])
                    }
                    $poolCells = $poolCells[5..($poolCells.Count-1)]
                }
            }
            
            $poolFinalMemory = [GC]::GetTotalMemory($true)
            $poolMemoryUse = $poolFinalMemory - $poolInitialMemory
            
            # Return all cells
            foreach ($cell in $poolCells) {
                $pool.Return($cell)
            }
            
            # Test direct allocation
            $directInitialMemory = [GC]::GetTotalMemory($true)
            
            $directCells = @()
            for ($i = 0; $i -lt $iterations; $i++) {
                $directCells += [TuiCell]::new()
            }
            
            $directFinalMemory = [GC]::GetTotalMemory($true)
            $directMemoryUse = $directFinalMemory - $directInitialMemory
            
            Write-Host "Memory usage comparison:" -ForegroundColor Yellow
            Write-Host "  Pooled allocation: $([Math]::Round($poolMemoryUse / 1024, 2)) KB" -ForegroundColor Cyan
            Write-Host "  Direct allocation: $([Math]::Round($directMemoryUse / 1024, 2)) KB" -ForegroundColor Cyan
            
            if ($directMemoryUse -gt 0) {
                $memoryEfficiency = ($directMemoryUse - $poolMemoryUse) / $directMemoryUse * 100
                Write-Host "  Memory savings: $([Math]::Round($memoryEfficiency, 1))%" -ForegroundColor Green
            }
            
            # Pooled allocation should use same or less memory
            $poolMemoryUse | Should -BeLessOrEqual $directMemoryUse
        }
    }
    
    Context "Concurrent Access Performance" {
        It "Should handle concurrent pool access efficiently" {
            $pool = [TuiCellBufferPool]::new(500)
            $threads = 4
            $iterationsPerThread = 250
            
            $jobs = @()
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Start concurrent jobs
            for ($t = 0; $t -lt $threads; $t++) {
                $job = Start-Job -ScriptBlock {
                    param($poolInstance, $iterations, $threadId)
                    
                    $cells = @()
                    for ($i = 0; $i -lt $iterations; $i++) {
                        $cell = $poolInstance.Rent()
                        $cell.SetCharacter([char](65 + ($threadId % 26)))
                        $cells += $cell
                        
                        # Return some cells periodically
                        if ($i % 10 -eq 0 -and $cells.Count -gt 5) {
                            for ($j = 0; $j -lt 5; $j++) {
                                $poolInstance.Return($cells[$j])
                            }
                            $cells = $cells[5..($cells.Count-1)]
                        }
                    }
                    
                    # Return remaining cells
                    foreach ($cell in $cells) {
                        $poolInstance.Return($cell)
                    }
                    
                    return $threadId
                } -ArgumentList $pool, $iterationsPerThread, $t
                
                $jobs += $job
            }
            
            # Wait for all jobs to complete
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            $stopwatch.Stop()
            
            $stats = $pool.GetStatistics()
            
            Write-Host "Concurrent access results:" -ForegroundColor Yellow
            Write-Host "  Total time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
            Write-Host "  Threads: $threads" -ForegroundColor Cyan
            Write-Host "  Operations per thread: $iterationsPerThread" -ForegroundColor Cyan
            Write-Host "  Pool hit rate: $($stats.PoolHitRate)%" -ForegroundColor Cyan
            Write-Host "  Total operations: $($stats.RentCount)" -ForegroundColor Cyan
            
            # Should complete concurrent access in reasonable time
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
            
            # All threads should complete
            $results.Count | Should -Be $threads
            
            # Should maintain reasonable hit rate under concurrent load
            $stats.PoolHitRate | Should -BeGreaterThan 30
        }
    }
    
    Context "Pool Statistics Performance" {
        It "Should provide statistics efficiently" {
            $pool = [TuiCellBufferPool]::new(100)
            
            # Do some operations to generate statistics
            $cells = @()
            for ($i = 0; $i -lt 200; $i++) {
                $cells += $pool.Rent()
            }
            
            for ($i = 0; $i -lt 100; $i++) {
                $pool.Return($cells[$i])
            }
            
            $iterations = 1000
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Get statistics many times
            for ($i = 0; $i -lt $iterations; $i++) {
                $stats = $pool.GetStatistics()
            }
            
            $stopwatch.Stop()
            
            Write-Host "Statistics generation: $($stopwatch.ElapsedMilliseconds)ms for $iterations calls" -ForegroundColor Cyan
            
            # Statistics should be generated quickly
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 100
            
            # Cleanup
            for ($i = 100; $i -lt $cells.Count; $i++) {
                $pool.Return($cells[$i])
            }
        }
    }
}

Write-Host "Buffer pooling performance tests loaded" -ForegroundColor Green