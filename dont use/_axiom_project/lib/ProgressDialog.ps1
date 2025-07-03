class ProgressDialog : Dialog {
    [int] $PercentComplete = 0
    [string] $StatusText = ""
    [bool] $ShowCancel = $false
    [bool] $IsCancelled = $false
    
    ProgressDialog([string]$title, [string]$message) : base("ProgressDialog") {
        $this.Title = $title; $this.Message = $message; $this.Width = 60; $this.Height = 10
    }
    
    [void] UpdateProgress([int]$percent, [string]$status = "") {
        $this.PercentComplete = [Math]::Max(0, [Math]::Min(100, $percent))
        if ($status) { $this.StatusText = $status }
        $this.RequestRedraw()
    }
    
    [void] RenderDialogContent() {
        $barY = 4; $barX = 4; $barWidth = $this.Width - 8
        $filledWidth = [Math]::Floor($barWidth * ($this.PercentComplete / 100.0))
        Write-TuiText -Buffer $this.{_private_buffer} -X $barX -Y $barY -Text ('─' * $barWidth) -ForegroundColor [ConsoleColor]::DarkGray
        if ($filledWidth -gt 0) { Write-TuiText -Buffer $this.{_private_buffer} -X $barX -Y $barY -Text ('█' * $filledWidth) -ForegroundColor [ConsoleColor]::Green }
        
        $percentText = "$($this.PercentComplete)%"; $percentX = [Math]::Floor(($this.Width - $percentText.Length) / 2)
        Write-TuiText -Buffer $this.{_private_buffer} -X $percentX -Y ($barY + 1) -Text $percentText -ForegroundColor [ConsoleColor]::White
        
        if ($this.StatusText) {
            $statusY = $barY + 3; $maxStatusWidth = $this.Width - 8
            $displayStatus = if ($this.StatusText.Length -gt $maxStatusWidth) { $this.StatusText.Substring(0, $maxStatusWidth - 3) + "..." } else { $this.StatusText }
            $statusX = [Math]::Floor(($this.Width - $displayStatus.Length) / 2)
            Write-TuiText -Buffer $this.{_private_buffer} -X $statusX -Y $statusY -Text $displayStatus -ForegroundColor [ConsoleColor]::Gray
        }
        
        if ($this.ShowCancel) {
            $buttonY = $this.Height - 2; $cancelLabel = "[ Cancel ]"; $buttonX = [Math]::Floor(($this.Width - $cancelLabel.Length) / 2)
            Write-TuiText -Buffer $this.{_private_buffer} -X $buttonX -Y $buttonY -Text $cancelLabel -ForegroundColor [ConsoleColor]::Yellow
        }
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($this.ShowCancel -and $key.Key -in @([ConsoleKey]::Escape, [ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            $this.IsCancelled = $true
            $this.Close()
            return $true
        }
        return $false
    }
}
