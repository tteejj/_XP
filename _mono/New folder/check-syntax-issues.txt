# Search for potential switch statement syntax issues in AllComponents.ps1

$content = Get-Content "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllComponents.ps1" -Raw

# Find lines with the problematic pattern: multiple ConsoleKey cases separated by semicolons
$pattern = '\)\s*;\s*\([^)]*ConsoleKey'
$matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)

Write-Host "Searching for switch statement syntax issues..." -ForegroundColor Cyan

if ($matches.Count -eq 0) {
    Write-Host "✓ No other similar syntax issues found!" -ForegroundColor Green
} else {
    Write-Host "Found $($matches.Count) potential issues:" -ForegroundColor Yellow
    
    foreach ($match in $matches) {
        # Get line number
        $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
        
        # Get the line content
        $lines = $content -split "`n"
        $lineContent = $lines[$lineNumber - 1]
        
        Write-Host "`nLine $lineNumber`:" -ForegroundColor Red
        Write-Host "  $($lineContent.Trim())" -ForegroundColor Gray
    }
}

# Also check if our fix was successful by verifying the fixed line
Write-Host "`n`nVerifying our fix at line 2550..." -ForegroundColor Cyan
$lines = $content -split "`n"
if ($lines.Count -gt 2549) {
    $fixedLine = $lines[2549].Trim()
    if ($fixedLine -like '*{$_ -in*') {
        Write-Host "✓ Fix successfully applied!" -ForegroundColor Green
        Write-Host "  Line 2550: $fixedLine" -ForegroundColor Gray
    } else {
        Write-Host "✗ Fix may not have been applied correctly" -ForegroundColor Red
        Write-Host "  Line 2550: $fixedLine" -ForegroundColor Gray
    }
}
