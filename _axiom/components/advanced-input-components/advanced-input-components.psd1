@{
    # Module manifest for Advanced Input Components
    RootModule = 'advanced-input-components.psm1'
    ModuleVersion = '3.0.0'
    GUID = '3c2d5e4f-7a8b-9c0d-1e2f-3a4b5c6d7e8f'
    Author = 'PMC Terminal Development Team'
    CompanyName = 'PMC Terminal'
    Copyright = '© 2024 PMC Terminal. All rights reserved.'
    Description = 'Advanced input components for TUI applications, featuring multiline text, numeric input, date selection, and dropdown controls with theme integration and overlay rendering.'
    
    PowerShellVersion = '7.0'
    
    # Dependencies
#    RequiredModules = @(
#        @{ ModuleName = 'ui-classes'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'tui-components'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'tui-primitives'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'theme-manager'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' }
#    )
    
    # Functions to export
    FunctionsToExport = @(
        'New-TuiMultilineTextBox'
        'New-TuiNumericInput'
        'New-TuiDateInput'
        'New-TuiComboBox'
    )
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Classes to export (automatically available)
    # MultilineTextBoxComponent, NumericInputComponent, DateInputComponent, ComboBoxComponent
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'Input', 'Advanced', 'Multiline', 'Numeric', 'Date', 'ComboBox', 'Dropdown', 'Overlay')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = @'
v5.0.0:
- Complete theme integration with semantic color keys
- Advanced cursor handling with non-destructive block cursors
- Bidirectional scrolling support for multiline text
- True overlay rendering for dropdown components
- Real-time input validation with visual feedback
- Performance optimizations with viewport-based rendering
- Enhanced keyboard navigation and accessibility
- Comprehensive error handling and logging
- Lifecycle management with proper resource cleanup
- Factory functions for easy component creation
'@
        }
    }
}
