# check-extraction.ps1 - Diagnostic tool for extraction
$content = Get-Content "all-classes.ps1" -Raw

Write-Host "Extraction Summary:" -ForegroundColor Cyan
Write-Host "File size: $($content.Length) bytes" -ForegroundColor Gray

$enums = ([regex]::Matches($content, 'enum\s+(\w+)')).Count
$classes = ([regex]::Matches($content, 'class\s+(\w+)')).Count

Write-Host "Found in output file:" -ForegroundColor Yellow
Write-Host "  - $enums enums" -ForegroundColor Gray
Write-Host "  - $classes classes" -ForegroundColor Gray

if ($classes -eq 0) {
    Write-Host "`n⚠️  WARNING: No classes found!" -ForegroundColor Red
    Write-Host "This suggests the extraction failed." -ForegroundColor Red
}

Write-Host "`nFirst 20 type definitions:" -ForegroundColor Yellow
$matches = [regex]::Matches($content, '(?m)^(enum|class)\s+(\w+)')
$matches | Select-Object -First 20 | ForEach-Object {
    Write-Host "  - $($_.Groups[1].Value) $($_.Groups[2].Value)" -ForegroundColor DarkGray
}
