@{
    RootModule = 'ui-core.psm1'
    ModuleVersion = '1.3.1' # Incremented version
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    Author = 'Your Name'
    Description = 'Axiom-Phoenix Core UI Classes (Primitives, UIElement, Panel, and all standard/advanced components)'
    
    FunctionsToExport = @(
        'New-TuiBuffer', 'Write-TuiText', 'Write-TuiBox',
        'New-TuiLabel', 'New-TuiButton', 'New-TuiTextBox', 'New-TuiCheckBox', 'New-TuiRadioButton',
        'New-TuiTable',
        'New-TuiMultilineTextBox', 'New-TuiNumericInput', 'New-TuiDateInput', 'New-TuiComboBox',
        'Show-AlertDialog', 'Show-ConfirmDialog', 'Show-InputDialog', 'Get-WordWrappedLines',
        'Register-CommandPalette'
    )
    
    # Classes defined in the RootModule are exported automatically by PowerShell 7+
    # and do not need to be listed here.
    
    # FIX: Corrected the format for RequiredModules to include a version.
    RequiredModules = @(
        @{ ModuleName = 'theme-manager'; ModuleVersion = '1.0.0' },
        @{ ModuleName = 'exceptions'; ModuleVersion = '1.0.0' }
    )
    
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'UI', 'Framework', 'Core', 'Components', 'All-In-One')
        }
    }
}