####\DialogComponents.ps1
# ==============================================================================
# Axiom-Phoenix v4.0 - Dialog and Popup Components (CORRECTED)
# Contains the CommandPalette, the DialogResult enum, the base Dialog class,
# standard dialogs (Alert, Confirm, Input), and application-specific dialogs.
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#<!-- PAGE: ACO.016 - CommandPalette Class -->
# ===== CLASS: CommandPalette =====
# Module: command-palette
# Dependencies: UIElement, Panel, ListBox, TextBoxComponent
# Purpose: Searchable command interface
class CommandPalette : UIElement {
    hidden [ListBox]$_listBox
    hidden [TextBoxComponent]$_searchBox
    hidden [Panel]$_panel
    hidden [List[object]]$_allActions
    hidden [List[object]]$_filteredActions
    [scriptblock]$OnExecute
    [scriptblock]$OnCancel

    CommandPalette([string]$name) : base($name) {
        # The palette is a container; it should not be focusable.
        # Focus will be managed for the search box and list box inside it.
        $this.IsFocusable = $false # <<< FIX
        $this.Visible = $false
        $this.IsOverlay = $true
        $this.Width = 60
        $this.Height = 20
        
        $this._allActions = [List[object]]::new()
        $this._filteredActions = [List[object]]::new() # Corrected from [List[int]]
        
        $this.Initialize()
    }

    hidden [void] Initialize() {
        # Create main panel with border
        $this._panel = [Panel]::new("CommandPalette_Panel")
        $this._panel.IsFocusable = $false # Ensure panel is not focusable
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
        $this._panel.Title = " Command Palette "
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height
        $this._panel.X = 0
        $this._panel.Y = 0
        $this.AddChild($this._panel)

        # Create search box
        $this._searchBox = [TextBoxComponent]::new("CommandPalette_Search")
        $this._searchBox.X = 2
        $this._searchBox.Y = 1
        $this._searchBox.Width = $this.Width - 4
        $this._searchBox.Height = 3
        $this._searchBox.Placeholder = "Type to search commands..."
        $this._searchBox.IsFocusable = $true # Explicitly ensure it's focusable
        $this._searchBox.Enabled = $true
        $this._searchBox.Visible = $true
        
        # Connect search box to filtering
        $paletteRef = $this
        $this._searchBox.OnChange = { 
            param($sender, $text) 
            $paletteRef.FilterActions($text) 
        }.GetNewClosure()
        $this._panel.AddChild($this._searchBox)

        # Create list box for results
        $this._listBox = [ListBox]::new("CommandPalette_List")
        $this._listBox.X = 2
        $this._listBox.Y = 4
        $this._listBox.Width = $this.Width - 4
        $this._listBox.Height = $this.Height - 6
        $this._listBox.IsFocusable = $true # Explicitly ensure it's focusable
        $this._listBox.Enabled = $true
        $this._listBox.Visible = $true
        $this._panel.AddChild($this._listBox)
    }

    [void] SetActions([object[]]$actionList) {
        Write-Log -Level Debug -Message "CommandPalette.SetActions: Received $($actionList.Count) actions"
        $this._allActions.Clear()
        foreach ($action in $actionList) {
            $this._allActions.Add($action)
        }
        $this.FilterActions("")  # Show all actions initially
        
        # Don't set focus here - let SetInitialFocus handle it
        Write-Log -Level Debug -Message "CommandPalette.SetActions: Actions set, list should be populated"
    }

    [void] FilterActions([string]$searchText) {
        $this._filteredActions.Clear()
        $this._listBox.ClearItems()
        
        $actionsToDisplay = if ([string]::IsNullOrWhiteSpace($searchText)) { 
            $this._allActions 
        } else {
            $searchLower = $searchText.ToLower()
            @($this._allActions | Where-Object {
                $_.Name.ToLower().Contains($searchLower) -or
                ($_.Description -and $_.Description.ToLower().Contains($searchLower)) -or
                ($_.Category -and $_.Category.ToLower().Contains($searchLower))
            })
        }

        foreach ($action in $actionsToDisplay) {
            $this._filteredActions.Add($action)
            $displayText = if ($action.Category) { 
                "[$($action.Category)] $($action.Name)" 
            } else { 
                $action.Name 
            }
            $this._listBox.AddItem("$displayText - $($action.Description)")
        }
        
        if ($this._filteredActions.Count -gt 0) { 
            $this._listBox.SelectedIndex = 0 
        }
        $this.RequestRedraw()
    }

    [void] SetInitialFocus() {
        Write-Log -Level Debug -Message "CommandPalette.SetInitialFocus: Starting"
        
        if ($this._searchBox) {
            # Clear any previous search text
            $this._searchBox.Text = ""
            $this._searchBox.CursorPosition = 0
            
            # Make absolutely sure the search box is ready
            $this._searchBox.IsFocusable = $true
            $this._searchBox.Enabled = $true
            $this._searchBox.Visible = $true
            
            # Force a render to ensure the component is ready
            $this._searchBox.RequestRedraw()
            
            # Use FocusManager to set focus
            $focusManager = $global:TuiState.Services.FocusManager
            if ($focusManager) {
                Write-Log -Level Debug -Message "CommandPalette.SetInitialFocus: FocusManager found, setting focus to search box"
                Write-Log -Level Debug -Message "  SearchBox properties - Name: $($this._searchBox.Name), IsFocusable: $($this._searchBox.IsFocusable), Enabled: $($this._searchBox.Enabled), Visible: $($this._searchBox.Visible)"
                $focusManager.SetFocus($this._searchBox)
                
                # Double-check that focus was set
                if ($focusManager.FocusedComponent -eq $this._searchBox) {
                    Write-Log -Level Debug -Message "  Focus successfully set to search box"
                } else {
                    Write-Log -Level Warning -Message "  Focus was NOT set to search box! Current focus: $($focusManager.FocusedComponent?.Name)"
                }
            } else {
                Write-Log -Level Error -Message "CommandPalette.SetInitialFocus: FocusManager not found!"
            }
        } else {
            Write-Log -Level Error -Message "CommandPalette.SetInitialFocus: _searchBox is null!"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }
        
        # This container handles Escape, Enter, Tab, and delegates arrow keys
        switch ($key.Key) {
            ([ConsoleKey]::Escape) { 
                if ($this.OnCancel) {
                    & $this.OnCancel
                }
                return $true 
            }
            ([ConsoleKey]::Enter) {
                # If focus is on search box, move to list
                if ($global:TuiState.Services.FocusManager.FocusedComponent -eq $this._searchBox -and $this._filteredActions.Count -gt 0) {
                    $global:TuiState.Services.FocusManager.SetFocus($this._listBox)
                    return $true
                }
                # If focus is on list, execute selection
                if ($this._listBox.SelectedIndex -ge 0 -and $this._listBox.SelectedIndex -lt $this._filteredActions.Count) {
                    $selectedAction = $this._filteredActions[$this._listBox.SelectedIndex]
                    if ($selectedAction -and $this.OnExecute) {
                        & $this.OnExecute $this $selectedAction
                    }
                }
                return $true
            }
            ([ConsoleKey]::Tab) {
                # Switch focus between search box and list
                $focusManager = $global:TuiState.Services.FocusManager
                if ($focusManager.FocusedComponent -eq $this._searchBox) {
                    $focusManager.SetFocus($this._listBox)
                } else {
                    $focusManager.SetFocus($this._searchBox)
                }
                return $true
            }
            {$_ -in @([ConsoleKey]::UpArrow, [ConsoleKey]::DownArrow)} {
                # If focus is on search box and there are items, move focus to list
                if ($global:TuiState.Services.FocusManager.FocusedComponent -eq $this._searchBox -and $this._filteredActions.Count -gt 0) {
                    $global:TuiState.Services.FocusManager.SetFocus($this._listBox)
                    # Let the list handle the actual arrow key
                    return $this._listBox.HandleInput($key)
                }
                # Otherwise return false to let the focused component handle it
                return $false
            }
        }
        
        # For any other key, return false to let the focused component handle it
        return $false
    }

    [void] OnFocus() {
        ([UIElement]$this).OnFocus()
        # Set initial focus to search box
        if ($this._searchBox) {
            $this._searchBox.IsFocused = $true
            $this._searchBox.RequestRedraw()
        }
    }

    [void] OnBlur() {
        ([UIElement]$this).OnBlur()
        if ($this._searchBox) {
            $this._searchBox.IsFocused = $false
            $this._searchBox.RequestRedraw()
        }
    }

    [void] Cleanup() {
        if ($this._searchBox) {
            $this._searchBox.Text = ""
            $this._searchBox.CursorPosition = 0
        }
        if ($this._listBox) {
            $this._listBox.ClearItems()
            $this._listBox.SelectedIndex = -1
        }
        $this._allActions.Clear()
        $this._filteredActions.Clear()
    }
}

#<!-- END_PAGE: ACO.016 -->

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

#<!-- PAGE: ACO.017 - Dialog Class -->
# ===== CLASS: Dialog =====
# Module: dialog-system-class
# Dependencies: UIElement, Panel
# Purpose: Base class for modal dialogs
class Dialog : UIElement {
    [string]$Title = ""
    [string]$Message = ""
    hidden [Panel]$_panel
    hidden [object]$Result = $null
    hidden [bool]$_isComplete = $false
    [scriptblock]$OnClose
    [DialogResult]$DialogResult = [DialogResult]::None

    Dialog([string]$name) : base($name) {
        # This component is a container, it should not be focusable itself.
        # Focus will be managed for its children (buttons, input boxes).
        $this.IsFocusable = $false # <<< FIX
        $this.Visible = $false
        $this.IsOverlay = $true
        $this.Width = 50
        $this.Height = 10
        
        $this.InitializeDialog()
    }

    hidden [void] InitializeDialog() {
        $this._panel = [Panel]::new($this.Name + "_Panel")
        $this._panel.HasBorder = $true
        $this._panel.BorderStyle = "Double"
        $this._panel.BorderColor = "#00FFFF"    # FIXED: Use hex string for border
        $this._panel.BackgroundColor = "#000000" # FIXED: Use hex string for background
        $this._panel.Width = $this.Width
        $this._panel.Height = $this.Height
        $this.AddChild($this._panel)
    }

    [void] Show([string]$title, [string]$message) {
        $this.Title = $title
        $this.Message = $message
        $this._panel.Title = " $title "
        $this._isComplete = $false
        $this.Result = $null
        $this.Visible = $true
        $this.RequestRedraw()
    }

    # Renamed from Close to Complete to match guide
    [void] Complete([object]$result) {
        $this.Result = $result
        $this._isComplete = $true
        
        # Call the OnClose scriptblock if provided
        if ($this.OnClose) {
            try { 
                & $this.OnClose $result 
            } catch { 
                # Write-Log -Level Warning -Message "Dialog '$($this.Name)': Error in OnClose callback: $($_.Exception.Message)" 
            }
        }
        
        # Publish a general dialog close event for DialogManager to pick up
        if ($global:TuiState.Services.EventManager) {
            $global:TuiState.Services.EventManager.Publish("Dialog.Completed", @{ Dialog = $this; Result = $result })
        }
        # The DialogManager will then call HideDialog for actual UI removal and focus restoration.
    }

    # Legacy method for compatibility
    [void] Close([object]$result) {
        $this.Complete($result)
    }

    # New method for DialogManager to call to set initial focus within the dialog
    [void] SetInitialFocus() {
        $firstFocusable = $this.Children | Where-Object { $_.IsFocusable -and $_.Visible -and $_.Enabled } | Sort-Object TabIndex, Y, X | Select-Object -First 1
        if ($firstFocusable -and $global:TuiState.Services.FocusManager) {
            $global:TuiState.Services.FocusManager.SetFocus($firstFocusable)
            # Write-Log -Level Debug -Message "Dialog '$($this.Name)': Set initial focus to '$($firstFocusable.Name)'."
        }
    }

    # Update Title on render
    [void] OnRender() {
        # Base Panel's OnRender already draws border and title using ThemeManager colors
        $this._panel.Title = " $this.Title " # Ensure title is updated on panel
        $this._panel.OnRender() # Render the internal panel
    }

    [object] ShowDialog([string]$title, [string]$message) {
        $this.Show($title, $message)
        
        # In a real implementation, this would block until dialog closes
        # For now, return immediately
        return $this.Result
    }
}

#<!-- END_PAGE: ACO.017 -->

#<!-- PAGE: ACO.018 - AlertDialog Class -->
# ===== CLASS: AlertDialog =====
# Module: dialog-system-class
# Dependencies: Dialog, ButtonComponent
# Purpose: Simple message dialog
class AlertDialog : Dialog {
    hidden [ButtonComponent]$_okButton

    AlertDialog([string]$name) : base($name) {
        $this.Height = 8
        $this.InitializeAlert()
    }

    hidden [void] InitializeAlert() {
        # OK button
        $this._okButton = [ButtonComponent]::new($this.Name + "_OK")
        $this._okButton.Text = "OK"
        $this._okButton.Width = 10
        $this._okButton.Height = 3
        $this._okButton.OnClick = {
            $this.Complete($true)
        }.GetNewClosure()
        $this._panel.AddChild($this._okButton)
    }

    [void] Show([string]$title, [string]$message) {
        ([Dialog]$this).Show($title, $message)
        
        # Position OK button
        $this._okButton.X = [Math]::Floor(($this.Width - $this._okButton.Width) / 2)
        $this._okButton.Y = $this.Height - 4
    }

    [void] OnRender() {
        ([Dialog]$this).OnRender()
        
        if ($this.Visible -and $this.Message) {
            # Draw message within the dialog's panel content area
            $panelContentX = $this._panel.ContentX
            $panelContentY = $this._panel.ContentY
            $maxWidth = $this.Width - 4 # Panel width - 2*border - 2*padding

            # Simple word wrap (use Write-TuiText)
            $words = $this.Message -split ' '
            $currentLine = ""
            $currentY = $panelContentY + 1 # Start drawing message below title

            foreach ($word in $words) {
                if (($currentLine + " " + $word).Length -gt $maxWidth) {
                    if ($currentLine) {
                        Write-TuiText -Buffer $this._panel._private_buffer -X $panelContentX -Y $currentY -Text $currentLine -Style @{ FG = Get-ThemeColor("dialog.foreground"); BG = Get-ThemeColor("dialog.background") }
                        $currentY++
                    }
                    $currentLine = $word
                }
                else {
                    $currentLine = if ($currentLine) { "$currentLine $word" } else { $word }
                }
            }
            if ($currentLine) {
                Write-TuiText -Buffer $this._panel._private_buffer -X $panelContentX -Y $currentY -Text $currentLine -Style @{ FG = Get-ThemeColor("dialog.foreground"); BG = Get-ThemeColor("dialog.background") }
            }
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }

        # Let OK button handle input first
        if ($this._okButton.HandleInput($key)) { return $true }
        
        if ($key.Key -eq [ConsoleKey]::Escape -or $key.Key -eq [ConsoleKey]::Enter) {
            $this.Complete($true) # Complete dialog
            return $true
        }
        return $false
    }

    [void] OnEnter() {
        # Set focus to the OK button when dialog appears
        $global:TuiState.Services.FocusManager?.SetFocus($this._okButton)
    }
}

#<!-- END_PAGE: ACO.018 -->

#<!-- PAGE: ACO.019 - ConfirmDialog Class -->
# ===== CLASS: ConfirmDialog =====
# Module: dialog-system-class
# Dependencies: Dialog, ButtonComponent
# Purpose: Yes/No confirmation dialog
class ConfirmDialog : Dialog {
    hidden [ButtonComponent]$_yesButton
    hidden [ButtonComponent]$_noButton
    # Removed manual focus tracking - will use FocusManager instead

    ConfirmDialog([string]$name) : base($name) {
        $this.Height = 8
        $this.InitializeConfirm()
    }

    hidden [void] InitializeConfirm() {
        # Yes button
        $this._yesButton = [ButtonComponent]::new($this.Name + "_Yes")
        $this._yesButton.Text = "Yes"
        $this._yesButton.Width = 10
        $this._yesButton.Height = 3
        $this._yesButton.TabIndex = 1 # Explicitly set tab order
        $this._yesButton.OnClick = {
            $this.Complete($true)
        }.GetNewClosure()
        $this._panel.AddChild($this._yesButton)

        # No button
        $this._noButton = [ButtonComponent]::new($this.Name + "_No")
        $this._noButton.Text = "No"
        $this._noButton.Width = 10
        $this._noButton.Height = 3
        $this._noButton.TabIndex = 2 # Explicitly set tab order
        $this._noButton.OnClick = {
            $this.Complete($false)
        }.GetNewClosure()
        $this._panel.AddChild($this._noButton)
    }

    [void] Show([string]$title, [string]$message) {
        ([Dialog]$this).Show($title, $message)
        
        # Position buttons
        $buttonY = $this.Height - 4
        $totalWidth = $this._yesButton.Width + $this._noButton.Width + 4
        $startX = [Math]::Floor(($this.Width - $totalWidth) / 2)
        
        $this._yesButton.X = $startX
        $this._yesButton.Y = $buttonY
        
        $this._noButton.X = $startX + $this._yesButton.Width + 4
        $this._noButton.Y = $buttonY
        
    }

    [void] OnEnter() {
        # When the dialog is shown, tell the FocusManager to focus the first element (Yes button)
        $global:TuiState.Services.FocusManager?.SetFocus($this._yesButton)
    }

    [void] OnRender() {
        ([Dialog]$this).OnRender()
        
        if ($this.Visible -and $this.Message) {
            # Draw message (same as AlertDialog)
            $panelContentX = $this._panel.ContentX
            $panelContentY = $this._panel.ContentY
            $maxWidth = $this.Width - 4
            
            $words = $this.Message -split ' '
            $currentLine = ""
            $currentY = $panelContentY + 1
            
            foreach ($word in $words) {
                if (($currentLine + " " + $word).Length -gt $maxWidth) {
                    if ($currentLine) {
                        Write-TuiText -Buffer $this._panel._private_buffer -X $panelContentX -Y $currentY -Text $currentLine -Style @{ FG = Get-ThemeColor("dialog.foreground"); BG = Get-ThemeColor("dialog.background") }
                        $currentY++
                    }
                    $currentLine = $word
                }
                else {
                    $currentLine = if ($currentLine) { "$currentLine $word" } else { $word }
                }
            }
            
            if ($currentLine) {
                Write-TuiText -Buffer $this._panel._private_buffer -X $panelContentX -Y $currentY -Text $currentLine -Style @{ FG = Get-ThemeColor("dialog.foreground"); BG = Get-ThemeColor("dialog.background") }
            }
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return $false }

        # Handle Escape to cancel
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Complete($false) # Using new Complete method
            return $true
        }

        # The global input handler will route Tab/Shift+Tab to the FocusManager.
        # Left/Right arrow keys can be used to switch between Yes/No buttons
        if ($key.Key -eq [ConsoleKey]::LeftArrow -or $key.Key -eq [ConsoleKey]::RightArrow) {
            $focusManager = $global:TuiState.Services.FocusManager
            if ($focusManager) {
                # Toggle focus between the two buttons
                if ($focusManager.FocusedComponent -eq $this._yesButton) {
                    $focusManager.SetFocus($this._noButton)
                } else {
                    $focusManager.SetFocus($this._yesButton)
                }
                return $true
            }
        }
        
        # Let the focused child handle the input
        # The FocusManager will have already routed input to the focused button
        return $false
    }
}

#<!-- END_PAGE: ACO.019 -->

#<!-- PAGE: ACO.020 - InputDialog Class -->
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
        
        # Set initial focus using FocusManager
        if ($global:TuiState.Services.FocusManager) {
            $global:TuiState.Services.FocusManager.SetFocus($this._inputBox)
        }
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
        
        # Tab navigation is handled by the main input loop and FocusManager
        # No need to manually handle Tab or manage focus here
        return $false
    }
    
    [void] SetInitialFocus() {
        # Set focus to the input box when dialog appears
        if ($this._inputBox -and $global:TuiState.Services.FocusManager) {
            $global:TuiState.Services.FocusManager.SetFocus($this._inputBox)
        }
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
    
    [void] SetInitialFocus() {
        # Set focus to the title box when dialog appears
        if ($this._titleBox -and $global:TuiState.Services.FocusManager) {
            $global:TuiState.Services.FocusManager.SetFocus($this._titleBox)
        }
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
        # This is a container panel, focus should be on its children
        $this.IsFocusable = $false # <<< FIX
        
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
        $this.AddChild($titleLabel)
        
        $this._titleTextBox = [TextBoxComponent]::new("TitleTextBox")
        $this._titleTextBox.X = 2
        $this._titleTextBox.Y = $y + 1
        $this._titleTextBox.Width = $this.Width - 6
        $this._titleTextBox.Height = 1
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
            $focusManager.SetFocus($this._titleTextBox)
        }
    }
}

#endregion