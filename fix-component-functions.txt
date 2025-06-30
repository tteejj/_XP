# Component Function Fix Script
# This script removes the global: prefix from function definitions

$componentPaths = @(
    "components\advanced-data-components.psm1",
    "components\advanced-input-components.psm1", 
    "components\tui-components.psm1",
    "layout\panels.psm1",
    "modules\dialog-system.psm1",
    "modules\event-system.psm1",
    "modules\state-manager.psm1",
    "modules\text-resources.psm1",
    "modules\theme-manager.psm1",
    "services\keybindings.psm1",
    "services\navigation.psm1",
    "services\task-services.psm1",
    "utilities\focus-manager.psm1",
    "utilities\layout-manager.psm1",
    "utilities\positioning-helper.psm1"
)

$baseDir = "C:\Users\jhnhe\Documents\GitHub\_XP\"
$totalFixed = 0

foreach ($relativePath in $componentPaths) {
    $fullPath = Join-Path $baseDir $relativePath
    
    if (Test-Path $fullPath) {
        Write-Host "`nProcessing: $relativePath" -ForegroundColor Cyan
        
        $content = Get-Content $fullPath -Raw
        $backupPath = "$fullPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        $content | Set-Content $backupPath
        
        # Replace function global:FunctionName with function FunctionName
        $pattern = 'function\s+global:(\w+)'
        $replacement = 'function $1'
        
        $matches = [regex]::Matches($content, $pattern)
        $count = $matches.Count
        
        if ($count -gt 0) {
            $updatedContent = $content -replace $pattern, $replacement
            $updatedContent | Set-Content $fullPath
            
            Write-Host "  Fixed $count function definitions" -ForegroundColor Green
            foreach ($match in $matches) {
                Write-Host "    - $($match.Groups[1].Value)" -ForegroundColor DarkGray
            }
            $totalFixed += $count
        } else {
            Write-Host "  No global: prefixes found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nWARNING: File not found: $fullPath" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Total functions fixed: $totalFixed" -ForegroundColor Green
Write-Host "All component files have been updated!" -ForegroundColor Green
