@{
    # Module manifest for keybinding-service
    RootModule = 'keybinding-service.psm1'
    ModuleVersion = '1.0.0'
    GUID = '2b4e6f8a-1c3d-5e7f-9a2b-4c6d8e0f2a3b'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    Description = 'Factory functions for creating KeybindingService instances'
    PowerShellVersion = '7.0'
    
    # Dependencies
    RequiredModules = @(
        @{ ModuleName = 'keybinding-service-class'; ModuleVersion = '1.0.0' }
    )
    
    # Export the factory function
    FunctionsToExport = @('New-KeybindingService')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'KeyBinding', 'Factory', 'Service')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'Factory functions for KeybindingService instances'
        }
    }
}
