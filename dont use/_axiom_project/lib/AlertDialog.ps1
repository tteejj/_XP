class AlertDialog : Dialog {
    [string] $ButtonText = "OK"
    AlertDialog([string]$title, [string]$message) : base("AlertDialog") {
        $this.Title = $title; $this.Message = $message; $this.Height = 10
        $this.Width = [Math]::Min(80, [Math]::Max(40, $message.Length + 10))
    }
    [void] RenderDialogContent() {
        $buttonY = $this.Height - 2; $buttonLabel = "[ $($this.ButtonText) ]"
        $buttonX = [Math]::Floor(($this.Width - $buttonLabel.Length) / 2)
        Write-TuiText -Buffer $this.{_private_buffer} -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor ([ConsoleColor]::Yellow)
    }
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) { $this.OnConfirm(); return $true }
        return ([Dialog]$this).HandleInput($key)
    }
}
