function Start-PMCTerminal {
    [CmdletBinding()]
    param()
    
    & "$PSScriptRoot\axiom.ps1" -DebugLoading
}

Export-ModuleMember -Function Start-PMCTerminal
