@{
    ModuleVersion = '1.0.0'
    GUID = '3c4d5e6f-7a8b-9c0d-1e2f-3a4b5c6d7e8f'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Description = 'Advanced error handling and custom exception types for PMC Terminal'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @()
    FunctionsToExport = @('Invoke-WithErrorHandling', 'Get-ErrorHistory')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('ErrorHandling', 'Exceptions', 'TUI')
            ReleaseNotes = 'Custom exception types and centralized error handling wrapper'
        }
    }
}
