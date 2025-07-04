@{
    # Module manifest for navigation-service
    RootModule = 'navigation-service.psm1'
    ModuleVersion = '1.0.0'
    GUID = '4d6f8a1b-3c5d-7e9f-2a4b-6c8d0e2f4a5b'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    Description = 'Factory functions for creating NavigationService instances'
    PowerShellVersion = '7.0'
    
    # Dependencies
    RequiredModules = @(
        @{ ModuleName = 'navigation-service-class'; ModuleVersion = '1.0.0' }
    )
    
    # Export the factory function
    FunctionsToExport = @('Initialize-NavigationService')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'Navigation', 'Factory', 'Service')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'Factory functions for NavigationService instances'
        }
    }
}
