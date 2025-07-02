@{
    RootModule = 'advanced-data-components.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'e5f6g7h8-i9j0-1234-efgh-567890123456'
    Author = 'PMC Terminal'
    Description = 'Advanced data components - Table, DataTableComponent'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        @{ ModuleName = 'ui-classes'; ModuleVersion = '1.0.0' }
    )
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    ClassesToExport = @(
        'Table',
        'DataTableComponent'
    )
}
