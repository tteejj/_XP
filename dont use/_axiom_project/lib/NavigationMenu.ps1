class NavigationMenu : UIElement {
    [System.Collections.Generic.List[NavigationItem]] $Items
    [hashtable] $Services
    [string] $Orientation = "Vertical"
    [string] $Separator = "  |  "
    [bool] $ShowDescriptions = $false
    [ConsoleColor] $SeparatorColor = [ConsoleColor]::DarkGray
    [int] $SelectedIndex = 0
    [bool] $IsFocused = $false
    
    NavigationMenu([string]$name) : base() {
        $this.Name = $name
        $this.Items = [System.Collections.Generic.List[NavigationItem]]::new()
        $this.IsFocusable = $true
        $this.SelectedIndex = 0
        $this.Width = 30
        $this.Height = 10
    }
    
    NavigationMenu([string]$name, [hashtable]$services) : base() {
        if ($null -eq $services) { throw [ArgumentNullException]::new("services") }
        $this.Name = $name
        $this.Services = $services
        $this.Items = [System.Collections.Generic.List[NavigationItem]]::new()
        $this.IsFocusable = $true
        $this.SelectedIndex = 0
        $this.Width = 30
        $this.Height = 10
    }
    
    [void] AddItem([NavigationItem]$item) {
        if (-not $item) { throw [ArgumentNullException]::new("item") }
        if ($this.Items.Exists({param($x) $x.Key -eq $item.Key})) { 
            throw [InvalidOperationException]::new("Item with key '$($item.Key)' already exists") 
        }
        $this.Items.Add($item)
        $this.RequestRedraw()
    }
    
    [void] RemoveItem([string]$key) {
        $item = $this.GetItem($key)
        if ($item) { 
            [void]$this.Items.Remove($item)
            $this.RequestRedraw()
        }
    }
    
    [NavigationItem] GetItem([string]$key) {
        return $this.Items.Find({param($x) $x.Key -eq $key.ToUpper()})
    }

    [void] ExecuteAction([string]$key) {
        $item = $this.GetItem($key)
        if ($item -and $item.Visible) {
            Invoke-WithErrorHandling -Component "NavigationMenu" -Context "ExecuteAction:$key" -ScriptBlock { 
                $item.Execute() 
            }
        }
    }

    [void] AddSeparator() {
        $separatorItem = [NavigationItem]::new("-", "---", {})
        $separatorItem.Enabled = $false
        $this.Items.Add($separatorItem)
        $this.RequestRedraw()
    }
    
    # AI: REFACTORED - Now uses Panel buffer integration
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # Clear our buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            # Get visible items
            $visibleItems = @($this.Items | Where-Object { $null -ne $_ -and $_.Visible })
            if ($visibleItems.Count -eq 0) { return }
            
            if ($this.Orientation -eq "Horizontal") { 
                $this.RenderHorizontal($visibleItems) 
            }
            else { 
                $this.RenderVertical($visibleItems) 
            }
            
        } catch { 
            Write-Log -Level Error -Message "NavigationMenu render error for '$($this.Name)': $_" 
        }
    }
    
    hidden [void] RenderHorizontal([object[]]$items) {
        if ($null -eq $items -or $items.Count -eq 0) { return }
        
        $menuText = ""
        $isFirst = $true
        foreach ($item in $items) {
            if ($null -eq $item) { continue }
            
            if (-not $isFirst) {
                $menuText += $this.Separator
            }
            $menuText += "[$($item.Key)] $($item.Label)"
            $isFirst = $false
        }
        
        # Write to our private buffer
        $this._private_buffer.WriteString(0, 0, $menuText, [ConsoleColor]::White, [ConsoleColor]::Black)
    }
    
    hidden [void] RenderVertical([object[]]$items) {
        if ($null -eq $items -or $items.Count -eq 0) { return }
        
        # Ensure SelectedIndex is within bounds
        if ($this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $items.Count) {
            $this.SelectedIndex = 0
        }
        
                for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            if ($null -eq $item) { continue }

            $isItemSelected = ($i -eq $this.SelectedIndex -and $this.IsFocused)
            
            $prefix = if ($isItemSelected -and $item.Key -ne "-") { "> " } else { "  " }
            $menuText = "$prefix[$($item.Key)] $($item.Label)"

            $fg = if ($isItemSelected -and $item.Key -ne "-") { [ConsoleColor]::Black } else { [ConsoleColor]::White }
            $bg = if ($isItemSelected -and $item.Key -ne "-") { [ConsoleColor]::White } else { [ConsoleColor]::Black }

            # Explicitly paint the entire line with the correct background color first
            $this._private_buffer.WriteString(0, $i, (' ' * $this.Width), $fg, $bg)
            # Then, write the actual text on top
            $this._private_buffer.WriteString(0, $i, $menuText, $fg, $bg)
        }
    }
    
    # AI: REFACTORED - Updated input handling for new architecture
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        try {
            $visibleItems = @($this.Items | Where-Object { $null -ne $_ -and $_.Visible })
            if ($visibleItems.Count -eq 0) { return $false }
            
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.SelectedIndex -lt ($visibleItems.Count - 1)) {
                        $this.SelectedIndex++
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $visibleItems.Count) {
                        $selectedItem = $visibleItems[$this.SelectedIndex]
                        if ($selectedItem.Enabled -and $selectedItem.Key -ne "-") {
                            $selectedItem.Execute()
                        }
                    }
                    return $true
                }
                default {
                    # Check for direct key matches
                    $keyChar = $keyInfo.KeyChar.ToString().ToUpper()
                    $matchingItem = $this.Items.Find({param($x) $x.Key -eq $keyChar})
                    if ($matchingItem -and $matchingItem.Enabled -and $matchingItem.Visible) {
                        $matchingItem.Execute()
                        return $true
                    }
                }
            }
            
        } catch { 
            Write-Log -Level Error -Message "NavigationMenu input error for '$($this.Name)': $_" 
        }
        
        return $false
    }
    
    # AI: NEW - Focus management
    [void] OnFocus() {
        $this.IsFocused = $true
        $this.RequestRedraw()
    }
    
    [void] OnBlur() {
        $this.IsFocused = $false
        $this.RequestRedraw()
    }
}
