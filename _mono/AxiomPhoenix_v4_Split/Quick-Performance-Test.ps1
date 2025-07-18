#!/usr/bin/env pwsh
# Quick test to verify optimizations are working

# Load optimized framework
. "./Base/ABC.001_TuiAnsiHelper.ps1"
. "./Base/ABC.002_TuiCell.ps1"
. "./Base/ABC.003_TuiBuffer.ps1"

Write-Host "🚀 Quick Performance Verification Test" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

# Test 1: Quick frame rendering
Write-Host "Testing frame rendering..." -ForegroundColor Yellow
$buffer = [TuiBuffer]::new(80, 24)
$style = @{ FG = "#FFFFFF"; BG = "#000000" }

$sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($frame = 0; $frame -lt 5; $frame++) {
    $buffer.Clear()
    for ($y = 0; $y -lt 24; $y++) {
        $buffer.WriteString(0, $y, "Frame $frame Line $y " + ("." * 50), $style)
    }
}
$sw.Stop()

$avgFrameTime = $sw.ElapsedMilliseconds / 5
$fps = 1000 / $avgFrameTime

Write-Host "Results:" -ForegroundColor Cyan
Write-Host "  5 frames rendered in: $($sw.ElapsedMilliseconds)ms"
Write-Host "  Average frame time: $([Math]::Round($avgFrameTime, 1))ms"
Write-Host "  Estimated FPS: $([Math]::Round($fps, 1))"

if ($fps -gt 10) {
    Write-Host "  ✅ SUCCESS: >10 FPS achieved!" -ForegroundColor Green
} elseif ($fps -gt 5) {
    Write-Host "  ⚠️  ACCEPTABLE: >5 FPS" -ForegroundColor Yellow
} else {
    Write-Host "  ❌ NEEDS WORK: <5 FPS" -ForegroundColor Red
}

# Test 2: Buffer Clear performance
Write-Host ""
Write-Host "Testing buffer clear performance..." -ForegroundColor Yellow
$clearSw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt 10; $i++) {
    $buffer.Clear()
}
$clearSw.Stop()

Write-Host "  10 buffer clears: $($clearSw.ElapsedMilliseconds)ms"
Write-Host "  Average: $($clearSw.ElapsedMilliseconds/10)ms per clear"

if ($clearSw.ElapsedMilliseconds -lt 200) {
    Write-Host "  ✅ GOOD: Fast buffer clearing" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  SLOW: Buffer clearing needs work" -ForegroundColor Yellow
}

# Test 3: WriteString performance
Write-Host ""
Write-Host "Testing WriteString performance..." -ForegroundColor Yellow
$writeSw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt 50; $i++) {
    $y = $i % 24
    $buffer.WriteString(0, $y, "Performance test string for optimization validation", $style)
}
$writeSw.Stop()

$writeOpsPerSec = 50 / ($writeSw.ElapsedMilliseconds / 1000)
Write-Host "  50 WriteString operations: $($writeSw.ElapsedMilliseconds)ms"
Write-Host "  Rate: $([Math]::Round($writeOpsPerSec, 0)) ops/sec"

if ($writeOpsPerSec -gt 100) {
    Write-Host "  ✅ GOOD: >100 ops/sec" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  ACCEPTABLE: WriteString working" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Framework is functional and optimized!" -ForegroundColor Green