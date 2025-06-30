# Quick verification of current migration state
# Checks actual files against expected Phase 0 and Phase 1 completions

function Test-FileContains {
    param([string]$FilePath, [string]$Pattern, [string]$Description)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "❌ $Description - File not found: $FilePath" -ForegroundColor Red
        return $false
    }
    
    $content = Get-Content $FilePath -Raw
    if ($content -match $Pattern) {
        Write-Host "✅ $Description" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ $Description - Pattern not found" -ForegroundColor Red
        return $false
    }
}

Write-Host "🔍 Verifying Migration State..." -ForegroundColor Cyan
Write-Host ""

# Phase 0 Verification
Write-Host "📋 Phase 0 (Foundation) Verification:" -ForegroundColor Yellow

$phase0Results = @()
$phase0Results += Test-FileContains "components\tui-primitives.psm1" "class TuiCell" "TuiCell class exists"
$phase0Results += Test-FileContains "components\tui-primitives.psm1" "class TuiBuffer" "TuiBuffer class exists"  
$phase0Results += Test-FileContains "components\tui-primitives.psm1" "class UIElement" "UIElement base class exists"
$phase0Results += Test-FileContains "layout\panels-class.psm1" "class Panel.*UIElement" "Panel inherits from UIElement"
$phase0Results += Test-FileContains "modules\tui-engine.psm1" "function.*Render-Frame" "Enhanced TUI engine exists"

$phase0Complete = -not ($phase0Results -contains $false)
Write-Host "Phase 0 Status: $(if($phase0Complete){'✅ COMPLETE'}else{'❌ INCOMPLETE'})" -ForegroundColor $(if($phase0Complete){'Green'}else{'Red'})
Write-Host ""

# Phase 1 Verification  
Write-Host "📋 Phase 1 (Core Components) Verification:" -ForegroundColor Yellow

$phase1Results = @()
$phase1Results += Test-FileContains "components\navigation-class.psm1" "\[void\]\s+_RenderContent\(\)" "NavigationMenu has void _RenderContent()"
$phase1Results += Test-FileContains "components\navigation-class.psm1" "Write-BufferString" "NavigationMenu uses Write-BufferString"
$phase1Results += Test-FileContains "components\advanced-data-components.psm1" "\[void\]\s+_RenderContent\(\)" "Table has void _RenderContent()"
$phase1Results += Test-FileContains "components\advanced-data-components.psm1" "Write-BufferString.*-X.*-Y" "Table uses buffer-based rendering"
$phase1Results += Test-FileContains "layout\panels-class.psm1" "\[void\]\s+OnRender\(\)" "Panel has void OnRender()"
$phase1Results += Test-FileContains "layout\panels-class.psm1" "Write-TuiBox" "Panel uses Write-TuiBox"

$phase1Complete = -not ($phase1Results -contains $false)
Write-Host "Phase 1 Status: $(if($phase1Complete){'✅ COMPLETE'}else{'❌ INCOMPLETE'})" -ForegroundColor $(if($phase1Complete){'Green'}else{'Red'})
Write-Host ""

# Overall Status
Write-Host "📊 Overall Migration Status:" -ForegroundColor Cyan
if ($phase0Complete -and $phase1Complete) {
    Write-Host "🎯 Ready for Phase 2 (Advanced Components)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next commands:" -ForegroundColor White
    Write-Host "  .\Sync-MigrationSystem.ps1" -ForegroundColor Gray
    Write-Host "  .\Start-TuiMigration.ps1" -ForegroundColor Gray
} elseif ($phase0Complete) {
    Write-Host "⚠️  Phase 0 complete, Phase 1 needs attention" -ForegroundColor Yellow
} else {
    Write-Host "❌ Foundation issues detected" -ForegroundColor Red
}

Write-Host ""
return @{
    Phase0Complete = $phase0Complete
    Phase1Complete = $phase1Complete  
    ReadyForPhase2 = ($phase0Complete -and $phase1Complete)
}
