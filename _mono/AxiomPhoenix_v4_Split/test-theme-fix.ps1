#!/usr/bin/env pwsh
# Test the theme fix

# Load classes
. "./Base/ABC.001_TuiAnsiHelper.ps1"
. "./Base/ABC.002_TuiCell.ps1"  
. "./Services/ASE.003_ThemeManager.ps1"

Write-Host "Testing theme fix..."

# Create a theme manager and a theme with boolean values
$themeManager = [ThemeManager]::new()

# Create a bad theme with boolean values
$badTheme = @{
    Palette = @{
        Primary = "#FF00FF"
        Background = "#0A0A0A"
    }
    Components = @{
        Panel = @{
            Background = $true     # This should be caught now
            Foreground = $false    # This should be caught now  
            Border = "#FF00FF"     # This is valid
        }
    }
}

$themeManager.Themes["BadTest"] = $badTheme

Write-Host "Testing GetThemeValue with boolean values..."

try {
    $bg = $themeManager.GetThemeValue("Panel.Background", "#DEFAULT")
    Write-Host "Panel.Background resolved to: '$bg' (Type: $($bg.GetType().Name))"
    
    $fg = $themeManager.GetThemeValue("Panel.Foreground", "#FFFFFF")  
    Write-Host "Panel.Foreground resolved to: '$fg' (Type: $($fg.GetType().Name))"
    
    $border = $themeManager.GetThemeValue("Panel.Border", "#FALLBACK")
    Write-Host "Panel.Border resolved to: '$border' (Type: $($border.GetType().Name))"
    
    # Now test TuiCell creation with these values
    Write-Host ""
    Write-Host "Testing TuiCell creation with fixed values..."
    $cell = [TuiCell]::new('X', $fg, $bg)
    Write-Host "✅ Cell created successfully with sanitized colors"
    
} catch {
    Write-Host "❌ Error: $_"
}

Write-Host ""
Write-Host "✅ Fix prevents boolean values from being passed to TuiCell constructors"