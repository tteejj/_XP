# Monitor-AxiomLog.ps1 - Real-time log monitoring utility

param(
    [int]$Lines = 50,
    [switch]$Follow
)

$logFile = Join-Path $PSScriptRoot "axiom-phoenix-debug.log"

if (-not (Test-Path $logFile)) {
    Write-Host "Log file not found at: $logFile" -ForegroundColor Red
    Write-Host "Run Start.ps1 first to initialize logging." -ForegroundColor Yellow
    exit 1
}

Write-Host "Axiom Phoenix Debug Log Monitor" -ForegroundColor Cyan
Write-Host "Log file: $logFile" -ForegroundColor Gray
Write-Host ("=" * 80) -ForegroundColor DarkGray

if ($Follow) {
    # Real-time monitoring
    Write-Host "Following log file (Press Ctrl+C to stop)..." -ForegroundColor Yellow
    Write-Host ""
    
    Get-Content -Path $logFile -Tail $Lines -Wait | ForEach-Object {
        if ($_ -match '\[ERROR\]') {
            Write-Host $_ -ForegroundColor Red
        }
        elseif ($_ -match '\[WARNING\]') {
            Write-Host $_ -ForegroundColor Yellow
        }
        elseif ($_ -match '\[DEBUG\]') {
            Write-Host $_ -ForegroundColor DarkGray
        }
        elseif ($_ -match '\[VERBOSE\]') {
            Write-Host $_ -ForegroundColor DarkCyan
        }
        elseif ($_ -match '\[HOST\]') {
            Write-Host $_ -ForegroundColor White
        }
        else {
            Write-Host $_ -ForegroundColor Gray
        }
    }
} else {
    # Show last N lines
    Write-Host "Showing last $Lines lines:" -ForegroundColor Yellow
    Write-Host ""
    
    Get-Content -Path $logFile -Tail $Lines | ForEach-Object {
        if ($_ -match '\[ERROR\]') {
            Write-Host $_ -ForegroundColor Red
        }
        elseif ($_ -match '\[WARNING\]') {
            Write-Host $_ -ForegroundColor Yellow
        }
        elseif ($_ -match '\[DEBUG\]') {
            Write-Host $_ -ForegroundColor DarkGray
        }
        elseif ($_ -match '\[VERBOSE\]') {
            Write-Host $_ -ForegroundColor DarkCyan
        }
        elseif ($_ -match '\[HOST\]') {
            Write-Host $_ -ForegroundColor White
        }
        else {
            Write-Host $_ -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor DarkGray
    Write-Host "Use -Follow parameter to monitor in real-time" -ForegroundColor Green
}
