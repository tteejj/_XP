# TimeEntry Model - Based on PMC pattern from doc_review.txt
# 15-minute increments, workday filtering, cumulative tracking

class TimeEntry {
    [string]$ID
    [datetime]$Date
    [string]$ProjectID  # Links to Project.ID
    [double]$Hours      # Enforced to 15-minute increments (0.25, 0.5, 0.75, 1.0, etc.)
    [string]$Description
    [string]$Category   # Optional: "Development", "Meeting", "Documentation", etc.
    [datetime]$CreatedAt
    [datetime]$ModifiedAt
    
    TimeEntry() {
        $this.ID = [guid]::NewGuid().ToString()
        $this.Date = [datetime]::Today
        $this.Hours = 0.25  # Default to 15 minutes
        $this.Description = ""
        $this.Category = "Development"
        $this.CreatedAt = [datetime]::Now
        $this.ModifiedAt = [datetime]::Now
    }
    
    TimeEntry([string]$projectID, [double]$hours, [string]$description) {
        $this.ID = [guid]::NewGuid().ToString()
        $this.Date = [datetime]::Today
        $this.ProjectID = $projectID
        $this.Hours = $this.RoundToQuarterHour($hours)
        $this.Description = $description
        $this.Category = "Development"
        $this.CreatedAt = [datetime]::Now
        $this.ModifiedAt = [datetime]::Now
    }
    
    # Enforce 15-minute increments as per PMC pattern
    [double] RoundToQuarterHour([double]$hours) {
        return [Math]::Round($hours * 4) / 4
    }
    
    # Set hours with automatic rounding
    [void] SetHours([double]$hours) {
        $this.Hours = $this.RoundToQuarterHour($hours)
        $this.ModifiedAt = [datetime]::Now
    }
    
    # Format for display
    [string] ToString() {
        return "$($this.Date.ToString('yyyy-MM-dd')) - $($this.Hours)h - $($this.Description)"
    }
    
    # Format for CSV export (timesheet compatibility)
    [hashtable] ToCSVRow() {
        return @{
            Date = $this.Date.ToString('yyyy-MM-dd')
            ProjectID = $this.ProjectID
            Hours = $this.Hours
            Description = $this.Description
            Category = $this.Category
        }
    }
    
    # Validation - Combined comprehensive checks
    [bool] IsValid() {
        if ([string]::IsNullOrWhiteSpace($this.ProjectID)) { return $false }
        if ($this.Hours -le 0) { return $false }
        if ($this.Date -eq [datetime]::MinValue) { return $false }
        if ([string]::IsNullOrWhiteSpace($this.Description)) { return $false }
        return $true
    }
    
    # Common time increments for UI
    static [double[]] GetStandardIncrements() {
        return @(0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 4.0, 8.0)
    }
    
    # Common categories
    static [string[]] GetStandardCategories() {
        return @("Development", "Meeting", "Documentation", "Testing", "Planning", "Review", "Admin")
    }
}