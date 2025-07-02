# PMC Terminal v5 - Fix Script
# Fixes two critical issues in Monolithic-PMCTerminal.ps1

Write-Host "PMC Terminal v5 - Applying Critical Fixes" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$filePath = "C:\Users\jhnhe\Documents\GitHub\_XP\Monolithic-PMCTerminal.ps1"

# Read the file
Write-Host "`nReading monolithic file..." -ForegroundColor Yellow
$content = Get-Content $filePath -Raw

$fixCount = 0

# Issue 1: Parser error with null-conditional operator (already fixed, but verify)
Write-Host "`nChecking parser error fix..." -ForegroundColor Yellow
if ($content -match '\$propValue\?\.ToString\(\) \?\? ""') {
    Write-Host "Found null-conditional operator - fixing..." -ForegroundColor Yellow
    $content = $content -replace '\$cellValue = \$propValue\?\.ToString\(\) \?\? ""', '$cellValue = if ($null -ne $propValue) { $propValue.ToString() } else { "" }'
    $fixCount++
    Write-Host "Fixed: Replaced null-conditional operator with if statement" -ForegroundColor Green
} else {
    Write-Host "Parser error already fixed - null-conditional operator not found" -ForegroundColor Green
}

# Issue 2: DashboardScreen inheritance
Write-Host "`nSearching for DashboardScreen inheritance issue..." -ForegroundColor Yellow
$dashboardMatches = [regex]::Matches($content, 'class\s+DashboardScreen\s*:\s*(\w+)')
foreach ($match in $dashboardMatches) {
    $currentBase = $match.Groups[1].Value
    if ($currentBase -eq "UIElement") {
        $lineNum = ($content.Substring(0, $match.Index) -split '\r?\n').Count
        Write-Host "Found at line $lineNum : DashboardScreen inherits from $currentBase" -ForegroundColor Cyan
        $oldText = $match.Value
        $newText = $oldText -replace ':.*$', ': Screen'
        $content = $content.Replace($oldText, $newText)
        $fixCount++
        Write-Host "Fixed: DashboardScreen now inherits from Screen" -ForegroundColor Green
    }
}

# Issue 3: TaskListScreen inheritance  
Write-Host "`nSearching for TaskListScreen inheritance issue..." -ForegroundColor Yellow
$taskListMatches = [regex]::Matches($content, 'class\s+TaskListScreen\s*:\s*(\w+)')
foreach ($match in $taskListMatches) {
    $currentBase = $match.Groups[1].Value
    if ($currentBase -eq "UIElement") {
        $lineNum = ($content.Substring(0, $match.Index) -split '\r?\n').Count
        Write-Host "Found at line $lineNum : TaskListScreen inherits from $currentBase" -ForegroundColor Cyan
        $oldText = $match.Value
        $newText = $oldText -replace ':.*$', ': Screen'
        $content = $content.Replace($oldText, $newText)
        $fixCount++
        Write-Host "Fixed: TaskListScreen now inherits from Screen" -ForegroundColor Green
    }
}

# Write the content back
if ($fixCount -gt 0) {
    Write-Host "`nWriting fixed content back to file..." -ForegroundColor Yellow
    Set-Content -Path $filePath -Value $content -Encoding UTF8 -NoNewline
    Write-Host "Successfully applied $fixCount fixes!" -ForegroundColor Green
} else {
    Write-Host "`nNo fixes needed - all issues already resolved!" -ForegroundColor Green
}

Write-Host "`nSummary of fixes applied:" -ForegroundColor Cyan
Write-Host "1. Parser error: Null-conditional operator replaced with if statement" -ForegroundColor White
Write-Host "2. DashboardScreen: Now inherits from Screen instead of UIElement" -ForegroundColor White
Write-Host "3. TaskListScreen: Now inherits from Screen instead of UIElement" -ForegroundColor White

Write-Host "`nYou can now run the monolithic script:" -ForegroundColor Green
Write-Host 'pwsh -File "C:\Users\jhnhe\Documents\GitHub\_XP\Monolithic-PMCTerminal.ps1"' -ForegroundColor Yellow
