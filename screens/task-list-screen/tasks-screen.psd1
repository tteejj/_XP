@{
    RootModule = 'tasks-screen.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'k1l2m3n4-o5p6-7890-klmn-123456789012'
    Author = 'PMC Terminal'
    Description = 'Tasks screen implementation'
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
        'TaskListScreen'
    )
}
