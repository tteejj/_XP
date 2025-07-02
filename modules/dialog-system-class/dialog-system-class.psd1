@{
    ModuleVersion = '1.0.0'
    GUID = '8b9c0d1e-2f3a-4b5c-6d7e-8f9a0b1c2d3e'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Description = 'Class-based dialog system with UIElement inheritance'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @(
        @{ ModuleName = 'exceptions'; ModuleVersion = '1.0.0'; RequiredVersion = '1.0.0' },
        @{ ModuleName = 'event-system'; ModuleVersion = '1.0.0'; RequiredVersion = '1.0.0' }
    )
    FunctionsToExport = @(
        'Initialize-DialogSystem', 'Show-AlertDialog', 'Show-ConfirmDialog', 
        'Show-InputDialog', 'Show-ProgressDialog', 'Show-ListDialog', 'Close-TuiDialog'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Dialog', 'UI', 'Classes', 'TUI')
            ReleaseNotes = 'Dialog classes: Alert, Confirm, Input, Progress, List dialogs'
        }
    }
}
