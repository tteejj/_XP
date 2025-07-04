@{
    # Module manifest for dashboard-screen
    RootModule = 'dashboard-screen.psm1'
    ModuleVersion = '3.0.0'
    GUID = '5e7f9a2b-4c6d-8e0f-3a5b-7c9d1e3f5a6b'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    Description = 'DashboardScreen class for the main dashboard view in Axiom-Phoenix'
    PowerShellVersion = '7.0'
    
    # Dependencies
    RequiredModules = @(
        @{ ModuleName = 'ui-classes'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'panels-class'; ModuleVersion = '5.0.0' }
        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'theme-manager'; ModuleVersion = '3.0.0' }
    )
    
    # No functions to export - only classes
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    # PowerShell classes are automatically exported: DashboardScreen
    
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'Dashboard', 'Screen', 'UI', 'Class')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'DashboardScreen class for Axiom-Phoenix TUI framework'
        }
    }
}
