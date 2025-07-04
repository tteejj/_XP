# Migrate-To-Axiom.ps1
# Master migration script for converting PMC Terminal to AXIOM module architecture
# This script orchestrates the entire migration process

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$OutputPath = (Join-Path $ProjectRoot "axiom-modules"),
    [switch]$DryRun,
    [switch]$SkipBackup,
    [switch]$Force
)

# Import our tools
. (Join-Path $PSScriptRoot "Dependency-Analyzer.ps1")
. (Join-Path $PSScriptRoot "Module-Manifest-Generator.ps1")

class AxiomMigrator {
    [string]$SourceRoot
    [string]$TargetRoot
    [hashtable]$ModuleMap = @{}
    [hashtable]$DependencyGraph = @{}
    [System.Collections.ArrayList]$MigrationOrder = @()
    [bool]$DryRun
    
    AxiomMigrator([string]$source, [string]$target, [bool]$dryRun) {
        $this.SourceRoot = $source
        $this.TargetRoot = $target
        $this.DryRun = $dryRun
        
        if (-not $dryRun -and -not (Test-Path $target)) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }
    }
    
    [void] StartMigration() {
        Write-Host "🚀 Starting AXIOM Migration Process" -ForegroundColor Cyan
        Write-Host "═" * 60
        Write-Host "Source: $($this.SourceRoot)"
        Write-Host "Target: $($this.TargetRoot)"
        Write-Host "Mode: $(if($this.DryRun){'DRY RUN'}else{'LIVE'})"
        Write-Host "═" * 60
        
        # Step 1: Analyze current structure
        Write-Host "`n📊 Step 1: Analyzing Current Structure" -ForegroundColor Yellow
        $this.AnalyzeCurrentStructure()
        
        # Step 2: Build dependency graph
        Write-Host "`n🔗 Step 2: Building Dependency Graph" -ForegroundColor Yellow
        $this.BuildDependencyGraph()
        
        # Step 3: Determine migration order
        Write-Host "`n📋 Step 3: Determining Migration Order" -ForegroundColor Yellow
        $this.DetermineMigrationOrder()
        
        # Step 4: Create backup
        if (-not $script:SkipBackup -and -not $this.DryRun) {
            Write-Host "`n💾 Step 4: Creating Backup" -ForegroundColor Yellow
            $this.CreateBackup()
        }
        
        # Step 5: Migrate modules
        Write-Host "`n🔄 Step 5: Migrating Modules" -ForegroundColor Yellow
        $this.MigrateModules()
        
        # Step 6: Create master module
        Write-Host "`n📦 Step 6: Creating Master Module" -ForegroundColor Yellow
        $this.CreateMasterModule()
        
        # Step 7: Generate compatibility shim
        Write-Host "`n🔧 Step 7: Creating Compatibility Shim" -ForegroundColor Yellow
        $this.CreateCompatibilityShim()
        
        # Step 8: Generate test scripts
        Write-Host "`n🧪 Step 8: Generating Test Scripts" -ForegroundColor Yellow
        $this.GenerateTestScripts()
        
        Write-Host "`n✅ Migration Complete!" -ForegroundColor Green
    }
    
    [void] AnalyzeCurrentStructure() {
        $modules = @{
            # Core primitives (no dependencies)
            'tui-primitives' = @{
                Path = 'components\tui-primitives\tui-primitives.psm1'
                Type = 'Core'
                Priority = 1
            }
            
            # Base classes (depends on primitives)
            'ui-classes' = @{
                Path = 'components\ui-classes\ui-classes.psm1'
                Type = 'Core'
                Priority = 2
            }
            
            # Services and utilities
            'logger' = @{
                Path = 'modules\logger\logger.psm1'
                Type = 'Service'
                Priority = 1
            }
            'event-system' = @{
                Path = 'modules\event-system\event-system.psm1'
                Type = 'Service'
                Priority = 1
            }
            'theme-manager' = @{
                Path = 'modules\theme-manager\theme-manager.psm1'
                Type = 'Service'
                Priority = 2
            }
            'models' = @{
                Path = 'modules\models\models.psm1'
                Type = 'Data'
                Priority = 1
            }
            'service-container' = @{
                Path = 'services\service-container\service-container.psm1'
                Type = 'Service'
                Priority = 1
            }
            'panic-handler' = @{
                Path = 'modules\panic-handler\panic-handler.psm1'
                Type = 'Service'
                Priority = 1
            }
            
            # Layout components
            'panels-class' = @{
                Path = 'layout\panels-class\panels-class.psm1'
                Type = 'Component'
                Priority = 3
            }
            
            # UI Components
            'tui-components' = @{
                Path = 'components\tui-components\tui-components.psm1'
                Type = 'Component'
                Priority = 4
            }
            'navigation-class' = @{
                Path = 'components\navigation-class\navigation-class.psm1'
                Type = 'Component'
                Priority = 4
            }
            'advanced-data-components' = @{
                Path = 'components\advanced-data-components\advanced-data-components.psm1'
                Type = 'Component'
                Priority = 5
            }
            'advanced-input-components' = @{
                Path = 'components\advanced-input-components\advanced-input-components.psm1'
                Type = 'Component'
                Priority = 5
            }
            
            # Services with dependencies
            'data-manager-class' = @{
                Path = 'modules\data-manager-class\data-manager-class.psm1'
                Type = 'Service'
                Priority = 3
            }
            'keybinding-service-class' = @{
                Path = 'services\keybinding-service-class\keybinding-service-class.psm1'
                Type = 'Service'
                Priority = 3
            }
            'navigation-service-class' = @{
                Path = 'services\navigation-service-class\navigation-service-class.psm1'
                Type = 'Service'
                Priority = 4
            }
            'dialog-system-class' = @{
                Path = 'modules\dialog-system-class\dialog-system-class.psm1'
                Type = 'Service'
                Priority = 4
            }
            
            # Screens (highest level)
            'dashboard-screen' = @{
                Path = 'screens\dashboard-screen\dashboard-screen.psm1'
                Type = 'Screen'
                Priority = 6
            }
            'task-list-screen' = @{
                Path = 'screens\task-list-screen\task-list-screen.psm1'
                Type = 'Screen'
                Priority = 6
            }
            
            # Engine (orchestrator)
            'tui-engine' = @{
                Path = 'modules\tui-engine\tui-engine.psm1'
                Type = 'Engine'
                Priority = 7
            }
        }
        
        foreach ($name in $modules.Keys) {
            $module = $modules[$name]
            $fullPath = Join-Path $this.SourceRoot $module.Path
            if (Test-Path $fullPath) {
                $module.FullPath = $fullPath
                $module.Exists = $true
                $this.ModuleMap[$name] = $module
            } else {
                Write-Warning "Module not found: $name at $($module.Path)"
            }
        }
        
        Write-Host "  Found $($this.ModuleMap.Count) modules to migrate"
    }
    
    [void] BuildDependencyGraph() {
        # Run dependency analyzer
        $analyzer = [DependencyAnalyzer]::new($this.SourceRoot)
        $analyzer.AnalyzeProject()
        $report = $analyzer.GenerateReport()
        
        $this.DependencyGraph = $report.ModuleDependencies
        
        # Add manual dependency hints for accuracy
        $manualDependencies = @{
            'ui-classes' = @('tui-primitives')
            'panels-class' = @('ui-classes', 'tui-primitives')
            'tui-components' = @('ui-classes', 'tui-primitives')
            'advanced-data-components' = @('ui-classes', 'tui-components', 'panels-class')
            'advanced-input-components' = @('ui-classes', 'tui-components')
            'dialog-system-class' = @('ui-classes', 'panels-class', 'tui-primitives')
            'data-manager-class' = @('models', 'event-system')
            'navigation-service-class' = @('ui-classes', 'event-system')
            'dashboard-screen' = @('ui-classes', 'panels-class', 'tui-components', 'navigation-class')
            'task-list-screen' = @('ui-classes', 'panels-class', 'advanced-data-components')
            'tui-engine' = @('ui-classes', 'tui-primitives', 'panic-handler', 'event-system')
        }
        
        foreach ($module in $manualDependencies.Keys) {
            if ($this.DependencyGraph.ContainsKey($module)) {
                $existing = $this.DependencyGraph[$module]
                $manual = $manualDependencies[$module]
                $combined = @($existing + $manual | Select-Object -Unique)
                $this.DependencyGraph[$module] = $combined
            } else {
                $this.DependencyGraph[$module] = $manualDependencies[$module]
            }
        }
    }
    
    [void] DetermineMigrationOrder() {
        # Topological sort based on dependencies
        $visited = @{}
        $order = [System.Collections.ArrayList]::new()
        
        foreach ($module in $this.ModuleMap.Keys) {
            if (-not $visited.ContainsKey($module)) {
                $this.TopologicalSort($module, $visited, $order)
            }
        }
        
        $this.MigrationOrder = $order
        
        Write-Host "  Migration order determined:"
        for ($i = 0; $i -lt $this.MigrationOrder.Count; $i++) {
            $module = $this.MigrationOrder[$i]
            $deps = if ($this.DependencyGraph.ContainsKey($module)) { 
                $this.DependencyGraph[$module] -join ', ' 
            } else { 
                'none' 
            }
            Write-Host "    $($i+1). $module (deps: $deps)" -ForegroundColor DarkGray
        }
    }
    
    [void] TopologicalSort($module, $visited, $order) {
        $visited[$module] = $true
        
        if ($this.DependencyGraph.ContainsKey($module)) {
            foreach ($dep in $this.DependencyGraph[$module]) {
                if (-not $visited.ContainsKey($dep) -and $this.ModuleMap.ContainsKey($dep)) {
                    $this.TopologicalSort($dep, $visited, $order)
                }
            }
        }
        
        $order.Insert(0, $module) | Out-Null
    }
    
    [void] MigrateModule($moduleName) {
        $module = $this.ModuleMap[$moduleName]
        Write-Host "  🔄 Migrating: $moduleName" -ForegroundColor Cyan
        
        if ($this.DryRun) {
            Write-Host "    [DRY RUN] Would migrate $($module.Path)" -ForegroundColor Yellow
            return
        }
        
        # Create module directory
        $targetModuleDir = Join-Path $this.TargetRoot $moduleName
        New-Item -ItemType Directory -Path $targetModuleDir -Force | Out-Null
        
        # Copy module file
        $sourceFile = $module.FullPath
        $targetFile = Join-Path $targetModuleDir "$moduleName.psm1"
        Copy-Item -Path $sourceFile -Destination $targetFile -Force
        
        # Remove any existing 'using module' statements
        $content = Get-Content $targetFile -Raw
        $content = $content -replace 'using\s+module\s+.+\r?\n', ''
        Set-Content -Path $targetFile -Value $content
        
        # Generate manifest
        $dependencies = if ($this.DependencyGraph.ContainsKey($moduleName)) {
            $this.DependencyGraph[$moduleName]
        } else {
            @()
        }
        
        # Create manifest using our generator
        & $PSScriptRoot\Module-Manifest-Generator.ps1 `
            -ModulePath $targetFile `
            -RequiredModules $dependencies `
            -Description "PMC Terminal AXIOM Module: $moduleName" `
            -Force
        
        Write-Host "    ✓ Migrated to: $targetModuleDir" -ForegroundColor Green
    }
    
    [void] MigrateModules() {
        foreach ($moduleName in $this.MigrationOrder) {
            $this.MigrateModule($moduleName)
        }
    }
    
    [void] CreateMasterModule() {
        if ($this.DryRun) {
            Write-Host "  [DRY RUN] Would create master module" -ForegroundColor Yellow
            return
        }
        
        $masterPath = Join-Path $this.TargetRoot "PMCTerminal"
        New-Item -ItemType Directory -Path $masterPath -Force | Out-Null
        
        # Create main module file
        $mainModule = @'
# PMCTerminal.psm1
# Master module for PMC Terminal - AXIOM Architecture
# This module serves as the entry point for the application

# The module manifest handles all dependencies
# All required modules are loaded automatically by PowerShell

# Export main entry function
function Start-PMCTerminal {
    [CmdletBinding()]
    param(
        [switch]$Debug,
        [switch]$SkipLogo
    )
    
    try {
        Write-Host "`n=== PMC Terminal AXIOM - Starting Up ===" -ForegroundColor Cyan
        
        # Initialize services through service container
        $container = Get-ServiceContainer
        
        # Get required services
        $navigation = $container.Resolve("NavigationService")
        $engine = $container.Resolve("TuiEngine")
        
        # Create initial screen
        $initialScreen = $navigation.CreateScreen("DashboardScreen")
        
        # Start the application
        $engine.Start($initialScreen)
        
    } catch {
        Write-Host "Fatal error: $_" -ForegroundColor Red
        throw
    }
}

Export-ModuleMember -Function Start-PMCTerminal
'@
        
        Set-Content -Path (Join-Path $masterPath "PMCTerminal.psm1") -Value $mainModule
        
        # Create master manifest
        $masterManifest = @{
            Path = Join-Path $masterPath "PMCTerminal.psd1"
            RootModule = 'PMCTerminal.psm1'
            ModuleVersion = '4.0.0'
            GUID = [guid]::NewGuid().ToString()
            Author = 'PMC Terminal Team'
            CompanyName = 'PMC Terminal'
            Copyright = "(c) $(Get-Date -Format yyyy) PMC Terminal. All rights reserved."
            Description = 'PMC Terminal - PowerShell Management Console with TUI'
            PowerShellVersion = '7.0'
            RequiredModules = @(
                # List all modules in dependency order
                foreach ($module in $this.MigrationOrder) {
                    @{
                        ModuleName = $module
                        ModuleVersion = '1.0.0'
                    }
                }
            )
            FunctionsToExport = @('Start-PMCTerminal')
            CmdletsToExport = @()
            VariablesToExport = @()
            AliasesToExport = @()
        }
        
        New-ModuleManifest @masterManifest
        Write-Host "  ✓ Created master module: $masterPath" -ForegroundColor Green
    }
    
    [void] CreateBackup() {
        $backupPath = Join-Path $this.SourceRoot "_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        
        Write-Host "  Creating backup at: $backupPath"
        
        $itemsToCopy = @(
            'components',
            'layout',
            'modules',
            'screens',
            'services',
            'run.ps1'
        )
        
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        
        foreach ($item in $itemsToCopy) {
            $source = Join-Path $this.SourceRoot $item
            if (Test-Path $source) {
                Copy-Item -Path $source -Destination $backupPath -Recurse -Force
            }
        }
        
        Write-Host "  ✓ Backup created successfully" -ForegroundColor Green
    }
    
    [void] CreateCompatibilityShim() {
        if ($this.DryRun) {
            Write-Host "  [DRY RUN] Would create compatibility shim" -ForegroundColor Yellow
            return
        }
        
        $shimContent = @'
# run-axiom.ps1
# Compatibility shim for running PMC Terminal with AXIOM architecture
# This allows gradual migration while maintaining the old entry point

param(
    [switch]$Debug,
    [switch]$SkipLogo
)

# Add the axiom modules to PSModulePath
$axiomPath = Join-Path $PSScriptRoot "axiom-modules"
if ($env:PSModulePath -notlike "*$axiomPath*") {
    $env:PSModulePath = "$axiomPath;$env:PSModulePath"
}

# Import the master module
Import-Module PMCTerminal -Force

# Start the application
Start-PMCTerminal -Debug:$Debug -SkipLogo:$SkipLogo
'@
        
        $shimPath = Join-Path $this.SourceRoot "run-axiom.ps1"
        Set-Content -Path $shimPath -Value $shimContent
        
        Write-Host "  ✓ Created compatibility shim: run-axiom.ps1" -ForegroundColor Green
    }
    
    [void] GenerateTestScripts() {
        if ($this.DryRun) {
            Write-Host "  [DRY RUN] Would generate test scripts" -ForegroundColor Yellow
            return
        }
        
        $testDir = Join-Path $this.TargetRoot "tests"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        
        # Create module load test
        $loadTest = @'
# Test-ModuleLoading.ps1
# Tests that all AXIOM modules can be loaded successfully

$ErrorActionPreference = 'Stop'

# Add axiom modules to path
$axiomPath = Split-Path -Parent $PSScriptRoot
if ($env:PSModulePath -notlike "*$axiomPath*") {
    $env:PSModulePath = "$axiomPath;$env:PSModulePath"
}

$modules = Get-ChildItem -Path $axiomPath -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "$($_.Name).psd1")
}

Write-Host "Testing $($modules.Count) modules..." -ForegroundColor Cyan

$failed = 0
foreach ($module in $modules) {
    Write-Host "  Testing: $($module.Name)... " -NoNewline
    try {
        Import-Module $module.Name -Force
        Write-Host "✓" -ForegroundColor Green
    } catch {
        Write-Host "✗" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        $failed++
    }
}

if ($failed -eq 0) {
    Write-Host "`nAll modules loaded successfully!" -ForegroundColor Green
} else {
    Write-Host "`n$failed modules failed to load" -ForegroundColor Red
    exit 1
}
'@
        
        Set-Content -Path (Join-Path $testDir "Test-ModuleLoading.ps1") -Value $loadTest
        
        Write-Host "  ✓ Generated test scripts in: $testDir" -ForegroundColor Green
    }
}

# Main execution
if (-not $Force -and -not $DryRun) {
    Write-Warning @"
This will migrate your PMC Terminal to the AXIOM module architecture.
This is a significant change that will:
- Create a new module structure in: $OutputPath
- Generate module manifests for all components
- Create a new entry point for the application

Use -DryRun to see what would happen without making changes.
Use -Force to skip this confirmation.
"@
    
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Migration cancelled" -ForegroundColor Yellow
        exit 0
    }
}

$migrator = [AxiomMigrator]::new($ProjectRoot, $OutputPath, $DryRun)
$migrator.StartMigration()
