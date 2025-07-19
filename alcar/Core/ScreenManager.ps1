# Screen Manager - Handles navigation between screens

class ScreenManager {
    [System.Collections.Stack]$ScreenStack
    [Screen]$CurrentScreen
    [bool]$Running = $true
    
    ScreenManager() {
        $this.ScreenStack = [System.Collections.Stack]::new()
    }
    
    # Push a new screen onto the stack
    [void] Push([Screen]$screen) {
        if ($this.CurrentScreen) {
            $this.CurrentScreen.OnDeactivate()
            $this.ScreenStack.Push($this.CurrentScreen)
        }
        
        $this.CurrentScreen = $screen
        $this.CurrentScreen.OnActivate()
        $this.CurrentScreen.NeedsRender = $true
        
        # Don't render here - let the main loop handle it
    }
    
    # Pop current screen and return to previous
    [void] Pop() {
        if ($this.ScreenStack.Count -gt 0) {
            if ($this.CurrentScreen) {
                $this.CurrentScreen.OnDeactivate()
            }
            
            $this.CurrentScreen = $this.ScreenStack.Pop()
            $this.CurrentScreen.OnActivate()
            $this.CurrentScreen.NeedsRender = $true
        } else {
            # No more screens - exit
            $this.Running = $false
        }
    }
    
    # Replace current screen without pushing to stack
    [void] Replace([Screen]$screen) {
        if ($this.CurrentScreen) {
            $this.CurrentScreen.OnDeactivate()
        }
        
        $this.CurrentScreen = $screen
        $this.CurrentScreen.OnActivate()
        $this.CurrentScreen.NeedsRender = $true
    }
    
    # Clear all screens and set a new root
    [void] SetRoot([Screen]$screen) {
        $this.ScreenStack.Clear()
        
        if ($this.CurrentScreen) {
            $this.CurrentScreen.OnDeactivate()
        }
        
        $this.CurrentScreen = $screen
        $this.CurrentScreen.OnActivate()
        $this.CurrentScreen.NeedsRender = $true
        
        # Don't render here - let Run() handle initial render
    }
    
    # Main run loop
    [void] Run() {
        # Setup console with alternate screen buffer
        try {
            [Console]::CursorVisible = $false
        } catch {
            # Ignore cursor visibility errors
        }
        
        # Enter alternate screen buffer, hide cursor
        [Console]::Write("`e[?1049h`e[?25l")
        
        try {
            # Initial render
            if ($this.CurrentScreen) {
                $this.CurrentScreen.Render()
            }
            
            while ($this.Running -and $this.CurrentScreen) {
                # Check if screen is still active
                if (-not $this.CurrentScreen.Active) {
                    $this.Pop()
                    if ($this.CurrentScreen) {
                        $this.CurrentScreen.NeedsRender = $true
                    }
                    continue
                }
                
                # Handle input
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    # Global shortcuts
                    if ($key.Modifiers -eq [ConsoleModifiers]::Control -and $key.Key -eq [ConsoleKey]::Q) {
                        # Ctrl+Q - Quick exit
                        $this.Running = $false
                        continue
                    }
                    
                    # Let screen handle input
                    $this.CurrentScreen.HandleInput($key)
                }
                
                # Only render if needed
                if ($this.CurrentScreen.NeedsRender) {
                    $this.CurrentScreen.Render()
                }
                
                Start-Sleep -Milliseconds 50  # Increased to reduce flicker
            }
        } finally {
            # Cleanup - exit alternate buffer and restore cursor
            [Console]::Write("`e[?1049l`e[?25h")
            try {
                [Console]::CursorVisible = $true
            } catch {
                # Ignore cursor visibility errors
            }
        }
    }
    
    # Get screen depth
    [int] GetDepth() {
        return $this.ScreenStack.Count + 1
    }
    
    # Check if we can go back
    [bool] CanGoBack() {
        return $this.ScreenStack.Count -gt 0
    }
}

# Global screen manager instance
$global:ScreenManager = $null