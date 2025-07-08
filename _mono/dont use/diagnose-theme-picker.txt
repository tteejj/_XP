# Diagnostic script for ThemePickerScreen
Write-Host "Running ThemePickerScreen diagnostics..." -ForegroundColor Cyan

# Enable verbose output
$VerbosePreference = "Continue"

# Load all files
$files = @(
    "AllBaseClasses.ps1",
    "AllModels.ps1", 
    "AllComponents.ps1",
    "AllScreens.ps1",
    "AllFunctions.ps1",
    "AllServices.ps1",
    "AllRuntime.ps1"
)

foreach ($file in $files) {
    Write-Host "Loading $file..." -ForegroundColor Gray
    . (Join-Path $PSScriptRoot $file)
}

# Create a minimal test environment
Write-Host "`nCreating test environment..." -ForegroundColor Yellow

# Create theme manager
$themeManager = [ThemeManager]::new()
$themes = $themeManager.GetAvailableThemes()
Write-Host "Available themes from ThemeManager: $($themes -join ', ')" -ForegroundColor Green
Write-Host "Current theme: $($themeManager.ThemeName)" -ForegroundColor Green

# Test ScrollablePanel directly
Write-Host "`nTesting ScrollablePanel..." -ForegroundColor Yellow
$scrollPanel = [ScrollablePanel]::new("TestPanel")
$scrollPanel.Width = 60
$scrollPanel.Height = 15
$scrollPanel.UpdateContentDimensions()

Write-Host "ScrollablePanel created:" -ForegroundColor Green
Write-Host "  - ContentWidth: $($scrollPanel.ContentWidth)"
Write-Host "  - ContentHeight: $($scrollPanel.ContentHeight)"
Write-Host "  - Width: $($scrollPanel.Width)"
Write-Host "  - Height: $($scrollPanel.Height)"

# Add test children
for ($i = 0; $i -lt 5; $i++) {
    $testPanel = [Panel]::new("TestItem_$i")
    $testPanel.X = 0
    $testPanel.Y = $i * 3
    $testPanel.Width = 50
    $testPanel.Height = 2
    $testPanel.HasBorder = $false
    $testPanel.BackgroundColor = "#333333"
    
    $label = [LabelComponent]::new("Label_$i")
    $label.Text = "Test Item $i"
    $label.X = 1
    $label.Y = 0
    $testPanel.AddChild($label)
    
    $scrollPanel.AddChild($testPanel)
}

Write-Host "`nAdded $($scrollPanel.Children.Count) children to ScrollablePanel" -ForegroundColor Green

# Test ThemePickerScreen initialization
Write-Host "`nTesting ThemePickerScreen..." -ForegroundColor Yellow

# Create minimal service container
$serviceContainer = @{
    GetService = {
        param($name)
        if ($name -eq "ThemeManager") {
            return $themeManager
        }
        return $null
    }
}

$themeScreen = [ThemePickerScreen]::new($serviceContainer)
$themeScreen.Width = 120
$themeScreen.Height = 30

# Initialize the screen
$themeScreen.Initialize()

Write-Host "`nThemePickerScreen initialized:" -ForegroundColor Green
Write-Host "  - Themes found: $($themeScreen._themes -join ', ')"
Write-Host "  - Selected index: $($themeScreen._selectedIndex)"
Write-Host "  - Main panel children: $($themeScreen._mainPanel.Children.Count)"
Write-Host "  - Theme panel children: $($themeScreen._themePanel.Children.Count)"

# Check theme panel content
if ($themeScreen._themePanel.Children.Count -gt 0) {
    Write-Host "`nTheme panel children details:" -ForegroundColor Yellow
    foreach ($child in $themeScreen._themePanel.Children) {
        Write-Host "  - $($child.Name) at Y=$($child.Y), Height=$($child.Height)"
    }
} else {
    Write-Host "`nWARNING: No children in theme panel!" -ForegroundColor Red
}

# Check if UpdateMaxScroll exists
$updateMaxScrollMethod = $themeScreen._themePanel.GetType().GetMethod("UpdateMaxScroll")
if ($updateMaxScrollMethod) {
    Write-Host "`nUpdateMaxScroll method found" -ForegroundColor Green
} else {
    Write-Host "`nWARNING: UpdateMaxScroll method not found!" -ForegroundColor Red
}

Write-Host "`nDiagnostics complete." -ForegroundColor Cyan
