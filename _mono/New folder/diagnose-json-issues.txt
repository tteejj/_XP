# Diagnostic script to find potential JSON serialization issues

Write-Host "=== Searching for Potential JSON Serialization Issues ===" -ForegroundColor Cyan

$files = Get-ChildItem "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\*.ps1" -File

$patterns = @(
    'ConvertTo-Json(?!.*-ErrorAction)',  # ConvertTo-Json without error handling
    'ConvertTo-Json.*-Depth\s+\d{2,}',   # ConvertTo-Json with depth 10 or more
    '\| Out-Default',                     # Piping to Out-Default (implicit serialization)
    'Write-Output.*\$this',               # Writing $this to output
    'return\s+\$this(?!\.\w)',           # Returning $this without property access
    '^\s*\$this\s*$',                     # $this on its own line (implicit output)
    '^\s*\$[\w_]+\s*$'                    # Variable on its own line (might output object)
)

$findings = @()

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $lines = $content -split "`r?`n"
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1
        
        foreach ($pattern in $patterns) {
            if ($line -match $pattern) {
                # Skip comments and strings
                if ($line -match '^\s*#' -or $line -match '^\s*[\''"]') { continue }
                
                # Special handling for variable-only lines
                if ($pattern -eq '^\s*\$[\w_]+\s*$') {
                    # Check if it's inside a function/method and not the last line
                    $inFunction = $false
                    for ($j = $i - 1; $j -ge 0 -and $j -ge $i - 10; $j--) {
                        if ($lines[$j] -match '(function|method|\[void\]|\[bool\]|\[string\])') {
                            $inFunction = $true
                            break
                        }
                    }
                    
                    # Skip if it's a return statement or assignment
                    if ($i -gt 0 -and ($lines[$i-1] -match 'return|=' -or $lines[$i+1] -match '^}')) {
                        continue
                    }
                    
                    if (-not $inFunction) { continue }
                }
                
                $findings += [PSCustomObject]@{
                    File = $file.Name
                    Line = $lineNum
                    Pattern = $pattern
                    Content = $line.Trim()
                }
                break
            }
        }
    }
}

if ($findings.Count -gt 0) {
    Write-Host "`nPotential Issues Found:" -ForegroundColor Yellow
    $findings | Group-Object File | ForEach-Object {
        Write-Host "`n$($_.Name):" -ForegroundColor Cyan
        $_.Group | ForEach-Object {
            Write-Host "  Line $($_.Line): $($_.Content)" -ForegroundColor Gray
            Write-Host "    Pattern: $($_.Pattern)" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`nRecommendations:" -ForegroundColor Yellow
    Write-Host "1. Add -ErrorAction Stop to ConvertTo-Json calls" -ForegroundColor White
    Write-Host "2. Wrap ConvertTo-Json in try-catch blocks" -ForegroundColor White
    Write-Host "3. Add | Out-Null to collection operations that don't need output" -ForegroundColor White
    Write-Host "4. Be explicit about return values in methods" -ForegroundColor White
} else {
    Write-Host "`nNo obvious serialization issues found!" -ForegroundColor Green
}

Write-Host "`nNote: This is not exhaustive. The main issue was in Write-Log function." -ForegroundColor Gray
