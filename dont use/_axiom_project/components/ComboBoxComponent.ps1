class ComboBoxComponent : UIElement {
    [object[]]$Items = @()
    [object]$SelectedItem = $null
    [int]$SelectedIndex = -1
    [string]$DisplayMember = "Display"
    [string]$ValueMember = "Value"
    [string]$Placeholder = "Select an item..."
    [bool]$IsDropDownOpen = $false
    [int]$MaxDropDownHeight = 6
    [int]$ScrollOffset = 0
    [scriptblock]$OnSelectionChanged
    
    ComboBoxComponent([string]$name) : base() {
        $this.Name = $name
        $this.IsFocusable = $true
        $this.Width = 30
        $this.Height = 3
    }
    
    # AI: REFACTORED - Now uses UIElement buffer system
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
#```
        
        try {
            # Clear buffer
            $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
            
            $borderColor = $this.IsFocused ? [ConsoleColor]::Yellow : [ConsoleColor]::Gray
            
            # AI: Draw main combobox
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -BorderStyle "Single" -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Display selected item or placeholder
            $displayText = ""
            if ($this.SelectedItem) {
                if ($this.SelectedItem -is [string]) {
                    $displayText = $this.SelectedItem
                } elseif ($this.SelectedItem -is [hashtable] -and $this.SelectedItem.ContainsKey($this.DisplayMember)) {
                    $displayText = $this.SelectedItem[$this.DisplayMember]
                } else {
                    $displayText = $this.SelectedItem.ToString()
                }
            } else {
                $displayText = $this.Placeholder
            }
            
            $maxDisplayLength = $this.Width - 6
            if ($displayText.Length -gt $maxDisplayLength) {
                $displayText = $displayText.Substring(0, $maxDisplayLength - 3) + "..."
            }
            
            $textColor = $this.SelectedItem ? [ConsoleColor]::White : [ConsoleColor]::DarkGray
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y 1 -Text $displayText `
                -ForegroundColor $textColor -BackgroundColor ([ConsoleColor]::Black)
            
            # AI: Draw dropdown arrow
            $arrow = $this.IsDropDownOpen ? "▲" : "▼"
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 3) -Y 1 -Text $arrow `
                -ForegroundColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
        } catch { 
            Write-Log -Level Error -Message "ComboBox render error for '$($this.Name)': $_" 
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            $handled = $true
            $originalSelection = $this.SelectedItem
            
            if ($this.IsDropDownOpen) {
                switch ($key.Key) {
                    ([ConsoleKey]::Escape) {
                        $this.IsDropDownOpen = $false
                    }
                    ([ConsoleKey]::Enter) {
                        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
                            $this.SelectedItem = $this.Items[$this.SelectedIndex]
                        }
                        $this.IsDropDownOpen = $false
                    }
                    ([ConsoleKey]::UpArrow) {
                        if ($this.SelectedIndex -gt 0) {
                            $this.SelectedIndex--
                            $this._UpdateScrolling()
                        }
                    }
                    ([ConsoleKey]::DownArrow) {
                        if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                            $this.SelectedIndex++
                            $this._UpdateScrolling()
                        }
                    }
                    default { $handled = $false }
                }
            } else {
                switch ($key.Key) {
                    ([ConsoleKey]::Enter) { $this._OpenDropDown() }
                    ([ConsoleKey]::Spacebar) { $this._OpenDropDown() }
                    ([ConsoleKey]::DownArrow) { $this._OpenDropDown() }
                    ([ConsoleKey]::UpArrow) { $this._OpenDropDown() }
                    ([ConsoleKey]::F4) { $this._OpenDropDown() }
                    default { $handled = $false }
                }
            }
            
            if ($handled -and $this.SelectedItem -ne $originalSelection -and $this.OnSelectionChanged) {
                Invoke-WithErrorHandling -Component "$($this.Name).OnSelectionChanged" -Context "Selection Change" -ScriptBlock { 
                    & $this.OnSelectionChanged -SelectedItem $this.SelectedItem 
                }
                $this.RequestRedraw()
            }
            
            return $handled
        } catch { 
            Write-Log -Level Error -Message "ComboBox input error for '$($this.Name)': $_"
            return $false 
        }
    }
    
    hidden [void] _OpenDropDown() {
        if ($this.Items.Count -gt 0) {
            $this.IsDropDownOpen = $true
            $this._FindCurrentSelection()
        }
    }
    
    hidden [void] _FindCurrentSelection() {
        $this.SelectedIndex = -1
        if ($this.SelectedItem) {
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                if ($this._ItemsEqual($this.Items[$i], $this.SelectedItem)) {
                    $this.SelectedIndex = $i
                    break
                }
            }
        }
        if ($this.SelectedIndex -eq -1) { $this.SelectedIndex = 0 }
        $this._UpdateScrolling()
    }
    
    hidden [void] _UpdateScrolling() {
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $this.MaxDropDownHeight)) {
            $this.ScrollOffset = $this.SelectedIndex - $this.MaxDropDownHeight + 1
        }
    }
    
    hidden [bool] _ItemsEqual([object]$item1, [object]$item2) {
        if ($item1 -is [string] -and $item2 -is [string]) {
            return $item1 -eq $item2
        } elseif ($item1 -is [hashtable] -and $item2 -is [hashtable]) {
            return $item1[$this.ValueMember] -eq $item2[$this.ValueMember]
        } else {
            return $item1 -eq $item2
        }
    }
    
    [void] SetItems([object[]]$items) {
        $this.Items = $items
        $this.SelectedItem = $null
        $this.SelectedIndex = -1
        $this.ScrollOffset = 0
        $this.IsDropDownOpen = $false
        $this.RequestRedraw()
    }
    
    [object] GetSelectedValue() {
        if ($this.SelectedItem -is [hashtable] -and $this.SelectedItem.ContainsKey($this.ValueMember)) {
            return $this.SelectedItem[$this.ValueMember]
        }
        return $this.SelectedItem
    }
}
