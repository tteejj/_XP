@{
    # Module manifest for Advanced Data Components
    RootModule = 'advanced-data-components.psm1'
    ModuleVersion = '3.0.0'
    GUID = '8f9e6d2c-1a4b-4c3d-9e8f-2c1a4b3d9e8f'
    Author = 'PMC Terminal Development Team'
    CompanyName = 'PMC Terminal'
    Copyright = '© 2024 PMC Terminal. All rights reserved.'
    Description = 'Advanced data display components for TUI applications, featuring high-performance scrollable tables with theme integration and event-driven selection.'
    
    PowerShellVersion = '7.0'
    
    # Dependencies
#    RequiredModules = @(
#        @{ ModuleName = 'tui-primitives'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'ui-classes'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'theme-manager'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' }
#    )
    
    # Functions to export
    FunctionsToExport = @(
        'New-TuiTable'
    )
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Classes to export (automatically available)
    # Table, TableColumn
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'Table', 'DataGrid', 'Components', 'UI')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = @'
v3.0.0:
- Added high-performance viewport scrolling for large datasets
- Full theme integration with ThemeManager
- Dynamic column sizing with 'Auto' width support
- Event-driven selection with OnSelectionChanged callback
- Enhanced cell formatting with alignment and overflow handling
- Improved error handling and logging
- Parameter validation for better type safety
'@
        }
    }
}
