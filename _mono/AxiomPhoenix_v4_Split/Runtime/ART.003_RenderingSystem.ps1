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

#region Rendering System

function Invoke-TuiRender {
    [CmdletBinding()]
    param()
    
    try {
        if ($null -eq $global:TuiState.CompositorBuffer) {
            return
        }
        
        # Clear the main compositor buffer with the base theme background
        $bgColor = Get-ThemeColor "Screen.Background" "#000000"
        $global:TuiState.CompositorBuffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # FIXED: WINDOW-BASED MODEL: Render all windows in the stack
        $navService = $global:TuiState.Services.NavigationService
        if ($navService) {
            # GetWindows() returns the stack from bottom to top, with the current screen last.
            $windowsToRender = $navService.GetWindows()
            
            foreach ($window in $windowsToRender) {
                if ($null -eq $window -or -not $window.Visible) { continue }
                
                try {
                    # Render the window, which updates its internal buffer
                    $window.Render()
                    
                    # Get the window's buffer and blend it onto the main compositor
                    $windowBuffer = $window.GetBuffer()
                    if ($windowBuffer) {
                        # The BlendBuffer method in TuiBuffer handles the Z-indexing and composition.
                        # For overlays, the dialog's OnRender method should handle dimming the background.
                        $global:TuiState.CompositorBuffer.BlendBuffer($windowBuffer, 0, 0)
                    }
                }
                catch {
                    Write-Error "Error rendering window '$($window.Name)': $_"
                    throw
                }
            }
        }
        
        # FIXED: Force full redraw on first frame by making previous buffer different
        if ($global:TuiState.FrameCount -eq 0) {
            for ($y = 0; $y -lt $global:TuiState.PreviousCompositorBuffer.Height; $y++) {
                for ($x = 0; $x -lt $global:TuiState.PreviousCompositorBuffer.Width; $x++) {
                    # Use a character and color that is unlikely to be the default
                    $global:TuiState.PreviousCompositorBuffer.SetCell($x, $y, [TuiCell]::new('?', "#010101", "#010101"))
                }
            }
        }
        
        # Differential rendering - compare current compositor to previous
        Render-DifferentialBuffer
        
        # FIXED: Swap buffers for next frame using the efficient Clone() method
        $global:TuiState.PreviousCompositorBuffer = $global:TuiState.CompositorBuffer.Clone()
        
    }
    catch {
        Write-Error "Render error: $_"
        throw
    }
}

function Render-DifferentialBuffer {
    [CmdletBinding()]
    param()
    
    try {
        $current = $global:TuiState.CompositorBuffer
        $previous = $global:TuiState.PreviousCompositorBuffer
        
        if ($null -eq $current -or $null -eq $previous) {
            return
        }
        
        $ansiBuilder = [System.Text.StringBuilder]::new()
        $lastFg = $null
        $lastBg = $null
        $lastBold = $false
        $lastItalic = $false
        $lastUnderline = $false
        $lastStrikethrough = $false
        
        $needsReset = $true # Start with a reset
        
        for ($y = 0; $y -lt $current.Height; $y++) {
            for ($x = 0; $x -lt $current.Width; $x++) {
                $currentCell = $current.GetCell($x, $y)
                $previousCell = $previous.GetCell($x, $y)
                
                if ($currentCell.DiffersFrom($previousCell)) {
                    # Move cursor to the correct position
                    [void]$ansiBuilder.Append("`e[$($y + 1);$($x + 1)H")
                    
                    # Check if styling has changed
                    $styleChanged = ($currentCell.ForegroundColor -ne $lastFg) -or
                                    ($currentCell.BackgroundColor -ne $lastBg) -or
                                    ($currentCell.Bold -ne $lastBold) -or
                                    ($currentCell.Italic -ne $lastItalic) -or
                                    ($currentCell.Underline -ne $lastUnderline) -or
                                    ($currentCell.Strikethrough -ne $lastStrikethrough)

                    if ($styleChanged) {
                        # Use the cell's ToAnsiString method which generates the full sequence
                        [void]$ansiBuilder.Append($currentCell.ToAnsiString())
                        
                        # Update last known styles
                        $lastFg = $currentCell.ForegroundColor
                        $lastBg = $currentCell.BackgroundColor
                        $lastBold = $currentCell.Bold
                        $lastItalic = $currentCell.Italic
                        $lastUnderline = $currentCell.Underline
                        $lastStrikethrough = $currentCell.Strikethrough
                    } else {
                        # Style is the same, just print the character
                        [void]$ansiBuilder.Append($currentCell.Char)
                    }
                }
            }
        }
        
        # Reset styling at the very end of the string
        if ($ansiBuilder.Length -gt 0) {
            [void]$ansiBuilder.Append([TuiAnsiHelper]::Reset())
            [Console]::Write($ansiBuilder.ToString())
        }
    }
    catch {
        Write-Error "Differential rendering error: $_"
        throw
    }
}

#endregion
#<!-- END_PAGE: ART.003 -->