@{
    ModuleVersion = '1.0.0'
    GUID = '5e6f7a8b-9c0d-1e2f-3a4b-5c6d7e8f9a0b'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Description = 'Theme and color management system for TUI applications'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @(
        @{ ModuleName = 'event-system'; ModuleVersion = '1.0.0'; RequiredVersion = '1.0.0' },
        @{ ModuleName = 'exceptions'; ModuleVersion = '1.0.0'; RequiredVersion = '1.0.0' }
    )
    FunctionsToExport = @(
        'Initialize-ThemeManager', 'Set-TuiTheme', 'Get-ThemeColor', 'Get-TuiTheme',
        'Get-AvailableThemes', 'New-TuiTheme', 'Export-TuiTheme', 'Import-TuiTheme'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Theming', 'Colors', 'UI', 'TUI')
            ReleaseNotes = 'Built-in themes with import/export capability'
        }
    }
}
