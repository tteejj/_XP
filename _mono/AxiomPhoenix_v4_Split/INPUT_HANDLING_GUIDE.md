# Axiom-Phoenix v4.0 - CRITICAL: Input Handling Documentation
# THIS DOCUMENT EXPLAINS THE CORRECT WAY TO HANDLE INPUT IN SCREENS

## NCURSES WINDOW MODEL - NO FOCUS MANAGER

This TUI framework uses the ncurses window model where:
- Each Screen manages its own internal focus/active component
- There is NO external FocusManager service
- Input flows from Engine → Screen → (optionally) to components
- Screens decide what to do with each keystroke

## CORRECT SCREEN IMPLEMENTATION PATTERN

```powershell
class YourScreen : Screen {
    # Internal state for tracking active component
    hidden [string] $_activeComponent = "main"  # e.g., "main", "filter", "list"
    
    [void] Initialize() {
        # Create UI components
        # Set IsFocusable = $false on all components
        # The screen handles ALL input directly
        
        $this._listBox = [ListBox]::new("MyList")
        $this._listBox.IsFocusable = $false  # IMPORTANT!
        
        $this._textBox = [TextBoxComponent]::new("MyTextBox")
        $this._textBox.IsFocusable = $false  # IMPORTANT!
    }
    
    [void] OnEnter() {
        # DO NOT use FocusManager!
        # Just set initial state
        $this._activeComponent = "main"
        $this._UpdateVisualFocus()  # Update visual indicators
        $this.RequestRedraw()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Log for debugging
        Write-Log -Level Debug -Message "$($this.Name): Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)'"
        
        # Handle based on active component
        if ($this._activeComponent -eq "textbox") {
            # Handle text input manually
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Escape) {
                    $this._activeComponent = "main"
                    $this._UpdateVisualFocus()
                    return $true
                }
                ([ConsoleKey]::Backspace) {
                    # Handle backspace
                    if ($this._textBox.Text.Length -gt 0) {
                        $this._textBox.Text = $this._textBox.Text.Substring(0, $this._textBox.Text.Length - 1)
                        $this.RequestRedraw()
                    }
                    return $true
                }
                default {
                    # Add character
                    if ($keyInfo.KeyChar) {
                        $this._textBox.Text += $keyInfo.KeyChar
                        $this.RequestRedraw()
                        return $true
                    }
                }
            }
        }
        
        # Main mode - handle shortcuts
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Tab) {
                # Cycle through components
                $this._CycleActiveComponent()
                return $true
            }
            ([ConsoleKey]::Escape) {
                # Go back
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService?.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
        }
        
        # Handle character shortcuts
        switch ($keyInfo.KeyChar) {
            'q' { 
                # Quit
                $actionService = $this.ServiceContainer?.GetService("ActionService")
                $actionService?.ExecuteAction("app.exit", @{})
                return $true
            }
        }
        
        return $false
    }
    
    hidden [void] _UpdateVisualFocus() {
        # Update visual indicators (borders, colors, cursor)
        switch ($this._activeComponent) {
            "textbox" {
                $this._textBox.ShowCursor = $true
                $this._textBox.BorderColor = Get-ThemeColor "focus" "#00D4FF"
            }
            default {
                $this._textBox.ShowCursor = $false
                $this._textBox.BorderColor = Get-ThemeColor "border" "#333333"
            }
        }
        $this.RequestRedraw()
    }
}
```

## KEY PRINCIPLES

1. **NO FOCUS MANAGER** - Each screen tracks its own active component
2. **IsFocusable = $false** - Set on ALL components, screen handles input
3. **Direct Input Handling** - Screen's HandleInput processes everything
4. **Visual Focus Indicators** - Update borders/colors to show active component
5. **Manual Text Input** - Handle Backspace, character input yourself
6. **Tab Navigation** - Implement your own Tab cycling logic
7. **Always Return Bool** - Return $true if handled, $false if not

## COMMON PATTERNS

### List Navigation
```powershell
([ConsoleKey]::UpArrow) {
    if ($this._selectedIndex -gt 0) {
        $this._selectedIndex--
        $this._listBox.SelectedIndex = $this._selectedIndex
        $this.RequestRedraw()
    }
    return $true
}
```

### Text Input Mode
```powershell
if ($this._activeComponent -eq "search") {
    if ($keyInfo.Key -eq [ConsoleKey]::Backspace) {
        # Handle backspace
    } elseif ($keyInfo.KeyChar) {
        # Add character
        $this._searchText += $keyInfo.KeyChar
    }
    return $true
}
```

### Mode Switching
```powershell
'/' {  # Enter search mode
    $this._activeComponent = "search"
    $this._UpdateVisualFocus()
    return $true
}
```

## WHAT NOT TO DO

1. **DON'T** use FocusManager service
2. **DON'T** set IsFocusable = $true on components
3. **DON'T** rely on component HandleInput being called automatically
4. **DON'T** forget to return bool from HandleInput
5. **DON'T** forget to handle $null keyInfo

## DEBUGGING TIPS

1. Add logging at the start of HandleInput:
   ```powershell
   Write-Log -Level Debug -Message "$($this.Name): Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)', Active=$($this._activeComponent)"
   ```

2. Test with direct key presses:
   - Number keys: both keyInfo.KeyChar and ConsoleKey.D1-D9
   - Letters: check both upper and lowercase
   - Special keys: Tab, Enter, Escape, arrows

3. Verify input flow:
   - Engine calls Screen.HandleInput
   - Screen decides what to do
   - Screen returns true if handled

## MIGRATION CHECKLIST

When fixing a screen:
- [ ] Remove all FocusManager usage
- [ ] Add $_activeComponent field
- [ ] Set IsFocusable = $false on all components
- [ ] Implement complete HandleInput method
- [ ] Add visual focus indicators
- [ ] Test all keyboard shortcuts
- [ ] Test Tab navigation
- [ ] Test Escape to go back
- [ ] Add debug logging

Remember: The screen is in COMPLETE CONTROL of input handling!
