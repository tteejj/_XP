class InputDialog : Dialog {
    [string] $Prompt = ""
    [string] $InputValue = ""
    [int] $CursorPosition = 0
    [scriptblock] $OnSubmitAction
    [scriptblock] $OnCancelAction
    
    InputDialog([string]$title, [string]$prompt, [scriptblock]$onSubmit, [scriptblock]$onCancel) : base("InputDialog") {
        $this.Title = $title
        $this.Prompt = $prompt
        $this.OnSubmitAction = $onSubmit
        $this.OnCancelAction = $onCancel
        $this.Width = [Math]::Min(80, [Math]::Max(50, $prompt.Length + 20))
        $this.Height = 12
    }
    
    [void] SetDefaultValue([string]$value) {
        $this.InputValue = $value
        $this.CursorPosition = $value.Length
    }
    
    [void] RenderDialogContent() {
        $promptY = 3; $promptX = 4
        Write-TuiText -Buffer $this.{_private_buffer} -X $promptX -Y $promptY -Text $this.Prompt -ForegroundColor [ConsoleColor]::White
        
        $inputY = 5; $inputX = 4; $inputWidth = $this.Width - 8
        Write-TuiBox -Buffer $this.{_private_buffer} -X $inputX -Y $inputY -Width $inputWidth -Height 3 -BorderStyle "Single" -BorderColor [ConsoleColor]::DarkGray
        
        $displayValue = $this.InputValue
        if ($displayValue.Length -gt ($inputWidth - 3)) {
            $displayValue = $displayValue.Substring($displayValue.Length - ($inputWidth - 3))
        }
        Write-TuiText -Buffer $this.{_private_buffer} -X ($inputX + 1) -Y ($inputY + 1) -Text $displayValue -ForegroundColor [ConsoleColor]::Yellow
        
        $buttonY = $this.Height - 3; $okLabel = "[ OK ]"; $cancelLabel = "[ Cancel ]"
        $totalWidth = $okLabel.Length + $cancelLabel.Length + 4
        $startX = [Math]::Floor(($this.Width - $totalWidth) / 2)
        Write-TuiText -Buffer $this.{_private_buffer} -X $startX -Y $buttonY -Text $okLabel -ForegroundColor [ConsoleColor]::Green
        Write-TuiText -Buffer $this.{_private_buffer} -X ($startX + $okLabel.Length + 4) -Y $buttonY -Text $cancelLabel -ForegroundColor [ConsoleColor]::Gray
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::Enter) { $this.OnSubmit(); return $true }
            ([ConsoleKey]::Escape) { $this.OnCancel(); return $true }
            ([ConsoleKey]::Backspace) { if ($this.CursorPosition -gt 0) { $this.InputValue = $this.InputValue.Remove($this.CursorPosition - 1, 1); $this.CursorPosition--; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::Delete) { if ($this.CursorPosition -lt $this.InputValue.Length) { $this.InputValue = $this.InputValue.Remove($this.CursorPosition, 1); $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::LeftArrow) { if ($this.CursorPosition -gt 0) { $this.CursorPosition--; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::RightArrow) { if ($this.CursorPosition -lt $this.InputValue.Length) { $this.CursorPosition++; $this.RequestRedraw() }; return $true }
            ([ConsoleKey]::Home) { $this.CursorPosition = 0; $this.RequestRedraw(); return $true }
            ([ConsoleKey]::End) { $this.CursorPosition = $this.InputValue.Length; $this.RequestRedraw(); return $true }
            default {
                if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or $key.KeyChar -in @(' ', '.', '-', '_', '@', '!', '?', ',', ';', ':', '/', '\', '(', ')', '[', ']', '{', '}')) {
                    $this.InputValue = $this.InputValue.Insert($this.CursorPosition, $key.KeyChar)
                    $this.CursorPosition++
                    $this.RequestRedraw()
                    return $true
                }
            }
        }
        return ([Dialog]$this).HandleInput($key)
    }
    
    [void] OnSubmit() {
        $this.Close()
        if ($this.OnSubmitAction) {
            Invoke-WithErrorHandling -Component "InputDialog" -Context "OnSubmit" -ScriptBlock { & $this.OnSubmitAction $this.InputValue }
        }
    }
    
    [void] OnCancel() {
        $this.Close()
        if ($this.OnCancelAction) {
            Invoke-WithErrorHandling -Component "InputDialog" -Context "OnCancel" -ScriptBlock $this.OnCancelAction
        }
    }
}
