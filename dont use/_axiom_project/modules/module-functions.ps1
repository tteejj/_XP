function Get-ErrorHistory {
    [CmdletBinding()]
    param([int]$Count = 25)
    
    $total = $script:ErrorHistory.Count
    if ($Count -ge $total) { return $script:ErrorHistory }
    $start = $total - $Count
    return $script:ErrorHistory.GetRange($start, $Count)
}

function Get-TuiBorderChars {
    param([string]$Style = "Single")
    
    $styles = @{
        Single = @{
            TopLeft = '┌'; TopRight = '┐'; BottomLeft = '└'; BottomRight = '┘'
            Horizontal = '─'; Vertical = '│'
        }
        Double = @{
            TopLeft = '╔'; TopRight = '╗'; BottomLeft = '╚'; BottomRight = '╝'
            Horizontal = '═'; Vertical = '║'
        }
        Rounded = @{
            TopLeft = '╭'; TopRight = '╮'; BottomLeft = '╰'; BottomRight = '╯'
            Horizontal = '─'; Vertical = '│'
        }
        Thick = @{
            TopLeft = '┏'; TopRight = '┓'; BottomLeft = '┗'; BottomRight = '┛'
            Horizontal = '━'; Vertical = '┃'
        }
    }
    
    return $styles[$Style] ?? $styles.Single
}

function Get-EventHandlers {
    <# .SYNOPSIS Gets all registered event handlers #>
    param([Parameter()] [string]$EventName)
    return Invoke-WithErrorHandling -Component "EventSystem.GetEventHandlers" -Context "Getting event handlers for '$EventName'" -ScriptBlock {
        if ($EventName) { return $script:EventHandlers[$EventName] ?? @() }
        else { return $script:EventHandlers }
    }
}

function Get-EventHistory {
    <# .SYNOPSIS Gets the event history #>
    param([Parameter()] [string]$EventName, [Parameter()] [int]$Last = 0)
    return Invoke-WithErrorHandling -Component "EventSystem.GetEventHistory" -Context "Getting event history for '$EventName'" -ScriptBlock {
        $history = $script:EventHistory
        if ($EventName) { $history = $history | Where-Object { $_.EventName -eq $EventName } }
        if ($Last -gt 0) { $history = $history | Select-Object -Last $Last }
        return $history
    }
}

function Remove-ComponentEventHandlers {
    <# .SYNOPSIS Removes all event handlers associated with a specific component #>
    param([Parameter(Mandatory)] [string]$ComponentId)
    Invoke-WithErrorHandling -Component "EventSystem.RemoveComponentEventHandlers" -Context "Removing event handlers for component '$ComponentId'" -ScriptBlock {
        $removedCount = 0
        foreach ($eventName in @($script:EventHandlers.Keys)) {
            $initialCount = $script:EventHandlers[$eventName].Count
            $script:EventHandlers[$eventName] = @($script:EventHandlers[$eventName] | Where-Object { $_.Source -ne $ComponentId })
            $removedCount += $initialCount - $script:EventHandlers[$eventName].Count
            if ($script:EventHandlers[$eventName].Count -eq 0) { $script:EventHandlers.Remove($eventName) }
        }
        Write-Verbose "Removed $removedCount event handlers for component: $ComponentId"
    }
}

function Set-TuiTheme {
    param([Parameter(Mandatory)] [string]$ThemeName)
    Invoke-WithErrorHandling -Component "ThemeManager.SetTheme" -Context "Setting active TUI theme" -AdditionalData @{ ThemeName = $ThemeName } -ScriptBlock {
        if ($script:Themes.ContainsKey($ThemeName)) {
            $script:CurrentTheme = $script:Themes[$ThemeName]
            if ($Host.UI.RawUI) {
                $Host.UI.RawUI.BackgroundColor = $script:CurrentTheme.Colors.Background
                $Host.UI.RawUI.ForegroundColor = $script:CurrentTheme.Colors.Foreground
            }
            Write-Log -Level Debug -Message "Theme set to: $ThemeName"
            Publish-Event -EventName "Theme.Changed" -Data @{ ThemeName = $ThemeName; Theme = $script:CurrentTheme }
        } else {
            Write-Log -Level Warning -Message "Theme not found: $ThemeName"
        }
    }
}

function Get-ThemeColor {
    param([Parameter(Mandatory)] [string]$ColorName, [ConsoleColor]$Default = [ConsoleColor]::Gray)
    try {
        return $script:CurrentTheme.Colors[$ColorName] ?? $Default
    } catch {
        Write-Log -Level Warning -Message "Error in Get-ThemeColor for '$ColorName'. Returning default. Error: $_"
        return $Default
    }
}

function Get-TuiTheme {
    Invoke-WithErrorHandling -Component "ThemeManager.GetTheme" -Context "Retrieving current theme" -ScriptBlock {
        return $script:CurrentTheme
    }
}

function Get-AvailableThemes {
    Invoke-WithErrorHandling -Component "ThemeManager.GetAvailableThemes" -Context "Retrieving available themes" -ScriptBlock {
        return $script:Themes.Keys | Sort-Object
    }
}

function New-TuiTheme {
    param([Parameter(Mandatory)] [string]$Name, [string]$BaseTheme = "Modern", [hashtable]$Colors = @{})
    Invoke-WithErrorHandling -Component "ThemeManager.NewTheme" -Context "Creating new theme" -AdditionalData @{ ThemeName = $Name } -ScriptBlock {
        $newTheme = @{ Name = $Name; Colors = @{} }
        if ($script:Themes.ContainsKey($BaseTheme)) { $newTheme.Colors = $script:Themes[$BaseTheme].Colors.Clone() }
        foreach ($colorKey in $Colors.Keys) { $newTheme.Colors[$colorKey] = $Colors[$colorKey] }
        $script:Themes[$Name] = $newTheme
        Write-Log -Level Info -Message "Created new theme: $Name"
        return $newTheme
    }
}

function New-TuiLabel {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "Label_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $label = [LabelComponent]::new($name)
    
    $label.X = $Props.X ?? $label.X
    $label.Y = $Props.Y ?? $label.Y
    $label.Width = $Props.Width ?? $label.Width
    $label.Height = $Props.Height ?? $label.Height
    $label.Visible = $Props.Visible ?? $label.Visible
    $label.ZIndex = $Props.ZIndex ?? $label.ZIndex
    $label.Text = $Props.Text ?? $label.Text
    $label.ForegroundColor = $Props.ForegroundColor ?? $label.ForegroundColor
    
    return $label
}

function New-TuiButton {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "Button_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $button = [ButtonComponent]::new($name)
    
    $button.X = $Props.X ?? $button.X
    $button.Y = $Props.Y ?? $button.Y
    $button.Width = $Props.Width ?? $button.Width
    $button.Height = $Props.Height ?? $button.Height
    $button.Visible = $Props.Visible ?? $button.Visible
    $button.ZIndex = $Props.ZIndex ?? $button.ZIndex
    $button.Text = $Props.Text ?? $button.Text
    $button.OnClick = $Props.OnClick ?? $button.OnClick
    
    return $button
}

function New-TuiTextBox {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "TextBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $textBox = [TextBoxComponent]::new($name)
    
    $textBox.X = $Props.X ?? $textBox.X
    $textBox.Y = $Props.Y ?? $textBox.Y
    $textBox.Width = $Props.Width ?? $textBox.Width
    $textBox.Height = $Props.Height ?? $textBox.Height
    $textBox.Visible = $Props.Visible ?? $textBox.Visible
    $textBox.ZIndex = $Props.ZIndex ?? $textBox.ZIndex
    $textBox.Text = $Props.Text ?? $textBox.Text
    $textBox.Placeholder = $Props.Placeholder ?? $textBox.Placeholder
    $textBox.MaxLength = $Props.MaxLength ?? $textBox.MaxLength
    $textBox.CursorPosition = $Props.CursorPosition ?? $textBox.CursorPosition
    $textBox.OnChange = $Props.OnChange ?? $textBox.OnChange
    
    return $textBox
}

function New-TuiCheckBox {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "CheckBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $checkBox = [CheckBoxComponent]::new($name)
    
    $checkBox.X = $Props.X ?? $checkBox.X
    $checkBox.Y = $Props.Y ?? $checkBox.Y
    $checkBox.Width = $Props.Width ?? $checkBox.Width
    $checkBox.Height = $Props.Height ?? $checkBox.Height
    $checkBox.Visible = $Props.Visible ?? $checkBox.Visible
    $checkBox.ZIndex = $Props.ZIndex ?? $checkBox.ZIndex
    $checkBox.Text = $Props.Text ?? $checkBox.Text
    $checkBox.Checked = $Props.Checked ?? $checkBox.Checked
    $checkBox.OnChange = $Props.OnChange ?? $checkBox.OnChange
    
    return $checkBox
}

function New-TuiRadioButton {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "RadioButton_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $radioButton = [RadioButtonComponent]::new($name)
    
    $radioButton.X = $Props.X ?? $radioButton.X
    $radioButton.Y = $Props.Y ?? $radioButton.Y
    $radioButton.Width = $Props.Width ?? $radioButton.Width
    $radioButton.Height = $Props.Height ?? $radioButton.Height
    $radioButton.Visible = $Props.Visible ?? $radioButton.Visible
    $radioButton.ZIndex = $Props.ZIndex ?? $radioButton.ZIndex
    $radioButton.Text = $Props.Text ?? $radioButton.Text
    $radioButton.Selected = $Props.Selected ?? $radioButton.Selected
    $radioButton.GroupName = $Props.GroupName ?? $radioButton.GroupName
    $radioButton.OnChange = $Props.OnChange ?? $radioButton.OnChange
    
    return $radioButton
}

function New-TuiTable {
    # AI: REFACTORED - Creates a proper Table instance
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "Table_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $table = [Table]::new($name)
    
    if ($Props.Columns) {
        $table.SetColumns($Props.Columns)
    }
    if ($Props.Data) {
        $table.SetData($Props.Data)
    }

    $table.X = $Props.X ?? $table.X
    $table.Y = $Props.Y ?? $table.Y
    $table.Width = $Props.Width ?? $table.Width
    $table.Height = $Props.Height ?? $table.Height
    $table.ShowBorder = $Props.ShowBorder ?? $table.ShowBorder
    $table.ShowHeader = $Props.ShowHeader ?? $table.ShowHeader
    $table.Visible = $Props.Visible ?? $table.Visible
    
    return $table
}

function New-TuiMultilineTextBox {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "MultilineTextBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $textBox = [MultilineTextBoxComponent]::new($name)
    
    $textBox.X = $Props.X ?? $textBox.X
    $textBox.Y = $Props.Y ?? $textBox.Y
    $textBox.Width = $Props.Width ?? $textBox.Width
    $textBox.Height = $Props.Height ?? $textBox.Height
    $textBox.Visible = $Props.Visible ?? $textBox.Visible
    $textBox.ZIndex = $Props.ZIndex ?? $textBox.ZIndex
    $textBox.Placeholder = $Props.Placeholder ?? $textBox.Placeholder
    $textBox.MaxLines = $Props.MaxLines ?? $textBox.MaxLines
    $textBox.MaxLineLength = $Props.MaxLineLength ?? $textBox.MaxLineLength
    $textBox.WordWrap = $Props.WordWrap ?? $textBox.WordWrap
    $textBox.OnChange = $Props.OnChange ?? $textBox.OnChange
    
    if ($Props.Text) {
        $textBox.SetText($Props.Text)
    }
    
    return $textBox
}

function New-TuiNumericInput {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "NumericInput_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $numericInput = [NumericInputComponent]::new($name)
    
    $numericInput.X = $Props.X ?? $numericInput.X
    $numericInput.Y = $Props.Y ?? $numericInput.Y
    $numericInput.Width = $Props.Width ?? $numericInput.Width
    $numericInput.Height = $Props.Height ?? $numericInput.Height
    $numericInput.Visible = $Props.Visible ?? $numericInput.Visible
    $numericInput.ZIndex = $Props.ZIndex ?? $numericInput.ZIndex
    $numericInput.Value = $Props.Value ?? $numericInput.Value
    $numericInput.Min = $Props.Min ?? $numericInput.Min
    $numericInput.Max = $Props.Max ?? $numericInput.Max
    $numericInput.Step = $Props.Step ?? $numericInput.Step
    $numericInput.DecimalPlaces = $Props.DecimalPlaces ?? $numericInput.DecimalPlaces
    $numericInput.Suffix = $Props.Suffix ?? $numericInput.Suffix
    $numericInput.OnChange = $Props.OnChange ?? $numericInput.OnChange
    
    # Update text value based on initial value
    $numericInput.TextValue = $numericInput.Value.ToString("F$($numericInput.DecimalPlaces)")
    
    return $numericInput
}

function New-TuiDateInput {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "DateInput_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $dateInput = [DateInputComponent]::new($name)
    
    $dateInput.X = $Props.X ?? $dateInput.X
    $dateInput.Y = $Props.Y ?? $dateInput.Y
    $dateInput.Width = $Props.Width ?? $dateInput.Width
    $dateInput.Height = $Props.Height ?? $dateInput.Height
    $dateInput.Visible = $Props.Visible ?? $dateInput.Visible
    $dateInput.ZIndex = $Props.ZIndex ?? $dateInput.ZIndex
    $dateInput.Value = $Props.Value ?? $dateInput.Value
    $dateInput.MinDate = $Props.MinDate ?? $dateInput.MinDate
    $dateInput.MaxDate = $Props.MaxDate ?? $dateInput.MaxDate
    $dateInput.Format = $Props.Format ?? $dateInput.Format
    $dateInput.OnChange = $Props.OnChange ?? $dateInput.OnChange
    
    # Update text value based on initial value
    $dateInput.TextValue = $dateInput.Value.ToString($dateInput.Format)
    
    return $dateInput
}

function New-TuiComboBox {
    param([hashtable]$Props = @{})
    
    $name = $Props.Name ?? "ComboBox_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    $comboBox = [ComboBoxComponent]::new($name)
    
    $comboBox.X = $Props.X ?? $comboBox.X
    $comboBox.Y = $Props.Y ?? $comboBox.Y
    $comboBox.Width = $Props.Width ?? $comboBox.Width
    $comboBox.Height = $Props.Height ?? $comboBox.Height
    $comboBox.Visible = $Props.Visible ?? $comboBox.Visible
    $comboBox.ZIndex = $Props.ZIndex ?? $comboBox.ZIndex
    $comboBox.DisplayMember = $Props.DisplayMember ?? $comboBox.DisplayMember
    $comboBox.ValueMember = $Props.ValueMember ?? $comboBox.ValueMember
    $comboBox.Placeholder = $Props.Placeholder ?? $comboBox.Placeholder
    $comboBox.MaxDropDownHeight = $Props.MaxDropDownHeight ?? $comboBox.MaxDropDownHeight
    $comboBox.OnSelectionChanged = $Props.OnSelectionChanged ?? $comboBox.OnSelectionChanged
    
    if ($Props.Items) {
        $comboBox.SetItems($Props.Items)
    }
    
    if ($Props.SelectedItem) {
        $comboBox.SelectedItem = $Props.SelectedItem
    }
    
    return $comboBox
}

function Get-WordWrappedLines {
    param([string]$Text, [int]$MaxWidth)
    $lines = @(); $words = $Text -split '\s+'; $currentLine = ""
    foreach ($word in $words) {
        if ($currentLine.Length -eq 0) { $currentLine = $word } 
        elseif (($currentLine.Length + 1 + $word.Length) -le $MaxWidth) { $currentLine += " " + $word } 
        else { $lines += $currentLine; $currentLine = $word }
    }
    if ($currentLine.Length -gt 0) { $lines += $currentLine }
    return $lines
}

function New-KeybindingService {
    <#
    .SYNOPSIS
    Creates a new instance of the KeybindingService class.
    #>
    [CmdletBinding()]
    param(
        [switch]$EnableChords
    )
    
    if ($EnableChords) {
        return [KeybindingService]::new($true)
    }
    else {
        return [KeybindingService]::new()
    }
}

function Set-ComponentFocus { 
    param([UIElement]$Component)
    if ($Component -and (-not $Component.Enabled)) { return }
    
    $global:TuiState.FocusedComponent?.OnBlur()
    if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.LastFocusedComponent = $Component }
    $global:TuiState.FocusedComponent = $Component
    $Component?.OnFocus()
    
    Request-TuiRefresh 
}

function Get-NextFocusableComponent { 
    param([UIElement]$CurrentComponent, [bool]$Reverse = $false)
    if (-not $global:TuiState.CurrentScreen) { return $null }
    
    $focusableComponents = [System.Collections.Generic.List[UIElement]]::new()
    
    function Find-Focusable([UIElement]$Comp) {
        if ($Comp.IsFocusable -and $Comp.Visible -and $Comp.Enabled) {
            $focusableComponents.Add($Comp)
        }
        foreach ($child in $Comp.Children) { Find-Focusable $child }
    }
    
    Find-Focusable $global:TuiState.CurrentScreen
    
    if ($focusableComponents.Count -eq 0) { return $null }
    
    $sorted = $focusableComponents | Sort-Object { $_.TabIndex * 10000 + $_.Y * 100 + $_.X }
    
    if ($Reverse) { [Array]::Reverse($sorted) }
    
    $currentIndex = [array]::IndexOf($sorted, $CurrentComponent)
    if ($currentIndex -ge 0) { 
        return $sorted[($currentIndex + 1) % $sorted.Count] 
    } else { 
        return $sorted[0] 
    } 
}

function Get-FocusedComponent { return $global:TuiState.FocusedComponent }

function Get-AnsiColorCode { param([ConsoleColor]$Color, [bool]$IsBackground); $map = @{ Black=30;DarkBlue=34;DarkGreen=32;DarkCyan=36;DarkRed=31;DarkMagenta=35;DarkYellow=33;Gray=37;DarkGray=90;Blue=94;Green=92;Cyan=96;Red=91;Magenta=95;Yellow=93;White=97 }; $code = $map[$Color.ToString()]; return $IsBackground ? $code + 10 : $code }

function Get-TuiAsyncResults {
    <# .SYNOPSIS Checks for completed async jobs and returns their results. #>
    param([switch]$RemoveCompleted = $true)
    Invoke-WithErrorHandling -Component "TuiFramework.AsyncResults" -Context "Checking async job results" -ScriptBlock {
        $results = @()
        $completedJobs = $script:TuiAsyncJobs | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') }
        
        foreach ($job in $completedJobs) {
            $results += @{
                JobId = $job.Id; JobName = $job.Name; State = $job.State
                Output = if ($job.State -eq 'Completed') { Receive-Job -Job $job } else { $null }
                Error = if ($job.State -eq 'Failed') { $job.ChildJobs[0].JobStateInfo.Reason } else { $null }
            }
            Write-Log -Level Debug -Message "Async job completed: $($job.Name)" -Data @{ JobId = $job.Id; State = $job.State }
        }
        
        if ($RemoveCompleted -and $completedJobs.Count -gt 0) {
            foreach ($job in $completedJobs) {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                $script:TuiAsyncJobs = $script:TuiAsyncJobs | Where-Object { $_.Id -ne $job.Id }
            }
        }
        return $results
    }
}

function Get-TuiState { return $global:TuiState }

