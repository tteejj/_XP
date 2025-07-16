#!/usr/bin/env pwsh
# Fix component type issues across all screen files

$files = Get-ChildItem -Path "Screens" -Filter "*.ps1"

foreach ($file in $files) {
    Write-Host "Fixing $($file.Name)..." -ForegroundColor Yellow
    
    # Read content
    $content = Get-Content $file.FullName -Raw
    
    # Fix component type names
    $content = $content -replace '\[Label\]', '[LabelComponent]'
    $content = $content -replace '\[ComboBox\]', '[ComboBoxComponent]'
    $content = $content -replace '\[CheckBox\]', '[CheckBoxComponent]'
    
    # Fix BorderStyle
    $content = $content -replace 'BorderStyle = \[BorderStyle\]::Single', 'HasBorder = $true'
    $content = $content -replace 'BorderStyle = \[BorderStyle\]::None', 'HasBorder = $false'
    $content = $content -replace '\.BorderStyle = "Single"', '.HasBorder = $true'
    $content = $content -replace '\.BorderStyle = "None"', '.HasBorder = $false'
    
    # Write back
    $content | Set-Content $file.FullName -NoNewline
    
    Write-Host "  ✓ Fixed $($file.Name)" -ForegroundColor Green
}

Write-Host "All files fixed!" -ForegroundColor Cyan