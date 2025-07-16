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
        [int]$PerformanceReportInterval = 300  # frames
    )
    
    try {
        Write-Log -Level Info -Message "Starting TUI Engine with target FPS: $TargetFPS"
        
        Write-Log -Level Debug -Message "Start-TuiEngine: Setting up frame timing"
        $targetFrameTime = [timespan]::FromSeconds(1.0 / $TargetFPS)
        $frameStopwatch = [System.Diagnostics.Stopwatch]::new()
        
        Write-Log -Level Debug -Message "Start-TuiEngine: Initializing engine state"
        $global:TuiState.Running = $true
        $global:TuiState.FrameCount = 0
        $global:TuiState.DeferredActions = New-Object 'System.Collections.Concurrent.ConcurrentQueue[hashtable]'
        
        Write-Log -Level Debug -Message "Start-TuiEngine: Entering main render loop"
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
                    # Linux-compatible key input detection
                    $keyAvailable = $false
                    try {
                        $keyAvailable = [Console]::KeyAvailable
                    } catch {
                        # Use Console.In.Peek for Linux compatibility
                        try { $keyAvailable = [Console]::In.Peek() -ne -1 } catch {}
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
                Write-Log -Level Error -Message "TUI Engine: Unhandled error in frame $($global:TuiState.FrameCount): $($_.Exception.Message)"
                Start-Sleep -Milliseconds 50
            }
        }
    }
    catch {
        Write-Log -Level Fatal -Message "TUI Engine critical error: $($_.Exception.Message)"
        Invoke-PanicHandler $_
    }
    finally {
        Stop-TuiEngine
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
        Start-TuiEngine
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