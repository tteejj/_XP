# clean-classes.ps1 - Removes module qualifiers from type references
param(
    [string]$InputFile = "all-classes.ps1",
    [string]$OutputFile = "all-classes-clean.ps1"
)

Write-Host "🧹 Cleaning module qualifiers from $InputFile..." -ForegroundColor Cyan

$content = Get-Content $InputFile -Raw

# Find all class names in the file
$classNames = [regex]::Matches($content, '(?m)^(?:class|enum)\s+(\w+)') | 
    ForEach-Object { $_.Groups[1].Value } | 
    Sort-Object -Unique

Write-Host "Found $($classNames.Count) class/enum names to clean" -ForegroundColor Gray

# Remove module qualifiers for each known class
$cleaned = $content
foreach ($className in $classNames) {
    # Pattern matches [module.ClassName] or [modules.ClassName] etc.
    $pattern = '\[[\w.]+\.(' + [regex]::Escape($className) + ')\]'
    $replacement = '[$1]'
    
    $matches = [regex]::Matches($cleaned, $pattern)
    if ($matches.Count -gt 0) {
        Write-Host "  Cleaning $($matches.Count) references to $className" -ForegroundColor DarkGray
        $cleaned = [regex]::Replace($cleaned, $pattern, $replacement)
    }
}

# Also clean up any {_variableName} which should be $_variableName
$cleaned = [regex]::Replace($cleaned, '\{(_\w+)\}', '$$$1')

# Save cleaned file
Set-Content -Path $OutputFile -Value $cleaned -Encoding UTF8
Write-Host "✅ Saved cleaned file to $OutputFile" -ForegroundColor Green

# Update launcher to use the cleaned file
$launcherContent = @'
# launcher.ps1 - Loads all classes then runs the application
param(
    [switch]$Debug,
    [switch]$SkipLogo
)

$ErrorActionPreference = 'Stop'
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "🚀 Axiom-Phoenix Launcher" -ForegroundColor Cyan

# STAGE 1: Load all class definitions (cleaned version)
Write-Host "Loading class definitions..." -ForegroundColor Gray
. "$PSScriptRoot\all-classes-clean.ps1"

# STAGE 2: Now we can safely run the main script
Write-Host "Starting main application..." -ForegroundColor Gray

# The run.ps1 can now assume all classes exist
$runScript = Join-Path $PSScriptRoot "run.ps1"
if (Test-Path $runScript) {
    & $runScript @PSBoundParameters
} else {
    Write-Host "ERROR: run.ps1 not found!" -ForegroundColor Red
    Write-Host "Expected location: $runScript" -ForegroundColor Red
}
'@

Set-Content -Path "launcher.ps1" -Value $launcherContent -Encoding UTF8
Write-Host "✅ Updated launcher.ps1 to use cleaned file" -ForegroundColor Green

# Update test script too
$testContent = @'
# test-classes.ps1 - Test if classes load correctly
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Testing class loading..." -ForegroundColor Cyan
    . ".\all-classes-clean.ps1"
    
    Write-Host "`nTesting basic class instantiation:" -ForegroundColor Yellow
    
    # Test enum
    $status = [TaskStatus]::Pending
    Write-Host "  ✓ TaskStatus enum: $status" -ForegroundColor Green
    
    # Test basic class
    $task = [PmcTask]::new()
    Write-Host "  ✓ PmcTask class: Created task with ID $($task.Id)" -ForegroundColor Green
    
    # Test UI class  
    $ui = [UIElement]::new()
    Write-Host "  ✓ UIElement class: Created element '$($ui.Name)'" -ForegroundColor Green
    
    Write-Host "`n✅ All basic tests passed!" -ForegroundColor Green
    Write-Host "`nAvailable classes:" -ForegroundColor Gray
    
    # List all loaded types that aren't from System namespace
    [AppDomain]::CurrentDomain.GetAssemblies() | 
        ForEach-Object { try { $_.GetTypes() } catch {} } | 
        Where-Object { $_.IsClass -and $_.Namespace -eq $null } |
        Select-Object -First 20 -ExpandProperty Name |
        Sort-Object |
        ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }
    
} catch {
    Write-Host "`n❌ Error loading classes:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}
'@

Set-Content -Path "test-classes.ps1" -Value $testContent -Encoding UTF8
Write-Host "✅ Updated test-classes.ps1" -ForegroundColor Green