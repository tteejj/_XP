# keybinding-service.psm1

# Contains only the factory function for creating KeybindingService instances.

using module keybinding-service-class

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

Export-ModuleMember -Function New-KeybindingService
