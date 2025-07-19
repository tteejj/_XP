# TaskService - Business logic for task management
# Separated from UI concerns for better architecture

class TaskService {
    hidden [System.Collections.ArrayList]$Tasks = [System.Collections.ArrayList]::new()
    hidden [string]$DataFile = "$HOME/.alcar/tasks.json"
    
    TaskService() {
        $this.LoadTasks()
    }
    
    [void] LoadTasks() {
        if (Test-Path $this.DataFile) {
            try {
                $json = Get-Content $this.DataFile -Raw
                $data = $json | ConvertFrom-Json
                $this.Tasks.Clear()
                foreach ($taskData in $data) {
                    $task = [Task]::new($taskData.Title)
                    $task.Status = $taskData.Status
                    $task.Description = $taskData.Description
                    if ($taskData.Project) {
                        $task.ProjectId = $taskData.Project
                    }
                    if ($taskData.DueDate) {
                        $task.DueDate = [DateTime]::Parse($taskData.DueDate)
                    }
                    if ($taskData.ParentId) {
                        $task.ParentId = $taskData.ParentId
                    }
                    $task.Id = $taskData.Id
                    $this.Tasks.Add($task) | Out-Null
                }
            }
            catch {
                Write-Error "Failed to load tasks: $_"
            }
        }
    }
    
    [void] SaveTasks() {
        $dir = Split-Path $this.DataFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        $data = @()
        foreach ($task in $this.Tasks) {
            $data += @{
                Id = $task.Id
                Title = $task.Title
                Status = $task.Status
                Description = $task.Description
                Project = $task.ProjectId
                DueDate = if ($task.DueDate) { $task.DueDate.ToString("o") } else { $null }
                ParentId = $task.ParentId
            }
        }
        
        $json = $data | ConvertTo-Json -Depth 10
        Set-Content -Path $this.DataFile -Value $json
    }
    
    [Task[]] GetAllTasks() {
        return $this.Tasks.ToArray()
    }
    
    [Task[]] GetTasksByProject([string]$project) {
        return $this.Tasks | Where-Object { $_.ProjectId -eq $project }
    }
    
    [Task[]] GetSubtasks([string]$parentId) {
        return $this.Tasks | Where-Object { $_.ParentId -eq $parentId }
    }
    
    [Task] GetTask([string]$id) {
        return $this.Tasks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    }
    
    [Task] AddTask([string]$title) {
        $task = [Task]::new($title)
        $this.Tasks.Add($task) | Out-Null
        $this.SaveTasks()
        return $task
    }
    
    [Task] AddTask([Task]$task) {
        $this.Tasks.Add($task) | Out-Null
        $this.SaveTasks()
        return $task
    }
    
    [void] UpdateTask([Task]$task) {
        # Task is already in the list (reference type)
        $this.SaveTasks()
    }
    
    [void] DeleteTask([string]$id) {
        $task = $this.GetTask($id)
        if ($task) {
            $this.Tasks.Remove($task)
            # Also remove subtasks
            $subtasks = $this.GetSubtasks($id)
            foreach ($subtask in $subtasks) {
                $this.Tasks.Remove($subtask)
            }
            $this.SaveTasks()
        }
    }
    
    [hashtable] GetTaskStats() {
        $total = $this.Tasks.Count
        $completed = ($this.Tasks | Where-Object { $_.Status -eq "Done" }).Count
        $inProgress = ($this.Tasks | Where-Object { $_.Status -eq "InProgress" }).Count
        $todo = ($this.Tasks | Where-Object { $_.Status -eq "Todo" }).Count
        
        return @{
            Total = $total
            Completed = $completed
            InProgress = $inProgress
            Todo = $todo
            CompletionRate = if ($total -gt 0) { [math]::Round($completed / $total * 100) } else { 0 }
        }
    }
}