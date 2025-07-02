# navigation-service-functions.psm1
# Contains only the factory function for the NavigationService.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-NavigationService {
    param([hashtable]$Services)
    if (-not $Services) { throw [System.ArgumentNullException]::new("Services") }
    return [NavigationService]::new($Services)
}

Export-ModuleMember -Function 'Initialize-NavigationService'