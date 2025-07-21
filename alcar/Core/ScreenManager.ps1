# Screen Manager - Handles navigation between screens

class ScreenManager {
    [System.Collections.Stack]$ScreenStack
    [Screen]$CurrentScreen
    [bool]$Running = $true
    [bool]$UseAlternateBuffer = $false
    [bool]$AsyncInputEnabled = $false
    
    ScreenManager() {
        $this.ScreenStack = [System.Collections.Stack]::new()
    }
    
    # PTUI Pattern: Alternate buffer switching for modal dialogs
    [void] EnterAlternateBuffer() {
        [Console]::Write("`e[?1049h")  # Enter alternate screen buffer
        $this.UseAlternateBuffer = $true
    }
    
    [void] ExitAlternateBuffer() {
        [Console]::Write("`e[?1049l")  # Exit alternate screen buffer
        $this.UseAlternateBuffer = $false
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
    
    # PTUI Pattern: Push modal dialog with alternate buffer
    [void] PushModal([Screen]$screen) {
        $this.EnterAlternateBuffer()
        $this.Push($screen)
    }
    
    # Pop current screen and return to previous
    [void] Pop() {
        # PTUI Pattern: Exit alternate buffer if we're using it
        if ($this.UseAlternateBuffer) {
            $this.ExitAlternateBuffer()
        }
        
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
        
        # Initialize async input if enabled
        if ($this.AsyncInputEnabled -and -not $global:AsyncInputManager) {
            $global:AsyncInputManager = [AsyncInputManager]::new()
            $global:AsyncInputManager.Enable()
        }
        
        try {
            # Initial render
            if ($this.CurrentScreen) {
                # Set async input manager on screen if supported
                if ($this.AsyncInputEnabled -and $this.CurrentScreen.SupportsAsyncInput) {
                    $this.CurrentScreen.AsyncInputManager = $global:AsyncInputManager
                }
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
                $hasInput = $false
                
                # Check async input first
                if ($this.AsyncInputEnabled -and $global:AsyncInputManager -and $global:AsyncInputManager.HasInput()) {
                    $input = $global:AsyncInputManager.GetNextInput()
                    if ($input -and $input.Type -eq "Key") {
                        $this.CurrentScreen.HandleInput($input.KeyInfo)
                        $hasInput = $true
                    }
                }
                
                # Check normal input if no async input
                if (-not $hasInput -and [Console]::KeyAvailable) {
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
                
                # No sleep needed - fast rendering with proper VT100
            }
        } finally {
            # Cleanup async input if enabled
            if ($this.AsyncInputEnabled -and $global:AsyncInputManager) {
                $global:AsyncInputManager.Disable()
            }
            
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