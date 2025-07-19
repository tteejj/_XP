# Command Palette Component - Quick command execution interface
# Inspired by VS Code's Ctrl+Shift+P functionality

class CommandPalette : Component {
    [System.Collections.ArrayList]$Commands
    [System.Collections.ArrayList]$FilteredCommands
    [string]$SearchText = ""
    [int]$SelectedIndex = 0
    [bool]$IsOpen = $false
    [int]$MaxHeight = 15
    [scriptblock]$OnExecute = $null
    [scriptblock]$OnCancel = $null
    
    # Visual settings
    [int]$Width = 60
    [int]$PaddingX = 2
    [int]$PaddingY = 1
    
    CommandPalette([string]$name) : base($name) {
        $this.Commands = [System.Collections.ArrayList]::new()
        $this.FilteredCommands = [System.Collections.ArrayList]::new()
        $this.IsFocusable = $true
    }
    
    [void] RegisterCommand([string]$name, [string]$description, [scriptblock]$action) {
        $this.Commands.Add(@{
            Name = $name
            Description = $description
            Action = $action
            SearchText = "$name $description".ToLower()
        }) | Out-Null
    }
    
    [void] RegisterCommands([array]$commands) {
        foreach ($cmd in $commands) {
            $this.RegisterCommand($cmd.Name, $cmd.Description, $cmd.Action)
        }
    }
    
    [void] Open() {
        $this.IsOpen = $true
        $this.SearchText = ""
        $this.SelectedIndex = 0
        $this.UpdateFilter()
        $this.Visible = $true
        $this.RequestFocus()
        $this.Invalidate()
    }
    
    [void] Close() {
        $this.IsOpen = $false
        $this.Visible = $false
        $this.SearchText = ""
        if ($this.OnCancel) {
            & $this.OnCancel
        }
        $this.Invalidate()
    }
    
    [void] UpdateFilter() {
        $this.FilteredCommands.Clear()
        
        if ([string]::IsNullOrEmpty($this.SearchText)) {
            $this.FilteredCommands.AddRange($this.Commands)
        } else {
            $searchLower = $this.SearchText.ToLower()
            $scored = @()
            
            foreach ($cmd in $this.Commands) {
                $score = $this.CalculateScore($cmd.SearchText, $searchLower)
                if ($score -gt 0) {
                    $scored += @{
                        Command = $cmd
                        Score = $score
                    }
                }
            }
            
            # Sort by score descending
            $sorted = $scored | Sort-Object -Property Score -Descending
            foreach ($item in $sorted) {
                $this.FilteredCommands.Add($item.Command) | Out-Null
            }
        }
        
        # Reset selection if out of bounds
        if ($this.SelectedIndex -ge $this.FilteredCommands.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FilteredCommands.Count - 1)
        }
    }
    
    [int] CalculateScore([string]$text, [string]$search) {
        # Simple fuzzy matching score
        $score = 0
        $textIndex = 0
        
        for ($i = 0; $i -lt $search.Length; $i++) {
            $char = $search[$i]
            $found = $false
            
            for ($j = $textIndex; $j -lt $text.Length; $j++) {
                if ($text[$j] -eq $char) {
                    $score += 10
                    if ($j -eq $textIndex) {
                        $score += 5  # Bonus for consecutive characters
                    }
                    $textIndex = $j + 1
                    $found = $true
                    break
                }
            }
            
            if (-not $found) {
                return 0  # Character not found
            }
        }
        
        # Bonus for exact match
        if ($text.Contains($search)) {
            $score += 50
        }
        
        # Bonus for match at beginning
        if ($text.StartsWith($search)) {
            $score += 100
        }
        
        return $score
    }
    
    [void] OnRender([object]$buffer) {
        if (-not $this.IsOpen -or -not $this.Visible) { return }
        
        # Calculate position (centered on screen)
        $screenWidth = [Console]::WindowWidth
        $screenHeight = [Console]::WindowHeight
        $paletteX = [int](($screenWidth - $this.Width) / 2)
        $paletteY = [int]($screenHeight * 0.2)  # 20% from top
        
        # Draw shadow
        $shadowColor = [VT]::RGB(20, 20, 20)
        for ($y = 1; $y -le $this.GetHeight(); $y++) {
            $this.DrawText($buffer, $paletteX + 2, $paletteY + $y, 
                          $shadowColor + (" " * $this.Width) + [VT]::Reset())
        }
        
        # Draw background
        $bgColor = [VT]::RGBBG(40, 40, 50)
        for ($y = 0; $y -lt $this.GetHeight(); $y++) {
            $this.DrawText($buffer, $paletteX, $paletteY + $y, 
                          $bgColor + (" " * $this.Width) + [VT]::Reset())
        }
        
        # Draw border
        $borderColor = [VT]::RGB(100, 150, 200)
        $this.DrawBorder($buffer, $paletteX, $paletteY, $this.Width, $this.GetHeight(), $borderColor)
        
        # Draw title
        $title = " Command Palette "
        $titleX = $paletteX + [int](($this.Width - $title.Length) / 2)
        $this.DrawText($buffer, $titleX, $paletteY, 
                      $borderColor + [VT]::Bold() + $title + [VT]::Reset())
        
        # Draw search box
        $searchY = $paletteY + 2
        $searchX = $paletteX + $this.PaddingX
        $searchWidth = $this.Width - ($this.PaddingX * 2)
        
        $this.DrawText($buffer, $searchX, $searchY, 
                      [VT]::RGB(150, 150, 150) + "Search: " + [VT]::Reset())
        
        $searchBoxX = $searchX + 8
        $searchBoxWidth = $searchWidth - 8
        $searchBg = if ($this.IsFocused) { [VT]::RGBBG(50, 50, 70) } else { [VT]::RGBBG(30, 30, 40) }
        $this.DrawText($buffer, $searchBoxX, $searchY,
                      $searchBg + $this.SearchText.PadRight($searchBoxWidth) + [VT]::Reset())
        
        # Draw filtered commands
        $listY = $searchY + 2
        $visibleItems = [Math]::Min($this.FilteredCommands.Count, $this.MaxHeight - 5)
        $scrollOffset = $this.CalculateScrollOffset($visibleItems)
        
        for ($i = 0; $i -lt $visibleItems; $i++) {
            $cmdIndex = $i + $scrollOffset
            if ($cmdIndex -ge $this.FilteredCommands.Count) { break }
            
            $cmd = $this.FilteredCommands[$cmdIndex]
            $itemY = $listY + $i
            $isSelected = ($cmdIndex -eq $this.SelectedIndex)
            
            if ($isSelected) {
                # Selected item background
                $this.DrawText($buffer, $paletteX + 1, $itemY,
                              [VT]::RGBBG(60, 60, 100) + (" " * ($this.Width - 2)) + [VT]::Reset())
            }
            
            # Command name
            $nameX = $paletteX + $this.PaddingX
            $nameColor = if ($isSelected) { [VT]::RGB(255, 255, 255) } else { [VT]::RGB(200, 200, 255) }
            $this.DrawText($buffer, $nameX, $itemY, $nameColor + $cmd.Name + [VT]::Reset())
            
            # Command description
            if ($cmd.Description) {
                $descX = $nameX + 25
                $descColor = if ($isSelected) { [VT]::RGB(200, 200, 200) } else { [VT]::RGB(150, 150, 150) }
                $maxDescLen = $this.Width - $descX + $paletteX - $this.PaddingX
                $desc = if ($cmd.Description.Length -gt $maxDescLen) {
                    $cmd.Description.Substring(0, $maxDescLen - 3) + "..."
                } else {
                    $cmd.Description
                }
                $this.DrawText($buffer, $descX, $itemY, $descColor + $desc + [VT]::Reset())
            }
            
            # Selection indicator
            if ($isSelected) {
                $this.DrawText($buffer, $paletteX + 1, $itemY,
                              [VT]::RGB(100, 200, 255) + "▶" + [VT]::Reset())
            }
        }
        
        # Draw scrollbar if needed
        if ($this.FilteredCommands.Count -gt $visibleItems) {
            $this.DrawScrollbar($buffer, $paletteX + $this.Width - 2, $listY, 
                               $visibleItems, $scrollOffset, $this.FilteredCommands.Count)
        }
        
        # Draw help text
        $helpY = $paletteY + $this.GetHeight() - 2
        $helpText = "↑↓ Navigate • Enter Select • Esc Cancel"
        $helpX = $paletteX + [int](($this.Width - $helpText.Length) / 2)
        $this.DrawText($buffer, $helpX, $helpY,
                      [VT]::RGB(100, 100, 100) + $helpText + [VT]::Reset())
        
        # Show cursor in search box
        $cursorX = $searchBoxX + $this.SearchText.Length
        if ($cursorX -lt $searchBoxX + $searchBoxWidth) {
            $this.DrawText($buffer, $cursorX, $searchY, [VT]::ShowCursor())
        }
    }
    
    [int] GetHeight() {
        $itemCount = [Math]::Min($this.FilteredCommands.Count, $this.MaxHeight - 5)
        return 5 + $itemCount + 2  # Border + search + items + help
    }
    
    [int] CalculateScrollOffset([int]$visibleItems) {
        if ($this.FilteredCommands.Count -le $visibleItems) {
            return 0
        }
        
        # Keep selected item visible
        if ($this.SelectedIndex -lt $visibleItems / 2) {
            return 0
        }
        elseif ($this.SelectedIndex -gt $this.FilteredCommands.Count - $visibleItems / 2) {
            return $this.FilteredCommands.Count - $visibleItems
        }
        else {
            return $this.SelectedIndex - [int]($visibleItems / 2)
        }
    }
    
    [void] DrawBorder([object]$buffer, [int]$x, [int]$y, [int]$w, [int]$h, [string]$color) {
        # Top border
        $this.DrawText($buffer, $x, $y, $color + "╭" + ("─" * ($w - 2)) + "╮" + [VT]::Reset())
        
        # Sides
        for ($i = 1; $i -lt $h - 1; $i++) {
            $this.DrawText($buffer, $x, $y + $i, $color + "│" + [VT]::Reset())
            $this.DrawText($buffer, $x + $w - 1, $y + $i, $color + "│" + [VT]::Reset())
        }
        
        # Bottom border
        $this.DrawText($buffer, $x, $y + $h - 1, $color + "╰" + ("─" * ($w - 2)) + "╯" + [VT]::Reset())
    }
    
    [void] DrawScrollbar([object]$buffer, [int]$x, [int]$y, [int]$height, [int]$offset, [int]$total) {
        $thumbSize = [Math]::Max(1, [int]($height * $height / $total))
        $thumbPos = [int](($height - $thumbSize) * $offset / ($total - $height))
        
        for ($i = 0; $i -lt $height; $i++) {
            $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { "█" } else { "░" }
            $this.DrawText($buffer, $x, $y + $i, [VT]::RGB(80, 80, 100) + $char + [VT]::Reset())
        }
    }
    
    [void] DrawText([object]$buffer, [int]$x, [int]$y, [string]$text) {
        # Simplified for alcar - would integrate with buffer system
        # In production, this would write to the buffer
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.IsOpen) { return $false }
        
        switch ($key.Key) {
            ([ConsoleKey]::Escape) {
                $this.Close()
                return $true
            }
            ([ConsoleKey]::Enter) {
                if ($this.FilteredCommands.Count -gt 0 -and $this.SelectedIndex -ge 0) {
                    $cmd = $this.FilteredCommands[$this.SelectedIndex]
                    $this.Close()
                    
                    if ($cmd.Action) {
                        & $cmd.Action
                    }
                    
                    if ($this.OnExecute) {
                        & $this.OnExecute $cmd
                    }
                }
                return $true
            }
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.Invalidate()
                }
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.FilteredCommands.Count - 1) {
                    $this.SelectedIndex++
                    $this.Invalidate()
                }
                return $true
            }
            ([ConsoleKey]::Backspace) {
                if ($this.SearchText.Length -gt 0) {
                    $this.SearchText = $this.SearchText.Substring(0, $this.SearchText.Length - 1)
                    $this.UpdateFilter()
                    $this.Invalidate()
                }
                return $true
            }
            default {
                if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or 
                    $key.KeyChar -eq ' ' -or [char]::IsPunctuation($key.KeyChar)) {
                    $this.SearchText += $key.KeyChar
                    $this.UpdateFilter()
                    $this.Invalidate()
                    return $true
                }
            }
        }
        
        return $false
    }
    
    # Static helper to create a global command palette
    static [CommandPalette] CreateGlobal() {
        $palette = [CommandPalette]::new("GlobalCommandPalette")
        
        # Register default commands
        $palette.RegisterCommands(@(
            @{Name = "Tasks: View All"; Description = "Open task list"; Action = {
                $global:ScreenManager.Push([TaskScreen]::new())
            }},
            @{Name = "Projects: View All"; Description = "Open project list"; Action = {
                $global:ScreenManager.Push([ProjectsScreen]::new())
            }},
            @{Name = "File: Browse"; Description = "Open file browser"; Action = {
                $global:ScreenManager.Push([FileBrowserScreen]::new())
            }},
            @{Name = "Editor: New File"; Description = "Create new file in editor"; Action = {
                $global:ScreenManager.Push([TextEditorScreenV2]::new())
            }},
            @{Name = "View: Dashboard"; Description = "Return to dashboard"; Action = {
                $global:ScreenManager.Push([DashboardScreen]::new())
            }},
            @{Name = "Settings: Open"; Description = "Open settings"; Action = {
                $global:ScreenManager.Push([SettingsScreenV2]::new())
            }},
            @{Name = "App: Quit"; Description = "Exit application"; Action = {
                $global:ScreenManager.Quit()
            }}
        ))
        
        return $palette
    }
}