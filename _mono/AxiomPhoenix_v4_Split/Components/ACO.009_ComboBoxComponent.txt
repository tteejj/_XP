# ==============================================================================
# Axiom-Phoenix v4.0 - All Components
# UI components that extend UIElement - full implementations from axiom
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ACO.###" to find specific sections.
# Each section ends with "END_PAGE: ACO.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#

# ===== CLASS: ComboBoxComponent =====
# Module: advanced-input-components
# Dependencies: UIElement, TuiCell
# Purpose: Dropdown with search and overlay rendering
class ComboBoxComponent : UIElement {
    [List[object]]$Items
    [int]$SelectedIndex = -1
    [string]$DisplayMember = ""
    [string]$ValueMember = ""
    [bool]$IsEditable = $false
    [string]$Text = ""
    [scriptblock]$OnSelectionChanged
    hidden [bool]$_isDropdownOpen = $false
    hidden [int]$_highlightedIndex = -1
    hidden [string]$_searchText = ""
    hidden [List[int]]$_filteredIndices
    
    ComboBoxComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 25
        $this.Height = 3
        $this.Items = [List[object]]::new()
        $this._filteredIndices = [List[int]]::new()
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor("input.background")
            $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
            
            # Draw main box
            if ($this.IsFocused) { 
                $borderColor = Get-ThemeColor("Primary") 
            } else { 
                $borderColor = Get-ThemeColor("component.border") 
            }
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -Style @{ BorderFG = $borderColor; BG = $bgColor; BorderStyle = "Single" }
            
            # Draw selected text or placeholder
            $displayText = ""
            if ($this.IsEditable) {
                $displayText = $this._searchText
            }
            elseif ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
                $item = $this.Items[$this.SelectedIndex]
                $displayText = $this.GetDisplayText($item)
            }
            
            if ($displayText) { 
                $textColor = Get-ThemeColor("input.foreground") 
            } else { 
                $textColor = Get-ThemeColor("input.placeholder") 
            }
            
            $maxTextWidth = $this.Width - 4  # Border + dropdown arrow
            if ($displayText.Length -gt $maxTextWidth) {
                $displayText = $displayText.Substring(0, $maxTextWidth)
            }
            
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $displayText `
                -Style @{ FG = $textColor; BG = $bgColor }
            
            # Draw dropdown arrow
            if ($this._isDropdownOpen) { 
                $arrowChar = '▲' 
            } else { 
                $arrowChar = '▼' 
            }
            if ($this.IsFocused) { 
                $arrowColor = Get-ThemeColor("Accent") 
            } else { 
                $arrowColor = Get-ThemeColor("Subtle") 
            }
            $this._private_buffer.SetCell($this.Width - 2, 1, [TuiCell]::new($arrowChar, $arrowColor, $bgColor))
            
            # Draw dropdown if open (as overlay)
            if ($this._isDropdownOpen) {
                $this.IsOverlay = $true
                $this.DrawDropdown()
            }
            else {
                $this.IsOverlay = $false
            }
        }
        catch {}
    }
    
    hidden [void] DrawDropdown() {
        $dropdownY = $this.Height
        $maxDropdownHeight = 10
        $dropdownHeight = [Math]::Min($this._filteredIndices.Count + 2, $maxDropdownHeight)
        
        if ($dropdownHeight -lt 3) { $dropdownHeight = 3 }  # Minimum height
        
        # Create dropdown buffer
        $dropdownBuffer = [TuiBuffer]::new($this.Width, $dropdownHeight)
        $dropdownBuffer.Name = "ComboDropdown"
        
        # Draw dropdown border
        Write-TuiBox -Buffer $dropdownBuffer -X 0 -Y 0 `
            -Width $this.Width -Height $dropdownHeight `
            -Style @{ BorderFG = Get-ThemeColor("component.border"); BG = Get-ThemeColor("input.background"); BorderStyle = "Single" }
        
        # Draw items
        $itemY = 1
        $maxItems = $dropdownHeight - 2
        $scrollOffset = 0
        
        if ($this._highlightedIndex -ge $maxItems) {
            $scrollOffset = $this._highlightedIndex - $maxItems + 1
        }
        
        for ($i = $scrollOffset; $i -lt $this._filteredIndices.Count -and $itemY -lt $dropdownHeight - 1; $i++) {
            $itemIndex = $this._filteredIndices[$i]
            $item = $this.Items[$itemIndex]
            $itemText = $this.GetDisplayText($item)
            
            $itemFg = Get-ThemeColor("list.item.normal")
            $itemBg = Get-ThemeColor("input.background")
            
            if ($i -eq $this._highlightedIndex) {
                $itemFg = Get-ThemeColor("list.item.selected")
                $itemBg = Get-ThemeColor("list.item.selected.background")
            }
            elseif ($itemIndex -eq $this.SelectedIndex) {
                $itemFg = Get-ThemeColor("Accent")
            }
            
            # Clear line and draw item
            for ($x = 1; $x -lt $this.Width - 1; $x++) {
                $dropdownBuffer.SetCell($x, $itemY, [TuiCell]::new(' ', $itemFg, $itemBg))
            }
            
            $maxTextWidth = $this.Width - 2
            if ($itemText.Length -gt $maxTextWidth) {
                $itemText = $itemText.Substring(0, $maxTextWidth - 3) + "..."
            }
            
            Write-TuiText -Buffer $dropdownBuffer -X 1 -Y $itemY -Text $itemText -Style @{ FG = $itemFg; BG = $itemBg }
            $itemY++
        }
        
        # Blend dropdown buffer with main buffer at dropdown position
        $absPos = $this.GetAbsolutePosition()
        $dropX = 0
        $dropY = $dropdownY
        
        for ($y = 0; $y -lt $dropdownBuffer.Height; $y++) {
            for ($x = 0; $x -lt $dropdownBuffer.Width; $x++) {
                $cell = $dropdownBuffer.GetCell($x, $y)
                if ($cell) {
                    $this._private_buffer.SetCell($dropX + $x, $dropY + $y, $cell)
                }
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        $handled = $true
        
        if (-not $this._isDropdownOpen) {
            switch ($key.Key) {
                ([ConsoleKey]::Enter) { 
                    $this.OpenDropdown()
                }
                ([ConsoleKey]::Spacebar) {
                    if (-not $this.IsEditable) {
                        $this.OpenDropdown()
                    }
                    else {
                        $handled = $false
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    $this.OpenDropdown()
                }
                default {
                    if ($this.IsEditable -and $key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                        $this._searchText += $key.KeyChar
                        $this.OpenDropdown()
                        $this.FilterItems()
                    }
                    else {
                        $handled = $false
                    }
                }
            }
        }
        else {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this.CloseDropdown()
                }
                ([ConsoleKey]::Enter) {
                    if ($this._highlightedIndex -ge 0 -and $this._highlightedIndex -lt $this._filteredIndices.Count) {
                        $this.SelectItem($this._filteredIndices[$this._highlightedIndex])
                        $this.CloseDropdown()
                    }
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this._highlightedIndex -gt 0) {
                        $this._highlightedIndex--
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this._highlightedIndex -lt $this._filteredIndices.Count - 1) {
                        $this._highlightedIndex++
                    }
                }
                ([ConsoleKey]::Home) {
                    $this._highlightedIndex = 0
                }
                ([ConsoleKey]::End) {
                    $this._highlightedIndex = $this._filteredIndices.Count - 1
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.IsEditable -and $this._searchText.Length -gt 0) {
                        $this._searchText = $this._searchText.Substring(0, $this._searchText.Length - 1)
                        $this.FilterItems()
                    }
                }
                default {
                    if ($this.IsEditable -and $key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                        $this._searchText += $key.KeyChar
                        $this.FilterItems()
                    }
                    else {
                        $handled = $false
                    }
                }
            }
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    hidden [void] OpenDropdown() {
        $this._isDropdownOpen = $true
        $this.FilterItems()
        
        # Set highlighted index to selected item
        if ($this.SelectedIndex -ge 0) {
            for ($i = 0; $i -lt $this._filteredIndices.Count; $i++) {
                if ($this._filteredIndices[$i] -eq $this.SelectedIndex) {
                    $this._highlightedIndex = $i
                    break
                }
            }
        }
        
        if ($this._highlightedIndex -eq -1 -and $this._filteredIndices.Count -gt 0) {
            $this._highlightedIndex = 0
        }
    }
    
    hidden [void] CloseDropdown() {
        $this._isDropdownOpen = $false
        $this.IsOverlay = $false
        if (-not $this.IsEditable) {
            $this._searchText = ""
        }
    }
    
    hidden [void] FilterItems() {
        $this._filteredIndices.Clear()
        
        if ($this._searchText -eq "") {
            # Show all items
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                $this._filteredIndices.Add($i)
            }
        }
        else {
            # Filter items based on search text
            $searchLower = $this._searchText.ToLower()
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                $itemText = $this.GetDisplayText($this.Items[$i]).ToLower()
                if ($itemText.Contains($searchLower)) {
                    $this._filteredIndices.Add($i)
                }
            }
        }
        
        # Reset highlighted index
        if ($this._highlightedIndex -ge $this._filteredIndices.Count) {
            $this._highlightedIndex = $this._filteredIndices.Count - 1
        }
        if ($this._highlightedIndex -lt 0 -and $this._filteredIndices.Count -gt 0) {
            $this._highlightedIndex = 0
        }
    }
    
    hidden [void] SelectItem([int]$index) {
        $oldIndex = $this.SelectedIndex
        $this.SelectedIndex = $index
        
        if (-not $this.IsEditable) {
            $this.Text = $this.GetDisplayText($this.Items[$index])
        }
        
        if ($oldIndex -ne $index -and $this.OnSelectionChanged) {
            try { & $this.OnSelectionChanged $this $index } catch {}
        }
    }
    
    hidden [string] GetDisplayText([object]$item) {
        if ($null -eq $item) { return "" }
        
        if ($this.DisplayMember -and $item.PSObject.Properties[$this.DisplayMember]) {
            return $item.$($this.DisplayMember).ToString()
        }
        
        return $item.ToString()
    }
}

#<!-- END_PAGE: ACO.009 -->
