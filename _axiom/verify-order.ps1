# verify-order.ps1 - Verifies class ordering
$content = Get-Content "all-classes.ps1" -Raw
$lines = $content -split "`n"

Write-Host "Checking class ordering..." -ForegroundColor Cyan

# Find all class definitions and their line numbers
$classes = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^(class|enum)\s+(\w+)(?:\s*:\s*(\w+))?') {
        $classes += @{
            Type = $Matches[1]
            Name = $Matches[2]
            Base = $Matches[3]
            Line = $i + 1
        }
    }
}

Write-Host "Found $($classes.Count) type definitions" -ForegroundColor Gray

# Check that base classes come before derived classes
$defined = @{}
$errors = 0

foreach ($class in $classes) {
    $defined[$class.Name] = $class.Line
    
    if ($class.Base -and -not $defined.ContainsKey($class.Base)) {
        Write-Host "❌ ERROR: $($class.Name) (line $($class.Line)) inherits from $($class.Base) which hasn't been defined yet" -ForegroundColor Red
        $errors++
    }
}

if ($errors -eq 0) {
    Write-Host "✅ All classes are properly ordered!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Found $errors ordering errors" -ForegroundColor Red
}

# Show first few definitions
Write-Host "`nFirst 10 definitions:" -ForegroundColor Yellow
$classes | Select-Object -First 10 | ForEach-Object {
    $baseInfo = if ($_.Base) { ": $($_.Base)" } else { "" }
    Write-Host "  $($_.Type) $($_.Name)$baseInfo (line $($_.Line))" -ForegroundColor DarkGray
}
