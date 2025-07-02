@{
    ModuleVersion = '1.0.0'
    GUID = '7a8b9c0d-1e2f-3a4b-5c6d-7e8f9a0b1c2d'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Description = 'TUI framework utilities and async job management'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @(
        @{ ModuleName = 'exceptions'; ModuleVersion = '1.0.0'; RequiredVersion = '1.0.0' },
        @{ ModuleName = 'event-system'; ModuleVersion = '1.0.0'; RequiredVersion = '1.0.0' }
    )
    FunctionsToExport = @(
        'Invoke-TuiMethod', 'Initialize-TuiFramework', 'Invoke-TuiAsync', 'Get-TuiAsyncResults',
        'Stop-AllTuiAsyncJobs', 'Request-TuiRefresh', 'Get-TuiState', 'Test-TuiState'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Framework', 'Utilities', 'Async', 'TUI')
            ReleaseNotes = 'Framework utilities with async job management and state validation'
        }
    }
}
