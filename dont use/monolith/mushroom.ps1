<#
.SYNOPSIS
A tool to split a large, monolithic PowerShell script into smaller, logical chunks
and rejoin them. The script intelligently splits at module boundaries.

.DESCRIPTION
This script has two modes of operation, controlled by switches:

-Split: Reads a large input file (like all.txt) and splits it into a specified
        number of chunk files. It identifies module boundaries defined by comments
        like "--- START OF FILE ---" and ensures that no chunk ends in the middle
        of a module.

-Join:  Finds all chunk files in a directory, sorts them numerically, and
        concatenates them back into a single, complete monolithic script.

.PARAMETER Split
Activates the splitting functionality.

.PARAMETER Join
Activates the joining (reconstruction) functionality.

.PARAMETER InputFile
[Split Mode] The path to the monolithic file to be split.
Default: 'all.txt'

.PARAMETER OutputFile
[Join Mode] The path for the reconstructed monolithic file.
Default: 'reconstructed_all.txt'

.PARAMETER ChunkDirectory
The directory where chunk files are stored (for splitting) or read from (for joining).
Default: 'chunks'

.PARAMETER NumChunks
[Split Mode] The number of chunks to create.
Default: 4

.PARAMETER Force
If specified, the script will overwrite the chunk directory (in split mode) or the
output file (in join mode) if they already exist.

.EXAMPLE
# Split 'all.txt' into 4 chunks in the 'chunks' directory
./manage_monolith.ps1 -Split

.EXAMPLE
# Split 'my_script.txt' into 10 chunks, overwriting the 'chunks' dir if it exists
./manage_monolith.ps1 -Split -InputFile 'my_script.txt' -NumChunks 10 -Force

.EXAMPLE
# Join the chunks from the 'chunks' directory back into 'reconstructed_all.txt'
./manage_monolith.ps1 -Join

.EXAMPLE
# Join chunks from './my_chunks' into 'final.ps1', overwriting if it exists
./manage_monolith.ps1 -Join -ChunkDirectory './my_chunks' -OutputFile 'final.ps1' -Force
#>
[CmdletBinding(DefaultParameterSetName = 'Split')]
param(
    # --- Split Parameter Set ---
    [Parameter(Mandatory, ParameterSetName = 'Split', HelpMessage = "Activates the splitting functionality.")]
    [switch]$Split,

    [Parameter(ParameterSetName = 'Split')]
    [ValidateRange(2, 20)]
    [int]$NumChunks = 4,

    [Parameter(ParameterSetName = 'Split')]
    [string]$InputFile = "all.txt",

    # --- Join Parameter Set ---
    [Parameter(Mandatory, ParameterSetName = 'Join', HelpMessage = "Activates the joining (reconstruction) functionality.")]
    [switch]$Join,

    [Parameter(ParameterSetName = 'Join')]
    [string]$OutputFile = "reconstructed_all.txt",

    # --- Common Parameters ---
    [Parameter(ParameterSetName = 'Split')]
    [Parameter(ParameterSetName = 'Join')]
    [string]$ChunkDirectory = "chunks",

    [switch]$Force
)

# --- Main Logic ---
# Use a switch on the parameter set name to determine the action
switch ($PSCmdlet.ParameterSetName) {
    'Split' {
        Write-Host "--- Performing SPLIT operation ---" -ForegroundColor Cyan

        # 1. Validate input file exists
        if (-not (Test-Path -LiteralPath $InputFile)) {
            Write-Error "Input file not found: '$InputFile'"
            return
        }

        # 2. Setup the output directory
        if (Test-Path -LiteralPath $ChunkDirectory) {
            if ($Force) {
                Write-Warning "Forcing removal of existing chunk directory: $ChunkDirectory"
                Remove-Item -Path $ChunkDirectory -Recurse -Force
            }
            else {
                Write-Error "Chunk directory '$ChunkDirectory' already exists. Use -Force to overwrite."
                return
            }
        }
        New-Item -Path $ChunkDirectory -ItemType Directory -Force | Out-Null
        Write-Host "Created clean output directory: $ChunkDirectory"

        # 3. Read the file and identify all logical units (modules/blocks)
        $lines = Get-Content -Path $InputFile
        $logicalUnits = [System.Collections.Generic.List[object]]::new()
        $currentUnitLines = [System.Collections.Generic.List[string]]::new()
        $isFirstUnit = $true

        Write-Host "Analyzing '$InputFile' for logical units..."
        foreach ($line in $lines) {
            if ($line -match "^# --- START OF (ORIGINAL FILE|FULL REPLACEMENT|REPLACEMENT BLOCK|MAIN EXECUTION LOGIC)") {
                if ($currentUnitLines.Count -gt 0) {
                    $logicalUnits.Add([pscustomobject]@{ Content = $currentUnitLines.ToArray() })
                    $currentUnitLines.Clear()
                }
            }
            $currentUnitLines.Add($line)
        }
        if ($currentUnitLines.Count -gt 0) {
            $logicalUnits.Add([pscustomobject]@{ Content = $currentUnitLines.ToArray() })
        }
        Write-Host "Found $($logicalUnits.Count) logical code blocks to distribute."

        # 4. Distribute the logical units into the specified number of chunks
        $unitsPerChunk = [Math]::Ceiling($logicalUnits.Count / $NumChunks)
        $unitIndex = 0

        for ($chunkNum = 1; $chunkNum -le $NumChunks; $chunkNum++) {
            $chunkContent = [System.Collections.Generic.List[string]]::new()
            $unitsInThisChunk = $logicalUnits | Select-Object -Skip $unitIndex -First $unitsPerChunk
            if ($unitsInThisChunk.Count -eq 0) { continue }

            foreach ($unit in $unitsInThisChunk) {
                $chunkContent.AddRange($unit.Content)
            }

            $chunkFilePath = Join-Path $ChunkDirectory "chunk_$($chunkNum).txt"
            $chunkContent | Set-Content -Path $chunkFilePath
            Write-Host " - Created '$chunkFilePath' with $($unitsInThisChunk.Count) logical units."
            $unitIndex += $unitsPerChunk
        }

        Write-Host "`n✅ Monolith successfully split into $NumChunks chunks in the '$ChunkDirectory' directory."
    }

    'Join' {
        Write-Host "--- Performing JOIN operation ---" -ForegroundColor Cyan

        # 1. Check if chunk directory exists
        if (-not (Test-Path -LiteralPath $ChunkDirectory)) {
            Write-Error "Chunk directory not found: '$ChunkDirectory'. Cannot join."
            return
        }

        # 2. Find and sort all chunk files
        $chunkFiles = Get-ChildItem -Path $ChunkDirectory -Filter "chunk_*.txt" |
                      Sort-Object { [int]($_.Name -replace '\D') }

        if (-not $chunkFiles) {
            Write-Error "No chunk files found in the '$ChunkDirectory' directory."
            return
        }
        Write-Host "Found $($chunkFiles.Count) chunks to reconstruct."

        # 3. Clear any old reconstructed file
        if (Test-Path -LiteralPath $OutputFile) {
            if ($Force) {
                Write-Warning "Forcing removal of existing output file: '$OutputFile'"
                Remove-Item -LiteralPath $OutputFile -Force
            }
            else {
                Write-Error "Output file '$OutputFile' already exists. Use -Force to overwrite."
                return
            }
        }

        # 4. Reassemble the file
        Write-Host "Reconstructing into '$OutputFile'..."
        foreach ($file in $chunkFiles) {
            Get-Content -Path $file.FullName -Raw | Add-Content -Path $OutputFile
            # Ensure a newline exists between joined files
            Add-Content -Path $OutputFile -Value ""
            Write-Host " - Appended '$($file.Name)'"
        }

        Write-Host "`n✅ Reconstruction complete. Monolithic script saved to '$OutputFile'."
    }
}