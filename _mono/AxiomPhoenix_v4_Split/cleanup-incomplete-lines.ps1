# Clean up all standalone variable/property lines that are incomplete
# These are causing parse errors

$ErrorActionPreference = "Stop"

Write-Host "Cleaning up incomplete variable/property lines..." -ForegroundColor Yellow

# Find all PS1 files
$files = Get-ChildItem -Path . -Include "*.ps1" -Recurse -File | Where-Object { 
    $_.Name -ne "cleanup-incomplete-lines.ps1" -and
    -not $_.Name.EndsWith(".backup") -and
    -not $_.Name.EndsWith(".old")
}

$patterns = @(
    '(?m)^\s*BackgroundColor\s*$',          # Standalone BackgroundColor
    '(?m)^\s*\$selectedTheme\s*$',          # Standalone $selectedTheme
    '(?m)^\s*ForegroundColor\s*$',          # Standalone ForegroundColor
    '(?m)^\s*BorderColor\s*$',              # Standalone BorderColor
    '(?m)^\s*\$this\.[A-Za-z]+Color\s*$',   # Standalone $this.SomeColor
    '(?m)^\s*\$[A-Za-z]+\s*$'               # Any standalone variable
)

$totalFixed = 0

foreach ($file in $files) {
    Write-Host "Checking $($file.Name)..." -NoNewline
    
    $content = Get-Content $file -Raw
    $originalContent = $content
    $fileFixed = 0
    
    # Remove each pattern
    foreach ($pattern in $patterns) {
        $matches = ([regex]::Matches($content, $pattern)).Count
        if ($matches -gt 0) {
            $content = $content -replace $pattern, ''
            $fileFixed += $matches
        }
    }
    
    if ($content -ne $originalContent) {
        # Save the file
        Set-Content -Path $file -Value $content -NoNewline
        
        Write-Host " Fixed $fileFixed lines" -ForegroundColor Green
        $totalFixed += $fileFixed
    } else {
        Write-Host " No issues found" -ForegroundColor Gray
    }
}

Write-Host "`nTotal incomplete lines removed: $totalFixed" -ForegroundColor Cyan
Write-Host "Cleanup complete!" -ForegroundColor Green
