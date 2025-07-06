# fix-original-syntax.ps1 - Fixes syntax errors in original PSM1 files
[CmdletBinding()]
param(
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "🔍 Scanning for files with syntax issues..." -ForegroundColor Cyan

# Find all PSM1 files
$moduleFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.psm1" -Recurse | 
    Where-Object { $_.DirectoryName -notmatch "_UPGRADE_DOCUMENTATION" }

$totalFixed = 0

foreach ($file in $moduleFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Fix patterns like $this.{_propertyName} -> $this._propertyName
    $pattern1 = '\$this\.\{(_\w+)\}'
    $matches1 = [regex]::Matches($content, $pattern1)
    if ($matches1.Count -gt 0) {
        Write-Host "`n📄 $($file.Name)" -ForegroundColor Yellow
        Write-Host "  Found $($matches1.Count) instances of `$this.{_property} pattern" -ForegroundColor Gray
        $content = [regex]::Replace($content, $pattern1, '$this.$1')
        $totalFixed += $matches1.Count
    }
    
    # Fix patterns like [models.ClassName] -> [ClassName] (for known classes)
    $knownClasses = @('PmcTask', 'PmcProject', 'UIElement', 'ServiceContainer', 'ValidationBase')
    foreach ($className in $knownClasses) {
        $pattern2 = '\[[\w.]+\.(' + [regex]::Escape($className) + ')\]'
        $matches2 = [regex]::Matches($content, $pattern2)
        if ($matches2.Count -gt 0) {
            if ($matches1.Count -eq 0) {
                Write-Host "`n📄 $($file.Name)" -ForegroundColor Yellow
            }
            Write-Host "  Found $($matches2.Count) instances of module-qualified [$className]" -ForegroundColor Gray
            $content = [regex]::Replace($content, $pattern2, '[$1]')
            $totalFixed += $matches2.Count
        }
    }
    
    # Only write if changes were made
    if ($content -ne $originalContent) {
        if ($WhatIf) {
            Write-Host "  Would fix this file" -ForegroundColor DarkCyan
        } else {
            # Create backup
            $backupPath = "$($file.FullName).backup"
            Copy-Item -Path $file.FullName -Destination $backupPath -Force
            
            # Write fixed content
            Set-Content -Path $file.FullName -Value $content -Encoding UTF8
            Write-Host "  ✓ Fixed and backed up to .backup" -ForegroundColor Green
        }
    }
}

Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "  Total issues found: $totalFixed" -ForegroundColor White

if ($WhatIf) {
    Write-Host "`n⚠️  This was a dry run. To apply fixes, run without -WhatIf" -ForegroundColor Yellow
} else {
    Write-Host "`n✅ Fixes applied! Original files backed up with .backup extension" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Run the extractor again: .\fixed-extractor.ps1" -ForegroundColor White
    Write-Host "  2. Test the classes: .\test-classes.ps1" -ForegroundColor White
}

# Also create a restore script
if (-not $WhatIf) {
    $restoreScript = @'
# restore-backups.ps1 - Restores original files from backups
Get-ChildItem -Path . -Filter "*.backup" -Recurse | ForEach-Object {
    $originalPath = $_.FullName.Replace('.backup', '')
    Copy-Item -Path $_.FullName -Destination $originalPath -Force
    Remove-Item -Path $_.FullName
    Write-Host "Restored: $($_.Name.Replace('.backup', ''))"
}
'@
    Set-Content -Path "restore-backups.ps1" -Value $restoreScript
    Write-Host "`n💾 Created restore-backups.ps1 in case you need to undo changes" -ForegroundColor DarkGray
}