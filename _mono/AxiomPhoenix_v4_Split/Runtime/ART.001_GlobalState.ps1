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

#region Global State

# Initialize global TUI state
$global:TuiState = @{
    Running = $false
    BufferWidth = 80
    BufferHeight = 24
    CompositorBuffer = $null
    PreviousCompositorBuffer = $null
    ScreenStack = [System.Collections.Generic.Stack[Screen]]::new() # CHANGED TO GENERIC STACK
    CurrentScreen = $null
    IsDirty = $true
    FocusedComponent = $null
    # CommandPalette removed - now managed by CommandPaletteManager service
    Services = @{}
    LastRenderTime = [datetime]::Now
    FrameCount = 0
    InputQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]'
    OverlayStack = [System.Collections.Stack]::new() # Stack for proper Peek()
    # Added for input thread management
    CancellationTokenSource = $null
    InputRunspace = $null
    InputPowerShell = $null
    InputAsyncResult = $null
}

function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Component,
        
        [Parameter(Mandatory)]
        [string]$Context,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [hashtable]$AdditionalData = @{}
    )
    
    try {
        & $ScriptBlock
    }
    catch {
        $errorDetails = @{
            Component = $Component
            Context = $Context
            ErrorMessage = $_.Exception.Message
            ErrorType = $_.Exception.GetType().FullName
            StackTrace = $_.ScriptStackTrace
            Timestamp = [datetime]::Now
        }
        
        foreach ($key in $AdditionalData.Keys) {
            $errorDetails[$key] = $AdditionalData[$key]
        }
        
        $logger = $global:TuiState.Services.Logger
        if ($logger) {
            $logger.Log("Error", "Error in $Component during $Context : $($_.Exception.Message)")
            # Simple error logging without JSON serialization
            $logger.Log("Debug", "Error type: $($_.Exception.GetType().FullName)")
        }
        
        # Re-throw for caller to handle if needed
        throw
    }
}
#endregion
#<!-- END_PAGE: ART.001 -->
