class PmcTask : ValidationBase {
    [string]$Id = [Guid]::NewGuid().ToString()
    [string]$Title
    [string]$Description
    [TaskStatus]$Status = [TaskStatus]::Pending
    [TaskPriority]$Priority = [TaskPriority]::Medium
    [string]$ProjectKey = "General"
    [string]$Category
    [datetime]$CreatedAt = [datetime]::Now
    [datetime]$UpdatedAt = [datetime]::Now
    [Nullable[datetime]]$DueDate
    [string[]]$Tags = @()
    [int]$Progress = 0
    [bool]$Completed = $false

    PmcTask() {}
    PmcTask([string]$title) { [ValidationBase]::ValidateNotEmpty($title, "Title"); $this.Title = $title }
    PmcTask([string]$title, [string]$description, [TaskPriority]$priority, [string]$projectKey) {
        [ValidationBase]::ValidateNotEmpty($title, "Title")
        $this.Title = $title; $this.Description = $description; $this.Priority = $priority
        $this.ProjectKey = $projectKey; $this.Category = $projectKey
    }

    [void] Complete() {
        $this.Status = [TaskStatus]::Completed; $this.Completed = $true
        $this.Progress = 100; $this.UpdatedAt = [datetime]::Now
    }

    [void] UpdateProgress([int]$newProgress) {
        if ($newProgress -lt 0 -or $newProgress -gt 100) { throw "Progress must be between 0 and 100." }
        $this.Progress = $newProgress
        $this.Status = $newProgress -eq 100 ? [TaskStatus]::Completed : $newProgress -gt 0 ? [TaskStatus]::InProgress : [TaskStatus]::Pending
        $this.Completed = ($this.Status -eq [TaskStatus]::Completed)
        $this.UpdatedAt = [datetime]::Now
    }
    
    [string] GetDueDateString() { return $this.DueDate ? $this.DueDate.Value.ToString("yyyy-MM-dd") : "N/A" }

    [hashtable] ToLegacyFormat() {
        return @{
            id = $this.Id; title = $this.Title; description = $this.Description
            completed = $this.Completed; priority = $this.Priority.ToString().ToLower()
            project = $this.ProjectKey; due_date = $this.DueDate ? $this.GetDueDateString() : $null
            created_at = $this.CreatedAt.ToString("o"); updated_at = $this.UpdatedAt.ToString("o")
        }
    }

    static [PmcTask] FromLegacyFormat([hashtable]$legacyData) {
        $task = [PmcTask]::new()
        $task.Id = $legacyData.id ?? $task.Id
        $task.Title = $legacyData.title
        $task.Description = $legacyData.description
        if ($legacyData.priority) { try { $task.Priority = [TaskPriority]::$($legacyData.priority) } catch {} }
        $task.ProjectKey = $legacyData.project ?? $legacyData.Category ?? "General"
        $task.Category = $task.ProjectKey
        if ($legacyData.created_at) { try { $task.CreatedAt = [datetime]::Parse($legacyData.created_at) } catch {} }
        if ($legacyData.updated_at) { try { $task.UpdatedAt = [datetime]::Parse($legacyData.updated_at) } catch {} }
        if ($legacyData.due_date -and $legacyData.due_date -ne "N/A") { try { $task.DueDate = [datetime]::Parse($legacyData.due_date) } catch {} }
        if ($legacyData.completed -is [bool] -and $legacyData.completed) { $task.Complete() }
        return $task
    }
}
