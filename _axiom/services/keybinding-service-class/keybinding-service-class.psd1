@{
    # Module manifest for keybinding-service-class
    RootModule = 'keybinding-service-class.psm1'
    ModuleVersion = '3.0.0'
    GUID = '7a3e4f5d-8b2c-4e6f-9a1b-3c5d7e9f1a2b'
    Author = 'PMC Terminal Team'
    CompanyName = 'PMC Terminal'
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    Description = 'KeybindingService class for managing keyboard shortcuts and hotkeys in TUI applications'
    PowerShellVersion = '7.0'
    
    # Dependencies
#    RequiredModules = @(
#        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' }
#        @{ ModuleName = 'exceptions'; ModuleVersion = '3.0.0' }
#    )
    
    # No functions to export - only classes
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    # PowerShell classes are automatically exported
    
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'KeyBinding', 'Hotkey', 'Console', 'Class')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'KeybindingService class for Axiom-Phoenix TUI framework'
        }
    }
}
