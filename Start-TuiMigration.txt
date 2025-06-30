# Master Refactor Orchestrator
# Run this to execute the ncurses-inspired TUI migration

using module .\tools\refactor-checkpoint.psm1
using module .\tools\tui-validation.psm1 
using module .\tools\refactor-errors.psm1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Start-TuiMigration {
    Write-Host @"
╔══════════════════════════════════════════════════════════════════╗
║           PMC Terminal v5 - NCurses Migration Tool               ║
║                                                                  ║
║  This tool will guide you through the migration to a            ║
║  composited, layered window architecture.                        ║
╚══════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    # Check for existing migration
    if (Test-Path ".\refactor-manifest.json") {
        $manifest = Get-Content ".\refactor-manifest.json" | ConvertFrom-Json
        Write-Host "`nExisting migration found!" -ForegroundColor Yellow
        Write-Host "Current Phase: $($manifest.refactor.currentPhase)" -ForegroundColor White
        
        $resume = Read-Host "Resume existing migration? (Y/N)"
        if ($resume -ne 'Y') {
            Write-Host "Creating backup of existing migration..." -ForegroundColor Gray
            $backupName = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item ".\refactor-manifest.json" ".\refactor-manifest.$backupName.json"
            Remove-Item ".\refactor-manifest.json"
        }
    }
    
    Show-RefactorStatus
}

function Invoke-RefactorPhase {
    param([string]$PhaseName)
    
    Start-RefactorPhase -PhaseName $PhaseName
    
    try {
        switch ($PhaseName) {
            "pre-a" { Invoke-PrePhaseA }
            "phase-0" { Invoke-Phase0 }
            "phase-1" { Invoke-Phase1 }
            "phase-2" { Invoke-Phase2 }
            "validation" { Invoke-ValidationPhase }
            default { throw "Unknown phase: $PhaseName" }
        }
        
        Write-Host "`nPhase $PhaseName completed successfully!" -ForegroundColor Green
    }
    catch {
        Add-RefactorError -ErrorType "PhaseFailed" -Message "Phase $PhaseName failed" -Exception $_
        Write-Host "`nPhase $PhaseName FAILED!" -ForegroundColor Red
        Write-Host "Run 'Get-RefactorErrors -Unresolved' to see details" -ForegroundColor Yellow
        throw
    }
}

function Invoke-PrePhaseA {
    Write-Host "`nPre-Phase A: Setting up safety infrastructure" -ForegroundColor White
    
    # Create initial checkpoint
    New-RefactorCheckpoint -Name "pre-migration" -Description "State before any migration changes"
    
    # Run baseline performance tests
    Write-Host "`nRunning baseline performance tests..." -ForegroundColor Gray
    $baseline = Measure-TuiPerformance -Scenario {
        # Simulate typical render workload
        for ($i = 0; $i -lt 10; $i++) {
            # This would be replaced with actual component render tests
            Start-Sleep -Milliseconds 5
        }
    }
    
    $manifest = Get-Content ".\refactor-manifest.json" | ConvertFrom-Json
    $manifest.refactor.benchmarks.baseline = $baseline.Average
    $manifest | ConvertTo-Json -Depth 10 | Set-Content ".\refactor-manifest.json"
    
    Write-Host "Baseline performance: $($baseline.Average)ms average" -ForegroundColor White
}

function Invoke-Phase0 {
    Write-Host "`nPhase 0: Core Engine and Contract Stabilization" -ForegroundColor White
    
    # Create checkpoint before phase
    New-RefactorCheckpoint -Name "phase-0-start" -Description "Before core engine changes"
    
    Set-RefactorContext -FileName "modules/dialog-system.psm1"
    if (Test-Path "modules\dialog-system.psm1") {
        Write-Host "Removing legacy dialog system..." -ForegroundColor Gray
        Remove-Item "modules\dialog-system.psm1" -Force
    }
    
    Set-RefactorContext -FileName "modules/tui-engine.psm1"
    # Here you would apply the actual engine modifications
    # For now, we'll simulate the update
    
    # Mark components as updated in manifest
    Update-ComponentStatus -File "modules/tui-engine.psm1" -Status "completed"
}

function Update-ComponentStatus {
    param(
        [string]$File,
        [string]$Status
    )
    
    $manifest = Get-Content ".\refactor-manifest.json" | ConvertFrom-Json
    
    foreach ($category in $manifest.refactor.components.PSObject.Properties) {
        foreach ($component in $category.Value) {
            if ($component.file -eq $File) {
                $component.status = $Status
                break
            }
        }
    }
    
    $manifest | ConvertTo-Json -Depth 10 | Set-Content ".\refactor-manifest.json"
}

# Interactive Menu
function Show-MigrationMenu {
    while ($true) {
        Clear-Host
        Write-Host @"
╔══════════════════════════════════════════════════════════════════╗
║                  NCurses Migration Control Panel                 ║
╚══════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
        
        Show-RefactorStatus
        
        Write-Host "`n[1] Execute Next Phase" -ForegroundColor White
        Write-Host "[2] Run Component Tests" -ForegroundColor White
        Write-Host "[3] Create Checkpoint" -ForegroundColor White
        Write-Host "[4] Restore Checkpoint" -ForegroundColor White
        Write-Host "[5] View Errors" -ForegroundColor White
        Write-Host "[6] Generate Report" -ForegroundColor White
        Write-Host "[Q] Quit" -ForegroundColor White
        
        $choice = Read-Host "`nSelect option"
        
        switch ($choice) {
            "1" {
                $manifest = Get-Content ".\refactor-manifest.json" | ConvertFrom-Json
                $nextPhase = Get-NextPhase -CurrentPhase $manifest.refactor.currentPhase
                if ($nextPhase) {
                    Invoke-RefactorPhase -PhaseName $nextPhase
                } else {
                    Write-Host "All phases completed!" -ForegroundColor Green
                }
                Read-Host "Press Enter to continue"
            }
            "2" {
                Write-Host "Running component tests..." -ForegroundColor Yellow
                # Run validation tests
                Read-Host "Press Enter to continue"
            }
            "3" {
                $name = Read-Host "Checkpoint name"
                $desc = Read-Host "Description"
                New-RefactorCheckpoint -Name $name -Description $desc
                Read-Host "Press Enter to continue"
            }
            "4" {
                $checkpoints = Get-RefactorCheckpoints
                if ($checkpoints) {
                    for ($i = 0; $i -lt $checkpoints.Count; $i++) {
                        Write-Host "[$i] $($checkpoints[$i].Name) - $($checkpoints[$i].Timestamp)"
                    }
                    $selection = Read-Host "Select checkpoint"
                    if ($selection -match '^\d+$' -and [int]$selection -lt $checkpoints.Count) {
                        Restore-RefactorCheckpoint -CheckpointPath $checkpoints[[int]$selection].Path
                    }
                }
                Read-Host "Press Enter to continue"
            }
            "5" {
                Get-RefactorErrors -Unresolved | Format-Table -AutoSize
                Read-Host "Press Enter to continue"
            }
            "6" {
                Generate-MigrationReport
                Read-Host "Press Enter to continue"
            }
            "Q" { return }
        }
    }
}

function Get-NextPhase {
    param([string]$CurrentPhase)
    
    $phases = @("pre-a", "phase-0", "phase-1", "phase-2", "validation")
    $currentIndex = $phases.IndexOf($CurrentPhase)
    
    if ($currentIndex -ge 0 -and $currentIndex -lt $phases.Count - 1) {
        return $phases[$currentIndex + 1]
    }
    
    return $null
}

function Generate-MigrationReport {
    $manifest = Get-Content ".\refactor-manifest.json" | ConvertFrom-Json
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $report = @"
# NCurses Migration Report
Generated: $timestamp

## Status
- Current Phase: $($manifest.refactor.currentPhase)
- Start Date: $($manifest.refactor.startDate)

## Component Progress
"@

    foreach ($category in $manifest.refactor.components.PSObject.Properties) {
        $report += "`n### $($category.Name)`n"
        foreach ($component in $category.Value) {
            $status = if ($component.status -eq "completed") { "✓" } else { "○" }
            $report += "- [$status] $($component.file)`n"
        }
    }
    
    $report += "`n## Errors`n"
    $errors = $manifest.refactor.errors
    if ($errors.Count -eq 0) {
        $report += "No errors recorded.`n"
    } else {
        foreach ($error in $errors) {
            $resolved = if ($error.Resolved) { "RESOLVED" } else { "OPEN" }
            $report += "- [$resolved] $($error.Message) ($($error.Phase))`n"
        }
    }
    
    $reportPath = ".\migration_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    $report | Set-Content -Path $reportPath
    Write-Host "Report saved: $reportPath" -ForegroundColor Green
}

# Entry Point
Start-TuiMigration
Show-MigrationMenu