# Deconstruct-Monolith.ps1 (v2 - Automated Refactoring)
# This script reverses the monolith creation process, automatically creating a
# runnable, modular project structure by synthesizing a new runner script.

param(
    [string]$MonolithPath = ".\Monolithic-PMCTerminal.txt",
    [string]$BuildScriptPath = ".\monolith.txt",
    [string]$OutputDirectory = ".\Restored-PMCTerminal"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Starting intelligent deconstruction of '$MonolithPath'..." -ForegroundColor Yellow

# --- 1. Setup Output Directory ---
if (Test-Path $OutputDirectory) {
    Write-Host "Output directory '$OutputDirectory' already exists. Cleaning it for a fresh restore..." -ForegroundColor DarkYellow
    Get-ChildItem -Path $OutputDirectory -Recurse | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
Write-Host "Created clean output directory: $OutputDirectory" -ForegroundColor Green

# --- 2. Read Input Files ---
if (-not (Test-Path $MonolithPath)) { throw "Monolithic script not found at: $MonolithPath" }
if (-not (Test-Path $BuildScriptPath)) { throw "Build script ('$BuildScriptPath') not found. It is required to get the file load order." }

$monolithContent = Get-Content -Path $MonolithPath -Raw
$buildScriptContent = Get-Content -Path $BuildScriptPath -Raw

# --- 3. Extract All Necessary Components ---

# A. Extract the top-level parameter block from the monolith
$paramBlockRegex = '(?msi)^param\s*\((.*?)\)'
$paramBlock = ""
if ($monolithContent -match $paramBlockRegex) {
    $paramBlock = $matches[0]
    Write-Host "  -> Extracted top-level param() block." -ForegroundColor Cyan
}

# B. Extract the main logic block from the monolith
$mainLogicRegex = '(?ms)# --- START OF MAIN EXECUTION LOGIC \(from _CLASSY-MAIN\.ps1\).*?---\r?\n(.*?)\r?\n# --- END OF MAIN EXECUTION LOGIC ---'
$mainLogicContent = ""
if ($monolithContent -match $mainLogicRegex) {
    $mainLogicContent = $matches[1].Trim()
    Write-Host "  -> Extracted main execution logic." -ForegroundColor Cyan
} else {
    throw "Could not find the main execution logic block in the monolith."
}

# C. Extract the individual file contents from the monolith
$fileContentRegex = '(?ms)# --- START OF ORIGINAL FILE: (.*?)\s*---\r?\n(.*?)\r?\n# --- END OF ORIGINAL FILE:'
$fileMatches = [regex]::Matches($monolithContent, $fileContentRegex)
if ($fileMatches.Count -eq 0) {
    throw "No file markers found in the monolithic script. Cannot deconstruct."
}
Write-Host "  -> Found $($fileMatches.Count) individual file sections to restore." -ForegroundColor Cyan

# D. Extract the file load order from the build script
$fileOrderRegex = '(?msi)\$FileLoadOrder\s*=\s*@\((.*?)\)'
$fileOrderArrayString = ""
if ($buildScriptContent -match $fileOrderRegex) {
    # Reconstruct the array definition string for the new runner script
    $fileOrderArrayString = "@(" + "`r`n" + $matches[1].Trim() + "`r`n" + ")"
    Write-Host "  -> Extracted file load order from build script." -ForegroundColor Cyan
} else {
    throw "Could not find `$FileLoadOrder in the build script '$BuildScriptPath'."
}


# --- 4. Re-assemble the Modular Project ---

Write-Host "`nAssembling restored project..." -ForegroundColor Yellow

# A. Write the individual module files
foreach ($match in $fileMatches) {
    $originalPath = $match.Groups[1].Value.Trim()
    $fileContent = $match.Groups[2].Value.Trim()
    $destinationPath = Join-Path $OutputDirectory $originalPath
    $destinationDir = Split-Path $destinationPath -Parent
    if (-not (Test-Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }
    Set-Content -Path $destinationPath -Value $fileContent -Encoding UTF8
    Write-Host "  -> Restored: $originalPath"
}

# B. Write the main logic to _CLASSY-MAIN.ps1 (without params)
$mainLogicPath = Join-Path $OutputDirectory "_CLASSY-MAIN.ps1"
Set-Content -Path $mainLogicPath -Value $mainLogicContent -Encoding UTF8
Write-Host "  -> Restored: _CLASSY-MAIN.ps1 (as logic container)" -ForegroundColor Green

# C. Synthesize and write the new runner script
$runnerScriptPath = Join-Path $OutputDirectory "Run-Application.ps1"
$runnerScriptContent = @"
# Run-Application.ps1
# This script is the main entry point for the deconstructed application.
# It loads all modules in the correct order and then executes the main logic.

$paramBlock

Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"

`$PSScriptRoot = Get-Location
`$MainScriptPath = Join-Path `$PSScriptRoot '_CLASSY-MAIN.ps1'

# This is the verified load order, taken from the original build script.
`$FileLoadOrder = $fileOrderArrayString

Write-Host "Loading application modules..." -ForegroundColor Cyan

# Use dot-sourcing to load all functions and classes into the current scope.
foreach (`$filePath in `$FileLoadOrder) {
    `$fullPath = Join-Path `$PSScriptRoot `$filePath
    if (Test-Path `$fullPath) {
        # Write-Host "  -> Loading `$filePath" # Uncomment for verbose loading
        . `$fullPath
    } else {
        Write-Warning "Module file not found, skipping: `$filePath"
    }
}

Write-Host "All modules loaded. Starting application..." -ForegroundColor Green

# Now that everything is loaded, execute the main script logic.
& `$MainScriptPath @PSBoundParameters

"@
Set-Content -Path $runnerScriptPath -Value $runnerScriptContent -Encoding UTF8
Write-Host "  -> SYNTHESIZED: Run-Application.ps1 (as new entry point)" -ForegroundColor Green

# D. Restore the build script itself
$buildScriptDestPath = Join-Path $OutputDirectory "Create-Monolith.ps1"
Set-Content -Path $buildScriptDestPath -Value $buildScriptContent -Encoding UTF8
Write-Host "  -> Restored: Create-Monolith.ps1" -ForegroundColor Green

Write-Host "`nDeconstruction complete. Project restored to: $OutputDirectory" -ForegroundColor Yellow
Write-Host "To run the application, use: '.\Run-Application.ps1'" -ForegroundColor White