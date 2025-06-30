# Refactor Checkpoint System
# Manages safe rollback points during the ncurses migration

function New-RefactorCheckpoint {
    param([string]$Name, [string]$Description)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $checkpointDir = ".\refactor_checkpoints\checkpoint_${timestamp}_${Name}"
    
    Write-Host "Creating checkpoint: $Name" -ForegroundColor Cyan
    
    # Create checkpoint directory
    New-Item -ItemType Directory -Path $checkpointDir -Force | Out-Null
    
    # Save current state of all tracked files
    $manifest = Get-Content -Path ".\refactor-manifest.json" | ConvertFrom-Json
    
    foreach ($category in $manifest.refactor.components.PSObject.Properties) {
        foreach ($component in $category.Value) {
            if (Test-Path $component.file) {
                $destPath = Join-Path $checkpointDir $component.file
                $destDir = Split-Path $destPath -Parent
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                Copy-Item -Path $component.file -Destination $destPath -Force
            }
        }
    }
    
    # Save checkpoint metadata
    @{
        Name = $Name
        Description = $Description
        Timestamp = $timestamp
        Files = $manifest.refactor.components
    } | ConvertTo-Json -Depth 10 | Set-Content -Path "$checkpointDir\checkpoint.json"
    
    # Update manifest
    $manifest.refactor.lastCheckpoint = $checkpointDir
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path ".\refactor-manifest.json"
    
    Write-Host "Checkpoint created: $checkpointDir" -ForegroundColor Green
}

function Restore-RefactorCheckpoint {
    param([string]$CheckpointPath)
    
    if (-not (Test-Path "$CheckpointPath\checkpoint.json")) {
        throw "Invalid checkpoint: $CheckpointPath"
    }
    
    Write-Host "Restoring from checkpoint: $CheckpointPath" -ForegroundColor Yellow
    
    $checkpoint = Get-Content "$CheckpointPath\checkpoint.json" | ConvertFrom-Json
    
    foreach ($category in $checkpoint.Files.PSObject.Properties) {
        foreach ($component in $category.Value) {
            $sourcePath = Join-Path $CheckpointPath $component.file
            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $component.file -Force
                Write-Host "  Restored: $($component.file)" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "Checkpoint restored successfully" -ForegroundColor Green
}

function Get-RefactorCheckpoints {
    Get-ChildItem -Path ".\refactor_checkpoints" -Directory | 
        Where-Object { Test-Path "$($_.FullName)\checkpoint.json" } |
        ForEach-Object {
            $meta = Get-Content "$($_.FullName)\checkpoint.json" | ConvertFrom-Json
            [PSCustomObject]@{
                Path = $_.FullName
                Name = $meta.Name
                Description = $meta.Description
                Timestamp = $meta.Timestamp
            }
        } | Sort-Object Timestamp -Descending
}

Export-ModuleMember -Function New-RefactorCheckpoint, Restore-RefactorCheckpoint, Get-RefactorCheckpoints