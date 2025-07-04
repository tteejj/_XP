@{
    # Module manifest for Navigation Class
    RootModule = 'navigation-class.psm1'
    ModuleVersion = '3.0.0'
    GUID = '4d3e5f6a-7b8c-9d0e-1f2a-3b4c5d6e7f8a'
    Author = 'PMC Terminal Development Team'
    CompanyName = 'PMC Terminal'
    Copyright = '© 2024 PMC Terminal. All rights reserved.'
    Description = 'Navigation menu components for contextual and local navigation in TUI applications, featuring theme integration and keyboard navigation.'
    
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
    # NavigationItem, NavigationMenu
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'Navigation', 'Menu', 'Context', 'Keyboard', 'Theme', 'Local')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = @'
v5.0.0:
- Complete theme integration with semantic color keys
- Clarified role as contextual menu component (not global navigation)
- Enhanced rendering with improved selection highlighting
- Comprehensive keyboard navigation support
- Separator support for menu organization
- Robust error handling with comprehensive logging
- State management for enabled/disabled and visible/hidden items
- Performance optimizations with efficient rendering
- Clear documentation of use cases and migration path
'@
        }
    }
}
