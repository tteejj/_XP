# Fix all standalone BackgroundColor lines across the codebase
# These are remnants of incomplete property assignments

$ErrorActionPreference = "Stop"

Write-Host "Fixing standalone BackgroundColor lines..." -ForegroundColor Yellow

# Find all PS1 files
$files = Get-ChildItem -Path . -Include "*.ps1" -Recurse -File | Where-Object { 
    $_.Name -ne "fix-backgroundcolor.ps1" -and
    -not $_.Name.EndsWith(".backup") -and
    -not $_.Name.EndsWith(".old")
}

$totalFixed = 0

foreach ($file in $files) {
    Write-Host "Checking $($file.Name)..." -NoNewline
    
    $content = Get-Content $file -Raw
    $originalContent = $content
    
    # Remove standalone BackgroundColor lines (lines that only contain BackgroundColor and whitespace)
    # This pattern matches lines that have only whitespace, then BackgroundColor, then optional whitespace, then line ending
    $content = $content -replace '(?m)^\s*BackgroundColor\s*$\r?\n', ''
    
    if ($content -ne $originalContent) {
        # Count how many lines were removed
        $removedCount = ([regex]::Matches($originalContent, '(?m)^\s*BackgroundColor\s*$')).Count
        
        # Save the file
        Set-Content -Path $file -Value $content -NoNewline
        
        Write-Host " Fixed $removedCount lines" -ForegroundColor Green
        $totalFixed += $removedCount
    } else {
        Write-Host " No issues found" -ForegroundColor Gray
    }
}

Write-Host "`nTotal BackgroundColor lines removed: $totalFixed" -ForegroundColor Cyan

# Also check TXT files that might be component definitions
Write-Host "`nChecking TXT files..." -ForegroundColor Yellow
$txtFiles = Get-ChildItem -Path . -Include "*.txt" -Recurse -File | Where-Object {
    $_.Name -notmatch "(README|LICENSE|GUIDE|TODO|STATUS|PLAN|NOTES)"
}

foreach ($file in $txtFiles) {
    Write-Host "Checking $($file.Name)..." -NoNewline
    
    $content = Get-Content $file -Raw
    $originalContent = $content
    
    # Remove standalone BackgroundColor lines
    $content = $content -replace '(?m)^\s*BackgroundColor\s*$\r?\n', ''
    
    if ($content -ne $originalContent) {
        $removedCount = ([regex]::Matches($originalContent, '(?m)^\s*BackgroundColor\s*$')).Count
        
        Set-Content -Path $file -Value $content -NoNewline
        
        Write-Host " Fixed $removedCount lines" -ForegroundColor Green
        $totalFixed += $removedCount
    } else {
        Write-Host " No issues found" -ForegroundColor Gray
    }
}

Write-Host "`nGrand total BackgroundColor lines removed: $totalFixed" -ForegroundColor Cyan
Write-Host "Fix complete!" -ForegroundColor Green
