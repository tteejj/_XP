# Task model keeping Axiom's data structure

class Task {
    [string]$Id
    [string]$Title
    [string]$Description
    [string]$Status  # Pending, InProgress, Completed, Cancelled
    [string]$Priority  # Low, Medium, High
    [int]$Progress  # 0-100
    [string]$ProjectId
    [datetime]$CreatedDate
    [datetime]$ModifiedDate
    [datetime]$DueDate
    [string]$AssignedTo
    [System.Collections.ArrayList]$Tags
    [string]$ParentId  # For subtasks
    [System.Collections.ArrayList]$SubtaskIds  # Children
    [bool]$IsExpanded = $true  # For tree view
    [int]$Level = 0  # Nesting level for display
    
    Task() {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.CreatedDate = [datetime]::Now
        $this.ModifiedDate = [datetime]::Now
        $this.Status = "Pending"
        $this.Priority = "Medium"
        $this.Progress = 0
        $this.Tags = [System.Collections.ArrayList]::new()
        $this.SubtaskIds = [System.Collections.ArrayList]::new()
    }
    
    Task([string]$title) {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.Title = $title
        $this.CreatedDate = [datetime]::Now
        $this.ModifiedDate = [datetime]::Now
        $this.Status = "Pending"
        $this.Priority = "Medium"
        $this.Progress = 0
        $this.Tags = [System.Collections.ArrayList]::new()
        $this.SubtaskIds = [System.Collections.ArrayList]::new()
    }
    
    [string] GetStatusSymbol() {
        switch ($this.Status) {
            "Pending" { return "○" }
            "InProgress" { return "◐" }
            "Completed" { return "●" }
            "Cancelled" { return "✗" }
            default { return "?" }
        }
        return "?"
    }
    
    [string] GetStatusColor() {
        switch ($this.Status) {
            "Pending" { return [VT]::TextDim() }
            "InProgress" { return [VT]::Warning() }
            "Completed" { return [VT]::Accent() }
            "Cancelled" { return [VT]::Error() }
            default { return [VT]::Text() }
        }
        return [VT]::Text()
    }
    
    [string] GetPrioritySymbol() {
        switch ($this.Priority) {
            "Low" { return "↓" }
            "Medium" { return "→" }
            "High" { return "↑" }
            default { return "?" }
        }
        return "?"
    }
    
    [string] GetPriorityColor() {
        switch ($this.Priority) {
            "Low" { return [VT]::TextDim() }
            "Medium" { return [VT]::Text() }
            "High" { return [VT]::Error() }
            default { return [VT]::Text() }
        }
        return [VT]::Text()
    }
    
    [bool] IsOverdue() {
        return $this.DueDate -and $this.DueDate -lt [datetime]::Now -and $this.Status -ne "Completed"
    }
    
    [void] Update() {
        $this.ModifiedDate = [datetime]::Now
    }
}