# Fix for JSON serialization depth issue in Write-Log
# This script patches the Write-Log function to handle circular references

$filePath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllFunctions.ps1"
$content = Get-Content $filePath -Raw

# Find and replace the problematic ConvertTo-Json line
$oldPattern = @'
        if \(\$Data\) \{
            \$dataJson = \$Data \| ConvertTo-Json -Compress -Depth 10
            \$finalMessage = "\$Message \| Data: \$dataJson"
        \}
'@

$newCode = @'
        if ($Data) {
            try {
                # Handle UIElement objects specially to avoid circular reference issues
                if ($Data -is [UIElement]) {
                    $finalMessage = "$Message | Data: [UIElement: Name=$($Data.Name), Type=$($Data.GetType().Name)]"
                }
                elseif ($Data -is [System.Collections.IEnumerable] -and -not ($Data -is [string])) {
                    # Handle collections
                    $count = 0
                    try { $count = @($Data).Count } catch { }
                    $finalMessage = "$Message | Data: [Collection with $count items]"
                }
                else {
                    # For other objects, try to serialize but catch any errors
                    $dataJson = $Data | ConvertTo-Json -Compress -Depth 3 -ErrorAction Stop
                    $finalMessage = "$Message | Data: $dataJson"
                }
            }
            catch {
                # If serialization fails, just use ToString()
                $finalMessage = "$Message | Data: $($Data.ToString())"
            }
        }
'@

# Use simpler approach - find the exact lines
$lines = $content -split "`r?`n"
$newLines = @()
$i = 0

while ($i -lt $lines.Count) {
    if ($lines[$i] -match '^\s*if \(\$Data\) \{' -and $i -lt $lines.Count - 3) {
        if ($lines[$i+1] -match '\$dataJson = \$Data \| ConvertTo-Json' -and 
            $lines[$i+2] -match '\$finalMessage = "\$Message \| Data: \$dataJson"') {
            
            # Found the pattern, replace with new code
            $newLines += '        if ($Data) {'
            $newLines += '            try {'
            $newLines += '                # Handle UIElement objects specially to avoid circular reference issues'
            $newLines += '                if ($Data -is [UIElement]) {'
            $newLines += '                    $finalMessage = "$Message | Data: [UIElement: Name=$($Data.Name), Type=$($Data.GetType().Name)]"'
            $newLines += '                }'
            $newLines += '                elseif ($Data -is [System.Collections.IEnumerable] -and -not ($Data -is [string])) {'
            $newLines += '                    # Handle collections'
            $newLines += '                    $count = 0'
            $newLines += '                    try { $count = @($Data).Count } catch { }'
            $newLines += '                    $finalMessage = "$Message | Data: [Collection with $count items]"'
            $newLines += '                }'
            $newLines += '                else {'
            $newLines += '                    # For other objects, try to serialize but catch any errors'
            $newLines += '                    $dataJson = $Data | ConvertTo-Json -Compress -Depth 3 -ErrorAction Stop'
            $newLines += '                    $finalMessage = "$Message | Data: $dataJson"'
            $newLines += '                }'
            $newLines += '            }'
            $newLines += '            catch {'
            $newLines += '                # If serialization fails, just use ToString()'
            $newLines += '                $finalMessage = "$Message | Data: $($Data.ToString())"'
            $newLines += '            }'
            $newLines += '        }'
            
            $i += 4 # Skip the old lines
            continue
        }
    }
    
    $newLines += $lines[$i]
    $i++
}

# Write the updated content back
$newContent = $newLines -join "`r`n"
Set-Content $filePath $newContent -NoNewline

Write-Host "Successfully patched Write-Log function to handle circular references" -ForegroundColor Green
