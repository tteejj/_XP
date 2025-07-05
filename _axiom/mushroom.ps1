# mushroom.ps1 - The Monolith Decomposer & Recomposer Toolkit (v6.0 - Hard-Coded)

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = 'help',
    
    [Parameter(Position = 1)]
    [string]$Path,
    
    [Parameter(Position = 2)]
    [string]$Output = "AxiomPhoenix.ps1"
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

function Invoke-Recompose {
    param($SourceDir, $OutputPath)
    Write-Status "Recomposing project from '$SourceDir' into '$OutputPath'..."
    
    # The master build order. This is the source of truth for dependencies.
    $SourceFileOrder = @(
        'modules\exceptions\exceptions.psm1', 'modules\logger\logger.psm1', 'modules\event-system\event-system.psm1', 'modules\models\models.psm1',
        'components\tui-primitives\tui-primitives.psm1', 'modules\theme-manager\theme-manager.psm1', 'components\ui-classes\ui-classes.psm1',
        'layout\panels-class\panels-class.psm1', 'services\service-container\service-container.psm1', 'services\action-service\action-service.psm1',
        'services\keybinding-service-class\keybinding-service-class.psm1', 'services\navigation-service-class\navigation-service-class.psm1',
        'components\tui-components\tui-components.psm1', 'components\advanced-data-components\advanced-data-components.psm1',
        'components\advanced-input-components\advanced-input-components.psm1', 'modules\dialog-system-class\dialog-system-class.psm1',
        'modules\panic-handler\panic-handler.psm1', 'services\keybinding-service\keybinding-service.psm1', 'services\navigation-service\navigation-service.psm1',
        'modules\tui-framework\tui-framework.psm1', 'components\command-palette\command-palette.psm1', 'modules\data-manager\data-manager.psm1',
        'screens\dashboard-screen\dashboard-screen.psm1', 'screens\task-list-screen\task-list-screen.psm1', 'modules\tui-engine\tui-engine.psm1',
        'run.ps1'
    )
    
    $mainLogicSource = Join-Path $SourceDir 'run.ps1'
    if (-not (Test-Path $mainLogicSource)) { throw "'run.ps1' not found in source directory."}
    
    $runnerContent = Get-Content -Path $mainLogicSource -Raw
    $paramBlock = if ($runnerContent -match '(?msi)(^param\s*\(.*?\))') { $matches[0] } else { '' }
    $mainLogic = ($runnerContent -split '# --- MAIN EXECUTION LOGIC ---', 2)[-1]

    # --- Build the Monolith ---
    Write-Status "Assembling the monolith..."
    $sb = [System.Text.StringBuilder]::new()

    # HARD-CODED using statements, as instructed. This is the definitive list.
    [void]$sb.AppendLine("# --- HARD-CODED USING STATEMENTS ---")
    [void]$sb.AppendLine("using namespace System.Collections.Concurrent")
    [void]$sb.AppendLine("using namespace System.Collections.Generic")
    [void]$sb.AppendLine("using namespace System.Management.Automation")
    [void]$sb.AppendLine("using namespace System.Threading")
    [void]$sb.AppendLine("using namespace System.Threading.Tasks")
    [void]$sb.AppendLine("# --- END USING STATEMENTS ---")
    [void]$sb.AppendLine()
    
    # Write the param() block AFTER using statements
    [void]$sb.AppendLine($paramBlock)
    [void]$sb.AppendLine()

    $filesToEmbed = $SourceFileOrder | Where-Object { $_ -ne 'run.ps1' }
    foreach ($path in $filesToEmbed) {
        $fullPath = Join-Path $SourceDir $path
        if (-not (Test-Path $fullPath)) { Write-Warning "Source file '$fullPath' is missing. Skipping."; continue }
        
        # Read the file line by line and STRIP ALL 'using' statements.
        $cleanLines = Get-Content -Path $fullPath | Where-Object { -not $_.Trim().StartsWith('using ') }
        $cleanContent = $cleanLines -join [System.Environment]::NewLine

        Write-Status "  -> Embedding: $path" 'Gray'
        [void]$sb.AppendLine("####$path")
        [void]$sb.AppendLine($cleanContent.Trim())
        [void]$sb.AppendLine()
    }

    # Write the main logic at the very end
    [void]$sb.AppendLine("####run.ps1")
    [void]$sb.AppendLine($mainLogic.Trim())
    
    Set-Content -Path $OutputPath -Value $sb.ToString() -Encoding UTF8
    Write-Status "Recomposition complete! New monolith is at '$OutputPath'" "Green"
}


function Show-Help {
    Write-Host "help"
}

#==============================================================================
# MAIN EXECUTION BLOCK
#==============================================================================
try {
    switch ($Command.ToLower()) {
        'recompose' {
            $sourceDir = if ($Path) { $Path } else { "." }
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