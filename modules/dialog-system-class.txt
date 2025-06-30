####\modules\dialog-system-class.psm1
# ==============================================================================
# PMC Terminal v5 - Class-Based Dialog System
# Implements dialogs as proper UIElement classes following the unified architecture
# ==============================================================================

using namespace System.Management.Automation
using module ..\components\ui-classes.psm1
using module ..\components\tui-primitives.psm1
using module ..\modules\exceptions.psm1
using module ..\modules\logger.psm1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
        # Calculate centered position
        $this.X = [Math]::Floor(($global:TuiState.BufferWidth - $this.Width) / 2)
        $this.Y = [Math]::Floor(($global:TuiState.BufferHeight - $this.Height) / 2)
        
        # Initialize buffer with correct size
        if ($null -eq $this._private_buffer -or $this._private_buffer.Width -ne $this.Width -or $this._private_buffer.Height -ne $this.Height) {
            $this._private_buffer = [TuiBuffer]::new($this.Width, $this.Height, "$($this.Name).Buffer")
        }
        
        # Register with dialog manager
        $script:DialogState.CurrentDialog = $this
        # AI: FIX - Correctly call the exported function directly.
        Request-TuiRefresh
    }
    
    [void] Close() {
        $script:DialogState.CurrentDialog = $null
        if ($script:DialogState.DialogStack.Count -gt 0) {
            $script:DialogState.CurrentDialog = $script:DialogState.DialogStack.Pop()
        }
        # AI: FIX - Correctly call the exported function directly.
        Request-TuiRefresh
    }
    
    # Implement OnRender for new architecture
    [void] OnRender() {
        if ($null -eq $this._private_buffer) { return }
        
        # Clear buffer
        $bgCell = [TuiCell]::new(' ', [ConsoleColor]::White, [ConsoleColor]::Black)
        $this._private_buffer.Clear($bgCell)
        
        # Draw dialog box
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
            -BorderStyle "Single" -BorderColor $this.BorderColor -BackgroundColor [ConsoleColor]::Black -Title $this.Title
        
        # Draw message if present
        if (-not [string]::IsNullOrWhiteSpace($this.Message)) {
            $this.RenderMessage()
        }
        
        # Let derived classes render their specific content
        $this.RenderDialogContent()
    }
    
    hidden [void] RenderMessage() {
        $messageY = 2
        $messageX = 2
        $maxWidth = $this.Width - 4
        
        # AI: FIX - Correctly call the exported function directly.
        $wrappedLines = Get-WordWrappedLines -Text $this.Message -MaxWidth $maxWidth
        foreach ($line in $wrappedLines) {
            if ($messageY -ge ($this.Height - 3)) { break }
            Write-TuiText -Buffer $this._private_buffer -X $messageX -Y $messageY -Text $line -ForegroundColor $this.MessageColor
            $messageY++
        }
    }
    
    # Virtual method for derived classes
    [void] RenderDialogContent() { }
    
    # Base input handling - ESC closes dialog
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.OnCancel()
            return $true
        }
        return $false
    }
    
    # Virtual methods for derived classes
    [void] OnConfirm() { $this.Close() }
    [void] OnCancel() { $this.Close() }
}

# Alert Dialog - Simple OK dialog
class AlertDialog : Dialog {
    [string] $ButtonText = "OK"
    
    AlertDialog([string]$title, [string]$message) : base("AlertDialog") {
        $this.Title = $title
        $this.Message = $message
        $this.Height = 10
        $this.Width = [Math]::Min(80, [Math]::Max(40, $message.Length + 10))
    }
    
    [void] RenderDialogContent() {
        # Render OK button
        $buttonY = $this.Height - 2
        $buttonLabel = "[ $($this.ButtonText) ]"
        $buttonX = [Math]::Floor(($this.Width - $buttonLabel.Length) / 2)
        
        Write-TuiText -Buffer $this._private_buffer -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor ([ConsoleColor]::Yellow)
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::Enter) { $this.OnConfirm(); return $true }
            ([ConsoleKey]::Spacebar) { $this.OnConfirm(); return $true }
            ([ConsoleKey]::Escape) { $this.OnCancel(); return $true }
        }
        return $false
    }
}

# Confirm Dialog - Yes/No dialog
class ConfirmDialog : Dialog {
    [scriptblock] $OnConfirmAction
    [scriptblock] $OnCancelAction
    [string[]] $Buttons = @("Yes", "No")
    [int] $SelectedButton = 0
    
    ConfirmDialog([string]$title, [string]$message, [scriptblock]$onConfirm, [scriptblock]$onCancel) : base("ConfirmDialog") {
        $this.Title = $title
        $this.Message = $message
        $this.OnConfirmAction = $onConfirm
        $this.OnCancelAction = $onCancel
        $this.Width = [Math]::Min(80, [Math]::Max(50, $message.Length + 10))
        $this.Height = 10
    }
    
    [void] RenderDialogContent() {
        # Render buttons
        $buttonY = $this.Height - 3
        $totalButtonWidth = ($this.Buttons.Count * 12) + (($this.Buttons.Count - 1) * 2)
        $buttonX = [Math]::Floor(($this.Width - $totalButtonWidth) / 2)
        
        for ($i = 0; $i -lt $this.Buttons.Count; $i++) {
            $button = $this.Buttons[$i]
            $isSelected = ($i -eq $this.SelectedButton)
            $buttonLabel = if ($isSelected) { "[ $button ]" } else { "  $button  " }
            $color = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray }
            
            Write-TuiText -Buffer $this._private_buffer -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor $color
            $buttonX += 14
        }
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::LeftArrow) { 
                $this.SelectedButton = [Math]::Max(0, $this.SelectedButton - 1)
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::RightArrow) { 
                $this.SelectedButton = [Math]::Min($this.Buttons.Count - 1, $this.SelectedButton + 1)
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Tab) { 
                $this.SelectedButton = ($this.SelectedButton + 1) % $this.Buttons.Count
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Enter) { 
                if ($this.SelectedButton -eq 0) { $this.OnConfirm() } else { $this.OnCancel() }
                return $true
            }
            ([ConsoleKey]::Spacebar) { 
                if ($this.SelectedButton -eq 0) { $this.OnConfirm() } else { $this.OnCancel() }
                return $true
            }
            ([ConsoleKey]::Escape) { 
                $this.OnCancel()
                return $true
            }
        }
        return $false
    }
    
    [void] OnConfirm() {
        $this.Close()
        if ($this.OnConfirmAction) {
            Invoke-WithErrorHandling -Component "ConfirmDialog" -Context "OnConfirm" -ScriptBlock $this.OnConfirmAction
        }
    }
    
    [void] OnCancel() {
        $this.Close()
        if ($this.OnCancelAction) {
            Invoke-WithErrorHandling -Component "ConfirmDialog" -Context "OnCancel" -ScriptBlock $this.OnCancelAction
        }
    }
}

# Input Dialog - Text input dialog
class InputDialog : Dialog {
    [string] $Prompt = ""
    [string] $InputValue = ""
    [string] $DefaultValue = ""
    [scriptblock] $OnSubmitAction
    [scriptblock] $OnCancelAction
    [int] $FocusedElement = 0  # 0=TextBox, 1=OK, 2=Cancel
    [int] $CursorPosition = 0
    
    InputDialog([string]$title, [string]$prompt, [scriptblock]$onSubmit, [scriptblock]$onCancel) : base("InputDialog") {
        $this.Title = $title
        $this.Prompt = $prompt
        $this.OnSubmitAction = $onSubmit
        $this.OnCancelAction = $onCancel
        $this.Width = [Math]::Min(70, [Math]::Max(50, $prompt.Length + 10))
        $this.Height = 10
    }
    
    [void] RenderDialogContent() {
        # Render prompt
        $promptX = 2
        $promptY = 2
        Write-TuiText -Buffer $this._private_buffer -X $promptX -Y $promptY -Text $this.Prompt -ForegroundColor ([ConsoleColor]::White)
        
        # Render input box
        $inputY = $promptY + 2
        $inputWidth = $this.Width - 4
        $isFocused = ($this.FocusedElement -eq 0)
        $borderColor = if ($isFocused) { [ConsoleColor]::Yellow } else { [ConsoleColor]::DarkGray }
        
        Write-TuiBox -Buffer $this._private_buffer -X $promptX -Y $inputY -Width $inputWidth -Height 3 -BorderColor $borderColor
        
        # Render input text
        $displayText = $this.InputValue
        if ($displayText.Length -gt ($inputWidth - 3)) {
            $displayText = $displayText.Substring(0, $inputWidth - 3)
        }
        Write-TuiText -Buffer $this._private_buffer -X ($promptX + 1) -Y ($inputY + 1) -Text $displayText -ForegroundColor ([ConsoleColor]::White)
        
        # Show cursor when focused
        if ($isFocused -and $this.CursorPosition -le $displayText.Length) {
            Write-TuiText -Buffer $this._private_buffer -X ($promptX + 1 + $this.CursorPosition) -Y ($inputY + 1) `
                -Text "_" -ForegroundColor ([ConsoleColor]::Yellow)
        }
        
        # Render buttons
        $buttonY = $this.Height - 2
        $buttonSpacing = 15
        $buttonsWidth = $buttonSpacing * 2
        $buttonX = [Math]::Floor(($this.Width - $buttonsWidth) / 2)
        
        # OK button
        $okFocused = ($this.FocusedElement -eq 1)
        $okText = if ($okFocused) { "[ OK ]" } else { "  OK  " }
        $okColor = if ($okFocused) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray }
        Write-TuiText -Buffer $this._private_buffer -X $buttonX -Y $buttonY -Text $okText -ForegroundColor $okColor
        
        # Cancel button
        $cancelFocused = ($this.FocusedElement -eq 2)
        $cancelText = if ($cancelFocused) { "[ Cancel ]" } else { "  Cancel  " }
        $cancelColor = if ($cancelFocused) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Gray }
        Write-TuiText -Buffer $this._private_buffer -X ($buttonX + $buttonSpacing) -Y $buttonY -Text $cancelText -ForegroundColor $cancelColor
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::Tab) {
                $direction = if ($key.Modifiers -band [ConsoleModifiers]::Shift) { -1 } else { 1 }
                $this.FocusedElement = ($this.FocusedElement + $direction + 3) % 3
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Escape) { 
                $this.OnCancel()
                return $true
            }
            default {
                switch ($this.FocusedElement) {
                    0 { # TextBox
                        switch ($key.Key) {
                            ([ConsoleKey]::Enter) { 
                                $this.OnConfirm()
                                return $true
                            }
                            ([ConsoleKey]::Backspace) {
                                if ($this.InputValue.Length -gt 0 -and $this.CursorPosition -gt 0) {
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
                                $this.CursorPosition = [Math]::Max(0, $this.CursorPosition - 1)
                                $this.RequestRedraw()
                                return $true
                            }
                            ([ConsoleKey]::RightArrow) {
                                $this.CursorPosition = [Math]::Min($this.InputValue.Length, $this.CursorPosition + 1)
                                $this.RequestRedraw()
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
                                if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
                                    $this.InputValue = $this.InputValue.Insert($this.CursorPosition, $key.KeyChar)
                                    $this.CursorPosition++
                                    $this.RequestRedraw()
                                    return $true
                                }
                            }
                        }
                    }
                    1 { # OK Button
                        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                            $this.OnConfirm()
                            return $true
                        }
                    }
                    2 { # Cancel Button
                        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                            $this.OnCancel()
                            return $true
                        }
                    }
                }
            }
        }
        return $false
    }
    
    [void] SetDefaultValue([string]$value) {
        $this.InputValue = $value
        $this.DefaultValue = $value
        $this.CursorPosition = $value.Length
    }
    
    [void] OnConfirm() {
        $this.Close()
        if ($this.OnSubmitAction) {
            $submitAction = $this.OnSubmitAction
            $submittedValue = $this.InputValue
            Invoke-WithErrorHandling -Component "InputDialog" -Context "OnSubmit" -ScriptBlock {
                & $submitAction -Value $submittedValue
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

# Progress Dialog
class ProgressDialog : Dialog {
    [int] $PercentComplete = 0
    [bool] $ShowCancel = $false
    [bool] $IsCancelled = $false
    
    ProgressDialog([string]$title, [string]$message) : base("ProgressDialog") {
        $this.Title = $title
        $this.Message = $message
        $this.Width = 60
        $this.Height = 8
    }
    
    [void] RenderDialogContent() {
        # Render progress bar
        $barY = 4
        $barWidth = $this.Width - 4
        $filledWidth = [Math]::Floor($barWidth * ($this.PercentComplete / 100.0))
        
        # Draw bar background
        Write-TuiText -Buffer $this._private_buffer -X 2 -Y $barY -Text ("─" * $barWidth) -ForegroundColor ([ConsoleColor]::DarkGray)
        
        # Draw filled portion
        if ($filledWidth -gt 0) {
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y $barY -Text ("█" * $filledWidth) -ForegroundColor ([ConsoleColor]::Green)
        }
        
        # Draw percentage
        $percentText = "$($this.PercentComplete)%"
        $percentX = [Math]::Floor(($this.Width - $percentText.Length) / 2)
        Write-TuiText -Buffer $this._private_buffer -X $percentX -Y $barY -Text $percentText -ForegroundColor ([ConsoleColor]::White)
        
        # Draw cancel button if enabled
        if ($this.ShowCancel) {
            $buttonY = $this.Height - 2
            $buttonLabel = if ($this.IsCancelled) { "[ Cancelling... ]" } else { "[ Cancel ]" }
            $buttonX = [Math]::Floor(($this.Width - $buttonLabel.Length) / 2)
            Write-TuiText -Buffer $this._private_buffer -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor ([ConsoleColor]::Yellow)
        }
    }
    
    [void] UpdateProgress([int]$percent, [string]$message) {
        $this.PercentComplete = [Math]::Min(100, [Math]::Max(0, $percent))
        if (-not [string]::IsNullOrWhiteSpace($message)) {
            $this.Message = $message
        }
        $this.RequestRedraw()
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($this.ShowCancel -and -not $this.IsCancelled) {
            if ($key.Key -in @([ConsoleKey]::Escape, [ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                $this.IsCancelled = $true
                $this.RequestRedraw()
                return $true
            }
        }
        return $false
    }
}

# List Dialog
class ListDialog : Dialog {
    [string[]] $Items = @()
    [int] $SelectedIndex = 0
    [bool] $AllowMultiple = $false
    [System.Collections.Generic.HashSet[int]] $SelectedItems
    [scriptblock] $OnSelectAction
    [scriptblock] $OnCancelAction
    
    ListDialog([string]$title, [string]$prompt, [string[]]$items, [scriptblock]$onSelect, [scriptblock]$onCancel) : base("ListDialog") {
        $this.Title = $title
        $this.Message = $prompt
        $this.Items = $items
        $this.OnSelectAction = $onSelect
        $this.OnCancelAction = $onCancel
        $this.Width = 60
        $this.Height = [Math]::Min(20, $items.Count + 8)
        $this.SelectedItems = [System.Collections.Generic.HashSet[int]]::new()
    }
    
    [void] RenderDialogContent() {
        $listY = 4
        $listHeight = $this.Height - 7
        $listWidth = $this.Width - 4
        
        # Calculate visible range with scrolling
        $startIndex = [Math]::Max(0, $this.SelectedIndex - [Math]::Floor($listHeight / 2))
        $endIndex = [Math]::Min($this.Items.Count - 1, $startIndex + $listHeight - 1)
        
        # Render items
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            $itemY = $listY + ($i - $startIndex)
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            $isChecked = $this.SelectedItems.Contains($i)
            
            $prefix = if ($this.AllowMultiple) {
                if ($isChecked) { "[X] " } else { "[ ] " }
            } else { "" }
            
            $itemText = "$prefix$item"
            if ($itemText.Length -gt $listWidth - 2) {
                $itemText = $itemText.Substring(0, $listWidth - 5) + "..."
            }
            
            $bgColor = if ($isSelected) { [ConsoleColor]::White } else { [ConsoleColor]::Black }
            $fgColor = if ($isSelected) { [ConsoleColor]::Black } else { [ConsoleColor]::Gray }
            
            # Clear the line first
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y $itemY -Text (" " * ($listWidth - 2)) -BackgroundColor $bgColor
            Write-TuiText -Buffer $this._private_buffer -X 2 -Y $itemY -Text $itemText -ForegroundColor $fgColor -BackgroundColor $bgColor
        }
        
        # Render scrollbar if needed
        if ($this.Items.Count -gt $listHeight) {
            $scrollbarX = $this.Width - 2
            $scrollbarHeight = $listHeight
            $thumbSize = [Math]::Max(1, [Math]::Floor($scrollbarHeight * $listHeight / $this.Items.Count))
            $thumbPos = [Math]::Floor($scrollbarHeight * $this.SelectedIndex / $this.Items.Count)
            
            for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { "█" } else { "│" }
                Write-TuiText -Buffer $this._private_buffer -X $scrollbarX -Y ($listY + $i) -Text $char -ForegroundColor ([ConsoleColor]::DarkGray)
            }
        }
        
        # Render buttons for multi-select
        if ($this.AllowMultiple) {
            $buttonY = $this.Height - 2
            $okText = "[ OK ]"
            $cancelText = "[ Cancel ]"
            $buttonSpacing = 15
            $totalWidth = 30
            $startX = [Math]::Floor(($this.Width - $totalWidth) / 2)
            
            Write-TuiText -Buffer $this._private_buffer -X $startX -Y $buttonY -Text $okText -ForegroundColor ([ConsoleColor]::Green)
            Write-TuiText -Buffer $this._private_buffer -X ($startX + $buttonSpacing) -Y $buttonY -Text $cancelText -ForegroundColor ([ConsoleColor]::Gray)
        }
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - 1)
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + 1)
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Spacebar) {
                if ($this.AllowMultiple) {
                    if ($this.SelectedItems.Contains($this.SelectedIndex)) {
                        [void]$this.SelectedItems.Remove($this.SelectedIndex)
                    } else {
                        [void]$this.SelectedItems.Add($this.SelectedIndex)
                    }
                    $this.RequestRedraw()
                }
                return $true
            }
            ([ConsoleKey]::Enter) {
                $this.OnConfirm()
                return $true
            }
            ([ConsoleKey]::Escape) {
                $this.OnCancel()
                return $true
            }
        }
        return $false
    }
    
    [void] OnConfirm() {
        $this.Close()
        if ($this.OnSelectAction) {
            $selectAction = $this.OnSelectAction
            if ($this.AllowMultiple) {
                $selectedValues = @($this.SelectedItems | ForEach-Object { $this.Items[$_] })
                Invoke-WithErrorHandling -Component "ListDialog" -Context "OnSelect" -ScriptBlock {
                    & $selectAction -Selected $selectedValues
                }
            } else {
                $selected = $this.Items[$this.SelectedIndex]
                Invoke-WithErrorHandling -Component "ListDialog" -Context "OnSelect" -ScriptBlock {
                    & $selectAction -Selected $selected
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

# Dialog State Management
$script:DialogState = @{
    CurrentDialog = $null
    DialogStack   = [System.Collections.Stack]::new()
}

# Public API Functions
function Initialize-DialogSystem {
    Invoke-WithErrorHandling -Component "DialogSystem" -Context "Initialize" -ScriptBlock {
        # Subscribe to dialog events
        Subscribe-Event -EventName "Confirm.Request" -Handler {
            param($EventData)
            $params = $EventData.Data
            Show-ConfirmDialog -Title $params.Title -Message $params.Message `
                -OnConfirm $params.OnConfirm -OnCancel $params.OnCancel
        }
        
        Subscribe-Event -EventName "Alert.Show" -Handler {
            param($EventData)
            $params = $EventData.Data
            Show-AlertDialog -Title $params.Title -Message $params.Message
        }
        
        Subscribe-Event -EventName "Input.Request" -Handler {
            param($EventData)
            $params = $EventData.Data
            Show-InputDialog -Title $params.Title -Prompt $params.Prompt `
                -DefaultValue $params.DefaultValue -OnSubmit $params.OnSubmit -OnCancel $params.OnCancel
        }
        
        Write-Log -Level Info -Message "Class-based Dialog System initialized"
    }
}

function Show-AlertDialog {
    param(
        [string]$Title = "Alert",
        [string]$Message
    )
    
    Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowAlertDialog" -ScriptBlock {
        $dialog = [AlertDialog]::new($Title, $Message)
        $dialog.Show()
    }
}

function Show-ConfirmDialog {
    param(
        [string]$Title = "Confirm",
        [string]$Message,
        [scriptblock]$OnConfirm,
        [scriptblock]$OnCancel = {}
    )
    
    Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowConfirmDialog" -ScriptBlock {
        $dialog = [ConfirmDialog]::new($Title, $Message, $OnConfirm, $OnCancel)
        $dialog.Show()
    }
}

function Show-InputDialog {
    param(
        [string]$Title = "Input",
        [string]$Prompt,
        [string]$DefaultValue = "",
        [scriptblock]$OnSubmit,
        [scriptblock]$OnCancel = {}
    )
    
    Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowInputDialog" -ScriptBlock {
        $dialog = [InputDialog]::new($Title, $Prompt, $OnSubmit, $OnCancel)
        if ($DefaultValue) {
            $dialog.SetDefaultValue($DefaultValue)
        }
        $dialog.Show()
    }
}

function Show-ProgressDialog {
    param(
        [string]$Title = "Progress",
        [string]$Message = "Processing...",
        [int]$PercentComplete = 0,
        [switch]$ShowCancel
    )
    
    Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowProgressDialog" -ScriptBlock {
        $dialog = [ProgressDialog]::new($Title, $Message)
        $dialog.PercentComplete = $PercentComplete
        $dialog.ShowCancel = $ShowCancel
        $dialog.Show()
        return $dialog
    }
}

function Show-ListDialog {
    param(
        [string]$Title = "Select Item",
        [string]$Prompt = "Choose an item:",
        [string[]]$Items,
        [scriptblock]$OnSelect,
        [scriptblock]$OnCancel = {},
        [switch]$AllowMultiple
    )
    
    Invoke-WithErrorHandling -Component "DialogSystem" -Context "ShowListDialog" -ScriptBlock {
        $dialog = [ListDialog]::new($Title, $Prompt, $Items, $OnSelect, $OnCancel)
        $dialog.AllowMultiple = $AllowMultiple
        $dialog.Show()
    }
}

function Close-TuiDialog {
    Invoke-WithErrorHandling -Component "DialogSystem" -Context "CloseDialog" -ScriptBlock {
        if ($script:DialogState.CurrentDialog) {
            $script:DialogState.CurrentDialog.Close()
        }
    }
}

Export-ModuleMember -Function @(
    'Initialize-DialogSystem',
    'Show-AlertDialog',
    'Show-ConfirmDialog', 
    'Show-InputDialog',
    'Show-ProgressDialog',
    'Show-ListDialog',
    'Close-TuiDialog'
) -Variable @()