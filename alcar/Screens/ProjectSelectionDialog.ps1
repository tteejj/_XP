# ProjectSelectionDialog - Simple project picker for time tracking filters

class ProjectSelectionDialog : Dialog {
    [array]$Projects
    [object]$ProjectList
    
    ProjectSelectionDialog([string]$title) : base($title) {
        $this.Width = 50
        $this.Height = 20
        $this.InitializeComponents()
        $this.BindKeys()
    }
    
    [void] InitializeComponents() {
        # Project list
        $this.ProjectList = [ListBox]::new("ProjectList")
        $this.ProjectList.X = 2
        $this.ProjectList.Y = 3
        $this.ProjectList.Width = 44
        $this.ProjectList.Height = 12
        $this.ProjectList.HasBorder = $true
        $this.ProjectList.IsFocusable = $true
        $this.ProjectList.ItemFormatter = {
            param($project)
            return "$($project.Name) - $($project.Description)"
        }
        $this.AddChild($this.ProjectList)
        
        # Buttons
        $y = 16
        $this.OkButton = [Button]::new("Select")
        $this.OkButton.X = 12
        $this.OkButton.Y = $y
        $this.OkButton.Width = 10
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
        $this.SetFocus($this.ProjectList)
    }
    
    [void] BindKeys() {
        # Navigation
        $this.BindKey([ConsoleKey]::DownArrow, { $this.ProjectList.NavigateDown() })
        $this.BindKey([ConsoleKey]::UpArrow, { $this.ProjectList.NavigateUp() })
        
        # Tab navigation
        $this.BindKey([ConsoleKey]::Tab, { $this.FocusNext() })
        $this.BindKey([ConsoleKey]::Tab, { $this.FocusPrevious() }, [ConsoleModifiers]::Shift)
        
        # Enter to select
        $this.BindKey([ConsoleKey]::Enter, { $this.OnOK() })
        
        # Escape to cancel
        $this.BindKey([ConsoleKey]::Escape, { $this.OnCancel() })
    }
    
    [object] OnOK() {
        $selectedProject = $this.ProjectList.GetSelectedItem()
        if (-not $selectedProject) {
            $this.ShowMessage("Please select a project")
            return $null
        }
        
        $this.Result = $selectedProject
        $this.RequestClose()
        return $selectedProject
    }
    
    [void] OnCancel() {
        $this.Result = $null
        $this.RequestClose()
    }
    
    [void] OnShow() {
        # Load projects into list
        $this.ProjectList.SetItems($this.Projects)
        ([Dialog]$this).OnShow()
    }
}