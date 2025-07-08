# Critical Stability Fixes - Part 1
# Complete code blocks for direct replacement in AllComponents.ps1

# ===============================================================================
# FIX 1.1: CommandPalette HandleInput Method - ExecuteAction Overload Fix
# ===============================================================================
# Location: AllComponents.ps1 -> CommandPalette Class -> HandleInput Method
# Replace the entire HandleInput method with this fixed version:

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Hide()
            return $true
        }
        
        if ($key.Key -eq [ConsoleKey]::Enter -and $this._listBox.SelectedIndex -ge 0) {
            $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
            if ($selectedAction) {
                $this.Hide()
                if ($this.OnSelect) {
                    & $this.OnSelect $selectedAction
                }
                else {
                    # Execute action directly - FIX: Pass empty hashtable as second parameter
                    $this._actionService.ExecuteAction($selectedAction.Name, @{})
                }
            }
            return $true
        }
        
        # Pass input to search box or list box
        if ($key.Key -in @([ConsoleKey]::UpArrow, [ConsoleKey]::DownArrow, 
                          [ConsoleKey]::PageUp, [ConsoleKey]::PageDown)) {
            return $this._listBox.HandleInput($key)
        }
        else {
            return $this._searchBox.HandleInput($key)
        }
    }

# ===============================================================================
# FIX 1.2: ConsoleColor to Hex String Conversions
# ===============================================================================

# -----------------------------------------------------------------------
# MultilineTextBoxComponent - Property Declarations (Lines ~295-300)
# -----------------------------------------------------------------------
# Replace these property declarations in the MultilineTextBoxComponent class:

    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$BorderColor = "#808080"

# -----------------------------------------------------------------------
# Panel - Property Declarations (Lines ~1095-1100)
# -----------------------------------------------------------------------
# Replace these property declarations in the Panel class:

    [string]$BorderColor = "#808080"
    [string]$BackgroundColor = "#000000"

# -----------------------------------------------------------------------
# GroupPanel - Constructor (Lines ~1265-1270)
# -----------------------------------------------------------------------
# Replace the GroupPanel constructor with this fixed version:

    GroupPanel([string]$name) : base($name) {
        $this.BorderStyle = "Double"
        $this.BorderColor = "#008B8B"  # DarkCyan in hex
        $this.BackgroundColor = "#000000"  # Black in hex
    }

# -----------------------------------------------------------------------
# NavigationMenu - Property Declarations
# -----------------------------------------------------------------------
# If NavigationMenu class exists, replace these property declarations:

    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$SelectedBackgroundColor = "#00008B"
    [string]$SelectedForegroundColor = "#FFFF00"

# -----------------------------------------------------------------------
# ListBox - Already Fixed in Current Code
# -----------------------------------------------------------------------
# The ListBox class in the current code already has hex string properties:
# [string]$ForegroundColor = "#FFFFFF"
# [string]$BackgroundColor = "#000000"
# [string]$SelectedForegroundColor = "#000000"
# [string]$SelectedBackgroundColor = "#00FFFF"
# [string]$BorderColor = "#808080"
# No changes needed for ListBox.

# -----------------------------------------------------------------------
# DateInputComponent OnRender Fix (Lines ~875-885)
# -----------------------------------------------------------------------
# In DateInputComponent.OnRender(), replace the color declarations:

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # FIX: Use hex strings instead of ConsoleColor
            $bgColor = Get-ThemeColor -ColorName "input.background" -DefaultColor $this.BackgroundColor
            $fgColor = Get-ThemeColor -ColorName "input.foreground" -DefaultColor $this.ForegroundColor
            $borderColor = if ($this.IsFocused) { Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF" } else { Get-ThemeColor -ColorName "component.border" -DefaultColor $this.BorderColor }
            
            # Rest of the method remains the same...
