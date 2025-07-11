# Enable debug logging for CommandPalette testing
$env:AXIOM_LOG_LEVEL = "Debug"
$env:AXIOM_VERBOSE = "1"

# Run the main application
& "$PSScriptRoot\Start.ps1"
