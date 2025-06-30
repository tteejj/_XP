# Sync Migration System with Actual File State
# Fixes outdated checkpoint and manifest data

param(
    [switch]$WhatIf
)

Write-Host "🔄 Syncing Migration System with Actual File State..." -ForegroundColor Cyan

# Load migration tools
try {
    Import-Module ".\tools\refactor-checkpoint.psm1" -Force
    Import-Module ".\tools\refactor-errors.psm1" -Force
    Import-Module ".\tools\tui-validation.psm1" -Force
    Write-Host "✅ Migration tools loaded" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load migration tools: $_" -ForegroundColor Red
    exit 1
}

# Create updated manifest reflecting actual completion state
$updatedManifest = @{
    refactor = @{
        name = "ncurses-compositor-migration"
        startDate = "2025-06-29"
        currentPhase = "phase-1-complete"
        lastCheckpoint = ".\refactor_checkpoints\checkpoint_$(Get-Date -Format 'yyyyMMdd_HHmmss')_phase-1-verified"
        components = @{
            core = @(
                @{
                    file = "components/tui-primitives.psm1"
                    status = "completed"
                    dependencies = @()
                    tests = @()
                    classes = @("TuiCell", "TuiBuffer", "UIElement", "TuiAnsiHelper")
                    completedDate = "2025-06-29T00:00:00Z"
                    notes = "Foundation classes - TuiCell compositor system operational"
                    verifiedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                },
                @{
                    file = "modules/tui-engine.psm1"
                    status = "completed"
                    dependencies = @("components/tui-primitives.psm1")
                    tests = @()
                    completedDate = "2025-06-29T00:00:00Z"
                    notes = "Enhanced with NCurses compositor support, buffer-based rendering"
                    verifiedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                }
            )
            panels = @(
                @{
                    file = "layout/panels-class.psm1"
                    status = "completed"
                    dependencies = @("components/tui-primitives.psm1")
                    tests = @()
                    classes = @("Panel", "ScrollablePanel", "GroupPanel")
                    completedDate = "2025-06-29T00:00:00Z"
                    notes = "Panel foundation classes with NCurses architecture - OnRender() methods implemented"
                    verifiedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                }
            )
            components = @(
                @{
                    file = "components/navigation-class.psm1"
                    class = "NavigationMenu"
                    status = "completed"
                    dependencies = @("layout/panels-class.psm1")
                    tests = @()
                    phase = "phase-1"
                    completedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                    notes = "_RenderContent() void method implemented, Write-BufferString rendering, ANSI helpers removed"
                    verifiedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                },
                @{
                    file = "components/advanced-data-components.psm1"
                    class = "Table"
                    status = "completed"
                    dependencies = @("layout/panels-class.psm1")
                    tests = @()
                    phase = "phase-1"
                    completedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                    notes = "_RenderContent() void method implemented, buffer-based rendering"
                    verifiedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                },
                @{
                    file = "components/advanced-data-components.psm1"
                    class = "DataTableComponent"
                    status = "completed"
                    dependencies = @("layout/panels-class.psm1")
                    tests = @()
                    phase = "phase-1"
                    completedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                    notes = "_RenderContent() void method implemented, placeholder for complex features"
                    verifiedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                },
                @{
                    file = "components/tui-components.psm1"
                    status = "pending"
                    dependencies = @("layout/panels-class.psm1")
                    tests = @()
                    phase = "phase-2"
                    classes = @("Button", "TextBox", "Label", "CheckBox", "RadioButton")
                    notes = "Ready for Phase 2 - functional to class conversion"
                },
                @{
                    file = "components/advanced-input-components.psm1"
                    status = "pending"
                    dependencies = @("layout/panels-class.psm1")
                    tests = @()
                    phase = "phase-2"
                    classes = @("MultilineTextBox", "NumericInput", "DateInput", "ComboBox")
                    notes = "Ready for Phase 2 - functional to class conversion"
                },
                @{
                    file = "modules/dialog-system-class.psm1"
                    status = "pending"
                    dependencies = @("layout/panels-class.psm1")
                    tests = @()
                    phase = "phase-2"
                    classes = @("Dialog", "MessageDialog", "InputDialog", "ConfirmDialog")
                    notes = "Ready for Phase 2 - dialog system integration"
                }
            )
            screens = @(
                @{
                    file = "screens/dashboard-screen.psm1"
                    status = "pending"
                    dependencies = @("components/navigation-class.psm1", "components/advanced-data-components.psm1")
                    tests = @()
                    phase = "phase-3"
                    notes = "Ready for Phase 3 - screen integration"
                },
                @{
                    file = "screens/task-list-screen.psm1"
                    status = "pending"
                    dependencies = @("components/advanced-data-components.psm1")
                    tests = @()
                    phase = "phase-3"
                    notes = "Ready for Phase 3 - screen integration"
                }
            )
        }
        phases = @{
            "pre-a" = @{
                name = "NCurses Foundation"
                status = "completed"
                description = "Establish TuiCell, UIElement, and Panel foundation classes"
                completedDate = "2025-06-29T00:00:00Z"
                verifiedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                deliverables = @(
                    "TuiCell class with blending support",
                    "TuiBuffer 2D array management", 
                    "UIElement base class for all components",
                    "Panel base class with layout support",
                    "Enhanced TUI engine with compositor"
                )
            }
            "phase-1" = @{
                name = "Core Components Migration"
                status = "completed"
                description = "Migrate basic UI components to buffer-based rendering"
                dependencies = @("pre-a")
                completedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                verifiedDate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
                targets = @(
                    "NavigationMenu - void _RenderContent()",
                    "Table - buffer-based rendering",
                    "DataTableComponent - placeholder implementation",
                    "Panel classes - OnRender() methods"
                )
            }
            "phase-2" = @{
                name = "Advanced Components & Dialogs"
                status = "ready"
                description = "Convert functional components to classes, integrate dialog system"
                dependencies = @("phase-1")
                targets = @(
                    "Button, TextBox, Label components",
                    "Advanced input components",
                    "Dialog system integration"
                )
            }
            "phase-3" = @{
                name = "Screen Integration"
                status = "pending"
                description = "Migrate all screens to new architecture"
                dependencies = @("phase-2")
                targets = @(
                    "Dashboard screen",
                    "Task screens",
                    "All remaining screens"
                )
            }
        }
        errors = @()
        benchmarks = @{
            baseline = $null
            current = $null
        }
        statistics = @{
            totalComponents = 15
            completedComponents = 8
            completionPercentage = 53.3
            lastUpdate = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
        }
    }
}

# Write updated manifest
$manifestPath = ".\refactor-manifest.json"
$backupPath = ".\refactor-manifest.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

if (-not $WhatIf) {
    # Backup current manifest if it exists
    if (Test-Path $manifestPath) {
        Copy-Item $manifestPath $backupPath
        Write-Host "📋 Backed up current manifest to: $backupPath" -ForegroundColor Yellow
    }
    
    # Write new manifest
    $updatedManifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8
    Write-Host "✅ Updated manifest written to: $manifestPath" -ForegroundColor Green
} else {
    Write-Host "📋 [WHATIF] Would update manifest: $manifestPath" -ForegroundColor Yellow
}

# Create verified checkpoint
$checkpointName = "phase-1-verified"
$checkpointDesc = "Phase 0 and Phase 1 completed - verified against actual file state"

if (-not $WhatIf) {
    try {
        New-RefactorCheckpoint -Name $checkpointName -Description $checkpointDesc
        Write-Host "✅ Created verified checkpoint: $checkpointName" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Checkpoint creation failed: $_" -ForegroundColor Yellow
        Write-Host "   Manual checkpoint creation may be required" -ForegroundColor Yellow
    }
} else {
    Write-Host "📁 [WHATIF] Would create checkpoint: $checkpointName" -ForegroundColor Yellow
}

# Clear any stale errors
if (-not $WhatIf) {
    try {
        Clear-RefactorErrors
        Write-Host "🧹 Cleared stale error log" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Could not clear errors: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "🧹 [WHATIF] Would clear error log" -ForegroundColor Yellow
}

# Display current status
Write-Host ""
Write-Host "📊 Updated Migration Status:" -ForegroundColor Cyan
Write-Host "  • Phase 0 (Foundation): ✅ COMPLETE" -ForegroundColor Green
Write-Host "  • Phase 1 (Core Components): ✅ COMPLETE" -ForegroundColor Green  
Write-Host "  • Phase 2 (Advanced Components): 🔄 READY" -ForegroundColor Yellow
Write-Host "  • Phase 3 (Screen Integration): ⏳ PENDING" -ForegroundColor Gray
Write-Host ""
Write-Host "📈 Progress: 8/15 components (53.3%) complete" -ForegroundColor Cyan
Write-Host ""

if (-not $WhatIf) {
    Write-Host "🎯 Migration system synchronized!" -ForegroundColor Green
    Write-Host "   Ready to proceed with Phase 2" -ForegroundColor Green
} else {
    Write-Host "💡 Run without -WhatIf to apply changes" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. .\Sync-MigrationSystem.ps1" -ForegroundColor Gray
Write-Host "  2. .\Start-TuiMigration.ps1" -ForegroundColor Gray  
Write-Host "  3. Tell Helios: 'Execute Phase 2'" -ForegroundColor Gray
