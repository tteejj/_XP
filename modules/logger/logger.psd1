@{
    ModuleVersion = '1.0.0'
    GUID = '1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Description = 'Robust logging system with multiple output targets and performance monitoring'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @()
    FunctionsToExport = @(
        'Initialize-Logger', 'Write-Log', 'Trace-FunctionEntry', 'Trace-FunctionExit', 
        'Trace-Step', 'Trace-StateChange', 'Trace-ComponentLifecycle', 'Trace-ServiceCall',
        'Get-LogEntries', 'Get-CallTrace', 'Clear-LogQueue', 'Set-LogLevel', 
        'Enable-CallTracing', 'Disable-CallTracing', 'Get-LogPath', 'Get-LogStatistics'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Logging', 'Diagnostics', 'TUI')
            ReleaseNotes = 'Self-contained logging module with performance monitoring'
        }
    }
}
