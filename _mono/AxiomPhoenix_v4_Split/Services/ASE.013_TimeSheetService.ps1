# ==============================================================================
# Axiom-Phoenix v4.0 - TimeSheetService
# Time tracking and reporting service
# ==============================================================================

#region TimeSheetService Class

# ===== CLASS: TimeSheetService =====
# Module: time-sheet-service
# Dependencies: DataManager, EventManager (optional)
# Purpose: Manages time tracking, reporting, and aggregation
class TimeSheetService {
    hidden [DataManager]$_dataManager
    hidden [EventManager]$_eventManager
    
    TimeSheetService([DataManager]$dataManager) {
        $this._dataManager = $dataManager
    }
    
    TimeSheetService([DataManager]$dataManager, [EventManager]$eventManager) {
        $this._dataManager = $dataManager
        $this._eventManager = $eventManager
    }
    
    # Get week start date (Monday) for a given date
    [DateTime] GetWeekStartDate([DateTime]$date) {
        $dayOfWeek = [int]$date.DayOfWeek
        if ($dayOfWeek -eq 0) { $dayOfWeek = 7 } # Sunday = 7
        $daysToSubtract = $dayOfWeek - 1
        return $date.Date.AddDays(-$daysToSubtract)
    }
    
    # Get week end date (Sunday) for a given date
    [DateTime] GetWeekEndDate([DateTime]$date) {
        $weekStart = $this.GetWeekStartDate($date)
        return $weekStart.AddDays(6).Date.AddHours(23).AddMinutes(59).AddSeconds(59)
    }
    
    # Generate weekly timesheet report
    [hashtable] GenerateWeeklyReport([DateTime]$weekDate) {
        $weekStart = $this.GetWeekStartDate($weekDate)
        $weekEnd = $this.GetWeekEndDate($weekDate)
        
        # Get all time entries for the week
        $entries = $this._dataManager.GetTimeEntriesByDateRange($weekStart, $weekEnd)
        
        # Initialize report structure
        $report = @{
            WeekStart = $weekStart
            WeekEnd = $weekEnd
            Projects = @{}
            ID1Categories = @{}
            DailyTotals = @{}
            TotalHours = 0
            TotalBillableHours = 0
            Entries = @()
        }
        
        # Initialize daily totals for each day of the week
        for ($i = 0; $i -lt 7; $i++) {
            $date = $weekStart.AddDays($i).ToString("yyyy-MM-dd")
            $report.DailyTotals[$date] = 0
        }
        
        # Process each entry
        foreach ($entry in $entries) {
            $hours = $entry.GetHours()
            $dateKey = $entry.StartTime.ToString("yyyy-MM-dd")
            
            # Add to total hours
            $report.TotalHours += $hours
            
            # Add to billable hours if applicable
            if ($entry.BillingType -eq [BillingType]::Billable) {
                $report.TotalBillableHours += $hours
            }
            
            # Add to daily totals
            if ($report.DailyTotals.ContainsKey($dateKey)) {
                $report.DailyTotals[$dateKey] += $hours
            }
            
            # Handle project-based vs ID1-based entries
            if ($entry.IsProjectEntry()) {
                # Add to project totals
                if (-not $report.Projects.ContainsKey($entry.ProjectKey)) {
                    $project = $this._dataManager.GetProject($entry.ProjectKey)
                    $projectName = if ($project) { $project.Name } else { $entry.ProjectKey }
                    
                    $report.Projects[$entry.ProjectKey] = @{
                        ProjectKey = $entry.ProjectKey
                        ProjectName = $projectName
                        TotalHours = 0
                        BillableHours = 0
                        Tasks = @{}
                    }
                }
                
                # Add hours to project
                $report.Projects[$entry.ProjectKey].TotalHours += $hours
                if ($entry.BillingType -eq [BillingType]::Billable) {
                    $report.Projects[$entry.ProjectKey].BillableHours += $hours
                }
                
                # Add to task totals within project
                if ($entry.TaskId) {
                    if (-not $report.Projects[$entry.ProjectKey].Tasks.ContainsKey($entry.TaskId)) {
                        $task = $this._dataManager.GetTask($entry.TaskId)
                        $taskTitle = if ($task) { $task.Title } else { "Unknown Task" }
                        
                        $report.Projects[$entry.ProjectKey].Tasks[$entry.TaskId] = @{
                            TaskId = $entry.TaskId
                            TaskTitle = $taskTitle
                            TotalHours = 0
                            Entries = @()
                        }
                    }
                    
                    $report.Projects[$entry.ProjectKey].Tasks[$entry.TaskId].TotalHours += $hours
                    $report.Projects[$entry.ProjectKey].Tasks[$entry.TaskId].Entries += $entry
                }
            }
            elseif ($entry.IsID1Entry()) {
                # Add to ID1 category totals
                if (-not $report.ID1Categories.ContainsKey($entry.ID1)) {
                    $billingTypeName = [Enum]::GetName([BillingType], $entry.BillingType)
                    
                    $report.ID1Categories[$entry.ID1] = @{
                        ID1 = $entry.ID1
                        CategoryName = "$($entry.ID1) ($billingTypeName)"
                        TotalHours = 0
                        BillingType = $entry.BillingType
                        Entries = @()
                    }
                }
                
                # Add hours to ID1 category
                $report.ID1Categories[$entry.ID1].TotalHours += $hours
                $report.ID1Categories[$entry.ID1].Entries += $entry
            }
            
            # Add entry to report
            $report.Entries += $entry
        }
        
        return $report
    }
    
    # Generate report data for Table component
    [array] GenerateWeeklyReportTable([DateTime]$weekDate) {
        $report = $this.GenerateWeeklyReport($weekDate)
        $tableData = @()
        
        # Add header row with day names and dates
        $headerRow = @{
            Project = "Project"
            Monday = "Mon " + $report.WeekStart.ToString("MM/dd")
            Tuesday = "Tue " + $report.WeekStart.AddDays(1).ToString("MM/dd")
            Wednesday = "Wed " + $report.WeekStart.AddDays(2).ToString("MM/dd")
            Thursday = "Thu " + $report.WeekStart.AddDays(3).ToString("MM/dd")
            Friday = "Fri " + $report.WeekStart.AddDays(4).ToString("MM/dd")
            Saturday = "Sat " + $report.WeekStart.AddDays(5).ToString("MM/dd")
            Sunday = "Sun " + $report.WeekStart.AddDays(6).ToString("MM/dd")
            Total = "Total"
        }
        
        # Process each project
        foreach ($projectKey in $report.Projects.Keys) {
            $project = $report.Projects[$projectKey]
            
            # Initialize daily hours for this project
            $projectRow = @{
                Project = $project.ProjectName
                Monday = 0
                Tuesday = 0
                Wednesday = 0
                Thursday = 0
                Friday = 0
                Saturday = 0
                Sunday = 0
                Total = $project.TotalHours
            }
            
            # Calculate daily hours for this project
            foreach ($taskData in $project.Tasks.Values) {
                foreach ($entry in $taskData.Entries) {
                    $dayName = $entry.StartTime.DayOfWeek.ToString()
                    $hours = $entry.GetHours()
                    
                    if ($projectRow.ContainsKey($dayName)) {
                        $projectRow[$dayName] += $hours
                    }
                }
            }
            
            # Format hours to 2 decimal places
            foreach ($key in @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday', 'Total')) {
                if ($projectRow[$key] -gt 0) {
                    $projectRow[$key] = "{0:N2}" -f $projectRow[$key]
                } else {
                    $projectRow[$key] = "-"
                }
            }
            
            $tableData += $projectRow
        }
        
        # Process each ID1 category
        foreach ($id1Key in $report.ID1Categories.Keys) {
            $category = $report.ID1Categories[$id1Key]
            
            # Initialize daily hours for this ID1 category
            $categoryRow = @{
                Project = $category.CategoryName
                Monday = 0
                Tuesday = 0
                Wednesday = 0
                Thursday = 0
                Friday = 0
                Saturday = 0
                Sunday = 0
                Total = $category.TotalHours
            }
            
            # Calculate daily hours for this ID1 category
            foreach ($entry in $category.Entries) {
                $dayName = $entry.StartTime.DayOfWeek.ToString()
                $hours = $entry.GetHours()
                
                if ($categoryRow.ContainsKey($dayName)) {
                    $categoryRow[$dayName] += $hours
                }
            }
            
            # Format hours to 2 decimal places
            foreach ($key in @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday', 'Total')) {
                if ($categoryRow[$key] -gt 0) {
                    $categoryRow[$key] = "{0:N2}" -f $categoryRow[$key]
                } else {
                    $categoryRow[$key] = "-"
                }
            }
            
            $tableData += $categoryRow
        }
        
        # Add totals row
        $totalsRow = @{
            Project = "TOTAL"
            Monday = "-"
            Tuesday = "-"
            Wednesday = "-"
            Thursday = "-"
            Friday = "-"
            Saturday = "-"
            Sunday = "-"
            Total = "{0:N2}" -f $report.TotalHours
        }
        
        # Calculate daily totals
        $dayNames = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')
        for ($i = 0; $i -lt 7; $i++) {
            $dateKey = $report.WeekStart.AddDays($i).ToString("yyyy-MM-dd")
            $dayTotal = $report.DailyTotals[$dateKey]
            if ($dayTotal -gt 0) {
                $totalsRow[$dayNames[$i]] = "{0:N2}" -f $dayTotal
            }
        }
        
        $tableData += $totalsRow
        
        return @($headerRow) + $tableData
    }
    
    # Start tracking time for a task
    [TimeEntry] StartTimeTracking([string]$taskId, [string]$projectKey, [string]$description, [string]$userId) {
        # Check if there's already an active time entry
        $activeEntries = $this._dataManager.GetTimeEntries() | Where-Object { $_.IsRunning() }
        if ($activeEntries.Count -gt 0) {
            throw [System.InvalidOperationException]::new("There is already an active time entry. Please stop it before starting a new one.")
        }
        
        $entry = [TimeEntry]::new($taskId, $projectKey, [DateTime]::Now)
        $entry.Description = $description
        $entry.UserId = $userId
        
        $this._dataManager.AddTimeEntry($entry)
        
        if ($this._eventManager) {
            $this._eventManager.Publish("TimeTracking.Started", @{
                TimeEntry = $entry
                ProjectKey = $projectKey
                TaskId = $taskId
            })
        }
        
        return $entry
    }
    
    # Start tracking time for ID1-based (non-project) activity
    [TimeEntry] StartID1TimeTracking([string]$id1, [string]$description, [BillingType]$billingType, [string]$userId) {
        # Check if there's already an active time entry
        $activeEntries = $this._dataManager.GetTimeEntries() | Where-Object { $_.IsRunning() }
        if ($activeEntries.Count -gt 0) {
            throw [System.InvalidOperationException]::new("There is already an active time entry. Please stop it before starting a new one.")
        }
        
        $entry = [TimeEntry]::new($id1, [DateTime]::Now, $description, $billingType)
        $entry.UserId = $userId
        
        $this._dataManager.AddTimeEntry($entry)
        
        if ($this._eventManager) {
            $this._eventManager.Publish("TimeTracking.Started", @{
                TimeEntry = $entry
                ID1 = $id1
                BillingType = $billingType
            })
        }
        
        return $entry
    }
    
    # Stop tracking time
    [TimeEntry] StopTimeTracking([string]$entryId) {
        $entry = $this._dataManager.GetTimeEntry($entryId)
        if ($null -eq $entry) {
            throw [System.InvalidOperationException]::new("Time entry with ID '$entryId' not found")
        }
        
        if (-not $entry.IsRunning()) {
            throw [System.InvalidOperationException]::new("Time entry is not running")
        }
        
        $entry.Stop()
        $this._dataManager.UpdateTimeEntry($entry)
        
        if ($this._eventManager) {
            $this._eventManager.Publish("TimeTracking.Stopped", @{
                TimeEntry = $entry
                Duration = $entry.GetDuration()
                Hours = $entry.GetHours()
            })
        }
        
        return $entry
    }
    
    # Get active time entry
    [TimeEntry] GetActiveTimeEntry() {
        $activeEntries = $this._dataManager.GetTimeEntries() | Where-Object { $_.IsRunning() }
        if ($activeEntries.Count -gt 0) {
            return $activeEntries[0]
        }
        return $null
    }
    
    # Get summary statistics
    [hashtable] GetSummaryStats([DateTime]$startDate, [DateTime]$endDate) {
        $entries = $this._dataManager.GetTimeEntriesByDateRange($startDate, $endDate)
        
        $stats = @{
            TotalEntries = $entries.Count
            TotalHours = 0
            BillableHours = 0
            NonBillableHours = 0
            ProjectCount = 0
            AverageHoursPerDay = 0
            Projects = @{}
        }
        
        foreach ($entry in $entries) {
            $hours = $entry.GetHours()
            $stats.TotalHours += $hours
            
            if ($entry.BillingType -eq [BillingType]::Billable) {
                $stats.BillableHours += $hours
            } else {
                $stats.NonBillableHours += $hours
            }
            
            if (-not $stats.Projects.ContainsKey($entry.ProjectKey)) {
                $stats.Projects[$entry.ProjectKey] = 0
            }
            $stats.Projects[$entry.ProjectKey] += $hours
        }
        
        $stats.ProjectCount = $stats.Projects.Count
        $totalDays = ($endDate - $startDate).TotalDays + 1
        if ($totalDays -gt 0) {
            $stats.AverageHoursPerDay = $stats.TotalHours / $totalDays
        }
        
        return $stats
    }
    
    # Export timesheet data to CSV format
    [string] ExportToCSV([DateTime]$startDate, [DateTime]$endDate, [string]$format = "Standard") {
        $entries = $this._dataManager.GetTimeEntriesByDateRange($startDate, $endDate)
        
        switch ($format) {
            "Standard" {
                $csvData = @()
                $csvData += "Date,Project/ID1,ID2,Task,Hours,Description,BillingType,UserId"
                
                foreach ($entry in $entries) {
                    if ($entry.IsProjectEntry()) {
                        # Project-based entry
                        $project = $this._dataManager.GetProject($entry.ProjectKey)
                        $projectId2 = if ($project) { $project.ID2 } else { $entry.ProjectKey }
                        $projectOrId1 = $entry.ProjectKey
                        
                        $task = if ($entry.TaskId) {
                            $taskObj = $this._dataManager.GetTask($entry.TaskId)
                            if ($taskObj) { $taskObj.Title } else { "Unknown Task" }
                        } else { "" }
                    }
                    elseif ($entry.IsID1Entry()) {
                        # ID1-based entry
                        $projectOrId1 = $entry.ID1
                        $projectId2 = ""
                        $task = ""
                    }
                    else {
                        # Unassigned entry
                        $projectOrId1 = "UNASSIGNED"
                        $projectId2 = ""
                        $task = ""
                    }
                    
                    $dateStr = $entry.StartTime.ToString("yyyy-MM-dd")
                    $hours = "{0:N2}" -f $entry.GetHours()
                    $description = $entry.Description -replace '"', '""'  # Escape quotes
                    
                    $csvData += "$dateStr,$projectOrId1,$projectId2,`"$task`",$hours,`"$description`",$($entry.BillingType),$($entry.UserId)"
                }
                
                return $csvData -join "`n"
            }
            
            "Weekly" {
                $report = $this.GenerateWeeklyReport($startDate)
                $csvData = @()
                $csvData += "Project/ID1,ID2,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday,Total"
                
                # Add project entries
                foreach ($projectKey in $report.Projects.Keys) {
                    $project = $report.Projects[$projectKey]
                    $projectObj = $this._dataManager.GetProject($projectKey)
                    $projectId2 = if ($projectObj) { $projectObj.ID2 } else { $projectKey }
                    
                    # Calculate daily hours for this project
                    $dailyHours = @(0, 0, 0, 0, 0, 0, 0)  # Mon-Sun
                    
                    foreach ($taskData in $project.Tasks.Values) {
                        foreach ($entry in $taskData.Entries) {
                            $dayOfWeek = [int]$entry.StartTime.DayOfWeek
                            if ($dayOfWeek -eq 0) { $dayOfWeek = 7 }  # Sunday = 7
                            $dailyHours[$dayOfWeek - 1] += $entry.GetHours()
                        }
                    }
                    
                    $dailyFormatted = $dailyHours | ForEach-Object { "{0:N2}" -f $_ }
                    $totalFormatted = "{0:N2}" -f $project.TotalHours
                    
                    $csvData += "$($project.ProjectName),$projectId2,$($dailyFormatted -join ','),$totalFormatted"
                }
                
                # Add ID1 category entries
                foreach ($id1Key in $report.ID1Categories.Keys) {
                    $category = $report.ID1Categories[$id1Key]
                    
                    # Calculate daily hours for this ID1 category
                    $dailyHours = @(0, 0, 0, 0, 0, 0, 0)  # Mon-Sun
                    
                    foreach ($entry in $category.Entries) {
                        $dayOfWeek = [int]$entry.StartTime.DayOfWeek
                        if ($dayOfWeek -eq 0) { $dayOfWeek = 7 }  # Sunday = 7
                        $dailyHours[$dayOfWeek - 1] += $entry.GetHours()
                    }
                    
                    $dailyFormatted = $dailyHours | ForEach-Object { "{0:N2}" -f $_ }
                    $totalFormatted = "{0:N2}" -f $category.TotalHours
                    
                    $csvData += "$($category.CategoryName),,$($dailyFormatted -join ','),$totalFormatted"
                }
                
                return $csvData -join "`n"
            }
            
            default {
                throw "Unknown CSV format: $format"
            }
        }
        
        # This should never be reached
        return ""
    }
    
    # Export timesheet data to file
    [bool] ExportToFile([DateTime]$startDate, [DateTime]$endDate, [string]$filePath, [string]$format = "Standard") {
        try {
            $csvContent = $this.ExportToCSV($startDate, $endDate, $format)
            $csvContent | Out-File -FilePath $filePath -Encoding UTF8 -Force
            return $true
        }
        catch {
            Write-Log -Level Error -Message "Failed to export timesheet to file: $_"
            return $false
        }
    }
    
    # Copy timesheet data to clipboard
    [bool] ExportToClipboard([DateTime]$startDate, [DateTime]$endDate, [string]$format = "Standard") {
        try {
            $csvContent = $this.ExportToCSV($startDate, $endDate, $format)
            $csvContent | Set-Clipboard
            return $true
        }
        catch {
            Write-Log -Level Error -Message "Failed to export timesheet to clipboard: $_"
            return $false
        }
    }
}

#endregion