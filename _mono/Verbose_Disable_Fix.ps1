# Add this at the beginning of Start.ps1, right after the script header
# Disable verbose output to prevent JSON serialization warnings
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'

# Only enable verbose output if explicitly requested
if ($env:AXIOM_VERBOSE -eq '1') {
    $VerbosePreference = 'Continue'
}
