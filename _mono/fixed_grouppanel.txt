# ===============================================================================
# COMPLETE FIXED GROUPPANEL CLASS
# ===============================================================================
# Replace the entire GroupPanel class with this fixed version:

# ===== CLASS: GroupPanel =====
# Module: panels-class
# Dependencies: Panel
# Purpose: Themed panel for grouping
class GroupPanel : Panel {
    [bool]$IsExpanded = $true
    [bool]$CanCollapse = $true

    GroupPanel([string]$name) : base($name) {
        $this.BorderStyle = "Double"
        $this.BorderColor = "#008B8B"     # FIXED: DarkCyan in hex
        $this.BackgroundColor = "#000000" # FIXED: Black in hex
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Show children only if expanded
        foreach ($child in $this.Children) {
            $child.Visible = $this.IsExpanded
        }

        # Adjust height if collapsed
        if (-not $this.IsExpanded -and $this.CanCollapse) {
            $this._originalHeight = $this.Height
            $this.Height = 3  # Just title bar
        }
        elseif ($this.IsExpanded -and $this._originalHeight) {
            $this.Height = $this._originalHeight
        }

        # Add expand/collapse indicator to title
        if ($this.CanCollapse -and $this.Title) {
            $indicator = if ($this.IsExpanded) { "[-]" } else { "[+]" }
            $this.Title = "$indicator $($this.Title.TrimStart('[+]', '[-]').Trim())"
        }

        ([Panel]$this).OnRender()
    }

    hidden [int]$_originalHeight = 0

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or -not $this.CanCollapse) { return $false }
        
        if ($key.Key -eq [ConsoleKey]::Spacebar) {
            $this.Toggle()
            return $true
        }
        
        return $false
    }

    [void] Toggle() {
        $this.IsExpanded = -not $this.IsExpanded
        $this.RequestRedraw()
    }
}
