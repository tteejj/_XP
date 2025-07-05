# ==============================================================================
# Navigation Class Module v5.0
# Contextual navigation menu components with theme integration
# ==============================================================================
# NOTE: This module is intended for LOCAL/CONTEXTUAL menus only.
# Global application commands should be registered with the ActionService and
# accessed via the CommandPalette (Ctrl+P).
# ==============================================================================

#using module ui-classes
#using module tui-primitives
#using module theme-manager
#using namespace System.Management.Automation
#using namespace System.Collections.Generic

#region Navigation Classes

class NavigationItem {
    [string]$Key
    [string]$Label
    [scriptblock]$Action
    [bool]$Enabled = $true
    [bool]$Visible = $true
    [string]$Description = ""

    NavigationItem([string]$key, [string]$label, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw [System.ArgumentException]::new("Navigation key cannot be null or empty")
        }
        if ([string]::IsNullOrWhiteSpace($label)) {
            throw [System.ArgumentException]::new("Navigation label cannot be null or empty")
        }
        if (-not $action) {
            throw [System.ArgumentNullException]::new("action", "Navigation action cannot be null")
        }

        $this.Key = $key.ToUpper()
        $this.Label = $label
        $this.Action = $action
        
        Write-Verbose "NavigationItem: Created item '$($this.Key)' - '$($this.Label)'"
    }

    [void] Execute() {
        try {
            if (-not $this.Enabled) {
                Write-Log -Level Warning -Message "Attempted to execute disabled navigation item: $($this.Key)"
                return
            }
            
            Write-Log -Level Debug -Message "Executing navigation item: $($this.Key)"
            Invoke-WithErrorHandling -Component "NavigationItem" -Context "Execute '$($this.Key)'" -ScriptBlock $this.Action
        }
        catch {
            Write-Error "NavigationItem '$($this.Key)': Error during execution: $($_.Exception.Message)"
        }
    }

    [string] ToString() {
        return "NavigationItem(Key='$($this.Key)', Label='$($this.Label)', Enabled=$($this.Enabled))"
    }
}

class NavigationMenu : UIElement {
    [System.Collections.Generic.List[NavigationItem]]$Items
    [ValidateSet("Vertical", "Horizontal")][string]$Orientation = "Vertical"
    [string]$Separator = " | "
    [int]$SelectedIndex = 0

    NavigationMenu([string]$name) : base($name) {
        $this.Items = [System.Collections.Generic.List[NavigationItem]]::new()
        $this.IsFocusable = $true
        $this.Width = 20
        $this.Height = 10
        Write-Verbose "NavigationMenu: Constructor called for '$($this.Name)'"
    }

    [void] AddItem([NavigationItem]$item) {
        try {
            if (-not $item) {
                throw [System.ArgumentNullException]::new("item")
            }
            
            # Check for duplicate keys
            $existingItem = $this.Items | Where-Object { $_.Key -eq $item.Key }
            if ($existingItem) {
                throw [System.InvalidOperationException]::new("Item with key '$($item.Key)' already exists")
            }
            
            $this.Items.Add($item)
            $this.RequestRedraw()
            Write-Verbose "NavigationMenu '$($this.Name)': Added item '$($item.Key)'"
        }
        catch {
            Write-Error "NavigationMenu '$($this.Name)': Error adding item: $($_.Exception.Message)"
            throw
        }
    }

    [void] AddSeparator() {
        try {
            $separatorItem = [NavigationItem]::new("-", "---", {})
            $separatorItem.Enabled = $false
            $this.Items.Add($separatorItem)
            $this.RequestRedraw()
            Write-Verbose "NavigationMenu '$($this.Name)': Added separator"
        }
        catch {
            Write-Error "NavigationMenu '$($this.Name)': Error adding separator: $($_.Exception.Message)"
        }
    }

    [void] RemoveItem([string]$key) {
        try {
            if ([string]::IsNullOrWhiteSpace($key)) { return }
            $item = $this.Items | Where-Object { $_.Key -eq $key.ToUpper() }
            if ($item) {
                $this.Items.Remove($item)
                
                # Adjust selected index if needed
                if ($this.SelectedIndex -ge $this.Items.Count) {
                    $this.SelectedIndex = [Math]::Max(0, $this.Items.Count - 1)
                }
                
                $this.RequestRedraw()
                Write-Verbose "NavigationMenu '$($this.Name)': Removed item '$key'"
            }
        }
        catch {
            Write-Error "NavigationMenu '$($this.Name)': Error removing item '$key': $($_.Exception.Message)"
        }
    }

    [NavigationItem] GetItem([string]$key) {
        if ([string]::IsNullOrWhiteSpace($key)) { return $null }
        return $this.Items | Where-Object { $_.Key -eq $key.ToUpper() } | Select-Object -First 1
    }

    [void] ExecuteSelectedItem() {
        try {
            $visibleItems = @($this.Items | Where-Object { $_.Visible })
            if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $visibleItems.Count) {
                $selectedItem = $visibleItems[$this.SelectedIndex]
                if ($selectedItem.Enabled -and $selectedItem.Key -ne "-") {
                    $selectedItem.Execute()
                }
            }
        }
        catch {
            Write-Error "NavigationMenu '$($this.Name)': Error executing selected item: $($_.Exception.Message)"
        }
    }

    [void] ExecuteByKey([string]$key) {
        try {
            if ([string]::IsNullOrWhiteSpace($key)) { return }
            $item = $this.GetItem($key)
            if ($item -and $item.Enabled -and $item.Visible) {
                $item.Execute()
            }
        }
        catch {
            Write-Error "NavigationMenu '$($this.Name)': Error executing item by key '$key': $($_.Exception.Message)"
        }
    }

    [void] OnRender() {
        if (-not $this.Visible -or -not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = Get-ThemeColor 'Background'
            $fgColor = Get-ThemeColor 'Foreground'
            
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            
            $visibleItems = @($this.Items | Where-Object { $_.Visible })
            if ($visibleItems.Count -eq 0) {
                Write-Verbose "NavigationMenu '$($this.Name)': No visible items to render"
                return
            }

            # Ensure selected index is valid
            if ($this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $visibleItems.Count) {
                $this.SelectedIndex = 0
            }

            if ($this.Orientation -eq "Horizontal") {
                $this._RenderHorizontal($visibleItems)
            } else {
                $this._RenderVertical($visibleItems)
            }
            
            Write-Verbose "NavigationMenu '$($this.Name)': Rendered $($visibleItems.Count) items"
        }
        catch {
            Write-Error "NavigationMenu '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    hidden [void] _RenderHorizontal([NavigationItem[]]$items) {
        try {
            $currentX = 0
            $maxY = 0
            
            for ($i = 0; $i -lt $items.Count; $i++) {
                if ($currentX -ge $this.Width) { break }
                
                $item = $items[$i]
                $isSelected = ($i -eq $this.SelectedIndex)
                $isFocused = ($isSelected -and $this.IsFocused)
                
                # Get colors based on state
                $itemFg = if (-not $item.Enabled) {
                    Get-ThemeColor 'menu.item.disabled' -Fallback (Get-ThemeColor 'Subtle')
                } elseif ($isFocused) {
                    Get-ThemeColor 'menu.item.foreground.focus' -Fallback (Get-ThemeColor 'Background')
                } else {
                    Get-ThemeColor 'menu.item.foreground.normal' -Fallback (Get-ThemeColor 'Foreground')
                }
                
                $itemBg = if ($isFocused) {
                    Get-ThemeColor 'menu.item.background.focus' -Fallback (Get-ThemeColor 'Accent')
                } else {
                    Get-ThemeColor 'Background'
                }
                
                # Format item text
                $text = if ($item.Key -eq "-") {
                    "---"
                } else {
                    "[$($item.Key)] $($item.Label)"
                }
                
                # Draw item
                $textLength = [Math]::Min($text.Length, $this.Width - $currentX)
                $displayText = $text.Substring(0, $textLength)
                
                Write-TuiText -Buffer $this._private_buffer -X $currentX -Y 0 -Text $displayText -ForegroundColor $itemFg -BackgroundColor $itemBg
                $currentX += $textLength
                
                # Add separator if not last item and space available
                if ($i -lt ($items.Count - 1) -and ($currentX + $this.Separator.Length) -lt $this.Width) {
                    $separatorColor = Get-ThemeColor 'menu.item.separator' -Fallback (Get-ThemeColor 'Subtle')
                    Write-TuiText -Buffer $this._private_buffer -X $currentX -Y 0 -Text $this.Separator -ForegroundColor $separatorColor -BackgroundColor (Get-ThemeColor 'Background')
                    $currentX += $this.Separator.Length
                }
            }
        }
        catch {
            Write-Error "NavigationMenu '$($this.Name)': Error rendering horizontal layout: $($_.Exception.Message)"
        }
    }

    hidden [void] _RenderVertical([NavigationItem[]]$items) {
        try {
            $maxItems = [Math]::Min($items.Count, $this.Height)
            
            for ($i = 0; $i -lt $maxItems; $i++) {
                $item = $items[$i]
                $isSelected = ($i -eq $this.SelectedIndex)
                $isFocused = ($isSelected -and $this.IsFocused)
                
                # Handle separators
                if ($item.Key -eq "-") {
                    $separatorColor = Get-ThemeColor 'menu.item.separator' -Fallback (Get-ThemeColor 'Subtle')
                    $line = '─' * $this.Width
                    Write-TuiText -Buffer $this._private_buffer -X 0 -Y $i -Text $line -ForegroundColor $separatorColor -BackgroundColor (Get-ThemeColor 'Background')
                    continue
                }
                
                # Get colors based on state
                $itemBg = if ($isFocused) {
                    Get-ThemeColor 'menu.item.background.focus' -Fallback (Get-ThemeColor 'Accent')
                } else {
                    Get-ThemeColor 'Background'
                }
                
                $prefixFg = if ($isFocused) {
                    Get-ThemeColor 'menu.item.prefix.focus' -Fallback (Get-ThemeColor 'Background')
                } else {
                    Get-ThemeColor 'menu.item.prefix.normal' -Fallback (Get-ThemeColor 'Accent')
                }
                
                $keyFg = if (-not $item.Enabled) {
                    Get-ThemeColor 'menu.item.disabled' -Fallback (Get-ThemeColor 'Subtle')
                } elseif ($isFocused) {
                    Get-ThemeColor 'menu.item.hotkey.focus' -Fallback (Get-ThemeColor 'Background')
                } else {
                    Get-ThemeColor 'menu.item.hotkey.normal' -Fallback (Get-ThemeColor 'Accent')
                }
                
                $labelFg = if (-not $item.Enabled) {
                    Get-ThemeColor 'menu.item.disabled' -Fallback (Get-ThemeColor 'Subtle')
                } elseif ($isFocused) {
                    Get-ThemeColor 'menu.item.foreground.focus' -Fallback (Get-ThemeColor 'Background')
                } else {
                    Get-ThemeColor 'menu.item.foreground.normal' -Fallback (Get-ThemeColor 'Foreground')
                }
                
                # Draw selection highlight background
                $highlightText = ' ' * $this.Width
                Write-TuiText -Buffer $this._private_buffer -X 0 -Y $i -Text $highlightText -ForegroundColor $labelFg -BackgroundColor $itemBg
                
                # Draw selection prefix
                $prefix = if ($isSelected) { "> " } else { "  " }
                Write-TuiText -Buffer $this._private_buffer -X 0 -Y $i -Text $prefix -ForegroundColor $prefixFg -BackgroundColor $itemBg
                
                # Draw hotkey
                $keyText = "[$($item.Key)]"
                Write-TuiText -Buffer $this._private_buffer -X 2 -Y $i -Text $keyText -ForegroundColor $keyFg -BackgroundColor $itemBg
                
                # Draw label
                $labelX = 2 + $keyText.Length + 1
                $maxLabelWidth = $this.Width - $labelX
                $labelText = $item.Label
                if ($labelText.Length -gt $maxLabelWidth) {
                    $labelText = $labelText.Substring(0, $maxLabelWidth - 3) + "..."
                }
                Write-TuiText -Buffer $this._private_buffer -X $labelX -Y $i -Text $labelText -ForegroundColor $labelFg -BackgroundColor $itemBg
            }
        }
        catch {
            Write-Error "NavigationMenu '$($this.Name)': Error rendering vertical layout: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        try {
            $visibleItems = @($this.Items | Where-Object { $_.Visible })
            if ($visibleItems.Count -eq 0) {
                return $false
            }
            
            # Handle direct hotkey access
            $keyChar = $keyInfo.KeyChar.ToString().ToUpper()
            $hotkeyItem = $visibleItems | Where-Object { $_.Key -eq $keyChar -and $_.Enabled }
            if ($hotkeyItem) {
                $hotkeyItem.Execute()
                return $true
            }
            
            # Handle navigation keys
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Enter) {
                    $this.ExecuteSelectedItem()
                    return $true
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this.Orientation -eq "Vertical") {
                        $this._MovePrevious($visibleItems)
                        return $true
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.Orientation -eq "Vertical") {
                        $this._MoveNext($visibleItems)
                        return $true
                    }
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.Orientation -eq "Horizontal") {
                        $this._MovePrevious($visibleItems)
                        return $true
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.Orientation -eq "Horizontal") {
                        $this._MoveNext($visibleItems)
                        return $true
                    }
                }
                ([ConsoleKey]::Home) {
                    $this.SelectedIndex = 0
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::End) {
                    $this.SelectedIndex = $visibleItems.Count - 1
                    $this.RequestRedraw()
                    return $true
                }
            }
            
            return $false
        }
        catch {
            Write-Error "NavigationMenu '$($this.Name)': Error handling input: $($_.Exception.Message)"
            return $false
        }
    }

    hidden [void] _MovePrevious([NavigationItem[]]$items) {
        do {
            $this.SelectedIndex = if ($this.SelectedIndex -le 0) { $items.Count - 1 } else { $this.SelectedIndex - 1 }
        } while ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $items.Count -and (-not $items[$this.SelectedIndex].Enabled -or $items[$this.SelectedIndex].Key -eq "-"))
        
        $this.RequestRedraw()
    }

    hidden [void] _MoveNext([NavigationItem[]]$items) {
        do {
            $this.SelectedIndex = if ($this.SelectedIndex -ge ($items.Count - 1)) { 0 } else { $this.SelectedIndex + 1 }
        } while ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $items.Count -and (-not $items[$this.SelectedIndex].Enabled -or $items[$this.SelectedIndex].Key -eq "-"))
        
        $this.RequestRedraw()
    }

    [void] OnFocus() {
        ([UIElement]$this).OnFocus()
        $this.RequestRedraw()
        Write-Verbose "NavigationMenu '$($this.Name)': Gained focus"
    }

    [void] OnBlur() {
        ([UIElement]$this).OnBlur()
        $this.RequestRedraw()
        Write-Verbose "NavigationMenu '$($this.Name)': Lost focus"
    }

    [string] ToString() {
        return "NavigationMenu(Name='$($this.Name)', Items=$($this.Items.Count), Selected=$($this.SelectedIndex), Orientation='$($this.Orientation)')"
    }
}

#endregion

#region Module Exports

# Classes are automatically exported in PowerShell 7+
# NavigationItem, NavigationMenu classes are available when module is imported

#endregion
