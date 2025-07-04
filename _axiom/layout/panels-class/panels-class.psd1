@{
    # Module manifest for Panel Classes
    RootModule = 'panels-class.psm1'
    ModuleVersion = '5.0.0'
    GUID = '7c8b5a9f-3e2d-4f1a-8b7c-5a9f3e2d4f1a'
    Author = 'PMC Terminal Development Team'
    CompanyName = 'PMC Terminal'
    Copyright = '© 2024 PMC Terminal. All rights reserved.'
    Description = 'Panel classes for layout management and container components in TUI applications, featuring automatic layout, scrolling, and collapsible content.'
    
    PowerShellVersion = '7.0'
    
    # Dependencies
#    RequiredModules = @(
#        @{ ModuleName = 'ui-classes'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'tui-primitives'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'theme-manager'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' }
#    )
    
    # Functions to export
    FunctionsToExport = @()
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Classes to export (automatically available)
    # Panel, ScrollablePanel, GroupPanel
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'Panel', 'Layout', 'Container', 'UI', 'Scrollable', 'Collapsible')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = @'
v5.0.0:
- Full Axiom-Phoenix integration with lifecycle management
- Enhanced error handling and parameter validation
- Comprehensive theme integration with ThemeManager
- Improved focus management with hierarchical navigation
- Performance optimizations for layout calculations
- Advanced scrolling capabilities with viewport rendering
- Collapsible panels with state management
- Extensive logging and debugging support
- Consistent ToString() implementations for debugging
'@
        }
    }
}
