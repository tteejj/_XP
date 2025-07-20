# ProjectCreationDialog - Guided project creation based on PMC pattern
# Interactive step-by-step project creation with validation and smart defaults

class ProjectCreationDialog : Screen {
    [object]$ProjectService
    [hashtable]$ProjectData = @{}
    [int]$CurrentStep = 0
    [string[]]$Steps = @(
        "FullProjectName",
        "Nickname", 
        "ID1",
        "ID2",
        "DateAssigned",
        "BFDate",
        "Note",
        "CAAPath",
        "RequestPath",
        "T2020Path",
        "Confirm"
    )
    [bool]$Completed = $false
    [bool]$Cancelled = $false
    
    ProjectCreationDialog([object]$projectService) {
        $this.Title = "Create New Project"
        $this.ProjectService = $projectService
        $this.InitializeDefaults()
    }
    
    [void] InitializeDefaults() {
        $today = [DateTime]::Now.ToString("yyyy-MM-dd")
        $this.ProjectData = @{
            FullProjectName = ""
            Nickname = ""
            ID1 = ""
            ID2 = ""
            DateAssigned = $today
            BFDate = $today
            Note = ""
            CAAPath = ""
            RequestPath = ""
            T2020Path = ""
        }
    }
    
    [string] PromptWithDefault([string]$promptText, [string]$defaultValue) {
        if ($defaultValue) {
            $input = Read-Host "$promptText (default: $defaultValue)"
        } else {
            $input = Read-Host "$promptText"
        }
        
        if ([string]::IsNullOrWhiteSpace($input) -and $defaultValue) {
            return $defaultValue
        }
        return $input
    }
    
    [string] GetDateInput([string]$promptText, [string]$defaultValue) {
        while ($true) {
            $input = $this.PromptWithDefault($promptText, $defaultValue)
            try {
                $parsedDate = [DateTime]::ParseExact($input, "yyyy-MM-dd", $null)
                return $parsedDate.ToString("yyyy-MM-dd")
            }
            catch {
                [Console]::WriteLine("Invalid date format. Please enter as yyyy-MM-dd.")
            }
        }
        # This line should never be reached, but PowerShell requires it
        return ""
    }
    
    [bool] ValidateNickname([string]$nickname) {
        if ([string]::IsNullOrWhiteSpace($nickname)) {
            return $false
        }
        
        # Check if nickname already exists
        $existing = $this.ProjectService.GetProjectByName($nickname)
        if ($existing) {
            [Console]::WriteLine("Error: Project nickname '$nickname' already exists. Please choose a unique nickname.")
            return $false
        }
        
        return $true
    }
    
    [string] RenderContent() {
        $output = ""
        $output += [VT]::Clear()
        $output += [VT]::MoveTo(1, 1)
        
        # Header
        $output += [VT]::Border() + "╔══════════════════════════════════════════════════════════════════════════════╗" + [VT]::Reset() + "`n"
        $output += [VT]::Border() + "║" + [VT]::Reset()
        $output += [VT]::TextBright() + "                          CREATE NEW PROJECT                                  " + [VT]::Reset()
        $output += [VT]::Border() + "║" + [VT]::Reset() + "`n"
        $output += [VT]::Border() + "╚══════════════════════════════════════════════════════════════════════════════╝" + [VT]::Reset() + "`n`n"
        
        # Instructions
        $output += [VT]::Warning() + "Press Enter to accept default values. Type 'cancel' to abort creation." + [VT]::Reset() + "`n`n"
        
        # Progress indicator
        $output += [VT]::Text() + "Step $($this.CurrentStep + 1) of $($this.Steps.Count): " + [VT]::Reset()
        $currentStepName = $this.Steps[$this.CurrentStep]
        $output += [VT]::Border() + $currentStepName + [VT]::Reset() + "`n`n"
        
        # Show completed fields
        if ($this.CurrentStep -gt 0) {
            $output += [VT]::Accent() + "Completed:" + [VT]::Reset() + "`n"
            for ($i = 0; $i -lt $this.CurrentStep; $i++) {
                $stepName = $this.Steps[$i]
                $value = $this.ProjectData[$stepName]
                if ($value) {
                    $output += "  $stepName" + [VT]::TextDim() + " = " + [VT]::Reset() + "$value`n"
                }
            }
            $output += "`n"
        }
        
        return $output
    }
    
    [void] ProcessInput([string]$input) {
        if ($input.ToLower() -eq "cancel") {
            $this.Cancelled = $true
            return
        }
        
        $currentStepName = $this.Steps[$this.CurrentStep]
        
        switch ($currentStepName) {
            "FullProjectName" {
                $value = $this.PromptWithDefault("Enter full project name", "")
                if ($value.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                if ([string]::IsNullOrWhiteSpace($value)) {
                    [Console]::WriteLine("Full project name is required.")
                    return
                }
                $this.ProjectData.FullProjectName = $value
            }
            
            "Nickname" {
                $value = $this.PromptWithDefault("Enter project nickname (unique)", "")
                if ($value.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                if (-not $this.ValidateNickname($value)) {
                    return
                }
                $this.ProjectData.Nickname = $value
            }
            
            "ID1" {
                $value = $this.PromptWithDefault("Enter ID1", "")
                if ($value.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                $this.ProjectData.ID1 = $value
            }
            
            "ID2" {
                $value = $this.PromptWithDefault("Enter ID2", "")
                if ($value.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                $this.ProjectData.ID2 = $value
            }
            
            "DateAssigned" {
                $value = $this.GetDateInput("Enter Date Assigned (yyyy-MM-dd)", $this.ProjectData.DateAssigned)
                if ($value.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                $this.ProjectData.DateAssigned = $value
            }
            
            "BFDate" {
                $value = $this.GetDateInput("Enter BF Date (yyyy-MM-dd)", $this.ProjectData.BFDate)
                if ($value.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                $this.ProjectData.BFDate = $value
            }
            
            "Note" {
                $value = $this.PromptWithDefault("Enter Note", "")
                if ($value.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                $this.ProjectData.Note = $value
            }
            
            "CAAPath" {
                $value = $this.PromptWithDefault("Enter CAA file path", "")
                if ($value.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                $this.ProjectData.CAAPath = $value
            }
            
            "RequestPath" {
                $value = $this.PromptWithDefault("Enter Request file path", "")
                if ($value.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                $this.ProjectData.RequestPath = $value
            }
            
            "T2020Path" {
                $value = $this.PromptWithDefault("Enter T2020 file path", "")
                if ($value.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                $this.ProjectData.T2020Path = $value
            }
            
            "Confirm" {
                $this.ShowConfirmationSummary()
                $confirm = $this.PromptWithDefault("Create this project? (y/n)", "y")
                if ($confirm.ToLower() -eq "cancel") { $this.Cancelled = $true; return }
                if ($confirm.ToLower() -eq "y" -or $confirm.ToLower() -eq "yes" -or [string]::IsNullOrWhiteSpace($confirm)) {
                    $this.CreateProject()
                    $this.Completed = $true
                } else {
                    $this.Cancelled = $true
                }
                return
            }
        }
        
        $this.CurrentStep++
        if ($this.CurrentStep -ge $this.Steps.Count) {
            $this.CurrentStep = $this.Steps.Count - 1
        }
    }
    
    [void] ShowConfirmationSummary() {
        [Console]::WriteLine("`n" + [VT]::Warning() + "Project Summary:" + [VT]::Reset())
        [Console]::WriteLine("─────────────────────────────────────────")
        
        foreach ($key in $this.ProjectData.Keys) {
            $value = $this.ProjectData[$key]
            if ($value) {
                [Console]::WriteLine("$key" + [VT]::TextDim() + " = " + [VT]::Reset() + "$value")
            }
        }
        
        [Console]::WriteLine("─────────────────────────────────────────")
    }
    
    [void] CreateProject() {
        try {
            # Create new project with enhanced constructor
            $project = [Project]::new($this.ProjectData.FullProjectName, $this.ProjectData.Nickname)
            
            # Set all the PMC fields
            $project.ID1 = $this.ProjectData.ID1
            $project.ID2 = $this.ProjectData.ID2
            $project.DateAssigned = [DateTime]::ParseExact($this.ProjectData.DateAssigned, "yyyy-MM-dd", $null)
            $project.BFDate = [DateTime]::ParseExact($this.ProjectData.BFDate, "yyyy-MM-dd", $null)
            $project.DateDue = $project.DateAssigned.AddDays(42)  # 6 weeks from assigned date
            $project.Note = $this.ProjectData.Note
            $project.CAAPath = $this.ProjectData.CAAPath
            $project.RequestPath = $this.ProjectData.RequestPath
            $project.T2020Path = $this.ProjectData.T2020Path
            
            # Add to service (this will save it)
            $this.ProjectService.AddProject($project)
            
            [Console]::WriteLine("`n" + [VT]::Accent() + "✓ Project '$($project.Nickname)' created successfully!" + [VT]::Reset())
            [Console]::WriteLine([VT]::TextDim() + "Due date: $($project.DateDue.ToString('yyyy-MM-dd'))" + [VT]::Reset())
            [Console]::WriteLine("`nPress any key to continue...")
            [Console]::ReadKey($true) | Out-Null
        }
        catch {
            [Console]::WriteLine("`n" + [VT]::Error() + "Error creating project: $_" + [VT]::Reset())
            [Console]::WriteLine("Press any key to continue...")
            [Console]::ReadKey($true) | Out-Null
        }
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($this.Completed -or $this.Cancelled) {
            return $true  # Exit dialog
        }
        
        if ($key.Key -eq [ConsoleKey]::Escape) {
            $this.Cancelled = $true
            return $true
        }
        
        # Handle step-by-step input
        $this.ProcessInput("")
        
        return $this.Completed -or $this.Cancelled
    }
}