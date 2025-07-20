# TimesheetExportDialog - Export timesheet data to CSV
# Supports date range selection and output directory

class TimesheetExportDialog : Dialog {
    [object]$StartDateInput
    [object]$EndDateInput
    [object]$OutputDirInput
    [object]$FormatCombo
    [object]$PresetCombo
    
    TimesheetExportDialog([string]$title) : base($title) {
        $this.Width = 60
        $this.Height = 18
        $this.InitializeComponents()
        $this.BindKeys()
    }
    
    [void] InitializeComponents() {
        $y = 3
        
        # Preset ranges
        $this.AddLabel("Quick Range:", 2, $y)
        $this.PresetCombo = [ComboBox]::new("PresetCombo")
        $this.PresetCombo.X = 16
        $this.PresetCombo.Y = $y
        $this.PresetCombo.Width = 25
        $this.PresetCombo.IsFocusable = $true
        $this.PresetCombo.AddItem("Current Week")
        $this.PresetCombo.AddItem("Last Week")
        $this.PresetCombo.AddItem("Current Month")
        $this.PresetCombo.AddItem("Last Month")
        $this.PresetCombo.AddItem("Last 7 Days")
        $this.PresetCombo.AddItem("Last 30 Days")
        $this.PresetCombo.AddItem("Custom Range")
        $this.PresetCombo.SelectedIndex = 0
        $this.PresetCombo.OnSelectionChanged = { $this.OnPresetChanged() }
        $this.AddChild($this.PresetCombo)
        $y += 3
        
        # Start date
        $this.AddLabel("Start Date:", 2, $y)
        $this.StartDateInput = [DateInput]::new("StartDateInput")
        $this.StartDateInput.X = 16
        $this.StartDateInput.Y = $y
        $this.StartDateInput.Width = 15
        $this.StartDateInput.IsFocusable = $true
        $this.AddChild($this.StartDateInput)
        $y += 2
        
        # End date
        $this.AddLabel("End Date:", 2, $y)
        $this.EndDateInput = [DateInput]::new("EndDateInput")
        $this.EndDateInput.X = 16
        $this.EndDateInput.Y = $y
        $this.EndDateInput.Width = 15
        $this.EndDateInput.IsFocusable = $true
        $this.AddChild($this.EndDateInput)
        $y += 3
        
        # Output directory
        $this.AddLabel("Output Dir:", 2, $y)
        $this.OutputDirInput = [TextBox]::new("OutputDirInput")
        $this.OutputDirInput.X = 16
        $this.OutputDirInput.Y = $y
        $this.OutputDirInput.Width = 35
        $this.OutputDirInput.Text = Join-Path $PSScriptRoot "../_ProjectData/exports"
        $this.OutputDirInput.IsFocusable = $true
        $this.AddChild($this.OutputDirInput)
        $y += 2
        
        # Export format
        $this.AddLabel("Format:", 2, $y)
        $this.FormatCombo = [ComboBox]::new("FormatCombo")
        $this.FormatCombo.X = 16
        $this.FormatCombo.Y = $y
        $this.FormatCombo.Width = 20
        $this.FormatCombo.IsFocusable = $true
        $this.FormatCombo.AddItem("CSV (Standard)")
        $this.FormatCombo.AddItem("CSV with Summary")
        $this.FormatCombo.SelectedIndex = 1
        $this.AddChild($this.FormatCombo)
        $y += 3
        
        # Buttons
        $this.OkButton = [Button]::new("Export")
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
        
        # Set initial focus and dates
        $this.SetInitialDates()
        $this.SetFocus($this.PresetCombo)
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
    
    [void] SetInitialDates() {
        # Default to current week
        $now = [datetime]::Now
        $startOfWeek = $now.AddDays(-[int]$now.DayOfWeek)
        $endOfWeek = $startOfWeek.AddDays(6)
        
        $this.StartDateInput.Value = $startOfWeek
        $this.EndDateInput.Value = $endOfWeek
    }
    
    [void] OnPresetChanged() {
        $now = [datetime]::Now
        
        switch ($this.PresetCombo.SelectedIndex) {
            0 { # Current Week
                $startOfWeek = $now.AddDays(-[int]$now.DayOfWeek)
                $this.StartDateInput.Value = $startOfWeek
                $this.EndDateInput.Value = $startOfWeek.AddDays(6)
            }
            1 { # Last Week
                $startOfLastWeek = $now.AddDays(-[int]$now.DayOfWeek - 7)
                $this.StartDateInput.Value = $startOfLastWeek
                $this.EndDateInput.Value = $startOfLastWeek.AddDays(6)
            }
            2 { # Current Month
                $startOfMonth = [datetime]::new($now.Year, $now.Month, 1)
                $this.StartDateInput.Value = $startOfMonth
                $this.EndDateInput.Value = $startOfMonth.AddMonths(1).AddDays(-1)
            }
            3 { # Last Month
                $lastMonth = $now.AddMonths(-1)
                $startOfLastMonth = [datetime]::new($lastMonth.Year, $lastMonth.Month, 1)
                $this.StartDateInput.Value = $startOfLastMonth
                $this.EndDateInput.Value = $startOfLastMonth.AddMonths(1).AddDays(-1)
            }
            4 { # Last 7 Days
                $this.StartDateInput.Value = $now.AddDays(-7)
                $this.EndDateInput.Value = $now
            }
            5 { # Last 30 Days
                $this.StartDateInput.Value = $now.AddDays(-30)
                $this.EndDateInput.Value = $now
            }
            6 { # Custom Range - don't change dates
                # User will set manually
            }
        }
    }
    
    [object] OnOK() {
        # Validate dates
        if ($this.StartDateInput.Value -gt $this.EndDateInput.Value) {
            $this.ShowMessage("Start date must be before end date")
            return $null
        }
        
        # Validate output directory
        $outputDir = $this.OutputDirInput.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($outputDir)) {
            $this.ShowMessage("Please specify output directory")
            return $null
        }
        
        # Create directory if it doesn't exist
        try {
            if (-not (Test-Path $outputDir)) {
                New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            }
        }
        catch {
            $this.ShowMessage("Cannot create output directory: $($_.Exception.Message)")
            return $null
        }
        
        # Create result
        $result = @{
            StartDate = $this.StartDateInput.Value
            EndDate = $this.EndDateInput.Value
            OutputDir = $outputDir
            Format = $this.FormatCombo.SelectedIndex
            IncludeSummary = ($this.FormatCombo.SelectedIndex -eq 1)
        }
        
        $this.Result = $result
        $this.RequestClose()
        return $result
    }
    
    [void] OnCancel() {
        $this.Result = $null
        $this.RequestClose()
    }
    
    [string] Render() {
        $output = ([Dialog]$this).Render()
        
        # Add helpful information
        $dateRange = "$($this.StartDateInput.Value.ToString('yyyy-MM-dd')) to $($this.EndDateInput.Value.ToString('yyyy-MM-dd'))"
        $days = ($this.EndDateInput.Value - $this.StartDateInput.Value).Days + 1
        
        $output += [VT]::MoveTo($this.X + 2, $this.Y + $this.Height - 3)
        $output += [VT]::TextDim() + "Range: $dateRange ($days days)" + [VT]::Reset()
        
        return $output
    }
}