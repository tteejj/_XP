# Axiom-Phoenix v4.0 - Hybrid Model Migration Summary

## Quick Reference: Converting Screens to Hybrid Model

### What Changes

**FROM (Direct Input Model):**
```powershell
# Manual focus tracking
hidden [string] $_activeComponent = "list"
hidden [int] $_focusIndex = 0

# Components not focusable
$this._textBox.IsFocusable = $false

# Manual Tab handling
if ($keyInfo.Key -eq [ConsoleKey]::Tab) {
    $this._activeComponent = "next"
    $this._UpdateVisualFocus()
    return $true
}

# Manual text input
if ($this._activeComponent -eq "textbox") {
    if ($keyInfo.Key -eq [ConsoleKey]::Backspace) {
        # Handle backspace manually
    }
}
```

**TO (Hybrid Window Model):**
```powershell
# No manual tracking needed!

# Components ARE focusable
$this._textBox.IsFocusable = $true
$this._textBox.TabIndex = 0  # Optional: control order

# Override focus events for visuals
$this._textBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
    $this.BorderColor = Get-ThemeColor "primary.accent"
    $this.ShowCursor = $true
    $this.RequestRedraw()
} -Force

# Call base HandleInput first
[bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
    # Base class handles Tab automatically!
    if (([Screen]$this).HandleInput($keyInfo)) {
        return $true
    }
    
    # Only handle screen-level shortcuts
    switch ($keyInfo.Key) {
        ([ConsoleKey]::Escape) { 
            # Go back
        }
    }
}
```

### Step-by-Step Migration

1. **Remove Manual Tracking**
   - Delete `$_activeComponent`, `$_focusIndex`, `$_fieldOrder` variables
   - Delete `_UpdateVisualFocus()` method

2. **Update Components**
   ```powershell
   # Set focusable
   $this._titleBox.IsFocusable = $true
   $this._titleBox.TabIndex = 0  # First
   
   $this._saveButton.IsFocusable = $true  
   $this._saveButton.TabIndex = 1  # Second
   ```

3. **Add Visual Feedback**
   ```powershell
   $component | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
       $this.BorderColor = Get-ThemeColor "primary.accent"
       $this.RequestRedraw()
   } -Force
   
   $component | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
       $this.BorderColor = Get-ThemeColor "border"
       $this.RequestRedraw()
   } -Force
   ```

4. **Simplify HandleInput**
   ```powershell
   [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
       if ($null -eq $keyInfo) { return $false }
       
       # ALWAYS call base first - handles Tab and routing
       if (([Screen]$this).HandleInput($keyInfo)) {
           return $true
       }
       
       # Only screen shortcuts here
       switch ($keyInfo.Key) {
           ([ConsoleKey]::Escape) {
               # Navigate back
               return $true
           }
           ([ConsoleKey]::F5) {
               # Refresh
               return $true
           }
       }
       
       return $false
   }
   ```

5. **Update OnEnter**
   ```powershell
   [void] OnEnter() {
       # Your initialization...
       
       # Call base to set initial focus
       ([Screen]$this).OnEnter()
   }
   ```

### Common Gotchas

❌ **DON'T** handle Tab in your screen - base class does it
❌ **DON'T** manually route input to components
❌ **DON'T** set ShowCursor manually except in OnFocus/OnBlur
❌ **DON'T** track active component manually

✅ **DO** set IsFocusable = true on interactive components
✅ **DO** call base HandleInput first
✅ **DO** use TabIndex to control order
✅ **DO** override OnFocus/OnBlur for visual feedback

### Testing Checklist

- [ ] Tab moves forward through all fields
- [ ] Shift+Tab moves backward  
- [ ] Text boxes accept typing
- [ ] Backspace works in text boxes
- [ ] Enter/Space activate buttons when focused
- [ ] Visual focus indicators update
- [ ] Escape still goes back
- [ ] Screen shortcuts work from any field

### Benefits You Get

1. **No Manual Tracking** - Framework handles focus
2. **Automatic Tab Nav** - Just works
3. **Reusable Components** - TextBox works the same everywhere
4. **Less Code** - Remove all the manual input routing
5. **Consistent UX** - All screens work the same way

### Example: Minimal Form Screen

```powershell
class MyFormScreen : Screen {
    hidden [TextBoxComponent] $_nameBox
    hidden [ButtonComponent] $_saveButton
    
    [void] Initialize() {
        # Create form
        $this._nameBox = [TextBoxComponent]::new("Name")
        $this._nameBox.IsFocusable = $true
        $this._nameBox.TabIndex = 0
        # Add visual feedback
        $this._nameBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = "#00D4FF"
            $this.RequestRedraw()
        } -Force
        
        $this._saveButton = [ButtonComponent]::new("Save")
        $this._saveButton.IsFocusable = $true
        $this._saveButton.TabIndex = 1
        $this._saveButton.OnClick = { $this.Save() }
        
        # Add to screen...
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Base handles Tab and component input
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # Just handle Escape
        if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            # Go back
            return $true
        }
        
        return $false
    }
}
```

That's it! Much simpler than manual input handling.
