# keybinding-service.psm1
# Contains only the factory function for creating KeybindingService instances.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-KeybindingService {
    <#
    .SYNOPSIS
    Creates a new instance of the KeybindingService class.
    #>
    [CmdletBinding()]
    param(
        [switch]$EnableChords
    )
    
    if ($EnableChords) {
        return [KeybindingService]::new($true)
    }
    else {
        return [KeybindingService]::new()
    }
}

Export-ModuleMember -Function 'New-KeybindingService'