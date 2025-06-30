# Fixed TUI Render Test
# This script tests if the TUI can render after scope fixes

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Set-Location "C:\Users\jhnhe\Documents\GitHub\_XP"

try {
    Write-Host "Loading required modules..." -ForegroundColor Cyan
    
    # Import modules with correct names and proper error handling
    Import-Module ".\modules\exceptions.psm1" -Global -Force
    Import-Module ".\modules\logger.psm1" -Global -Force  
    Import-Module ".\modules\theme-manager.psm1" -Global -Force
    Import-Module ".\modules\event-system.psm1" -Global -Force
    Import-Module ".\modules\tui-engine-v2.psm1" -Global -Force
    Import-Module ".\components\tui-components.psm1" -Global -Force

    Write-Host "Modules loaded successfully!" -ForegroundColor Green

    # Initialize required systems
    Initialize-Logger
    Initialize-EventSystem  
    Initialize-ThemeManager

    Write-Host "Creating test screen..." -ForegroundColor Cyan

    # Create a minimal test screen using correct component factory pattern
    $testScreen = @{
        Name = "TestScreen"
        Components = @{}
        
        Init = {
            param($self, $services)
            Write-Host "Test screen initializing..." -ForegroundColor Green
            
            # Add a simple label to verify rendering
            $label = New-TuiLabel -Props @{
                X = 5
                Y = 5
                Text = "TUI IS RENDERING!"
                ForegroundColor = [ConsoleColor]::Green
                Name = "TestLabel"
            }
            $self.Components["TestLabel"] = $label
            
            # Add a box to make it obvious
            $button = New-TuiButton -Props @{
                X = 5
                Y = 7
                Width = 25
                Height = 3
                Text = "Press ENTER or ESC"
                Name = "TestButton"
                OnClick = { Write-Host "Button clicked!" -ForegroundColor Yellow }
            }
            $self.Components["TestButton"] = $button
            
            # Add visual border
            Write-Host "Components created successfully" -ForegroundColor Green
        }
        
        Render = {
            param($self)
            try {
                # Draw border around the test area
                Write-BufferBox -X 2 -Y 2 -Width 30 -Height 10 -Title "Render Test" -BorderColor ([ConsoleColor]::Cyan)
                
                # Render all components
                foreach ($component in $self.Components.Values) {
                    if ($component.Render) {
                        & $component.Render -self $component
                    }
                }
            }
            catch {
                Write-Log -Level Error -Message "Screen render failed: $_"
            }
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape -or $Key.Key -eq [ConsoleKey]::Q) {
                return "Quit"
            }
            return $null
        }
    }

    Write-Host "Initializing TUI Engine..." -ForegroundColor Cyan
    Initialize-TuiEngine
    
    Write-Host "Verifying global state..." -ForegroundColor Cyan
    if ($global:TuiState -eq $null) {
        throw "Global TUI state was not initialized!"
    }
    
    Write-Host "Global TUI state confirmed: Width=$($global:TuiState.BufferWidth), Height=$($global:TuiState.BufferHeight)" -ForegroundColor Green

    Write-Host "Starting render test (Press ESC or Q to quit)..." -ForegroundColor Yellow
    
    # Push the test screen and start the loop
    Push-Screen -Screen $testScreen
    
    # Quick verification that buffer has content
    Clear-BackBuffer
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
        Write-Host "The TUI is now able to render. Starting interactive loop..." -ForegroundColor Green
        Write-Host "Use TAB to focus the button, ENTER to click it, ESC to quit." -ForegroundColor Yellow
        
        # Start the full interactive loop
        Start-TuiLoop
    } else {
        Write-Host "`nFAILED: No content in buffer - rendering is still broken!" -ForegroundColor Red
        Write-Host "Buffer state: Width=$($global:TuiState.BufferWidth), Height=$($global:TuiState.BufferHeight)" -ForegroundColor Yellow
        