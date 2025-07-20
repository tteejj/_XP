# GuidedTimeEntryDialog - Step-by-step time entry creation
# ID2 -> Date -> Hours workflow

class GuidedTimeEntryDialog : Dialog {
    [int]$Step = 1  # 1=ID2, 2=Date, 3=Hours, 4=Confirm
    [string]$ID2 = ""
    [string]$DateInput = ""
    [string]$HoursInput = ""
    [datetime]$ParsedDate
    [double]$ParsedHours
    [string]$ErrorMessage = ""
    [object]$TimeService
    [object]$ParentScreen
    [object]$NewEntry
    
    GuidedTimeEntryDialog([object]$parent) : base("NEW TIME ENTRY", "") {
        $this.ParentScreen = $parent
        $this.TimeService = [TimeTrackingService]::new()
        $this.DialogWidth = 60
        $this.DialogHeight = 15
        
        # Set default date to today
        $this.DateInput = [datetime]::Today.ToString("MMdd")
        
        $this.BindKeys()
    }
    
    [void] BindKeys() {
        $this.BindKey([ConsoleKey]::Enter, { $this.NextStep() })
        $this.BindKey([ConsoleKey]::Escape, { $this.Cancel() })
        $this.BindKey([ConsoleKey]::Backspace, { $this.DeleteChar() })
        
        # Character input will be handled in HandleInput override
    }
    
    [void] NextStep() {
        $this.ErrorMessage = ""
        
        switch ($this.Step) {
            1 { # Validate ID2
                if ([string]::IsNullOrWhiteSpace($this.ID2)) {
                    $this.ErrorMessage = "ID2 cannot be empty"
                    return
                }
                $this.Step = 2
            }
            2 { # Validate Date
                if ($this.ValidateDate()) {
                    $this.Step = 3
                } else {
                    return
                }
            }
            3 { # Validate Hours
                if ($this.ValidateHours()) {
                    $this.Step = 4
                } else {
                    return
                }
            }
            4 { # Create Entry
                $this.CreateEntry()
            }
        }
        $this.RequestRender()
    }
    
    [bool] ValidateDate() {
        try {
            $currentYear = [datetime]::Now.Year
            
            if ($this.DateInput.Length -eq 4) {
                # MMDD format
                $month = [int]$this.DateInput.Substring(0, 2)
                $day = [int]$this.DateInput.Substring(2, 2)
                $this.ParsedDate = [datetime]::new($currentYear, $month, $day)
            } elseif ($this.DateInput.Length -eq 8) {
                # YYYYMMDD format
                $year = [int]$this.DateInput.Substring(0, 4)
                $month = [int]$this.DateInput.Substring(4, 2)
                $day = [int]$this.DateInput.Substring(6, 2)
                $this.ParsedDate = [datetime]::new($year, $month, $day)
            } else {
                $this.ErrorMessage = "Date must be MMDD or YYYYMMDD format"
                return $false
            }
            return $true
        } catch {
            $this.ErrorMessage = "Invalid date format"
            return $false
        }
    }
    
    [bool] ValidateHours() {
        try {
            $hours = [double]$this.HoursInput
            if ($hours -le 0) {
                $this.ErrorMessage = "Hours must be greater than 0"
                return $false
            }
            
            # Round to nearest 0.25
            $this.ParsedHours = [Math]::Round($hours * 4) / 4
            
            if ($this.ParsedHours -ne $hours) {
                $this.HoursInput = $this.ParsedHours.ToString()
            }
            
            return $true
        } catch {
            $this.ErrorMessage = "Invalid hours format (use decimal like 1.5)"
            return $false
        }
    }
    
    [void] CreateEntry() {
        try {
            $this.NewEntry = [TimeEntry]::new()
            $this.NewEntry.ProjectID = $this.ID2  # Using ProjectID field for ID2
            $this.NewEntry.Date = $this.ParsedDate
            $this.NewEntry.Hours = $this.ParsedHours
            $this.NewEntry.Description = "Time entry for $($this.ID2)"
            $this.NewEntry.Category = "Work"
            
            # Add to service
            $this.TimeService.AddTimeEntry($this.NewEntry)
            
            $this.Result = [DialogResult]::OK
            $this.Close()
        } catch {
            $this.ErrorMessage = "Failed to create entry: $($_.Exception.Message)"
        }
    }
    
    [void] AddChar([char]$char) {
        switch ($this.Step) {
            1 { # ID2 input
                if ($this.ID2.Length -lt 20) {
                    $this.ID2 += $char
                }
            }
            2 { # Date input
                if ($char -match '[0-9]' -and $this.DateInput.Length -lt 8) {
                    $this.DateInput += $char
                }
            }
            3 { # Hours input
                if (($char -match '[0-9]' -or $char -eq '.') -and $this.HoursInput.Length -lt 6) {
                    $this.HoursInput += $char
                }
            }
        }
        $this.RequestRender()
    }
    
    # Override HandleInput to handle character typing
    [void] HandleInput([ConsoleKeyInfo]$key) {
        # Call base implementation first for bound keys
        ([Dialog]$this).HandleInput($key)
        
        # If no binding was found and we have a printable character, handle it
        if ($key.KeyChar -and $key.KeyChar -match '[a-zA-Z0-9.\-_]') {
            $this.AddChar($key.KeyChar)
        }
    }
    
    [void] DeleteChar() {
        switch ($this.Step) {
            1 { 
                if ($this.ID2.Length -gt 0) {
                    $this.ID2 = $this.ID2.Substring(0, $this.ID2.Length - 1)
                }
            }
            2 { 
                if ($this.DateInput.Length -gt 0) {
                    $this.DateInput = $this.DateInput.Substring(0, $this.DateInput.Length - 1)
                }
            }
            3 { 
                if ($this.HoursInput.Length -gt 0) {
                    $this.HoursInput = $this.HoursInput.Substring(0, $this.HoursInput.Length - 1)
                }
            }
        }
        $this.RequestRender()
    }
    
    [void] Cancel() {
        $this.Result = [DialogResult]::Cancel
        $this.Close()
    }
    
    [string] RenderContent() {
        $output = ([Dialog]$this).RenderContent()
        
        # Title and step indicator
        $stepText = "Step $($this.Step) of 4"
        $output += [VT]::MoveTo($this.DialogX + 2, $this.DialogY + 1)
        $output += [VT]::TextDim() + $stepText + [VT]::Reset()
        
        $y = $this.DialogY + 3
        
        # Step 1: ID2
        $id2Color = if ($this.Step -eq 1) { [VT]::TextBright() } else { [VT]::Text() }
        $output += [VT]::MoveTo($this.DialogX + 2, $y)
        $output += $id2Color + "ID2 (Project/Task Code): " + [VT]::Reset()
        
        $output += [VT]::MoveTo($this.DialogX + 25, $y)
        if ($this.Step -eq 1) {
            $output += [VT]::Selected() + $this.ID2 + "█" + [VT]::Reset()
        } else {
            $output += [VT]::Text() + $this.ID2 + [VT]::Reset()
        }
        $y += 2
        
        # Step 2: Date
        $dateColor = if ($this.Step -eq 2) { [VT]::TextBright() } else { [VT]::Text() }
        $output += [VT]::MoveTo($this.DialogX + 2, $y)
        $output += $dateColor + "Date (MMDD/YYYYMMDD): " + [VT]::Reset()
        
        $output += [VT]::MoveTo($this.DialogX + 25, $y)
        if ($this.Step -eq 2) {
            $output += [VT]::Selected() + $this.DateInput + "█" + [VT]::Reset()
        } else {
            $output += [VT]::Text() + $this.DateInput + [VT]::Reset()
        }
        $y += 2
        
        # Step 3: Hours
        $hoursColor = if ($this.Step -eq 3) { [VT]::TextBright() } else { [VT]::Text() }
        $output += [VT]::MoveTo($this.DialogX + 2, $y)
        $output += $hoursColor + "Hours (0.25 increments): " + [VT]::Reset()
        
        $output += [VT]::MoveTo($this.DialogX + 25, $y)
        if ($this.Step -eq 3) {
            $output += [VT]::Selected() + $this.HoursInput + "█" + [VT]::Reset()
        } else {
            $output += [VT]::Text() + $this.HoursInput + [VT]::Reset()
        }
        $y += 2
        
        # Step 4: Confirmation
        if ($this.Step -eq 4) {
            $output += [VT]::MoveTo($this.DialogX + 2, $y)
            $output += [VT]::TextBright() + "Confirm Entry:" + [VT]::Reset()
            $y++
            
            $output += [VT]::MoveTo($this.DialogX + 4, $y)
            $output += [VT]::Text() + "ID2: $($this.ID2)" + [VT]::Reset()
            $y++
            
            $output += [VT]::MoveTo($this.DialogX + 4, $y)
            $output += [VT]::Text() + "Date: $($this.ParsedDate.ToString('yyyy-MM-dd'))" + [VT]::Reset()
            $y++
            
            $output += [VT]::MoveTo($this.DialogX + 4, $y)
            $output += [VT]::Text() + "Hours: $($this.ParsedHours)" + [VT]::Reset()
            $y++
        }
        
        # Error message
        if ($this.ErrorMessage) {
            $output += [VT]::MoveTo($this.DialogX + 2, $this.DialogY + $this.DialogHeight - 4)
            $output += [VT]::Error() + $this.ErrorMessage + [VT]::Reset()
        }
        
        # Instructions
        $instructions = if ($this.Step -eq 4) { "Enter: Create Entry | Esc: Cancel" } else { "Enter: Next | Esc: Cancel" }
        $output += [VT]::MoveTo($this.DialogX + 2, $this.DialogY + $this.DialogHeight - 2)
        $output += [VT]::TextDim() + $instructions + [VT]::Reset()
        
        return $output
    }
}