# TimeTrackingService - Time entry management with CSV export
# Based on PMC patterns from doc_review.txt

class TimeTrackingService {
    [string]$DataFile
    [System.Collections.ArrayList]$TimeEntries
    [hashtable]$Cache
    
    TimeTrackingService() {
        $this.DataFile = Join-Path $PSScriptRoot "../_ProjectData/timetracking.csv"
        $this.TimeEntries = [System.Collections.ArrayList]::new()
        $this.Cache = @{}
        $this.EnsureDataDirectory()
        $this.LoadTimeEntries()
    }
    
    TimeTrackingService([string]$dataFile) {
        $this.DataFile = $dataFile
        $this.TimeEntries = [System.Collections.ArrayList]::new()
        $this.Cache = @{}
        $this.EnsureDataDirectory()
        $this.LoadTimeEntries()
    }
    
    # Ensure data directory exists (PMC pattern)
    [void] EnsureDataDirectory() {
        $dir = Split-Path $this.DataFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    # Load time entries from CSV
    [void] LoadTimeEntries() {
        try {
            if (Test-Path $this.DataFile) {
                $csvData = Import-Csv -Path $this.DataFile -Encoding UTF8
                $this.TimeEntries.Clear()
                
                foreach ($row in $csvData) {
                    $entry = [TimeEntry]::new()
                    $entry.ID = $row.ID
                    $entry.Date = [datetime]::Parse($row.Date)
                    $entry.ProjectID = $row.ProjectID
                    $entry.Hours = [double]$row.Hours
                    $entry.Description = $row.Description
                    $entry.Category = $row.Category
                    $entry.CreatedAt = [datetime]::Parse($row.CreatedAt)
                    $entry.ModifiedAt = [datetime]::Parse($row.ModifiedAt)
                    
                    $this.TimeEntries.Add($entry) | Out-Null
                }
                
                Write-Host "Loaded $($this.TimeEntries.Count) time entries" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Failed to load time entries: $($_.Exception.Message)"
        }
        
        # Add default entry if none exist
        if ($this.TimeEntries.Count -eq 0) {
            $defaultEntry = [TimeEntry]::new()
            $defaultEntry.Date = [datetime]::new(1900, 1, 1)
            $defaultEntry.ProjectID = "default"
            $defaultEntry.Hours = 0.25
            $defaultEntry.Description = "Default entry - example time tracking"
            $defaultEntry.Category = "Example"
            $defaultEntry.CreatedAt = [datetime]::new(1900, 1, 1)
            $defaultEntry.ModifiedAt = [datetime]::new(1900, 1, 1)
            $this.TimeEntries.Add($defaultEntry) | Out-Null
            
            # Save the default entry
            $this.SaveTimeEntries()
        }
        
        $this.ClearCache()
    }
    
    # Save time entries to CSV (atomic operation as per PMC pattern)
    [void] SaveTimeEntries() {
        try {
            # Create backup first
            if (Test-Path $this.DataFile) {
                $backupFile = $this.DataFile + ".backup"
                Copy-Item $this.DataFile $backupFile -Force
            }
            
            # Convert to CSV format
            $csvData = @()
            foreach ($entry in $this.TimeEntries) {
                $csvData += [PSCustomObject]@{
                    ID = $entry.ID
                    Date = $entry.Date.ToString('yyyy-MM-dd')
                    ProjectID = $entry.ProjectID
                    Hours = $entry.Hours
                    Description = $entry.Description
                    Category = $entry.Category
                    CreatedAt = $entry.CreatedAt.ToString('yyyy-MM-dd HH:mm:ss')
                    ModifiedAt = $entry.ModifiedAt.ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
            
            # Atomic save
            $csvData | Export-Csv -Path $this.DataFile -NoTypeInformation -Encoding UTF8
            Write-Host "Saved $($this.TimeEntries.Count) time entries" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to save time entries: $($_.Exception.Message)"
        }
        
        $this.ClearCache()
    }
    
    # Add new time entry
    [TimeEntry] AddTimeEntry([string]$projectID, [double]$hours, [string]$description) {
        $entry = [TimeEntry]::new($projectID, $hours, $description)
        
        if ($entry.IsValid()) {
            $this.TimeEntries.Add($entry) | Out-Null
            $this.SaveTimeEntries()
            return $entry
        }
        else {
            throw "Invalid time entry data"
        }
    }
    
    # Add time entry with all parameters
    [TimeEntry] AddTimeEntry([datetime]$date, [string]$projectID, [double]$hours, [string]$description, [string]$category) {
        $entry = [TimeEntry]::new($projectID, $hours, $description)
        $entry.Date = $date
        $entry.Category = $category
        
        if ($entry.IsValid()) {
            $this.TimeEntries.Add($entry) | Out-Null
            $this.SaveTimeEntries()
            return $entry
        }
        else {
            throw "Invalid time entry data"
        }
    }
    
    # Add time entry object
    [TimeEntry] AddTimeEntry([TimeEntry]$entry) {
        if ($entry.IsValid()) {
            $this.TimeEntries.Add($entry) | Out-Null
            $this.SaveTimeEntries()
            return $entry
        } else {
            throw "Invalid time entry data"
        }
    }
    
    # Update time entry
    [bool] UpdateTimeEntry([TimeEntry]$entry) {
        $existingEntry = $this.GetTimeEntry($entry.ID)
        if ($existingEntry -and $entry.IsValid()) {
            $existingEntry.Date = $entry.Date
            $existingEntry.ProjectID = $entry.ProjectID
            $existingEntry.Hours = $entry.Hours
            $existingEntry.Description = $entry.Description
            $existingEntry.Category = $entry.Category
            $existingEntry.ModifiedAt = [datetime]::Now
            
            $this.SaveTimeEntries()
            return $true
        }
        return $false
    }
    
    # Delete time entry
    [bool] DeleteTimeEntry([string]$entryID) {
        $entry = $this.GetTimeEntry($entryID)
        if ($entry) {
            $this.TimeEntries.Remove($entry)
            $this.SaveTimeEntries()
            return $true
        }
        return $false
    }
    
    # Get time entry by ID
    [TimeEntry] GetTimeEntry([string]$entryID) {
        return $this.TimeEntries | Where-Object { $_.ID -eq $entryID } | Select-Object -First 1
    }
    
    # Get all time entries
    [System.Collections.ArrayList] GetAllTimeEntries() {
        if (-not $this.TimeEntries) {
            $this.TimeEntries = [System.Collections.ArrayList]::new()
        }
        return $this.TimeEntries
    }
    
    # Get time entries for project
    [array] GetTimeEntriesForProject([string]$projectID) {
        return $this.TimeEntries | Where-Object { $_.ProjectID -eq $projectID }
    }
    
    # Get time entries for date range
    [array] GetTimeEntriesForDateRange([datetime]$startDate, [datetime]$endDate) {
        return $this.TimeEntries | Where-Object { 
            $_.Date -ge $startDate -and $_.Date -le $endDate 
        }
    }
    
    # Get time entries for current week
    [array] GetCurrentWeekEntries() {
        $now = [datetime]::Now
        $startOfWeek = $now.AddDays(-[int]$now.DayOfWeek)
        $endOfWeek = $startOfWeek.AddDays(6)
        return $this.GetTimeEntriesForDateRange($startOfWeek, $endOfWeek)
    }
    
    # Calculate total hours for project
    [double] GetTotalHoursForProject([string]$projectID) {
        $cacheKey = "total_$projectID"
        if ($this.Cache.ContainsKey($cacheKey)) {
            return $this.Cache[$cacheKey]
        }
        
        $total = ($this.GetTimeEntriesForProject($projectID) | Measure-Object -Property Hours -Sum).Sum
        $this.Cache[$cacheKey] = $total
        return $total
    }
    
    # Calculate total hours for date range
    [double] GetTotalHoursForDateRange([datetime]$startDate, [datetime]$endDate) {
        return ($this.GetTimeEntriesForDateRange($startDate, $endDate) | Measure-Object -Property Hours -Sum).Sum
    }
    
    # Export timesheet for date range
    [void] ExportTimesheet([datetime]$startDate, [datetime]$endDate, [string]$outputFile) {
        $entries = $this.GetTimeEntriesForDateRange($startDate, $endDate)
        
        # Group by project and date for summary
        $summary = $entries | Group-Object ProjectID | ForEach-Object {
            $projectID = $_.Name
            $projectEntries = $_.Group
            $totalHours = ($projectEntries | Measure-Object -Property Hours -Sum).Sum
            
            [PSCustomObject]@{
                ProjectID = $projectID
                TotalHours = $totalHours
                Entries = $projectEntries.Count
                DateRange = "$($startDate.ToString('yyyy-MM-dd')) to $($endDate.ToString('yyyy-MM-dd'))"
            }
        }
        
        # Export detailed entries
        $exportData = @()
        foreach ($entry in $entries) {
            $exportData += $entry.ToCSVRow()
        }
        
        # Create export directory
        $exportDir = Split-Path $outputFile -Parent
        if (-not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        
        # Export to CSV
        $exportData | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
        
        # Also create summary file
        $summaryFile = $outputFile -replace '\.csv$', '_summary.csv'
        $summary | Export-Csv -Path $summaryFile -NoTypeInformation -Encoding UTF8
        
        Write-Host "Exported $($entries.Count) time entries to $outputFile" -ForegroundColor Green
        Write-Host "Summary exported to $summaryFile" -ForegroundColor Green
    }
    
    # Quick export for current week
    [void] ExportCurrentWeek([string]$outputDir) {
        $now = [datetime]::Now
        $startOfWeek = $now.AddDays(-[int]$now.DayOfWeek)
        $endOfWeek = $startOfWeek.AddDays(6)
        
        $filename = "timesheet_week_$($startOfWeek.ToString('yyyy-MM-dd')).csv"
        $outputFile = Join-Path $outputDir $filename
        
        $this.ExportTimesheet($startOfWeek, $endOfWeek, $outputFile)
    }
    
    # Clear cache
    [void] ClearCache() {
        $this.Cache.Clear()
    }
    
    # Get statistics
    [hashtable] GetStatistics() {
        $total = ($this.TimeEntries | Measure-Object -Property Hours -Sum).Sum
        $projectCounts = $this.TimeEntries | Group-Object ProjectID | ForEach-Object {
            @{
                ProjectID = $_.Name
                Hours = ($_.Group | Measure-Object -Property Hours -Sum).Sum
                Entries = $_.Count
            }
        }
        
        return @{
            TotalEntries = $this.TimeEntries.Count
            TotalHours = $total
            ProjectBreakdown = $projectCounts
            DateRange = @{
                Earliest = ($this.TimeEntries | Sort-Object Date | Select-Object -First 1).Date
                Latest = ($this.TimeEntries | Sort-Object Date -Descending | Select-Object -First 1).Date
            }
        }
    }
}