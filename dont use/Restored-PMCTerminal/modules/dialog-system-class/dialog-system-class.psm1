# ==============================================================================
# PMC Terminal v5 - Class-Based Dialog System
# Implements dialogs as proper UIElement classes following the unified architecture
# ==============================================================================









# Base Dialog Class - properly inheriting from UIElement
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
        if ($null -eq $this._private_buffer -or $this._private_buffer.Width -ne $this.Width -or $this._private_buffer.Height -ne $this.Height) {
            $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        }
        $script:DialogState.CurrentDialog = $this
        # AI: FIX - Changed to event-based refresh to break circular dependency
        Publish-Event -EventName "TUI.RefreshRequested"
    }
    
    [void] Close() {
        $script:DialogState.CurrentDialog = $null
        if ($script:DialogState.DialogStack.Count -gt 0) {
            $script:DialogState.CurrentDialog = $script:DialogState.DialogStack.Pop()
        }
        # AI: FIX - Changed to event-based refresh to break circular dependency
        Publish-Event -EventName "TUI.RefreshRequested"
    }
    
    [void] OnRender() {
        if ($null -eq $this._private_buffer) { return }
        $this._private_buffer.Clear([TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black))
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
            -BorderStyle "Single" -BorderColor $this.BorderColor -BackgroundColor [ConsoleColor]::Black -Title $this.Title
        if (-not [string]::IsNullOrWhiteSpace($this.Message)) { $this.RenderMessage() }
        $this.RenderDialogContent()
    }
    
    hidden [void] RenderMessage() {
        $messageY = 2; $messageX = 2; $maxWidth = $this.Width - 4
        $wrappedLines = Get-WordWrappedLines -Text $this.Message -MaxWidth $maxWidth
        foreach ($line in $wrappedLines) {
            if ($messageY -ge ($this.Height - 3)) { break }
            Write-TuiText -Buffer $this._private_buffer -X $messageX -Y $messageY -Text $line -ForegroundColor $this.MessageColor
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

class AlertDialog : Dialog {
    [string] $ButtonText = "OK"
    AlertDialog([string]$title, [string]$message) : base("AlertDialog") {
        $this.Title = $title; $this.Message = $message; $this.Height = 10
        $this.Width = [Math]::Min(80, [Math]::Max(40, $message.Length + 10))
    }
    [void] RenderDialogContent() {
        $buttonY = $this.Height - 2; $buttonLabel = "[ $($this.ButtonText) ]"
        $buttonX = [Math]::Floor(($this.Width - $buttonLabel.Length) / 2)
        Write-TuiText -Buffer $this._private_buffer -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor ([ConsoleColor]::Yellow)
    }
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) { $this.OnConfirm(); return $true }
        return ([Dialog]$this).HandleInput($key)
    }
}

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
            Write-TuiText -Buffer $this._private_buffer -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor $color
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
        # Render prompt
        $promptY = 3
        $promptX = 4
        Write-TuiText -Buffer $this._private_buffer -X $promptX -Y $promptY -Text $this.Prompt -ForegroundColor [ConsoleColor]::White
        
        # Render input box
        $inputY = 5
        $inputX = 4
        $inputWidth = $this.Width - 8
        
        # Input box border
        Write-TuiBox -Buffer $this._private_buffer -X $inputX -Y $inputY -Width $inputWidth -Height 3 `
            -BorderStyle "Single" -BorderColor [ConsoleColor]::DarkGray
        
        # Input value
        $displayValue = $this.InputValue
        if ($displayValue.Length -gt ($inputWidth - 3)) {
            $displayValue = $displayValue.Substring($displayValue.Length - ($inputWidth - 3))
        }
        Write-TuiText -Buffer $this._private_buffer -X ($inputX + 1) -Y ($inputY + 1) -Text $displayValue `
            -ForegroundColor [ConsoleColor]::Yellow
        
        # Render buttons
        $buttonY = $this.Height - 3
        $okLabel = "[ OK ]"
        $cancelLabel = "[ Cancel ]"
        $totalWidth = $okLabel.Length + $cancelLabel.Length + 4
        $startX = [Math]::Floor(($this.Width - $totalWidth) / 2)
        
        Write-TuiText -Buffer $this._private_buffer -X $startX -Y $buttonY -Text $okLabel `
            -ForegroundColor [ConsoleColor]::Green
        Write-TuiText -Buffer $this._private_buffer -X ($startX + $okLabel.Length + 4) -Y $buttonY `
            -Text $cancelLabel -ForegroundColor [ConsoleColor]::Gray
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::Enter) {
                $this.OnSubmit()
                return $true
            }
            ([ConsoleKey]::Escape) {
                $this.OnCancel()
                return $true
            }
            ([ConsoleKey]::Backspace) {
                if ($this.CursorPosition -gt 0) {
                    $this.InputValue = $this.InputValue.Remove($this.CursorPosition - 1, 1)
                    $this.CursorPosition--
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::Delete) {
                if ($this.CursorPosition -lt $this.InputValue.Length) {
                    $this.InputValue = $this.InputValue.Remove($this.CursorPosition, 1)
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this.CursorPosition -gt 0) {
                    $this.CursorPosition--
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::RightArrow) {
                if ($this.CursorPosition -lt $this.InputValue.Length) {
                    $this.CursorPosition++
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::Home) {
                $this.CursorPosition = 0
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::End) {
                $this.CursorPosition = $this.InputValue.Length
                $this.RequestRedraw()
                return $true
            }
            default {
                if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or 
                    $key.KeyChar -in @(' ', '.', '-', '_', '@', '!', '?', ',', ';', ':', '/', '\', '(', ')', '[', ']', '{', '}')) {
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
            Invoke-WithErrorHandling -Component "InputDialog" -Context "OnSubmit" -ScriptBlock {
                & $this.OnSubmitAction $this.InputValue
            }
        }
    }
    
    [void] OnCancel() {
        $this.Close()
        if ($this.OnCancelAction) {
            Invoke-WithErrorHandling -Component "InputDialog" -Context "OnCancel" -ScriptBlock $this.OnCancelAction
        }
    }
}

class ProgressDialog : Dialog {
    [int] $PercentComplete = 0
    [string] $StatusText = ""
    [bool] $ShowCancel = $false
    [bool] $IsCancelled = $false
    
    ProgressDialog([string]$title, [string]$message) : base("ProgressDialog") {
        $this.Title = $title
        $this.Message = $message
        $this.Width = 60
        $this.Height = 10
    }
    
    [void] UpdateProgress([int]$percent, [string]$status = "") {
        $this.PercentComplete = [Math]::Max(0, [Math]::Min(100, $percent))
        if ($status) { $this.StatusText = $status }
        $this.RequestRedraw()
    }
    
    [void] RenderDialogContent() {
        # Progress bar
        $barY = 4
        $barX = 4
        $barWidth = $this.Width - 8
        $filledWidth = [Math]::Floor($barWidth * ($this.PercentComplete / 100.0))
        
        # Bar background
        Write-TuiText -Buffer $this._private_buffer -X $barX -Y $barY `
            -Text ('─' * $barWidth) -ForegroundColor [ConsoleColor]::DarkGray
        
        # Filled portion
        if ($filledWidth -gt 0) {
            Write-TuiText -Buffer $this._private_buffer -X $barX -Y $barY `
                -Text ('█' * $filledWidth) -ForegroundColor [ConsoleColor]::Green
        }
        
        # Percentage text
        $percentText = "$($this.PercentComplete)%"
        $percentX = [Math]::Floor(($this.Width - $percentText.Length) / 2)
        Write-TuiText -Buffer $this._private_buffer -X $percentX -Y ($barY + 1) `
            -Text $percentText -ForegroundColor [ConsoleColor]::White
        
        # Status text
        if ($this.StatusText) {
            $statusY = $barY + 3
            $maxStatusWidth = $this.Width - 8
            if ($this.StatusText.Length -gt $maxStatusWidth) {
                $displayStatus = $this.StatusText.Substring(0, $maxStatusWidth - 3) + "..."
            } else {
                $displayStatus = $this.StatusText
            }
            $statusX = [Math]::Floor(($this.Width - $displayStatus.Length) / 2)
            Write-TuiText -Buffer $this._private_buffer -X $statusX -Y $statusY `
                -Text $displayStatus -ForegroundColor [ConsoleColor]::Gray
        }
        
        # Cancel button if enabled
        if ($this.ShowCancel) {
            $buttonY = $this.Height - 2
            $cancelLabel = "[ Cancel ]"
            $buttonX = [Math]::Floor(($this.Width - $cancelLabel.Length) / 2)
            Write-TuiText -Buffer $this._private_buffer -X $buttonX -Y $buttonY `
                -Text $cancelLabel -ForegroundColor [ConsoleColor]::Yellow
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

class ListDialog : Dialog {
    [string] $Prompt = ""
    [string[]] $Items = @()
    [int] $SelectedIndex = 0
    [int] $ScrollOffset = 0
    [int] $VisibleItems = 10
    [bool] $AllowMultiple = $false
    [System.Collections.Generic.HashSet[int]] $SelectedIndices
    [scriptblock] $OnSelectAction
    [scriptblock] $OnCancelAction
    
    ListDialog([string]$title, [string]$prompt, [string[]]$items, [scriptblock]$onSelect, [scriptblock]$onCancel) : base("ListDialog") {
        $this.Title = $title
        $this.Prompt = $prompt
        $this.Items = $items
        $this.OnSelectAction = $onSelect
        $this.OnCancelAction = $onCancel
        $this.SelectedIndices = [System.Collections.Generic.HashSet[int]]::new()
        
        # Calculate dimensions
        $maxItemWidth = ($items | Measure-Object -Property Length -Maximum).Maximum
        $this.Width = [Math]::Min(80, [Math]::Max(40, $maxItemWidth + 10))
        $this.VisibleItems = [Math]::Min(10, $items.Count)
        $this.Height = $this.VisibleItems + 8
    }
    
    [void] RenderDialogContent() {
        # Render prompt
        if ($this.Prompt) {
            $promptY = 2
            $promptX = 4
            Write-TuiText -Buffer $this._private_buffer -X $promptX -Y $promptY `
                -Text $this.Prompt -ForegroundColor [ConsoleColor]::White
        }
        
        # List area
        $listY = 4
        $listX = 4
        $listWidth = $this.Width - 8
        
        # Render visible items
        $endIndex = [Math]::Min($this.ScrollOffset + $this.VisibleItems, $this.Items.Count)
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $relativeY = $listY + ($i - $this.ScrollOffset)
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            $isChecked = $this.SelectedIndices.Contains($i)
            
            # Truncate if too long
            if ($item.Length -gt ($listWidth - 4)) {
                $item = $item.Substring(0, $listWidth - 7) + "..."
            }
            
            # Format item
            $prefix = ""
            if ($this.AllowMultiple) {
                $prefix = if ($isChecked) { "[x] " } else { "[ ] " }
            }
            $displayText = "$prefix$item"
            
            # Colors
            $fg = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray }
            $bg = if ($isSelected) { [ConsoleColor]::DarkGray } else { [ConsoleColor]::Black }
            
            # Clear line and write
            Write-TuiText -Buffer $this._private_buffer -X $listX -Y $relativeY `
                -Text (' ' * $listWidth) -BackgroundColor $bg
            Write-TuiText -Buffer $this._private_buffer -X $listX -Y $relativeY `
                -Text $displayText -ForegroundColor $fg -BackgroundColor $bg
        }
        
        # Scroll indicators
        if ($this.ScrollOffset -gt 0) {
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 5) -Y $listY `
                -Text "▲" -ForegroundColor [ConsoleColor]::DarkGray
        }
        if ($endIndex -lt $this.Items.Count) {
            Write-TuiText -Buffer $this._private_buffer -X ($this.Width - 5) -Y ($listY + $this.VisibleItems - 1) `
                -Text "▼" -ForegroundColor [ConsoleColor]::DarkGray
        }
        
        # Instructions
        $instructY = $this.Height - 3
        $instructions = if ($this.AllowMultiple) { 
            "Space: Toggle, Enter: Confirm, Esc: Cancel" 
        } else { 
            "Enter: Select, Esc: Cancel" 
        }
        $instructX = [Math]::Floor(($this.Width - $instructions.Length) / 2)
        Write-TuiText -Buffer $this._private_buffer -X $instructX -Y $instructY `
            -Text $instructions -ForegroundColor [ConsoleColor]::DarkGray
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    if ($this.SelectedIndex -lt $this.ScrollOffset) {
                        $this.ScrollOffset = $this.SelectedIndex
                    }
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                    $this.SelectedIndex++
                    if ($this.SelectedIndex -ge ($this.ScrollOffset + $this.VisibleItems)) {
                        $this.ScrollOffset = $this.SelectedIndex - $this.VisibleItems + 1
                    }
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::Spacebar) {
                if ($this.AllowMultiple) {
                    if ($this.SelectedIndices.Contains($this.SelectedIndex)) {
                        [void]$this.SelectedIndices.Remove($this.SelectedIndex)
                    } else {
                        [void]$this.SelectedIndices.Add($this.SelectedIndex)
                    }
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::Enter) {
                $this.OnSelect()
                return $true
            }
            ([ConsoleKey]::Escape) {
                $this.OnCancel()
                return $true
            }
        }
        return $false
    }
    
    [void] OnSelect() {
        $this.Close()
        if ($this.OnSelectAction) {
            if ($this.AllowMultiple) {
                $selectedItems = @()
                foreach ($index in $this.SelectedIndices) {
                    $selectedItems += $this.Items[$index]
                }
                Invoke-WithErrorHandling -Component "ListDialog" -Context "OnSelect" -ScriptBlock {
                    & $this.OnSelectAction $selectedItems
                }
            } else {
                $selectedItem = $this.Items[$this.SelectedIndex]
                Invoke-WithErrorHandling -Component "ListDialog" -Context "OnSelect" -ScriptBlock {
                    & $this.OnSelectAction $selectedItem
                }
            }
        }
    }
    
    [void] OnCancel() {
        $this.Close()
        if ($this.OnCancelAction) {
            Invoke-WithErrorHandling -Component "ListDialog" -Context "OnCancel" -ScriptBlock $this.OnCancelAction
        }
    }
}

# Helper function for word wrapping
function Get-WordWrappedLines {
    param([string]$Text, [int]$MaxWidth)
    
    $lines = @()
    $words = $Text -split '\s+'
    $currentLine = ""
    
    foreach ($word in $words) {
        if ($currentLine.Length -eq 0) {
            $currentLine = $word
        } elseif (($currentLine.Length + 1 + $word.Length) -le $MaxWidth) {
            $currentLine += " " + $word
        } else {
            $lines += $currentLine
            $currentLine = $word
        }
    }
    
    if ($currentLine.Length -gt 0) {
        $lines += $currentLine
    }
    
    return $lines
}

$script:DialogState = @{ CurrentDialog = $null; DialogStack = [System.Collections.Stack]::new() }

function Initialize-DialogSystem {
    Invoke-WithErrorHandling -Component "DialogSystem" -Context "Initialize" -ScriptBlock {
        Subscribe-Event -EventName "Confirm.Request" -Handler { param($EventData)
            $params = $EventData.Data; Show-ConfirmDialog @params }
        Subscribe-Event -EventName "Alert.Show" -Handler { param($EventData)
            $params = $EventData.Data; Show-AlertDialog @params }
        Subscribe-Event -EventName "Input.Request" -Handler { param($EventData)
            $params = $EventData.Data; Show-InputDialog @params }
        Write-Log -Level Info -Message "Class-based Dialog System initialized"
    }
}

function Show-AlertDialog { param([string]$Title="Alert", [string]$Message); Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowAlertDialog" -ScriptBlock { ([AlertDialog]::new($Title, $Message)).Show() } }
function Show-ConfirmDialog { param([string]$Title="Confirm", [string]$Message, [scriptblock]$OnConfirm, [scriptblock]$OnCancel={}); Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowConfirmDialog" -ScriptBlock { ([ConfirmDialog]::new($Title, $Message, $OnConfirm, $OnCancel)).Show() } }
function Show-InputDialog { param([string]$Title="Input", [string]$Prompt, [string]$DefaultValue="", [scriptblock]$OnSubmit, [scriptblock]$OnCancel={}); Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowInputDialog" -ScriptBlock { $d = [InputDialog]::new($Title, $Prompt, $OnSubmit, $OnCancel); if ($DefaultValue) { $d.SetDefaultValue($DefaultValue) }; $d.Show() } }
function Show-ProgressDialog { param([string]$Title="Progress", [string]$Message="Processing...", [int]$PercentComplete=0, [switch]$ShowCancel); Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowProgressDialog" -ScriptBlock { $d = [ProgressDialog]::new($Title, $Message); $d.PercentComplete = $PercentComplete; $d.ShowCancel = $ShowCancel; $d.Show(); return $d } }
function Show-ListDialog { param([string]$Title="Select Item", [string]$Prompt="Choose an item:", [string[]]$Items, [scriptblock]$OnSelect, [scriptblock]$OnCancel={}, [switch]$AllowMultiple); Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowListDialog" -ScriptBlock { $d = [ListDialog]::new($Title, $Prompt, $Items, $OnSelect, $OnCancel); $d.AllowMultiple = $AllowMultiple; $d.Show() } }
function Close-TuiDialog { Invoke-WithErrorHandling -Component "DialogSystem" -Context "CloseDialog" -ScriptBlock { if ($script:DialogState.CurrentDialog) { $script:DialogState.CurrentDialog.Close() } } }
