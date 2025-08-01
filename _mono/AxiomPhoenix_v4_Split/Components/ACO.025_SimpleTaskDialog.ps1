# ==============================================================================
#
#   Axiom-Phoenix v4.1 - Simple Task Dialog (Component)
#
#   File: Components\ACO.025_SimpleTaskDialog.ps1
#   Status: VERIFIED & CLEANED
#
# ==============================================================================

class SimpleTaskDialog : Screen {
    #region UI Components
    hidden [Panel] $_dialogPanel
    hidden [TextBoxComponent] $_titleBox
    hidden [TextBoxComponent] $_descriptionBox
    hidden [ButtonComponent] $_saveButton
    hidden [ButtonComponent] $_cancelButton
    #endregion

    #region State
    hidden [PmcTask] $_task
    hidden [bool] $_isNewTask
    [scriptblock]$OnSave = {}
    #endregion

    SimpleTaskDialog([object]$serviceContainer, [PmcTask]$existingTask) : base("SimpleTaskDialog", $serviceContainer) {
        $this.IsOverlay = $true # This tells the renderer to treat it as an overlay
        if ($existingTask) {
            $this._task = $existingTask
            $this._isNewTask = $false
        } else {
            $this._task = [PmcTask]::new()
            $this._isNewTask = $true
        }
    }

    [void] Initialize() {
        # Dialog Panel (centered)
        $dialogWidth = 60
        $dialogHeight = 15
        $this._dialogPanel = [Panel]::new("DialogMain")
        $this._dialogPanel.X = [Math]::Floor(($this.Width - $dialogWidth) / 2)
        $this._dialogPanel.Y = [Math]::Floor(($this.Height - $dialogHeight) / 2)
        $this._dialogPanel.Width = $dialogWidth
        $this._dialogPanel.Height = $dialogHeight
        $dialogTitle = " Edit Task "
        if ($this._isNewTask) { $dialogTitle = " New Task " }
        $this._dialogPanel.Title = $dialogTitle
        $this._dialogPanel.BorderStyle = "Double"
        $this._dialogPanel.IsFocusable = $false # Decorative
        $this.AddChild($this._dialogPanel)

        # Title Field
        $this._titleBox = [TextBoxComponent]::new("TitleBox")
        $this._titleBox.X = 2; $this._titleBox.Y = 2
        $this._titleBox.Width = $dialogWidth - 4; $this._titleBox.Height = 3
        $this._titleBox.Text = $this._task.Title
        $this._titleBox.IsFocusable = $true; $this._titleBox.TabIndex = 0
        $this._titleBox.Placeholder = "Enter task title..."
        $this._dialogPanel.AddChild($this._titleBox)

        # Description Field
        $this._descriptionBox = [TextBoxComponent]::new("DescBox")
        $this._descriptionBox.X = 2; $this._descriptionBox.Y = 6
        $this._descriptionBox.Width = $dialogWidth - 4; $this._descriptionBox.Height = 3
        $this._descriptionBox.Text = $this._task.Description
        $this._descriptionBox.IsFocusable = $true; $this._descriptionBox.TabIndex = 1
        $this._descriptionBox.Placeholder = "Enter task description..."
        $this._dialogPanel.AddChild($this._descriptionBox)

        # Save Button
        $this._saveButton = [ButtonComponent]::new("SaveBtn")
        $this._saveButton.Text = "Save"; $this._saveButton.X = 15; $this._saveButton.Y = 10
        $this._saveButton.IsFocusable = $true; $this._saveButton.TabIndex = 2
        $screenRef = $this
        $this._saveButton.OnClick = { $screenRef._SaveTask() }.GetNewClosure()
        $this._dialogPanel.AddChild($this._saveButton)

        # Cancel Button
        $this._cancelButton = [ButtonComponent]::new("CancelBtn")
        $this._cancelButton.Text = "Cancel"; $this._cancelButton.X = 35; $this._cancelButton.Y = 10
        $this._cancelButton.IsFocusable = $true; $this._cancelButton.TabIndex = 3
        $screenRef = $this
        $this._cancelButton.OnClick = { $screenRef._Cancel() }.GetNewClosure()
        $this._dialogPanel.AddChild($this._cancelButton)
    }

    [void] OnEnter() {
        # Base OnEnter will automatically focus the first component by TabIndex.
        ([Screen]$this).OnEnter()
        $this.RequestRedraw()
    }

    hidden [void] _SaveTask() {
        if ([string]::IsNullOrWhiteSpace($this._titleBox.Text)) {
            $this._titleBox.BorderColor = (Get-ThemeColor "palette.error")
            $this.RequestRedraw()
            return
        }
        $this._task.Title = $this._titleBox.Text
        $this._task.Description = $this._descriptionBox.Text
        if ($this.OnSave) { & $this.OnSave $this._task }
        $this._NavigateBack()
    }

    hidden [void] _Cancel() {
        $this._NavigateBack()
    }

    hidden [void] _NavigateBack() {
        $navService = $this.ServiceContainer.GetService("NavigationService")
        if ($navService.CanGoBack()) { $navService.GoBack() }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Let the base class handle Tab navigation and routing to focused components FIRST.
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }

        # Handle screen-level shortcuts if no component handled the key.
        if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            $this._Cancel()
            return $true
        }
        return $false
    }
}