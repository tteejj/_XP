# PTUI Demo Screen - Showcases all implemented PTUI patterns
# Demonstrates: Alternate buffer, Search, Multi-select, Enhanced input

class PTUIDemoScreen : EnhancedScreen {
    [MultiSelectListBox]$DemoList
    [System.Collections.ArrayList]$SampleData
    [string]$InfoText = ""
    
    PTUIDemoScreen() : base() {
        $this.Title = "PTUI PATTERNS DEMO"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Create sample data
        $this.SampleData = [System.Collections.ArrayList]@(
            @{ Name = "Apple"; Category = "Fruit"; Color = "Red"; Price = 1.50 },
            @{ Name = "Banana"; Category = "Fruit"; Color = "Yellow"; Price = 0.75 },
            @{ Name = "Carrot"; Category = "Vegetable"; Color = "Orange"; Price = 0.50 },
            @{ Name = "Lettuce"; Category = "Vegetable"; Color = "Green"; Price = 2.00 },
            @{ Name = "Tomato"; Category = "Vegetable"; Color = "Red"; Price = 1.25 },
            @{ Name = "Orange"; Category = "Fruit"; Color = "Orange"; Price = 1.00 },
            @{ Name = "Grape"; Category = "Fruit"; Color = "Purple"; Price = 3.00 },
            @{ Name = "Broccoli"; Category = "Vegetable"; Color = "Green"; Price = 1.75 },
            @{ Name = "Strawberry"; Category = "Fruit"; Color = "Red"; Price = 4.00 },
            @{ Name = "Cucumber"; Category = "Vegetable"; Color = "Green"; Price = 1.00 }
        )
        
        # Create searchable multi-select list
        $this.DemoList = [MultiSelectListBox]::new("DemoList")
        $this.DemoList.X = 2
        $this.DemoList.Y = 4
        $this.DemoList.Width = 60
        $this.DemoList.Height = 15
        $this.DemoList.SearchPrompt = "Search items: "
        
        # Custom formatter
        $this.DemoList.ItemFormatter = {
            param($item)
            return "$($item.Name) ($($item.Category)) - $($item.Color) - `$$($item.Price)"
        }.GetNewClosure()
        
        $this.DemoList.SetItems($this.SampleData)
        
        # Enhanced key bindings
        $this.InputManager.RegisterKeyHandler("f1", { $this.ShowHelp() })
        $this.InputManager.RegisterKeyHandler("f2", { $this.FilterFruits() })
        $this.InputManager.RegisterKeyHandler("f3", { $this.FilterVegetables() })
        $this.InputManager.RegisterKeyHandler("f4", { $this.ClearFilter() })
        $this.InputManager.RegisterKeyHandler("ctrl+s", { $this.ShowSelected() })
        $this.InputManager.RegisterKeyHandler("ctrl+r", { $this.SelectRed() })
        
        # Vim-like sequences
        $this.InputManager.RegisterKeySequence("d d", { $this.DeleteSelected() })
        $this.InputManager.RegisterKeySequence("y y", { $this.CopySelected() })
        $this.InputManager.RegisterKeySequence("s a", { $this.SelectAll() })
        $this.InputManager.RegisterKeySequence("s n", { $this.SelectNone() })
        
        # Navigation
        $this.InputManager.RegisterKeyHandler("up", { $this.DemoList.NavigateUp() })
        $this.InputManager.RegisterKeyHandler("down", { $this.DemoList.NavigateDown() })
        $this.InputManager.RegisterKeyHandler("pageup", { $this.DemoList.PageUp() })
        $this.InputManager.RegisterKeyHandler("pagedown", { $this.DemoList.PageDown() })
        
        $this.UpdateStatusBar()
    }
    
    [void] ShowHelp() {
        $helpText = @"
PTUI PATTERNS DEMO - HELP

SEARCH FEATURES:
• Type to search items live
• ESC to clear search
• Backspace to edit search

MULTI-SELECT:
• SPACE to toggle selection
• Ctrl+A to select all
• Ctrl+D to clear selection

FILTERS:
• F2 - Show only fruits
• F3 - Show only vegetables  
• F4 - Clear filter

BULK OPERATIONS:
• Ctrl+S - Show selected items
• Ctrl+R - Select all red items
• dd - Delete selected (vim-style)
• yy - Copy selected (vim-style)
• sa - Select all (vim-style)
• sn - Select none (vim-style)

NAVIGATION:
• gg - Go to top
• G - Go to bottom
• zz - Center view

Press any key to continue...
"@
        
        $this.InfoText = $helpText
        $this.RequestRender()
        [Console]::ReadKey($true) | Out-Null
        $this.InfoText = ""
        $this.RequestRender()
    }
    
    [void] FilterFruits() {
        $fruits = $this.SampleData | Where-Object { $_.Category -eq "Fruit" }
        $this.DemoList.SetItems($fruits)
        $this.InfoText = "Showing fruits only"
        $this.RequestRender()
    }
    
    [void] FilterVegetables() {
        $vegetables = $this.SampleData | Where-Object { $_.Category -eq "Vegetable" }
        $this.DemoList.SetItems($vegetables)
        $this.InfoText = "Showing vegetables only"
        $this.RequestRender()
    }
    
    [void] ClearFilter() {
        $this.DemoList.SetItems($this.SampleData)
        $this.InfoText = "Filter cleared - showing all items"
        $this.RequestRender()
    }
    
    [void] ShowSelected() {
        $selected = $this.DemoList.GetSelectedItems()
        if ($selected.Count -eq 0) {
            $this.InfoText = "No items selected"
        } else {
            $names = $selected | ForEach-Object { $_.Name }
            $this.InfoText = "Selected: $($names -join ', ')"
        }
        $this.RequestRender()
    }
    
    [void] SelectRed() {
        $redItems = @()
        for ($i = 0; $i -lt $this.DemoList.Items.Count; $i++) {
            if ($this.DemoList.Items[$i].Color -eq "Red") {
                $redItems += $i
            }
        }
        
        $this.DemoList.ClearSelection()
        foreach ($index in $redItems) {
            $this.DemoList.SelectedIndices[$index] = $true
        }
        
        $this.InfoText = "Selected all red items"
        $this.RequestRender()
    }
    
    [void] DeleteSelected() {
        $selected = $this.DemoList.GetSelectedItems()
        if ($selected.Count -eq 0) {
            $this.InfoText = "No items to delete"
            $this.RequestRender()
            return
        }
        
        foreach ($item in $selected) {
            $this.SampleData.Remove($item)
        }
        
        $this.DemoList.SetItems($this.SampleData)
        $this.InfoText = "Deleted $($selected.Count) items"
        $this.RequestRender()
    }
    
    [void] CopySelected() {
        $selected = $this.DemoList.GetSelectedItems()
        if ($selected.Count -eq 0) {
            $this.InfoText = "No items to copy"
        } else {
            # Simulate copying by showing what would be copied
            $this.InfoText = "Copied $($selected.Count) items to clipboard"
        }
        $this.RequestRender()
    }
    
    [void] SelectAll() {
        $this.DemoList.SelectAll()
        $this.InfoText = "Selected all visible items"
        $this.RequestRender()
    }
    
    [void] SelectNone() {
        $this.DemoList.ClearSelection()
        $this.InfoText = "Cleared all selections"
        $this.RequestRender()
    }
    
    # Override navigation methods
    [void] GoToTop() {
        $this.DemoList.SelectedIndex = 0
        $this.DemoList.ScrollOffset = 0
        $this.InfoText = "Jumped to top"
        $this.RequestRender()
    }
    
    [void] GoToBottom() {
        $this.DemoList.SelectedIndex = $this.DemoList.Items.Count - 1
        $this.DemoList.AdjustScrollOffset()
        $this.InfoText = "Jumped to bottom"
        $this.RequestRender()
    }
    
    [void] CenterView() {
        $middle = [Math]::Floor($this.DemoList.Items.Count / 2)
        $this.DemoList.SelectedIndex = $middle
        $this.DemoList.AdjustScrollOffset()
        $this.InfoText = "Centered view"
        $this.RequestRender()
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        $this.AddStatusItem('F1', 'help')
        $this.AddStatusItem('F2-F4', 'filters')
        $this.AddStatusItem('Space', 'select')
        $this.AddStatusItem('Type', 'search')
        $this.AddStatusItem('Ctrl+S', 'show selected')
        $this.AddStatusItem('gg/G', 'nav')
        $this.AddStatusItem('ESC', 'back')
        
        # Show current sequence if any
        $this.UpdateSequenceStatus()
    }
    
    [string] RenderContent() {
        $output = ""
        $output += [VT]::Clear()
        
        # Header
        $output += [VT]::MoveTo(2, 1)
        $output += [VT]::TextBright() + "PTUI PATTERNS DEMONSTRATION" + [VT]::Reset()
        
        # Instructions
        $output += [VT]::MoveTo(2, 2)
        $output += [VT]::TextDim() + "This screen demonstrates all PTUI patterns: Search, Multi-select, Key sequences, Alternate buffer" + [VT]::Reset()
        
        # Info text
        if ($this.InfoText) {
            if ($this.InfoText.Contains("`n")) {
                # Multi-line help text
                $output += [VT]::MoveTo(65, 4)
                $lines = $this.InfoText -split "`n"
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    $output += [VT]::MoveTo(65, 4 + $i)
                    $output += [VT]::Warning() + $lines[$i] + [VT]::Reset()
                }
            } else {
                # Single line info
                $output += [VT]::MoveTo(2, 3)
                $output += [VT]::Warning() + $this.InfoText + [VT]::Reset()
            }
        }
        
        # Render the demo list
        $output += $this.DemoList.Render()
        
        return $output
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        # Let demo list handle search input first
        if ($this.DemoList.HandleKey($key)) {
            $this.RequestRender()
            return $true
        }
        
        # Then enhanced input manager
        return ([EnhancedScreen]$this).HandleInput($key)
    }
}