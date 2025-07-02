@{
    RootModule = 'panels-class.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'c3d4e5f6-g7h8-9012-cdef-345678901234'
    Author = 'PMC Terminal'
    Description = 'Panel layout containers - Panel, ScrollablePanel, GroupPanel'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        @{ ModuleName = '..\components\ui-classes.psd1'; RequiredVersion = '1.0.0' }
    )
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    ClassesToExport = @(
        'Panel',
        'ScrollablePanel',
        'GroupPanel'
    )
}
