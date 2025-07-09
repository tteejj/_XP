# Fix script to comment out all Write-Verbose calls in AllServices.ps1

$filePath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllServices.ps1"

# Read the file
$content = Get-Content -Path $filePath -Raw

# Replace all Write-Verbose calls with commented versions
$content = $content -replace '(?m)^(\s*)(Write-Verbose\s+.*)$', '$1# $2'

# Write back to the file
Set-Content -Path $filePath -Value $content -Encoding UTF8

Write-Host "Commented out all Write-Verbose calls in AllServices.ps1" -ForegroundColor Green
