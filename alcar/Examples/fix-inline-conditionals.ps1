#!/usr/bin/env pwsh
# Script to fix inline conditional expressions that PowerShell doesn't support

$ErrorActionPreference = 'Stop'

# Find all PS1 files
$files = Get-ChildItem -Path . -Filter "*.ps1" -Recurse | Where-Object { $_.FullName -notmatch 'fix-inline-conditionals\.ps1' }

$totalFixed = 0

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content
    $fileFixed = 0
    
    # Pattern 1: Variable assignment with inline if
    # $var = value - (if (condition) { x } else { y })
    $pattern1 = '(\$\w+\s*=\s*[^-\n]+)\s*-\s*\(if\s*\(([^)]+)\)\s*\{\s*(\d+)\s*\}\s*else\s*\{\s*(\d+)\s*\}\)'
    $content = [regex]::Replace($content, $pattern1, {
        param($match)
        $prefix = $match.Groups[1].Value
        $condition = $match.Groups[2].Value
        $trueValue = $match.Groups[3].Value
        $falseValue = $match.Groups[4].Value
        $varMatch = [regex]::Match($prefix, '\$(\w+)\s*=')
        $varName = $varMatch.Groups[1].Value
        
        @"
if ($condition) {
            $prefix - $trueValue
        } else {
            $prefix - $falseValue
        }
"@
    })
    
    # Pattern 2: Simple inline if assignments
    # $var = if (condition) { value1 } else { value2 }
    $pattern2 = '(\$\w+)\s*=\s*if\s*\(([^)]+)\)\s*\{\s*([^}]+)\s*\}\s*else\s*\{\s*([^}]+)\s*\}'
    while ($content -match $pattern2) {
        $content = [regex]::Replace($content, $pattern2, {
            param($match)
            $var = $match.Groups[1].Value
            $condition = $match.Groups[2].Value
            $trueValue = $match.Groups[3].Value.Trim()
            $falseValue = $match.Groups[4].Value.Trim()
            
            @"
if ($condition) {
            $var = $trueValue
        } else {
            $var = $falseValue
        }
"@
        }, 1)
        $fileFixed++
    }
    
    # Pattern 3: Inline if in expressions (common in calculations)
    # something + (if (condition) { x } else { y })
    $pattern3 = '([^=\n]+)\s*([+\-*/])\s*\(if\s*\(([^)]+)\)\s*\{\s*(\d+)\s*\}\s*else\s*\{\s*(\d+)\s*\}\)'
    while ($content -match $pattern3) {
        # Extract the full line for context
        $lines = $content -split "`n"
        $newLines = @()
        $modified = $false
        
        foreach ($line in $lines) {
            if ($line -match $pattern3 -and $line -match '^\s*\$(\w+)\s*=') {
                $varName = $matches[1]
                $fullMatch = [regex]::Match($line, $pattern3)
                $prefix = $fullMatch.Groups[1].Value
                $operator = $fullMatch.Groups[2].Value
                $condition = $fullMatch.Groups[3].Value
                $trueValue = $fullMatch.Groups[4].Value
                $falseValue = $fullMatch.Groups[5].Value
                
                $newLines += "        if ($condition) {"
                $newLines += "            `$$varName = $prefix $operator $trueValue"
                $newLines += "        } else {"
                $newLines += "            `$$varName = $prefix $operator $falseValue"
                $newLines += "        }"
                $modified = $true
                $fileFixed++
            } else {
                $newLines += $line
            }
        }
        
        if ($modified) {
            $content = $newLines -join "`n"
        } else {
            break
        }
    }
    
    if ($content -ne $originalContent) {
        Write-Host "Fixing $($file.Name)..." -ForegroundColor Yellow
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $totalFixed += $fileFixed
    }
}

Write-Host "`nFixed $totalFixed inline conditionals!" -ForegroundColor Green