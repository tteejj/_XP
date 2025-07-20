# Enhanced Input Manager - PTUI Pattern: Advanced key handling
# Provides sophisticated input parsing, key combinations, and timeout handling

class EnhancedInputManager {
    [hashtable]$KeyHandlers = @{}
    [hashtable]$KeySequences = @{}
    [string]$CurrentSequence = ""
    [datetime]$LastKeyTime = [datetime]::MinValue
    [int]$SequenceTimeout = 1000  # ms
    [bool]$CapsLockState = $false
    
    # PTUI Pattern: Register key combination handlers
    [void] RegisterKeyHandler([string]$keyCombo, [scriptblock]$handler) {
        $this.KeyHandlers[$keyCombo.ToLower()] = $handler
    }
    
    # Register multi-key sequences (like vim commands)
    [void] RegisterKeySequence([string]$sequence, [scriptblock]$handler) {
        $this.KeySequences[$sequence.ToLower()] = $handler
    }
    
    # Process key input with enhanced parsing
    [bool] ProcessKey([ConsoleKeyInfo]$key) {
        $this.LastKeyTime = [datetime]::Now
        
        # Build key combination string
        $keyString = $this.BuildKeyString($key)
        
        # Handle key sequences first
        if ($this.ProcessKeySequence($keyString)) {
            return $true
        }
        
        # Check for direct key handlers
        if ($this.KeyHandlers.ContainsKey($keyString)) {
            & $this.KeyHandlers[$keyString] $key
            return $true
        }
        
        return $false
    }
    
    # Build standardized key string representation
    [string] BuildKeyString([ConsoleKeyInfo]$key) {
        $parts = @()
        
        # Add modifiers
        if ($key.Modifiers.HasFlag([ConsoleModifiers]::Control)) {
            $parts += "ctrl"
        }
        if ($key.Modifiers.HasFlag([ConsoleModifiers]::Alt)) {
            $parts += "alt"
        }
        if ($key.Modifiers.HasFlag([ConsoleModifiers]::Shift)) {
            $parts += "shift"
        }
        
        # Add key name
        $keyName = $this.GetKeyName($key)
        $parts += $keyName
        
        return ($parts -join "+").ToLower()
    }
    
    # Get standardized key name
    [string] GetKeyName([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) { return "up" }
            ([ConsoleKey]::DownArrow) { return "down" }
            ([ConsoleKey]::LeftArrow) { return "left" }
            ([ConsoleKey]::RightArrow) { return "right" }
            ([ConsoleKey]::PageUp) { return "pageup" }
            ([ConsoleKey]::PageDown) { return "pagedown" }
            ([ConsoleKey]::Home) { return "home" }
            ([ConsoleKey]::End) { return "end" }
            ([ConsoleKey]::Insert) { return "insert" }
            ([ConsoleKey]::Delete) { return "delete" }
            ([ConsoleKey]::Backspace) { return "backspace" }
            ([ConsoleKey]::Tab) { return "tab" }
            ([ConsoleKey]::Enter) { return "enter" }
            ([ConsoleKey]::Escape) { return "escape" }
            ([ConsoleKey]::Spacebar) { return "space" }
            ([ConsoleKey]::F1) { return "f1" }
            ([ConsoleKey]::F2) { return "f2" }
            ([ConsoleKey]::F3) { return "f3" }
            ([ConsoleKey]::F4) { return "f4" }
            ([ConsoleKey]::F5) { return "f5" }
            ([ConsoleKey]::F6) { return "f6" }
            ([ConsoleKey]::F7) { return "f7" }
            ([ConsoleKey]::F8) { return "f8" }
            ([ConsoleKey]::F9) { return "f9" }
            ([ConsoleKey]::F10) { return "f10" }
            ([ConsoleKey]::F11) { return "f11" }
            ([ConsoleKey]::F12) { return "f12" }
            default { 
                if ($key.KeyChar -ne "`0") {
                    return $key.KeyChar.ToString().ToLower()
                }
                return $key.Key.ToString().ToLower()
            }
        }
        # This should never be reached, but PowerShell requires it
        return "unknown"
    }
    
    # Process key sequences with timeout
    [bool] ProcessKeySequence([string]$keyString) {
        # Check if sequence has timed out
        if ($this.CurrentSequence -and 
            ([datetime]::Now - $this.LastKeyTime).TotalMilliseconds -gt $this.SequenceTimeout) {
            $this.CurrentSequence = ""
        }
        
        # Add key to current sequence
        $testSequence = if ($this.CurrentSequence) { 
            $this.CurrentSequence + " " + $keyString 
        } else { 
            $keyString 
        }
        
        # Check for exact match
        if ($this.KeySequences.ContainsKey($testSequence)) {
            & $this.KeySequences[$testSequence]
            $this.CurrentSequence = ""
            return $true
        }
        
        # Check if this could be the start of a sequence
        $possibleSequences = $this.KeySequences.Keys | Where-Object { $_.StartsWith($testSequence) }
        if ($possibleSequences.Count -gt 0) {
            $this.CurrentSequence = $testSequence
            return $true
        }
        
        # No match - clear sequence and try as single key
        $this.CurrentSequence = ""
        return $false
    }
    
    # Clear current key sequence
    [void] ClearSequence() {
        $this.CurrentSequence = ""
    }
    
    # Get current sequence for display
    [string] GetCurrentSequence() {
        return $this.CurrentSequence
    }
}

# Enhanced Screen base class with better input handling
class EnhancedScreen : Screen {
    [EnhancedInputManager]$InputManager
    
    EnhancedScreen() : base() {
        $this.InputManager = [EnhancedInputManager]::new()
        $this.SetupDefaultKeyBindings()
    }
    
    [void] SetupDefaultKeyBindings() {
        # Common key combinations
        $this.InputManager.RegisterKeyHandler("ctrl+c", { $this.Active = $false })
        $this.InputManager.RegisterKeyHandler("ctrl+q", { $this.Active = $false })
        $this.InputManager.RegisterKeyHandler("escape", { $this.Active = $false })
        
        # Navigation
        $this.InputManager.RegisterKeyHandler("ctrl+home", { $this.GoToTop() })
        $this.InputManager.RegisterKeyHandler("ctrl+end", { $this.GoToBottom() })
        
        # Common sequences (vim-like)
        $this.InputManager.RegisterKeySequence("g g", { $this.GoToTop() })
        $this.InputManager.RegisterKeySequence("shift+g", { $this.GoToBottom() })
        $this.InputManager.RegisterKeySequence("z z", { $this.CenterView() })
    }
    
    # Override input handling to use enhanced manager
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($this.InputManager.ProcessKey($key)) {
            $this.RequestRender()
            return $true
        }
        
        # Fall back to base class
        return ([Screen]$this).HandleInput($key)
    }
    
    # Virtual methods for common actions
    [void] GoToTop() { }
    [void] GoToBottom() { }
    [void] CenterView() { }
    
    # Show current key sequence in status
    [void] UpdateSequenceStatus() {
        $sequence = $this.InputManager.GetCurrentSequence()
        if ($sequence) {
            $this.AddStatusItem($sequence, 'sequence')
        }
    }
}