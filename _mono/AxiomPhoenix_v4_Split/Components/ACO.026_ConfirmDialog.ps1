# ==============================================================================
#
#   Axiom-Phoenix v4.1 - Confirmation Dialog (Component)
#
#   File: Components\ACO.026_ConfirmDialog.ps1
#   Status: NEW & VERIFIED
#
#   DESCRIPTION:
#   This is a standalone dialog for Yes/No confirmations. It inherits from
#   Screen to function as a modal window and fully complies with the new
#   Hybrid Window Manager model.
#
# ==============================================================================

class ConfirmDialog : Screen {
    #region UI Components
    hidden [Panel] $_dialogPanel
    hidden [LabelComponent] $_messageLabel
    hidden [ButtonComponent] $_yesButton
    hidden [ButtonComponent] $_noButton
    #endregion

    #region Public Properties
    [string]$Title = "Confirm"
    [string]$Message = "Are you sure?"
    [scriptblock]$OnConfirm = {}
    #endregion

    ConfirmDialog([object]$serviceContainer) : base("ConfirmDialog", $serviceContainer) {
        $this.IsOverlay = $true
    }

    [void] Initialize() {
        # Dialog Panel
        $dialogWidth = 50; $dialogHeight = 10
        $this._dialogPanel = [Panel]::new("DialogMain")
        $this._dialogPanel.X = [Math]::Floor(($this.Width - $dialogWidth) / 2)
        $this._dialogPanel.Y = [Math]::Floor(($this.Height - $dialogHeight) / 2)
        $this._dialogPanel.Width = $dialogWidth; $this._dialogPanel.Height = $dialogHeight
        $this._dialogPanel.Title = " $($this.Title) "
        $this._dialogPanel.BorderStyle = "Double"
        $this._dialogPanel.IsFocusable = $false
        $this.AddChild($this._dialogPanel)

        # Message Label
        $this._messageLabel = [LabelComponent]::new("MessageLabel")
        $this._messageLabel.X = 2; $this._messageLabel.Y = 2
        $this._messageLabel.Width = $dialogWidth - 4; $this._messageLabel.Height = 3
        $this._messageLabel.Text = $this.Message
        $this._messageLabel.IsFocusable = $false
        $this._dialogPanel.AddChild($this._messageLabel)

        # Yes Button
        $this._yesButton = [ButtonComponent]::new("YesButton")
        $this._yesButton.Text = "Yes"; $this._yesButton.X = 10; $this._yesButton.Y = 6
        $this._yesButton.IsFocusable = $true; $this._yesButton.TabIndex = 0
        $this._yesButton.OnClick = { $this._Confirm() }
        $this._dialogPanel.AddChild($this._yesButton)

        # No Button
        $this._noButton = [ButtonComponent]::new("NoButton")
        $this._noButton.Text = "No"; $this._noButton.X = 30; $this._noButton.Y = 6
        $this._noButton.IsFocusable = $true; $this._noButton.TabIndex = 1
        $this._noButton.OnClick = { $this._Cancel() }
        $this._dialogPanel.AddChild($this._noButton)
    }

    [void] OnEnter() {
        # The base OnEnter will focus the first element (Yes button).
        ([Screen]$this).OnEnter()
        $this.RequestRedraw()
    }

    hidden [void] _Confirm() {
        if ($this.OnConfirm) { & $this.OnConfirm }
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
        # Let the base class handle Tab navigation and routing to focused button FIRST.
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }

        # Add convenient Left/Right arrow key navigation between buttons.
        $focusedChild = $this.GetFocusedChild()
        if ($keyInfo.Key -eq [ConsoleKey]::LeftArrow -or $keyInfo.Key -eq [ConsoleKey]::RightArrow) {
            if ($focusedChild -eq $this._yesButton) { $this.SetChildFocus($this._noButton) }
            else { $this.SetChildFocus($this._yesButton) }
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