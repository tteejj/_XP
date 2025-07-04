# Module-Manifest-Generator.ps1
# Generates PowerShell module manifests (.psd1) for PMC Terminal modules
# Part of the AXIOM modularization effort

param(
    [Parameter(Mandatory)]
    [string]$ModulePath,
    
    [string[]]$RequiredModules = @(),
    
    [string]$Author = "PMC Terminal Team",
    
    [string]$CompanyName = "PMC Terminal",
    
    [string]$Description,
    
    [switch]$Force,
    
    [switch]$AnalyzeDependencies
)

class ManifestGenerator {
    [string]$ModulePath
    [string]$ModuleName
    [hashtable]$ManifestData
    [string[]]$ClassExports = @()
    [string[]]$FunctionExports = @()
    [string[]]$AliasExports = @()
    [string[]]$DetectedDependencies = @()
    
    ManifestGenerator([string]$path) {
        if (-not (Test-Path $path)) {
            throw "Module path does not exist: $path"
        }
        
        $this.ModulePath = $path
        $this.ModuleName = [System.IO.Path]::GetFileNameWithoutExtension($path)
        
        # Initialize default manifest data
        $this.ManifestData = @{
            Path = $this.GetManifestPath()
            RootModule = [System.IO.Path]::GetFileName($path)
            ModuleVersion = '1.0.0'
            GUID = [guid]::NewGuid().ToString()
            Author = 'PMC Terminal Team'
            CompanyName = 'PMC Terminal'
            Copyright = "(c) $(Get-Date -Format yyyy) PMC Terminal. All rights reserved."
            Description = "PMC Terminal Module: $($this.ModuleName)"
            PowerShellVersion = '7.0'
            RequiredModules = @()
            FunctionsToExport = @()
            CmdletsToExport = @()
            VariablesToExport = @()
            AliasesToExport = @()
            PrivateData = @{
                PSData = @{
                    Tags = @('PMCTerminal', 'TUI', 'PowerShell7')
                }
            }
        }
    }
    
    [string] GetManifestPath() {
        $dir = Split-Path $this.ModulePath -Parent
        $manifestName = "$($this.ModuleName).psd1"
        return Join-Path $dir $manifestName
    }
    
    [void] AnalyzeModule() {
        Write-Host "🔍 Analyzing module: $($this.ModuleName)" -ForegroundColor Cyan
        
        $content = Get-Content $this.ModulePath -Raw
        
        # Extract exported classes (PowerShell automatically exports all classes)
        $classMatches = [regex]::Matches($content, 'class\s+(\w+)(?:\s*:\s*(\w+))?\s*{')
        foreach ($match in $classMatches) {
            $this.ClassExports += $match.Groups[1].Value
        }
        
        # Extract exported functions
        $functionMatches = [regex]::Matches($content, 'function\s+([\w-]+)\s*[({]')
        foreach ($match in $functionMatches) {
            $funcName = $match.Groups[1].Value
            # Check if it's likely a public function (common patterns)
            if ($funcName -notmatch '^_' -and 
                ($funcName -match '^(Get|Set|New|Remove|Add|Clear|Initialize|Start|Stop|Test|Write|Read|Show|Hide|Export|Import|ConvertTo|ConvertFrom)-' -or
                 $content -match "Export-ModuleMember.*$funcName")) {
                $this.FunctionExports += $funcName
            }
        }
        
        # Extract aliases
        $aliasMatches = [regex]::Matches($content, 'Set-Alias\s+-Name\s+(\w+)')
        foreach ($match in $aliasMatches) {
            $this.AliasExports += $match.Groups[1].Value
        }
        
        # Analyze dependencies if requested
        if ($script:AnalyzeDependencies) {
            $this.AnalyzeDependencies($content)
        }
        
        Write-Host "  Found: $($this.ClassExports.Count) classes, $($this.FunctionExports.Count) functions, $($this.AliasExports.Count) aliases"
    }
    
    [void] AnalyzeDependencies([string]$content) {
        $dependencies = @{}
        
        # Known module mappings
        $classToModule = @{
            'TuiCell' = 'tui-primitives'
            'TuiBuffer' = 'tui-primitives'
            'UIElement' = 'ui-classes'
            'Component' = 'ui-classes'
            'Panel' = 'panels-class'
            'Screen' = 'ui-classes'
            'DataManager' = 'data-manager-class'
            'NavigationService' = 'navigation-service-class'
            'KeybindingService' = 'keybinding-service-class'
            'ServiceContainer' = 'service-container'
            'PmcTask' = 'models'
            'PmcProject' = 'models'
        }
        
        # Check for class usage
        foreach ($class in $classToModule.Keys) {
            if ($content -match "\[$class\]|\b$class\b::|New-Object\s+$class|\[$class\]::new") {
                $module = $classToModule[$class]
                if ($module -ne $this.ModuleName) {
                    $dependencies[$module] = $true
                }
            }
        }
        
        # Check for function calls from known modules
        $functionToModule = @{
            'Initialize-Logger' = 'logger'
            'Write-TuiLog' = 'logger'
            'Initialize-EventSystem' = 'event-system'
            'Publish-Event' = 'event-system'
            'Subscribe-Event' = 'event-system'
            'Initialize-ThemeManager' = 'theme-manager'
            'Get-ThemeColor' = 'theme-manager'
            'Show-AlertDialog' = 'dialog-system-class'
            'Show-ConfirmDialog' = 'dialog-system-class'
        }
        
        foreach ($func in $functionToModule.Keys) {
            if ($content -match "\b$func\b") {
                $module = $functionToModule[$func]
                if ($module -ne $this.ModuleName) {
                    $dependencies[$module] = $true
                }
            }
        }
        
        $this.DetectedDependencies = @($dependencies.Keys | Sort-Object)
        
        if ($this.DetectedDependencies.Count -gt 0) {
            Write-Host "  Detected dependencies: $($this.DetectedDependencies -join ', ')" -ForegroundColor Yellow
        }
    }
    
    [void] SetManifestData([string]$key, $value) {
        $this.ManifestData[$key] = $value
    }
    
    [void] GenerateManifest() {
        # Update manifest with analyzed data
        $this.ManifestData.FunctionsToExport = $this.FunctionExports
        $this.ManifestData.AliasesToExport = $this.AliasExports
        
        # Add module description if provided
        if ($script:Description) {
            $this.ManifestData.Description = $script:Description
        }
        
        # Add author and company if provided
        if ($script:Author) {
            $this.ManifestData.Author = $script:Author
        }
        if ($script:CompanyName) {
            $this.ManifestData.CompanyName = $script:CompanyName
        }
        
        # Handle required modules
        $requiredModules = @()
        
        # Add explicitly provided modules
        foreach ($module in $script:RequiredModules) {
            $requiredModules += @{
                ModuleName = $module
                ModuleVersion = '1.0.0'
            }
        }
        
        # Add detected dependencies if analyzing
        if ($script:AnalyzeDependencies) {
            foreach ($dep in $this.DetectedDependencies) {
                if ($dep -notin $script:RequiredModules) {
                    $requiredModules += @{
                        ModuleName = $dep
                        ModuleVersion = '1.0.0'
                    }
                }
            }
        }
        
        if ($requiredModules.Count -gt 0) {
            $this.ManifestData.RequiredModules = $requiredModules
        }
        
        # Check if manifest already exists
        $manifestPath = $this.GetManifestPath()
        if ((Test-Path $manifestPath) -and -not $script:Force) {
            Write-Host "⚠️  Manifest already exists: $manifestPath" -ForegroundColor Yellow
            Write-Host "   Use -Force to overwrite" -ForegroundColor Yellow
            return
        }
        
        # Generate the manifest
        try {
            New-ModuleManifest @ManifestData
            Write-Host "✅ Generated manifest: $manifestPath" -ForegroundColor Green
            
            # Show summary
            Write-Host "`n📋 Manifest Summary:" -ForegroundColor Cyan
            Write-Host "   Module: $($this.ModuleName)"
            Write-Host "   Version: $($this.ManifestData.ModuleVersion)"
            Write-Host "   Functions: $($this.FunctionExports.Count) exported"
            Write-Host "   Classes: $($this.ClassExports.Count) defined (auto-exported)"
            if ($requiredModules.Count -gt 0) {
                Write-Host "   Dependencies: $($requiredModules.Count) modules"
                foreach ($req in $requiredModules) {
                    Write-Host "     - $($req.ModuleName)" -ForegroundColor DarkGray
                }
            }
        }
        catch {
            Write-Host "❌ Failed to generate manifest: $_" -ForegroundColor Red
            throw
        }
    }
    
    [void] GenerateModuleStructure() {
        # Create proper module directory structure if needed
        $moduleDir = Split-Path $this.ModulePath -Parent
        $moduleName = $this.ModuleName
        
        # Check if we need to restructure
        if ([System.IO.Path]::GetFileName($moduleDir) -ne $moduleName) {
            Write-Host "⚠️  Module directory name doesn't match module name" -ForegroundColor Yellow
            Write-Host "   Expected: $moduleName" -ForegroundColor Yellow
            Write-Host "   Actual: $([System.IO.Path]::GetFileName($moduleDir))" -ForegroundColor Yellow
            
            # Suggest proper structure
            $properPath = Join-Path (Split-Path $moduleDir -Parent) $moduleName
            Write-Host "`n📁 Suggested module structure:" -ForegroundColor Cyan
            Write-Host "   $properPath\"
            Write-Host "     ├── $moduleName.psd1 (manifest)"
            Write-Host "     └── $moduleName.psm1 (module)"
        }
    }
}

# Main execution
$script:AnalyzeDependencies = $AnalyzeDependencies
$script:Force = $Force
$script:Description = $Description
$script:Author = $Author
$script:CompanyName = $CompanyName
$script:RequiredModules = $RequiredModules

try {
    $generator = [ManifestGenerator]::new($ModulePath)
    $generator.AnalyzeModule()
    $generator.GenerateManifest()
    $generator.GenerateModuleStructure()
}
catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
