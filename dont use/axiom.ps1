# PMC-Terminal-Axiom-Loader.ps1
# Master loader for PMC Terminal v5 (Axiom) with comprehensive debugging

[CmdletBinding()]
param(
    [switch]$DebugLoading,
    [switch]$VerboseErrors,
    [switch]$CleanSession
)

# Global tracking for module load debugging
$Global:PMC_LoadTrace = @()
$Global:PMC_LoadErrors = @()

function Write-LoadTrace {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $traceEntry = "$timestamp [$Type] $Message"
    $Global:PMC_LoadTrace += $traceEntry
    
    if ($DebugLoading) {
        $color = switch ($Type) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            "SUCCESS" { "Green" }
            default { "Cyan" }
        }
        Write-Host $traceEntry -ForegroundColor $color
    }
}

function Test-ModuleManifest {
    param([string]$ManifestPath)
    
    try {
        $manifest = Import-PowerShellDataFile -Path $ManifestPath -ErrorAction Stop
        Write-LoadTrace "Manifest validated: $ManifestPath" "SUCCESS"
        return $manifest
    }
    catch {
        Write-LoadTrace "Manifest validation failed: $ManifestPath - $($_.Exception.Message)" "ERROR"
        $Global:PMC_LoadErrors += @{
            Type = "ManifestValidation"
            Path = $ManifestPath
            Error = $_.Exception.Message
            FullError = $_
        }
        return $null
    }
}

function Get-ModuleDependencyTree {
    param([string]$ManifestPath)
    
    $manifest = Test-ModuleManifest -ManifestPath $ManifestPath
    if (-not $manifest) { return @() }
    
    $dependencies = @()
    if ($manifest.RequiredModules) {
        foreach ($dep in $manifest.RequiredModules) {
            $depName = if ($dep -is [string]) { $dep } else { $dep.ModuleName }
            $dependencies += $depName
            Write-LoadTrace "Found dependency: $depName for $ManifestPath"
        }
    }
    
    return $dependencies
}

function Clear-ModuleCache {
    Write-LoadTrace "Clearing PowerShell module cache" "INFO"
    
    # Remove any PMC-related modules from current session
    Get-Module | Where-Object { $_.Name -like "*PMC*" -or $_.Name -like "*Tui*" } | Remove-Module -Force
    
    # Clear the module cache
    $cacheDir = "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\ModuleAnalysisCache"
    if (Test-Path $cacheDir) {
        try {
            Remove-Item "$cacheDir\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-LoadTrace "Module analysis cache cleared" "SUCCESS"
        }
        catch {
            Write-LoadTrace "Warning: Could not clear module cache - $($_.Exception.Message)" "WARN"
        }
    }
}

function Test-PMCEnvironment {
    Write-LoadTrace "Testing PMC Terminal environment" "INFO"
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-LoadTrace "ERROR: PowerShell 7+ required. Current version: $($PSVersionTable.PSVersion)" "ERROR"
        return $false
    }
    
    # Check if we're in the right directory
    $expectedFiles = @("PMCTerminal.psd1", "_CLASSY-MAIN.ps1")
    foreach ($file in $expectedFiles) {
        if (-not (Test-Path $file)) {
            Write-LoadTrace "ERROR: Missing expected file: $file" "ERROR"
            return $false
        }
    }
    
    Write-LoadTrace "Environment validation passed" "SUCCESS"
    return $true
}

function Import-PMCModuleWithDebugging {
    param([string]$ModulePath)
    
    try {
        Write-LoadTrace "Attempting to import: $ModulePath" "INFO"
        
        # Pre-flight check
        if (-not (Test-Path $ModulePath)) {
            throw "Module path does not exist: $ModulePath"
        }
        
        # Import with explicit error handling
        $module = Import-Module $ModulePath -PassThru -Force -ErrorAction Stop
        
        Write-LoadTrace "Successfully imported: $($module.Name) from $ModulePath" "SUCCESS"
        return $module
    }
    catch {
        $errorDetails = @{
            Type = "ModuleImport"
            Path = $ModulePath
            Error = $_.Exception.Message
            FullError = $_
            InnerException = $_.Exception.InnerException?.Message
            ScriptStackTrace = $_.ScriptStackTrace
        }
        
        $Global:PMC_LoadErrors += $errorDetails
        
        Write-LoadTrace "FAILED to import: $ModulePath" "ERROR"
        Write-LoadTrace "Error: $($_.Exception.Message)" "ERROR"
        
        if ($VerboseErrors) {
            Write-LoadTrace "Stack trace: $($_.ScriptStackTrace)" "ERROR"
            if ($_.Exception.InnerException) {
                Write-LoadTrace "Inner exception: $($_.Exception.InnerException.Message)" "ERROR"
            }
        }
        
        throw
    }
}

function Show-LoadReport {
    Write-Host "`n=== PMC Terminal Load Report ===" -ForegroundColor Magenta
    Write-Host "Total trace entries: $($Global:PMC_LoadTrace.Count)" -ForegroundColor Cyan
    Write-Host "Total errors: $($Global:PMC_LoadErrors.Count)" -ForegroundColor $(if ($Global:PMC_LoadErrors.Count -eq 0) { "Green" } else { "Red" })
    
    if ($Global:PMC_LoadErrors.Count -gt 0) {
        Write-Host "`nERRORS ENCOUNTERED:" -ForegroundColor Red
        foreach ($error in $Global:PMC_LoadErrors) {
            Write-Host "  Type: $($error.Type)" -ForegroundColor Yellow
            Write-Host "  Path: $($error.Path)" -ForegroundColor Yellow
            Write-Host "  Error: $($error.Error)" -ForegroundColor Red
            if ($VerboseErrors -and $error.InnerException) {
                Write-Host "  Inner: $($error.InnerException)" -ForegroundColor Red
            }
            Write-Host ""
        }
    }
    
    if ($DebugLoading) {
        Write-Host "`nFULL TRACE LOG:" -ForegroundColor Magenta
        $Global:PMC_LoadTrace | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
}

function Start-PMCTerminal {
    try {
        Write-LoadTrace "Starting PMC Terminal application" "INFO"
        
        # Look for the main entry point
        if (Test-Path "_CLASSY-MAIN.ps1") {
            Write-LoadTrace "Executing _CLASSY-MAIN.ps1" "INFO"
            & ".\_CLASSY-MAIN.ps1"
        }
        elseif (Get-Command "Start-PMCTerminal" -ErrorAction SilentlyContinue) {
            Write-LoadTrace "Calling Start-PMCTerminal command" "INFO"
            Start-PMCTerminal
        }
        else {
            throw "No valid entry point found. Expected _CLASSY-MAIN.ps1 or Start-PMCTerminal command."
        }
    }
    catch {
        Write-LoadTrace "Failed to start PMC Terminal: $($_.Exception.Message)" "ERROR"
        $Global:PMC_LoadErrors += @{
            Type = "ApplicationStart"
            Error = $_.Exception.Message
            FullError = $_
        }
        throw
    }
}

# === MAIN EXECUTION ===

try {
    Write-Host "PMC Terminal v5 (Axiom) Loader" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    
    # Clear session if requested
    if ($CleanSession) {
        Clear-ModuleCache
    }
    
    # Environment validation
    if (-not (Test-PMCEnvironment)) {
        throw "Environment validation failed. Check the trace above for details."
    }
    
    # Validate main manifest exists
    $mainManifest = "PMCTerminal.psd1"
    if (-not (Test-Path $mainManifest)) {
        throw "Main manifest not found: $mainManifest"
    }
    
    # Read main manifest to get dependencies
    Write-LoadTrace "Reading main manifest: $mainManifest" "INFO"
    $manifestData = Import-PowerShellDataFile -Path $mainManifest -ErrorAction Stop
    
    # Manually load each required module first
    if ($manifestData.RequiredModules) {
        Write-LoadTrace "Loading required modules manually..." "INFO"
        foreach ($reqModule in $manifestData.RequiredModules) {
            $modulePath = if ($reqModule -is [hashtable]) {
                $reqModule.ModuleName
            } else {
                $reqModule
            }
            
            Write-LoadTrace "Loading dependency: $modulePath" "INFO"
            try {
                # Import the dependency
                Import-Module $modulePath -Force -ErrorAction Stop
                Write-LoadTrace "Successfully loaded: $modulePath" "SUCCESS"
            }
            catch {
                Write-LoadTrace "Failed to load dependency: $modulePath - $($_.Exception.Message)" "ERROR"
                throw
            }
        }
    }
    
    # Now we need to temporarily remove RequiredModules from the manifest
    # Create a temporary manifest without RequiredModules
    $tempManifest = "PMCTerminal-temp.psd1"
    $manifestContent = Get-Content $mainManifest -Raw
    $manifestContent = $manifestContent -replace "RequiredModules\s*=\s*@\([^)]+\)", "RequiredModules = @()"
    $manifestContent | Out-File $tempManifest -Encoding UTF8
    
    # Import the main module using the temp manifest
    Write-LoadTrace "Importing main PMC Terminal module" "INFO"
    $pmcModule = Import-PMCModuleWithDebugging -ModulePath ".\$tempManifest"
    
    # Clean up temp manifest
    Remove-Item $tempManifest -Force -ErrorAction SilentlyContinue
    
    Write-LoadTrace "PMC Terminal module loaded successfully" "SUCCESS"
    Write-LoadTrace "Loaded module: $($pmcModule.Name), Version: $($pmcModule.Version)" "SUCCESS"
    
    # Show what got loaded
    $loadedModules = Get-Module | Where-Object { $_.Name -like "*PMC*" -or $_.Name -like "*Tui*" }
    Write-LoadTrace "Total PMC/TUI modules loaded: $($loadedModules.Count)" "SUCCESS"
    
    if ($DebugLoading) {
        foreach ($mod in $loadedModules) {
            Write-LoadTrace "  Loaded: $($mod.Name) v$($mod.Version) from $($mod.ModuleBase)" "SUCCESS"
        }
    }
    
    # Start the application
    Start-PMCTerminal
}
catch {
    Write-LoadTrace "CRITICAL ERROR: $($_.Exception.Message)" "ERROR"
    
    if ($VerboseErrors) {
        Write-LoadTrace "Full exception details:" "ERROR"
        Write-LoadTrace $_.Exception.ToString() "ERROR"
    }
}
finally {
    # Always show the load report
    Show-LoadReport
    
    # Export trace for debugging
    if ($Global:PMC_LoadTrace) {
        $traceFile = "PMC_Load_Trace_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $Global:PMC_LoadTrace | Out-File -FilePath $traceFile -Encoding UTF8
        Write-Host "Load trace saved to: $traceFile" -ForegroundColor Green
    }
    
    # Clean up any temp files
    if (Test-Path "PMCTerminal-temp.psd1") {
        Remove-Item "PMCTerminal-temp.psd1" -Force -ErrorAction SilentlyContinue
    }
}