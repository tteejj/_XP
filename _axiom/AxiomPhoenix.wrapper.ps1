# Type-Safe Wrapper for AxiomPhoenix.ps1
# This wrapper ensures all types are loaded before execution

$ErrorActionPreference = 'Stop'

# Load the monolith in a way that allows type resolution
& {
    # First, dot-source to load all type definitions
    . 'AxiomPhoenix.ps1'
    
    # Types should now be available
    Write-Host "Monolith loaded successfully!" -ForegroundColor Green
}
