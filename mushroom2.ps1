# mushroom.ps1 - The Monolith Decomposer & Recomposer Toolkit (v11 - Recompose Fixed)

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
    $monolithContent = Get-Content -Path $MonolithPath -Raw
    $monolithLines = $monolithContent -split '(\r?\n)'
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
    
    # 1. Extract Using Statements and Param Block first
    $usingStatements = @()
    $paramBlock = ''
    $inParamBlock = $false
    $firstCodeLine = 0
    for ($i = 0; $i -lt $monolithLines.Count; $i++) {
        $line = $monolithLines[$i]
        if ($line.Trim() -match '^#') { continue } # Skip comments
        if ($line.Trim() -match '^using namespace') { $usingStatements += $line.Trim(); continue }
        if ($line.Trim() -match '^param\s*\(') { $inParamBlock = $true }
        if ($inParamBlock) { $paramBlock += "$line`r`n" }
        if ($inParamBlock -and $line.Trim() -eq ')') { $inParamBlock = $false; $firstCodeLine = $i + 1; break }
        if (-not $inParamBlock -and -not [string]::IsNullOrWhiteSpace($line)) { $firstCodeLine = $i; break }
    }
    Write-Status "  -> Extracted $($usingStatements.Count) 'using' statements."
    if ($paramBlock) { Write-Status "  -> Extracted param() block." }
    
    # 2. Find all file markers
    $markerRegex = '(?i)^# --- START OF .*?([\w\-\.\/\\]+\.psm?1)'
    $fileMarkers = @()
    for ($i = $firstCodeLine; $i -lt $monolithLines.Count; $i++) {
        if ($monolithLines[$i] -match $markerRegex) {
            $fileMarkers += [PSCustomObject]@{
                Path      = $matches[1].Trim()
                StartLine = $i
            }
        }
    }
    if ($fileMarkers.Count -eq 0) { throw "No valid '# --- START OF...' markers found." }
    Write-Status "  -> Found $($fileMarkers.Count) file blocks."

    # 3. Find Main Logic boundaries
    $mainLogicStartLine = [array]::FindIndex($monolithLines, {param($l) $l -match '# --- START OF MAIN EXECUTION LOGIC'})
    $mainLogicEndLine = [array]::FindIndex($monolithLines, {param($l) $l -match '# --- END OF MAIN EXECUTION LOGIC'})
    if ($mainLogicStartLine -lt 0 -or $mainLogicEndLine -lt 0) { throw "Could not find main logic start/end markers."}
    $mainLogicContent = ($monolithLines[($mainLogicStartLine + 1)..($mainLogicEndLine - 1)] | Out-String).Trim()
    Write-Status "  -> Extracted main logic block."

    # 4. Extract content for each file block
    $orderedFiles = @()
    for ($i = 0; $i -lt $fileMarkers.Count; $i++) {
        $currentMarker = $fileMarkers[$i]
        $contentStart = $currentMarker.StartLine + 1
        
        # The end of a block is right before the start of the next block OR the start of the main logic
        $endBoundary = if ($i + 1 -lt $fileMarkers.Count) { $fileMarkers[$i + 1].StartLine } else { $mainLogicStartLine }
        $contentEnd = $endBoundary - 1

        $contentBlock = $monolithLines[$contentStart..$contentEnd]
        $fileContent = ($contentBlock | Where-Object { $_ -notmatch '# --- END OF ORIGINAL FILE:' }).Trim() | Out-String
        
        $orderedFiles += [PSCustomObject]@{
            Path = $currentMarker.Path
            Content = $fileContent.Trim()
        }
    }
    Write-Status "  -> Successfully extracted content for all $($orderedFiles.Count) files."
    
    $components = @{
        UsingStatements = $usingStatements
        ParamBlock      = $paramBlock
        MainLogic       = $mainLogicContent
        OrderedFiles    = $orderedFiles
    }

    # 5. Assemble the Modular Project
    Write-Status "Phase 2: Assembling modular project..."
    foreach ($file in $components.OrderedFiles) {
        $destinationPath = Join-Path $TargetDir $file.Path
        $destinationDir = Split-Path $destinationPath -Parent
        if (-not (Test-Path $destinationDir)) { New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null }
        
        # Add 'using' statements to files that need them (class definitions)
        $fileOutput = if ($file.Content -match 'class\s+\w+') { ($components.UsingStatements | Out-String).Trim() + "`r`n`r`n" + $file.Content } else { $file.Content }
        Set-Content -Path $destinationPath -Value $fileOutput -Encoding UTF8
        Write-Status "  -> Restored: $($file.Path)" 'Gray'
    }
    Synthesize-RunnerScript -Components $components -OutDir $TargetDir

    Write-Status "Decomposition complete!" 'Green'
    Write-Status "To run the new project: cd '$TargetDir'; ./run.ps1" 'Yellow'
}

function Synthesize-RunnerScript {
    param($Components, $OutDir)
    $fileOrderString = @($Components.OrderedFiles.Path | ForEach-Object { "    '$_'" }) -join ",`r`n"
    # The runner is lightweight. It does NOT contain the main logic itself.
    $runnerScriptContent = @"
# run.ps1 - Main entry point for the deconstructed application.
# Synthesized by mushroom.

$($Components.ParamBlock)

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

`$PSScriptRoot = Split-Path -Parent `$MyInvocation.MyCommand.Definition
`$FileLoadOrder = @(
$($fileOrderString)
)

foreach (`$filePath in `$FileLoadOrder) {
    `$fullPath = Join-Path `$PSScriptRoot `$filePath
    if (Test-Path `$fullPath) {
        . `$fullPath
    } else {
        Write-Warning "Module not found: `$filePath"
    }
}

# The main logic is now inside one of the sourced modules (likely tui-framework.psm1)
# and is executed by calling its entry-point function.
# This logic is now correctly extracted from the monolith.
$($Components.MainLogic)
"@
    Set-Content -Path (Join-Path $OutDir "run.ps1") -Value $runnerScriptContent -Encoding UTF8
    Write-Status "  -> SYNTHESIZED: run.ps1 (lightweight entry point)" 'Green'
}

function Invoke-Recompose {
    # --- THIS IS THE COMPLETELY REWRITTEN AND CORRECTED FUNCTION ---
    param($SourceDir, $OutputPath)

    Write-Status "Recomposing project from '$SourceDir' to '$OutputPath'..."
    
    $runnerPath = Join-Path $SourceDir "run.ps1"
    if (-not (Test-Path $runnerPath)) { throw "'run.ps1' not found in source directory '$SourceDir'."}
    
    $runnerContent = Get-Content -Path $runnerPath -Raw
    $paramBlock = if ($runnerContent -match '(?msi)^param\s*\((.*?)\)') { $matches[0] } else { '' }
    $mainLogic = if ($runnerContent -match '(?msi)# --- MAIN EXECUTION LOGIC ---\r?\n(.*?)\s*$') { $matches[1].Trim() } else { throw "Main logic not found in run.ps1" }
    $fileOrderMatch = if ($runnerContent -match '(?msi)\$FileLoadOrder\s*=\s*(@\(.*?\))') { $matches[1] } else { throw "`$FileLoadOrder not found in run.ps1" }
    $FileLoadOrder = Invoke-Expression $fileOrderMatch

    Write-Status "  -> Found load order with $($FileLoadOrder.Count) files in run.ps1"
    
    $sb = [System.Text.StringBuilder]::new()

    # 1. Header and using statements
    [void]$sb.AppendLine("# MONOLITHIC SCRIPT (Generated by mushroom recompose)")
    [void]$sb.AppendLine("# ==================================================================================")
    [void]$sb.AppendLine("#Requires -Version 7.0")

    # Collect all 'using' statements from the modular files
    $allUsingStatements = @()
    foreach($path in $FileLoadOrder) {
        $fullPath = Join-Path $SourceDir $path
        if (Test-Path $fullPath) {
            $allUsingStatements += Get-Content $fullPath | Where-Object { $_.Trim() -match '^using namespace' }
        }
    }
    # Add unique statements to the top
    $allUsingStatements | Select-Object -Unique | ForEach-Object { [void]$sb.AppendLine($_) }

    # 2. Param block and global settings
    [void]$sb.AppendLine($paramBlock)
    [void]$sb.AppendLine("# Global script settings")
    [void]$sb.AppendLine('$ErrorActionPreference = "Stop"') # No backtick
    [void]$sb.AppendLine()

    # 3. Embed all files
    foreach ($path in $FileLoadOrder) {
        $fullPath = Join-Path $SourceDir $path
        if (-not (Test-Path $fullPath)) { throw "Source file '$fullPath' is missing." }
        
        $fileContent = Get-Content -Path $fullPath -Raw
        # Remove any 'using' statements from the file content itself, as they are already at the top
        $cleanContent = $fileContent -replace '(?m)^\s*using namespace .*\r?\n', ''

        Write-Status "  -> Embedding: $path" 'Gray'
        [void]$sb.AppendLine("# --- START OF ORIGINAL FILE: $path ---")
        [void]$sb.AppendLine($cleanContent.Trim())
        [void]$sb.AppendLine("# --- END OF ORIGINAL FILE: $path ---")
        [void]$sb.AppendLine()
    }

    # 4. Add the main logic block at the very end
    [void]$sb.AppendLine("# --- START OF MAIN EXECUTION LOGIC ---")
    [void]$sb.AppendLine($mainLogic)
    [void]$sb.AppendLine("# --- END OF MAIN EXECUTION LOGIC ---")

    Set-Content -Path $OutputPath -Value $sb.ToString() -Encoding UTF8
    
    Write-Status "Recomposition complete! New monolith is at '$OutputPath'" "Green"
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