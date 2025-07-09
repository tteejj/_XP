# More comprehensive search for JSON issues
Write-Host "=== Comprehensive JSON Serialization Search ===" -ForegroundColor Cyan

$results = @()

Get-ChildItem "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\*.ps1" | ForEach-Object {
    $file = $_
    $content = Get-Content $file.FullName
    
    for ($i = 0; $i -lt $content.Count; $i++) {
        $line = $content[$i]
        $lineNum = $i + 1
        
        # Skip comments
        if ($line -match '^\s*#') { continue }
        
        # Check for JSON conversion
        if ($line -match 'ConvertTo-Json') {
            $results += [PSCustomObject]@{
                File = $file.Name
                Line = $lineNum
                Type = "ConvertTo-Json"
                Content = $line.Trim()
            }
        }
        
        # Check for Write-Verbose with complex expressions
        if ($line -match 'Write-Verbose.*\$\(.*\)') {
            $results += [PSCustomObject]@{
                File = $file.Name
                Line = $lineNum
                Type = "Write-Verbose with expression"
                Content = $line.Trim()
            }
        }
        
        # Check for Write-Host/Output with variables
        if ($line -match 'Write-(Host|Output|Information).*\$\w+' -and $line -notmatch '\$_|"[^"]*\$\w+[^"]*"') {
            $results += [PSCustomObject]@{
                File = $file.Name
                Line = $lineNum
                Type = "Write-* with variable"
                Content = $line.Trim()
            }
        }
    }
}

if ($results.Count -gt 0) {
    Write-Host "`nFound $($results.Count) potential issues:" -ForegroundColor Yellow
    $results | Format-Table -AutoSize
} else {
    Write-Host "`nNo obvious JSON serialization found in code." -ForegroundColor Green
}

Write-Host "`nChecking Start.ps1 for verbose preferences..." -ForegroundColor Yellow
$startContent = Get-Content "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\Start.ps1" -Raw
if ($startContent -match 'VerbosePreference') {
    Write-Host "Found VerbosePreference setting in Start.ps1" -ForegroundColor Red
}
