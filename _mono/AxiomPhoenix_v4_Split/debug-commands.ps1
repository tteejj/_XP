# ==============================================================================
# Axiom-Phoenix v4.0 - Debug Commands
# Useful commands for debugging performance and rendering issues
# ==============================================================================

# Enable debug mode if not already enabled
if (-not $global:TuiDebugMode) {
    Write-Host "Debug mode is not enabled. Run with './Start.ps1 -Debug' to enable." -ForegroundColor Yellow
}

function Show-PerformanceMetrics {
    [CmdletBinding()]
    param()
    
    Write-Host "`n=== Performance Metrics ===" -ForegroundColor Cyan
    
    if ($global:TuiPerformanceMetrics) {
        Write-Host "Frame Count: $($global:TuiPerformanceMetrics.FrameCount)" -ForegroundColor Green
        Write-Host "Average Render Time: $($global:TuiPerformanceMetrics.AverageRenderTime)ms" -ForegroundColor Green
        Write-Host "Min Render Time: $($global:TuiPerformanceMetrics.MinRenderTime)ms" -ForegroundColor Green
        Write-Host "Max Render Time: $($global:TuiPerformanceMetrics.MaxRenderTime)ms" -ForegroundColor Green
        Write-Host "Total Render Time: $($global:TuiPerformanceMetrics.TotalRenderTime)ms" -ForegroundColor Green
    } else {
        Write-Host "No performance metrics available" -ForegroundColor Red
    }
}

function Show-MemoryMetrics {
    [CmdletBinding()]
    param()
    
    Write-Host "`n=== Memory Metrics ===" -ForegroundColor Cyan
    
    if ($global:TuiMemoryMetrics) {
        Write-Host "TuiCells Created: $($global:TuiMemoryMetrics.TuiCellsCreated)" -ForegroundColor Green
        Write-Host "TuiCells Reused: $($global:TuiMemoryMetrics.TuiCellsReused)" -ForegroundColor Green
        Write-Host "Buffer Swaps: $($global:TuiMemoryMetrics.BufferSwaps)" -ForegroundColor Green
        Write-Host "Blend Operations: $($global:TuiMemoryMetrics.BlendOperations)" -ForegroundColor Green
        
        $total = $global:TuiMemoryMetrics.TuiCellsCreated + $global:TuiMemoryMetrics.TuiCellsReused
        if ($total -gt 0) {
            $reuseRate = ($global:TuiMemoryMetrics.TuiCellsReused / $total) * 100
            Write-Host "Cell Reuse Rate: $([Math]::Round($reuseRate, 2))%" -ForegroundColor Green
        }
    } else {
        Write-Host "No memory metrics available" -ForegroundColor Red
    }
}

function Show-TemplateCellPool {
    [CmdletBinding()]
    param()
    
    Write-Host "`n=== Template Cell Pool ===" -ForegroundColor Cyan
    
    if ($global:TuiTemplateCellPool) {
        Write-Host "Pool Size: $($global:TuiTemplateCellPool.Count)" -ForegroundColor Green
        Write-Host "Pool Keys:" -ForegroundColor Yellow
        foreach ($key in $global:TuiTemplateCellPool.Keys) {
            Write-Host "  $key" -ForegroundColor Gray
        }
    } else {
        Write-Host "No template cell pool available" -ForegroundColor Red
    }
}

function Show-FullReport {
    [CmdletBinding()]
    param()
    
    Write-Host "`n=== FULL PERFORMANCE REPORT ===" -ForegroundColor Magenta
    
    $report = Get-TuiPerformanceReport
    $report | ConvertTo-Json -Depth 3 | Write-Host
}

function Reset-Metrics {
    [CmdletBinding()]
    param()
    
    Write-Host "Resetting all metrics..." -ForegroundColor Yellow
    
    if ($global:TuiPerformanceMetrics) {
        $global:TuiPerformanceMetrics.RenderTimes.Clear()
        $global:TuiPerformanceMetrics.FrameCount = 0
        $global:TuiPerformanceMetrics.TotalRenderTime = 0
        $global:TuiPerformanceMetrics.AverageRenderTime = 0
        $global:TuiPerformanceMetrics.MaxRenderTime = 0
        $global:TuiPerformanceMetrics.MinRenderTime = [long]::MaxValue
    }
    
    if ($global:TuiMemoryMetrics) {
        $global:TuiMemoryMetrics.TuiCellsCreated = 0
        $global:TuiMemoryMetrics.TuiCellsReused = 0
        $global:TuiMemoryMetrics.BufferSwaps = 0
        $global:TuiMemoryMetrics.BlendOperations = 0
    }
    
    Write-Host "Metrics reset complete" -ForegroundColor Green
}

function Test-RenderingIssue {
    [CmdletBinding()]
    param()
    
    Write-Host "`n=== Testing Rendering Issue ===" -ForegroundColor Cyan
    
    # Test template cell pool
    if ($global:TuiTemplateCellPool) {
        Write-Host "Template cell pool exists with $($global:TuiTemplateCellPool.Count) entries" -ForegroundColor Green
        
        # Check if any template cells have weird characters
        foreach ($key in $global:TuiTemplateCellPool.Keys) {
            $cell = $global:TuiTemplateCellPool[$key]
            if ($cell.Char -ne ' ') {
                Write-Host "WARNING: Template cell has non-space character: '$($cell.Char)'" -ForegroundColor Red
            }
        }
    }
    
    # Check if debug mode is working
    if ($global:TuiDebugMode) {
        Write-Host "Debug mode is active" -ForegroundColor Green
    } else {
        Write-Host "Debug mode is NOT active - run with -Debug flag" -ForegroundColor Red
    }
}

# Display available commands
Write-Host "`n=== Debug Commands Available ===" -ForegroundColor Cyan
Write-Host "Show-PerformanceMetrics  - Display render performance stats" -ForegroundColor Green
Write-Host "Show-MemoryMetrics       - Display memory usage stats" -ForegroundColor Green
Write-Host "Show-TemplateCellPool    - Display template cell pool info" -ForegroundColor Green
Write-Host "Show-FullReport          - Display complete performance report" -ForegroundColor Green
Write-Host "Reset-Metrics            - Reset all metrics to zero" -ForegroundColor Green
Write-Host "Test-RenderingIssue      - Diagnose rendering problems" -ForegroundColor Green
Write-Host "`nUsage: Just call any function by name, e.g. 'Show-PerformanceMetrics'" -ForegroundColor Yellow