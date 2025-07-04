@{
    # Module manifest for TUI Engine
    RootModule = 'tui-engine.psm1'
    ModuleVersion = '3.0'
    GUID = '1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d'
    Author = 'PMC Terminal Development Team'
    CompanyName = 'PMC Terminal'
    Copyright = '© 2024 PMC Terminal. All rights reserved.'
    Description = 'Core TUI engine providing lifecycle management, high-performance rendering, and comprehensive input handling for terminal user interfaces.'
    
    PowerShellVersion = '7.0'
    
    # Dependencies
    RequiredModules = @(
        @{ ModuleName = 'tui-primitives'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'panic-handler'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'logger'; ModuleVersion = '3.0.0' }
        @{ ModuleName = 'event-system'; ModuleVersion = '3.0.0' }
    )
    
    # Functions to export
    FunctionsToExport = @(
        'Initialize-TuiEngine'
        'Start-TuiLoop'
        'Cleanup-TuiEngine'
        'Push-Screen'
        'Pop-Screen'
        'Show-TuiOverlay'
        'Close-TopTuiOverlay'
        'Set-ComponentFocus'
        'Get-FocusedComponent'
        'Request-TuiRefresh'
        'Render-Frame'
        'Process-TuiInput'
        'Check-ForResize'
    )
    
    # Variables to export
    VariablesToExport = @(
        'TuiState'
    )
    
    # Aliases to export
    AliasesToExport = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('TUI', 'Engine', 'Rendering', 'Input', 'Lifecycle', 'Performance', 'Screen', 'Overlay')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = @'
v5.3.0:
- Complete component lifecycle management with Initialize, Cleanup, and Resize hooks
- Enhanced terminal resize detection and propagation
- Improved resource management with automatic cleanup
- High-performance compositor-based rendering with differential updates
- Asynchronous input processing with concurrent queuing
- Comprehensive error handling with panic recovery
- Stack-based screen navigation with proper state management
- Modal overlay support with focus management
- Thread-safe operations with proper synchronization
- Memory optimization with buffer pooling and reuse
'@
        }
    }
}
