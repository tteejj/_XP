@{
    RootModule = 'tui-primitives.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'PMC Terminal'
    Description = 'Core TUI primitives - TuiCell and TuiBuffer classes'
    PowerShellVersion = '7.0'
    RequiredModules = @()
    FunctionsToExport = @(
        'Write-TuiText',
        'Write-TuiBox'
    )
#    CmdletsToExport = @()
#    VariablesToExport = @()
#    AliasesToExport = @()
#    ClassesToExport = @()
#        'TuiCell',
#        'TuiBuffer'
#    )
}
