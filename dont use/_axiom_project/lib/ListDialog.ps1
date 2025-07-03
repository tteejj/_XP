class ListDialog : Dialog {
    [string] $Prompt = ""; [string[]] $Items = @(); [int] $SelectedIndex = 0; [int] $ScrollOffset = 0; [int] $VisibleItems = 10; [bool] $AllowMultiple = $false; [System.Collections.Generic.HashSet[int]] $SelectedIndices; [scriptblock] $OnSelectAction; [scriptblock] $OnCancelAction
    
    ListDialog([string]$title, [string]$prompt, [string[]]$items, [scriptblock]$onSelect, [scriptblock]$onCancel) : base("ListDialog") {
        $this.Title = $title; $this.Prompt = $prompt; $this.Items = $items; $this.OnSelectAction = $onSelect; $this.OnCancelAction = $onCancel
        $this.SelectedIndices = [System.Collections.Generic.HashSet[int]]::new()
        $maxItemWidth = ($items | Measure-Object -Property Length -Maximum).Maximum
        $this.Width = [Math]::Min(80, [Math]::Max(40, $maxItemWidth + 10))
        $this.VisibleItems = [Math]::Min(10, $items.Count)
        $this.Height = $this.VisibleItems + 8
    }
    
    [void] RenderDialogContent() {
        if ($this.Prompt) { $promptY = 2; $promptX = 4; Write-TuiText -Buffer $this.{_private_buffer} -X $promptX -Y $promptY -Text $this.Prompt -ForegroundColor [ConsoleColor]::White }
        
        $listY = 4; $listX = 4; $listWidth = $this.Width - 8
        $endIndex = [Math]::Min($this.ScrollOffset + $this.VisibleItems, $this.Items.Count)
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $relativeY = $listY + ($i - $this.ScrollOffset); $item = $this.Items[$i]; $isSelected = ($i -eq $this.SelectedIndex); $isChecked = $this.SelectedIndices.Contains($i)
            if ($item.Length -gt ($listWidth - 4)) { $item = $item.Substring(0, $listWidth - 7) + "..." }
            $prefix = if ($this.AllowMultiple) { if ($isChecked) { "[x] " } else { "[ ] " } } else { "" }
            $displayText = "$prefix$item"
            $fg = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray }; $bg = if ($isSelected) { [ConsoleColor]::DarkGray } else { [ConsoleColor]::Black }
            Write-TuiText -Buffer $this.{_private_buffer} -X $listX -Y $relativeY -Text (' ' * $listWidth) -BackgroundColor $bg
            Write-TuiText -Buffer $this.{_private_buffer} -X $listX -Y $relativeY -Text $displayText -ForegroundColor $fg -BackgroundColor $bg
        }
        
        if ($this.ScrollOffset -gt 0) { Write-TuiText -Buffer $this.{_private_buffer} -X ($this.Width - 5) -Y $listY -Text "▲" -ForegroundColor [ConsoleColor]::DarkGray }
        if ($endIndex -lt $this.Items.Count) { Write-TuiText -Buffer $this.{_private_buffer} -X ($this.Width - 5) -Y ($listY + $this.VisibleItems - 1) -Text "▼" -ForegroundColor [ConsoleColor]::DarkGray }
        
        $instructY = $this.Height - 3; $instructions = if ($this.AllowMultiple) { "Space: Toggle, Enter: Confirm, Esc: Cancel" } else { "Enter: Select, Esc: Cancel" }; $instructX = [Math]::Floor(($this.Width - $instructions.Length) / 2)
        Write-TuiText -Buffer $this.{_private_buffer} -X $instructX -Y $instructY -Text $instructions -ForegroundColor [ConsoleColor]::DarkGray
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) { if ($this.SelectedIndex -gt 0) { $this.SelectedIndex--; if ($this.SelectedIndex -lt $this.ScrollOffset) { $this.ScrollOffset = $this.SelectedIndex }; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::DownArrow) { if ($this.SelectedIndex -lt ($this.Items.Count - 1)) { $this.SelectedIndex++; if ($this.SelectedIndex -ge ($this.ScrollOffset + $this.VisibleItems)) { $this.ScrollOffset = $this.SelectedIndex - $this.VisibleItems + 1 }; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::Spacebar) { if ($this.AllowMultiple) { if ($this.SelectedIndices.Contains($this.SelectedIndex)) { [void]$this.SelectedIndices.Remove($this.SelectedIndex) } else { [void]$this.SelectedIndices.Add($this.SelectedIndex) }; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::Enter) { $this.OnSelect(); return $true }
            ([ConsoleKey]::Escape) { $this.OnCancel(); return $true }
        }
        return $false
    }
    
    [void] OnSelect() {
        $this.Close()
        if ($this.OnSelectAction) {
            if ($this.AllowMultiple) {
                $selectedItems = @(); foreach ($index in $this.SelectedIndices) { $selectedItems += $this.Items[$index] }
                Invoke-WithErrorHandling -Component "ListDialog" -Context "OnSelect" -ScriptBlock { & $this.OnSelectAction $selectedItems }
            } else {
                $selectedItem = $this.Items[$this.SelectedIndex]
                Invoke-WithErrorHandling -Component "ListDialog" -Context "OnSelect" -ScriptBlock { & $this.OnSelectAction $selectedItem }
            }
        }
    }
    
    [void] OnCancel() {
        $this.Close()
        if ($this.OnCancelAction) {
            Invoke-WithErrorHandling -Component "ListDialog" -Context "OnCancel" -ScriptBlock $this.OnCancelAction
        }
    }
}
