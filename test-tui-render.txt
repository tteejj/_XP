# Minimal TUI Render Test
# This script tests if the TUI can render after scope fixes

Set-Location "C:\Users\jhnhe\Documents\GitHub\_XP"

# Import required modules in correct order
Import-Module ".\modules\exception-system.psm1" -Global
Import-Module ".\modules\logging.psm1" -Global  
Import-Module ".\modules\theme-manager.psm1" -Global
Import-Module ".\modules\event-system.psm1" -Global
Import-Module ".\modules\tui-engine-v2.psm1" -Global
Import-Module ".\components\tui-components.psm1" -Global

Write-Host "Creating test screen..." -ForegroundColor Cyan

# Create a minimal test screen
$testScreen = @{
    Name = "TestScreen"
    Components = @{}
    
    Init = {
        param($self, $services)
        Write-Host "Test screen initializing..." -ForegroundColor Green
        
        # Add a simple label to verify rendering
        $label = New-TuiLabel -X 5 -Y 5 -Text "TUI IS RENDERING!" -ForegroundColor Green
        $self.Components["TestLabel"] = $label
        
        # Add a box to make it obvious
        $box = New-TuiBox -X 2 -Y 2 -Width 30 -Height 10 -Title "Render Test"
        $self.Components["TestBox"] = $box
    }
    
    Render = {
        param($self)
        # Render all components
        foreach ($component in $self.Components.Values) {
            if ($component.Render) {
                & $component.Render -self $component
            }
        }
    }
    
    HandleInput = {
        param($self, $Key)
        if ($Key.Key -eq [ConsoleKey]::Escape -or $Key.Key -eq [ConsoleKey]::Q) {
            return "Quit"
        }
    }
}

try {
    Write-Host "Initializing TUI Engine..." -ForegroundColor Cyan
    Initialize-TuiEngine
    
    Write-Host "Starting render test (Press ESC or Q to quit)..." -ForegroundColor Yellow
    
    # Quick test - just render one frame
    Push-Screen -Screen $testScreen
    Clear-BackBuffer
    
    # Force a render
    if ($global:TuiState.CurrentScreen -and $global:TuiState.CurrentScreen.Render) {
        & $global:TuiState.CurrentScreen.Render -self $global:TuiState.CurrentScreen
    }
    
    # Check if anything was written to the buffer
    $hasContent = $false
    for ($y = 0; $y -lt $global:TuiState.BufferHeight; $y++) {
        for ($x = 0; $x -lt $global:TuiState.BufferWidth; $x++) {
            if ($global:TuiState.BackBuffer[$y, $x].Char -ne ' ') {
                $hasContent = $true
                break
            }
        }
        if ($hasContent) { break }
    }
    
    if ($hasContent) {
        Write-Host "`nSUCCESS: Content detected in buffer!" -ForegroundColor Green
        Write-Host "The TUI is now able to render. Starting full loop..." -ForegroundColor Green
        
        # Now run the full loop
        Start-TuiLoop
    } else {
        Write-Host "`nFAILED: No content in buffer - rendering is still broken!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "`nERROR during test: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
} finally {
    # Cleanup
    [Console]::Clear()
    [Console]::CursorVisible = $true
}
