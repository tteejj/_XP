@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'data-manager.psm1'
    
    # Version number of this module.
    ModuleVersion = '3.0.0'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Core')
    
    # ID used to uniquely identify this module
    GUID = 'e4f5a6b7-8901-2bcd-3def-45678901bcde'
    
    # Author of this module
    Author = 'PMC Terminal Team'
    
    # Company or vendor of this module
    CompanyName = 'PMC Terminal'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 PMC Terminal. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'PMC Terminal AXIOM Module: High-performance data persistence service with transactional operations, indexing, and lifecycle management'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Modules that must be imported into the global environment prior to importing this module
#    RequiredModules = @(
#        @{
#            ModuleName = 'exceptions'
#            ModuleVersion = '1.0.0'
#        },
#        @{
#            ModuleName = 'event-system'
#            ModuleVersion = '1.0.0'
#        },
#        @{
#            ModuleName = 'models'
#            ModuleVersion = '1.0.0'
#        }
#    )
    
    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()
    
    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    ScriptsToProcess = @()
    
    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Initialize-DataManager'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # DSC resources to export from this module
    DscResourcesToExport = @()
    
    # List of all files packaged with this module
    FileList = @('data-manager.psm1', 'data-manager.psd1', 'README.md')
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for online gallery discoverability
            Tags = @('PMCTerminal', 'DataPersistence', 'PowerShell7', 'Performance', 'Transactions')
            
            # A URL to the main website for this project
            ProjectUri = ''
            
            # A URL to an icon representing this module
            IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Initial AXIOM architecture release - High-performance data persistence with transactional operations'
            
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
