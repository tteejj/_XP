#Requires -Version 7.0
param(
    [Parameter(Position = 0)]
    [string]$Command = 'help',
    
    [Parameter(Position = 1)]
    [string]$Path,
    
    [string]$Output = "recomposed.ps1"
)

$ErrorActionPreference = 'Stop'
$script:ManifestFile = "mushroom.json"

# Simple status writer
function Write-Status {
    param($Message, $Color = 'Cyan')
    Write-Host "MUSHROOM: $Message" -ForegroundColor $Color
}

# AST Parser for PowerShell code
function Parse-PowerShellFile {
    param($FilePath)
    
    try {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $FilePath,
            [ref]$tokens,
            [ref]$errors
        )
        
        if ($errors.Count -gt 0) {
            Write-Status "Parse errors found in source file:" "Red"
            $errors | ForEach-Object { Write-Host $_.Message -ForegroundColor Red }
            return $null
        }
        
        return $ast
    }
    catch {
        Write-Status "Failed to parse file: $_" "Red"
        return $null
    }
}

# Extract components from AST
function Get-Components {
    param($Ast)
    
    $components = @{
        Classes = @()
        Functions = @()
        UsingStatements = @()
    }
    
    # Get using statements
    if ($Ast.UsingStatements) {
        $components.UsingStatements = $Ast.UsingStatements | ForEach-Object {
            $_.Extent.Text
        }
    }
    
    # Find all classes
    $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.TypeDefinitionAst] }, $true) | ForEach-Object {
        $components.Classes += @{
            Name = $_.Name
            Text = $_.Extent.Text
            Type = if ($_.Name -match 'Screen$') { 'screen' }
                   elseif ($_.Name -match 'Component$') { 'component' }
                   elseif ($_.Name -match 'Service$') { 'service' }
                   elseif ($_.Name -match 'Manager$') { 'module' }
                   else { 'lib' }
        }
    }
    
    # Find all functions
    $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object {
        $components.Functions += @{
            Name = $_.Name
            Text = $_.Extent.Text
            Type = if ($_.Name -match '^(Show|Hide|Write)-') { 'component' }
                   elseif ($_.Name -match '^(Get|Set|New|Remove)-') { 'module' }
                   else { 'lib' }
        }
    }
    
    return $components
}

# DECOMPOSE command
if ($Command -eq 'decompose') {
    if (-not $Path -or -not (Test-Path $Path)) {
        Write-Status "Usage: mushroom decompose <file.ps1>" "Red"
        exit 1
    }
    
    Write-Status "Decomposing $Path..."
    
    # Parse the file
    $ast = Parse-PowerShellFile -FilePath $Path
    if (-not $ast) { exit 1 }
    
    $components = Get-Components -Ast $ast
    
    # Create directories
    $dirs = @('lib', 'modules', 'components', 'screens', 'services')
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Status "Created $dir/" "Green"
        }
    }
    
    # Save manifest
    $manifest = @{
        source = (Get-Item $Path).Name
        created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        files = @{}
    }
    
    # Extract using statements (will be added to each file)
    $usingBlock = if ($components.UsingStatements) {
        $components.UsingStatements -join "`n"
    } else { "" }
    
    # Extract classes
    foreach ($class in $components.Classes) {
        $dir = switch ($class.Type) {
            'screen' { 'screens' }
            'component' { 'components' }
            'service' { 'services' }
            'module' { 'modules' }
            default { 'lib' }
        }
        
        $filename = "$($class.Name).ps1"
        $filepath = Join-Path $dir $filename
        
        $content = @()
        if ($usingBlock) {
            $content += $usingBlock
            $content += ""
        }
        $content += $class.Text
        
        $content -join "`n" | Set-Content $filepath
        Write-Status "Extracted: $filepath" "Green"
        
        $manifest.files[$filename] = @{
            type = 'class'
            name = $class.Name
            path = $filepath
        }
    }
    
    # Extract functions (group by module)
    $functionGroups = $components.Functions | Group-Object Type
    
    foreach ($group in $functionGroups) {
        $dir = switch ($group.Name) {
            'component' { 'components' }
            'module' { 'modules' }
            default { 'lib' }
        }
        
        $filename = "$($group.Name)-functions.ps1"
        $filepath = Join-Path $dir $filename
        
        $content = @()
        if ($usingBlock) {
            $content += $usingBlock
            $content += ""
        }
        
        foreach ($func in $group.Group) {
            $content += $func.Text
            $content += ""
        }
        
        $content -join "`n" | Set-Content $filepath
        Write-Status "Extracted: $filepath" "Green"
        
        $manifest.files[$filename] = @{
            type = 'functions'
            path = $filepath
            functions = $group.Group.Name
        }
    }
    
    # Create loader script
    $loader = @'
#Requires -Version 7.0
# Auto-generated by Mushroom

Write-Host "Loading modules..." -ForegroundColor Gray

# Load in dependency order
$patterns = @(
    'lib/*.ps1',
    'modules/*.ps1',
    'services/*.ps1',
    'components/*.ps1',
    'screens/*.ps1'
)

foreach ($pattern in $patterns) {
    Get-ChildItem $pattern -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  Loading: $($_.Name)" -ForegroundColor DarkGray
        . $_.FullName
    }
}

Write-Host "Ready!" -ForegroundColor Green

# Call main if exists
if (Get-Command Start-Application -ErrorAction SilentlyContinue) {
    Start-Application
}
'@
    
    $loader | Set-Content "run.ps1"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content $script:ManifestFile
    
    Write-Status "Decomposition complete! Use 'mushroom run' to execute." "Green"
}

# RECOMPOSE command
elseif ($Command -eq 'recompose') {
    if (-not (Test-Path $script:ManifestFile)) {
        Write-Status "No manifest found. Run decompose first." "Red"
        exit 1
    }
    
    Write-Status "Recomposing to $Output..."
    
    $manifest = Get-Content $script:ManifestFile -Raw | ConvertFrom-Json
    $output = @()
    
    # Header
    $output += "#Requires -Version 7.0"
    $output += "# Recomposed from: $($manifest.source)"
    $output += "# Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $output += ""
    
    # Get all using statements (deduplicated)
    $allUsing = @()
    Get-ChildItem -Path "lib/*.ps1", "modules/*.ps1", "components/*.ps1", "screens/*.ps1", "services/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        $lines = $content -split "`n"
        $allUsing += $lines | Where-Object { $_ -match '^using ' }
    }
    
    $output += $allUsing | Select-Object -Unique
    $output += ""
    
    # Add all files in order
    $dirs = @('lib', 'modules', 'services', 'components', 'screens')
    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            $output += "# ========== $($dir.ToUpper()) =========="
            Get-ChildItem "$dir/*.ps1" | ForEach-Object {
                Write-Status "Adding: $($_.Name)"
                $content = Get-Content $_.FullName -Raw
                # Remove using statements (already at top)
                $content = $content -replace '(?m)^using .+$', ''
                $output += "# --- $($_.Name) ---"
                $output += $content.Trim()
                $output += ""
            }
        }
    }
    
    $output -join "`n" | Set-Content $Output
    Write-Status "Recomposed to: $Output" "Green"
}

# RUN command
elseif ($Command -eq 'run') {
    if (Test-Path "run.ps1") {
        Write-Status "Starting application..." "Green"
        & .\run.ps1
    }
    else {
        Write-Status "No run.ps1 found. Run decompose first." "Red"
    }
}

# ADD command
elseif ($Command -eq 'add') {
    if ($Path -match '^(\w+):(\w+)$') {
        $type = $Matches[1]
        $name = $Matches[2]
        
        $templates = @{
            'screen' = @"
class ${name}Screen : Screen {
    ${name}Screen() : base() {
        `$this.Title = "$name"
    }
    
    [void] OnRender() {
        # Render logic here
    }
}
"@
            'component' = @"
class ${name}Component : Component {
    ${name}Component() : base() {
        `$this.Width = 20
        `$this.Height = 3
    }
    
    [void] OnRender() {
        # Render logic here
    }
}
"@
            'service' = @"
class ${name}Service {
    [void] Initialize() {
        # Init logic here
    }
}
"@
        }
        
        if ($templates.ContainsKey($type)) {
            $dir = "${type}s"
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            
            $filepath = Join-Path $dir "$name.ps1"
            $templates[$type] | Set-Content $filepath
            Write-Status "Created: $filepath" "Green"
        }
        else {
            Write-Status "Unknown type. Use: screen, component, or service" "Red"
        }
    }
    else {
        Write-Status "Usage: mushroom add <type>:<name>" "Red"
        Write-Status "Example: mushroom add screen:Settings" "Yellow"
    }
}

# HELP
else {
    Write-Host @"

MUSHROOM - PowerShell Module Manager

Commands:
  decompose <file>    Break apart a monolithic file
  recompose          Rebuild into single file  
  run                Run the modular app
  add <type>:<name>  Create new component

Examples:
  mushroom decompose MyBigScript.ps1
  mushroom run
  mushroom add screen:Settings
  mushroom recompose -Output final.ps1

"@ -ForegroundColor Cyan
}