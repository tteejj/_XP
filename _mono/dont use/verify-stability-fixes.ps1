# Diagnostic Script - Verify Critical Stability Fixes
# Run this after applying fixes to verify correct implementation

Write-Host "=== AXIOM-PHOENIX v4.0 STABILITY FIX VERIFICATION ===" -ForegroundColor Cyan
Write-Host ""

# Check if AllComponents.ps1 exists
$componentsFile = ".\AllComponents.ps1"
if (-not (Test-Path $componentsFile)) {
    Write-Host "ERROR: AllComponents.ps1 not found in current directory!" -ForegroundColor Red
    exit 1
}

Write-Host "Analyzing AllComponents.ps1..." -ForegroundColor Yellow
$content = Get-Content $componentsFile -Raw

# Test 1: Check CommandPalette ExecuteAction fix
Write-Host "`n[TEST 1] CommandPalette ExecuteAction Fix" -ForegroundColor Green
$executionPattern = 'ExecuteAction\s*\(\s*\$selectedAction\.Name\s*,\s*@\{\}\s*\)'
if ($content -match $executionPattern) {
    Write-Host "  ✓ PASS: ExecuteAction correctly called with empty hashtable parameter" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: ExecuteAction still missing second parameter!" -ForegroundColor Red
    Write-Host "    Fix: Add ', @{}' after $selectedAction.Name in CommandPalette.HandleInput" -ForegroundColor Yellow
}

# Test 2: Check for remaining ConsoleColor usage
Write-Host "`n[TEST 2] ConsoleColor Property Declarations" -ForegroundColor Green
$colorProperties = Select-String -InputObject $content -Pattern '\[\s*ConsoleColor\s*\]\s*\$\w+' -AllMatches
$colorCount = $colorProperties.Matches.Count

if ($colorCount -eq 0) {
    Write-Host "  ✓ PASS: No ConsoleColor property declarations found" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: Found $colorCount ConsoleColor property declarations!" -ForegroundColor Red
    Write-Host "    These need to be changed to [string] with hex values:" -ForegroundColor Yellow
    
    # Show first 5 matches
    $colorProperties.Matches | Select-Object -First 5 | ForEach-Object {
        Write-Host "    - $($_.Value)" -ForegroundColor Magenta
    }
}

# Test 3: Check specific components for hex colors
Write-Host "`n[TEST 3] Component Color Properties" -ForegroundColor Green

$componentsToCheck = @(
    @{Name="MultilineTextBoxComponent"; Props=@("BackgroundColor", "ForegroundColor", "BorderColor")},
    @{Name="Panel"; Props=@("BorderColor", "BackgroundColor")},
    @{Name="GroupPanel"; Props=@("BorderColor", "BackgroundColor")},
    @{Name="ListBox"; Props=@("ForegroundColor", "BackgroundColor", "BorderColor")}
)

foreach ($comp in $componentsToCheck) {
    Write-Host "  Checking $($comp.Name)..." -ForegroundColor Cyan
    
    # Extract the class definition
    $classPattern = "class\s+$($comp.Name)[\s\S]*?(?=^class|\z)"
    if ($content -match $classPattern) {
        $classContent = $matches[0]
        $allGood = $true
        
        foreach ($prop in $comp.Props) {
            # Check if property exists with hex default
            if ($classContent -match "\[\s*string\s*\]\s*\$$prop\s*=\s*`"#[0-9A-Fa-f]{6}`"") {
                Write-Host "    ✓ $prop uses hex string" -ForegroundColor Green
            } else {
                Write-Host "    ✗ $prop not using hex string!" -ForegroundColor Red
                $allGood = $false
            }
        }
        
        if (-not $allGood) {
            Write-Host "    Fix: Update color properties to use [string] with hex defaults" -ForegroundColor Yellow
        }
    } else {
        Write-Host "    ⚠ Could not find $($comp.Name) class definition" -ForegroundColor Yellow
    }
}

# Test 4: Check for ConsoleColor enum usage in code
Write-Host "`n[TEST 4] ConsoleColor Enum Usage" -ForegroundColor Green
$enumPattern = '\[ConsoleColor\]::\w+'
$enumMatches = Select-String -InputObject $content -Pattern $enumPattern -AllMatches

if ($enumMatches.Matches.Count -eq 0) {
    Write-Host "  ✓ PASS: No ConsoleColor enum usage found" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: Found $($enumMatches.Matches.Count) ConsoleColor enum usages!" -ForegroundColor Red
    Write-Host "    These need to be replaced with hex strings:" -ForegroundColor Yellow
    
    $enumMatches.Matches | Select-Object -First 5 -Unique | ForEach-Object {
        $colorName = $_.Value -replace '\[ConsoleColor\]::', ''
        $hexValue = switch ($colorName) {
            "Black" { "#000000" }
            "White" { "#FFFFFF" }
            "Gray" { "#808080" }
            "DarkGray" { "#A9A9A9" }
            "Red" { "#FF0000" }
            "DarkRed" { "#8B0000" }
            "Green" { "#00FF00" }
            "DarkGreen" { "#006400" }
            "Blue" { "#0000FF" }
            "DarkBlue" { "#00008B" }
            "Cyan" { "#00FFFF" }
            "DarkCyan" { "#008B8B" }
            "Yellow" { "#FFFF00" }
            "DarkYellow" { "#BDB76B" }
            "Magenta" { "#FF00FF" }
            "DarkMagenta" { "#8B008B" }
            default { "#FFFFFF" }
        }
        Write-Host "    - $($_.Value) → `"$hexValue`"" -ForegroundColor Magenta
    }
}

# Test 5: Check DateInputComponent OnRender
Write-Host "`n[TEST 5] DateInputComponent OnRender Method" -ForegroundColor Green
if ($content -match "class\s+DateInputComponent[\s\S]*?OnRender\s*\(\)[\s\S]*?try\s*\{[\s\S]*?Get-ThemeColor") {
    Write-Host "  ✓ PASS: DateInputComponent.OnRender uses Get-ThemeColor" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: DateInputComponent.OnRender not using theme colors!" -ForegroundColor Red
    Write-Host "    Fix: Update OnRender to use Get-ThemeColor instead of ConsoleColor" -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
$issues = 0

if (-not ($content -match $executionPattern)) { $issues++ }
if ($colorCount -gt 0) { $issues++ }
if ($enumMatches.Matches.Count -gt 0) { $issues++ }

if ($issues -eq 0) {
    Write-Host "All critical stability fixes appear to be applied correctly! ✓" -ForegroundColor Green
    Write-Host "The application should now run without type mismatch crashes." -ForegroundColor Green
} else {
    Write-Host "Found $issues issue(s) that need to be fixed." -ForegroundColor Red
    Write-Host "Please apply the fixes from the provided fix files." -ForegroundColor Yellow
}

Write-Host "`nRun './Start.ps1' to test the application after applying fixes." -ForegroundColor Cyan
