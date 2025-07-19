# ConfirmDialog Component - Yes/No confirmation dialog

class ConfirmDialog : Dialog {
    [string]$YesText = "Yes"
    [string]$NoText = "No"
    [bool]$DefaultToNo = $true
    hidden [int]$_selectedButton = 1  # 0=Yes, 1=No
    
    ConfirmDialog() : base() {
        $this.DialogWidth = 40
        $this.DialogHeight = 8
        $this.InitializeConfirmDialog()
    }
    
    ConfirmDialog([string]$title, [string]$message) : base($title, $message) {
        $this.DialogWidth = [Math]::Max(40, $message.Length + 4)
        $this.DialogHeight = 8
        $this.InitializeConfirmDialog()
    }
    
    [void] InitializeConfirmDialog() {
        # Set default selection
        $this._selectedButton = if ($this.DefaultToNo) { 1 } else { 0 }
        
        # Key bindings
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.SelectPrevious() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.SelectNext() })
        $this.BindKey([ConsoleKey]::Tab, { $this.SelectNext() })
        $this.BindKey([ConsoleKey]::Enter, { $this.Confirm() })
        $this.BindKey('y', { $this.Yes() })
        $this.BindKey('n', { $this.No() })
    }
    
    [void] SelectPrevious() {
        if ($this._selectedButton -gt 0) {
            $this._selectedButton--
            $this.RequestRender()
        }
    }
    
    [void] SelectNext() {
        if ($this._selectedButton -lt 1) {
            $this._selectedButton++
            $this.RequestRender()
        }
    }
    
    [void] Confirm() {
        if ($this._selectedButton -eq 0) {
            $this.Yes()
        } else {
            $this.No()
        }
    }
    
    [void] Yes() {
        $this.Result = [DialogResult]::Yes
        $this.Close()
    }
    
    [void] No() {
        $this.Result = [DialogResult]::No
        $this.Close()
    }
    
    [string] RenderDialogContent() {
        $output = ""
        
        # Calculate button positions
        $buttonY = $this.DialogY + $this.DialogHeight - 3
        $totalButtonWidth = $this.YesText.Length + $this.NoText.Length + 10  # +4 per button, +2 space
        $startX = $this.DialogX + [int](($this.DialogWidth - $totalButtonWidth) / 2)
        
        # Draw Yes button
        $yesX = $startX
        $output += $this.DrawButton($this.YesText, $yesX, $buttonY, $this._selectedButton -eq 0)
        
        # Draw No button
        $noX = $startX + $this.YesText.Length + 6
        $output += $this.DrawButton($this.NoText, $noX, $buttonY, $this._selectedButton -eq 1)
        
        # Help text
        $helpY = $this.DialogY + $this.DialogHeight - 2
        $helpText = "Press Y/N or use arrows"
        $helpX = $this.DialogX + [int](($this.DialogWidth - $helpText.Length) / 2)
        $output += [VT]::MoveTo($helpX, $helpY)
        $output += [VT]::RGB(100, 100, 100) + $helpText + [VT]::Reset()
        
        return $output
    }
    
    # Static factory methods
    static [bool] Show([string]$title, [string]$message) {
        $dialog = [ConfirmDialog]::new($title, $message)
        $result = $dialog.ShowDialog()
        return $result -eq [DialogResult]::Yes
    }
    
    static [bool] ShowWarning([string]$message) {
        $dialog = [ConfirmDialog]::new("Warning", $message)
        $dialog.DialogBorderColor = [VT]::RGB(255, 200, 100)
        $dialog.DefaultToNo = $true
        $result = $dialog.ShowDialog()
        return $result -eq [DialogResult]::Yes
    }
    
    static [bool] ShowDelete([string]$itemName) {
        $message = "Are you sure you want to delete '$itemName'?"
        $dialog = [ConfirmDialog]::new("Confirm Delete", $message)
        $dialog.YesText = "Delete"
        $dialog.NoText = "Cancel"
        $dialog.DialogBorderColor = [VT]::RGB(255, 100, 100)
        $dialog.DefaultToNo = $true
        $result = $dialog.ShowDialog()
        return $result -eq [DialogResult]::Yes
    }
}