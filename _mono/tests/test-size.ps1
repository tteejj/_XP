Write-Host "Method 1 - Host.UI.RawUI: $($Host.UI.RawUI.WindowSize.Width) x $($Host.UI.RawUI.WindowSize.Height)"
Write-Host "Method 2 - Console Class: $([Console]::WindowWidth) x $([Console]::WindowHeight)"
$mode = mode con | Select-String "Columns:"
Write-Host "Method 3 - Mode command: $mode"
