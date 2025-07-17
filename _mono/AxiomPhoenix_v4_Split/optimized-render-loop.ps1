# ==============================================================================
# Optimized Render Loop Implementation
# Implements demand-driven rendering to eliminate wasteful 30 FPS when idle
# ==============================================================================

# Enhanced TUI State for render optimization
function Initialize-OptimizedRenderState {
    if (-not $global:TuiState.PSObject.Properties['RenderState']) {
        $global:TuiState.RenderState = @{
            # Core rendering control
            ShouldRender = $false           # Main render gate
            RenderRequested = $false        # Immediate render request
            
            # Performance tracking
            LastRenderTime = [DateTime]::Now
            IdleTime = [TimeSpan]::Zero
            FramesSaved = 0
            
            # Render batching
            BatchedRequests = 0
            MaxBatchDelay = 16              # Max 16ms batching (~60fps cap)
            
            # Automatic render scenarios
            AutoRenderOnInput = $true       # Render after input
            AutoRenderOnResize = $true      # Render after resize
            AutoRenderOnFocus = $true       # Render on focus changes
            
            # Debugging
            DebugMode = $false
            RenderRequestStack = @()        # Track what requested renders
        }
    }
}

# Enhanced RequestRedraw with context tracking
function Request-OptimizedRedraw {
    param(
        [string]$Source = "Unknown",
        [switch]$Immediate,
        [switch]$Force
    )
    
    $renderState = $global:TuiState.RenderState
    
    # Track render request source for debugging
    if ($renderState.DebugMode) {
        $renderState.RenderRequestStack += @{
            Source = $Source
            Time = [DateTime]::Now
            Immediate = $Immediate.IsPresent
        }
    }
    
    # Set render flags
    $renderState.ShouldRender = $true
    
    if ($Immediate -or $Force) {
        $renderState.RenderRequested = $true
    } else {
        $renderState.BatchedRequests++
    }
    
    # Wake up the render loop if it's sleeping
    if ($global:TuiState.PSObject.Properties['RenderEvent']) {
        $global:TuiState.RenderEvent.Set()
    }
}

# Optimized render loop with demand-driven rendering
function Start-OptimizedTuiEngine {
    param(
        [int]$TargetFPS = 30,
        [int]$IdleCheckInterval = 100,      # Check every 100ms when idle
        [switch]$EnablePerformanceMonitoring
    )
    
    try {
        Write-Host "Starting Optimized TUI Engine (demand-driven rendering)" -ForegroundColor Green
        
        # Initialize render state
        Initialize-OptimizedRenderState
        
        # Create event for waking up render loop
        $global:TuiState.RenderEvent = [System.Threading.ManualResetEventSlim]::new($false)
        
        $targetFrameTime = [timespan]::FromSeconds(1.0 / $TargetFPS)
        $idleCheckTime = [timespan]::FromMilliseconds($IdleCheckInterval)
        $frameStopwatch = [System.Diagnostics.Stopwatch]::new()
        
        $global:TuiState.Running = $true
        $global:TuiState.FrameCount = 0
        $renderState = $global:TuiState.RenderState
        
        # Initial render
        $renderState.ShouldRender = $true
        $renderState.RenderRequested = $true
        
        while ($global:TuiState.Running) {
            $frameStopwatch.Restart()
            
            try {
                # Phase 1: Handle console resize
                if ([Console]::WindowWidth -ne $global:TuiState.BufferWidth -or 
                    [Console]::WindowHeight -ne $global:TuiState.BufferHeight) {
                    
                    Update-TuiEngineSize
                    
                    if ($renderState.AutoRenderOnResize) {
                        Request-OptimizedRedraw -Source "Resize" -Immediate
                    }
                }
                
                # Phase 2: Process input
                $keyAvailable = $false
                try {
                    $keyAvailable = [Console]::KeyAvailable
                } catch {
                    try { $keyAvailable = [Console]::In.Peek() -ne -1 } catch {}
                }
                
                if ($keyAvailable) {
                    $keyInfo = [Console]::ReadKey($true)
                    if ($keyInfo) { 
                        Process-TuiInput -KeyInfo $keyInfo 
                        
                        if ($renderState.AutoRenderOnInput) {
                            Request-OptimizedRedraw -Source "Input" -Immediate
                        }
                    }
                }
                
                # Phase 3: Process deferred actions
                if ($global:TuiState.DeferredActions.Count -gt 0) {
                    $deferredAction = $null
                    if ($global:TuiState.DeferredActions.TryDequeue([ref]$deferredAction)) {
                        if ($deferredAction -and $deferredAction.ActionName) {
                            $actionService = $global:TuiState.Services.ActionService
                            if ($actionService) { 
                                $actionService.ExecuteAction($deferredAction.ActionName, @{})
                                Request-OptimizedRedraw -Source "DeferredAction"
                            }
                        }
                    }
                }
                
                # Phase 4: OPTIMIZED RENDERING DECISION
                $shouldRender = $false
                
                if ($renderState.RenderRequested) {
                    # Immediate render requested
                    $shouldRender = $true
                    $renderState.RenderRequested = $false
                } elseif ($renderState.BatchedRequests -gt 0) {
                    # Check if batching delay has elapsed
                    $timeSinceLastRender = [DateTime]::Now - $renderState.LastRenderTime
                    if ($timeSinceLastRender.TotalMilliseconds -ge $renderState.MaxBatchDelay) {
                        $shouldRender = $true
                        $renderState.BatchedRequests = 0
                    }
                }
                
                # Phase 5: CONDITIONAL RENDERING
                if ($shouldRender -and $renderState.ShouldRender) {
                    # Actually render
                    Invoke-TuiRender
                    $renderState.LastRenderTime = [DateTime]::Now
                    $renderState.ShouldRender = $false  # Reset render gate
                    $global:TuiState.FrameCount++
                    
                    # Performance tracking
                    $renderState.IdleTime = [TimeSpan]::Zero
                } else {
                    # No render needed - track idle time and savings
                    $renderState.IdleTime = $renderState.IdleTime.Add($frameStopwatch.Elapsed)
                    $renderState.FramesSaved++
                }
                
                # Phase 6: ADAPTIVE FRAME TIMING
                $frameStopwatch.Stop()
                $elapsedTime = $frameStopwatch.Elapsed
                
                if ($shouldRender) {
                    # Normal frame timing for active rendering
                    if ($elapsedTime -lt $targetFrameTime) {
                        $sleepTime = $targetFrameTime - $elapsedTime
                        if ($sleepTime.TotalMilliseconds -gt 1) { 
                            Start-Sleep -Milliseconds ([int]$sleepTime.TotalMilliseconds) 
                        }
                    }
                } else {
                    # Longer sleep when idle to save CPU
                    $sleepTime = $idleCheckTime
                    if ($sleepTime.TotalMilliseconds -gt 1) {
                        # Use event-based waiting for better responsiveness
                        $global:TuiState.RenderEvent.Wait([int]$sleepTime.TotalMilliseconds)
                        $global:TuiState.RenderEvent.Reset()
                    }
                }
                
                # Performance reporting
                if ($EnablePerformanceMonitoring -and ($global:TuiState.FrameCount % 300 -eq 0)) {
                    $report = Get-OptimizedRenderReport
                    Write-Host "Render Optimization: $($report.FramesSaved) frames saved, $($report.CPUSavingsPercent)% CPU saved" -ForegroundColor Cyan
                }
                
            } catch {
                Write-Log -Level Error -Message "Optimized TUI Engine error: $($_.Exception.Message)"
                Start-Sleep -Milliseconds 50
            }
        }
        
    } catch {
        Write-Log -Level Fatal -Message "Optimized TUI Engine critical error: $($_.Exception.Message)"
        throw
    } finally {
        # Cleanup
        if ($global:TuiState.RenderEvent) {
            $global:TuiState.RenderEvent.Dispose()
        }
        Stop-TuiEngine
    }
}

# Performance reporting for render optimization
function Get-OptimizedRenderReport {
    $renderState = $global:TuiState.RenderState
    $totalFrames = $global:TuiState.FrameCount + $renderState.FramesSaved
    
    return @{
        FramesRendered = $global:TuiState.FrameCount
        FramesSaved = $renderState.FramesSaved
        TotalFrames = $totalFrames
        CPUSavingsPercent = if ($totalFrames -gt 0) { [math]::Round(($renderState.FramesSaved / $totalFrames) * 100, 1) } else { 0 }
        IdleTime = $renderState.IdleTime
        LastRenderTime = $renderState.LastRenderTime
        BatchedRequests = $renderState.BatchedRequests
        RenderRequestSources = $renderState.RenderRequestStack | Group-Object Source | ForEach-Object { @{ Source = $_.Name; Count = $_.Count } }
    }
}

# Helper function to update all RequestRedraw calls
function Update-ComponentRequestRedraw {
    param([string]$ComponentFile)
    
    # Replace RequestRedraw() calls with Request-OptimizedRedraw
    $content = Get-Content $ComponentFile -Raw
    $updatedContent = $content -replace 'RequestRedraw\(\)', 'Request-OptimizedRedraw -Source "$($this.Name)"'
    $updatedContent = $updatedContent -replace '\.RequestRedraw\(\)', '.Request-OptimizedRedraw -Source "$($this.Name)"'
    
    Set-Content $ComponentFile $updatedContent
}

# Test the optimization
function Test-RenderOptimization {
    Write-Host "=== Render Optimization Test ===" -ForegroundColor Green
    
    # Simulate normal usage patterns
    $tests = @(
        @{ Name = "Idle"; Duration = 5; Actions = @() }
        @{ Name = "Light Activity"; Duration = 3; Actions = @("keystroke", "mouse") }
        @{ Name = "Heavy Activity"; Duration = 2; Actions = @("keystroke", "mouse", "resize", "focus") }
    )
    
    foreach ($test in $tests) {
        Write-Host "Testing: $($test.Name)" -ForegroundColor Yellow
        
        # Reset counters
        $global:TuiState.FrameCount = 0
        $global:TuiState.RenderState.FramesSaved = 0
        
        # Simulate test duration
        $endTime = [DateTime]::Now.AddSeconds($test.Duration)
        while ([DateTime]::Now -lt $endTime) {
            # Simulate actions
            foreach ($action in $test.Actions) {
                switch ($action) {
                    "keystroke" { Request-OptimizedRedraw -Source "KeyTest" }
                    "mouse" { Request-OptimizedRedraw -Source "MouseTest" }
                    "resize" { Request-OptimizedRedraw -Source "ResizeTest" -Immediate }
                    "focus" { Request-OptimizedRedraw -Source "FocusTest" }
                }
            }
            Start-Sleep -Milliseconds 50
        }
        
        $report = Get-OptimizedRenderReport
        Write-Host "  Frames rendered: $($report.FramesRendered)" -ForegroundColor White
        Write-Host "  Frames saved: $($report.FramesSaved)" -ForegroundColor White
        Write-Host "  CPU savings: $($report.CPUSavingsPercent)%" -ForegroundColor Green
    }
}

Write-Host "Optimized render loop implementation loaded." -ForegroundColor Green
Write-Host "Use Start-OptimizedTuiEngine instead of Start-TuiEngine for demand-driven rendering." -ForegroundColor Yellow