#!/usr/bin/env pwsh

# Add debug logging to track IsFocused property changes
# This will help us catch exactly what's resetting the focus

$ErrorActionPreference = "Stop"

Write-Host "Adding debug logging to track IsFocused property changes..." -ForegroundColor Yellow

# Clear previous debug log
if (Test-Path "/tmp/focus-property-debug.log") {
    Remove-Item "/tmp/focus-property-debug.log" -Force
}

# Create a script to override the IsFocused property with debug logging
$debugScript = @'
# Override IsFocused property with debug logging for TitleBox components
$originalMethod = [TextBoxComponent].GetProperty("IsFocused")

# Add debug to existing TextBoxComponent instances
Get-Variable -Name "*" -Scope Global | ForEach-Object {
    if ($_.Value -is [TextBoxComponent] -and $_.Value.Name -eq "TitleBox") {
        $component = $_.Value
        
        # Add debug logging to track property changes
        $component | Add-Member -MemberType ScriptProperty -Name "IsFocused" -Value {
            return $this._isFocused
        } -SecondValue {
            param($value)
            if ($value -ne $this._isFocused) {
                $timestamp = Get-Date -Format "HH:mm:ss.fff"
                $stack = (Get-PSCallStack | Select-Object -First 3 | ForEach-Object { "$($_.Command):$($_.ScriptLineNumber)" }) -join " -> "
                "[$timestamp] TitleBox IsFocused: $($this._isFocused) -> $value | Stack: $stack" | Out-File "/tmp/focus-property-debug.log" -Append -Force
            }
            $this._isFocused = $value
        } -Force
    }
}
'@

Write-Host "Debug script created. This would require runtime modification to be effective." -ForegroundColor Green
Write-Host "The issue is likely that something is directly setting IsFocused = false without going through proper methods." -ForegroundColor Yellow