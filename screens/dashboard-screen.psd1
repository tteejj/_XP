@{
    RootModule = 'dashboard-screen.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a0b1c2d3-e4f5-6789-abcd-012345678901'
    Author = 'PMC Terminal'
    Description = 'Dashboard screen implementation'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        @{ ModuleName = '..\components\ui-classes.psd1'; RequiredVersion = '1.0.0' },
        @{ ModuleName = '..\layout\panels-class.psd1'; RequiredVersion = '1.0.0' },
        @{ ModuleName = '..\components\navigation-class.psd1'; RequiredVersion = '1.0.0' },
        @{ ModuleName = '..\components\tui-components.psd1'; RequiredVersion = '1.0.0' }
    )
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
