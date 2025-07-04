@{
    # Module manifest for Command Palette
    RootModule = 'command-palette.psm1'
    ModuleVersion = '3.0.0'
    GUID = '2b1c4d5e-6f7a-8b9c-0d1e-2f3a4b5c6d7e'
    Author = 'PMC Terminal Development Team'
    CompanyName = 'PMC Terminal'
    Copyright = '© 2024 PMC Terminal. All rights reserved.'
    Description = 'Advanced command palette component providing fuzzy search and quick action execution for TUI applications.'
    
    PowerShellVersion = '7.0'
    
    # Dependencies
    RequiredModules = @(
        @{ ModuleName = 'ui-classes'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'tui-components'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'tui-primitives'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'theme-manager'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'action-service'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'keybinding-service'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'event-system'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' }
    )
    
    # Functions to export
    FunctionsToExport = @(
        'Register-CommandPalette'
    )
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # Classes to export (automatically available)
    # CommandPalette
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'CommandPalette', 'Search', 'Actions', 'Modal', 'Fuzzy', 'Navigation')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = @'
v5.0.0:
- Complete rewrite for Axiom-Phoenix architecture
- Fuzzy search with real-time filtering
- Full keyboard navigation support
- Theme integration with semantic color keys
- ActionService integration for action execution
- Event-driven activation with global hotkey support
- Performance optimizations with viewport rendering
- Comprehensive error handling and logging
- Modal overlay interface with proper focus management
- Responsive design with automatic sizing
'@
        }
    }
}
