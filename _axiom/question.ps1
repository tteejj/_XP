# mushroom.ps1 - The Monolith Decomposer & Recomposer Toolkit (v7.0 - Type-Safe Reconstruction)

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = 'recompose',
    
    [Parameter(Position = 1)]
    [string]$Path,
    
    [Parameter(Position = 2)]
    [string]$Output = "AxiomPhoenix.ps1",
    
    [Parameter()]
    [switch]$DebugTypes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#==============================================================================
# FUNCTION DEFINITIONS
#==============================================================================

function Write-Status {
    param($Message, $Color = 'Cyan')
    Write-Host "🍄 $Message" -ForegroundColor $Color
}

function Get-ClassDefinitions {
    param([string]$Content)
    
    # Extract all class definitions
    $classPattern = '(?sm)^\s*class\s+(?<name>\w+)(?:\s*:\s*(?<base>\w+))?\s*\{(?<body>(?:[^{}]|(?<open>\{)|(?<-open>\}))+(?(open)(?!)))\}'
    $classes = @{}
    
    $matches = [regex]::Matches($Content, $classPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    foreach ($match in $matches) {
        $className = $match.Groups['name'].Value
        $baseClass = if ($match.Groups['base'].Success) { $match.Groups['base'].Value } else { $null }
        $classes[$className] = @{
            Name = $className
            Base = $baseClass
            Definition = $match.Value
            StartIndex = $match.Index
            Length = $match.Length
        }
    }
    
    return $classes
}

function Get-TypeReferences {
    param([string]$Content)
    
    # Find all type references in the content
    $typePattern = '\[(?<type>\w+)\]'
    $references = @{}
    
    $matches = [regex]::Matches($Content, $typePattern)
    foreach ($match in $matches) {
        $typeName = $match.Groups['type'].Value
        # Skip built-in types
        if ($typeName -notmatch '^(string|int|bool|void|object|array|hashtable|psobject|scriptblock|datetime|timespan|System\.)') {
            if (-not $references.ContainsKey($typeName)) {
                $references[$typeName] = @()
            }
            $references[$typeName] += $match.Index
        }
    }
    
    return $references
}

function Remove-StrictTypeHints {
    param([string]$Content, [hashtable]$CustomTypes)
    
    Write-Status "  -> Removing strict type hints for custom types..." 'DarkGray'
    
    # Pattern for parameter type hints
    $paramTypePattern = '\[\s*(?<type>\w+)\s*\]\s*\$(?<param>\w+)'
    
    $result = [regex]::Replace($Content, $paramTypePattern, {
        param($match)
        $typeName = $match.Groups['type'].Value
        $paramName = $match.Groups['param'].Value
        
        if ($CustomTypes.ContainsKey($typeName)) {
            # Replace with [object] for custom types
            Write-Verbose "    Replaced [$typeName]`$$paramName with [object]`$$paramName"
            return "[object]`$$paramName"
        }
        return $match.Value
    })
    
    # Pattern for return type hints
    $returnTypePattern = '\[\s*(?<type>\w+)\s*\]\s*(?=\w+\s*\()'
    
    $result = [regex]::Replace($result, $returnTypePattern, {
        param($match)
        $typeName = $match.Groups['type'].Value
        
        if ($CustomTypes.ContainsKey($typeName)) {
            # Replace with [object] for custom types
            Write-Verbose "    Replaced return type [$typeName] with [object]"
            return "[object] "
        }
        return $match.Value
    })
    
    return $result
}

function Get-DependencyOrder {
    param([hashtable]$Classes)
    
    # Build dependency graph
    $dependencies = @{}
    foreach ($className in $Classes.Keys) {
        $class = $Classes[$className]
        $dependencies[$className] = @()
        
        if ($class.Base) {
            $dependencies[$className] += $class.Base
        }
    }
    
    # Topological sort
    $sorted = @()
    $visited = @{}
    
    function Visit-Node {
        param($node)
        if ($visited.ContainsKey($node)) { return }
        $visited[$node] = $true
        
        if ($dependencies.ContainsKey($node)) {
            foreach ($dep in $dependencies[$node]) {
                Visit-Node $dep
            }
        }
        $sorted += $node
    }
    
    foreach ($className in $Classes.Keys) {
        Visit-Node $className
    }
    
    return $sorted
}

function Invoke-Recompose {
    param($SourceDir, $OutputPath)
    Write-Status "Recomposing project from '$SourceDir' into '$OutputPath'..."
    
    $SourceFileOrder = @(
        'modules\exceptions\exceptions.psm1',
        'modules\logger\logger.psm1',
        'modules\event-system\event-system.psm1',
        'modules\models\models.psm1',
        'components\tui-primitives\tui-primitives.psm1',
        'modules\theme-manager\theme-manager.psm1',
        'components\ui-classes\ui-classes.psm1',
        'layout\panels-class\panels-class.psm1',
        'services\service-container\service-container.psm1',
        'services\action-service\action-service.psm1',
        'services\keybinding-service-class\keybinding-service-class.psm1',
        'services\navigation-service-class\navigation-service-class.psm1',
        'components\tui-components\tui-components.psm1',
        'components\advanced-data-components\advanced-data-components.psm1',
        'components\advanced-input-components\advanced-input-components.psm1',
        'modules\dialog-system-class\dialog-system-class.psm1',
        'modules\panic-handler\panic-handler.psm1',
        'services\keybinding-service\keybinding-service.psm1',
        'services\navigation-service\navigation-service.psm1',
        'modules\tui-framework\tui-framework.psm1',
        'components\command-palette\command-palette.psm1',
        'modules\data-manager\data-manager.psm1',
        'screens\dashboard-screen\dashboard-screen.psm1',
        'screens\task-list-screen\task-list-screen.psm1',
        'modules\tui-engine\tui-engine.psm1'
    )
    
    $mainLogicSource = Join-Path $SourceDir 'run.ps1'
    if (-not (Test-Path $mainLogicSource)) { throw "'run.ps1' not found in source directory." }
    
    $runnerContent = Get-Content -Path $mainLogicSource -Raw
    $paramBlock = if ($runnerContent -match '(?msi)(^param\s*\(.*?\))') { $matches[0] } else { '' }
    $mainLogic = if ($runnerContent -match '(?msi)(# --- MAIN EXECUTION LOGIC ---.*)') { $matches[0] } else { $runnerContent }

    Write-Status "Phase 1: Scanning for class definitions and type references..."
    $allClasses = @{}
    $allTypeRefs = @{}
    $allUsingStatements = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    
    # First pass: collect all class definitions
    foreach ($path in $SourceFileOrder) {
        $fullPath = Join-Path $SourceDir $path
        if (-not (Test-Path $fullPath)) { continue }
        
        $fileContent = Get-Content -Path $fullPath -Raw
        $classes = Get-ClassDefinitions -Content $fileContent
        foreach ($className in $classes.Keys) {
            $allClasses[$className] = $classes[$className]
            Write-Status "    Found class: $className" 'DarkGray'
        }
    }
    
    Write-Status "Phase 2: Processing modules with type safety fixes..."
    $processedContent = @{}
    
    foreach ($path in $SourceFileOrder) {
        $fullPath = Join-Path $SourceDir $path
        if (-not (Test-Path $fullPath)) { 
            Write-Warning "Source file '$fullPath' is missing. Skipping."
            continue 
        }
        
        Write-Status "  -> Processing: $path" 'Gray'
        $fileContent = Get-Content -Path $fullPath -Raw
        
        # Extract using statements
        $usingMatches = [regex]::Matches($fileContent, '(?im)^using\s+namespace\s+.*')
        foreach ($match in $usingMatches) {
            [void]$allUsingStatements.Add($match.Value.Trim())
        }
        
        # Remove using statements
        $cleaned = $fileContent -replace '(?im)^using\s+(module|namespace)\s+.*'
        
        # Remove Export-ModuleMember (handles multi-line)
        $exportBlockRegex = '(?is)Export-ModuleMember.*?(?<!`)(\r?\n)'
        $cleaned = $cleaned -replace $exportBlockRegex
        
        # Apply type safety fixes
        if ($DebugTypes) {
            $cleaned = Remove-StrictTypeHints -Content $cleaned -CustomTypes $allClasses
        }
        
        $processedContent[$path] = $cleaned.Trim()
    }
    
    Write-Status "Phase 3: Assembling the monolith..."
    $finalScript = [System.Text.StringBuilder]::new()

    [void]$finalScript.AppendLine("# ==============================================================================")
    [void]$finalScript.AppendLine("# Axiom-Phoenix - MONOLITH SCRIPT")
    [void]$finalScript.AppendLine("# Auto-generated by mushroom.ps1 v7.0 on $(Get-Date)")
    [void]$finalScript.AppendLine("# ==============================================================================")
    [void]$finalScript.AppendLine()
    
    # Add global using statements
    [void]$finalScript.AppendLine("# --- Global Using Statements ---")
    foreach ($statement in $allUsingStatements | Sort-Object) {
        [void]$finalScript.AppendLine($statement)
    }
    [void]$finalScript.AppendLine("# --- End Using Statements ---")
    [void]$finalScript.AppendLine()
    
    # Add parameter block from run.ps1
    [void]$finalScript.AppendLine($paramBlock)
    [void]$finalScript.AppendLine()
    
    # Add type resolution helper if needed
    if ($allClasses.Count -gt 0) {
        [void]$finalScript.AppendLine(@'
# --- Type Resolution Helper ---
$script:TypeCache = @{}
function Get-CustomType {
    param([string]$TypeName)
    if (-not $script:TypeCache.ContainsKey($TypeName)) {
        $type = [System.AppDomain]::CurrentDomain.GetAssemblies().GetTypes() | 
            Where-Object { $_.Name -eq $TypeName } | 
            Select-Object -First 1
        $script:TypeCache[$TypeName] = $type
    }
    return $script:TypeCache[$TypeName]
}
# --- End Type Resolution ---

'@)
    }
    
    # Add all module content
    foreach ($path in $SourceFileOrder) {
        if ($processedContent.ContainsKey($path)) {
            [void]$finalScript.AppendLine("# ==== Module: $path ====")
            [void]$finalScript.AppendLine($processedContent[$path])
            [void]$finalScript.AppendLine()
        }
    }
    
    # Add main execution logic
    [void]$finalScript.AppendLine("# ==============================================================================")
    [void]$finalScript.AppendLine("# MAIN EXECUTION")
    [void]$finalScript.AppendLine("# ==============================================================================")
    [void]$finalScript.AppendLine($mainLogic.Trim())

    # Write the monolith
    Set-Content -Path $OutputPath -Value $finalScript.ToString() -Encoding UTF8
    
    # Create a type-safe wrapper if requested
    if ($DebugTypes) {
        $wrapperPath = [System.IO.Path]::ChangeExtension($OutputPath, ".wrapper.ps1")
        $wrapper = @"
# Type-Safe Wrapper for $OutputPath
# This wrapper ensures all types are loaded before execution

`$ErrorActionPreference = 'Stop'

# Load the monolith in a way that allows type resolution
& {
    # First, dot-source to load all type definitions
    . '$OutputPath'
    
    # Types should now be available
    Write-Host "Monolith loaded successfully!" -ForegroundColor Green
}
"@
        Set-Content -Path $wrapperPath -Value $wrapper -Encoding UTF8
        Write-Status "Created type-safe wrapper at '$wrapperPath'" "Yellow"
    }
    
    Write-Status "Recomposition complete! Monolith is at '$OutputPath'" "Green"
    
    # Provide diagnostics
    Write-Host ""
    Write-Status "Diagnostics:" "Magenta"
    Write-Status "  Total modules processed: $($processedContent.Count)" "White"
    Write-Status "  Classes found: $($allClasses.Count)" "White"
    if ($allClasses.Count -gt 0) {
        Write-Status "  Class load order:" "White"
        $order = Get-DependencyOrder -Classes $allClasses
        foreach ($className in $order) {
            Write-Status "    - $className" "DarkGray"
        }
    }
    
    if (-not $DebugTypes) {
        Write-Host ""
        Write-Status "TIP: If you get type errors, run with -DebugTypes flag" "Yellow"
    }
}

function Show-Help {
    Write-Host @"
Mushroom - The Monolith Decomposer & Recomposer Toolkit (v7.0)

USAGE:
    .\mushroom.ps1 [recompose] [path] [output] [-DebugTypes]

COMMANDS:
    recompose   - Combine modular files into a monolith (default)

PARAMETERS:
    path        - Source directory (default: current directory)
    output      - Output file name (default: AxiomPhoenix.ps1)
    -DebugTypes - Enable type safety fixes and create wrapper

EXAMPLES:
    .\mushroom.ps1
    .\mushroom.ps1 recompose . MyMonolith.ps1
    .\mushroom.ps1 recompose . MyMonolith.ps1 -DebugTypes

TYPE SYSTEM NOTES:
    PowerShell's type system can cause issues when combining modules.
    Use -DebugTypes to automatically fix type references and create
    a type-safe wrapper script.
"@
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================
try {
    switch ($Command.ToLower()) {
        'recompose' {
            $sourceDir = if ($Path) { (Resolve-Path $Path).Path } else { $PSScriptRoot }
            Invoke-Recompose -SourceDir $sourceDir -OutputPath $Output
        }
        default { Show-Help }
    }
} catch {
    Write-Host "`n🍄 ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    }
    exit 1
}