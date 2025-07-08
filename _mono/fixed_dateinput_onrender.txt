# ===============================================================================
# COMPLETE FIXED DATEINPUTCOMPONENT ONRENDER METHOD
# ===============================================================================
# Replace the entire OnRender method in DateInputComponent with this fixed version:

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # FIXED: Use hex strings and theme colors instead of ConsoleColor
            $bgColor = Get-ThemeColor -ColorName "input.background" -DefaultColor $this.BackgroundColor
            $fgColor = Get-ThemeColor -ColorName "input.foreground" -DefaultColor $this.ForegroundColor
            $borderColor = if ($this.IsFocused) { Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF" } else { Get-ThemeColor -ColorName "component.border" -DefaultColor $this.BorderColor }
            
            # Adjust height based on calendar visibility
            $renderHeight = if ($this._showCalendar) { 10 } else { 3 }
            if ($this.Height -ne $renderHeight) {
                $this.Height = $renderHeight
                $this.RequestRedraw()
                return
            }
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            
            # Draw text box
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                -Width $this.Width -Height 3 `
                -Style @{ BorderFG = $borderColor; BG = $bgColor; BorderStyle = "Single" }
            
            # Draw date value
            $dateStr = $this.Value.ToString("yyyy-MM-dd")
            Write-TuiText -Buffer $this._private_buffer -X 1 -Y 1 -Text $dateStr -Style @{ FG = $fgColor; BG = $bgColor }
            
            # Draw calendar icon
            $this._private_buffer.SetCell($this.Width - 2, 1, [TuiCell]::new('📅', $borderColor, $bgColor))
            
            # Draw calendar if shown
            if ($this._showCalendar) {
                $this.DrawCalendar(0, 3)
            }
        }
        catch {}
    }
