# Check-ExecuteAction.ps1
# This script verifies that all ExecuteAction calls have been fixed

Write-Host "`nChecking for ExecuteAction calls missing second parameter..." -ForegroundColor Cyan

$searchPath = $PSScriptRoot
$problemFiles = @()

# Search for ExecuteAction calls with only one parameter
Get-ChildItem -Path $searchPath -Filter "*.ps1" -Recurse | ForEach-Object {
    # Skip disabled files
    if ($_.Name -like "*.DISABLED") { return }
    
    $content = Get-Content $_.FullName -Raw
    
    # Look for ExecuteAction calls with only one parameter (no comma after first parameter)
    # This pattern matches ExecuteAction("something") without a comma and second parameter
    $pattern = '\.ExecuteAction\s*\(\s*["''][^"'']+["'']\s*\)\s*(?![,])'
    
    if ($content -match $pattern) {
        $matches = [regex]::Matches($content, $pattern)
        foreach ($match in $matches) {
            # Get line number
            $lines = $content.Split("`n")
            $lineNum = 1
            $charCount = 0
            foreach ($line in $lines) {
                $charCount += $line.Length + 1  # +1 for newline
                if ($charCount -gt $match.Index) {
                    break
                }
                $lineNum++
            }
            
            $problemFiles += [PSCustomObject]@{
                File = $_.FullName.Replace("$searchPath\", "")
                Line = $lineNum
                Code = $match.Value.Trim()
            }
        }
    }
}

if ($problemFiles.Count -eq 0) {
    Write-Host "`nAll ExecuteAction calls appear to be fixed!" -ForegroundColor Green
} else {
    Write-Host "`nFound $($problemFiles.Count) ExecuteAction calls missing second parameter:" -ForegroundColor Red
    $problemFiles | Format-Table -AutoSize
    
    Write-Host "`nTo fix, add ', @{}' after the action name in each call." -ForegroundColor Yellow
    Write-Host "Example: ExecuteAction(`"navigation.dashboard`") should be ExecuteAction(`"navigation.dashboard`", @{})" -ForegroundColor Yellow
}

Write-Host "`n" -NoNewline
Write-Host "CRITICAL: " -ForegroundColor Red -NoNewline
Write-Host "PowerShell caches class definitions!" -ForegroundColor Yellow
Write-Host "You MUST restart PowerShell for ALL fixes to take effect, including:" -ForegroundColor Yellow
Write-Host "  - TuiCell constructor fixes (4-parameter constructor)" -ForegroundColor Cyan
write-Host "  - ExecuteAction parameter fixes" -ForegroundColor Cyan
Write-Host "  - CommandPalette Enter key behavior" -ForegroundColor Cyan
Write-Host "`nRestart PowerShell and run Start.ps1 again." -ForegroundColor Green
