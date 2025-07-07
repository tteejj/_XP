#------------------------------------------------------------------------------------------
# SCRIPT:      filecopy-and-concatenate.ps1
#
# DESCRIPTION: Finds specified file types in a given path and its subdirectories.
#              For each file, it can create a .txt copy and/or concatenate all
#              file contents into a single output file.
#
# FEATURES:
#   - Full parameter support for path, file types, and output name.
#   - Safety features: Supports -WhatIf and -Confirm for all file operations.
#   - Verbose output: Use the -Verbose switch to see detailed progress.
#   - Performance: Uses an efficient single-write operation for the concatenated file.
#   - Robustness: Uses idiomatic PowerShell for path manipulation and error handling.
#   - Compatibility: Works on Windows PowerShell 5.1 and newer.
#   - NEW: Can create individual .txt copies of each source file.
#
# USAGE:
#   # Basic run in the current folder for PowerShell files
#   .\filecopy-and-concatenate.ps1 -Verbose
#
#   # Run on a different project, for C# files, with a different output name
#   .\filecopy-and-concatenate.ps1 -Path "C:\Projects\MyWebApp" -Include "*.cs" -OutputFileName "SourceCode.txt"
#
#   # To also create individual .txt copies of each file:
#   .\filecopy-and-concatenate.ps1 -CreateIndividualCopies -Verbose
#
#   # Perform a "dry run" to see what would happen without making any changes
#   .\filecopy-and-concatenate.ps1 -Path "C:\SomethingImportant" -CreateIndividualCopies -WhatIf
#
#------------------------------------------------------------------------------------------

# Enable support for -WhatIf, -Confirm, and advanced parameter binding
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # The starting directory to search in. Defaults to the current directory.
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "The root path to search for files.")]
    [string]
    $Path = (Get-Location).Path,

    # An array of file patterns to include. Defaults to PowerShell script files.
    [Parameter(Mandatory = $false, HelpMessage = "File patterns to include, e.g., '*.ps1', '*.psm1'.")]
    [string[]]
    $Include = @("*.ps1", "*.psm1"),

    # The name of the final concatenated output file.
    [Parameter(Mandatory = $false, HelpMessage = "Name of the concatenated output file.")]
    [string]
    $OutputFileName = "all.txt",

    # Switch to create a .txt copy of each individual file found.
    [Parameter(Mandatory = $false, HelpMessage = "If specified, creates a .txt copy of each found file.")]
    [switch]
    $CreateIndividualCopies
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    # Resolve-Path returns a PathInfo object. We use it for robustness.
    $resolvedPathObject = Resolve-Path -Path $Path
    $basePathString = $resolvedPathObject.Path # Store the string path for reuse
    $outputFilePath = Join-Path -Path $basePathString -ChildPath $OutputFileName

    Write-Verbose "Starting operations in: $basePathString"
    Write-Verbose "Searching for file types: $($Include -join ', ')"
    Write-Verbose "Output file will be: $outputFilePath"
    if ($CreateIndividualCopies.IsPresent) {
        Write-Verbose "Individual .txt copies will be created."
    }

    # --- Step 1: Find all specified files recursively ---
    $filesToProcess = Get-ChildItem -Path $basePathString -Recurse -Include $Include -File

    if ($null -eq $filesToProcess) {
        Write-Warning "No files found matching the specified criteria."
        return # Exit gracefully if no files are found
    }

    Write-Verbose "Found $($filesToProcess.Count) files to process."

    # --- Step 2: Clear the existing output file if it exists ---
    # This is part of the concatenation process, so it's good to do it early.
    if ((Test-Path $outputFilePath) -and $PSCmdlet.ShouldProcess($outputFilePath, "Remove existing output file")) {
        Remove-Item $outputFilePath -Force
    }

    # --- Step 3: Process each file for individual copies (if requested) ---
    if ($CreateIndividualCopies.IsPresent) {
        Write-Verbose "Processing files to create individual .txt copies..."
        foreach ($file in $filesToProcess) {
            # Create a new filename by changing the extension to .txt
            $txtCopyPath = [System.IO.Path]::ChangeExtension($file.FullName, ".txt")

            # Use ShouldProcess for -WhatIf and -Confirm support
            if ($PSCmdlet.ShouldProcess($txtCopyPath, "Copy from '$($file.Name)'")) {
                Copy-Item -Path $file.FullName -Destination $txtCopyPath -Force
                Write-Verbose "Created copy: '$txtCopyPath'"
            }
        }
    }

    # --- Step 4: Concatenate all files into the output file (Efficiently) ---
    Write-Verbose "Starting concatenation of all files into '$OutputFileName'..."
    if ($PSCmdlet.ShouldProcess($outputFilePath, "Concatenate $($filesToProcess.Count) files")) {
        # Using a subexpression `$(...)` to gather all output before writing to the file once.
        Set-Content -Path $outputFilePath -Encoding UTF8 -Value $(
            foreach ($file in $filesToProcess) {
                # Calculate the relative path for the header
                $relativePath = $file.FullName.Substring($basePathString.Length)
                # Ensure consistent format like '\subdir\file.ps1'
                $relativePath = '\' + $relativePath.TrimStart('\/')

                # Output the header for this file
                "####$relativePath"

                # Output the file's content
                Get-Content -Path $file.FullName -Raw -Encoding Default

                # Output two blank lines for separation
                ""
                ""
            }
        )
        Write-Host "All operations complete. Concatenated content saved to '$outputFilePath'."
    }
}
catch {
    # A global catch block for any unexpected, terminating errors.
    Write-Error "A critical error occurred: $($_.Exception.Message)"
    Write-Error "Script execution halted at line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line)"
}