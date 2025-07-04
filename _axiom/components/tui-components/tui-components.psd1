@{
    # Module manifest for TUI Components
    RootModule = 'tui-components.psm1'
    ModuleVersion = '3.0.0'
    GUID = '9a8b7c6d-5e4f-3a2b-9c8d-7e6f5a4b3c2d'
    Author = 'PMC Terminal Development Team'
    CompanyName = 'PMC Terminal'
    Copyright = '© 2024 PMC Terminal. All rights reserved.'
    Description = 'Core interactive UI components for TUI applications, featuring theme integration, advanced input handling, and comprehensive state management.'
    
    PowerShellVersion = '7.0'
    
    # Dependencies
    RequiredModules = @(
        @{ ModuleName = 'ui-classes'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'tui-primitives'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'theme-manager'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' }
    )
    
    # Functions to export
    FunctionsToExport = @(
        'New-TuiLabel'
        'New-TuiButton'
        'New-TuiTextBox'
        'New-TuiCheckBox'
        'New-TuiRadioButton'
    )
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Classes to export (automatically available)
    # LabelComponent, ButtonComponent, TextBoxComponent, CheckBoxComponent, RadioButtonComponent
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'Components', 'UI', 'Input', 'Button', 'TextBox', 'CheckBox', 'RadioButton')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = @'
v5.0.0:
- Full theme integration with ThemeManager
- Advanced TextBox with viewport scrolling and non-destructive cursors
- Enhanced state management with focus, enabled, and visibility states
- Comprehensive event-driven architecture with scriptblock callbacks
- Extensive parameter validation and error handling
- Performance optimizations with change detection
- True color support for enhanced visual appearance
- Improved accessibility with keyboard navigation
- Factory functions for easy component creation
'@
        }
    }
}
