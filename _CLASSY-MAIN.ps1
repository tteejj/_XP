using module '.\PMCTerminal\PMCTerminal.psd1'
# ==============================================================================
# PMC Terminal v5 "Helios" - Main Entry Point
# ==============================================================================

# Set strict mode and error preference for the entry script
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# The manifest in PMCTerminal.psd1 handles loading all other files.
# This single line replaces the entire previous list of `using module`.
# It loads the entire application as a single, coherent module.


# The execution logic (Start-PMCTerminal and the final try/catch block)
# has been moved into the root module file (PMCTerminal.psm1).
# When this script runs, it imports the module, which in turn automatically
# executes the logic contained within its .psm1 file.

# To run the application from an interactive console, you would now type:
#
# C:\> Import-Module .\PMCTerminal\PMCTerminal.psd1
# C:\> Start-PMCTerminal
#
# This file simply automates that process.

Write-Host "PMC Terminal module loaded. Execution is handled by the module itself." -ForegroundColor DarkGray