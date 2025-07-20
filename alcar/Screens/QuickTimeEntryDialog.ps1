# QuickTimeEntryDialog - Fast time entry for common scenarios
# Minimal UI for quick logging

class QuickTimeEntryDialog : Dialog {
    [array]$Projects
    [object]$ProjectCombo
    [object]$HoursCombo
    [object]$DescriptionInput
    
    QuickTimeEntryDialog([string]$title) : base($title) {
        $this.Width = 50
        $this.Height = 12
        $this.InitializeComponents()
        $this.BindKeys()
    }
    
    [void] InitializeComponents() {
        $y = 3
        
        # Project selection
        $this.AddLabel("Project:", 2, $y)
        $this.ProjectCombo = [ComboBox]::new("ProjectCombo")
        $this.ProjectCombo.X = 12
        $this.ProjectCombo.Y = $y
        $this.ProjectCombo.Width = 32
        $this.ProjectCombo.IsFocusable = $true
        $this.AddChild($this.ProjectCombo)
        $y += 2
        
        # Hours (common values only)
        $this.AddLabel("Hours:", 2, $y)
        $this.HoursCombo = [ComboBox]::new("HoursCombo")
        $this.HoursCombo.X = 12
        $this.HoursCombo.Y = $y
        $this.HoursCombo.Width = 15
        $this.HoursCombo.IsFocusable = $true
        # Common quick increments
        $this.HoursCombo.AddItem("0.25 (15 min)")
        $this.HoursCombo.AddItem("0.5 (30 min)")
        $this.HoursCombo.AddItem("1.0 (1 hour)")
        $this.HoursCombo.AddItem("2.0 (2 hours)")
        $this.HoursCombo.AddItem("4.0 (half day)")
        $this.HoursCombo.AddItem("8.0 (full day)")
        $this.HoursCombo.SelectedIndex = 2  # Default to 1 hour
        $this.AddChild($this.HoursCombo)
        $y += 2
        
        # Description
        $this.AddLabel("Task:", 2, $y)
        $this.DescriptionInput = [TextBox]::new("DescriptionInput")
        $this.DescriptionInput.X = 12
        $this.DescriptionInput.Y = $y
        $this.DescriptionInput.Width = 32
        $this.DescriptionInput.IsFocusable = $true
        $this.AddChild($this.DescriptionInput)
        $y += 3
        
        # Buttons
        $this.OkButton = [Button]::new("Log Time")
        $this.OkButton.X = 10
        $this.OkButton.Y = $y
        $this.OkButton.Width = 12
        $this.OkButton.IsFocusable = $true
        $this.OkButton.OnClick = { $this.OnOK() }
        $this.AddChild($this.OkButton)
        
        $this.CancelButton = [Button]::new("Cancel")
        $this.CancelButton.X = 26
        $this.CancelButton.Y = $y
        $this.CancelButton.Width = 10
        $this.CancelButton.IsFocusable = $true
        $this.CancelButton.OnClick = { $this.OnCancel() }
        $this.AddChild($this.CancelButton)
        
        # Set initial focus
        $this.SetFocus($this.ProjectCombo)
    }
    
    [void] BindKeys() {
        # Tab navigation
        $this.BindKey([ConsoleKey]::Tab, { $this.FocusNext() })
        $this.BindKey([ConsoleKey]::Tab, { $this.FocusPrevious() }, [ConsoleModifiers]::Shift)
        
        # Enter to confirm
        $this.BindKey([ConsoleKey]::Enter, { $this.OnOK() })
        
        # Escape to cancel
        $this.BindKey([ConsoleKey]::Escape, { $this.OnCancel() })
        
        # Quick hour selection with number keys
        $this.BindKey([ConsoleKey]::D1, { $this.HoursCombo.SelectedIndex = 0 })  # 0.25
        $this.BindKey([ConsoleKey]::D2, { $this.HoursCombo.SelectedIndex = 1 })  # 0.5
        $this.BindKey([ConsoleKey]::D3, { $this.HoursCombo.SelectedIndex = 2 })  # 1.0
        $this.BindKey([ConsoleKey]::D4, { $this.HoursCombo.SelectedIndex = 3 })  # 2.0
        $this.BindKey([ConsoleKey]::D5, { $this.HoursCombo.SelectedIndex = 4 })  # 4.0
        $this.BindKey([ConsoleKey]::D6, { $this.HoursCombo.SelectedIndex = 5 })  # 8.0
    }
    
    [object] OnOK() {
        # Validate inputs
        if ($this.ProjectCombo.SelectedIndex -eq -1) {
            $this.ShowMessage("Please select a project")
            return $null
        }
        
        if ([string]::IsNullOrWhiteSpace($this.DescriptionInput.Text)) {
            $this.ShowMessage("Please enter a task description")
            return $null
        }
        
        # Get selected project
        $selectedProject = $this.Projects[$this.ProjectCombo.SelectedIndex]
        
        # Parse hours from combo selection
        $hoursValues = @(0.25, 0.5, 1.0, 2.0, 4.0, 8.0)
        $selectedHours = $hoursValues[$this.HoursCombo.SelectedIndex]
        
        # Create result
        $result = @{
            ProjectID = $selectedProject.ID
            Hours = $selectedHours
            Description = $this.DescriptionInput.Text.Trim()
        }
        
        $this.Result = $result
        $this.RequestClose()
        return $result
    }
    
    [void] OnCancel() {
        $this.Result = $null
        $this.RequestClose()
    }
    
    [void] OnShow() {
        # Load projects
        $this.ProjectCombo.Clear()
        
        foreach ($project in $this.Projects) {
            $this.ProjectCombo.AddItem("$($project.Name)")
        }
        
        if ($this.Projects.Count -gt 0) {
            $this.ProjectCombo.SelectedIndex = 0
        }
        
        ([Dialog]$this).OnShow()
    }
    
    [string] Render() {
        $output = ([Dialog]$this).Render()
        
        # Add helpful hints
        $output += [VT]::MoveTo($this.X + 2, $this.Y + $this.Height - 2)
        $output += [VT]::TextDim() + "Tip: Use 1-6 keys for quick hour selection" + [VT]::Reset()
        
        return $output
    }
}