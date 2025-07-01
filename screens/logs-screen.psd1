@{
    RootModule = 'logs-screen.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'l2m3n4o5-p6q7-8901-lmno-234567890123'
    Author = 'PMC Terminal'
    Description = 'Logs screen implementation'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        @{ ModuleName = 'ui-classes'; RequiredVersion = '1.0.0'; ModuleVersion = '1.0.0' },
        @{ ModuleName = 'panels-class'; RequiredVersion = '1.0.0'; ModuleVersion = '1.0.0' },
        @{ ModuleName = 'tui-components'; RequiredVersion = '1.0.0'; ModuleVersion = '1.0.0' },
        @{ ModuleName = 'advanced-data-components'; RequiredVersion = '1.0.0'; ModuleVersion = '1.0.0' },
        @{ ModuleName = 'navigation-service-class'; RequiredVersion = '1.0.0'; ModuleVersion = '1.0.0' }
    )
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    ClassesToExport = @(
        'LogsScreen'
    )
}
