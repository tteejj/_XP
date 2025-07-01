@{
    RootModule = 'PMCTerminal.psm1'
    ModuleVersion = '5.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Description = 'PMC Terminal v5 "Axiom" - Component-based PowerShell TUI Framework'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    
    RequiredModules = @(
        'PMC-TuiEngine',
        'PMC-DashboardScreen',
        'PMC-TasksScreen',
        'PMC-NavigationService',
        'PMC-DataManager'
    )
    
    FunctionsToExport = @(
        'Start-PMCTerminal'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'PowerShell', 'Terminal', 'Axiom')
            ReleaseNotes = 'Axiom architecture - component-based with manifest dependencies'
        }
    }
}
