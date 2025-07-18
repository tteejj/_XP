# ==============================================================================
# Axiom-Phoenix v4.0 - All Runtime (Load Last)
# TUI engine, screen management, and main application loop
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ART.###" to find specific sections.
# Each section ends with "END_PAGE: ART.###"
# ==============================================================================

#region Engine Management

function Initialize-TuiEngine {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log -Level Info -Message "Initializing TUI engine..."
        
        Write-Log -Level Debug -Message "Initialize-TuiEngine: Storing original console state"
        # Store original console state
        $global:TuiState.OriginalWindowTitle = $Host.UI.RawUI.WindowTitle
        # Get original cursor state (Linux-compatible)
        $global:TuiState.OriginalCursorVisible = $true
        try { $global:TuiState.OriginalCursorVisible = [Console]::CursorVisible } catch {}
        
        Write-Log -Level Debug -Message "Initialize-TuiEngine: Configuring console"
        # Configure console
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding = [System.Text.Encoding]::UTF8
        [Console]::CursorVisible = $false
        
        # This property is read-only in some Windows consoles (e.g., conhost.exe)
        # and will throw a terminating error. Wrapping it prevents the crash.
        try {
            [Console]::TreatControlCAsInput = $true
            Write-Log -Level Debug -Message "Successfully set TreatControlCAsInput to true."
        }
        catch {
            Write-Log -Level Warning -Message "Could not set 'TreatControlCAsInput'. Ctrl+C will terminate the app. Error: $($_.Exception.Message)"
        }

        $Host.UI.RawUI.WindowTitle = "Axiom-Phoenix v4.0 TUI Framework"
        
        Write-Log -Level Debug -Message "Initialize-TuiEngine: Clearing screen and hiding cursor"
        # Clear screen and hide cursor
        Clear-Host
        [Console]::SetCursorPosition(0, 0)
        
        Write-Log -Level Debug -Message "Initialize-TuiEngine: Getting initial console size"
        # Get initial size
        Update-TuiEngineSize
        
        Write-Log -Level Debug -Message "Initialize-TuiEngine: Creating compositor buffers"
        # Create compositor buffers
        $width = $global:TuiState.BufferWidth
        $height = $global:TuiState.BufferHeight
        $global:TuiState.CompositorBuffer = [TuiBuffer]::new($width, $height, "Compositor")
        $global:TuiState.PreviousCompositorBuffer = [TuiBuffer]::new($width, $height, "PreviousCompositor")
        
        Write-Log -Level Debug -Message "Initialize-TuiEngine: Clearing buffers with theme background"
        # Clear with theme background
        $bgColor = Get-ThemeColor "Screen.Background" "#000000"
        $global:TuiState.CompositorBuffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        $global:TuiState.PreviousCompositorBuffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        Write-Log -Level Info -Message "TUI engine initialized. Buffer size: ${width}x${height}"
    }
    catch {
        Invoke-WithErrorHandling -Component "TuiEngine" -Context "Initialization" -ScriptBlock { throw } `
            -AdditionalData @{ Phase = "EngineInit" }
    }
}
function Start-TuiEngine {
    [CmdletBinding()]
    param(
        [int]$TargetFPS = 30,
        [switch]$EnablePerformanceMonitoring,
        [int]$PerformanceReportInterval = 300,  # frames
        [int]$IdleCheckInterval = 100,         # Check every 100ms when idle
        [switch]$OptimizedRendering = $true    # Use demand-driven rendering by default
    )
    
    try {
        Write-Log -Level Info -Message "Starting TUI Engine with target FPS: $TargetFPS (Optimized: $OptimizedRendering)"
        
        if ($OptimizedRendering) {
            # Use optimized demand-driven rendering
            Initialize-OptimizedRenderState
            
            # Create event for waking up render loop
            $global:TuiState.RenderEvent = [System.Threading.ManualResetEventSlim]::new($false)
            
            $targetFrameTime = [timespan]::FromSeconds(1.0 / $TargetFPS)
            $idleCheckTime = [timespan]::FromMilliseconds($IdleCheckInterval)
            $frameStopwatch = [System.Diagnostics.Stopwatch]::new()
            
            $global:TuiState.Running = $true
            $global:TuiState.FrameCount = 0
            $global:TuiState.DeferredActions = New-Object 'System.Collections.Concurrent.ConcurrentQueue[hashtable]'
            $renderState = $global:TuiState.RenderState
            
            # Initial render
            $renderState.ShouldRender = $true
            $renderState.RenderRequested = $true
            
            Write-Log -Level Debug -Message "Start-TuiEngine: Entering optimized render loop"
            while ($global:TuiState.Running) {
                $frameStopwatch.Restart()
                
                try {
                    # Phase 1: Handle console resize
                    if ([Console]::WindowWidth -ne $global:TuiState.BufferWidth -or 
                        [Console]::WindowHeight -ne $global:TuiState.BufferHeight) {
                        
                        Invoke-WithErrorHandling -Component "TuiEngine" -Context "Resize" -ScriptBlock { Update-TuiEngineSize }
                        
                        if ($renderState.AutoRenderOnResize) {
                            [void](Request-OptimizedRedraw -Source "Resize" -Immediate)
                        }
                    }
                    
                    # Phase 2: Process input - FIXED INPUT DETECTION
                    Invoke-WithErrorHandling -Component "TuiEngine" -Context "Input" -ScriptBlock {
                        $keyAvailable = $false
                        
                        # CRITICAL FIX: Use Host.UI.RawUI first for better compatibility
                        try {
                            # Method 1: Host.UI.RawUI.KeyAvailable (most compatible)
                            if ($Host.UI.RawUI.KeyAvailable) {
                                $keyAvailable = $true
                            }
                        } catch {
                            # Method 2: Console.In.Peek() fallback
                            try {
                                $peekResult = [Console]::In.Peek()
                                if ($peekResult -ne -1) {
                                    $keyAvailable = $true
                                }
                            } catch {
                                # Method 3: Console.KeyAvailable last resort
                                try {
                                    if ([Console]::KeyAvailable) {
                                        $keyAvailable = $true
                                    }
                                } catch {
                                    # All methods failed - no input detection possible
                                    $keyAvailable = $false
                                }
                            }
                        }
                        
                        if ($keyAvailable) {
                            # #Write-Host "INPUT ENGINE: Reading key..." -ForegroundColor Blue
                            try {
                                $keyInfo = [Console]::ReadKey($true)
                                if ($keyInfo) { 
                                    # #Write-Host "INPUT ENGINE: Got key: $($keyInfo.Key) - processing..." -ForegroundColor Green
                                    Process-TuiInput -KeyInfo $keyInfo 
                                    
                                    if ($renderState.AutoRenderOnInput) {
                                        [void](Request-OptimizedRedraw -Source "Input" -Immediate)
                                    }
                                    # #Write-Host "INPUT ENGINE: Key processing completed successfully" -ForegroundColor Green
                                } else {
                                    # #Write-Host "INPUT ENGINE: ReadKey returned null" -ForegroundColor Red
                                }
                            } catch {
                                # #Write-Host "INPUT ENGINE: ReadKey failed: $($_.Exception.Message)" -ForegroundColor Red
                            }
                        }
                    }
                    
                    # Phase 3: Process deferred actions
                    if ($global:TuiState.DeferredActions.Count -gt 0) {
                        $deferredAction = $null
                        if ($global:TuiState.DeferredActions.TryDequeue([ref]$deferredAction)) {
                            if ($deferredAction -and $deferredAction.ActionName) {
                                Invoke-WithErrorHandling -Component "TuiEngine" -Context "DeferredAction" -ScriptBlock {
                                    $actionService = $global:TuiState.Services.ActionService
                                    if ($actionService) { 
                                        $actionService.ExecuteAction($deferredAction.ActionName, @{})
                                        [void](Request-OptimizedRedraw -Source "DeferredAction")
                                    }
                                }
                            }
                        }
                    }
                    
                    # Phase 4: OPTIMIZED RENDERING DECISION
                    $shouldRender = $false
                    
                    #Write-Host "RENDER-DECISION: RenderRequested=$($renderState.RenderRequested), BatchedRequests=$($renderState.BatchedRequests), IsDirty=$($global:TuiState.IsDirty)" -ForegroundColor Cyan
                    
                    if ($renderState.RenderRequested) {
                        # Immediate render requested
                        $shouldRender = $true
                        $renderState.RenderRequested = $false
                        #Write-Host "RENDER-DECISION: Immediate render requested - shouldRender=true" -ForegroundColor Green
                    } elseif ($renderState.BatchedRequests -gt 0) {
                        # Check if batching delay has elapsed
                        $timeSinceLastRender = [DateTime]::Now - $renderState.LastRenderTime
                        if ($timeSinceLastRender.TotalMilliseconds -ge $renderState.MaxBatchDelay) {
                            $shouldRender = $true
                            $renderState.BatchedRequests = 0
                            #Write-Host "RENDER-DECISION: Batched render delay elapsed - shouldRender=true" -ForegroundColor Green
                        } else {
                            #Write-Host "RENDER-DECISION: Batched render delay NOT elapsed ($(($timeSinceLastRender.TotalMilliseconds)) < $($renderState.MaxBatchDelay))" -ForegroundColor Yellow
                        }
                    } elseif ($global:TuiState.IsDirty) {
                        # Legacy IsDirty flag support
                        $shouldRender = $true
                        $renderState.ShouldRender = $true  # Reset the render gate
                        $global:TuiState.IsDirty = $false
                        #Write-Host "RENDER-DECISION: IsDirty flag set - shouldRender=true" -ForegroundColor Green
                    }
                    
                    # Phase 5: CONDITIONAL RENDERING
                    $doRender = $shouldRender -and $renderState.ShouldRender
                    #Write-Host "ENGINE: shouldRender=$shouldRender, renderState.ShouldRender=$($renderState.ShouldRender), doRender=$doRender" -ForegroundColor Magenta
                    if ($doRender) {
                        # Actually render
                        #Write-Host "ENGINE: Calling Invoke-TuiRender" -ForegroundColor Magenta
                        Invoke-WithErrorHandling -Component "TuiEngine" -Context "Render" -ScriptBlock { Invoke-TuiRender }
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
                        # Shorter sleep when idle to maintain input responsiveness
                        $sleepTime = [Math]::Min(50, $idleCheckTime.TotalMilliseconds)  # Max 50ms sleep
                        if ($sleepTime -gt 1) {
                            Start-Sleep -Milliseconds ([int]$sleepTime)
                        }
                    }
                    
                    # Performance reporting
                    if ($EnablePerformanceMonitoring -and ($global:TuiState.FrameCount % $PerformanceReportInterval -eq 0)) {
                        $report = Get-OptimizedRenderReport
                        Write-Log -Level Info -Message "Render Optimization: $($report.FramesSaved) frames saved, $($report.CPUSavingsPercent)% CPU saved"
                    }
                    
                } catch {
                    # Write-Log -Level Error -Message "TUI Engine: Unhandled error in frame $($global:TuiState.FrameCount): $($_.Exception.Message)"
                    Start-Sleep -Milliseconds 50
                }
            }
        } else {
            # Use legacy continuous rendering
            Write-Log -Level Debug -Message "Start-TuiEngine: Using legacy continuous rendering"
            Start-TuiEngineLegacy -TargetFPS $TargetFPS -EnablePerformanceMonitoring:$EnablePerformanceMonitoring -PerformanceReportInterval $PerformanceReportInterval
        }
    }
    catch {
        # Write-Log -Level Fatal -Message "TUI Engine critical error: $($_.Exception.Message)"
        Invoke-PanicHandler $_
    }
    finally {
        # Cleanup
        if ($global:TuiState.RenderEvent) {
            $global:TuiState.RenderEvent.Dispose()
        }
        Stop-TuiEngine
    }
}

# Legacy continuous rendering function (for compatibility/fallback)
function Start-TuiEngineLegacy {
    [CmdletBinding()]
    param(
        [int]$TargetFPS = 30,
        [switch]$EnablePerformanceMonitoring,
        [int]$PerformanceReportInterval = 300
    )
    
    $targetFrameTime = [timespan]::FromSeconds(1.0 / $TargetFPS)
    $frameStopwatch = [System.Diagnostics.Stopwatch]::new()
    
    $global:TuiState.Running = $true
    $global:TuiState.FrameCount = 0
    $global:TuiState.DeferredActions = New-Object 'System.Collections.Concurrent.ConcurrentQueue[hashtable]'
    
    while ($global:TuiState.Running) {
        $frameStopwatch.Restart()
        
        try {
            # Phase 1: Handle console resize
            if ([Console]::WindowWidth -ne $global:TuiState.BufferWidth -or 
                [Console]::WindowHeight -ne $global:TuiState.BufferHeight) {
                Invoke-WithErrorHandling -Component "TuiEngine" -Context "Resize" -ScriptBlock { Update-TuiEngineSize }
            }
            
            # Phase 2: Process input  
            Invoke-WithErrorHandling -Component "TuiEngine" -Context "Input" -ScriptBlock {
                $keyAvailable = $false
                
                # Use same improved input detection as optimized engine
                try {
                    $keyAvailable = $Host.UI.RawUI.KeyAvailable
                } catch {
                    try { 
                        $keyAvailable = [Console]::In.Peek() -ne -1 
                    } catch {
                        try { 
                            $keyAvailable = [Console]::KeyAvailable 
                        } catch {}
                    }
                }
                
                if ($keyAvailable) {
                    $keyInfo = [Console]::ReadKey($true)
                    if ($keyInfo) { Process-TuiInput -KeyInfo $keyInfo }
                }
            }
            
            # Phase 3: Process deferred actions
            if ($global:TuiState.DeferredActions.Count -gt 0) {
                $deferredAction = $null
                if ($global:TuiState.DeferredActions.TryDequeue([ref]$deferredAction)) {
                    if ($deferredAction -and $deferredAction.ActionName) {
                        Invoke-WithErrorHandling -Component "TuiEngine" -Context "DeferredAction" -ScriptBlock {
                            $actionService = $global:TuiState.Services.ActionService
                            if ($actionService) { $actionService.ExecuteAction($deferredAction.ActionName, @{}) }
                        }
                    }
                }
            }
            
            # Phase 4: Render frame
            Invoke-WithErrorHandling -Component "TuiEngine" -Context "Render" -ScriptBlock { Invoke-TuiRender }
            
            $global:TuiState.FrameCount++
            
            # Phase 5: Frame rate throttling
            $frameStopwatch.Stop()
            $elapsedTime = $frameStopwatch.Elapsed
            
            if ($elapsedTime -lt $targetFrameTime) {
                $sleepTime = $targetFrameTime - $elapsedTime
                if ($sleepTime.TotalMilliseconds -gt 1) { Start-Sleep -Milliseconds ([int]$sleepTime.TotalMilliseconds) }
            }
        }
        catch {
            # Write-Log -Level Error -Message "TUI Engine: Unhandled error in frame $($global:TuiState.FrameCount): $($_.Exception.Message)"
            Start-Sleep -Milliseconds 50
        }
    }
}

# Optimized render state initialization
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
    
    # DEBUG: Show redraw requests
    #Write-Host "REDRAW: Request from $Source (Immediate=$($Immediate.IsPresent), Force=$($Force.IsPresent))" -ForegroundColor Yellow
    
    # Initialize render state if not present
    if (-not $global:TuiState.PSObject.Properties['RenderState']) {
        #Write-Host "REDRAW: Initializing render state" -ForegroundColor Yellow
        Initialize-OptimizedRenderState
    }
    
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
    #Write-Host "REDRAW: Set ShouldRender = true" -ForegroundColor Yellow
    
    if ($Immediate -or $Force) {
        $renderState.RenderRequested = $true
        #Write-Host "REDRAW: Set RenderRequested = true (immediate)" -ForegroundColor Yellow
    } else {
        $renderState.BatchedRequests++
        #Write-Host "REDRAW: Incremented BatchedRequests to $($renderState.BatchedRequests)" -ForegroundColor Yellow
    }
    
    # Wake up the render loop if it's sleeping
    if ($global:TuiState.PSObject.Properties['RenderEvent']) {
        [void]$global:TuiState.RenderEvent.Set()
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

function Stop-TuiEngine {
    [CmdletBinding()]
    param(
        [switch]$Force
    )
    
    try {
        $global:TuiState.Running = $false
        
        $navService = $global:TuiState.Services.NavigationService
        if ($navService) { $navService.Reset() }
        
        $container = $global:TuiState.ServiceContainer
        if ($container) { $container.Cleanup() }
        
        [Console]::CursorVisible = $true
        [Console]::Clear()
        [Console]::SetCursorPosition(0, 0)
        
    }
    catch {
        Write-Error "Error stopping TUI engine: $_"
    }
}

function Update-TuiEngineSize {
    [CmdletBinding()]
    param()
    
    try {
        $newWidth = $null
        $newHeight = $null
        
        try { $newWidth = $Host.UI.RawUI.WindowSize.Width; $newHeight = $Host.UI.RawUI.WindowSize.Height } catch {}
        if (-not $newWidth -or $newWidth -le 0) { try { $newWidth = [Console]::WindowWidth; $newHeight = [Console]::WindowHeight } catch {} }
        
        if (($null -eq $newWidth -or $newWidth -le 0) -and $IsWindows) {
            try {
                $modeOutput = cmd /c mode con 2>&1
                $colsLine = $modeOutput | Where-Object { $_ -match "Columns:" }
                $linesLine = $modeOutput | Where-Object { $_ -match "Lines:" }
                if ($colsLine) { $newWidth = [int]($colsLine -replace '.*:\s*', '') }
                if ($linesLine) { $newHeight = [int]($linesLine -replace '.*:\s*', '') }
            } catch {}
        }
        
        if ($null -eq $newWidth -or $newWidth -le 0 -or $null -eq $newHeight -or $newHeight -le 0) {
            $newWidth = 120
            $newHeight = 30
            Write-Log -Level Warning -Message "Could not detect console size. Using fallback: ${newWidth}x${newHeight}"
        }
        
        if ($newWidth -ne $global:TuiState.BufferWidth -or $newHeight -ne $global:TuiState.BufferHeight) {
            $global:TuiState.BufferWidth = $newWidth
            $global:TuiState.BufferHeight = $newHeight
            
            if ($global:TuiState.CompositorBuffer) { $global:TuiState.CompositorBuffer.Resize($newWidth, $newHeight) }
            if ($global:TuiState.PreviousCompositorBuffer) { $global:TuiState.PreviousCompositorBuffer.Resize($newWidth, $newHeight) }
            
            if ($global:TuiState.Services) {
                $navService = $global:TuiState.Services.NavigationService
                if ($navService -and $navService.CurrentScreen) { 
                    try {
                        $navService.CurrentScreen.Resize($newWidth, $newHeight)
                    } catch {
                        Write-Log -Level Warning -Message "Error resizing current screen: $($_.Exception.Message)"
                    }
                }
            }
            
            $global:TuiState.IsDirty = $true
            if ($global:TuiState.CompositorBuffer) { [Console]::Clear() }
        }
    }
    catch {
        Write-Error "Failed to update engine size: $_"
    }
}

function Start-AxiomPhoenix {
    [CmdletBinding()]
    param(
        [object]$ServiceContainer,
        [object]$InitialScreen
    )
    
    try {
        if ($null -eq $ServiceContainer -or $ServiceContainer.GetType().Name -ne 'ServiceContainer') {
            throw [System.ArgumentException]::new("A valid ServiceContainer object is required.")
        }
        
        if ($null -ne $InitialScreen -and -not ($InitialScreen.PSObject.Properties['ServiceContainer'] -and $InitialScreen.PSObject.Methods['Initialize'])) {
            throw [System.ArgumentException]::new("InitialScreen must be a valid Screen-derived object.")
        }
        
        $global:TuiState.ServiceContainer = $ServiceContainer
        $global:TuiState.Services = @{ ServiceContainer = $ServiceContainer }
        
        $serviceNames = @(
            'ActionService', 'KeybindingService', 'NavigationService', 
            'DataManager', 'ThemeManager', 'EventManager', 'Logger', 'DialogManager',
            'ViewDefinitionService', 'FileSystemService'
        )
        
        foreach ($serviceName in $serviceNames) {
            try {
                $service = $ServiceContainer.GetService($serviceName)
                if ($service) { 
                    $global:TuiState.Services[$serviceName] = $service
                    # Log successful service registration
                    if ($serviceName -eq 'Logger' -and $service) {
                        $service.Log("Logger service registered in global state", "Debug")
                    }
                }
            }
            catch {
                # Can't use Write-Log yet if Logger isn't loaded
                Write-Host "Failed to get service '$serviceName': $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        # Now that Logger is loaded, write a startup log
        Write-Log -Level Info -Message "Start-AxiomPhoenix: Services loaded, initializing engine"
        
        Write-Log -Level Debug -Message "Start-AxiomPhoenix: About to call Initialize-TuiEngine"
        Initialize-TuiEngine
        Write-Log -Level Debug -Message "Start-AxiomPhoenix: Initialize-TuiEngine completed"
        
        Write-Log -Level Debug -Message "Start-AxiomPhoenix: Getting NavigationService"
        $navService = $global:TuiState.Services.NavigationService
        if ($InitialScreen) {
            Write-Log -Level Debug -Message "Start-AxiomPhoenix: About to call NavigateTo with screen: $($InitialScreen.Name)"
            $navService.NavigateTo($InitialScreen)
            Write-Log -Level Debug -Message "Start-AxiomPhoenix: NavigateTo completed successfully"
        } else {
            Write-Log -Level Warning -Message "No initial screen provided."
        }
        
        Write-Log -Level Debug -Message "Start-AxiomPhoenix: About to call Start-TuiEngine"
        Start-TuiEngine -EnablePerformanceMonitoring
        Write-Log -Level Debug -Message "Start-AxiomPhoenix: Start-TuiEngine completed"
    }
    catch {
        Invoke-PanicHandler $_
    }
    finally {
        Stop-TuiEngine
    }
}

#endregion
#<!-- END_PAGE: ART.002 -->