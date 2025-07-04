@{
    # Module manifest for navigation-service-class
    RootModule = 'navigation-service-class.psm1'
    ModuleVersion = '3.0.0'
    GUID = '3c5e7f9a-2d4e-6f8a-1b3c-5d7e9f1a2b4c'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    Description = 'NavigationService and ScreenFactory classes for managing application navigation and screen creation'
    PowerShellVersion = '7.0'
    
    # Dependencies
#    RequiredModules = @(
#        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'exceptions'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'ui-classes'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'event-system'; ModuleVersion = '3.0.0' }
#    )
    
    # No functions to export - only classes
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    # PowerShell classes are automatically exported: NavigationService, ScreenFactory
    
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'Navigation', 'Screen', 'Routing', 'Class')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'NavigationService and ScreenFactory classes for Axiom-Phoenix TUI framework'
        }
    }
}
