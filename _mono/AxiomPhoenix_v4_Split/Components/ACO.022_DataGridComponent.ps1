# ==============================================================================
# Axiom-Phoenix v4.0 - All Components
# UI components that extend UIElement - full implementations from axiom
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ACO.###" to find specific sections.
# Each section ends with "END_PAGE: ACO.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#

# ===== CLASS: DataGridComponent =====
# Module: data-grid-component
# Dependencies: UIElement, TuiCell
# Purpose: Generic data grid for displaying tabular data with scrolling and selection
class DataGridComponent : UIElement {
    [hashtable[]]$Columns = @()
    [hashtable[]]$Items = @()
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowHeaders = $true
    [string]$HeaderBackgroundColor = "#333333"
    [string]$HeaderForegroundColor = "#FFFFFF"
    [string]$SelectedBackgroundColor = "#0078D4"
    [string]$SelectedForegroundColor = "#FFFFFF"
    [string]$NormalBackgroundColor = "#000000"
    [string]$NormalForegroundColor = "#C0C0C0"
    [scriptblock]$OnSelectionChanged
    
    DataGridComponent([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Width = 60
        $this.Height = 20
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Clear buffer
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        $y = 0
        
        # Render headers if enabled
        if ($this.ShowHeaders -and $this.Columns.Count -gt 0) {
            $x = 0
            foreach ($column in $this.Columns) {
                $header = if ($column.Header) { $column.Header } else { $column.Name }
                $width = if ($column.Width) { $column.Width } else { 10 }
                
                # Truncate header if needed
                if ($header.Length -gt $width) {
                    $header = $header.Substring(0, [Math]::Max(1, $width - 2)) + ".."
                }
                
                # Pad header to column width
                $header = $header.PadRight($width)
                
                Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $header -Style @{
                    FG = $this.HeaderForegroundColor
                    BG = $this.HeaderBackgroundColor
                }
                
                $x += $width + 1  # +1 for separator
            }
            $y++
        }
        
        # Calculate visible items
        $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
        $startIndex = $this.ScrollOffset
        $endIndex = [Math]::Min($this.Items.Count - 1, $startIndex + $visibleHeight - 1)
        
        # Render data rows
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            if ($i -ge $this.Items.Count) { break }
            
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            $x = 0
            foreach ($column in $this.Columns) {
                $value = if ($item.ContainsKey($column.Name)) { $item[$column.Name] } else { "" }
                $width = if ($column.Width) { $column.Width } else { 10 }
                
                # Convert value to string and truncate if needed
                $text = $value.ToString()
                if ($text.Length -gt $width) {
                    $text = $text.Substring(0, [Math]::Max(1, $width - 2)) + ".."
                }
                
                # Pad text to column width
                $text = $text.PadRight($width)
                
                # Set colors based on selection
                $fgColor = if ($isSelected) { $this.SelectedForegroundColor } else { $this.NormalForegroundColor }
                $bgColor = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.NormalBackgroundColor }
                
                Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $text -Style @{
                    FG = $fgColor
                    BG = $bgColor
                }
                
                $x += $width + 1  # +1 for separator
            }
            $y++
        }
        
        $this._needs_redraw = $false
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.Enabled -or -not $this.IsFocused) { return $false }
        
        $handled = $false
        $oldSelectedIndex = $this.SelectedIndex
        
        switch ($key.Key) {
            "UpArrow" {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this._EnsureVisible()
                    $handled = $true
                }
            }
            "DownArrow" {
                if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                    $this.SelectedIndex++
                    $this._EnsureVisible()
                    $handled = $true
                }
            }
            "PageUp" {
                $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $visibleHeight)
                $this._EnsureVisible()
                $handled = $true
            }
            "PageDown" {
                $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $visibleHeight)
                $this._EnsureVisible()
                $handled = $true
            }
            "Home" {
                $this.SelectedIndex = 0
                $this._EnsureVisible()
                $handled = $true
            }
            "End" {
                $this.SelectedIndex = [Math]::Max(0, $this.Items.Count - 1)
                $this._EnsureVisible()
                $handled = $true
            }
        }
        
        # Fire selection changed event if selection changed
        if ($handled -and $oldSelectedIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
            & $this.OnSelectionChanged $this $this.SelectedIndex
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }
    
    hidden [void] _EnsureVisible() {
        if ($this.Items.Count -eq 0) { return }
        
        $visibleHeight = $this.Height - $(if ($this.ShowHeaders) { 1 } else { 0 })
        
        # Scroll up if selected item is above visible area
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        }
        # Scroll down if selected item is below visible area
        elseif ($this.SelectedIndex -gt ($this.ScrollOffset + $visibleHeight - 1)) {
            $this.ScrollOffset = $this.SelectedIndex - $visibleHeight + 1
        }
        
        # Ensure scroll offset is within bounds
        $this.ScrollOffset = [Math]::Max(0, [Math]::Min($this.ScrollOffset, $this.Items.Count - $visibleHeight))
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SetItems([hashtable[]]$items) {
        $this.Items = $items
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this.RequestRedraw()
    }
    
    [void] SetColumns([hashtable[]]$columns) {
        $this.Columns = $columns
        $this.RequestRedraw()
    }
}
#<!-- END_PAGE: ACO.022 -->

#endregion Navigation Components

#region Dialog Result Enum
enum DialogResult {
    None = 0
    OK = 1
    Cancel = 2
    Yes = 3
    No = 4
    Retry = 5
    Abort = 6
}
#endregion

#region Task Management Dialogs

# ===== CLASS: TaskEditPanel =====
# Module: task-dialogs
# Dependencies: Panel, LabelComponent, TextBoxComponent, ButtonComponent
# Purpose: Modal panel for editing task properties
class TaskEditPanel : Panel {
    hidden [PmcTask]$_task
    hidden [bool]$_isNewTask = $false
    hidden [TextBoxComponent]$_titleTextBox
    hidden [TextBoxComponent]$_descriptionTextBox
    hidden [RadioButtonComponent]$_lowPriorityRadio
    hidden [RadioButtonComponent]$_mediumPriorityRadio
    hidden [RadioButtonComponent]$_highPriorityRadio
    hidden [ButtonComponent]$_saveButton
    hidden [ButtonComponent]$_cancelButton
    [DialogResult]$DialogResult = [DialogResult]::None
    [scriptblock]$OnSave
    [scriptblock]$OnCancel
    
    TaskEditPanel([string]$title, [PmcTask]$task) : base("TaskEditPanel") {
        $this._task = $task
        $this._isNewTask = ($null -eq $task)
        $this.Title = $title
        $this.Width = 60
        $this.Height = 16
        $this.HasBorder = $true
        $this.IsFocusable = $true
        
        $this._CreateControls()
        $this._PopulateData()
    }
    
    hidden [void] _CreateControls() {
        $y = 2
        
        # Title label and textbox
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Title:"
        $titleLabel.X = 2
        $titleLabel.Y = $y
        $titleLabel.Width = 10
        $titleLabel.Visible = $true  # Ensure visible
        $this.AddChild($titleLabel)
        
        $this._titleTextBox = [TextBoxComponent]::new("TitleTextBox")
        $this._titleTextBox.X = 2
        $this._titleTextBox.Y = $y + 1
        $this._titleTextBox.Width = $this.Width - 6
        $this._titleTextBox.Height = 1
        $this._titleTextBox.Visible = $true  # Ensure visible
        $this._titleTextBox.Enabled = $true  # Ensure enabled
        $this.AddChild($this._titleTextBox)
        $y += 3
        
        # Description label and textbox
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = 2
        $descLabel.Y = $y
        $descLabel.Width = 15
        $this.AddChild($descLabel)
        
        $this._descriptionTextBox = [TextBoxComponent]::new("DescriptionTextBox")
        $this._descriptionTextBox.X = 2
        $this._descriptionTextBox.Y = $y + 1
        $this._descriptionTextBox.Width = $this.Width - 6
        $this._descriptionTextBox.Height = 3
        $this.AddChild($this._descriptionTextBox)
        $y += 5
        
        # Priority label and radio buttons
        $priorityLabel = [LabelComponent]::new("PriorityLabel")
        $priorityLabel.Text = "Priority:"
        $priorityLabel.X = 2
        $priorityLabel.Y = $y
        $priorityLabel.Width = 10
        $this.AddChild($priorityLabel)
        $y += 1
        
        $this._lowPriorityRadio = [RadioButtonComponent]::new("LowPriorityRadio")
        $this._lowPriorityRadio.Text = "Low"
        $this._lowPriorityRadio.GroupName = "Priority"
        $this._lowPriorityRadio.X = 4
        $this._lowPriorityRadio.Y = $y
        $this.AddChild($this._lowPriorityRadio)
        
        $this._mediumPriorityRadio = [RadioButtonComponent]::new("MediumPriorityRadio")
        $this._mediumPriorityRadio.Text = "Medium"
        $this._mediumPriorityRadio.GroupName = "Priority"
        $this._mediumPriorityRadio.X = 14
        $this._mediumPriorityRadio.Y = $y
        $this.AddChild($this._mediumPriorityRadio)
        
        $this._highPriorityRadio = [RadioButtonComponent]::new("HighPriorityRadio")
        $this._highPriorityRadio.Text = "High"
        $this._highPriorityRadio.GroupName = "Priority"
        $this._highPriorityRadio.X = 28
        $this._highPriorityRadio.Y = $y
        $this.AddChild($this._highPriorityRadio)
        $y += 3
        
        # Buttons
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = "Save"
        $this._saveButton.X = $this.Width - 24
        $this._saveButton.Y = $this.Height - 4
        $this._saveButton.Width = 8
        $this._saveButton.Height = 1
        $thisPanel = $this
        $this._saveButton.OnClick = {
            if ($thisPanel._ValidateInput()) {
                $thisPanel.DialogResult = [DialogResult]::OK
                if ($thisPanel.OnSave) {
                    & $thisPanel.OnSave
                }
            }
        }.GetNewClosure()
        $this.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.X = $this.Width - 14
        $this._cancelButton.Y = $this.Height - 4
        $this._cancelButton.Width = 8
        $this._cancelButton.Height = 1
        $this._cancelButton.OnClick = {
            $thisPanel.DialogResult = [DialogResult]::Cancel
            if ($thisPanel.OnCancel) {
                & $thisPanel.OnCancel
            }
        }.GetNewClosure()
        $this.AddChild($this._cancelButton)
    }
    
    hidden [void] _PopulateData() {
        if ($this._task) {
            $this._titleTextBox.Text = $this._task.Title
            $this._descriptionTextBox.Text = if ($this._task.Description) { $this._task.Description } else { "" }
            
            switch ($this._task.Priority) {
                ([TaskPriority]::Low) { $this._lowPriorityRadio.Selected = $true }
                ([TaskPriority]::High) { $this._highPriorityRadio.Selected = $true }
                default { $this._mediumPriorityRadio.Selected = $true }
            }
        } else {
            $this._mediumPriorityRadio.Selected = $true
        }
    }
    
    hidden [bool] _ValidateInput() {
        if ([string]::IsNullOrWhiteSpace($this._titleTextBox.Text)) {
            return $false
        }
        return $true
    }
    
    [PmcTask] GetTask() {
        $task = if ($this._task) { $this._task } else { [PmcTask]::new() }
        
        $task.Title = $this._titleTextBox.Text.Trim()
        $task.Description = $this._descriptionTextBox.Text.Trim()
        
        if ($this._lowPriorityRadio.Selected) {
            $task.Priority = [TaskPriority]::Low
        } elseif ($this._highPriorityRadio.Selected) {
            $task.Priority = [TaskPriority]::High
        } else {
            $task.Priority = [TaskPriority]::Medium
        }
        
        if ($this._isNewTask) {
            $task.Status = [TaskStatus]::Pending
            $task.Progress = 0
            $task.CreatedAt = [datetime]::Now
        }
        $task.UpdatedAt = [datetime]::Now
        
        return $task
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $this.DialogResult = [DialogResult]::Cancel
                if ($this.OnCancel) {
                    & $this.OnCancel
                }
                return $true
            }
            ([ConsoleKey]::Enter) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Control) {
                    if ($this._ValidateInput()) {
                        $this.DialogResult = [DialogResult]::OK
                        if ($this.OnSave) {
                            & $this.OnSave
                        }
                    }
                    return $true
                }
            }
        }
        return ([Panel]$this).HandleInput($keyInfo)
    }
    
    [void] SetInitialFocus() {
        # Focus the title textbox first
        $focusManager = $global:TuiState.Services.FocusManager
        if ($focusManager) {
            Write-Log -Level Debug -Message "TaskEditPanel.SetInitialFocus: About to set focus to title textbox"
            Write-Log -Level Debug -Message "  - TextBox Name: $($this._titleTextBox.Name)"
            Write-Log -Level Debug -Message "  - TextBox IsFocusable: $($this._titleTextBox.IsFocusable)"
            Write-Log -Level Debug -Message "  - TextBox Enabled: $($this._titleTextBox.Enabled)"
            Write-Log -Level Debug -Message "  - TextBox Visible: $($this._titleTextBox.Visible)"
            $focusManager.SetFocus($this._titleTextBox)
            Write-Log -Level Debug -Message "  - FocusManager.FocusedComponent: $($focusManager.FocusedComponent?.Name)"
            Write-Log -Level Debug -Message "  - TextBox IsFocused: $($this._titleTextBox.IsFocused)"
        } else {
            Write-Log -Level Error -Message "TaskEditPanel.SetInitialFocus: FocusManager is null!"
        }
    }
}

# ===== CLASS: TaskDeleteDialog =====
# Module: task-dialogs  
# Dependencies: Panel, LabelComponent, ButtonComponent
# Purpose: Confirmation dialog for task deletion
class TaskDeleteDialog : Panel {
    hidden [PmcTask]$_task
    hidden [ButtonComponent]$_yesButton
    hidden [ButtonComponent]$_noButton
    [DialogResult]$DialogResult = [DialogResult]::None
    [scriptblock]$OnConfirm
    [scriptblock]$OnCancel
    
    TaskDeleteDialog([PmcTask]$task) : base("TaskDeleteDialog") {
        $this._task = $task
        $this.Title = "Delete Task"
        $this.Width = 50
        $this.Height = 8
        $this.HasBorder = $true
        $this.IsFocusable = $true
        
        $this._CreateControls()
    }
    
    hidden [void] _CreateControls() {
        # Confirmation message
        $messageLabel = [LabelComponent]::new("MessageLabel")
        $messageLabel.Text = "Are you sure you want to delete this task?"
        $messageLabel.X = 2
        $messageLabel.Y = 2
        $messageLabel.Width = $this.Width - 4
        $this.AddChild($messageLabel)
        
        $taskLabel = [LabelComponent]::new("TaskLabel")
        $taskLabel.Text = "Task: $($this._task.Title)"
        $taskLabel.X = 2
        $taskLabel.Y = 3
        $taskLabel.Width = $this.Width - 4
        $taskLabel.ForegroundColor = Get-ThemeColor -ColorName "Warning" -DefaultColor "#FFA500"
        $this.AddChild($taskLabel)
        
        # Buttons
        $thisDialog = $this
        $this._yesButton = [ButtonComponent]::new("YesButton")
        $this._yesButton.Text = "Yes"
        $this._yesButton.X = $this.Width - 24
        $this._yesButton.Y = $this.Height - 3
        $this._yesButton.Width = 8
        $this._yesButton.Height = 1
        $this._yesButton.OnClick = {
            $thisDialog.DialogResult = [DialogResult]::Yes
            if ($thisDialog.OnConfirm) {
                & $thisDialog.OnConfirm
            }
        }.GetNewClosure()
        $this.AddChild($this._yesButton)
        
        $this._noButton = [ButtonComponent]::new("NoButton")
        $this._noButton.Text = "No"
        $this._noButton.X = $this.Width - 14
        $this._noButton.Y = $this.Height - 3
        $this._noButton.Width = 8
        $this._noButton.Height = 1
        $this._noButton.OnClick = {
            $thisDialog.DialogResult = [DialogResult]::No
            if ($thisDialog.OnCancel) {
                & $thisDialog.OnCancel
            }
        }.GetNewClosure()
        $this.AddChild($this._noButton)
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $this.DialogResult = [DialogResult]::No
                if ($this.OnCancel) {
                    & $this.OnCancel
                }
                return $true
            }
            ([ConsoleKey]::Y) {
                $this.DialogResult = [DialogResult]::Yes
                if ($this.OnConfirm) {
                    & $this.OnConfirm
                }
                return $true
            }
            ([ConsoleKey]::N) {
                $this.DialogResult = [DialogResult]::No
                if ($this.OnCancel) {
                    & $this.OnCancel
                }
                return $true
            }
        }
        return ([Panel]$this).HandleInput($keyInfo)
    }
    
    [void] SetInitialFocus() {
        # Focus the No button by default (safer)
        $focusManager = $global:TuiState.Services.FocusManager
        if ($focusManager) {
            $focusManager.SetFocus($this._noButton)
        }
    }
}

# Alias for compatibility
class TaskDialog : TaskEditPanel {
    TaskDialog([string]$title, [PmcTask]$task) : base($title, $task) {}
}

#endregion
