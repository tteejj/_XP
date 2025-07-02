@{
    RootModule = 'navigation-class.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'g7h8i9j0-k1l2-3456-ghij-789012345678'
    Author = 'PMC Terminal'
    Description = 'Navigation components - NavigationItem, NavigationMenu'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        @{ ModuleName = '.\ui-classes.psd1'; RequiredVersion = '1.0.0' }
    )
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    ClassesToExport = @(
        'NavigationItem',
        'NavigationMenu'
    )
}
