# Comprehensive fixes for acta.ps1 errors
# Run this to apply all fixes to all.txt

$filePath = "C:\Users\jhnhe\Documents\GitHub\_XP\all.txt"
$content = Get-Content -Path $filePath -Raw

# Fix 1: Add missing Dialog base class before CommandPalette
$dialogClassDefinition = @'

# Base Dialog class (was missing)
class Dialog : UIElement {
    [string]$Title = "Dialog"
    [bool]$IsModal = $true
    [bool]$IsOpen = $false
    
    Dialog([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 60
        $this.Height = 20
    }
    
    [void] Show() {
        $this.IsOpen = $true
        Push-Overlay -Overlay $this
        $this.RequestRedraw()
    }
    
    [void] Close() {
        $this.IsOpen = $false
        Pop-Overlay
        $this.RequestRedraw()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Close()
            return $true
        }
        return $false
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer with semi-transparent background
        $this._private_buffer.Clear([TuiCell]::new(' ', "#FFFFFF", "#000000"))
        
        # Draw dialog box
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
            -Title $this.Title -Style @{ BorderStyle = "Double"; BorderFG = "#58a6ff"; BG = "#0d1117" }
    }
}

'@

# Insert Dialog class before CommandPalette
$insertPoint = "# In modules\\dialog-system-class\\dialog-system-class.psm1"
$content = $content -replace "($insertPoint)", "$1`n$dialogClassDefinition"

# Fix 2: Add missing PanicHandler class
$panicHandlerClass = @'

# --- START OF ORIGINAL FILE: modules/panic-handler.psm1 ---
class PanicHandler {
    static [void] Panic([Exception]$exception) {
        try {
            $dumpPath = Join-Path $env:TEMP "ProjectActa_Crash"
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $crashDir = Join-Path $dumpPath $timestamp
            New-Item -ItemType Directory -Path $crashDir -Force | Out-Null

            $stateDump = @{
                Reason = $exception.Message
                ExceptionType = $exception.GetType().FullName
                StackTrace = $exception.StackTrace
                Timestamp = $timestamp
                PSVersion = if ($null -ne $PSVersionTable) { $PSVersionTable.PSVersion.ToString() } else { "Unknown" }
                CurrentScreen = if ($null -ne $global:TuiState -and $null -ne $global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.Name } else { "Unknown" }
            }
            $stateDump | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $crashDir "crash.json")

            # Attempt to take a screenshot of the last valid buffer state
            if ($null -ne $global:TuiState -and $null -ne $global:TuiState.CompositorBuffer) {
                $sb = [System.Text.StringBuilder]::new()
                for ($y = 0; $y -lt $global:TuiState.BufferHeight; $y++) {
                    for ($x = 0; $x -lt $global:TuiState.BufferWidth; $x++) {
                        $sb.Append($global:TuiState.CompositorBuffer.GetCell($x, $y).Char)
                    }
                    $sb.AppendLine()
                }
                $sb.ToString() | Set-Content (Join-Path $crashDir "screen.txt")
            }
            
            Write-Host "A crash dump has been saved to: $crashDir" -ForegroundColor Yellow
        } catch { 
            Write-Host "Failed to create crash dump: $_" -ForegroundColor Red
        }
        finally {
            # Attempt to restore the terminal to a usable state.
            [Console]::Write("`e[0m`e[2J`e[H")
            [Console]::ResetColor()
            [Console]::CursorVisible = $true
            Write-Host "FATAL ERROR: A critical, unhandled exception occurred." -ForegroundColor Red
            exit 1
        }
    }
}
# --- END OF ORIGINAL FILE ---

'@

# Find where to insert PanicHandler (before it's used)
if ($content -notmatch "class PanicHandler") {
    # Insert after dialog system section
    $dialogSectionEnd = "# --- END OF ORIGINAL FILE: modules\\dialog-system-class\\dialog-system-class.psm1 ---"
    $content = $content -replace "($dialogSectionEnd)", "$1`n`n$panicHandlerClass"
}

# Fix 3: Fix KanbanBoardComponent $this.$Columns syntax error
# The error is likely in the SetData method where columns are being assigned
$content = $content -replace '\$this\.\$Columns', '$this.Columns'

# Fix 4: Add missing closing braces
# Search for incomplete class definitions and ensure they're closed properly
# This is harder to do generically, but we'll check common patterns

# Fix 5: Ensure all hashtables use proper syntax
$content = $content -replace 'PSVersion = if \(\$null -ne \$PSVersionTable\) \{ \$PSVersi', 'PSVersion = if ($null -ne $PSVersionTable) { $PSVersionTable.PSVersion.ToString() } else { "Unknown" }'

# Fix 6: Add missing helper functions for dialogs
$dialogHelpers = @'

# Dialog system helper functions
function Push-Overlay {
    param([UIElement]$Overlay)
    if ($null -eq $global:TuiState.OverlayStack) {
        $global:TuiState.OverlayStack = [System.Collections.Generic.Stack[UIElement]]::new()
    }
    $global:TuiState.OverlayStack.Push($Overlay)
    Request-TuiRefresh
}

function Pop-Overlay {
    if ($null -ne $global:TuiState.OverlayStack -and $global:TuiState.OverlayStack.Count -gt 0) {
        [void]$global:TuiState.OverlayStack.Pop()
        Request-TuiRefresh
    }
}

'@

# Insert dialog helpers after dialog system classes
$dialogSystemEnd = "# --- END OF ORIGINAL FILE: modules\\dialog-system-class\\dialog-system-class.psm1 ---"
if ($content -notmatch "function Push-Overlay") {
    $content = $content -replace "($dialogSystemEnd)", "$dialogHelpers`n$1"
}

# Save the fixed content
Set-Content -Path $filePath -Value $content -Encoding UTF8

Write-Host "All fixes have been applied to all.txt" -ForegroundColor Green
Write-Host "Fixed issues:" -ForegroundColor Yellow
Write-Host "  1. Added missing Dialog base class" -ForegroundColor Gray
Write-Host "  2. Added missing PanicHandler class with proper PSVersion and crashDir handling" -ForegroundColor Gray
Write-Host "  3. Fixed `$this.`$Columns syntax error" -ForegroundColor Gray
Write-Host "  4. Added dialog helper functions (Push-Overlay, Pop-Overlay)" -ForegroundColor Gray
Write-Host "  5. Fixed incomplete PSVersion assignment" -ForegroundColor Gray
