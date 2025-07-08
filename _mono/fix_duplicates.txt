# Script to find and fix duplicate class definitions

$content = Get-Content ".\AllComponents.ps1" -Raw

# Find all occurrences of the class definitions
$taskDialogMatches = [regex]::Matches($content, 'class TaskDialog\s*:\s*Dialog')
$taskDeleteDialogMatches = [regex]::Matches($content, 'class TaskDeleteDialog\s*:\s*ConfirmDialog')

Write-Host "Found $($taskDialogMatches.Count) occurrences of TaskDialog"
Write-Host "Found $($taskDeleteDialogMatches.Count) occurrences of TaskDeleteDialog"

# Display line numbers for each occurrence
$lines = $content -split "`n"
$lineNum = 0
$taskDialogLines = @()
$taskDeleteDialogLines = @()

foreach ($line in $lines) {
    $lineNum++
    if ($line -match 'class TaskDialog\s*:\s*Dialog') {
        Write-Host "TaskDialog found at line $lineNum"
        $taskDialogLines += $lineNum
    }
    if ($line -match 'class TaskDeleteDialog\s*:\s*ConfirmDialog') {
        Write-Host "TaskDeleteDialog found at line $lineNum"
        $taskDeleteDialogLines += $lineNum
    }
}

# If duplicates found, we'll create a fixed version
if ($taskDialogMatches.Count -gt 1 -or $taskDeleteDialogMatches.Count -gt 1) {
    Write-Host "`nDuplicates found! Creating fixed version..."
    
    # Read the file line by line
    $lines = Get-Content ".\AllComponents.ps1"
    $outputLines = @()
    $skipTaskDialog = $false
    $skipTaskDeleteDialog = $false
    $taskDialogCount = 0
    $taskDeleteDialogCount = 0
    $inTaskDialog = $false
    $inTaskDeleteDialog = $false
    $braceCount = 0
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Check if we're starting a TaskDialog class
        if ($line -match 'class TaskDialog\s*:\s*Dialog') {
            $taskDialogCount++
            if ($taskDialogCount -gt 1) {
                Write-Host "Skipping duplicate TaskDialog at line $($i+1)"
                $skipTaskDialog = $true
                $inTaskDialog = $true
                $braceCount = 0
                continue
            }
        }
        
        # Check if we're starting a TaskDeleteDialog class
        if ($line -match 'class TaskDeleteDialog\s*:\s*ConfirmDialog') {
            $taskDeleteDialogCount++
            if ($taskDeleteDialogCount -gt 1) {
                Write-Host "Skipping duplicate TaskDeleteDialog at line $($i+1)"
                $skipTaskDeleteDialog = $true
                $inTaskDeleteDialog = $true
                $braceCount = 0
                continue
            }
        }
        
        # Track braces to know when class ends
        if ($inTaskDialog -or $inTaskDeleteDialog) {
            $openBraces = ($line -split '{').Count - 1
            $closeBraces = ($line -split '}').Count - 1
            $braceCount += $openBraces - $closeBraces
            
            if ($braceCount -eq 0 -and ($openBraces -gt 0 -or $closeBraces -gt 0)) {
                # Class definition ended
                if ($inTaskDialog) {
                    $inTaskDialog = $false
                    $skipTaskDialog = $false
                    Write-Host "Finished skipping TaskDialog duplicate"
                }
                if ($inTaskDeleteDialog) {
                    $inTaskDeleteDialog = $false
                    $skipTaskDeleteDialog = $false
                    Write-Host "Finished skipping TaskDeleteDialog duplicate"
                }
                continue
            }
        }
        
        # Add line if not skipping
        if (-not $skipTaskDialog -and -not $skipTaskDeleteDialog) {
            $outputLines += $line
        }
    }
    
    # Write the fixed content
    $outputLines -join "`n" | Set-Content ".\AllComponents.ps1" -NoNewline
    Write-Host "`nFixed! Removed duplicate class definitions."
}
else {
    Write-Host "`nNo duplicates found in class definitions."
}
