# Dialog Base Class - Modal dialog system for alcar

enum DialogResult {
    None
    OK
    Cancel
    Yes
    No
    Retry
    Abort
}

class Dialog : Screen {
    [string]$Message = ""
    [DialogResult]$Result = [DialogResult]::None
    [int]$DialogWidth = 50
    [int]$DialogHeight = 10
    [bool]$CenterOnScreen = $true
    [bool]$Modal = $true
    [bool]$ShowShadow = $true
    
    # Visual properties
    [string]$DialogBorderStyle = "Double"  # Single, Double, Rounded
    [string]$DialogBackgroundColor = ""
    [string]$DialogBorderColor = ""
    [string]$ShadowColor = ""
    
    # Position (if not centered)
    [int]$DialogX = 0
    [int]$DialogY = 0
    
    # Callbacks
    [scriptblock]$OnShown = $null
    [scriptblock]$OnClosed = $null
    
    Dialog() {
        $this.Title = "Dialog"
        $this.InitializeDialog()
    }
    
    Dialog([string]$title, [string]$message) {
        $this.Title = $title
        $this.Message = $message
        $this.InitializeDialog()
    }
    
    [void] InitializeDialog() {
        # Dialog-specific initialization
        $this.UpdateDialogPosition()
        
        # Common key bindings
        $this.BindKey([ConsoleKey]::Escape, { $this.Cancel() })
    }
    
    [void] UpdateDialogPosition() {
        if ($this.CenterOnScreen) {
            $screenWidth = [Console]::WindowWidth
            $screenHeight = [Console]::WindowHeight
            $this.DialogX = [int](($screenWidth - $this.DialogWidth) / 2)
            $this.DialogY = [int](($screenHeight - $this.DialogHeight) / 2)
        }
    }
    
    [DialogResult] ShowDialog() {
        # Store current screen state if modal
        if ($this.Modal -and $global:ScreenManager) {
            $global:ScreenManager.Push($this)
        }
        
        # Fire OnShown event
        if ($this.OnShown) {
            & $this.OnShown $this
        }
        
        # Run dialog
        $this.Active = $true
        while ($this.Active) {
            $this.ProcessInput()
            $this.Render()
        }
        
        # Fire OnClosed event
        if ($this.OnClosed) {
            & $this.OnClosed $this $this.Result
        }
        
        return $this.Result
    }
    
    [void] OK() {
        $this.Result = [DialogResult]::OK
        $this.Close()
    }
    
    [void] Cancel() {
        $this.Result = [DialogResult]::Cancel
        $this.Close()
    }
    
    [void] Close() {
        $this.Active = $false
        
        # Pop from screen manager if modal
        if ($this.Modal -and $global:ScreenManager) {
            $global:ScreenManager.Pop()
        }
    }
    
    [string] RenderContent() {
        $output = ""
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Draw overlay background if modal
        if ($this.Modal) {
            $overlayColor = [VT]::RGBBG(20, 20, 20)
            for ($y = 1; $y -le $height; $y++) {
                $output += [VT]::MoveTo(1, $y)
                $output += $overlayColor + (" " * $width) + [VT]::Reset()
            }
        }
        
        # Draw shadow if enabled
        if ($this.ShowShadow) {
            $shadowColor = if ($this.ShadowColor) { $this.ShadowColor } else { [VT]::RGBBG(10, 10, 10) }
            for ($y = 1; $y -le $this.DialogHeight; $y++) {
                $output += [VT]::MoveTo($this.DialogX + 2, $this.DialogY + $y)
                $output += $shadowColor + (" " * $this.DialogWidth) + [VT]::Reset()
            }
        }
        
        # Draw dialog background
        $bgColor = if ($this.DialogBackgroundColor) { $this.DialogBackgroundColor } else { [VT]::RGBBG(30, 30, 40) }
        for ($y = 0; $y -lt $this.DialogHeight; $y++) {
            $output += [VT]::MoveTo($this.DialogX, $this.DialogY + $y)
            $output += $bgColor + (" " * $this.DialogWidth) + [VT]::Reset()
        }
        
        # Draw border
        $borderColor = if ($this.DialogBorderColor) { $this.DialogBorderColor } else { [VT]::RGB(100, 100, 150) }
        $output += $this.DrawDialogBorder($borderColor)
        
        # Draw title
        if ($this.Title) {
            $titleText = " $($this.Title) "
            $titleX = $this.DialogX + [int](($this.DialogWidth - $titleText.Length) / 2)
            $output += [VT]::MoveTo($titleX, $this.DialogY)
            $output += $borderColor + [VT]::Bold() + $titleText + [VT]::Reset()
        }
        
        # Draw message
        if ($this.Message) {
            $messageLines = $this.WrapText($this.Message, $this.DialogWidth - 4)
            $startY = $this.DialogY + 2
            
            foreach ($line in $messageLines) {
                $lineX = $this.DialogX + 2
                $output += [VT]::MoveTo($lineX, $startY)
                $output += [VT]::RGB(220, 220, 220) + $line + [VT]::Reset()
                $startY++
            }
        }
        
        # Draw dialog-specific content (override in derived classes)
        $output += $this.RenderDialogContent()
        
        return $output
    }
    
    [string] RenderDialogContent() {
        # Override in derived classes to add buttons, inputs, etc.
        return ""
    }
    
    [string] DrawDialogBorder([string]$color) {
        $output = ""
        
        $chars = switch ($this.DialogBorderStyle) {
            "Double" { @{TL="╔"; TR="╗"; BL="╚"; BR="╝"; H="═"; V="║"} }
            "Rounded" { @{TL="╭"; TR="╮"; BL="╰"; BR="╯"; H="─"; V="│"} }
            default { @{TL="┌"; TR="┐"; BL="└"; BR="┘"; H="─"; V="│"} }
        }
        
        # Top border
        $output += [VT]::MoveTo($this.DialogX, $this.DialogY)
        $output += $color + $chars.TL + ($chars.H * ($this.DialogWidth - 2)) + $chars.TR
        
        # Sides
        for ($y = 1; $y -lt $this.DialogHeight - 1; $y++) {
            $output += [VT]::MoveTo($this.DialogX, $this.DialogY + $y)
            $output += $color + $chars.V
            $output += [VT]::MoveTo($this.DialogX + $this.DialogWidth - 1, $this.DialogY + $y)
            $output += $color + $chars.V
        }
        
        # Bottom border
        $output += [VT]::MoveTo($this.DialogX, $this.DialogY + $this.DialogHeight - 1)
        $output += $color + $chars.BL + ($chars.H * ($this.DialogWidth - 2)) + $chars.BR
        
        $output += [VT]::Reset()
        return $output
    }
    
    [string[]] WrapText([string]$text, [int]$width) {
        $lines = @()
        $words = $text -split ' '
        $currentLine = ""
        
        foreach ($word in $words) {
            if ($currentLine.Length + $word.Length + 1 -le $width) {
                if ($currentLine) {
                    $currentLine += " " + $word
                } else {
                    $currentLine = $word
                }
            } else {
                if ($currentLine) {
                    $lines += $currentLine
                }
                $currentLine = $word
            }
        }
        
        if ($currentLine) {
            $lines += $currentLine
        }
        
        return $lines
    }
    
    # Helper method to draw buttons
    [string] DrawButton([string]$text, [int]$x, [int]$y, [bool]$isSelected) {
        $output = ""
        
        if ($isSelected) {
            $bgColor = [VT]::RGBBG(60, 60, 100)
            $fgColor = [VT]::RGB(255, 255, 255)
            $borderColor = [VT]::RGB(100, 200, 255)
        } else {
            $bgColor = [VT]::RGBBG(40, 40, 50)
            $fgColor = [VT]::RGB(200, 200, 200)
            $borderColor = [VT]::RGB(80, 80, 100)
        }
        
        $buttonWidth = $text.Length + 4
        
        # Button background
        $output += [VT]::MoveTo($x, $y)
        $output += $bgColor + (" " * $buttonWidth) + [VT]::Reset()
        
        # Button border
        $output += [VT]::MoveTo($x, $y)
        $output += $borderColor + "[" + [VT]::Reset()
        $output += [VT]::MoveTo($x + $buttonWidth - 1, $y)
        $output += $borderColor + "]" + [VT]::Reset()
        
        # Button text
        $output += [VT]::MoveTo($x + 2, $y)
        $output += $fgColor + $text + [VT]::Reset()
        
        return $output
    }
}