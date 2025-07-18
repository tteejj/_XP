# ==============================================================================
# Axiom-Phoenix v4.0 - Buffer Pool Optimization
# Object pooling for TuiCell instances to reduce GC pressure
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent

#region Buffer Pool Interface

# IBufferPool interface
# Object pooling interface for reusable objects
#   Rent() -> object
#   Return(item) -> void
#   Clear() -> void
#   GetStatistics() -> hashtable

#endregion

#region TuiCell Buffer Pool

class TuiCellBufferPool {
    hidden [ConcurrentQueue[object]] $_pool
    hidden [int] $_maxPoolSize = 1000
    hidden [int] $_rentCount = 0
    hidden [int] $_returnCount = 0
    hidden [int] $_createCount = 0
    hidden [bool] $_disposed = $false
    
    TuiCellBufferPool() {
        $this._pool = [ConcurrentQueue[object]]::new()
        $this.PrewarmPool()
    }
    
    TuiCellBufferPool([int]$maxPoolSize) {
        $this._maxPoolSize = $maxPoolSize
        $this._pool = [ConcurrentQueue[object]]::new()
        $this.PrewarmPool()
    }
    
    # Pre-warm the pool with initial objects
    [void] PrewarmPool() {
        $prewarmCount = [Math]::Min(50, $this._maxPoolSize / 10)
        for ($i = 0; $i -lt $prewarmCount; $i++) {
            $cell = $this.CreateNewCell()
            $this._pool.Enqueue($cell)
        }
        Write-Log -Level Debug -Message "TuiCell buffer pool pre-warmed with $prewarmCount instances"
    }
    
    # Rent a TuiCell from the pool
    [object] Rent() {
        if ($this._disposed) {
            throw "Buffer pool has been disposed"
        }
        
        $this._rentCount++
        
        $cell = $null
        if ($this._pool.TryDequeue([ref]$cell)) {
            # Reset the cell to default state
            $this.ResetCell($cell)
            return $cell
        }
        
        # Pool is empty, create new instance
        $this._createCount++
        $newCell = $this.CreateNewCell()
        Write-Log -Level Debug -Message "Created new TuiCell instance (pool exhausted)"
        return $newCell
    }
    
    # Return a TuiCell to the pool
    [void] Return([object]$cell) {
        if ($this._disposed -or $null -eq $cell) {
            return
        }
        
        $this._returnCount++
        
        # Only return to pool if we haven't exceeded max size
        if ($this._pool.Count -lt $this._maxPoolSize) {
            # Clean the cell before returning
            $this.CleanCell($cell)
            $this._pool.Enqueue($cell)
        }
    }
    
    # Create a new TuiCell instance
    hidden [object] CreateNewCell() {
        return [TuiCell]::new()
    }
    
    # Reset cell to default state for reuse
    hidden [void] ResetCell([object]$cell) {
        if ($cell -and $cell -is [TuiCell]) {
            $cell.Character = ' '
            $cell.ForegroundColor = [ConsoleColor]::White
            $cell.BackgroundColor = [ConsoleColor]::Black
            $cell.IsDirty = $false
        }
    }
    
    # Clean cell before returning to pool
    hidden [void] CleanCell([object]$cell) {
        $this.ResetCell($cell)
    }
    
    # Clear the entire pool
    [void] Clear() {
        while ($this._pool.TryDequeue([ref]$null)) {
            # Dequeue all items
        }
        Write-Log -Level Info -Message "TuiCell buffer pool cleared"
    }
    
    # Get pool statistics
    [hashtable] GetStatistics() {
        return @{
            PoolSize = $this._pool.Count
            MaxPoolSize = $this._maxPoolSize
            RentCount = $this._rentCount
            ReturnCount = $this._returnCount
            CreateCount = $this._createCount
            PoolHitRate = if ($this._rentCount -gt 0) { 
                [Math]::Round((($this._rentCount - $this._createCount) / $this._rentCount) * 100, 2) 
            } else { 0 }
            PoolEfficiency = if ($this._returnCount -gt 0) {
                [Math]::Round(($this._pool.Count / $this._returnCount) * 100, 2)
            } else { 0 }
        }
    }
    
    # Dispose the pool
    [void] Dispose() {
        if (-not $this._disposed) {
            $this.Clear()
            $this._disposed = $true
            Write-Log -Level Info -Message "TuiCell buffer pool disposed"
        }
    }
}

#endregion

#region Enhanced TuiBuffer with Pool Support

class PooledTuiBuffer : TuiBuffer {
    hidden [TuiCellBufferPool] $_cellPool
    hidden [bool] $_usePooling = $true
    
    PooledTuiBuffer([int]$width, [int]$height) : base($width, $height) {
        $this.InitializePool()
    }
    
    PooledTuiBuffer([int]$width, [int]$height, [TuiCellBufferPool]$cellPool) : base($width, $height) {
        $this._cellPool = $cellPool
        $this._usePooling = $true
        $this.ReplaceBufferWithPooledCells()
    }
    
    hidden [void] InitializePool() {
        # Get pool size from configuration or use default
        $maxPoolSize = Get-ConfigValue "Performance.MaxBufferPoolSize" 1000
        $this._cellPool = [TuiCellBufferPool]::new($maxPoolSize)
        $this.ReplaceBufferWithPooledCells()
    }
    
    hidden [void] ReplaceBufferWithPooledCells() {
        if (-not $this._usePooling -or -not $this._cellPool) {
            return
        }
        
        # Replace existing cells with pooled instances
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $pooledCell = $this._cellPool.Rent()
                $this.Buffer[$y][$x] = $pooledCell
            }
        }
    }
    
    # Override resize to use pooled cells
    [void] Resize([int]$newWidth, [int]$newHeight) {
        if ($newWidth -eq $this.Width -and $newHeight -eq $this.Height) {
            return
        }
        
        # Return existing cells to pool
        if ($this._usePooling -and $this._cellPool) {
            $this.ReturnCellsToPool()
        }
        
        # Call base resize
        ([TuiBuffer]$this).Resize($newWidth, $newHeight)
        
        # Replace new cells with pooled instances
        if ($this._usePooling -and $this._cellPool) {
            $this.ReplaceBufferWithPooledCells()
        }
    }
    
    # Return all cells to pool
    hidden [void] ReturnCellsToPool() {
        if (-not $this._cellPool) {
            return
        }
        
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $cell = $this.Buffer[$y][$x]
                if ($cell) {
                    $this._cellPool.Return($cell)
                }
            }
        }
    }
    
    # Enable/disable pooling
    [void] SetPoolingEnabled([bool]$enabled) {
        if ($enabled -eq $this._usePooling) {
            return
        }
        
        if (-not $enabled -and $this._usePooling) {
            # Disable pooling - return cells and create new ones
            $this.ReturnCellsToPool()
            $this.CreateNormalBuffer()
        } elseif ($enabled -and -not $this._usePooling) {
            # Enable pooling - replace with pooled cells
            if (-not $this._cellPool) {
                $this.InitializePool()
            }
            $this.ReplaceBufferWithPooledCells()
        }
        
        $this._usePooling = $enabled
    }
    
    hidden [void] CreateNormalBuffer() {
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.Buffer[$y][$x] = [TuiCell]::new()
            }
        }
    }
    
    # Get pool statistics
    [hashtable] GetPoolStatistics() {
        if ($this._cellPool) {
            return $this._cellPool.GetStatistics()
        }
        return @{
            PoolingEnabled = $false
            Message = "Buffer pooling is not enabled"
        }
    }
    
    # Cleanup - return cells to pool
    [void] Dispose() {
        if ($this._usePooling -and $this._cellPool) {
            $this.ReturnCellsToPool()
        }
        
        # Don't dispose the shared cell pool - it's managed globally
        # Just clear our references
        $this._cellPool = $null
    }
}

#endregion

#region Global Buffer Pool Service

class BufferPoolService {
    hidden [TuiCellBufferPool] $_cellPool
    hidden [hashtable] $_bufferPools = @{}
    hidden [bool] $_disposed = $false
    
    [void] Initialize() {
        $maxPoolSize = Get-ConfigValue "Performance.MaxBufferPoolSize" 1000
        $this._cellPool = [TuiCellBufferPool]::new($maxPoolSize)
        
        Write-Log -Level Info -Message "Buffer pool service initialized with max size: $maxPoolSize"
    }
    
    # Get the global TuiCell pool
    [TuiCellBufferPool] GetCellPool() {
        return $this._cellPool
    }
    
    # Create a pooled buffer
    [PooledTuiBuffer] CreatePooledBuffer([int]$width, [int]$height) {
        return [PooledTuiBuffer]::new($width, $height, $this._cellPool)
    }
    
    # Register a custom buffer pool
    [void] RegisterBufferPool([string]$name, [object]$pool) {
        $this._bufferPools[$name] = $pool
    }
    
    # Get a registered buffer pool
    [object] GetBufferPool([string]$name) {
        if ($this._bufferPools.ContainsKey($name)) {
            return $this._bufferPools[$name]
        }
        return $null
    }
    
    # Get comprehensive statistics
    [hashtable] GetStatistics() {
        $stats = @{
            CellPool = $this._cellPool.GetStatistics()
            RegisteredPools = $this._bufferPools.Keys
            TotalPools = $this._bufferPools.Count + 1
        }
        
        foreach ($kvp in $this._bufferPools.GetEnumerator()) {
            $stats["Pool_$($kvp.Key)"] = $kvp.Value.GetStatistics()
        }
        
        return $stats
    }
    
    # Force garbage collection and pool optimization
    [void] OptimizePools() {
        # Clear unused objects from pools
        foreach ($pool in $this._bufferPools.Values) {
            if ($pool.PSObject.Methods['Optimize']) {
                $pool.Optimize()
            }
        }
        
        # Force garbage collection
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()
        
        Write-Log -Level Info -Message "Buffer pools optimized and garbage collection performed"
    }
    
    [void] Dispose() {
        if (-not $this._disposed) {
            # Dispose all pools
            if ($this._cellPool) {
                $this._cellPool.Dispose()
            }
            
            foreach ($pool in $this._bufferPools.Values) {
                if ($pool.PSObject.Methods['Dispose']) {
                    $pool.Dispose()
                }
            }
            
            $this._bufferPools.Clear()
            $this._disposed = $true
            
            Write-Log -Level Info -Message "Buffer pool service disposed"
        }
    }
}

#endregion

#region Helper Functions

# Create a pooled buffer using the global service
function New-PooledBuffer {
    param(
        [int]$Width,
        [int]$Height
    )
    
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.BufferPool) {
        return $global:TuiState.Services.BufferPool.CreatePooledBuffer($Width, $Height)
    }
    
    # Fallback to regular buffer if service not available
    return [TuiBuffer]::new($Width, $Height)
}

# Get buffer pool statistics
function Get-BufferPoolStats {
    if ($global:TuiState -and $global:TuiState.Services -and $global:TuiState.Services.BufferPool) {
        return $global:TuiState.Services.BufferPool.GetStatistics()
    }
    
    return @{ Error = "Buffer pool service not available" }
}

#endregion

Write-Host "Buffer Pool Optimization system loaded" -ForegroundColor Green