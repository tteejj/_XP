# Search for HandleInput methods with potential missing return statements
$file = Get-Content "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllComponents.ps1" -Raw
$pattern = '\[bool\]\s+HandleInput\s*\([^)]+\)\s*\{[\s\S]*?\n\s*\}'
$matches = [regex]::Matches($file, $pattern)

Write-Host "Found $($matches.Count) HandleInput methods" -ForegroundColor Cyan

foreach ($match in $matches) {
    $lines = $match.Value -split "`n"
    $firstLine = $lines[0].Trim()
    
    # Check if the method has a return statement before the closing brace
    $lastNonEmptyLine = ($lines | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 2)[0]
    
    if ($lastNonEmptyLine -and -not ($lastNonEmptyLine -match 'return')) {
        Write-Host "`nPotential missing return in:" -ForegroundColor Yellow
        Write-Host "  $firstLine" -ForegroundColor White
        Write-Host "  Last line: $($lastNonEmptyLine.Trim())" -ForegroundColor Red
        
        # Find line number
        $lineNumber = ($file.Substring(0, $match.Index) -split "`n").Count
        Write-Host "  Around line: $lineNumber" -ForegroundColor Gray
    }
}
