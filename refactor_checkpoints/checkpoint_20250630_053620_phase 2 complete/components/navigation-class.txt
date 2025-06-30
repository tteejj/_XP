# Navigation Component Classes Module for PMC Terminal v5
# Implements navigation menu functionality with keyboard shortcuts

using namespace System.Management.Automation
using module ..\components\ui-classes.psm1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# NavigationItem - Represents a single menu item
class NavigationItem {
    [string] $Key
    [string] $Label
    [scriptblock] $Action
    [bool] $Enabled = $true
    [bool] $Visible = $true
    [string] $Description = ""
    [ConsoleColor] $KeyColor = [ConsoleColor]::Yellow
    [ConsoleColor] $LabelColor = [ConsoleColor]::White
    
    NavigationItem([string]$key, [string]$label, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($key))   { throw [ArgumentException]::new("Navigation key cannot be null or empty") }
        if ([string]::IsNullOrWhiteSpace($label)) { throw [ArgumentException]::new("Navigation label cannot be null or empty") }
        if ($null -eq $action)                    { throw [ArgumentNullException]::new("action", "Navigation action cannot be null") }
        
        $this.Key = $key.ToUpper()
        $this.Label = $label
        $this.Action = $action
    }
    
    [void] Execute() {
        if (-not $this.Enabled) {
            Write-Log -Level Warning -Message "Attempted to execute disabled navigation item: $($this.Key)"
            return
        }
        
        try {
            Write-Log -Level Debug -Message "Executing navigation item: $($this.Key) - $($this.Label)"
            & $this.Action
        }
        catch {
            Write-Log -Level Error -Message "Navigation action failed for item '$($this.Key)': $_"
            throw
        }
    }
    
    [string] FormatDisplay([bool]$showDescription = $false) {
        # Simplified format display without ANSI escape codes
        $display = "[$($this.Key)] "
        
        if ($this.Enabled) {
            $display += $this.Label
        }
        else {
            $display += "$($this.Label) (Disabled)"
        }
        
        if ($showDescription -and -not [string]::IsNullOrWhiteSpace($this.Description)) {
            $display += " - $($this.Description)"
        }
        
        return $display
    }
}

# NavigationMenu - Component for displaying and handling navigation options
class NavigationMenu : Component {
    [System.Collections.Generic.List[NavigationItem]] $Items
    [hashtable] $Services
    [string] $Orientation = "Vertical"
    [string] $Separator = "  |  "
    [bool] $ShowDescriptions = $false
    [ConsoleColor] $SeparatorColor = [ConsoleColor]::DarkGray
    [int] $SelectedIndex = 0
    
    NavigationMenu([string]$name) : base($name) {
        $this.Items = [System.Collections.Generic.List[NavigationItem]]::new()
        $this.SelectedIndex = 0
    }
    
    NavigationMenu([string]$name, [hashtable]$services) : base($name) {
        if ($null -eq $services) { throw [ArgumentNullException]::new("services") }
        $this.Services = $services
        $this.Items = [System.Collections.Generic.List[NavigationItem]]::new()
        $this.SelectedIndex = 0
    }
    
    [void] AddItem([NavigationItem]$item) {
        if (-not $item) { throw [ArgumentNullException]::new("item") }
        if ($this.Items.Exists({param($x) $x.Key -eq $item.Key})) { 
            throw [InvalidOperationException]::new("Item with key '$($item.Key)' already exists") 
        }
        $this.Items.Add($item)
    }
    
    [void] RemoveItem([string]$key) {
        $item = $this.GetItem($key)
        if ($item) { [void]$this.Items.Remove($item) }
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
    }

    [void] BuildContextMenu([string]$context) {
        $this.Items.Clear()
        
        switch ($context) {
            "Dashboard" {
                $this.AddItem([NavigationItem]::new("N", "New Task", { 
                    $this.Services.Navigation.GoTo("/tasks", @{mode="new"}) 
                }))
                $this.AddItem([NavigationItem]::new("P", "Projects", { 
                    $this.Services.Navigation.GoTo("/projects", @{}) 
                }))
                $this.AddItem([NavigationItem]::new("S", "Settings", { 
                    $this.Services.Navigation.GoTo("/settings", @{}) 
                }))
                $this.AddSeparator()
                $this.AddItem([NavigationItem]::new("Q", "Quit", { 
                    $this.Services.Navigation.RequestExit() 
                }))
            }
            "TaskList" {
                $this.AddItem([NavigationItem]::new("N", "New", { 
                    Write-Host "New task not implemented" 
                }))
                $this.AddItem([NavigationItem]::new("E", "Edit", { 
                    Write-Host "Edit not implemented" 
                }))
                $this.AddItem([NavigationItem]::new("D", "Delete", { 
                    Write-Host "Delete not implemented" 
                }))
                $this.AddItem([NavigationItem]::new("F", "Filter", { 
                    Write-Host "Filter not implemented" 
                }))
                $this.AddSeparator()
                $this.AddItem([NavigationItem]::new("B", "Back", { 
                    $this.Services.Navigation.PopScreen() 
                }))
            }
            default {
                $this.AddItem([NavigationItem]::new("B", "Back", { 
                    $this.Services.Navigation.PopScreen() 
                }))
                $this.AddItem([NavigationItem]::new("H", "Home", { 
                    $this.Services.Navigation.GoTo("/dashboard", @{}) 
                }))
            }
        }
    }
    
    # AI: FIX - Get render coordinates from parent panel
    hidden [hashtable] GetRenderPosition() {
        # Default position if no parent
        $x = 0
        $y = 0
        
        # AI: FIX - If we have a parent Panel, use its content area
        if ($this.Parent -and $this.Parent -is [Panel]) {
            $parentPanel = [Panel]$this.Parent
            $contentArea = $parentPanel.GetContentArea()
            $x = $contentArea.X
            $y = $contentArea.Y
        }
        
        return @{ X = $x; Y = $y }
    }
    
    hidden [void] _RenderContent() {
        # Get visible items
        if ($null -eq $this.Items -or $this.Items.Count -eq 0) {
            return
        }
        
        $visibleItems = @($this.Items | Where-Object { $null -ne $_ -and $_.Visible })
        if ($visibleItems.Count -eq 0) { return }
        
        if ($this.Orientation -eq "Horizontal") { 
            $this.RenderHorizontal($visibleItems) 
        }
        else { 
            $this.RenderVertical($visibleItems) 
        }
    }
    
    hidden [void] RenderHorizontal([object[]]$items) {
        if ($null -eq $items -or $items.Count -eq 0) {
            return
        }
        
        # AI: FIX - Get proper render position from parent
        $pos = $this.GetRenderPosition()
        
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
        
        if (Get-Command "Write-BufferString" -ErrorAction SilentlyContinue) {
            Write-BufferString -X $pos.X -Y $pos.Y -Text $menuText `
                -ForegroundColor ([ConsoleColor]::White) -BackgroundColor ([ConsoleColor]::Black)
        }
    }
    
    hidden [void] RenderVertical([object[]]$items) {
        if ($null -eq $items -or $items.Count -eq 0) {
            return
        }
        
        # AI: FIX - Get proper render position from parent
        $pos = $this.GetRenderPosition()
        
        # Ensure SelectedIndex is within bounds
        if ($this.SelectedIndex -lt 0 -or $this.SelectedIndex -ge $items.Count) {
            $this.SelectedIndex = 0
        }
        
        # AI: FIX - Calculate max width for proper clearing
        $maxWidth = 0
        if ($this.Parent -and $this.Parent -is [Panel]) {
            $parentPanel = [Panel]$this.Parent
            $contentArea = $parentPanel.GetContentArea()
            $maxWidth = $contentArea.Width
        }
        
        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            if ($null -eq $item) { continue }
            
            $prefix = if ($i -eq $this.SelectedIndex -and $item.Key -ne "-") { " > " } else { "   " }
            $menuText = "$prefix[$($item.Key)] $($item.Label)"
            
            # AI: FIX - Pad text to clear the full line width
            if ($maxWidth -gt 0 -and $menuText.Length -lt $maxWidth) {
                $menuText = $menuText.PadRight($maxWidth)
            }
            
            if (Get-Command "Write-BufferString" -ErrorAction SilentlyContinue) {
                $fg = if ($i -eq $this.SelectedIndex -and $item.Key -ne "-") { 
                    [ConsoleColor]::Black 
                } else { 
                    [ConsoleColor]::White 
                }
                $bg = if ($i -eq $this.SelectedIndex -and $item.Key -ne "-") { 
                    [ConsoleColor]::White 
                } else { 
                    [ConsoleColor]::Black 
                }
                
                Write-BufferString -X $pos.X -Y ($pos.Y + $i) -Text $menuText `
                    -ForegroundColor $fg -BackgroundColor $bg
            }
        }
    }
}

Export-ModuleMember -Function @()
