# Refactor Error Tracking System
# Captures and categorizes errors during the migration process

$script:ErrorLog = @{
    Errors = @()
    CurrentPhase = $null
    CurrentFile = $null
}

function Start-RefactorPhase {
    param([string]$PhaseName)
    
    $script:ErrorLog.CurrentPhase = $PhaseName
    Write-Host "`n=== Starting Phase: $PhaseName ===" -ForegroundColor Cyan
    
    # Update manifest
    $manifest = Get-Content -Path ".\refactor-manifest.json" | ConvertFrom-Json
    $manifest.refactor.currentPhase = $PhaseName
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path ".\refactor-manifest.json"
}

function Set-RefactorContext {
    param([string]$FileName)
    
    $script:ErrorLog.CurrentFile = $FileName
    Write-Host "Working on: $FileName" -ForegroundColor Gray
}

function Add-RefactorError {
    param(
        [string]$ErrorType,
        [string]$Message,
        [object]$Exception,
        [string]$Resolution = $null
    )
    
    $errorEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Phase = $script:ErrorLog.CurrentPhase
        File = $script:ErrorLog.CurrentFile
        Type = $ErrorType
        Message = $Message
        Exception = if ($Exception) { $Exception.ToString() } else { $null }
        Resolution = $Resolution
        Resolved = $false
    }
    
    $script:ErrorLog.Errors += $errorEntry
    
    # Save to manifest
    $manifest = Get-Content -Path ".\refactor-manifest.json" | ConvertFrom-Json
    $manifest.refactor.errors += $errorEntry
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path ".\refactor-manifest.json"
    
    Write-Host "ERROR: $Message" -ForegroundColor Red
    if ($Resolution) {
        Write-Host "RESOLUTION: $Resolution" -ForegroundColor Yellow
    }
}

function Get-RefactorErrors {
    param(
        [string]$Phase = $null,
        [string]$File = $null,
        [switch]$Unresolved
    )
    
    $manifest = Get-Content -Path ".\refactor-manifest.json" | ConvertFrom-Json
    $errors = $manifest.refactor.errors
    
    if ($Phase) {
        $errors = $errors | Where-Object { $_.Phase -eq $Phase }
    }
    
    if ($File) {
        $errors = $errors | Where-Object { $_.File -eq $File }
    }
    
    if ($Unresolved) {
        $errors = $errors | Where-Object { -not $_.Resolved }
    }
    
    return $errors
}

function Resolve-RefactorError {
    param(
        [int]$ErrorIndex,
        [string]$Resolution
    )
    
    $manifest = Get-Content -Path ".\refactor-manifest.json" | ConvertFrom-Json
    
    if ($ErrorIndex -lt $manifest.refactor.errors.Count) {
        $manifest.refactor.errors[$ErrorIndex].Resolution = $Resolution
        $manifest.refactor.errors[$ErrorIndex].Resolved = $true
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path ".\refactor-manifest.json"
        
        Write-Host "Error #$ErrorIndex resolved" -ForegroundColor Green
    }
}

function Show-RefactorStatus {
    $manifest = Get-Content -Path ".\refactor-manifest.json" | ConvertFrom-Json
    
    Write-Host "`n=== REFACTOR STATUS ===" -ForegroundColor Cyan
    Write-Host "Current Phase: $($manifest.refactor.currentPhase)" -ForegroundColor White
    Write-Host "Last Checkpoint: $($manifest.refactor.lastCheckpoint)" -ForegroundColor White
    
    # Component status
    $total = 0
    $completed = 0
    
    foreach ($category in $manifest.refactor.components.PSObject.Properties) {
        foreach ($component in $category.Value) {
            $total++
            if ($component.status -eq "completed") { $completed++ }
        }
    }
    
    Write-Host "`nProgress: $completed/$total components completed" -ForegroundColor $(if ($completed -eq $total) { "Green" } else { "Yellow" })
    
    # Error summary
    $unresolvedErrors = @($manifest.refactor.errors | Where-Object { -not $_.Resolved }).Count
    if ($unresolvedErrors -gt 0) {
        Write-Host "Unresolved Errors: $unresolvedErrors" -ForegroundColor Red
    }
    
    # Performance comparison
    if ($manifest.refactor.benchmarks.baseline -and $manifest.refactor.benchmarks.current) {
        $improvement = [Math]::Round((($manifest.refactor.benchmarks.baseline - $manifest.refactor.benchmarks.current) / $manifest.refactor.benchmarks.baseline) * 100, 2)
        Write-Host "`nPerformance: $($improvement)% improvement" -ForegroundColor $(if ($improvement -gt 0) { "Green" } else { "Red" })
    }
}

Export-ModuleMember -Function Start-RefactorPhase, Set-RefactorContext, Add-RefactorError, Get-RefactorErrors, Resolve-RefactorError, Show-RefactorStatus