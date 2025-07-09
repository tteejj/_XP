# PowerShell script to find and comment out problematic Write-Verbose calls
# Run this to automatically fix verbose logging issues

$files = @(
    "AllServices.ps1",
    "AllComponents.ps1", 
    "AllScreens.ps1",
    "AllRuntime.ps1"
)

foreach ($file in $files) {
    $path = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\$file"
    if (Test-Path $path) {
        Write-Host "Processing $file..." -ForegroundColor Cyan
        
        $content = Get-Content $path -Raw
        
        # Comment out all Write-Verbose calls (they can cause issues with complex objects)
        $content = $content -replace '(Write-Verbose\s+[^\n]+)', '# $1'
        
        # Save to a new file for review
        $newPath = $path -replace '\.ps1$', '_NoVerbose.ps1'
        Set-Content -Path $newPath -Value $content -Encoding UTF8
        
        Write-Host "Created $newPath with verbose logging disabled" -ForegroundColor Green
    }
}

Write-Host "`nTo apply the fix, replace the original files with the _NoVerbose versions" -ForegroundColor Yellow
