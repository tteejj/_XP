@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'task-list-screen.psm1'
    
    # Version number of this module.
    ModuleVersion = '3.0.0'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Core')
    
    # ID used to uniquely identify this module
    GUID = 'c3d4e5f6-a7b8-c901-2345-678901defab'
    
    # Author of this module
    Author = 'PMC Terminal Team'
    
    # Company or vendor of this module
    CompanyName = 'PMC Terminal'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'PMC Terminal AXIOM Module: A dynamic, action-driven, and theme-aware screen for managing tasks.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Modules that must be imported into the global environment prior to importing this module.
    # This screen depends on types and services defined in these core modules.
    RequiredModules = @(
        @{ ModuleName = 'ui-classes'; ModuleVersion = '3.0.0' },
        @{ ModuleName = 'panels-class'; ModuleVersion = '5.0.0' },
        @{ ModuleName = 'tui-components'; ModuleVersion = '3.0.0' },
        @{ ModuleName = 'advanced-data-components'; ModuleVersion = '3.0.0' },
        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' },
        @{ ModuleName = 'data-manager'; ModuleVersion = '3.0.0' },
        @{ ModuleName = 'theme-manager'; ModuleVersion = '3.0.0' },
        @{ ModuleName = 'action-service'; ModuleVersion = '3.0.0' },
        @{ ModuleName = 'keybinding-service-class'; ModuleVersion = '3.0.0' },
        @{ ModuleName = 'navigation-service-class'; ModuleVersion = '3.0.0' }
    )
    
    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()
    
    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    ScriptsToProcess = @()
    
    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()
    
    # Functions to export from this module. This module only exports a class.
    FunctionsToExport = @()
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # DSC resources to export from this module
    DscResourcesToExport = @()
    
    # List of all files packaged with this module
    FileList = @('task-list-screen.psm1', 'task-list-screen.psd1', 'README.md')
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for online gallery discoverability
            Tags = @('PMCTerminal', 'Screen', 'Tasks', 'UI', 'EventDriven', 'ActionDriven', 'Theming')
            
            # A URL to the main website for this project
            ProjectUri = ''
            
            # A URL to an icon representing this module
            IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Complete rewrite to align with the Axiom-Phoenix architecture. Replaces hardcoded input with ActionService/KeybindingService, uses ThemeManager for all styling, and is fully event-driven for data updates.'
            
            # Prerelease string of this module
            Prerelease = ''
            
            # Flag to indicate whether the module requires explicit user acceptance
            RequireLicenseAcceptance = $false
            
            # External dependent modules of this module
            ExternalModuleDependencies = @()
        }
    }
    
    # HelpInfo URI of this module
    HelpInfoURI = ''
}