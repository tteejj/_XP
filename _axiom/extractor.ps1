# manual-order-extractor.ps1 - Extracts classes in manually specified order
[CmdletBinding()]
param(
    [string]$OutputFile = "all-classes.ps1"
)

$ErrorActionPreference = 'Stop'
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "🔍 Manual Order Extractor - Using known dependency order..." -ForegroundColor Cyan

# MANUAL ORDER - Based on inheritance hierarchy
$classOrder = @(
    # Enums first (no dependencies)
    'TaskStatus',
    'TaskPriority', 
    'BillingType',
    'LogLevel',
    'EventScope',
    
    # Base validation class
    'ValidationBase',
    
    # Core models (depend on ValidationBase)
    'PmcTask',
    'PmcProject',
    'TimeEntry',
    
    # TUI primitives (no class dependencies)
    'TuiAnsiHelper',
    'TuiCell',
    'TuiBuffer',
    
    # Base exception classes
    'PmcException',
    'ComponentException',
    'ServiceException',
    'ValidationException',
    'ConfigurationException',
    'RenderException',
    
    # Base UI class (THE CRITICAL ONE)
    'UIElement',
    
    # Classes that inherit from UIElement
    'Component',
    'Screen',
    'Panel',
    'Container',
    'Dialog',
    'Table',
    'TableColumn',
    'LabelComponent',
    'ButtonComponent',
    'TextBoxComponent',
    'CheckBoxComponent',
    'RadioButtonComponent',
    'MultilineTextBoxComponent',
    'NumericInputComponent',
    'DateInputComponent',
    'ComboBoxComponent',
    'CommandPalette',
    'NavigationItem',
    'NavigationMenu',
    'ConfirmDialog',
    'DashboardScreen',
    'TaskListScreen',
    
    # Service classes
    'ServiceBase',
    'ServiceContainer',
    'ServiceRegistration',
    'NavigationService',
    'KeyBinding',
    'KeybindingService',
    'ActionService',
    
    # Data manager
    'DataManager',
    
    # Any remaining classes will be added at the end
    '*'
)

# Read all PSM1 files and extract content
Write-Host "Reading module files..." -ForegroundColor Gray
$moduleFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.psm1" -Recurse | 
    Where-Object { $_.DirectoryName -notmatch "_UPGRADE_DOCUMENTATION" }

# Extract all class/enum definitions
$allDefinitions = @{}

foreach ($file in $moduleFiles) {
    $content = Get-Content $file.FullName -Raw
    $relativePath = $file.FullName.Replace($PSScriptRoot, '').TrimStart('\')
    
    # Extract enums - simple pattern
    $enumMatches = [regex]::Matches($content, '(?ms)^enum\s+(\w+)\s*\{[^}]*\}')
    foreach ($match in $enumMatches) {
        $name = $match.Groups[1].Value
        $allDefinitions[$name] = @{
            Type = 'enum'
            Name = $name
            Definition = $match.Value
            File = $relativePath
        }
    }
    
    # Extract classes - use AST for reliability
    try {
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $classes = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.TypeDefinitionAst] -and $args[0].TypeAttributes -eq 'Class' }, $true)
        
        foreach ($class in $classes) {
            $name = $class.Name
            $definition = $content.Substring($class.Extent.StartOffset, $class.Extent.EndOffset - $class.Extent.StartOffset)
            
            $allDefinitions[$name] = @{
                Type = 'class'
                Name = $name
                Definition = $definition
                File = $relativePath
                BaseClass = if ($class.BaseTypes) { $class.BaseTypes[0].TypeName.Name } else { $null }
            }
        }
    } catch {
        Write-Warning "Failed to parse $($file.Name) with AST, falling back to regex"
        
        # Fallback to simple line parsing
        $lines = $content -split "`n"
        $inClass = $false
        $className = $null
        $classLines = @()
        $braceCount = 0
        
        foreach ($line in $lines) {
            if ($line -match '^\s*class\s+(\w+)') {
                $className = $Matches[1]
                $inClass = $true
                $classLines = @($line)
                $braceCount = ($line -split '\{').Count - ($line -split '\}').Count
            }
            elseif ($inClass) {
                $classLines += $line
                $braceCount += ($line -split '\{').Count - 1
                $braceCount -= ($line -split '\}').Count - 1
                
                if ($braceCount -eq 0) {
                    $allDefinitions[$className] = @{
                        Type = 'class'
                        Name = $className
                        Definition = $classLines -join "`n"
                        File = $relativePath
                    }
                    $inClass = $false
                }
            }
        }
    }
}

Write-Host "Found $($allDefinitions.Count) total definitions" -ForegroundColor Green

# Build output in manual order
$output = @"
# ==============================================================================
# All Classes - Manually Ordered by manual-order-extractor.ps1
# Generated: $(Get-Date)
# Total Definitions: $($allDefinitions.Count)
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Threading.Tasks
using namespace System.Collections.Concurrent
using namespace System.Text

"@

$addedDefinitions = @{}
$orderedDefinitions = @()

# Add in specified order
foreach ($name in $classOrder) {
    if ($name -eq '*') {
        # Add all remaining definitions
        foreach ($defName in $allDefinitions.Keys) {
            if (-not $addedDefinitions[$defName]) {
                $orderedDefinitions += $allDefinitions[$defName]
                $addedDefinitions[$defName] = $true
            }
        }
    }
    elseif ($allDefinitions.ContainsKey($name)) {
        if (-not $addedDefinitions[$name]) {
            $orderedDefinitions += $allDefinitions[$name]
            $addedDefinitions[$name] = $true
        }
    }
    else {
        Write-Warning "Class/Enum '$name' specified in order but not found"
    }
}

# Group by file for output
$currentFile = $null
foreach ($def in $orderedDefinitions) {
    if ($def.File -ne $currentFile) {
        if ($currentFile) {
            $output += "#endregion`n`n"
        }
        $output += "#region Definitions from $($def.File)`n`n"
        $currentFile = $def.File
    }
    
    $output += "$($def.Definition)`n`n"
}

if ($currentFile) {
    $output += "#endregion`n"
}

# Save
Set-Content -Path $OutputFile -Value $output -Encoding UTF8
Write-Host "✅ Generated $OutputFile with manual ordering" -ForegroundColor Green

# Create verification script
$verifyContent = @'
# verify-order.ps1 - Verifies class ordering
$content = Get-Content "all-classes.ps1" -Raw
$lines = $content -split "`n"

Write-Host "Checking class ordering..." -ForegroundColor Cyan

# Find all class definitions and their line numbers
$classes = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^(class|enum)\s+(\w+)(?:\s*:\s*(\w+))?') {
        $classes += @{
            Type = $Matches[1]
            Name = $Matches[2]
            Base = $Matches[3]
            Line = $i + 1
        }
    }
}

Write-Host "Found $($classes.Count) type definitions" -ForegroundColor Gray

# Check that base classes come before derived classes
$defined = @{}
$errors = 0

foreach ($class in $classes) {
    $defined[$class.Name] = $class.Line
    
    if ($class.Base -and -not $defined.ContainsKey($class.Base)) {
        Write-Host "❌ ERROR: $($class.Name) (line $($class.Line)) inherits from $($class.Base) which hasn't been defined yet" -ForegroundColor Red
        $errors++
    }
}

if ($errors -eq 0) {
    Write-Host "✅ All classes are properly ordered!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Found $errors ordering errors" -ForegroundColor Red
}

# Show first few definitions
Write-Host "`nFirst 10 definitions:" -ForegroundColor Yellow
$classes | Select-Object -First 10 | ForEach-Object {
    $baseInfo = if ($_.Base) { ": $($_.Base)" } else { "" }
    Write-Host "  $($_.Type) $($_.Name)$baseInfo (line $($_.Line))" -ForegroundColor DarkGray
}
'@

Set-Content -Path "verify-order.ps1" -Value $verifyContent
Write-Host "✅ Generated verify-order.ps1" -ForegroundColor Green

Write-Host "`n📋 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Verify ordering: .\verify-order.ps1" -ForegroundColor White
Write-Host "  2. Test classes:    .\test-classes.ps1" -ForegroundColor White