# Dependency-Analyzer.ps1
# Analyzes PMC Terminal codebase to map dependencies between modules
# This tool is critical for the AXIOM modularization effort

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$OutputJson,
    [switch]$ShowCircular,
    [switch]$Verbose
)

class DependencyAnalyzer {
    [string]$ProjectRoot
    [hashtable]$ClassDefinitions = @{}
    [hashtable]$FunctionDefinitions = @{}
    [hashtable]$ModuleDependencies = @{}
    [hashtable]$ClassInheritance = @{}
    [System.Collections.ArrayList]$CircularDependencies = @()
    
    DependencyAnalyzer([string]$root) {
        $this.ProjectRoot = $root
    }
    
    [void] AnalyzeProject() {
        Write-Host "🔍 Analyzing project at: $($this.ProjectRoot)" -ForegroundColor Cyan
        
        # Phase 1: Discover all definitions
        Write-Host "📋 Phase 1: Discovering definitions..." -ForegroundColor Yellow
        $this.DiscoverDefinitions()
        
        # Phase 2: Analyze dependencies
        Write-Host "🔗 Phase 2: Analyzing dependencies..." -ForegroundColor Yellow
        $this.AnalyzeDependencies()
        
        # Phase 3: Detect circular dependencies
        Write-Host "🔄 Phase 3: Checking for circular dependencies..." -ForegroundColor Yellow
        $this.DetectCircularDependencies()
        
        Write-Host "✅ Analysis complete!" -ForegroundColor Green
    }
    
    [void] DiscoverDefinitions() {
        $files = Get-ChildItem -Path $this.ProjectRoot -Filter "*.psm1" -Recurse
        
        foreach ($file in $files) {
            $moduleName = $this.GetModuleName($file)
            $content = Get-Content $file.FullName -Raw
            
            # Find class definitions
            $classMatches = [regex]::Matches($content, 'class\s+(\w+)(?:\s*:\s*(\w+))?\s*{')
            foreach ($match in $classMatches) {
                $className = $match.Groups[1].Value
                $baseClass = $match.Groups[2].Value
                
                $this.ClassDefinitions[$className] = @{
                    Module = $moduleName
                    File = $file.FullName
                    BaseClass = $baseClass
                }
                
                if ($baseClass) {
                    if (-not $this.ClassInheritance.ContainsKey($baseClass)) {
                        $this.ClassInheritance[$baseClass] = @()
                    }
                    $this.ClassInheritance[$baseClass] += $className
                }
                
                if ($script:Verbose) {
                    Write-Host "  Found class: $className$(if($baseClass){" : $baseClass"}) in $moduleName"
                }
            }
            
            # Find function definitions
            $functionMatches = [regex]::Matches($content, 'function\s+([\w-]+)\s*[({]')
            foreach ($match in $functionMatches) {
                $functionName = $match.Groups[1].Value
                $this.FunctionDefinitions[$functionName] = @{
                    Module = $moduleName
                    File = $file.FullName
                }
            }
        }
        
        Write-Host "  Found $($this.ClassDefinitions.Count) classes and $($this.FunctionDefinitions.Count) functions" -ForegroundColor Gray
    }
    
    [void] AnalyzeDependencies() {
        $files = Get-ChildItem -Path $this.ProjectRoot -Filter "*.psm1" -Recurse
        
        foreach ($file in $files) {
            $moduleName = $this.GetModuleName($file)
            $content = Get-Content $file.FullName -Raw
            $dependencies = @{}
            
            # Check for class usage (instantiation and type references)
            foreach ($className in $this.ClassDefinitions.Keys) {
                $patterns = @(
                    "\[$className\]",                    # Type reference
                    "New-Object\s+$className",           # New-Object
                    "\[$className\]::",                  # Static method call
                    "\[$className\]::new\(",             # Constructor
                    ":\s*$className\s*{",                # Inheritance
                    "\[$className\]\s*\$",               # Type declaration
                    "is\s+\[$className\]"                # Type check
                )
                
                foreach ($pattern in $patterns) {
                    if ($content -match $pattern) {
                        $definedIn = $this.ClassDefinitions[$className].Module
                        if ($definedIn -ne $moduleName) {
                            $dependencies[$definedIn] = $true
                        }
                        break
                    }
                }
            }
            
            # Check for function calls
            foreach ($functionName in $this.FunctionDefinitions.Keys) {
                if ($content -match "\b$functionName\b") {
                    $definedIn = $this.FunctionDefinitions[$functionName].Module
                    if ($definedIn -ne $moduleName) {
                        $dependencies[$definedIn] = $true
                    }
                }
            }
            
            # Check for explicit module references
            $moduleReferences = [regex]::Matches($content, 'using\s+module\s+(.+)')
            foreach ($match in $moduleReferences) {
                $referencedModule = $match.Groups[1].Value.Trim('"', "'")
                $dependencies[$referencedModule] = $true
            }
            
            $this.ModuleDependencies[$moduleName] = @($dependencies.Keys | Sort-Object)
            
            if ($dependencies.Count -gt 0 -and $script:Verbose) {
                Write-Host "  $moduleName depends on: $($dependencies.Keys -join ', ')"
            }
        }
    }
    
    [void] DetectCircularDependencies() {
        foreach ($module in $this.ModuleDependencies.Keys) {
            $visited = @{}
            $path = @()
            $this.CheckCircularDependency($module, $visited, $path)
        }
        
        if ($this.CircularDependencies.Count -gt 0) {
            Write-Host "  ⚠️  Found $($this.CircularDependencies.Count) circular dependencies!" -ForegroundColor Red
        } else {
            Write-Host "  ✓ No circular dependencies found" -ForegroundColor Green
        }
    }
    
    [bool] CheckCircularDependency($module, $visited, $path) {
        if ($visited.ContainsKey($module)) {
            if ($path -contains $module) {
                $circularPath = $path[($path.IndexOf($module))..($path.Count-1)] + $module
                $this.CircularDependencies.Add($circularPath -join " -> ") | Out-Null
                return $true
            }
            return $false
        }
        
        $visited[$module] = $true
        $path += $module
        
        if ($this.ModuleDependencies.ContainsKey($module)) {
            foreach ($dep in $this.ModuleDependencies[$module]) {
                if ($this.CheckCircularDependency($dep, $visited, $path)) {
                    return $true
                }
            }
        }
        
        $path = $path[0..($path.Count-2)]
        return $false
    }
    
    [string] GetModuleName($file) {
        $relativePath = $file.FullName.Replace($this.ProjectRoot, "").TrimStart("\")
        $parts = $relativePath -split '\\'
        
        # Handle different module locations
        if ($parts[0] -in @('components', 'modules', 'services', 'screens', 'layout')) {
            return $parts[1]
        }
        
        return [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    }
    
    [hashtable] GenerateReport() {
        $report = @{
            Summary = @{
                TotalModules = $this.ModuleDependencies.Count
                TotalClasses = $this.ClassDefinitions.Count
                TotalFunctions = $this.FunctionDefinitions.Count
                CircularDependencies = $this.CircularDependencies.Count
            }
            ClassDefinitions = $this.ClassDefinitions
            FunctionDefinitions = $this.FunctionDefinitions
            ModuleDependencies = $this.ModuleDependencies
            ClassInheritance = $this.ClassInheritance
            CircularDependencies = $this.CircularDependencies
        }
        
        return $report
    }
    
    [void] GenerateDependencyGraph() {
        Write-Host "`n📊 Module Dependency Graph:" -ForegroundColor Cyan
        Write-Host "═" * 60
        
        # Sort modules by dependency count
        $sortedModules = $this.ModuleDependencies.GetEnumerator() | 
            Sort-Object { $_.Value.Count }
        
        foreach ($module in $sortedModules) {
            $depCount = $module.Value.Count
            $marker = if ($depCount -eq 0) { "🟢" } 
                     elseif ($depCount -le 2) { "🟡" } 
                     else { "🔴" }
            
            Write-Host "$marker $($module.Key) " -NoNewline
            if ($depCount -gt 0) {
                Write-Host "→ $($module.Value -join ', ')" -ForegroundColor DarkGray
            } else {
                Write-Host "(no dependencies)" -ForegroundColor Green
            }
        }
        
        if ($this.CircularDependencies.Count -gt 0 -and $script:ShowCircular) {
            Write-Host "`n⚠️  Circular Dependencies:" -ForegroundColor Red
            foreach ($circular in $this.CircularDependencies) {
                Write-Host "  $circular" -ForegroundColor Yellow
            }
        }
    }
}

# Main execution
$script:Verbose = $Verbose
$analyzer = [DependencyAnalyzer]::new($ProjectRoot)
$analyzer.AnalyzeProject()

if ($OutputJson) {
    $report = $analyzer.GenerateReport()
    $jsonPath = Join-Path $PSScriptRoot "dependency-analysis.json"
    $report | ConvertTo-Json -Depth 10 | Set-Content $jsonPath
    Write-Host "`n📄 JSON report saved to: $jsonPath" -ForegroundColor Green
} else {
    $analyzer.GenerateDependencyGraph()
}

# Always show summary
$report = $analyzer.GenerateReport()
Write-Host "`n📈 Summary:" -ForegroundColor Cyan
Write-Host "  Total Modules: $($report.Summary.TotalModules)"
Write-Host "  Total Classes: $($report.Summary.TotalClasses)"
Write-Host "  Total Functions: $($report.Summary.TotalFunctions)"
Write-Host "  Circular Dependencies: $($report.Summary.CircularDependencies)"
