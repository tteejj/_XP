@{
    # Module manifest for Dialog System Class
    RootModule = 'dialog-system-class.psm1'
    ModuleVersion = '3.0.0'
    GUID = '4e3f2a1b-9c8d-5e4f-2a1b-9c8d5e4f2a1b'
    Author = 'PMC Terminal Development Team'
    CompanyName = 'PMC Terminal'
    Copyright = '© 2024 PMC Terminal. All rights reserved.'
    Description = 'Modal dialog system for TUI applications, featuring promise-based async API, theme integration, and comprehensive dialog types.'
    
    PowerShellVersion = '7.0'
    
    # Dependencies
    RequiredModules = @(
        @{ ModuleName = 'ui-classes'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'tui-components'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'tui-primitives'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'theme-manager'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' }
    )
    
    # Functions to export
    FunctionsToExport = @(
        'Show-AlertDialog'
        'Show-ConfirmDialog'
        'Show-InputDialog'
        'Get-WordWrappedLines'
    )
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Classes to export (automatically available)
    # Dialog, AlertDialog, ConfirmDialog, InputDialog
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'Dialog', 'Modal', 'UI', 'Alert', 'Confirm', 'Input', 'Promise', 'Async')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = @'
v5.0.0:
- Promise-based async API with await support
- Full theme integration with semantic color keys
- Component lifecycle management with proper initialization and cleanup
- Enhanced InputDialog using TextBoxComponent composition
- Improved keyboard navigation and accessibility
- Comprehensive error handling and logging
- Automatic dialog positioning and sizing
- Support for custom dialog types through base Dialog class
'@
        }
    }
}
