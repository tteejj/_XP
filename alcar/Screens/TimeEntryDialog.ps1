# TimeEntryDialog - Dialog for creating/editing time entries
# Based on ALCAR dialog patterns with time tracking specifics

class TimeEntryDialog : Dialog {
    [object]$ProjectService
    [object]$ProjectCombo
    [object]$DateInput
    [object]$HoursCombo
    [object]$DescriptionInput
    [object]$CategoryCombo
    [TimeEntry]$Entry
    
    TimeEntryDialog([string]$title) : base($title) {
        $this.Width = 60
        $this.Height = 20
        $this.Entry = [TimeEntry]::new()
        $this.InitializeComponents()
        $this.BindKeys()
    }
    
    [void] InitializeComponents() {
        $y = 3
        
        # Project selection
        $this.AddLabel("Project:", 2, $y)
        $this.ProjectCombo = [ComboBox]::new("ProjectCombo")
        $this.ProjectCombo.X = 15
        $this.ProjectCombo.Y = $y
        $this.ProjectCombo.Width = 40
        $this.ProjectCombo.IsFocusable = $true
        $this.AddChild($this.ProjectCombo)
        $y += 2
        
        # Date input
        $this.AddLabel("Date:", 2, $y)
        $this.DateInput = [DateInput]::new("DateInput")
        $this.DateInput.X = 15
        $this.DateInput.Y = $y
        $this.DateInput.Width = 15
        $this.DateInput.Value = [datetime]::Today
        $this.DateInput.IsFocusable = $true
        $this.AddChild($this.DateInput)
        $y += 2
        
        # Hours selection (15-minute increments)
        $this.AddLabel("Hours:", 2, $y)
        $this.HoursCombo = [ComboBox]::new("HoursCombo")
        $this.HoursCombo.X = 15
        $this.HoursCombo.Y = $y
        $this.HoursCombo.Width = 15
        $this.HoursCombo.IsFocusable = $true
        # Populate with standard increments
        $increments = [TimeEntry]::GetStandardIncrements()
        foreach ($increment in $increments) {
            $this.HoursCombo.AddItem("$($increment.ToString('0.00')) hours")
        }
        $this.HoursCombo.SelectedIndex = 3  # Default to 1.0 hour
        $this.AddChild($this.HoursCombo)
        $y += 2
        
        # Description
        $this.AddLabel("Description:", 2, $y)
        $this.DescriptionInput = [TextBox]::new("DescriptionInput")
        $this.DescriptionInput.X = 15
        $this.DescriptionInput.Y = $y
        $this.DescriptionInput.Width = 40
        $this.DescriptionInput.IsFocusable = $true
        $this.AddChild($this.DescriptionInput)
        $y += 2
        
        # Category
        $this.AddLabel("Category:", 2, $y)
        $this.CategoryCombo = [ComboBox]::new("CategoryCombo")
        $this.CategoryCombo.X = 15
        $this.CategoryCombo.Y = $y
        $this.CategoryCombo.Width = 20
        $this.CategoryCombo.IsFocusable = $true
        # Populate with standard categories
        $categories = [TimeEntry]::GetStandardCategories()
        foreach ($category in $categories) {
            $this.CategoryCombo.AddItem($category)
        }
        $this.CategoryCombo.SelectedIndex = 0  # Default to "Development"
        $this.AddChild($this.CategoryCombo)
        $y += 3
        
        # Buttons
        $this.OkButton = [Button]::new("OK")
        $this.OkButton.X = 15
        $this.OkButton.Y = $y
        $this.OkButton.Width = 10
        $this.OkButton.IsFocusable = $true
        $this.OkButton.OnClick = { $this.OnOK() }
        $this.AddChild($this.OkButton)
        
        $this.CancelButton = [Button]::new("Cancel")
        $this.CancelButton.X = 30
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
    }
    
    [void] LoadProjects() {
        if ($this.ProjectService) {
            $projects = $this.ProjectService.GetAllProjects()
            $this.ProjectCombo.Clear()
            
            foreach ($project in $projects) {
                $this.ProjectCombo.AddItem("$($project.Name) ($($project.ID))")
            }
            
            if ($projects.Count -gt 0) {
                $this.ProjectCombo.SelectedIndex = 0
            }
        }
    }
    
    [void] LoadEntry([TimeEntry]$entry) {
        $this.Entry = $entry
        
        # Set project
        if ($this.ProjectService -and $entry.ProjectID) {
            $projects = $this.ProjectService.GetAllProjects()
            for ($i = 0; $i -lt $projects.Count; $i++) {
                if ($projects[$i].ID -eq $entry.ProjectID) {
                    $this.ProjectCombo.SelectedIndex = $i
                    break
                }
            }
        }
        
        # Set date
        $this.DateInput.Value = $entry.Date
        
        # Set hours
        $increments = [TimeEntry]::GetStandardIncrements()
        for ($i = 0; $i -lt $increments.Count; $i++) {
            if ($increments[$i] -eq $entry.Hours) {
                $this.HoursCombo.SelectedIndex = $i
                break
            }
        }
        
        # Set description
        $this.DescriptionInput.Text = $entry.Description
        
        # Set category
        $categories = [TimeEntry]::GetStandardCategories()
        for ($i = 0; $i -lt $categories.Count; $i++) {
            if ($categories[$i] -eq $entry.Category) {
                $this.CategoryCombo.SelectedIndex = $i
                break
            }
        }
    }
    
    [object] OnOK() {
        # Validate inputs
        if ($this.ProjectCombo.SelectedIndex -eq -1) {
            $this.ShowMessage("Please select a project")
            return $null
        }
        
        if ([string]::IsNullOrWhiteSpace($this.DescriptionInput.Text)) {
            $this.ShowMessage("Please enter a description")
            return $null
        }
        
        # Get selected project
        $projects = $this.ProjectService.GetAllProjects()
        $selectedProject = $projects[$this.ProjectCombo.SelectedIndex]
        
        # Get selected hours
        $increments = [TimeEntry]::GetStandardIncrements()
        $selectedHours = $increments[$this.HoursCombo.SelectedIndex]
        
        # Get selected category
        $categories = [TimeEntry]::GetStandardCategories()
        $selectedCategory = $categories[$this.CategoryCombo.SelectedIndex]
        
        # Create result
        $result = @{
            Date = $this.DateInput.Value
            ProjectID = $selectedProject.ID
            Hours = $selectedHours
            Description = $this.DescriptionInput.Text.Trim()
            Category = $selectedCategory
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
        $this.LoadProjects()
        ([Dialog]$this).OnShow()
    }
}