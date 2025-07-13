# Emergency fix for the critical files that are preventing startup

$ErrorActionPreference = "Stop"

Write-Host "Emergency fix for critical files..." -ForegroundColor Yellow

# Files that MUST be fixed for startup
$criticalFiles = @(
    ".\Components\ACO.001_LabelComponent.ps1",
    ".\Base\ABC.004_UIElement.ps1",
    ".\Base\ABC.002_TuiCell.ps1"
)

foreach ($file in $criticalFiles) {
    if (Test-Path $file) {
        Write-Host "Fixing $file..." -NoNewline
        
        $content = Get-Content $file -Raw
        $originalContent = $content
        
        # Remove lines that contain ONLY BackgroundColor (and whitespace)
        $content = $content -replace '(?m)^\s*BackgroundColor\s*$\r?\n', ''
        
        # Remove lines that contain ONLY ForegroundColor (and whitespace)
        $content = $content -replace '(?m)^\s*ForegroundColor\s*$\r?\n', ''
        
        # Remove lines that contain ONLY BorderColor (and whitespace)
        $content = $content -replace '(?m)^\s*BorderColor\s*$\r?\n', ''
        
        # Fix "$null" string literals
        $content = $content -replace '\[string\]\s*\$BackgroundColor\s*=\s*"\$null"', '[string] $BackgroundColor = $null'
        $content = $content -replace '\[string\]\s*\$ForegroundColor\s*=\s*"\$null"', '[string] $ForegroundColor = $null'
        $content = $content -replace '\[string\]\s*\$BorderColor\s*=\s*"\$null"', '[string] $BorderColor = $null'
        
        if ($content -ne $originalContent) {
            Set-Content -Path $file -Value $content -NoNewline
            Write-Host " Fixed!" -ForegroundColor Green
        } else {
            Write-Host " No changes needed" -ForegroundColor Gray
        }
    } else {
        Write-Host "WARNING: $file not found!" -ForegroundColor Red
    }
}

Write-Host "`nNow try running: .\Start.ps1" -ForegroundColor Cyan
