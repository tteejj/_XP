# Comprehensive fix for all JSON serialization issues

Write-Host "=== Comprehensive JSON Serialization Fix ===" -ForegroundColor Cyan

# 1. Fix Write-Log function in AllFunctions.ps1
Write-Host "`n1. Fixing Write-Log function..." -ForegroundColor Yellow

$file = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllFunctions.ps1"
$content = Get-Content $file -Raw

# Replace the problematic section in Write-Log
$pattern = '(\$finalMessage = \$Message\s*\n\s*if \(\$Data\) \{[\s\S]*?\$finalMessage = "\$Message \| Data: \$dataJson"\s*\n\s*\})'
$replacement = @'
$finalMessage = $Message
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
                    # Use ErrorAction Stop to catch serialization errors  
                    $dataJson = $null
                    try {
                        $dataJson = $Data | ConvertTo-Json -Compress -Depth 3 -ErrorAction Stop
                    } catch {
                        # Serialization failed, use simple representation
                    }
                    
                    if ($dataJson) {
                        $finalMessage = "$Message | Data: $dataJson"
                    } else {
                        $finalMessage = "$Message | Data: $($Data.ToString())"
                    }
                }
            }
            catch {
                # If all else fails, just use ToString()
                $finalMessage = "$Message | Data: [Object of type $($Data.GetType().Name)]"
            }
        }
'@

if ($content -match $pattern) {
    $content = $content -replace $pattern, $replacement
    Set-Content $file $content -NoNewline
    Write-Host "  ✓ Fixed Write-Log function" -ForegroundColor Green
} else {
    Write-Host "  ! Pattern not found, attempting line-by-line fix..." -ForegroundColor Yellow
    
    # Alternative approach - find and replace specific lines
    $lines = $content -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '\$dataJson = \$Data \| ConvertTo-Json -Compress -Depth 10') {
            # Found the line, replace this section
            $indent = if ($lines[$i] -match '^(\s*)') { $matches[1] } else { "" }
            
            # Find the start of the if block
            $startIdx = $i - 1
            while ($startIdx -ge 0 -and $lines[$startIdx] -notmatch 'if \(\$Data\)') {
                $startIdx--
            }
            
            # Find the end of the if block
            $endIdx = $i + 1
            while ($endIdx -lt $lines.Count -and $lines[$endIdx] -notmatch '^\s*\}') {
                $endIdx++
            }
            
            if ($startIdx -ge 0 -and $endIdx -lt $lines.Count) {
                # Replace the section
                $newSection = @(
                    "${indent}if (`$Data) {"
                    "${indent}    try {"
                    "${indent}        # Handle UIElement objects specially to avoid circular reference issues"
                    "${indent}        if (`$Data -is [UIElement]) {"
                    "${indent}            `$finalMessage = ""`$Message | Data: [UIElement: Name=`$(`$Data.Name), Type=`$(`$Data.GetType().Name)]"""
                    "${indent}        }"
                    "${indent}        elseif (`$Data -is [System.Collections.IEnumerable] -and -not (`$Data -is [string])) {"
                    "${indent}            # Handle collections"
                    "${indent}            `$count = 0"
                    "${indent}            try { `$count = @(`$Data).Count } catch { }"
                    "${indent}            `$finalMessage = ""`$Message | Data: [Collection with `$count items]"""
                    "${indent}        }"
                    "${indent}        else {"
                    "${indent}            # For other objects, try to serialize but catch any errors"
                    "${indent}            `$dataJson = `$null"
                    "${indent}            try {"
                    "${indent}                `$dataJson = `$Data | ConvertTo-Json -Compress -Depth 3 -ErrorAction Stop"
                    "${indent}            } catch {"
                    "${indent}                # Serialization failed"
                    "${indent}            }"
                    "${indent}            if (`$dataJson) {"
                    "${indent}                `$finalMessage = ""`$Message | Data: `$dataJson"""
                    "${indent}            } else {"
                    "${indent}                `$finalMessage = ""`$Message | Data: `$(`$Data.ToString())"""
                    "${indent}            }"
                    "${indent}        }"
                    "${indent}    }"
                    "${indent}    catch {"
                    "${indent}        # If all else fails, use type name"
                    "${indent}        `$finalMessage = ""`$Message | Data: [Object of type `$(`$Data.GetType().Name)]"""
                    "${indent}    }"
                    "${indent}}"
                )
                
                # Remove old lines and insert new ones
                $lines = $lines[0..($startIdx-1)] + $newSection + $lines[($endIdx+1)..($lines.Count-1)]
                $content = $lines -join "`r`n"
                Set-Content $file $content -NoNewline
                Write-Host "  ✓ Fixed Write-Log function (line-by-line)" -ForegroundColor Green
                break
            }
        }
    }
}

# 2. Fix Logger.LogException in AllServices.ps1
Write-Host "`n2. Fixing Logger.LogException method..." -ForegroundColor Yellow

$file = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AllServices.ps1"
$content = Get-Content $file -Raw

# Fix the LogException method
$oldLine = '$detailsJson = $exceptionDetails | ConvertTo-Json -Compress'
$newLine = @'
try {
            $detailsJson = $exceptionDetails | ConvertTo-Json -Compress -Depth 3 -ErrorAction Stop
        } catch {
            # If serialization fails, create a simple string representation
            $detailsJson = "ExceptionType: $($exceptionDetails.ExceptionType), Message: $($exceptionDetails.ExceptionMessage)"
        }
'@

if ($content -match [regex]::Escape($oldLine)) {
    $content = $content -replace [regex]::Escape($oldLine), $newLine
    Set-Content $file $content -NoNewline
    Write-Host "  ✓ Fixed Logger.LogException method" -ForegroundColor Green
} else {
    Write-Host "  ! Logger.LogException pattern not found" -ForegroundColor Yellow
}

# 3. Add defensive Out-Null to methods that might output objects
Write-Host "`n3. Adding defensive Out-Null statements..." -ForegroundColor Yellow

$fixes = @(
    @{
        File = "AllComponents.ps1"
        Pattern = '\$global:TuiState\.OverlayStack\.Add\(\$this\)'
        Replace = '$global:TuiState.OverlayStack.Add($this) | Out-Null'
    },
    @{
        File = "AllComponents.ps1"
        Pattern = '\$global:TuiState\.OverlayStack\.Remove\(\$this\)'
        Replace = '$global:TuiState.OverlayStack.Remove($this) | Out-Null'
    },
    @{
        File = "AllServices.ps1"
        Pattern = 'New-Item -ItemType Directory -Path \$logDir -Force \| Out-Null'
        Replace = 'New-Item -ItemType Directory -Path $logDir -Force | Out-Null'
        Skip = $true  # Already has Out-Null
    }
)

foreach ($fix in $fixes) {
    if ($fix.Skip) { continue }
    
    $file = Join-Path "C:\Users\jhnhe\Documents\GitHub\_XP\_mono" $fix.File
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        if ($content -match [regex]::Escape($fix.Pattern) -and $fix.Pattern -notmatch 'Out-Null') {
            $content = $content -replace [regex]::Escape($fix.Pattern), $fix.Replace
            Set-Content $file $content -NoNewline
            Write-Host "  ✓ Fixed: $($fix.Pattern) in $($fix.File)" -ForegroundColor Green
        }
    }
}

# 4. Create a startup wrapper to suppress verbose object output
Write-Host "`n4. Creating startup wrapper..." -ForegroundColor Yellow

$wrapper = @'
# Startup wrapper to prevent JSON serialization warnings
# Add this to the beginning of your PowerShell session or Start.ps1

# Suppress JSON depth warnings
$global:WarningPreference = 'SilentlyContinue'

# Override Format-Default to prevent deep object serialization
if (-not $global:_OriginalFormatDefault) {
    $global:_OriginalFormatDefault = Get-Command Format-Default -ErrorAction SilentlyContinue
}

# Run the original command with the warnings suppressed
$originalWarningPreference = $WarningPreference
try {
    & $args[0]
} finally {
    $global:WarningPreference = $originalWarningPreference
}
'@

$wrapperPath = "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\run-axiom-phoenix.ps1"
Set-Content $wrapperPath @"
$wrapper
"@

# Create the actual runner
$runnerContent = @'
param([string]$StartScript = ".\Start.ps1")

# This will run the application with warnings suppressed
$originalWarningPreference = $WarningPreference
$WarningPreference = 'SilentlyContinue'

try {
    & $StartScript
} finally {
    $WarningPreference = $originalWarningPreference
}
'@

Set-Content $wrapperPath $runnerContent

Write-Host "  ✓ Created run-axiom-phoenix.ps1 wrapper" -ForegroundColor Green

Write-Host "`n=== Fix Complete ===" -ForegroundColor Green
Write-Host "The JSON serialization warnings should now be resolved." -ForegroundColor Green
Write-Host "`nYou can now run the application using:" -ForegroundColor Cyan
Write-Host "  .\Start.ps1" -ForegroundColor White
Write-Host "`nOr use the wrapper to suppress any remaining warnings:" -ForegroundColor Cyan
Write-Host "  .\run-axiom-phoenix.ps1" -ForegroundColor White
