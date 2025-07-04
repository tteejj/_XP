# ==============================================================================
# PMC Terminal Axiom-Phoenix v4.0 - Panic Handler Module
# ==============================================================================
# Purpose: Provides fail-safe error handling and terminal restoration
# Features:
#   - Captures unhandled exceptions from any part of the application
#   - Safely restores terminal to usable state
#   - Creates detailed crash reports with diagnostics
#   - Preserves last known good screen state
# ==============================================================================

using namespace System
using namespace System.Text
using namespace System.IO

# Global panic state tracking
$script:PanicState = @{
    HasPanicked = $false
    LastScreenBuffer = $null
    CrashLogPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PMCTerminal\CrashLogs'
    MaxCrashLogs = 10
}

class PanicHandler {
    static [string] $CrashLogDirectory
    static [TuiBuffer] $LastGoodFrame
    static [bool] $IsInitialized = $false
    static [datetime] $SessionStartTime
    static [hashtable] $SystemInfo = @{}
    
    # Initialize the panic handler system
    static [void] Initialize() {
        if ([PanicHandler]::IsInitialized) { return }
        
        try {
            # Set up crash log directory
            [PanicHandler]::CrashLogDirectory = $script:PanicState.CrashLogPath
            if (-not (Test-Path [PanicHandler]::CrashLogDirectory)) {
                New-Item -ItemType Directory -Path ([PanicHandler]::CrashLogDirectory) -Force | Out-Null
            }
            
            # Clean up old crash logs (keep only last N)
            [PanicHandler]::CleanupOldCrashLogs()
            
            # Capture system information for diagnostics
            [PanicHandler]::SystemInfo = @{
                PSVersion = $PSVersionTable.PSVersion.ToString()
                OSDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
                ProcessArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
                ConsoleWidth = [Console]::WindowWidth
                ConsoleHeight = [Console]::WindowHeight
                ConsoleBufferWidth = [Console]::BufferWidth
                ConsoleBufferHeight = [Console]::BufferHeight
            }
            
            [PanicHandler]::SessionStartTime = [DateTime]::Now
            [PanicHandler]::IsInitialized = $true
            
            Write-Log -Level Info -Message "Panic Handler initialized successfully"
        }
        catch {
            # If we can't initialize panic handler, at least try to log it
            Write-Warning "Failed to initialize Panic Handler: $_"
        }
    }
    
    # Main panic method - called when unhandled exception occurs
    static [void] Panic([Exception]$exception) {
        if ($script:PanicState.HasPanicked) {
            # Prevent recursive panics
            return
        }
        
        $script:PanicState.HasPanicked = $true
        
        try {
            # Step 1: Immediately attempt terminal restoration
            [PanicHandler]::RestoreTerminal()
            
            # Step 2: Create crash report
            $crashReport = [PanicHandler]::CreateCrashReport($exception)
            
            # Step 3: Save crash report to disk
            $crashFile = [PanicHandler]::SaveCrashReport($crashReport)
            
            # Step 4: Display user-friendly error message
            [PanicHandler]::DisplayCrashMessage($crashFile)
            
            # Step 5: Clean up any remaining resources
            [PanicHandler]::CleanupResources()
        }
        catch {
            # Last resort - just try to restore terminal and exit
            try {
                [Console]::ResetColor()
                [Console]::CursorVisible = $true
                [Console]::Clear()
            }
            catch {}
            
            Write-Host "FATAL: Panic handler itself failed. Terminal may be in inconsistent state." -ForegroundColor Red
            Write-Host "Original error: $($exception.Message)" -ForegroundColor Red
        }
    }
    
    # Restore terminal to usable state
    static hidden [void] RestoreTerminal() {
        try {
            # Reset all console attributes
            [Console]::Write("`e[0m")  # Reset all attributes
            [Console]::ResetColor()
            [Console]::CursorVisible = $true
            
            # Clear the screen
            [Console]::Clear()
            
            # Reset cursor position
            [Console]::SetCursorPosition(0, 0)
            
            # Ensure we're not in alternate screen buffer (if supported)
            [Console]::Write("`e[?1049l")
            
            # Reset any terminal modes
            [Console]::TreatControlCAsInput = $false
            
            Write-Log -Level Info -Message "Terminal restored successfully"
        }
        catch {
            # Even if restoration fails, we continue with crash reporting
            Write-Warning "Terminal restoration failed: $_"
        }
    }
    
    # Create detailed crash report
    static hidden [string] CreateCrashReport([Exception]$exception) {
        $report = [StringBuilder]::new()
        
        [void]$report.AppendLine("="*80)
        [void]$report.AppendLine("PMC TERMINAL CRASH REPORT")
        [void]$report.AppendLine("="*80)
        [void]$report.AppendLine()
        
        # Timestamp and session info
        [void]$report.AppendLine("Crash Time: $([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))")
        [void]$report.AppendLine("Session Start: $([PanicHandler]::SessionStartTime.ToString('yyyy-MM-dd HH:mm:ss'))")
        [void]$report.AppendLine("Session Duration: $([DateTime]::Now - [PanicHandler]::SessionStartTime)")
        [void]$report.AppendLine()
        
        # System information
        [void]$report.AppendLine("SYSTEM INFORMATION:")
        foreach ($key in [PanicHandler]::SystemInfo.Keys) {
            [void]$report.AppendLine("  $key : $([PanicHandler]::SystemInfo[$key])")
        }
        [void]$report.AppendLine()
        
        # Exception details
        [void]$report.AppendLine("EXCEPTION DETAILS:")
        [void]$report.AppendLine("Type: $($exception.GetType().FullName)")
        [void]$report.AppendLine("Message: $($exception.Message)")
        [void]$report.AppendLine("Source: $($exception.Source)")
        [void]$report.AppendLine("Target Site: $($exception.TargetSite)")
        [void]$report.AppendLine()
        
        # Stack trace
        [void]$report.AppendLine("STACK TRACE:")
        [void]$report.AppendLine($exception.StackTrace)
        [void]$report.AppendLine()
        
        # Inner exceptions
        $innerEx = $exception.InnerException
        $level = 1
        while ($null -ne $innerEx) {
            [void]$report.AppendLine("INNER EXCEPTION (Level $level):")
            [void]$report.AppendLine("Type: $($innerEx.GetType().FullName)")
            [void]$report.AppendLine("Message: $($innerEx.Message)")
            [void]$report.AppendLine("Stack Trace:")
            [void]$report.AppendLine($innerEx.StackTrace)
            [void]$report.AppendLine()
            
            $innerEx = $innerEx.InnerException
            $level++
        }
        
        # Application state (if available)
        if ($global:TuiState) {
            [void]$report.AppendLine("APPLICATION STATE:")
            [void]$report.AppendLine("  Running: $($global:TuiState.Running)")
            [void]$report.AppendLine("  Current Screen: $($global:TuiState.CurrentScreen?.Name ?? 'None')")
            [void]$report.AppendLine("  Screen Stack Count: $($global:TuiState.ScreenStack?.Count ?? 0)")
            [void]$report.AppendLine("  Overlay Stack Count: $($global:TuiState.OverlayStack?.Count ?? 0)")
            [void]$report.AppendLine("  Buffer Size: $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight)")
            [void]$report.AppendLine()
        }
        
        # Last rendered frame (if available)
        if ([PanicHandler]::LastGoodFrame -or $global:TuiState?.CompositorBuffer) {
            [void]$report.AppendLine("LAST RENDERED FRAME:")
            try {
                $buffer = [PanicHandler]::LastGoodFrame ?? $global:TuiState.CompositorBuffer
                $frameCapture = [PanicHandler]::CaptureBufferAsText($buffer)
                [void]$report.AppendLine($frameCapture)
            }
            catch {
                [void]$report.AppendLine("  [Failed to capture frame: $_]")
            }
            [void]$report.AppendLine()
        }
        
        # Memory usage
        try {
            $process = [System.Diagnostics.Process]::GetCurrentProcess()
            [void]$report.AppendLine("MEMORY USAGE:")
            [void]$report.AppendLine("  Working Set: $([Math]::Round($process.WorkingSet64 / 1MB, 2)) MB")
            [void]$report.AppendLine("  Private Memory: $([Math]::Round($process.PrivateMemorySize64 / 1MB, 2)) MB")
            [void]$report.AppendLine("  Virtual Memory: $([Math]::Round($process.VirtualMemorySize64 / 1MB, 2)) MB")
            [void]$report.AppendLine()
        }
        catch {}
        
        [void]$report.AppendLine("="*80)
        [void]$report.AppendLine("END OF CRASH REPORT")
        [void]$report.AppendLine("="*80)
        
        return $report.ToString()
    }
    
    # Capture buffer content as text for crash report
    static hidden [string] CaptureBufferAsText([TuiBuffer]$buffer) {
        if ($null -eq $buffer) { return "[No buffer available]" }
        
        $capture = [StringBuilder]::new()
        [void]$capture.AppendLine("┌$('─' * $buffer.Width)┐")
        
        for ($y = 0; $y -lt $buffer.Height; $y++) {
            [void]$capture.Append('│')
            for ($x = 0; $x -lt $buffer.Width; $x++) {
                $cell = $buffer.GetCell($x, $y)
                if ($null -ne $cell) {
                    [void]$capture.Append($cell.Char)
                }
                else {
                    [void]$capture.Append(' ')
                }
            }
            [void]$capture.AppendLine('│')
        }
        
        [void]$capture.AppendLine("└$('─' * $buffer.Width)┘")
        return $capture.ToString()
    }
    
    # Save crash report to disk
    static hidden [string] SaveCrashReport([string]$report) {
        try {
            $timestamp = [DateTime]::Now.ToString('yyyyMMdd_HHmmss')
            $filename = "crash_${timestamp}.log"
            $filepath = Join-Path ([PanicHandler]::CrashLogDirectory) $filename
            
            [File]::WriteAllText($filepath, $report)
            
            return $filepath
        }
        catch {
            # If we can't save to disk, at least return empty string
            Write-Warning "Failed to save crash report: $_"
            return ""
        }
    }
    
    # Display user-friendly crash message
    static hidden [void] DisplayCrashMessage([string]$crashFile) {
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║           PMC TERMINAL - UNHANDLED EXCEPTION                  ║" -ForegroundColor Red
        Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "An unexpected error occurred and the application had to close." -ForegroundColor Yellow
        Write-Host ""
        
        if (-not [string]::IsNullOrEmpty($crashFile)) {
            Write-Host "A crash report has been saved to:" -ForegroundColor Cyan
            Write-Host "  $crashFile" -ForegroundColor White
            Write-Host ""
        }
        
        Write-Host "Please report this issue with the crash report to help improve the application." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        
        try {
            [Console]::ReadKey($true) | Out-Null
        }
        catch {}
    }
    
    # Clean up any remaining resources
    static hidden [void] CleanupResources() {
        try {
            # Stop any running input threads
            if ($global:TuiState) {
                $global:TuiState.CancellationTokenSource?.Cancel()
                $global:TuiState.InputPowerShell?.Stop()
                $global:TuiState.InputRunspace?.Close()
            }
            
            # Clear any event subscriptions
            if (Get-Command -Name "Clear-AllEventSubscriptions" -ErrorAction SilentlyContinue) {
                Clear-AllEventSubscriptions
            }
        }
        catch {
            # Best effort cleanup - don't throw
        }
    }
    
    # Clean up old crash logs
    static hidden [void] CleanupOldCrashLogs() {
        try {
            $crashLogs = Get-ChildItem -Path ([PanicHandler]::CrashLogDirectory) -Filter "crash_*.log" |
                         Sort-Object -Property LastWriteTime -Descending
            
            if ($crashLogs.Count -gt $script:PanicState.MaxCrashLogs) {
                $toDelete = $crashLogs | Select-Object -Skip $script:PanicState.MaxCrashLogs
                $toDelete | Remove-Item -Force
            }
        }
        catch {
            # Non-critical operation
        }
    }
    
    # Store the last good frame for crash reporting
    static [void] StoreLastGoodFrame([TuiBuffer]$buffer) {
        if ($null -ne $buffer) {
            # Create a copy of the buffer
            [PanicHandler]::LastGoodFrame = [TuiBuffer]::new($buffer.Width, $buffer.Height, "LastGoodFrame")
            [PanicHandler]::LastGoodFrame.BlendBuffer($buffer, 0, 0)
        }
    }
}

# Export functions for module use
function Initialize-PanicHandler {
    [PanicHandler]::Initialize()
}

function Invoke-Panic {
    param([Exception]$Exception)
    [PanicHandler]::Panic($Exception)
}

function Store-LastGoodFrame {
    param([TuiBuffer]$Buffer)
    [PanicHandler]::StoreLastGoodFrame($Buffer)
}

# Export module members
Export-ModuleMember -Function Initialize-PanicHandler, Invoke-Panic, Store-LastGoodFrame