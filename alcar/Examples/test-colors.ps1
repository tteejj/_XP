#!/usr/bin/env pwsh
# Test color rendering

. ./Core/vt100.ps1

Write-Host "Testing colors:" -ForegroundColor Cyan

# Test yellow background
$output = [VT]::RGBBG(255, 255, 0) + [VT]::RGB(0, 0, 0) + " This should have yellow background " + [VT]::Reset()
[Console]::Write($output)
Write-Host ""

# Test edit mode style
$output2 = [VT]::RGBBG(255, 255, 0) + [VT]::RGB(0, 0, 0) + " EDIT MODE TEST ▌" + [VT]::Reset()
[Console]::Write($output2)
Write-Host ""

# Test selected style
$output3 = [VT]::Selected() + " > Selected item" + [VT]::Reset()
[Console]::Write($output3)
Write-Host ""

Write-Host "`nIf you see yellow background above, colors are working" -ForegroundColor Green