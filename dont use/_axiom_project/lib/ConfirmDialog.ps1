class ConfirmDialog : Dialog {
    [scriptblock] $OnConfirmAction; [scriptblock] $OnCancelAction
    [string[]] $Buttons = @("Yes", "No"); [int] $SelectedButton = 0
    ConfirmDialog([string]$title, [string]$message, [scriptblock]$onConfirm, [scriptblock]$onCancel) : base("ConfirmDialog") {
        $this.Title = $title; $this.Message = $message; $this.OnConfirmAction = $onConfirm; $this.OnCancelAction = $onCancel
        $this.Width = [Math]::Min(80, [Math]::Max(50, $message.Length + 10)); $this.Height = 10
    }
    [void] RenderDialogContent() {
        $buttonY = $this.Height - 3; $totalButtonWidth = ($this.Buttons.Count * 12) + (($this.Buttons.Count - 1) * 2)
        $buttonX = [Math]::Floor(($this.Width - $totalButtonWidth) / 2)
        for ($i = 0; $i -lt $this.Buttons.Count; $i++) {
            $isSelected = ($i -eq $this.SelectedButton)
            $buttonLabel = if ($isSelected) { "[ $($this.Buttons[$i]) ]" } else { "  $($this.Buttons[$i])  " }
            $color = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray }
            Write-TuiText -Buffer $this.{_private_buffer} -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor $color
            $buttonX += 14
        }
    }
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::LeftArrow) { $this.SelectedButton = [Math]::Max(0, $this.SelectedButton - 1); $this.RequestRedraw(); return $true }
            ([ConsoleKey]::RightArrow) { $this.SelectedButton = [Math]::Min($this.Buttons.Count - 1, $this.SelectedButton + 1); $this.RequestRedraw(); return $true }
            ([ConsoleKey]::Tab) { $this.SelectedButton = ($this.SelectedButton + 1) % $this.Buttons.Count; $this.RequestRedraw(); return $true }
            ([ConsoleKey]::Enter) { if ($this.SelectedButton -eq 0) { $this.OnConfirm() } else { $this.OnCancel() }; return $true }
            ([ConsoleKey]::Spacebar) { if ($this.SelectedButton -eq 0) { $this.OnConfirm() } else { $this.OnCancel() }; return $true }
        }
        return ([Dialog]$this).HandleInput($key)
    }
    [void] OnConfirm() { $this.Close(); if ($this.OnConfirmAction) { Invoke-WithErrorHandling -Component "ConfirmDialog" -Context "OnConfirm" -ScriptBlock $this.OnConfirmAction } }
    [void] OnCancel() { $this.Close(); if ($this.OnCancelAction) { Invoke-WithErrorHandling -Component "ConfirmDialog" -Context "OnCancel" -ScriptBlock $this.OnCancelAction } }
}
