# Quick fix for missing parentheses in setter method calls
# This fixes: SetForegroundColor(Get-ThemeColor ...) -> SetForegroundColor((Get-ThemeColor ...))

$ErrorActionPreference = "Stop"

Write-Host "Fixing missing parentheses in setter method calls..." -ForegroundColor Yellow

# Patterns to fix
$patterns = @(
    @{
        Pattern = '(Set(?:Foreground|Background|Border)Color\()Get-ThemeColor\s+'
        Replace = '$1(Get-ThemeColor '
    }
)

# Find all PS1 files
$files = Get-ChildItem -Path . -Include "*.ps1" -Recurse -File | Where-Object { 
    $_.Name -ne "fix-setter-parentheses.ps1" -and
    -not $_.Name.EndsWith(".backup") -and
    -not $_.Name.EndsWith(".old")
}

$totalFixed = 0

foreach ($file in $files) {
    Write-Host "Checking $($file.Name)..." -NoNewline
    
    $content = Get-Content $file -Raw
    $originalContent = $content
    $fileFixed = 0
    
    foreach ($pattern in $patterns) {
        $matches = ([regex]::Matches($content, $pattern.Pattern)).Count
        if ($matches -gt 0) {
            $content = $content -replace $pattern.Pattern, $pattern.Replace
            $fileFixed += $matches
        }
    }
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file -Value $content -NoNewline
        Write-Host " Fixed $fileFixed instances" -ForegroundColor Green
        $totalFixed += $fileFixed
    } else {
        Write-Host " No issues found" -ForegroundColor Gray
    }
}

Write-Host "`nTotal setter parentheses fixed: $totalFixed" -ForegroundColor Cyan
Write-Host "Fix complete!" -ForegroundColor Green
