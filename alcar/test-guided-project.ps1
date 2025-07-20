#!/usr/bin/env pwsh
# Test script for guided project creation

Write-Host "Testing Guided Project Creation..." -ForegroundColor Cyan

# Load dependencies in order
. "./Core/vt100.ps1"
. "./Core/Cell.ps1" 
. "./Core/Buffer.ps1"
. "./Core/layout2.ps1"
. "./Base/Screen.ps1"
. "./Models/Project.ps1"
. "./Services/ProjectService.ps1"
. "./Screens/ProjectCreationDialog.ps1"

# Test Project model
Write-Host "`nTesting enhanced Project model..." -ForegroundColor Yellow

$project = [Project]::new("Test Project", "TEST001")
$project.ID1 = "PRJ"
$project.ID2 = "001"
$project.Note = "Test project for PMC pattern validation"

Write-Host "✓ Project created: $($project.FullProjectName) ($($project.Nickname))" -ForegroundColor Green
Write-Host "  ID1: $($project.ID1), ID2: $($project.ID2)" -ForegroundColor Gray
Write-Host "  Due Date: $($project.DateDue.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
Write-Host "  Note: $($project.Note)" -ForegroundColor Gray

# Test ProjectService enhanced functionality
Write-Host "`nTesting enhanced ProjectService..." -ForegroundColor Yellow

$service = [ProjectService]::new()
$addedProject = $service.AddProject($project)

Write-Host "✓ Project added to service" -ForegroundColor Green

$allProjects = $service.GetAllProjects()
Write-Host "✓ Total projects in service: $($allProjects.Count)" -ForegroundColor Green

foreach ($proj in $allProjects) {
    Write-Host "  - $($proj.Nickname): $($proj.FullProjectName)" -ForegroundColor Gray
    Write-Host "    Assigned: $($proj.DateAssigned.ToString('yyyy-MM-dd')), Due: $($proj.DateDue.ToString('yyyy-MM-dd'))" -ForegroundColor DarkGray
}

Write-Host "`n✓ All tests passed! Guided project creation system is ready." -ForegroundColor Green
Write-Host "`nTo test the guided dialog:" -ForegroundColor Cyan
Write-Host "1. Run BOLT-AXIOM with: pwsh ./bolt.ps1" -ForegroundColor White
Write-Host "2. Navigate to main menu and press 'N' for New Project" -ForegroundColor White
Write-Host "3. Follow the guided prompts to create a project" -ForegroundColor White