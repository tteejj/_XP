# ===== CLASS: SidebarMenu =====
# Purpose: Simple vertical menu for navigation
class SidebarMenu : UIElement {
    [System.Collections.ArrayList]$MenuItems = [System.Collections.ArrayList]::new()
    [hashtable]$KeyMap = @{}
    [string]$Title = "Menu"
    [bool]$ShowBorder = $true
    
    SidebarMenu([string]$name) : base($name) {
        $this.IsFocusable = $false  # Menu is not focusable, responds to keys directly
        $this.Width = 20
    }
    
    [void] AddMenuItem([string]$key, [string]$label, [string]$action) {
        $menuItem = @{
            Key = $key
            Label = $label  
            Action = $action
        }
        $this.MenuItems.Add($menuItem) | Out-Null
        $this.KeyMap[$key.ToUpper()] = $action
    }
    
    [void] ClearItems() {
        $this.MenuItems.Clear()
        $this.KeyMap.Clear()
    }
    
    [void] OnRender() {
        if (-not $this._private_buffer) { return }
        
        # Clear buffer with background color
        $bgColor = Get-ThemeColor -ColorName "panel.background" -DefaultColor "#1E1E1E"
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Draw border if enabled
        if ($this.ShowBorder) {
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -Style @{
                BorderStyle = "Single"
                BorderFG = Get-ThemeColor "component.border"
                BorderBG = $bgColor
                FillBackground = $true
                FillBG = $bgColor
            }
        }
        
        $y = 1  # Start at 1 to avoid border
        $maxTextWidth = $this.Width - 6  # Reserve space for key display and margins
        
        # Draw title
        if ($this.Title) {
            $titleColor = Get-ThemeColor -ColorName "component.title" -DefaultColor "#FFFFFF"
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y $y -Text $this.Title -Style @{
                FG = $titleColor
                BG = $bgColor
            }
            $y += 2
        }
        
        # Draw menu items
        foreach ($item in $this.MenuItems) {
            if ($item.Key -eq "-") {
                # Separator
                $sepColor = Get-ThemeColor -ColorName "component.border" -DefaultColor "#606060"
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y $y -Text ("─" * ($this.Width - 2)) -Style @{
                    FG = $sepColor
                    BG = $bgColor
                }
            } else {
                # Menu item
                $keyDisplay = "[$($item.Key)]"
                $label = $item.Label
                
                # Truncate label if too long
                if ($label.Length -gt $maxTextWidth) {
                    $label = $label.Substring(0, $maxTextWidth - 2) + ".."
                }
                
                $accentColor = Get-ThemeColor -ColorName "Accent" -DefaultColor "#0078D4"
                $fgColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
                
                Write-TuiText -Buffer $this._private_buffer -X 1 -Y $y -Text $keyDisplay -Style @{
                    FG = $accentColor
                    BG = $bgColor
                }
                Write-TuiText -Buffer $this._private_buffer -X 5 -Y $y -Text $label -Style @{
                    FG = $fgColor
                    BG = $bgColor
                }
            }
            $y++
        }
    }
    
    [string] GetAction([string]$key) {
        $upperKey = $key.ToUpper()
        if ($this.KeyMap.ContainsKey($upperKey)) {
            return $this.KeyMap[$upperKey]
        }
        return $null
    }
    
    [bool] HandleKey([System.ConsoleKeyInfo]$keyInfo) {
        # Handle direct key presses for menu navigation
        $key = $keyInfo.KeyChar.ToString().ToUpper()
        
        # Debug logging
        Write-Log -Level Debug -Message "SidebarMenu.HandleKey: Received key '$key' (KeyChar: '$($keyInfo.KeyChar)', Key: '$($keyInfo.Key)')"
        
        $action = $this.GetAction($key)
        
        if ($action) {
            Write-Log -Level Debug -Message "SidebarMenu.HandleKey: Found action '$action' for key '$key'"
            $actionService = $global:TuiState.Services.ActionService
            if ($actionService) {
                try {
                    $actionService.ExecuteAction($action)
                    return $true
                } catch {
                    Write-Log -Level Error -Message "Failed to execute menu action '$action': $_"
                }
            } else {
                Write-Log -Level Error -Message "SidebarMenu.HandleKey: ActionService is null!"
            }
        } else {
            Write-Log -Level Debug -Message "SidebarMenu.HandleKey: No action found for key '$key'"
        }
        
        return $false
    }
}
