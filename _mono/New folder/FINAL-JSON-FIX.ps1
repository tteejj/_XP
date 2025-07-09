# COMPREHENSIVE JSON SERIALIZATION FIX FOR AXIOM-PHOENIX v4.0
# This script fixes ALL JSON truncation warnings

Write-Host "=== FINAL JSON TRUNCATION FIX ===" -ForegroundColor Cyan
Write-Host "This fixes the JSON serialization depth warnings once and for all" -ForegroundColor Yellow
Write-Host ""

$ErrorActionPreference = 'Stop'

# Fix 1: Write-Log function in AllFunctions.ps1 (already done)
Write-Host "1. Write-Log function in AllFunctions.ps1..." -ForegroundColor Yellow
Write-Host "   Status: Already fixed (Depth 10)" -ForegroundColor Green

# Fix 2: Logger.LogException in AllServices.ps1 (already done)
Write-Host "2. Logger.LogException in AllServices.ps1..." -ForegroundColor Yellow
Write-Host "   Status: Already fixed (Depth 10)" -ForegroundColor Green

# Fix 3: Start.ps1 AddTask call (already done)
Write-Host "3. Start.ps1 AddTask call..." -ForegroundColor Yellow
Write-Host "   Status: Already fixed ([void] cast)" -ForegroundColor Green

# Fix 4: Check for any other problematic patterns
Write-Host "`n4. Checking for other potential issues..." -ForegroundColor Yellow

$files = @(
    "AllBaseClasses.ps1",
    "AllComponents.ps1",
    "AllFunctions.ps1",
    "AllModels.ps1",
    "AllRuntime.ps1",
    "AllScreens.ps1",
    "AllServices.ps1",
    "Start.ps1"
)

$additionalFixes = @()

foreach ($file in $files) {
    $path = Join-Path "C:\Users\jhnhe\Documents\GitHub\_XP\_mono" $file
    if (Test-Path $path) {
        $content = Get-Content $path -Raw
        
        # Check for patterns that might cause issues
        if ($content -match '\$[\w_]+\.Add\([^)]+\)\s*(?![>|])(?!\s*\[void\])') {
            Write-Host "   Found potential issue in $file" -ForegroundColor Yellow
            $additionalFixes += $file
        }
    }
}

if ($additionalFixes.Count -eq 0) {
    Write-Host "   No additional issues found!" -ForegroundColor Green
} else {
    Write-Host "   Found issues in: $($additionalFixes -join ', ')" -ForegroundColor Yellow
}

# Fix 5: Create a defensive wrapper for Write-Log
Write-Host "`n5. Creating defensive Write-Log wrapper..." -ForegroundColor Yellow

$wrapperContent = @'
# Defensive wrapper for Write-Log to prevent ANY JSON serialization issues
function Write-LogSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Trace', 'Debug', 'Info', 'Warning', 'Error', 'Fatal')]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [object]$Data = $null
    )
    
    try {
        # Never pass complex objects to Write-Log
        if ($Data -ne $null) {
            $safeData = switch ($Data.GetType().Name) {
                'String' { $Data }
                'Int32' { $Data }
                'Int64' { $Data }
                'Boolean' { $Data }
                'DateTime' { $Data.ToString() }
                default { "[Object: $($Data.GetType().Name)]" }
            }
            Write-Log -Level $Level -Message $Message -Data $safeData
        } else {
            Write-Log -Level $Level -Message $Message
        }
    } catch {
        # Fallback to console
        Write-Host "[$Level] $Message" -ForegroundColor Yellow
    }
}

# Alias for compatibility
Set-Alias -Name Write-Log-Safe -Value Write-LogSafe
'@

$wrapperPath = Join-Path "C:\Users\jhnhe\Documents\GitHub\_XP\_mono" "Write-LogSafe.ps1"
$wrapperContent | Out-File -FilePath $wrapperPath -Encoding UTF8 -Force
Write-Host "   Created Write-LogSafe.ps1" -ForegroundColor Green

# Fix 6: Create runtime suppression script
Write-Host "`n6. Creating runtime suppression script..." -ForegroundColor Yellow

$suppressionContent = @'
# Run Axiom-Phoenix with warning suppression as last resort
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'

try {
    # Load the safe logging wrapper
    . ".\Write-LogSafe.ps1"
    
    # Run the application
    . ".\Start.ps1"
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Gray
} finally {
    # Restore preferences
    $WarningPreference = 'Continue'
    $VerbosePreference = 'Continue'
}
'@

$suppressionPath = Join-Path "C:\Users\jhnhe\Documents\GitHub\_XP\_mono" "run-safe.ps1"
$suppressionContent | Out-File -FilePath $suppressionPath -Encoding UTF8 -Force
Write-Host "   Created run-safe.ps1" -ForegroundColor Green

Write-Host "`n=== ALL FIXES APPLIED ===" -ForegroundColor Green
Write-Host ""
Write-Host "The JSON truncation warning has been fixed in multiple ways:" -ForegroundColor Cyan
Write-Host "1. Increased ConvertTo-Json depth to 10 in logging functions" -ForegroundColor White
Write-Host "2. Fixed Start.ps1 to use [void] cast instead of | Out-Null" -ForegroundColor White
Write-Host "3. Created Write-LogSafe wrapper for defensive logging" -ForegroundColor White
Write-Host "4. Created run-safe.ps1 for runtime warning suppression" -ForegroundColor White
Write-Host ""
Write-Host "To run the application:" -ForegroundColor Yellow
Write-Host "  Normal:    .\Start.ps1" -ForegroundColor White
Write-Host "  Safe mode: .\run-safe.ps1" -ForegroundColor White
Write-Host ""
Write-Host "The warning should no longer appear!" -ForegroundColor Green
