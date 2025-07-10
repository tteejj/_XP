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

# ===== CLASS: InputDialog =====
# Module: dialog-system-class
# Dependencies: Dialog, TextBoxComponent, ButtonComponent
# Purpose: Text input dialog
class InputDialog : Dialog {
    hidden [TextBoxComponent]$_inputBox
    hidden [ButtonComponent]$_okButton
    hidden [ButtonComponent]$_cancelButton
    hidden [bool]$_focusOnInput = $true
    hidden [int]$_focusIndex = 0  # 0=input, 1=ok, 2=cancel

    InputDialog([string]$name) : base($name) {
        $this.Height = 10
        $this.InitializeInput()
    }

    hidden [void] InitializeInput() {
        # Input box
        $this._inputBox = [TextBoxComponent]::new($this.Name + "_Input")
        $this._inputBox.Width = $this.Width - 4
        $this._inputBox.Height = 3
        $this._inputBox.X = 2
        $this._inputBox.Y = 4
        $this._panel.AddChild($this._inputBox)

        # OK button
        $this._okButton = [ButtonComponent]::new($this.Name + "_OK")
        $this._okButton.Text = "OK"
        $this._okButton.Width = 10
        $this._okButton.Height = 3
        $this._okButton.OnClick = {
            $this.Close($this._inputBox.Text)
        }.GetNewClosure()
        $this._panel.AddChild($this._okButton)

        # Cancel button
        $this._cancelButton = [ButtonComponent]::new($this.Name + "_Cancel")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.Width = 10
        $this._cancelButton.Height = 3
        $this._cancelButton.OnClick = {
            $this.Close($null)
        }.GetNewClosure()
        $this._panel.AddChild($this._cancelButton)
    }

    [void] Show([string]$title, [string]$message, [string]$defaultValue = "") {
        ([Dialog]$this).Show($title, $message)
        
        $this._inputBox.Text = $defaultValue
        $this._inputBox.CursorPosition = $defaultValue.Length
        
        # Position buttons
        $buttonY = $this.Height - 4
        $totalWidth = $this._okButton.Width + $this._cancelButton.Width + 4
        $startX = [Math]::Floor(($this.Width - $totalWidth) / 2)
        
        $this._okButton.X = $startX
        $this._okButton.Y = $buttonY
        
        $this._cancelButton.X = $startX + $this._okButton.Width + 4
        $this._cancelButton.Y = $buttonY
        
        # Set initial focus
        $this._focusIndex = 0
        $this.UpdateFocus()
    }

    hidden [void] UpdateFocus() {
        $this._inputBox.IsFocused = ($this._focusIndex -eq 0)
        $this._okButton.IsFocused = ($this._focusIndex -eq 1)
        $this._cancelButton.IsFocused = ($this._focusIndex -eq 2)
    }

    [void] OnRender() {
        ([Dialog]$this).OnRender()
        
        if ($this.Visible -and $this.Message) {
            # Draw message
            $this._panel._private_buffer.WriteString(2, 2, 
                $this.Message, [ConsoleColor]::White, [ConsoleColor]::Black)
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Close($null)
            return $true
        }
        
        if ($key.Key -eq [ConsoleKey]::Tab) {
            $this._focusIndex = ($this._focusIndex + 1) % 3
            $this.UpdateFocus()
            $this.RequestRedraw()
            return $true
        }
        
        switch ($this._focusIndex) {
            0 { return $this._inputBox.HandleInput($key) }
            1 { return $this._okButton.HandleInput($key) }
            2 { return $this._cancelButton.HandleInput($key) }
        }
        
        return $false
    }
}

# Task Create/Edit Dialog
class TaskDialog : Dialog {
    hidden [TextBoxComponent] $_titleBox
    hidden [MultilineTextBoxComponent] $_descriptionBox
    hidden [ComboBoxComponent] $_statusCombo
    hidden [ComboBoxComponent] $_priorityCombo
    hidden [NumericInputComponent] $_progressInput
    hidden [ButtonComponent] $_saveButton
    hidden [ButtonComponent] $_cancelButton
    hidden [PmcTask] $_task
    hidden [bool] $_isNewTask
    
    TaskDialog([string]$title, [PmcTask]$task) : base($title) {
        $this._task = if ($task) { $task } else { [PmcTask]::new() }
        $this._isNewTask = ($null -eq $task)
        $this.Width = 60
        $this.Height = 20
    }
    
    [void] Initialize() {
        ([Dialog]$this).Initialize()
        
        $contentY = 2
        $labelWidth = 12
        $inputX = $labelWidth + 2
        $inputWidth = $this.ContentWidth - $inputX - 2
        
        # Title
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Title:"
        $titleLabel.X = 2
        $titleLabel.Y = $contentY
        $this._panel.AddChild($titleLabel)
        
        $this._titleBox = [TextBoxComponent]::new("TitleBox")
        $this._titleBox.X = $inputX
        $this._titleBox.Y = $contentY
        $this._titleBox.Width = $inputWidth
        $this._titleBox.Height = 1
        $this._titleBox.Text = $this._task.Title
        $this._panel.AddChild($this._titleBox)
        $contentY += 2
        
        # Description
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = 2
        $descLabel.Y = $contentY
        $this._panel.AddChild($descLabel)
        
        $this._descriptionBox = [MultilineTextBoxComponent]::new("DescBox")
        $this._descriptionBox.X = $inputX
        $this._descriptionBox.Y = $contentY
        $this._descriptionBox.Width = $inputWidth
        $this._descriptionBox.Height = 3
        $this._descriptionBox.Text = $this._task.Description
        $this._panel.AddChild($this._descriptionBox)
        $contentY += 4
        
        # Status
        $statusLabel = [LabelComponent]::new("StatusLabel")
        $statusLabel.Text = "Status:"
        $statusLabel.X = 2
        $statusLabel.Y = $contentY
        $this._panel.AddChild($statusLabel)
        
        $this._statusCombo = [ComboBoxComponent]::new("StatusCombo")
        $this._statusCombo.X = $inputX
        $this._statusCombo.Y = $contentY
        $this._statusCombo.Width = $inputWidth
        $this._statusCombo.Height = 1
        $this._statusCombo.Items = @([TaskStatus]::GetEnumNames())
        $this._statusCombo.SelectedIndex = [Array]::IndexOf($this._statusCombo.Items, $this._task.Status.ToString())
        $this._panel.AddChild($this._statusCombo)
        $contentY += 2
        
        # Priority
        $priorityLabel = [LabelComponent]::new("PriorityLabel")
        $priorityLabel.Text = "Priority:"
        $priorityLabel.X = 2
        $priorityLabel.Y = $contentY
        $this._panel.AddChild($priorityLabel)
        
        $this._priorityCombo = [ComboBoxComponent]::new("PriorityCombo")
        $this._priorityCombo.X = $inputX
        $this._priorityCombo.Y = $contentY
        $this._priorityCombo.Width = $inputWidth
        $this._priorityCombo.Height = 1
        $this._priorityCombo.Items = @([TaskPriority]::GetEnumNames())
        $this._priorityCombo.SelectedIndex = [Array]::IndexOf($this._priorityCombo.Items, $this._task.Priority.ToString())
        $this._panel.AddChild($this._priorityCombo)
        $contentY += 2
        
        # Progress
        $progressLabel = [LabelComponent]::new("ProgressLabel")
        $progressLabel.Text = "Progress %:"
        $progressLabel.X = 2
        $progressLabel.Y = $contentY
        $this._panel.AddChild($progressLabel)
        
        $this._progressInput = [NumericInputComponent]::new("ProgressInput")
        $this._progressInput.X = $inputX
        $this._progressInput.Y = $contentY
        $this._progressInput.Width = 10
        $this._progressInput.Height = 1
        $this._progressInput.MinValue = 0
        $this._progressInput.MaxValue = 100
        $this._progressInput.Value = $this._task.Progress
        $this._panel.AddChild($this._progressInput)
        $contentY += 3
        
        # Buttons
        $buttonY = $this.ContentHeight - 3
        $buttonWidth = 12
        $spacing = 2
        $totalButtonWidth = ($buttonWidth * 2) + $spacing
        $startX = [Math]::Floor(($this.ContentWidth - $totalButtonWidth) / 2)
        
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = "Save"
        $this._saveButton.X = $startX
        $this._saveButton.Y = $buttonY
        $this._saveButton.Width = $buttonWidth
        $this._saveButton.Height = 1
        $thisDialog = $this
        $this._saveButton.OnClick = {
            $thisDialog.DialogResult = [DialogResult]::OK
            $thisDialog.Complete($thisDialog.DialogResult)
        }.GetNewClosure()
        $this._panel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.X = $startX + $buttonWidth + $spacing
        $this._cancelButton.Y = $buttonY
        $this._cancelButton.Width = $buttonWidth
        $this._cancelButton.Height = 1
        $this._cancelButton.OnClick = {
            $thisDialog.DialogResult = [DialogResult]::Cancel
            $thisDialog.Complete($thisDialog.DialogResult)
        }.GetNewClosure()
        $this._panel.AddChild($this._cancelButton)
        
        # Set initial focus
        Set-ComponentFocus -Component $this._titleBox
    }
    
    [PmcTask] GetTask() {
        if ($this.DialogResult -eq [DialogResult]::OK) {
            # Update task with form values
            $this._task.Title = $this._titleBox.Text
            $this._task.Description = $this._descriptionBox.Text
            $this._task.Status = [TaskStatus]::($this._statusCombo.Items[$this._statusCombo.SelectedIndex])
            $this._task.Priority = [TaskPriority]::($this._priorityCombo.Items[$this._priorityCombo.SelectedIndex])
            $this._task.SetProgress($this._progressInput.Value)
            $this._task.UpdatedAt = [DateTime]::Now
        }
        return $this._task
    }
}

# Task Delete Confirmation Dialog
class TaskDeleteDialog : ConfirmDialog { 
    hidden [PmcTask] $_task
    
    TaskDeleteDialog([PmcTask]$task) : base("Confirm Delete", "Are you sure you want to delete this task?") {
        $this._task = $task
    }
    
    [void] Initialize() {
        ([ConfirmDialog]$this).Initialize()
        
        # Add task details to the message
        if ($this._task) {
            $detailsLabel = [LabelComponent]::new("TaskDetails")
            $detailsLabel.Text = "Task: $($this._task.Title)"
            $detailsLabel.X = 2
            $detailsLabel.Y = 4
            $detailsLabel.ForegroundColor = Get-ThemeColor -ColorName "Warning" -DefaultColor "#FFA500"
            $this._panel.AddChild($detailsLabel)
        }
    }
}

#endregion Dialog Components

#region Navigation Components

#<!-- END_PAGE: ACO.020 -->
