@{
    ModuleVersion = '1.0.0'
    GUID = '4d5e6f7a-8b9c-0d1e-2f3a-4b5c6d7e8f9a'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Description = 'Publish-subscribe event system for decoupled component communication'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @(
        @{ ModuleName = 'exceptions'; ModuleVersion = '1.0.0'; RequiredVersion = '1.0.0' }
    )
    FunctionsToExport = @(
        'Initialize-EventSystem', 'Publish-Event', 'Subscribe-Event', 'Unsubscribe-Event',
        'Get-EventHandlers', 'Clear-EventHandlers', 'Get-EventHistory', 'Remove-ComponentEventHandlers'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Events', 'PubSub', 'Messaging', 'TUI')
            ReleaseNotes = 'Event system with history tracking and component cleanup'
        }
    }
}
