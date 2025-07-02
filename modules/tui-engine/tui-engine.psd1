@{
    RootModule = 'tui-engine.psm1'
    ModuleVersion = '5.1.0'
    GUID = 'b2c3d4e5-f6a7-8901-2345-678901bcdef2'
    Author = 'PMC Terminal'
    Description = 'TUI Engine for PMC Terminal'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        'PMC-TuiPrimitives',
        'PMC-UIClasses',
        'PMC-ThemeManager',
        'PMC-Logger',
        'PMC-EventSystem'
    )
    FunctionsToExport = @(
        'Initialize-TuiEngine',
        'Start-TuiLoop',
        'Push-Screen',
        'Pop-Screen',
        'Render-Frame',
        'Stop-TuiEngine'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
