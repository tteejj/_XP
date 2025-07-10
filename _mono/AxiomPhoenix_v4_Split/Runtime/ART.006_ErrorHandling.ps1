####\AllRuntime.ps1
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

#region Panic Handler

function Invoke-PanicHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ErrorRecord
    )
    
    # Ensure we're in a safe state to write to console
    try {
        [Console]::ResetColor()
        [Console]::CursorVisible = $true
        Clear-Host
    } catch { }
    
    Write-Host "`n`n" -NoNewline
    Write-Host "================================ PANIC HANDLER ================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "An unrecoverable error has occurred:" -ForegroundColor Yellow
    Write-Host ""
    
    # Error details
    Write-Host "ERROR: " -ForegroundColor Red -NoNewline
    Write-Host $ErrorRecord.Exception.Message
    Write-Host ""
    Write-Host "TYPE: " -ForegroundColor Yellow -NoNewline
    Write-Host $ErrorRecord.Exception.GetType().FullName
    Write-Host ""
    
    # Stack trace
    Write-Host "STACK TRACE:" -ForegroundColor Yellow
    $stackLines = $ErrorRecord.ScriptStackTrace -split "`n"
    foreach ($line in $stackLines) {
        Write-Host "  $line" -ForegroundColor DarkGray
    }
    Write-Host ""
    
    # System info
    Write-Host "SYSTEM INFO:" -ForegroundColor Yellow
    Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    Write-Host "  Platform: $($PSVersionTable.Platform)" -ForegroundColor DarkGray
    Write-Host "  OS: $($PSVersionTable.OS)" -ForegroundColor DarkGray
    Write-Host "  Host: $($Host.Name) v$($Host.Version)" -ForegroundColor DarkGray
    Write-Host ""
    
    # Save crash report
    $crashDir = Join-Path $env:TEMP "AxiomPhoenix\Crashes"
    if (-not (Test-Path $crashDir)) {
        New-Item -ItemType Directory -Path $crashDir -Force | Out-Null
    }
    
    $crashFile = Join-Path $crashDir "crash_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $crashReport = @{
        Timestamp = [datetime]::Now
        Error = @{
            Message = $ErrorRecord.Exception.Message
            Type = $ErrorRecord.Exception.GetType().FullName
            StackTrace = $ErrorRecord.ScriptStackTrace
            InnerException = if ($ErrorRecord.Exception.InnerException) { $ErrorRecord.Exception.InnerException.Message } else { $null }
        }
        System = @{
            PowerShell = $PSVersionTable.PSVersion.ToString()
            Platform = $PSVersionTable.Platform
            OS = $PSVersionTable.OS
            Host = "$($Host.Name) v$($Host.Version)"
        }
        GlobalState = @{
            Running = $global:TuiState.Running
            BufferSize = "$($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight)"
            CurrentScreen = if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.Name } else { "None" }
            OverlayCount = if ($global:TuiState.OverlayStack) { $global:TuiState.OverlayStack.Count } else { 0 }
        }
    }
    
    try {
        # Sanitize crash report data to avoid circular references
        $sanitizedReport = @{
            Timestamp = $crashReport.Timestamp
            ErrorMessage = $crashReport.ErrorMessage
            ErrorType = $crashReport.ErrorType
            ScriptStackTrace = $crashReport.ScriptStackTrace
            GlobalState = @{
                Running = $crashReport.GlobalState.Running
                BufferSize = $crashReport.GlobalState.BufferSize
                CurrentScreen = $crashReport.GlobalState.CurrentScreen
                OverlayCount = $crashReport.GlobalState.OverlayCount
            }
        }
        $sanitizedReport | ConvertTo-Json -Depth 5 | Out-File -FilePath $crashFile -Encoding UTF8
        Write-Host "Crash report saved to: $crashFile" -ForegroundColor Green
    } catch {
        Write-Host "Failed to save crash report: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Final cleanup
    try {
        Stop-TuiEngine -Force
    } catch { }
    
    exit 1
}

function Start-AxiomPhoenix {
    [CmdletBinding()]
    param(
        [object]$ServiceContainer,  # Changed from [ServiceContainer] to [object]
        [object]$InitialScreen      # Changed from [Screen] to [object]
    )
    
    try {
        # Write-Log -Level Info -Message "Starting Axiom-Phoenix application..."
        
        # Validate ServiceContainer
        if ($null -eq $ServiceContainer) {
            throw [System.ArgumentNullException]::new("ServiceContainer")
        }
        if ($ServiceContainer.GetType().Name -ne 'ServiceContainer') {
            throw [System.ArgumentException]::new("Expected ServiceContainer but got $($ServiceContainer.GetType().Name)")
        }
        
        # Validate InitialScreen if provided
        if ($null -ne $InitialScreen) {
            # Check if it's a Screen-derived type by looking for expected properties/methods
            if (-not ($InitialScreen.PSObject.Properties['ServiceContainer'] -and 
                      $InitialScreen.PSObject.Methods['Initialize'] -and
                      $InitialScreen.PSObject.Methods['OnEnter'])) {
                throw [System.ArgumentException]::new("Expected Screen-derived object but got $($InitialScreen.GetType().Name)")
            }
        }
        
        # Store services
        $global:TuiState.Services = @{
            ServiceContainer = $ServiceContainer
        }
        
        # Extract key services for quick access
        $serviceNames = @(
            'ActionService', 'KeybindingService', 'NavigationService', 
            'DataManager', 'ThemeManager', 'EventManager', 'Logger', 'FocusManager', 'DialogManager', 
            'TuiFrameworkService', 'CommandPaletteManager' # Add new services
        )
        
        foreach ($serviceName in $serviceNames) {
            try {
                $service = $ServiceContainer.GetService($serviceName)
                if ($service) {
                    $global:TuiState.Services[$serviceName] = $service
                }
            }
            catch {
                # Write-Log -Level Warning -Message "Failed to get service '$serviceName': $($_.Exception.Message)" -Data $_
            }
        }
        
        # CommandPalette is now managed by the CommandPaletteManager service
        
        # Initialize engine
        Initialize-TuiEngine
        
        # Get the NavigationService instance directly from global state
        $navService = $global:TuiState.Services.NavigationService

        # Set initial screen using NavigationService (CRUCIAL FIX)
        if ($InitialScreen) {
            Write-Log -Level Debug -Message "Start-AxiomPhoenix: Navigating to initial screen: $($InitialScreen.Name)"
            $navService.NavigateTo($InitialScreen) # Use the service directly
            Write-Log -Level Debug -Message "Start-AxiomPhoenix: Navigation complete. CurrentScreen: $($navService.CurrentScreen?.Name)"
        }
        else {
            Write-Log -Level Warning -Message "No initial screen provided. Application might not display anything."
        }
        
        # Start main loop
        Start-TuiEngine
    }
    catch {
        # Use Invoke-PanicHandler for critical startup errors
        Invoke-PanicHandler $_
    }
    finally {
        Stop-TuiEngine # Ensure cleanup even if startup fails
    }
}

#endregion
#<!-- END_PAGE: ART.006 -->
