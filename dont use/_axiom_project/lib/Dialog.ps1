class Dialog : UIElement {
    [string] $Title = "Dialog"
    [string] $Message = ""
    [ConsoleColor] $BorderColor = [ConsoleColor]::Cyan
    [ConsoleColor] $TitleColor = [ConsoleColor]::White
    [ConsoleColor] $MessageColor = [ConsoleColor]::Gray
    
    Dialog([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 50
        $this.Height = 10
    }
    
    [void] Show() {
        $this.X = [Math]::Floor(($global:TuiState.BufferWidth - $this.Width) / 2)
        $this.Y = [Math]::Floor(($global:TuiState.BufferHeight - $this.Height) / 2)
        if ($null -eq $this.{_private_buffer} -or $this.{_private_buffer}.Width -ne $this.Width -or $this.{_private_buffer}.Height -ne $this.Height) {
            $this.{_private_buffer} = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        }
        Show-TuiOverlay -Element $this
    }
    
    [void] Close() {
        Close-TopTuiOverlay
    }
    
    [void] OnRender() {
        if ($null -eq $this.{_private_buffer}) { return }
        $this.{_private_buffer}.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
        Write-TuiBox -Buffer $this.{_private_buffer} -X 0 -Y 0 -Width $this.Width -Height $this.Height `
            -BorderStyle "Single" -BorderColor $this.BorderColor -BackgroundColor [ConsoleColor]::Black -Title $this.Title
        if (-not [string]::IsNullOrWhiteSpace($this.Message)) { $this.RenderMessage() }
        $this.RenderDialogContent()
    }
    
    hidden [void] RenderMessage() {
        $messageY = 2; $messageX = 2; $maxWidth = $this.Width - 4
        $wrappedLines = Get-WordWrappedLines -Text $this.Message -MaxWidth $maxWidth
        foreach ($line in $wrappedLines) {
            if ($messageY -ge ($this.Height - 3)) { break }
            Write-TuiText -Buffer $this.{_private_buffer} -X $messageX -Y $messageY -Text $line -ForegroundColor $this.MessageColor
            $messageY++
        }
    }
    
    [void] RenderDialogContent() { }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Escape) { $this.OnCancel(); return $true }
        return $false
    }
    
    [void] OnConfirm() { $this.Close() }
    [void] OnCancel() { $this.Close() }
}
