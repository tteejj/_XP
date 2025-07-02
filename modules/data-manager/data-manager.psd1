@{
    RootModule = 'data-manager.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'c3d4e5f6-a7b8-9012-3456-789012cdef34'
    Author = 'PMC Terminal'
    Description = 'Data management for PMC Terminal'
    PowerShellVersion = '7.0'
    RequiredModules = @(
        'PMC-Models',
        'PMC-EventSystem',
        'PMC-Logger'
    )
    FunctionsToExport = @(
        'Initialize-DataManager',
        'Get-DataManager',
        'Add-Task',
        'Update-Task',
        'Remove-Task',
        'Get-AllTasks',
        'Get-TasksByStatus',
        'Add-Project',
        'Get-AllProjects',
        'Save-Data',
        'Load-Data'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
