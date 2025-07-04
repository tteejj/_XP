# ==============================================================================
# Dialog System Class Module v5.0
# Theme-aware, lifecycle-managed dialogs with modern promise-based API
# ==============================================================================

using namespace System.Management.Automation
using namespace System.Threading.Tasks

#region Base Dialog Class

class Dialog : UIElement {
    [string] $Title = "Dialog"
    [string] $Message = ""
    hidden [TaskCompletionSource[object]] $_tcs # For promise-based async result

    Dialog([Parameter(Mandatory)][string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 50
        $this.Height = 10
        $this._tcs = [TaskCompletionSource[object]]::new()
        Write-Verbose "Dialog: Constructor called for '$($this.Name)'"
    }

    [Task[object]] Show() {
        try {
            # Center the dialog on screen
            $this.X = [Math]::Floor(($global:TuiState.BufferWidth - $this.Width) / 2)
            $this.Y = [Math]::Floor(($global:TuiState.BufferHeight - $this.Height) / 4)
            
            # Show as overlay and set focus
            Show-TuiOverlay -Element $this
            Set-ComponentFocus -Component $this
            
            Write-Verbose "Dialog '$($this.Name)': Shown at ($($this.X), $($this.Y))"
            return $this._tcs.Task
        }
        catch {
            Write-Error "Dialog '$($this.Name)': Error showing dialog: $($_.Exception.Message)"
            $this._tcs.TrySetException($_.Exception)
            return $this._tcs.Task
        }
    }

    [void] Close([object]$result, [bool]$wasCancelled = $false) {
        try {
            if ($wasCancelled) {
                $this._tcs.TrySetCanceled()
                Write-Verbose "Dialog '$($this.Name)': Closed with cancellation"
            } else {
                $this._tcs.TrySetResult($result)
                Write-Verbose "Dialog '$($this.Name)': Closed with result: $result"
            }
            
            # The engine will call Cleanup() on this dialog automatically
            Close-TopTuiOverlay
        }
        catch {
            Write-Error "Dialog '$($this.Name)': Error closing dialog: $($_.Exception.Message)"
            $this._tcs.TrySetException($_.Exception)
        }
    }

    [void] OnRender() {
        if (-not $this._private_buffer) { return }
        
        try {
            # Get theme colors
            $bgColor = Get-ThemeColor 'dialog.background' -Fallback (Get-ThemeColor 'Background')
            $borderColor = Get-ThemeColor 'dialog.border' -Fallback (Get-ThemeColor 'Border')
            $titleColor = Get-ThemeColor 'dialog.title' -Fallback (Get-ThemeColor 'Accent')
            
            # Clear buffer and draw dialog
            $this._private_buffer.Clear([TuiCell]::new(' ', $titleColor, $bgColor))
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -Title " $($this.Title) " -BorderStyle "Double" -BorderColor $borderColor -BackgroundColor $bgColor

            # Render message if present
            if (-not [string]::IsNullOrWhiteSpace($this.Message)) {
                $this._RenderMessage()
            }
            
            # Allow subclasses to render their specific content
            $this.RenderDialogContent()
            
            Write-Verbose "Dialog '$($this.Name)': Rendered"
        }
        catch {
            Write-Error "Dialog '$($this.Name)': Error during render: $($_.Exception.Message)"
        }
    }

    hidden [void] _RenderMessage() {
        try {
            $messageColor = Get-ThemeColor 'dialog.message' -Fallback (Get-ThemeColor 'Foreground')
            $bgColor = Get-ThemeColor 'dialog.background' -Fallback (Get-ThemeColor 'Background')
            
            $messageY = 2
            $messageX = 2
            $maxWidth = $this.Width - 4
            
            $wrappedLines = Get-WordWrappedLines -Text $this.Message -MaxWidth $maxWidth
            foreach ($line in $wrappedLines) {
                if ($messageY -ge ($this.Height - 3)) { break }
                Write-TuiText -Buffer $this._private_buffer -X $messageX -Y $messageY -Text $line -ForegroundColor $messageColor -BackgroundColor $bgColor
                $messageY++
            }
        }
        catch {
            Write-Error "Dialog '$($this.Name)': Error rendering message: $($_.Exception.Message)"
        }
    }

    # Virtual method for subclasses to render their specific content
    [void] RenderDialogContent() { 
        # Override in subclasses
    }

    [bool] HandleInput([Parameter(Mandatory)][ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Close($null, $true)
            return $true
        }
        return $false
    }

    [string] ToString() {
        return "Dialog(Name='$($this.Name)', Title='$($this.Title)', Pos=($($this.X),$($this.Y)), Size=$($this.Width)x$($this.Height))"
    }
}

#endregion

#region Specialized Dialogs

class AlertDialog : Dialog {
    AlertDialog([Parameter(Mandatory)][string]$title, [Parameter(Mandatory)][string]$message) : base("AlertDialog") {
        $this.Title = $title
        $this.Message = $message
        $this.Height = 8
        $this.Width = [Math]::Min(70, [Math]::Max(40, $message.Length + 10))
        Write-Verbose "AlertDialog: Created with title '$title'"
    }

    [void] RenderDialogContent() {
        try {
            # Get theme colors for button
            $buttonFg = Get-ThemeColor 'dialog.button.focus.foreground' -Fallback (Get-ThemeColor 'Background')
            $buttonBg = Get-ThemeColor 'dialog.button.focus.background' -Fallback (Get-ThemeColor 'Accent')
            
            $buttonY = $this.Height - 2
            $buttonLabel = " [ OK ] "
            $buttonX = [Math]::Floor(($this.Width - $buttonLabel.Length) / 2)
            
            Write-TuiText -Buffer $this._private_buffer -X $buttonX -Y $buttonY -Text $buttonLabel -ForegroundColor $buttonFg -BackgroundColor $buttonBg
        }
        catch {
            Write-Error "AlertDialog '$($this.Name)': Error rendering content: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([Parameter(Mandatory)][ConsoleKeyInfo]$key) {
        if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            $this.Close($true)
            return $true
        }
        return ([Dialog]$this).HandleInput($key)
    }
}

class ConfirmDialog : Dialog {
    hidden [int] $_selectedButton = 0

    ConfirmDialog([Parameter(Mandatory)][string]$title, [Parameter(Mandatory)][string]$message) : base("ConfirmDialog") {
        $this.Title = $title
        $this.Message = $message
        $this.Height = 8
        $this.Width = [Math]::Min(70, [Math]::Max(50, $message.Length + 10))
        Write-Verbose "ConfirmDialog: Created with title '$title'"
    }

    [void] RenderDialogContent() {
        try {
            # Get theme colors
            $normalFg = Get-ThemeColor 'dialog.button.normal.foreground' -Fallback (Get-ThemeColor 'Foreground')
            $normalBg = Get-ThemeColor 'dialog.button.normal.background' -Fallback (Get-ThemeColor 'Background')
            $focusFg = Get-ThemeColor 'dialog.button.focus.foreground' -Fallback (Get-ThemeColor 'Background')
            $focusBg = Get-ThemeColor 'dialog.button.focus.background' -Fallback (Get-ThemeColor 'Accent')
            
            $buttonY = $this.Height - 3
            $buttons = @("  Yes  ", "  No   ")
            $startX = [Math]::Floor(($this.Width - 24) / 2)
            
            for ($i = 0; $i -lt $buttons.Count; $i++) {
                $isFocused = ($i -eq $this._selectedButton)
                $label = if ($isFocused) { "[ $($buttons[$i].Trim()) ]" } else { $buttons[$i] }
                $fg = if ($isFocused) { $focusFg } else { $normalFg }
                $bg = if ($isFocused) { $focusBg } else { $normalBg }
                
                Write-TuiText -Buffer $this._private_buffer -X ($startX + ($i * 14)) -Y $buttonY -Text $label -ForegroundColor $fg -BackgroundColor $bg
            }
        }
        catch {
            Write-Error "ConfirmDialog '$($this.Name)': Error rendering content: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([Parameter(Mandatory)][ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::LeftArrow), ([ConsoleKey]::RightArrow), ([ConsoleKey]::Tab) {
                $this._selectedButton = ($this._selectedButton + 1) % 2
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Enter) {
                $result = ($this._selectedButton -eq 0) # True for Yes, False for No
                $this.Close($result)
                return $true
            }
        }
        return ([Dialog]$this).HandleInput($key)
    }
}

class InputDialog : Dialog {
    hidden [TextBoxComponent] $_textBox
    
    InputDialog([Parameter(Mandatory)][string]$title, [Parameter(Mandatory)][string]$message, [string]$defaultValue = "") : base("InputDialog") {
        $this.Title = $title
        $this.Message = $message
        $this.Height = 10
        $this.Width = [Math]::Min(70, [Math]::Max(50, $message.Length + 20))
        # Store default value in metadata for use during initialization
        $this.Metadata.DefaultValue = $defaultValue
        Write-Verbose "InputDialog: Created with title '$title'"
    }

    # Create child components during the Initialize lifecycle hook
    [void] OnInitialize() {
        try {
            $this._textBox = New-TuiTextBox -Props @{ 
                Name = 'DialogInput'
                Text = $this.Metadata.DefaultValue
                Width = $this.Width - 4
                Height = 3
                X = 2
                Y = 4
            }
            $this.AddChild($this._textBox)
            Write-Verbose "InputDialog '$($this.Name)': TextBox component initialized"
        }
        catch {
            Write-Error "InputDialog '$($this.Name)': Error initializing: $($_.Exception.Message)"
        }
    }

    [void] OnResize([int]$newWidth, [int]$newHeight) {
        if ($this._textBox) {
            $this._textBox.Move(2, 4)
            $this._textBox.Resize($newWidth - 4, 3)
        }
    }

    [void] RenderDialogContent() {
        try {
            # The textbox is a child, so the base UIElement.Render() will handle it.
            # We just need to render the buttons.
            $normalFg = Get-ThemeColor 'dialog.button.normal.foreground' -Fallback (Get-ThemeColor 'Foreground')
            $focusFg = Get-ThemeColor 'dialog.button.focus.foreground' -Fallback (Get-ThemeColor 'Accent')
            $bgColor = Get-ThemeColor 'dialog.background' -Fallback (Get-ThemeColor 'Background')
            
            $buttonY = $this.Height - 2
            $okLabel = "[ OK ]"
            $cancelLabel = "[ Cancel ]"
            $startX = $this.Width - $okLabel.Length - $cancelLabel.Length - 6
            
            Write-TuiText -Buffer $this._private_buffer -X $startX -Y $buttonY -Text $okLabel -ForegroundColor $focusFg -BackgroundColor $bgColor
            Write-TuiText -Buffer $this._private_buffer -X ($startX + $okLabel.Length + 2) -Y $buttonY -Text $cancelLabel -ForegroundColor $normalFg -BackgroundColor $bgColor
        }
        catch {
            Write-Error "InputDialog '$($this.Name)': Error rendering content: $($_.Exception.Message)"
        }
    }

    [bool] HandleInput([Parameter(Mandatory)][ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter) {
            $result = $this._textBox ? $this._textBox.Text : ""
            $this.Close($result)
            return $true
        }
        
        # Let the textbox handle all other input
        if ($this._textBox -and $this._textBox.HandleInput($key)) {
            return $true
        }
        
        return ([Dialog]$this).HandleInput($key)
    }
}

#endregion

#region Factory Functions (Promise-based API)

function Show-AlertDialog {
    <#
    .SYNOPSIS
    Shows an alert dialog with a message and OK button.
    
    .DESCRIPTION
    Displays a modal alert dialog with the specified title and message.
    Returns a Task that can be awaited for the user's acknowledgment.
    
    .PARAMETER Title
    The title of the alert dialog.
    
    .PARAMETER Message
    The message to display in the dialog.
    
    .EXAMPLE
    $result = Show-AlertDialog -Title "Success" -Message "Operation completed successfully!"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message
    )
    
    try {
        $dialog = [AlertDialog]::new($Title, $Message)
        Write-Verbose "Show-AlertDialog: Created alert dialog '$Title'"
        return $dialog.Show()
    }
    catch {
        Write-Error "Show-AlertDialog: Error creating alert dialog: $($_.Exception.Message)"
        throw
    }
}

function Show-ConfirmDialog {
    <#
    .SYNOPSIS
    Shows a confirmation dialog with Yes/No buttons.
    
    .DESCRIPTION
    Displays a modal confirmation dialog with the specified title and message.
    Returns a Task that resolves to $true for Yes, $false for No.
    
    .PARAMETER Title
    The title of the confirmation dialog.
    
    .PARAMETER Message
    The message to display in the dialog.
    
    .EXAMPLE
    $confirmed = Show-ConfirmDialog -Title "Delete" -Message "Are you sure you want to delete this item?"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message
    )
    
    try {
        $dialog = [ConfirmDialog]::new($Title, $Message)
        Write-Verbose "Show-ConfirmDialog: Created confirm dialog '$Title'"
        return $dialog.Show()
    }
    catch {
        Write-Error "Show-ConfirmDialog: Error creating confirm dialog: $($_.Exception.Message)"
        throw
    }
}

function Show-InputDialog {
    <#
    .SYNOPSIS
    Shows an input dialog for text entry.
    
    .DESCRIPTION
    Displays a modal input dialog with the specified title, message, and optional default value.
    Returns a Task that resolves to the entered text, or null if cancelled.
    
    .PARAMETER Title
    The title of the input dialog.
    
    .PARAMETER Message
    The message to display in the dialog.
    
    .PARAMETER DefaultValue
    The default value to pre-fill in the text box.
    
    .EXAMPLE
    $userInput = Show-InputDialog -Title "Name" -Message "Enter your name:" -DefaultValue "John Doe"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message,
        [string]$DefaultValue = ""
    )
    
    try {
        $dialog = [InputDialog]::new($Title, $Message, $DefaultValue)
        Write-Verbose "Show-InputDialog: Created input dialog '$Title'"
        return $dialog.Show()
    }
    catch {
        Write-Error "Show-InputDialog: Error creating input dialog: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Utility Functions

function Get-WordWrappedLines {
    <#
    .SYNOPSIS
    Wraps text to fit within a specified width.
    
    .DESCRIPTION
    Breaks text into lines that fit within the specified maximum width,
    attempting to break at word boundaries when possible.
    
    .PARAMETER Text
    The text to wrap.
    
    .PARAMETER MaxWidth
    The maximum width for each line.
    
    .EXAMPLE
    $lines = Get-WordWrappedLines -Text "This is a long message that needs to be wrapped" -MaxWidth 20
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][int]$MaxWidth
    )
    
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    
    $lines = @()
    $words = $Text -split '\s+'
    $currentLine = ""
    
    foreach ($word in $words) {
        $testLine = if ($currentLine) { "$currentLine $word" } else { $word }
        
        if ($testLine.Length -le $MaxWidth) {
            $currentLine = $testLine
        } else {
            if ($currentLine) {
                $lines += $currentLine
                $currentLine = $word
            } else {
                # Word is longer than max width, break it
                while ($word.Length -gt $MaxWidth) {
                    $lines += $word.Substring(0, $MaxWidth)
                    $word = $word.Substring($MaxWidth)
                }
                $currentLine = $word
            }
        }
    }
    
    if ($currentLine) {
        $lines += $currentLine
    }
    
    return $lines
}

#endregion

#region Module Exports

# Export public functions
Export-ModuleMember -Function Show-AlertDialog, Show-ConfirmDialog, Show-InputDialog, Get-WordWrappedLines

# Classes are automatically exported in PowerShell 7+
# Dialog, AlertDialog, ConfirmDialog, InputDialog classes are available when module is imported

#endregion
