# micro.ps1 (FINAL v5 - Correct Structure)
# This script has the correct structure: Params, then ALL functions, then main logic.
# It will run with defaults and without errors.

[CmdletBinding()]
param(
    # The path to the monolithic script. Optional, defaults to axiom.ps1/axiom.txt.
    [Alias('Input', 'Mono')]
    [string]$MonolithScriptPath,

    # The directory for the restored project. Optional, defaults to _axiom.
    [Alias('Out', 'Path')]
    [string]$OutputDirectory,
    
    # The name of the new runner script.
    [Alias('Runner')]
    [string]$RunnerScriptName = "run.ps1"
)

# Set script-wide behaviors
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#==============================================================================
# FUNCTION DEFINITIONS
# All functions are defined first, before any of them are called.
#==============================================================================

function Setup-OutputDirectory {
    param([string]$Path)
    if (Test-Path $Path) {
        Write-Host "Output directory '$Path' already exists. Cleaning..." -ForegroundColor DarkYellow
        Get-ChildItem -Path $Path -Recurse | Remove-Item -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Write-Host "Created clean output directory: $Path" -ForegroundColor Green
}

function Extract-AllComponents {
    param([string]$monolithContent)
    Write-Host "`nPhase 1: Extracting components from monolith..." -ForegroundColor Yellow
    
    $mainLogicRegex = '(?msi)# --- END OF ORIGINAL FILE:.*?---\s*(.*?)\r?\n# --- END OF MAIN EXECUTION LOGIC ---'
    $paramBlockRegex = '(?msi)^param\s*\((.*?)\)'
    $fileContentRegex = '(?msi)# --- START OF ORIGINAL FILE: (.*?)\s*---\r?\n(.*?)\r?\n# --- END OF ORIGINAL FILE:'

    if ($monolithContent -match $paramBlockRegex) { $paramBlock = $matches[0]; Write-Host "  -> Extracted param() block." -ForegroundColor Cyan } else { $paramBlock = "" }
    if ($monolithContent -match $mainLogicRegex) { $mainLogicContent = $matches[1].Trim(); Write-Host "  -> Extracted main logic." -ForegroundColor Cyan } else { throw "Main logic block not found in monolith content." }
    
    $fileMatches = [regex]::Matches($monolithContent, $fileContentRegex)
    if ($fileMatches.Count -eq 0) { throw "No file markers (--- START OF ORIGINAL FILE ---) found in monolith." }
    
    $orderedFiles = @()
    foreach ($match in $fileMatches) {
        $orderedFiles += [PSCustomObject]@{
            Path    = $match.Groups[1].Value.Trim()
            Content = $match.Groups[2].Value.Trim()
        }
    }
    Write-Host "  -> Extracted $($orderedFiles.Count) files in their original order." -ForegroundColor Cyan
    
    return [PSCustomObject]@{
        ParamBlock   = $paramBlock
        MainLogic    = $mainLogicContent
        OrderedFiles = $orderedFiles
    }
}

function Assemble-Project {
    param([PSCustomObject]$Components, [string]$OutDir, [string]$RunnerName)
    Write-Host "`nPhase 2: Assembling modular project in '$OutDir'..." -ForegroundColor Yellow
    
    foreach ($file in $Components.OrderedFiles) {
        $destinationPath = Join-Path $OutDir $file.Path
        $destinationDir = Split-Path $destinationPath -Parent
        if (-not (Test-Path $destinationDir)) { New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null }
        Set-Content -Path $destinationPath -Value $file.Content -Encoding UTF8
        Write-Host "  -> Restored: $($file.Path)"
    }
    
    Synthesize-RunnerScript -Components $Components -OutDir $OutDir -RunnerName $RunnerName
    Synthesize-MegaScript -Components $Components -OutDir $OutDir
}

function Synthesize-RunnerScript {
    param([PSCustomObject]$Components, [string]$OutDir, [string]$RunnerName)
    $fileOrderString = @($Components.OrderedFiles.Path | ForEach-Object { "    '$_'" }) -join ",`r`n"
    $runnerScriptContent = @"
# $($RunnerName) - Main entry point for the deconstructed application.
# Synthesized by micro.ps1.

$($Components.ParamBlock)

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

# Load order derived directly from the original monolith's structure.
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
    $runnerScriptPath = Join-Path $OutDir $RunnerName; Set-Content -Path $runnerScriptPath -Value $runnerScriptContent -Encoding UTF8
    Write-Host "  -> SYNTHESIZED: $RunnerName (new entry point)" -ForegroundColor Green
}

function Synthesize-MegaScript {
    param([PSCustomObject]$Components, [string]$OutDir)
    $fileOrderString = @($Components.OrderedFiles.Path | ForEach-Object { "    '$_'" }) -join ",`r`n"
    $megaScriptContent = @"
# mega.ps1 - The Reconstructor
# Synthesized by micro.ps1 to enable a perfect round-trip build.

[CmdletBinding()]
param(
    [string]`$InputDirectory = ".",
    [string]`$OutputMonolithPath = "monolith.txt",
    [string]`$RunnerScriptName = "run.ps1"
)

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

Write-Host "MEGA: Reconstructing monolith from '`$InputDirectory'..."

`$runnerContent = Get-Content -Path (Join-Path `$InputDirectory `$RunnerScriptName) -Raw
`$paramBlock = if (`$runnerContent -match '(?msi)^param\s*\((.*?)\)') { `$matches[0] } else { '' }
`$mainLogic = if (`$runnerContent -match '(?msi)# --- MAIN EXECUTION LOGIC ---\r?\n(.*?)\s*`$') { `$matches[1].Trim() } else { throw "Main logic not found in `$RunnerScriptName" }

`$FileLoadOrder = @(
$fileOrderString
)

`$sb = [System.Text.StringBuilder]::new()
[void]`$sb.AppendLine("# MONOLITHIC SCRIPT (Generated by mega.ps1)")
[void]`$sb.AppendLine("`$paramBlock")
[void]`$sb.AppendLine('Set-StrictMode -Version Latest')
[void]`$sb.AppendLine('`$ErrorActionPreference = "Stop"')

foreach (`$path in `$FileLoadOrder) {
    `$fullPath = Join-Path `$InputDirectory `$path
    `$content = Get-Content -Path `$fullPath -Raw
    [void]`$sb.AppendLine("`n# --- START OF ORIGINAL FILE: `$path ---")
    [void]`$sb.AppendLine(`$content.Trim())
    [void]`$sb.AppendLine("# --- END OF ORIGINAL FILE: `$path ---")
}

[void]`$sb.AppendLine("`n# --- START OF MAIN EXECUTION LOGIC (from run.ps1) ---")
[void]`$sb.AppendLine(`$mainLogic)
[void]`$sb.AppendLine("# --- END OF MAIN EXECUTION LOGIC ---")

Set-Content -Path `$OutputMonolithPath -Value `$sb.ToString() -Encoding UTF8
Write-Host "New monolith created at: `$OutputMonolithPath" -ForegroundColor Green
"@
    $megaScriptPath = Join-Path $OutDir "mega.ps1"
    Set-Content -Path $megaScriptPath -Value $megaScriptContent -Encoding UTF8
    Write-Host "  -> SYNTHESIZED: mega.ps1 (for rebuilding)" -ForegroundColor Green
}


#==============================================================================
# SCRIPT EXECUTION
# This is the main body of the script. It runs after all functions are defined.
#==============================================================================

try {
    # --- Robust Path Resolution and Validation ---
    $ScriptDirectory = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }
    
    if (-not $PSBoundParameters.ContainsKey('MonolithScriptPath')) {
        $defaultPs1 = Join-Path $ScriptDirectory "axiom.ps1"
        $defaultTxt = Join-Path $ScriptDirectory "axiom.txt"
        if (Test-Path $defaultPs1) { $MonolithScriptPath = $defaultPs1 } 
        elseif (Test-Path $defaultTxt) { $MonolithScriptPath = $defaultTxt } 
        else { throw "Could not find default monolith file. Please provide a path using -MonolithScriptPath or ensure 'axiom.ps1' or 'axiom.txt' exists." }
    }
    
    if (-not $PSBoundParameters.ContainsKey('OutputDirectory')) {
        $OutputDirectory = Join-Path $ScriptDirectory "_axiom"
    }
    
    Write-Host "MICRO: Deconstructing '$MonolithScriptPath'..." -ForegroundColor Yellow

    if (-not (Test-Path $MonolithScriptPath)) { throw "Monolith file not found at: '$MonolithScriptPath'" }
    $monolithContent = Get-Content -Path $MonolithScriptPath -Raw
    if ([string]::IsNullOrWhiteSpace($monolithContent)) { throw "The monolith file '$MonolithScriptPath' is empty." }

    # Call the functions which are now loaded into memory
    Setup-OutputDirectory -Path $OutputDirectory
    $components = Extract-AllComponents -monolithContent $monolithContent
    Assemble-Project -Components $components -OutDir $OutputDirectory -RunnerName $RunnerScriptName

    Write-Host "`nDeconstruction complete!" -ForegroundColor Yellow
    Write-Host "Project restored to: '$OutputDirectory'" -ForegroundColor White
    Write-Host "To run the application, execute: `"$OutputDirectory\$RunnerScriptName`"" -ForegroundColor White
    
} catch {
    Write-Host ""
    Write-Host "==================== SCRIPT HALTED ====================" -ForegroundColor Red
    Write-Host "REASON: $($_.Exception.Message)" -ForegroundColor Yellow
    if ($_.InvocationInfo) { Write-Host "At line: $($_.InvocationInfo.ScriptLineNumber) in $($_.InvocationInfo.ScriptName)" -ForegroundColor Yellow }
    Write-Host "=======================================================" -ForegroundColor Red
    exit 1
}