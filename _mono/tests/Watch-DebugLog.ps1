# Watch the debug trace log in real-time
$ErrorActionPreference = 'Stop'

$debugLog = "$PSScriptRoot\debug-trace.log"

if (-not (Test-Path $debugLog)) {
    Write-Host "Debug log not found. Run Test-WithFileTrace.ps1 first." -ForegroundColor Red
    exit
}

Write-Host "Watching debug-trace.log (Press Ctrl+C to stop)..." -ForegroundColor Cyan
Write-Host ""

# Get initial content
$lastPosition = 0
if (Test-Path $debugLog) {
    $content = Get-Content $debugLog -Raw
    if ($content) {
        Write-Host $content -NoNewline
        $lastPosition = $content.Length
    }
}

# Watch for changes
while ($true) {
    Start-Sleep -Milliseconds 100
    
    if (Test-Path $debugLog) {
        $file = Get-Item $debugLog
        if ($file.Length -gt $lastPosition) {
            $stream = [System.IO.File]::OpenRead($debugLog)
            $stream.Position = $lastPosition
            $reader = New-Object System.IO.StreamReader($stream)
            $newContent = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            
            if ($newContent) {
                # Color code the output
                $lines = $newContent -split "`r?`n"
                foreach ($line in $lines) {
                    if ($line -match "ERROR|WARNING") {
                        Write-Host $line -ForegroundColor Red
                    } elseif ($line -match "CommandPalette|OnClose|Complete|DeferredAction") {
                        Write-Host $line -ForegroundColor Yellow
                    } elseif ($line -match "Executing action|Action executed") {
                        Write-Host $line -ForegroundColor Green
                    } else {
                        Write-Host $line
                    }
                }
            }
            
            $lastPosition = $file.Length
        }
    }
}
