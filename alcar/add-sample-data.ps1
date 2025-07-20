#!/usr/bin/env pwsh
# Add sample data to ALCAR for testing

Write-Host "Adding sample data to ALCAR..." -ForegroundColor Cyan

# Load services
. "$PSScriptRoot/Models/task.ps1"
. "$PSScriptRoot/Models/Project.ps1"
. "$PSScriptRoot/Services/ServiceContainer.ps1"
. "$PSScriptRoot/Services/TaskService.ps1"
. "$PSScriptRoot/Services/ProjectService.ps1"

# Initialize services
$projectService = [ProjectService]::new()
$taskService = [TaskService]::new()

# Add sample projects
Write-Host "`nAdding sample projects..." -ForegroundColor Green
$projects = @(
    @{ Name = "ALCAR UI Framework"; Description = "Terminal UI framework development" },
    @{ Name = "LazyGit Integration"; Description = "Multi-panel interface implementation" },
    @{ Name = "Documentation"; Description = "User guides and API docs" },
    @{ Name = "Testing Suite"; Description = "Unit and integration tests" }
)

$projectIds = @{}
foreach ($proj in $projects) {
    $project = $projectService.AddProject($proj.Name)
    $project.Description = $proj.Description
    $projectIds[$proj.Name] = $project.Id
    Write-Host "  ✓ Added project: $($proj.Name)" -ForegroundColor Gray
}

# Save projects
$projectService.SaveProjects()

# Add sample tasks
Write-Host "`nAdding sample tasks..." -ForegroundColor Green
$tasks = @(
    @{ Title = "Implement scrolling in list views"; Project = "ALCAR UI Framework"; Status = "Active"; Priority = "High" },
    @{ Title = "Fix keyboard navigation"; Project = "ALCAR UI Framework"; Status = "Completed"; Priority = "High" },
    @{ Title = "Add color theme support"; Project = "ALCAR UI Framework"; Status = "Pending"; Priority = "Medium" },
    @{ Title = "Optimize rendering performance"; Project = "ALCAR UI Framework"; Status = "Active"; Priority = "High" },
    @{ Title = "Create panel focus manager"; Project = "LazyGit Integration"; Status = "Completed"; Priority = "High" },
    @{ Title = "Implement command palette"; Project = "LazyGit Integration"; Status = "Active"; Priority = "Medium" },
    @{ Title = "Add cross-panel communication"; Project = "LazyGit Integration"; Status = "Pending"; Priority = "Medium" },
    @{ Title = "Create responsive layout system"; Project = "LazyGit Integration"; Status = "Completed"; Priority = "High" },
    @{ Title = "Write user guide"; Project = "Documentation"; Status = "Pending"; Priority = "Low" },
    @{ Title = "Document API methods"; Project = "Documentation"; Status = "Active"; Priority = "Medium" },
    @{ Title = "Create tutorial videos"; Project = "Documentation"; Status = "Pending"; Priority = "Low" },
    @{ Title = "Write unit tests for core components"; Project = "Testing Suite"; Status = "Active"; Priority = "High" },
    @{ Title = "Set up CI/CD pipeline"; Project = "Testing Suite"; Status = "Pending"; Priority = "Medium" },
    @{ Title = "Create integration test suite"; Project = "Testing Suite"; Status = "Pending"; Priority = "High" },
    @{ Title = "Fix memory leaks"; Project = $null; Status = "Active"; Priority = "High"; Description = "Investigate and fix memory issues" },
    @{ Title = "Review pull requests"; Project = $null; Status = "Active"; Priority = "Medium"; Description = "Review community contributions" }
)

foreach ($taskData in $tasks) {
    $task = [Task]::new($taskData.Title)
    $task.Status = $taskData.Status
    $task.Priority = $taskData.Priority
    
    if ($taskData.Description) {
        $task.Description = $taskData.Description
    }
    
    if ($taskData.Project -and $projectIds.ContainsKey($taskData.Project)) {
        $task.ProjectId = $projectIds[$taskData.Project]
    }
    
    # Add some with due dates
    $random = Get-Random -Maximum 10
    if ($random -gt 6) {
        $task.DueDate = (Get-Date).AddDays((Get-Random -Minimum -2 -Maximum 14))
    }
    
    $taskService.AddTask($task)
    Write-Host "  ✓ Added task: $($taskData.Title)" -ForegroundColor Gray
}

# Save tasks
$taskService.SaveTasks()

Write-Host "`n✅ Sample data added successfully!" -ForegroundColor Green
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Projects: $($projectService.GetAllProjects().Count)" -ForegroundColor Yellow
Write-Host "  Tasks: $($taskService.GetAllTasks().Count)" -ForegroundColor Yellow

Write-Host "`nYou can now run ./bolt.ps1 and press 'G' to see the data in LazyGit interface" -ForegroundColor Cyan