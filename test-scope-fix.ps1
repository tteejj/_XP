# Test TUI Scope Fix
# Verifies that the global scope fix allows proper TUI rendering

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Testing TUI Scope Fix..." -ForegroundColor Cyan

try {
    # Import modules with global scope
    Write-Host "  1. Loading TUI Engine..." -ForegroundColor Yellow
    Import-Module ".\modules\tui-engine-v2.psm1" -Global -Force
    
    Write-Host "  2. Loading Components..." -ForegroundColor Yellow
    Import-Module ".\components\tui-components.psm1" -Global -Force
    
    Write-Host "  3. Loading Theme Manager..." -ForegroundColor Yellow
    Import-Module ".\modules\theme-manager.psm1" -Global -Force
    
    # Check if global state is accessible
    Write-Host "  4. Initializing TUI Engine..." -ForegroundColor Yellow
    Initialize-TuiEngine -Width 60 -Height 20
    
    # Verify global state exists
    if ($global:TuiState) {
        Write-Host "  ✓ Global TUI state created successfully" -ForegroundColor Green
        Write-Host "    Buffer size: $($global:TuiState.BufferWidth) x $($global:TuiState.BufferHeight)" -ForegroundColor DarkGray
    } else {
        throw "Global TUI state not found"
    }
    
    # Test component creation (this should now work with global state)
    Write-Host "  5. Testing component creation..." -ForegroundColor Yellow
    $testLabel = New-TuiLabel -Props @{
        X = 5
        Y = 5
        Text = "Scope Fix Test"
        Name = "TestLabel"
    }
    
    if ($testLabel) {
        Write-Host "  ✓ Component created successfully" -ForegroundColor Green
    } else {
        throw "Component creation failed"
    }
    
    # Test component rendering (this requires access to global state)
    Write-Host "  6. Testing component rendering..." -ForegroundColor Yellow
    
    # Clear the buffer first
    Clear-BackBuffer
    
    # Try to render the component
    try {
        & $testLabel.Render -self $testLabel
        Write-Host "  ✓ Component rendered without errors" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Component rendering failed: $_" -ForegroundColor Red
        throw
    }
    
    # Test buffer write functions
    Write-Host "  7. Testing buffer operations..." -ForegroundColor Yellow
    Write-BufferString -X 10 -Y 10 -Text "Buffer Test" -ForegroundColor White
    Write-Host "  ✓ Buffer operations working" -ForegroundColor Green
    
    # Clean up
    Write-Host "  8. Cleaning up..." -ForegroundColor Yellow
    try {
        Cleanup-TuiEngine
    } catch {
        # Cleanup might fail if not fully initialized, that's OK for this test
    }
    
    Write-Host "`n✅ TUI Scope Fix Verification PASSED" -ForegroundColor Green
    Write-Host "   The TUI system can now access global state across modules." -ForegroundColor DarkGreen
    
} catch {
    Write-Host "`n❌ TUI Scope Fix Verification FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    exit 1
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  • Test with a full TUI application" -ForegroundColor Gray
Write-Host "  • Verify all components can render properly" -ForegroundColor Gray
Write-Host "  • Check input handling works across modules" -ForegroundColor Gray
