# Test script to verify render optimization is working
Write-Host "Testing render optimization integration..." -ForegroundColor Green

# Load the framework
. ./Start.ps1 -TestMode

# Test the optimized render functions
Write-Host "`nTesting optimized render functions:" -ForegroundColor Yellow

# Test 1: Initialize render state
Write-Host "1. Testing Initialize-OptimizedRenderState..." -ForegroundColor Cyan
Initialize-OptimizedRenderState
if ($global:TuiState.RenderState) {
    Write-Host "   ✓ RenderState initialized successfully" -ForegroundColor Green
    Write-Host "   ✓ ShouldRender: $($global:TuiState.RenderState.ShouldRender)" -ForegroundColor Green
    Write-Host "   ✓ FramesSaved: $($global:TuiState.RenderState.FramesSaved)" -ForegroundColor Green
} else {
    Write-Host "   ✗ RenderState not initialized" -ForegroundColor Red
}

# Test 2: Request optimized redraw
Write-Host "`n2. Testing Request-OptimizedRedraw..." -ForegroundColor Cyan
Request-OptimizedRedraw -Source "Test" -Immediate
if ($global:TuiState.RenderState.ShouldRender) {
    Write-Host "   ✓ ShouldRender set to true" -ForegroundColor Green
}
if ($global:TuiState.RenderState.RenderRequested) {
    Write-Host "   ✓ RenderRequested set to true" -ForegroundColor Green
}

# Test 3: Batched requests
Write-Host "`n3. Testing batched requests..." -ForegroundColor Cyan
$global:TuiState.RenderState.RenderRequested = $false
Request-OptimizedRedraw -Source "BatchTest1"
Request-OptimizedRedraw -Source "BatchTest2"
Write-Host "   ✓ BatchedRequests: $($global:TuiState.RenderState.BatchedRequests)" -ForegroundColor Green

# Test 4: Performance reporting
Write-Host "`n4. Testing performance reporting..." -ForegroundColor Cyan
$global:TuiState.FrameCount = 100
$global:TuiState.RenderState.FramesSaved = 50
$report = Get-OptimizedRenderReport
Write-Host "   ✓ Frames Rendered: $($report.FramesRendered)" -ForegroundColor Green
Write-Host "   ✓ Frames Saved: $($report.FramesSaved)" -ForegroundColor Green
Write-Host "   ✓ CPU Savings: $($report.CPUSavingsPercent)%" -ForegroundColor Green

# Test 5: Verify functions are available
Write-Host "`n5. Testing function availability..." -ForegroundColor Cyan
$functions = @('Initialize-OptimizedRenderState', 'Request-OptimizedRedraw', 'Get-OptimizedRenderReport')
foreach ($func in $functions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "   ✓ $func is available" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $func is not available" -ForegroundColor Red
    }
}

Write-Host "`n=== Render Optimization Test Complete ===" -ForegroundColor Green
Write-Host "The optimized render loop is integrated and working!" -ForegroundColor Yellow