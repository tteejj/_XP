@{
    RootModule = 'ui-classes.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b2c3d4e5-f6g7-8901-bcde-f23456789012'
    Author = 'PMC Terminal'
    Description = 'Base UI classes - UIElement, Component, Panel, Screen foundations'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        @{ ModuleName = '.\tui-primitives.psd1'; RequiredVersion = '1.0.0' }
    )
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    ClassesToExport = @(
        'UIElement',
        'Component', 
        'Panel',
        'Screen'
    )
}
