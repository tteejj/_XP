# mushroom.ps1 - The Monolith Decomposer & Recomposer Toolkit (v9 - Final, Correct Algorithm)

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = 'help',
    
    [Parameter(Position = 1)]
    [string]$Path,
    
    [Parameter(Position = 2)]
    [string]$TargetDirectory,
    
    [string]$Output = "monolith.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#==============================================================================
# FUNCTION DEFINITIONS
#==============================================================================

function Write-Status {
    param($Message, $Color = 'Cyan')
    Write-Host "🍄 $Message" -ForegroundColor $Color
}

function Invoke-Decompose {
    param(
        [string]$MonolithPath, 
        [string]$TargetDir
    )

    if (-not (Test-Path $MonolithPath)) { throw "Monolith file not found at: '$MonolithPath'" }
    $monolithLines = Get-Content -Path $MonolithPath
    if ($monolithLines.Count -eq 0) { throw "The monolith file '$MonolithPath' is empty." }

    Write-Status "Decomposing '$MonolithPath'..."

    # Setup Output Directory
    if (Test-Path $TargetDir) {
        Write-Status "Target directory '$TargetDir' already exists. Cleaning..." 'DarkYellow'
        Get-ChildItem -Path $TargetDir -Recurse | Remove-Item -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Status "Created clean output directory: $TargetDir" 'Green'

    Write-Status "Phase 1: Analyzing monolith structure..."
    
    # 1. Find all file markers and their locations
    $markerRegex = '(?i)^# --- START OF .*?([\w\-\.\/\\]+\.psm?1)'
    $fileMarkers = @()
    for ($i = 0; $i -lt $monolithLines.Count; $i++) {
        if ($monolithLines[$i] -match $markerRegex) {
            $fileMarkers += [PSCustomObject]@{
                Path      = $matches[1].Trim()
                StartLine = $i
            }
        }
    }
    if ($fileMarkers.Count -eq 0) { throw "No valid '# --- START OF...' markers found." }
    Write-Status "  -> Found $($fileMarkers.Count) file blocks."

    # 2. Extract content for each file block
    $orderedFiles = @()
    for ($i = 0; $i -lt $fileMarkers.Count; $i++) {
        $currentMarker = $fileMarkers[$i]
        $contentStart = $currentMarker.StartLine + 1
        $contentEnd = if ($i + 1 -lt $fileMarkers.Count) { $fileMarkers[$i + 1].StartLine - 1 } else { $monolithLines.Count -1 }
        
        $contentBlock = $monolithLines[$contentStart..$contentEnd]
        $fileContent = ($contentBlock | Where-Object { $_ -notmatch '# --- END OF ORIGINAL FILE:' }).Trim() | Out-String
        
        $orderedFiles += [PSCustomObject]@{
            Path = $currentMarker.Path
            Content = $fileContent.Trim()
        }
    }
    Write-Status "  -> Successfully extracted content for all $($orderedFiles.Count) files."
    
    # 3. Extract Param Block
    $paramBlockRegex = '(?msi)^param\s*\((.*?)\)'
    if (($monolithLines -join "`n") -match $paramBlockRegex) { $paramBlock = $matches[0]; Write-Status "  -> Extracted param() block." } else { $paramBlock = "" }

    # 4. Extract ONLY the Main Logic
    $lastEndFileMarkerLine = -1
    for ($i = $monolithLines.Count - 1; $i -ge 0; $i--) {
        if ($monolithLines[$i] -match '# --- END OF ORIGINAL FILE:') {
            $lastEndFileMarkerLine = $i; break
        }
    }
    if ($lastEndFileMarkerLine -eq -1) { throw "Could not find any '# --- END OF ORIGINAL FILE: ---' marker." }

    $endOfMainLogicMarkerLine = -1
    for ($i = $lastEndFileMarkerLine; $i -lt $monolithLines.Count; $i++) {
        if ($monolithLines[$i] -match '# --- END OF MAIN EXECUTION LOGIC ---') {
            $endOfMainLogicMarkerLine = $i; break
        }
    }
    if ($endOfMainLogicMarkerLine -eq -1) { throw "Could not find the '# --- END OF MAIN EXECUTION LOGIC ---' marker." }
    
    # The main logic is ONLY the lines between these two markers.
    $mainLogicLines = $monolithLines[($lastEndFileMarkerLine + 1)..($endOfMainLogicMarkerLine - 1)]
    $mainLogicContent = ($mainLogicLines | Out-String).Trim()
    Write-Status "  -> Extracted main logic block correctly."

    $components = @{
        ParamBlock   = $paramBlock
        MainLogic    = $mainLogicContent
        OrderedFiles = $orderedFiles
    }

    # 5. Assemble the Modular Project
    Write-Status "Phase 2: Assembling modular project..."
    foreach ($file in $components.OrderedFiles) {
        $destinationPath = Join-Path $TargetDir $file.Path
        $destinationDir = Split-Path $destinationPath -Parent
        if (-not (Test-Path $destinationDir)) { New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null }
        Set-Content -Path $destinationPath -Value $file.Content -Encoding UTF8
        Write-Status "  -> Restored: $($file.Path)" 'Gray'
    }
    Synthesize-RunnerScript -Components $components -OutDir $TargetDir

    Write-Status "Decomposition complete!" 'Green'
    Write-Status "To run the new project: cd '$TargetDir'; ./run.ps1" 'Yellow'
}

function Synthesize-RunnerScript {
    param($Components, $OutDir)
    $fileOrderString = @($Components.OrderedFiles.Path | ForEach-Object { "    '$_'" }) -join ",`r`n"
    $runnerScriptContent = @"
# run.ps1 - Main entry point for the deconstructed application.
# Synthesized by mushroom.

$($Components.ParamBlock)

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

# Load order derived directly from the original monolith's structure to ensure correctness.
# CRITICAL: To add a new file, add its path to this array in the correct dependency order.
`$FileLoadOrder = @(
$($fileOrderString)
)

Write-Host "Loading application modules..." -ForegroundColor Cyan
`$PSScriptRoot = Get-Location
foreach (`$filePath in `$FileLoadOrder) {
    `$fullPath = Join-Path `$PSScriptRoot `$filePath
    if (Test-Path `$fullPath) { . `$fullPath }
    else { Write-Warning "Module not found: `$filePath" }
}

Write-Host "All modules loaded. Starting application..." -ForegroundColor Green

# --- MAIN EXECUTION LOGIC ---
$($Components.MainLogic)
"@
    Set-Content -Path (Join-Path $OutDir "run.ps1") -Value $runnerScriptContent -Encoding UTF8
    Write-Status "  -> SYNTHESIZED: run.ps1 (new entry point)" 'Green'
}

function Invoke-Recompose {
    param($SourceDir, $OutputPath)
    # This function remains correct.
    Write-Status "Recomposing project from '$SourceDir' to '$OutputPath'..."
    $runnerPath = Join-Path $SourceDir "run.ps1"
    if (-not (Test-Path $runnerPath)) { throw "'run.ps1' not found in source directory '$SourceDir'. Cannot determine load order."}
    $runnerContent = Get-Content -Path $runnerPath -Raw
    $paramBlock = if ($runnerContent -match '(?msi)^param\s*\((.*?)\)') { $matches[0] } else { '' }
    $mainLogic = if ($runnerContent -match '(?msi)# --- MAIN EXECUTION LOGIC ---\r?\n(.*?)\s*$') { $matches[1].Trim() } else { throw "Main logic not found in run.ps1" }
    $fileOrderMatch = if ($runnerContent -match '(?msi)\$FileLoadOrder\s*=\s*(@\(.*?\))') { $matches[1] } else { throw "`$FileLoadOrder not found in run.ps1" }
    $FileLoadOrder = Invoke-Expression $fileOrderMatch
    Write-Status "  -> Found load order with $($FileLoadOrder.Count) files in run.ps1"
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# MONOLITHIC SCRIPT (Generated by mushroom recompose)")
    [void]$sb.AppendLine($paramBlock)
    [void]$sb.AppendLine('Set-StrictMode -Version Latest')
    [void]$sb.AppendLine('`$ErrorActionPreference = "Stop"')
    foreach ($path in $FileLoadOrder) {
        $fullPath = Join-Path $SourceDir $path
        if (-not (Test-Path $fullPath)) { throw "Source file '$fullPath' is missing." }
        $content = Get-Content -Path $fullPath -Raw
        Write-Status "  -> Embedding: $path" 'Gray'
        [void]$sb.AppendLine("`n# --- START OF ORIGINAL FILE: $path ---")
        [void]$sb.AppendLine($content.Trim())
        [void]$sb.AppendLine("# --- END OF ORIGINAL FILE: ---")
    }
    [void]$sb.AppendLine("`n# --- START OF MAIN EXECUTION LOGIC (from run.ps1) ---")
    [void]$sb.AppendLine($mainLogic)
    [void]$sb.AppendLine("# --- END OF MAIN EXECUTION LOGIC ---")
    Set-Content -Path $OutputPath -Value $sb.ToString() -Encoding UTF8
    Write-Status "Recomposition complete!" "Green"
}

function Show-Help {
    Write-Host @"

🍄 MUSHROOM - The Monolith Decomposer & Recomposer

COMMANDS:
  decompose <monolith_file> [target_directory]
  recompose [source_directory] [-Output <output_file>]

"@ -ForegroundColor 'Cyan'
}


#==============================================================================
# MAIN EXECUTION BLOCK
#==============================================================================

try {
    switch ($Command.ToLower()) {
        'decompose' {
            if (-not $Path) { throw "The 'decompose' command requires a path to the monolith file." }
            $target = if ($TargetDirectory) { $TargetDirectory } else { "_decomposed" }
            Invoke-Decompose -MonolithPath $Path -TargetDir $target
        }
        
        'recompose' {
            $sourceDir = if ($Path) { $Path } else { "." }
            Invoke-Recompose -SourceDir $sourceDir -OutputPath $Output
        }

        default {
            Show-Help
        }
    }
} catch {
    Write-Host ""
    Write-Host "🍄 ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}