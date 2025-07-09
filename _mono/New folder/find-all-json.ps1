# Search for ALL JSON serialization in all files
$files = Get-ChildItem "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\*.ps1" -File

Write-Host "Searching for JSON serialization in all files..." -ForegroundColor Yellow

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $lineNum = 0
    
    $content -split "`r?`n" | ForEach-Object {
        $lineNum++
        $line = $_
        
        # Look for any JSON conversion
        if ($line -match 'ConvertTo-Json|ConvertFrom-Json|\| *Format-\w+|Write-Output.*\$|Write-Host.*\$|Write-Verbose.*\$') {
            if ($line -notmatch '^\s*#') {  # Skip comments
                Write-Host "`n$($file.Name):$lineNum" -ForegroundColor Cyan
                Write-Host "  $line" -ForegroundColor White
            }
        }
    }
}

Write-Host "`n`nSearching for implicit output..." -ForegroundColor Yellow

# Search for lines that might cause implicit output
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $lineNum = 0
    
    $content -split "`r?`n" | ForEach-Object {
        $lineNum++
        $line = $_
        
        # Look for variable on its own line (implicit output)
        if ($line -match '^\s*\$\w+\s*$' -and $line -notmatch '^\s*#') {
            # Check context - is it the last line of a function/method?
            $nextLineNum = $lineNum + 1
            $nextLine = ($content -split "`r?`n")[$lineNum] 
            
            if ($nextLine -match '^\s*\}') {
                Write-Host "`n$($file.Name):$lineNum - Possible implicit output" -ForegroundColor Yellow
                Write-Host "  $line" -ForegroundColor White
            }
        }
    }
}
