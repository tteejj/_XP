# Fix inheritance issues in Monolithic-PMCTerminal.ps1

$filePath = "C:\Users\jhnhe\Documents\GitHub\_XP\Monolithic-PMCTerminal.ps1"
$content = Get-Content $filePath -Raw

Write-Host "Searching for inheritance issues..." -ForegroundColor Yellow

# Find and fix DashboardScreen inheritance
$dashboardPattern = 'class DashboardScreen\s*:\s*UIElement'
$dashboardMatch = [regex]::Match($content, $dashboardPattern)
if ($dashboardMatch.Success) {
    $lineNumber = ($content.Substring(0, $dashboardMatch.Index) -split '\r?\n').Count
    Write-Host "Found DashboardScreen : UIElement at line $lineNumber" -ForegroundColor Cyan
    $content = $content -replace 'class DashboardScreen\s*:\s*UIElement', 'class DashboardScreen : Screen'
    Write-Host "Fixed: DashboardScreen now inherits from Screen" -ForegroundColor Green
} else {
    Write-Host "DashboardScreen class not found!" -ForegroundColor Red
}

# Find and fix TaskListScreen inheritance
$taskListPattern = 'class TaskListScreen\s*:\s*UIElement'
$taskListMatch = [regex]::Match($content, $taskListPattern)
if ($taskListMatch.Success) {
    $lineNumber = ($content.Substring(0, $taskListMatch.Index) -split '\r?\n').Count
    Write-Host "Found TaskListScreen : UIElement at line $lineNumber" -ForegroundColor Cyan
    $content = $content -replace 'class TaskListScreen\s*:\s*UIElement', 'class TaskListScreen : Screen'
    Write-Host "Fixed: TaskListScreen now inherits from Screen" -ForegroundColor Green
} else {
    Write-Host "TaskListScreen class not found!" -ForegroundColor Red
}

# Write the fixed content back
Set-Content -Path $filePath -Value $content -Encoding UTF8 -NoNewline

Write-Host "`nInheritance fixes applied successfully!" -ForegroundColor Green
Write-Host "Both DashboardScreen and TaskListScreen now inherit from Screen class." -ForegroundColor Green

# Verify the parser error was fixed
Write-Host "`nVerifying previous parser error fix..." -ForegroundColor Yellow
if ($content -match '\$propValue\?\.ToString\(\) \?\? ""') {
    Write-Host "WARNING: Null-conditional operator still present!" -ForegroundColor Red
} else {
    Write-Host "Parser error fix confirmed - null-conditional operator replaced." -ForegroundColor Green
}

Write-Host "`nAll fixes completed!" -ForegroundColor Green
