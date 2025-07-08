# Find where to insert FocusManager in AllServices.ps1

$filePath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllServices.ps1"
$content = Get-Content $filePath
$lines = @()
$lineNumber = 0

foreach ($line in $content) {
    $lineNumber++
    if ($line -match 'class (\w+)') {
        $className = $matches[1]
        Write-Host "Line $lineNumber`: class $className" -ForegroundColor Yellow
    }
    if ($line -match '# ===== CLASS: (\w+) =====') {
        $className = $matches[1]
        Write-Host "Line $lineNumber`: Comment for class $className" -ForegroundColor Cyan
    }
}

# Find DialogManager specifically
$dialogManagerLine = 0
for ($i = 0; $i -lt $content.Count; $i++) {
    if ($content[$i] -match 'class DialogManager') {
        $dialogManagerLine = $i + 1
        Write-Host "`nDialogManager found at line $dialogManagerLine" -ForegroundColor Green
        
        # Show context
        Write-Host "`nContext around DialogManager:"
        for ($j = [Math]::Max(0, $i - 10); $j -lt [Math]::Min($content.Count, $i + 5); $j++) {
            $prefix = if ($j -eq $i) { ">>> " } else { "    " }
            Write-Host "$prefix$($j + 1): $($content[$j])"
        }
        break
    }
}

# Check if FocusManager exists
$focusManagerFound = $false
foreach ($line in $content) {
    if ($line -match 'class FocusManager') {
        $focusManagerFound = $true
        break
    }
}

if ($focusManagerFound) {
    Write-Host "`nFocusManager class already exists!" -ForegroundColor Green
} else {
    Write-Host "`nFocusManager class NOT found - needs to be added!" -ForegroundColor Red
    Write-Host "Should be inserted before line $dialogManagerLine (DialogManager)" -ForegroundColor Yellow
}
